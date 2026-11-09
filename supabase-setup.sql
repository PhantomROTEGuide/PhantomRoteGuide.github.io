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


-- Allow community contributors to update team recommendations (including TB Omicron selections)
-- while keeping officer-managed mission settings protected.
create or replace function public.save_public_recommendations(
  p_data jsonb,
  p_expected_updated_at timestamptz
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $
declare
  v_existing jsonb;
  v_merged jsonb;
  v_updated_at timestamptz;
  v_planet_key text;
  v_old_missions jsonb;
  v_new_missions jsonb;
  v_missions jsonb;
  v_i integer;
  v_old_mission jsonb;
  v_new_mission jsonb;
begin
  select data, updated_at
    into v_existing, v_updated_at
    from public.guide_data
    where id = 1
    for update;

  if not found then
    raise exception 'Shared guide row is missing.';
  end if;

  if p_expected_updated_at is distinct from v_updated_at then
    raise exception 'stale guide data; refresh and try again.';
  end if;

  v_merged := coalesce(v_existing, '{}'::jsonb);

  for v_planet_key in
    select key from jsonb_each(coalesce(p_data, '{}'::jsonb))
  loop
    v_old_missions := v_existing -> v_planet_key;
    v_new_missions := p_data -> v_planet_key;

    if jsonb_typeof(v_old_missions) = 'array'
       and jsonb_typeof(v_new_missions) = 'array' then
      v_missions := v_old_missions;

      for v_i in 0 .. jsonb_array_length(v_old_missions) - 1 loop
        if v_i < jsonb_array_length(v_new_missions) then
          v_old_mission := v_old_missions -> v_i;
          v_new_mission := v_new_missions -> v_i;

          if jsonb_typeof(v_old_mission) = 'object'
             and jsonb_typeof(v_new_mission) = 'object'
             and jsonb_typeof(v_new_mission -> 'recommendations') = 'array' then
            v_old_mission := jsonb_set(
              v_old_mission,
              '{recommendations}',
              v_new_mission -> 'recommendations',
              true
            );
            v_missions := jsonb_set(
              v_missions,
              array[v_i::text],
              v_old_mission,
              false
            );
          end if;
        end if;
      end loop;

      v_merged := jsonb_set(v_merged, array[v_planet_key], v_missions, true);
    end if;
  end loop;

  update public.guide_data
     set data = v_merged,
         updated_at = clock_timestamp()
   where id = 1
   returning updated_at into v_updated_at;

  return v_updated_at;
end;
$;

revoke all on function public.save_public_recommendations(jsonb, timestamptz) from public;
grant execute on function public.save_public_recommendations(jsonb, timestamptz) to anon, authenticated;

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
