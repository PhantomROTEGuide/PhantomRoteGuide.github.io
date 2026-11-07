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


-- Shared squad image storage
-- Public read access lets every guild member see recommendation images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'team-recommendations',
  'team-recommendations',
  true,
  8388608,
  array['image/jpeg','image/png','image/webp','image/gif']
)
on conflict (id) do update
set public = true,
    file_size_limit = 8388608,
    allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "Anyone can view squad recommendation images" on storage.objects;
create policy "Anyone can view squad recommendation images"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'team-recommendations');

drop policy if exists "Approved editors can upload squad recommendation images" on storage.objects;
create policy "Approved editors can upload squad recommendation images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'team-recommendations'
  and exists (select 1 from public.editors e where e.user_id = auth.uid())
);

drop policy if exists "Approved editors can update squad recommendation images" on storage.objects;
create policy "Approved editors can update squad recommendation images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'team-recommendations'
  and exists (select 1 from public.editors e where e.user_id = auth.uid())
)
with check (
  bucket_id = 'team-recommendations'
  and exists (select 1 from public.editors e where e.user_id = auth.uid())
);

drop policy if exists "Approved editors can delete squad recommendation images" on storage.objects;
create policy "Approved editors can delete squad recommendation images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'team-recommendations'
  and exists (select 1 from public.editors e where e.user_id = auth.uid())
);
