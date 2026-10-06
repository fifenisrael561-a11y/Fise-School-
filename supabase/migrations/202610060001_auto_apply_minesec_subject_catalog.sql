-- Fise School — application automatique du catalogue MINESEC/GCE
-- à toutes les salles actives, y compris les nouvelles salles.
--
-- Référence pédagogique : page officielle MINESEC « Programmes d'études »,
-- qui distingue les sous-systèmes francophone/anglophone et les secteurs
-- général/technique-professionnel.

create or replace function public.auto_apply_minesec_subject_catalog()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_base_subjects_to_class(new.id);
  return new;
end;
$$;

revoke all on function public.auto_apply_minesec_subject_catalog() from public;

drop trigger if exists trg_auto_apply_minesec_subject_catalog
on public.school_classes;

create trigger trg_auto_apply_minesec_subject_catalog
after insert on public.school_classes
for each row
when (new.is_active = true)
execute function public.auto_apply_minesec_subject_catalog();

-- Rejouer le catalogue sur toutes les salles actuellement actives.
-- Cela ajoute les matières manquantes sans supprimer les réglages existants.
do $$
declare
  r record;
begin
  for r in
    select id
    from public.school_classes
    where is_active = true
  loop
    perform public.apply_base_subjects_to_class(r.id);
  end loop;
end;
$$;

-- Garantir que les salles existantes restent alignées avec leur niveau,
-- sous-système, secteur et série après toute nouvelle migration du catalogue.
