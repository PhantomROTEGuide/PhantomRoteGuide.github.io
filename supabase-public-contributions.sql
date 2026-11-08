-- Phantom RoTE Guide: allow anonymous visitors to contribute team recommendations safely.
-- Run this entire script once in Supabase SQL Editor.
-- This RPC permits edits only inside existing missions' recommendations arrays.
-- It does NOT permit public users to add/delete missions or change mission settings,
-- forced leaders/factions/ships, special-mission rules, or other guide metadata.

create or replace function public.save_public_recommendations(
  p_data jsonb,
  p_expected_updated_at timestamptz
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current jsonb;
  v_updated_at timestamptz;
  v_key text;
  v_old_missions jsonb;
  v_new_missions jsonb;
  v_old_mission jsonb;
  v_new_mission jsonb;
  v_old_recs jsonb;
  v_new_recs jsonb;
  v_old_rec jsonb;
  v_new_rec jsonb;
  v_i integer;
  v_j integer;
  v_old_count integer;
  v_new_count integer;
  v_allowed text[] := array['title','team','images','names','notes','omicrons','fullAuto','successRate'];
begin
  if jsonb_typeof(p_data) <> 'object' then
    raise exception 'Invalid guide data.';
  end if;

  select data, updated_at
    into v_current, v_updated_at
    from public.guide_data
   where id = 1
   for update;

  if not found then
    raise exception 'Guide data row was not found.';
  end if;

  if v_updated_at is distinct from p_expected_updated_at then
    raise exception 'stale guide data: refresh before saving.';
  end if;

  if jsonb_object_length(v_current) <> jsonb_object_length(p_data) then
    raise exception 'Public contributions cannot add or remove planets.';
  end if;

  for v_key in select jsonb_object_keys(v_current)
  loop
    if not (p_data ? v_key) then
      raise exception 'Public contributions cannot add or remove planets.';
    end if;

    v_old_missions := v_current -> v_key;
    v_new_missions := p_data -> v_key;

    if jsonb_typeof(v_old_missions) <> 'array'
       or jsonb_typeof(v_new_missions) <> 'array'
       or jsonb_array_length(v_old_missions) <> jsonb_array_length(v_new_missions) then
      raise exception 'Public contributions cannot add or remove missions.';
    end if;

    for v_i in 0 .. jsonb_array_length(v_old_missions) - 1
    loop
      v_old_mission := v_old_missions -> v_i;
      v_new_mission := v_new_missions -> v_i;

      if (v_old_mission - 'recommendations') <> (v_new_mission - 'recommendations') then
        raise exception 'Public contributions cannot change mission settings or restrictions.';
      end if;

      v_old_recs := case when jsonb_typeof(v_old_mission -> 'recommendations') = 'array'
                         then v_old_mission -> 'recommendations' else '[]'::jsonb end;
      v_new_recs := case when jsonb_typeof(v_new_mission -> 'recommendations') = 'array'
                         then v_new_mission -> 'recommendations' else '[]'::jsonb end;

      v_old_count := jsonb_array_length(v_old_recs);
      v_new_count := jsonb_array_length(v_new_recs);

      if v_new_count < v_old_count or v_new_count > v_old_count + 20 or v_new_count > 60 then
        raise exception 'Public contributions may add recommendations, but cannot delete them or add more than 20 at once.';
      end if;

      for v_j in 0 .. v_new_count - 1
      loop
        v_new_rec := v_new_recs -> v_j;
        if jsonb_typeof(v_new_rec) <> 'object' then
          raise exception 'Invalid team recommendation.';
        end if;

        if v_j < v_old_count then
          v_old_rec := v_old_recs -> v_j;
          if (v_old_rec - v_allowed) <> (v_new_rec - v_allowed) then
            raise exception 'Public contributions can only edit team recommendation fields.';
          end if;
        elsif (v_new_rec - v_allowed) <> '{}'::jsonb then
          raise exception 'New recommendations may contain only team recommendation fields.';
        end if;

        if v_new_rec ? 'title' and (jsonb_typeof(v_new_rec -> 'title') <> 'string' or length(v_new_rec ->> 'title') > 160) then
          raise exception 'Team titles must be text up to 160 characters.';
        end if;
        if v_new_rec ? 'team' and (jsonb_typeof(v_new_rec -> 'team') <> 'string' or length(v_new_rec ->> 'team') > 160) then
          raise exception 'Team names must be text up to 160 characters.';
        end if;
        if v_new_rec ? 'notes' and (jsonb_typeof(v_new_rec -> 'notes') <> 'string' or length(v_new_rec ->> 'notes') > 12000) then
          raise exception 'Strategy notes must be text up to 12,000 characters.';
        end if;

        if v_new_rec ? 'images' then
          if jsonb_typeof(v_new_rec -> 'images') <> 'array' or jsonb_array_length(v_new_rec -> 'images') > 8
             or exists (select 1 from jsonb_array_elements(v_new_rec -> 'images') x where jsonb_typeof(x) <> 'string' or length(x #>> '{}') > 2048) then
            raise exception 'Invalid team image list.';
          end if;
        end if;
        if v_new_rec ? 'names' then
          if jsonb_typeof(v_new_rec -> 'names') <> 'array' or jsonb_array_length(v_new_rec -> 'names') > 8
             or exists (select 1 from jsonb_array_elements(v_new_rec -> 'names') x where jsonb_typeof(x) <> 'string' or length(x #>> '{}') > 160) then
            raise exception 'Invalid team character or ship list.';
          end if;
        end if;
        if v_new_rec ? 'omicrons' then
          if jsonb_typeof(v_new_rec -> 'omicrons') <> 'array' or jsonb_array_length(v_new_rec -> 'omicrons') > 8
             or exists (select 1 from jsonb_array_elements(v_new_rec -> 'omicrons') x where jsonb_typeof(x) <> 'boolean') then
            raise exception 'Invalid Omicron markers.';
          end if;
        end if;
        if v_new_rec ? 'fullAuto' and v_new_rec ->> 'fullAuto' not in ('yes','no','sometimes') then
          raise exception 'Invalid full-auto selection.';
        end if;
        if v_new_rec ? 'successRate' and v_new_rec ->> 'successRate' not in ('high','medium','low','hailmary') then
          raise exception 'Invalid success-rate selection.';
        end if;
      end loop;
    end loop;
  end loop;

  update public.guide_data
     set data = p_data,
         updated_at = clock_timestamp()
   where id = 1
   returning updated_at into v_updated_at;

  return v_updated_at;
end;
$$;

revoke all on function public.save_public_recommendations(jsonb, timestamptz) from public;
grant execute on function public.save_public_recommendations(jsonb, timestamptz) to anon, authenticated;
