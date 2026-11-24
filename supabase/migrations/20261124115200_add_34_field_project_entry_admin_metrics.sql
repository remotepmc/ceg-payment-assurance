-- Project Entry: 34 fields
-- Keep client-visible project data on projects; keep fields 22–31 in the
-- Admin-only project_admin_metrics table protected by private.is_admin().

alter table public.projects
  add column if not exists project_location text,
  add column if not exists execution_stage text;

alter table public.projects drop constraint if exists projects_execution_stage_check;
alter table public.projects add constraint projects_execution_stage_check
  check (execution_stage is null or execution_stage = any (array['WIP','Delay','Hold']));

alter table public.projects drop constraint if exists projects_project_type_check;
alter table public.projects add constraint projects_project_type_check
  check (project_type is null or project_type = any (array[
    'Civil','Interior Furniture',
    'Civil - Footing and Plinth','Civil - Structure upto Slab','Civil - Slab',
    'Civil - Brick work super structure','Civil - Plastering Tiles',
    'Civil - Door Window Gril Glass','Civil - MEP','Civil - Pain and Finish',
    'Interior - plywood work','Interior - lamination','Interior - hardware fitting',
    'Materials Supply','Design Drawing','Skill Training'
  ]));

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
  inactive_project_value numeric check (inactive_project_value is null or inactive_project_value >= 0),
  ceg_service_designed text,
  money_leakage numeric check (money_leakage is null or money_leakage >= 0),
  updated_at timestamptz not null default now()
);

alter table public.project_admin_metrics enable row level security;
drop policy if exists "Admins manage project admin metrics" on public.project_admin_metrics;
create policy "Admins manage project admin metrics"
  on public.project_admin_metrics for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

comment on table public.project_admin_metrics is
  'Admin-only project timing metrics, delay comments, inactive project amount/value, CEG service mapping and money leakage.';
