-- Fise School — rattachement automatique des élèves à leur salle.
--
-- Le profil d'inscription porte le niveau, le sous-système, le secteur et,
-- lorsque nécessaire, la série/spécialité. Cette migration transforme ces
-- informations en appartenance réelle à class_students.
--
-- Règle sûre : une seule salle active peut être auto-sélectionnée. Si plusieurs
-- salles correspondent exactement au même parcours, aucune salle arbitraire
-- n'est choisie : l'administration doit affecter l'élève.

create or replace function public.auto_assign_student_to_matching_class(
  p_student_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  p public.profiles%rowtype;
  current_year_id uuid;
  matching_class_id uuid;
  matching_count integer;
begin
  select *
    into p
  from public.profiles
  where id = p_student_id
    and role = 'student';

  if not found or p.exam_level_id is null
     or p.subsystem is null or p.sector is null then
    return;
  end if;

  select id
    into current_year_id
  from public.academic_years
  where is_current
  order by created_at desc
  limit 1;

  if current_year_id is null then
    return;
  end if;

  select count(*), min(sc.id)
    into matching_count, matching_class_id
  from public.school_classes sc
  where sc.is_active
    and sc.academic_year_id = current_year_id
    and sc.exam_level_id = p.exam_level_id
    and sc.subsystem = p.subsystem
    and sc.sector = p.sector
    and (
      (p.sector = 'general'
       and sc.series_id is not distinct from p.series_id
       and sc.specialty_id is null)
      or
      (p.sector = 'technical'
       and sc.specialty_id is not distinct from p.specialty_id
       and sc.series_id is null)
    );

  -- Plusieurs salles identiques : aucune affectation automatique arbitraire.
  if matching_count <> 1 then
    return;
  end if;

  -- Un élève ne garde qu'une appartenance active à la fois.
  update public.class_students
  set is_active = false
  where student_id = p.id
    and is_active = true
    and class_id <> matching_class_id;

  insert into public.class_students (class_id, student_id, joined_at, is_active)
  values (matching_class_id, p.id, now(), true)
  on conflict (class_id, student_id)
  do update set is_active = true;
end;
$$;

revoke all on function public.auto_assign_student_to_matching_class(uuid) from public;

create or replace function public.trg_auto_assign_student_class()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.auto_assign_student_to_matching_class(new.id);
  return new;
end;
$$;

drop trigger if exists profiles_auto_assign_matching_class on public.profiles;
create trigger profiles_auto_assign_matching_class
after insert or update of exam_level_id, series_id, specialty_id, subsystem, sector
on public.profiles
for each row
when (new.role = 'student')
execute function public.trg_auto_assign_student_class();

-- Une salle peut être créée après l'inscription. Dans ce cas, on retente
-- automatiquement l'affectation des élèves dont le parcours correspond.
create or replace function public.trg_auto_assign_students_for_class()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  student_id uuid;
begin
  if not new.is_active
     or new.academic_year_id is null
     or new.exam_level_id is null
     or new.subsystem is null
     or new.sector is null then
    return new;
  end if;

  for student_id in
    select p.id
    from public.profiles p
    where p.role = 'student'
      and p.exam_level_id = new.exam_level_id
      and p.subsystem = new.subsystem
      and p.sector = new.sector
      and (
        (new.sector = 'general'
         and p.series_id is not distinct from new.series_id
         and p.specialty_id is null)
        or
        (new.sector = 'technical'
         and p.specialty_id is not distinct from new.specialty_id
         and p.series_id is null)
      )
  loop
    perform public.auto_assign_student_to_matching_class(student_id);
  end loop;

  return new;
end;
$$;

revoke all on function public.trg_auto_assign_students_for_class() from public;

drop trigger if exists school_classes_auto_assign_matching_students on public.school_classes;
create trigger school_classes_auto_assign_matching_students
after insert or update of is_active, academic_year_id, exam_level_id, series_id, specialty_id, subsystem, sector
on public.school_classes
for each row
execute function public.trg_auto_assign_students_for_class();

-- Rattrapage des élèves déjà inscrits : seulement lorsqu'une seule salle
-- correspond exactement à leur parcours pour l'année scolaire courante.
do $$
declare
  p record;
begin
  for p in
    select id
    from public.profiles
    where role = 'student'
      and exam_level_id is not null
  loop
    perform public.auto_assign_student_to_matching_class(p.id);
  end loop;
end;
$$;
