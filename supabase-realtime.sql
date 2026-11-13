-- Phantom RoTE Guide: enable Supabase Realtime for live shared edits.
-- Run this once in Supabase Dashboard > SQL Editor.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'guide_data'
  ) then
    alter publication supabase_realtime add table public.guide_data;
  end if;
end
$$;
