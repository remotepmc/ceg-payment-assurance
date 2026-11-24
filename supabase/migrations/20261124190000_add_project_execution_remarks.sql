alter table public.projects
  add column if not exists execution_stage_remarks text,
  add column if not exists project_execution_remarks text;
