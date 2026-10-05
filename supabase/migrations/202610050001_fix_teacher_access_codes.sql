-- Fix teacher access-code security and class typing.

alter table public.teacher_access_codes
  alter column class_id type uuid
  using class_id::uuid;

alter table public.teacher_access_codes
  drop constraint if exists teacher_access_codes_class_id_fkey;

alter table public.teacher_access_codes
  add constraint teacher_access_codes_class_id_fkey
  foreign key (class_id)
  references public.school_classes(id)
  on delete cascade;

alter table public.teacher_access_codes
  enable row level security;

drop policy if exists "teachers_read_own_access_codes"
  on public.teacher_access_codes;

create policy "teachers_read_own_access_codes"
on public.teacher_access_codes
for select
to authenticated
using (
  public.is_admin()
  or teacher_id = auth.uid()
);

drop policy if exists "teachers_insert_own_access_codes"
  on public.teacher_access_codes;

create policy "teachers_insert_own_access_codes"
on public.teacher_access_codes
for insert
to authenticated
with check (
  public.is_admin()
  or (
    teacher_id = auth.uid()
    and public.teacher_can_manage_class(class_id, auth.uid())
  )
);

drop policy if exists "teachers_update_own_access_codes"
  on public.teacher_access_codes;

create policy "teachers_update_own_access_codes"
on public.teacher_access_codes
for update
to authenticated
using (
  public.is_admin()
  or (
    teacher_id = auth.uid()
    and public.teacher_can_manage_class(class_id, auth.uid())
  )
)
with check (
  public.is_admin()
  or (
    teacher_id = auth.uid()
    and public.teacher_can_manage_class(class_id, auth.uid())
  )
);

drop policy if exists "teachers_delete_own_access_codes"
  on public.teacher_access_codes;

create policy "teachers_delete_own_access_codes"
on public.teacher_access_codes
for delete
to authenticated
using (
  public.is_admin()
  or (
    teacher_id = auth.uid()
    and public.teacher_can_manage_class(class_id, auth.uid())
  )
);

-- Students verify a code through a boolean RPC instead of reading the
-- teacher_access_codes table directly.
create or replace function public.validate_teacher_access_code(
  p_code text,
  p_class_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teacher_access_codes t
    where lower(t.code) = lower(
      case
        when lower(trim(p_code)) like 'fise%'
          then substring(trim(p_code) from 5)
        else trim(p_code)
      end
    )
    and t.class_id = p_class_id
    and t.is_active
    and (
      public.is_admin()
      or public.is_teacher_assigned(p_class_id, auth.uid())
      or public.is_student_in_class(p_class_id, auth.uid())
    )
  );
$$;

revoke all
on function public.validate_teacher_access_code(text, uuid)
from public;

grant execute
on function public.validate_teacher_access_code(text, uuid)
to authenticated;
