-- Fise School: teacher forum/private-message access is controlled by the teacher's unique code.
-- A student must explicitly join a teacher's classroom space with that code.
-- Teachers keep access to their assigned classes without entering a code.

create table if not exists public.teacher_access_memberships (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.school_classes(id) on delete cascade,
  access_code_id text not null references public.teacher_access_codes(id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique(student_id, teacher_id, class_id)
);

create index if not exists teacher_access_memberships_student_idx
  on public.teacher_access_memberships(student_id, class_id);
create index if not exists teacher_access_memberships_teacher_idx
  on public.teacher_access_memberships(teacher_id, class_id);

alter table public.teacher_access_memberships enable row level security;

drop policy if exists "students read own teacher access memberships" on public.teacher_access_memberships;
create policy "students read own teacher access memberships"
on public.teacher_access_memberships
for select to authenticated
using (
  student_id = auth.uid()
  or teacher_id = auth.uid()
  or public.is_catalog_admin()
);

create or replace function public.has_teacher_access(
  p_student_id uuid,
  p_teacher_id uuid,
  p_class_id uuid
)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    public.is_catalog_admin()
    or (
      p_student_id = auth.uid()
      and exists (
        select 1
        from public.class_teachers ct
        where ct.teacher_id = p_teacher_id
          and ct.class_id = p_class_id
          and ct.is_active = true
      )
    )
    or exists (
      select 1
      from public.teacher_access_memberships m
      where m.student_id = p_student_id
        and m.teacher_id = p_teacher_id
        and m.class_id = p_class_id
    );
$$;

revoke all on function public.has_teacher_access(uuid, uuid, uuid) from public;
grant execute on function public.has_teacher_access(uuid, uuid, uuid) to authenticated;

-- Student enters the teacher's code once. The membership is then persistent.
create or replace function public.join_teacher_access_code(p_code text)
returns table (
  teacher_id uuid,
  class_id uuid,
  access_code_id text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_code text;
  v_teacher uuid;
  v_class uuid;
  v_code_id text;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_user and role = 'student'
  ) then
    raise exception 'Only students can join a teacher space';
  end if;

  v_code := trim(p_code);
  if lower(v_code) like 'fise%' then
    v_code := substring(v_code from 5);
  end if;

  select t.id, t.teacher_id, t.class_id
    into v_code_id, v_teacher, v_class
  from public.teacher_access_codes t
  where lower(trim(t.code)) = lower(trim(v_code))
    and t.is_active = true
  limit 1;

  if v_code_id is null then
    raise exception 'Invalid teacher access code';
  end if;

  if not public.is_student_in_class(v_class, v_user) then
    raise exception 'Student is not assigned to this classroom';
  end if;

  insert into public.teacher_access_memberships(
    student_id, teacher_id, class_id, access_code_id
  )
  values (v_user, v_teacher, v_class, v_code_id)
  on conflict (student_id, teacher_id, class_id)
  do update set access_code_id = excluded.access_code_id;

  return query
    select v_teacher, v_class, v_code_id;
end;
$$;

revoke all on function public.join_teacher_access_code(text) from public;
grant execute on function public.join_teacher_access_code(text) to authenticated;

-- Forum visibility: students see a teacher's forum only after joining that teacher
-- with the teacher's code. Teachers/admins keep their normal management access.
drop policy if exists "forum topics members read" on public.forum_topics;
create policy "forum topics members read"
on public.forum_topics
for select to authenticated
using (
  public.is_admin()
  or public.teacher_can_manage_class(class_id, auth.uid())
  or exists (
    select 1
    from public.teacher_access_memberships m
    where m.student_id = auth.uid()
      and m.class_id = forum_topics.class_id
      and m.teacher_id = forum_topics.creator_id
  )
);

drop policy if exists "forum posts members read" on public.forum_posts;
create policy "forum posts members read"
on public.forum_posts
for select to authenticated
using (
  exists (
    select 1
    from public.forum_topics t
    where t.id = forum_posts.topic_id
      and (
        public.is_admin()
        or public.teacher_can_manage_class(t.class_id, auth.uid())
        or exists (
          select 1
          from public.teacher_access_memberships m
          where m.student_id = auth.uid()
            and m.class_id = t.class_id
            and m.teacher_id = t.creator_id
        )
      )
  )
);

drop policy if exists "forum posts members create" on public.forum_posts;
create policy "forum posts members create"
on public.forum_posts
for insert to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1
    from public.forum_topics t
    where t.id = forum_posts.topic_id
      and (
        public.is_admin()
        or public.teacher_can_manage_class(t.class_id, auth.uid())
        or exists (
          select 1
          from public.teacher_access_memberships m
          where m.student_id = auth.uid()
            and m.class_id = t.class_id
            and m.teacher_id = t.creator_id
        )
      )
      and (
        not t.is_locked
        or public.is_admin()
        or public.teacher_can_manage_class(t.class_id, auth.uid())
      )
  )
);

-- Private messaging is also limited to a teacher/student pair that has
-- an active teacher-code membership.
create or replace function public.can_message(target_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    public.is_catalog_admin()
    or exists (
      select 1
      from public.teacher_access_memberships m
      where
        (
          m.student_id = auth.uid()
          and m.teacher_id = target_user_id
        )
        or (
          m.teacher_id = auth.uid()
          and m.student_id = target_user_id
        )
    )
    or exists (
      select 1
      from public.class_students cs
      join public.class_teachers ct on ct.class_id = cs.class_id
      where cs.is_active and ct.is_active
        and (
          (cs.student_id = auth.uid() and ct.teacher_id = target_user_id
           and public.teacher_can_manage_class(cs.class_id, target_user_id))
          or
          (ct.teacher_id = auth.uid() and cs.student_id = target_user_id
           and public.teacher_can_manage_class(cs.class_id, auth.uid()))
        )
    );
$$;

revoke all on function public.can_message(uuid) from public;
grant execute on function public.can_message(uuid) to authenticated;

create or replace function public.list_private_message_contacts()
returns table (id uuid, first_name text, last_name text, role text, class_name text)
language sql stable security definer set search_path = public
as $$
  select distinct on (p.id)
    p.id, p.first_name, p.last_name, p.role, c.display_name as class_name
  from public.teacher_access_memberships m
  join public.school_classes c on c.id = m.class_id
  join public.profiles p
    on p.id = case
      when m.student_id = auth.uid() then m.teacher_id
      else m.student_id
    end
  where m.student_id = auth.uid()
     or m.teacher_id = auth.uid()
  order by p.id, c.display_name;
$$;

create or replace function public.list_private_messages(target_user_id uuid)
returns setof public.private_messages
language sql stable security definer set search_path = public
as $$
  select m.*
  from public.private_messages m
  where public.can_message(target_user_id)
    and (
      (m.sender_id = auth.uid() and m.recipient_id = target_user_id)
      or (m.sender_id = target_user_id and m.recipient_id = auth.uid())
    )
  order by m.created_at;
$$;

revoke all on function public.list_private_message_contacts() from public;
revoke all on function public.list_private_messages(uuid) from public;
grant execute on function public.list_private_message_contacts() to authenticated;
grant execute on function public.list_private_messages(uuid) to authenticated;
