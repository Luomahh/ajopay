begin;
alter table public.savings_groups
  add column savings_mode text not null default 'rotating' check (savings_mode in ('rotating', 'target')),
  add column frequency text not null default 'monthly' check (frequency in ('daily', 'weekly', 'monthly')),
  add column end_date date,
  add column invite_code text not null default replace(gen_random_uuid()::text, '-', '') unique,
  add constraint valid_target_dates check ((savings_mode = 'rotating' and end_date is null) or (savings_mode = 'target' and end_date is not null and end_date > first_payout_date));
create function public.create_savings_group_v2(
  p_request_id text,
  p_name text,
  p_contribution_kobo bigint,
  p_member_limit integer,
  p_first_payout_date date,
  p_savings_mode text,
  p_frequency text,
  p_end_date date
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
    or p_first_payout_date is null
    or p_savings_mode is null or p_savings_mode not in ('rotating', 'target')
    or p_frequency is null or p_frequency not in ('daily', 'weekly', 'monthly')
    or (p_savings_mode = 'target' and (p_end_date is null or p_end_date <= p_first_payout_date or p_end_date > current_date + interval '2 years'))
    or (p_savings_mode = 'rotating' and p_end_date is not null) then
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
      or created.first_payout_date <> p_first_payout_date
      or created.savings_mode <> p_savings_mode or created.frequency <> p_frequency
      or created.end_date is distinct from p_end_date then
      raise exception 'Request already used with different terms' using errcode = '23505';
    end if;
    return to_jsonb(created);
  end if;

  -- Accept today in UTC to accommodate a future local calendar date.
  if p_first_payout_date < (now() at time zone 'UTC')::date then
    raise exception 'First payout date is in the past' using errcode = '22023';
  end if;
  insert into public.savings_groups
    (created_by, request_id, name, contribution_kobo, member_limit, first_payout_date, savings_mode, frequency, end_date)
    values (caller, p_request_id, btrim(p_name), p_contribution_kobo, p_member_limit, p_first_payout_date, p_savings_mode, p_frequency, p_end_date)
    returning * into created;
  insert into public.group_members (group_id, user_id, role)
    values (created.id, caller, 'owner');
  insert into public.group_events (group_id, actor_id, action)
    values (created.id, caller, 'group_created');
  return to_jsonb(created);
end;
$$;

revoke all on function public.create_savings_group_v2(text, text, bigint, integer, date, text, text, date) from public, anon;
grant execute on function public.create_savings_group_v2(text, text, bigint, integer, date, text, text, date) to authenticated;

create function public.join_savings_group(p_invite_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare caller uuid := auth.uid(); target public.savings_groups;
begin
  if caller is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_invite_code is null or p_invite_code !~ '^[0-9a-f]{32}$' then raise exception 'Invalid invite' using errcode = '22023'; end if;
  select * into target from public.savings_groups where invite_code = p_invite_code for update;
  if not found then raise exception 'Invalid invite' using errcode = '22023'; end if;
  if exists (select 1 from public.group_members where group_id = target.id and user_id = caller) then return to_jsonb(target); end if;
  if target.status <> 'draft' or (select count(*) from public.group_members where group_id = target.id) >= target.member_limit then
    raise exception 'Group is full or no longer accepting members' using errcode = '22023';
  end if;
  insert into public.group_members(group_id,user_id,role) values(target.id,caller,'member');
  insert into public.group_events(group_id,actor_id,action) values(target.id,caller,'member_joined');
  return to_jsonb(target);
end;
$$;
revoke all on function public.join_savings_group(text) from public, anon;
grant execute on function public.join_savings_group(text) to authenticated;
notify pgrst, 'reload schema';
commit;
