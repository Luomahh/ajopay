-- Compared with the remote public schema on 2026-09-24:
-- profiles (RLS enabled), three own-profile policies, handle_new_user().
-- This additive migration does not alter profiles or authentication triggers.
begin;

create table public.savings_groups (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id),
  request_id text not null check (request_id ~ '^[0-9a-f]{32}$'),
  name text not null check (char_length(btrim(name)) between 3 and 80),
  currency text not null default 'NGN' check (currency = 'NGN'),
  contribution_kobo bigint not null check (contribution_kobo between 100 and 100000000),
  member_limit integer not null check (member_limit between 2 and 50),
  first_payout_date date not null,
  status text not null default 'draft' check (status in ('draft', 'active', 'completed')),
  created_at timestamptz not null default now(),
  unique (created_by, request_id)
);

create table public.group_members (
  group_id uuid not null references public.savings_groups(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members(user_id, group_id);
create unique index group_members_one_owner_idx on public.group_members(group_id) where role = 'owner';

create table public.group_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.savings_groups(id),
  actor_id uuid not null references auth.users(id),
  action text not null,
  created_at timestamptz not null default now()
);

alter table public.savings_groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_events enable row level security;

-- Default Supabase grants must not permit direct client mutations.
revoke all on public.savings_groups, public.group_members, public.group_events from public, anon, authenticated;
grant select on public.savings_groups, public.group_members to authenticated;

create policy read_own_membership on public.group_members
  for select to authenticated using (user_id = (select auth.uid()));

create policy read_member_groups on public.savings_groups
  for select to authenticated using (
    exists (select 1 from public.group_members m
      where m.group_id = savings_groups.id and m.user_id = (select auth.uid()))
  );

create function public.create_savings_group(
  p_request_id text,
  p_name text,
  p_contribution_kobo bigint,
  p_member_limit integer,
  p_first_payout_date date
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  created public.savings_groups;
begin
  if caller is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_request_id is null or p_request_id !~ '^[0-9a-f]{32}$'
    or p_name is null or char_length(btrim(p_name)) not between 3 and 80
    or p_contribution_kobo is null or p_contribution_kobo not between 100 and 100000000
    or p_member_limit is null or p_member_limit not between 2 and 50
    or p_first_payout_date is null then
    raise exception 'Invalid group terms' using errcode = '22023';
  end if;

  -- Serialize retries by caller and request, including concurrent submissions.
  perform pg_advisory_xact_lock(hashtextextended(caller::text || ':' || p_request_id, 0));
  select * into created from public.savings_groups
    where created_by = caller and request_id = p_request_id;
  if found then
    if created.name <> btrim(p_name)
      or created.contribution_kobo <> p_contribution_kobo
      or created.member_limit <> p_member_limit
      or created.first_payout_date <> p_first_payout_date then
      raise exception 'Request already used with different terms' using errcode = '23505';
    end if;
    return to_jsonb(created);
  end if;

  -- Accept today in UTC to accommodate a future local calendar date.
  if p_first_payout_date < (now() at time zone 'UTC')::date then
    raise exception 'First payout date is in the past' using errcode = '22023';
  end if;
  insert into public.savings_groups
    (created_by, request_id, name, contribution_kobo, member_limit, first_payout_date)
    values (caller, p_request_id, btrim(p_name), p_contribution_kobo, p_member_limit, p_first_payout_date)
    returning * into created;
  insert into public.group_members (group_id, user_id, role)
    values (created.id, caller, 'owner');
  insert into public.group_events (group_id, actor_id, action)
    values (created.id, caller, 'group_created');
  return to_jsonb(created);
end;
$$;

revoke all on function public.create_savings_group(text, text, bigint, integer, date) from public, anon;
grant execute on function public.create_savings_group(text, text, bigint, integer, date) to authenticated;

notify pgrst, 'reload schema';
commit;
