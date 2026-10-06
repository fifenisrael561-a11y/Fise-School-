-- Fise School — séparation des parcours Form 5 anglophones
-- Science / Arts + affectation automatique sûre des élèves.
--
-- Référence GCE Board :
-- https://camgceb.org/examinations/gce-ordinary-level/
--
-- Le GCE Board confirme que l'Ordinary Level termine normalement la Form 5
-- et que English Language, French et Mathematics sont les matières communes
-- obligatoires à l'inscription. Les autres matières sont choisies selon le
-- parcours et les matières présentées.

-- ============================================================
-- 1. Form 5 général anglophone : deux parcours explicites
-- ============================================================

insert into public.series (code, name_fr, name_en, verification_status, source_url)
values
  ('gce_science', 'Science', 'Science', 'verified',
   'https://camgceb.org/examinations/gce-ordinary-level/'),
  ('gce_arts', 'Arts', 'Arts', 'verified',
   'https://camgceb.org/examinations/gce-ordinary-level/')
on conflict (code) do update set
  name_fr = excluded.name_fr,
  name_en = excluded.name_en,
  verification_status = 'verified',
  source_url = excluded.source_url,
  active = true,
  updated_at = now();

insert into public.exam_level_series (exam_level_id, series_id, verification_status, active)
select el.id, s.id, 'verified', true
from public.exam_levels el
join public.series s on s.code in ('gce_science', 'gce_arts')
where el.code = 'en_general_form_5'
on conflict (exam_level_id, series_id) do update set
  verification_status = 'verified',
  active = true;

-- La Form 5 générique ne doit plus être utilisée pour l'affectation :
-- les élèves doivent choisir Science ou Arts.
update public.school_classes
set is_active = false, updated_at = now()
where name = 'en_general_form_5';

-- Créer les deux salles/parcours 2026-2027.
insert into public.school_classes
  (name, display_name, subsystem, sector, academic_year_id,
   exam_level_id, series_id, specialty_id, is_active)
select
  v.class_name,
  v.display_name,
  'anglophone',
  'general',
  ay.id,
  el.id,
  s.id,
  null,
  true
from (
  values
    ('en_general_form_5_science', 'Form 5 Science', 'gce_science'),
    ('en_general_form_5_arts', 'Form 5 Arts', 'gce_arts')
) as v(class_name, display_name, series_code)
cross join lateral (
  select id from public.academic_years
  where label = '2026-2027' and is_current
  order by created_at desc
  limit 1
) ay
join public.exam_levels el on el.code = 'en_general_form_5'
join public.series s on s.code = v.series_code
on conflict (name, academic_year_id) do update set
  display_name = excluded.display_name,
  subsystem = excluded.subsystem,
  sector = excluded.sector,
  exam_level_id = excluded.exam_level_id,
  series_id = excluded.series_id,
  specialty_id = null,
  is_active = true,
  updated_at = now();

-- ============================================================
-- 2. Matières réellement visibles dans chaque parcours Form 5
-- ============================================================
-- Communes aux deux parcours : English, French, Mathematics.
-- Science : Biology, Chemistry, Physics, Computer Science, Geology.
-- Arts : Literature, History, Geography, Economics, Religious Studies, Logic.
-- Les matières restent des données de class_subjects : l'enseignant/admin
-- conserve ensuite la possibilité d'ajuster la salle.

do $$
declare
  science_class uuid;
  arts_class uuid;
begin
  select id into science_class
  from public.school_classes
  where name = 'en_general_form_5_science'
    and academic_year_id = (
      select id from public.academic_years
      where label = '2026-2027' and is_current
      order by created_at desc limit 1
    )
  limit 1;

  select id into arts_class
  from public.school_classes
  where name = 'en_general_form_5_arts'
    and academic_year_id = (
      select id from public.academic_years
      where label = '2026-2027' and is_current
      order by created_at desc limit 1
    )
  limit 1;

  if science_class is not null then
    update public.class_subjects cs
    set is_active = false
    where cs.class_id = science_class;

    insert into public.class_subjects
      (class_id, subject_id, is_compulsory, option_group, position, is_active)
    select science_class, s.id, true, null, v.position, true
    from (
      values
        ('english_language', 0),
        ('french_language', 1),
        ('mathematics_en', 2),
        ('biology_en', 3),
        ('chemistry_en', 4),
        ('physics_en', 5),
        ('computer_science_en', 6),
        ('geology', 7)
    ) v(subject_code, position)
    join public.subjects s on s.code = v.subject_code and s.is_active
    on conflict (class_id, subject_id) do update set
      is_compulsory = excluded.is_compulsory,
      option_group = excluded.option_group,
      position = excluded.position,
      is_active = true;
  end if;

  if arts_class is not null then
    update public.class_subjects cs
    set is_active = false
    where cs.class_id = arts_class;

    insert into public.class_subjects
      (class_id, subject_id, is_compulsory, option_group, position, is_active)
    select arts_class, s.id, true, null, v.position, true
    from (
      values
        ('english_language', 0),
        ('french_language', 1),
        ('mathematics_en', 2),
        ('literature_in_english', 3),
        ('history_en', 4),
        ('geography_en', 5),
        ('economics', 6),
        ('religious_studies', 7),
        ('logic', 8)
    ) v(subject_code, position)
    join public.subjects s on s.code = v.subject_code and s.is_active
    on conflict (class_id, subject_id) do update set
      is_compulsory = excluded.is_compulsory,
      option_group = excluded.option_group,
      position = excluded.position,
      is_active = true;
  end if;
end;
$$;

-- ============================================================
-- 3. Affectation automatique : éviter ON CONFLICT sur un index partiel
-- ============================================================
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

  if matching_count <> 1 then
    return;
  end if;

  update public.class_students
  set is_active = false
  where student_id = p.id
    and is_active = true
    and class_id <> matching_class_id;

  update public.class_students
  set is_active = true
  where class_id = matching_class_id
    and student_id = p.id;

  if not found then
    insert into public.class_students
      (class_id, student_id, joined_at, is_active)
    values
      (matching_class_id, p.id, now(), true);
  end if;
end;
$$;

revoke all on function public.auto_assign_student_to_matching_class(uuid) from public;

-- Rejouer le catalogue des deux salles Form 5 pour garantir leur état
-- après une nouvelle exécution du catalogue.
do $$
declare
  r record;
begin
  for r in
    select id
    from public.school_classes
    where is_active
      and name in ('en_general_form_5_science', 'en_general_form_5_arts')
  loop
    perform public.apply_base_subjects_to_class(r.id);
  end loop;
end;
$$;
