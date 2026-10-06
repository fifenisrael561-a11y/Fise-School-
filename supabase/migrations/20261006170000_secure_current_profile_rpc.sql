-- Read the signed-in user's own profile through a small, tightly-scoped RPC.
-- This keeps profile loading reliable even if public.profiles RLS policies change.

create or replace function public.get_my_profile()
returns setof public.profiles
language sql
stable
security definer
set search_path = ''
as $$
  select p.*
  from public.profiles as p
  where p.id = (select auth.uid())
  limit 1;
$$;

revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;
