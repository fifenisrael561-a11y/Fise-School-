-- Fise School auth/profile repair.
grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  requested_role text := metadata ->> 'role';
  requested_subsystem text := metadata ->> 'subsystem';
  requested_sector text := metadata ->> 'sector';
  profile_email text := coalesce(new.email, nullif(trim(metadata ->> 'email'), ''));
  uuid_pattern constant text :=
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';
begin
  insert into public.profiles (
    id, first_name, last_name, email, role, preferred_language,
    subsystem, sector, exam_level_id, exam_id, series_id, specialty_id,
    class_name, exam_level_label, exam_label, track_label
  )
  values (
    new.id,
    coalesce(nullif(trim(metadata ->> 'first_name'), ''),
             nullif(split_part(coalesce(profile_email, ''), '@', 1), ''),
             'Utilisateur'),
    coalesce(nullif(trim(metadata ->> 'last_name'), ''), 'Fise'),
    profile_email,
    case when requested_role in ('student', 'teacher') then requested_role else 'student' end,
    case when metadata ->> 'preferred_language' in ('fr', 'en')
      then metadata ->> 'preferred_language' else 'fr' end,
    case when requested_subsystem in ('francophone', 'anglophone')
      then requested_subsystem::public.catalog_subsystem else null end,
    case when requested_sector in ('general', 'technical')
      then requested_sector::public.catalog_sector else null end,
    case when metadata ->> 'exam_level_id' ~ uuid_pattern
      then (metadata ->> 'exam_level_id')::uuid else null end,
    case when metadata ->> 'exam_id' ~ uuid_pattern
      then (metadata ->> 'exam_id')::uuid else null end,
    case when metadata ->> 'series_id' ~ uuid_pattern
      then (metadata ->> 'series_id')::uuid else null end,
    case when metadata ->> 'specialty_id' ~ uuid_pattern
      then (metadata ->> 'specialty_id')::uuid else null end,
    nullif(trim(metadata ->> 'class_name'), ''),
    nullif(trim(metadata ->> 'exam_level'), ''),
    nullif(trim(metadata ->> 'exam'), ''),
    nullif(trim(metadata ->> 'track'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

insert into public.profiles (
  id, first_name, last_name, email, role, preferred_language,
  subsystem, sector, exam_level_id, exam_id, series_id, specialty_id,
  class_name, exam_level_label, exam_label, track_label
)
select
  u.id,
  coalesce(nullif(trim(u.raw_user_meta_data ->> 'first_name'), ''),
           nullif(split_part(coalesce(u.email, ''), '@', 1), ''), 'Utilisateur'),
  coalesce(nullif(trim(u.raw_user_meta_data ->> 'last_name'), ''), 'Fise'),
  u.email,
  case
    when u.raw_app_meta_data ->> 'role' = 'admin' then 'admin'
    when u.raw_user_meta_data ->> 'role' in ('student', 'teacher')
      then u.raw_user_meta_data ->> 'role'
    else 'student'
  end,
  case when u.raw_user_meta_data ->> 'preferred_language' in ('fr', 'en')
    then u.raw_user_meta_data ->> 'preferred_language' else 'fr' end,
  case when u.raw_user_meta_data ->> 'subsystem' in ('francophone', 'anglophone')
    then (u.raw_user_meta_data ->> 'subsystem')::public.catalog_subsystem else null end,
  case when u.raw_user_meta_data ->> 'sector' in ('general', 'technical')
    then (u.raw_user_meta_data ->> 'sector')::public.catalog_sector else null end,
  case when u.raw_user_meta_data ->> 'exam_level_id' ~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    then (u.raw_user_meta_data ->> 'exam_level_id')::uuid else null end,
  case when u.raw_user_meta_data ->> 'exam_id' ~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    then (u.raw_user_meta_data ->> 'exam_id')::uuid else null end,
  case when u.raw_user_meta_data ->> 'series_id' ~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    then (u.raw_user_meta_data ->> 'series_id')::uuid else null end,
  case when u.raw_user_meta_data ->> 'specialty_id' ~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    then (u.raw_user_meta_data ->> 'specialty_id')::uuid else null end,
  nullif(trim(u.raw_user_meta_data ->> 'class_name'), ''),
  nullif(trim(u.raw_user_meta_data ->> 'exam_level'), ''),
  nullif(trim(u.raw_user_meta_data ->> 'exam'), ''),
  nullif(trim(u.raw_user_meta_data ->> 'track'), '')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;