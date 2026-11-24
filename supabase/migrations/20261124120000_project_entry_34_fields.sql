-- Add the agreed 34-field project entry data model.
alter table public.projects
  add column if not exists project_location text,
  add column if not exists execution_stage text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'projects_execution_stage_check'
      and conrelid = 'public.projects'::regclass
  ) then
    alter table public.projects
      add constraint projects_execution_stage_check
      check (execution_stage is null or execution_stage in ('WIP', 'Delay', 'Hold'));
  end if;
end $$;

-- Keep all Admin-only tracking values outside the client-readable projects
-- and project_admin_tracking tables.
create table if not exists public.project_admin_metrics (
  project_id uuid primary key references public.projects(id) on delete cascade,
  execution_in_time boolean,
  execution_delay_days integer check (execution_delay_days is null or execution_delay_days >= 0),
  execution_delay_comment text,
  material_in_time boolean,
  material_delay_days integer check (material_delay_days is null or material_delay_days >= 0),
  material_delay_comment text,
  billing_in_time boolean,
  billing_delay_days integer check (billing_delay_days is null or billing_delay_days >= 0),
  billing_delay_comment text,
  payment_in_time boolean,
  payment_delay_days integer check (payment_delay_days is null or payment_delay_days >= 0),
  payment_delay_comment text,
  inactive_project_amount boolean not null default false,
  inactive_project_value numeric,
  ceg_service_designed text,
  money_leakage numeric,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

alter table public.project_admin_metrics enable row level security;
drop policy if exists "Admins manage project admin metrics" on public.project_admin_metrics;
create policy "Admins manage project admin metrics"
  on public.project_admin_metrics
  for all
  to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

grant select, insert, update, delete on public.project_admin_metrics to authenticated;

-- Preserve existing Admin-only values before clearing their legacy,
-- client-readable locations.
insert into public.project_admin_metrics (project_id, ceg_service_designed, money_leakage)
select p.id, coalesce(nullif(p.service_details, ''), nullif(t.ceg_service_designed, '')), p.money_leakage
from public.projects p
left join public.project_admin_tracking t on t.project_id = p.id
where p.service_details is not null
   or p.money_leakage is not null
   or t.ceg_service_designed is not null
on conflict (project_id) do update set
  ceg_service_designed = coalesce(public.project_admin_metrics.ceg_service_designed, excluded.ceg_service_designed),
  money_leakage = coalesce(public.project_admin_metrics.money_leakage, excluded.money_leakage),
  updated_at = now();

update public.projects
set service_details = null,
    money_leakage = null
where service_details is not null or money_leakage is not null;

update public.project_admin_tracking
set ceg_service_designed = null
where ceg_service_designed is not null;
