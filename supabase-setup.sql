-- Phantom RoTE Guide: shared database setup
-- Run this in Supabase Dashboard > SQL Editor.
create table if not exists public.guide_data (
  id integer primary key check (id = 1),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.guide_data (id, data)
values (1, '{}'::jsonb)
on conflict (id) do nothing;

create table if not exists public.editors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);

alter table public.guide_data enable row level security;
alter table public.editors enable row level security;

drop policy if exists "Anyone can view the guide" on public.guide_data;
create policy "Anyone can view the guide"
on public.guide_data for select
to anon, authenticated
using (true);

drop policy if exists "Approved editors can update the guide" on public.guide_data;
create policy "Approved editors can update the guide"
on public.guide_data for update
to authenticated
using (exists (select 1 from public.editors e where e.user_id = auth.uid()))
with check (exists (select 1 from public.editors e where e.user_id = auth.uid()));

drop policy if exists "Editors can view their own editor status" on public.editors;
create policy "Editors can view their own editor status"
on public.editors for select
to authenticated
using (user_id = auth.uid());

grant select on public.guide_data to anon, authenticated;
grant update on public.guide_data to authenticated;
grant select on public.editors to authenticated;

-- After creating each officer account in Authentication > Users,
-- add their UUID with:
-- insert into public.editors (user_id) values ('PASTE-AUTH-USER-UUID-HERE');
