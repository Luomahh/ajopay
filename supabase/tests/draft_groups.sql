-- Run as postgres AFTER the migration. Fixtures and writes are rolled back.
-- A failed assertion aborts the transaction; do not commit this script.
begin;
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000101', 'ajo-sql-owner@example.invalid', '{"full_name":"SQL Owner"}'),
  ('00000000-0000-4000-8000-000000000102', 'ajo-sql-outsider@example.invalid', '{"full_name":"SQL Outsider"}');

do $$
declare
  first_group jsonb;
  retry_group jsonb;
  group_id uuid;
  total integer;
begin
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);
  first_group := public.create_savings_group(repeat('a', 32), 'Regression group', 2000050, 10, current_date + 30);
  group_id := (first_group->>'id')::uuid;
  retry_group := public.create_savings_group(repeat('a', 32), 'Regression group', 2000050, 10, current_date + 30);
  if first_group->>'id' <> retry_group->>'id' then
    raise exception 'Retry created a duplicate group';
  end if;
  select count(*) into total from public.savings_groups where id = group_id;
  if total <> 1 then raise exception 'Owner cannot see own group'; end if;
  select count(*) into total from public.group_members where group_members.group_id = (first_group->>'id')::uuid;
  if total <> 1 then raise exception 'Owner membership was not created atomically'; end if;

  begin
    perform public.create_savings_group(repeat('b',32), 'Invalid', 1, 10, current_date + 30);
    raise exception 'Invalid amount was accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.create_savings_group(repeat('b',32), 'Invalid', 100, 1, current_date + 30);
    raise exception 'Invalid capacity was accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.create_savings_group(repeat('b',32), 'Invalid', 100, 2, current_date - 1);
    raise exception 'Past date was accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.create_savings_group(repeat('a',32), 'Changed terms', 100, 2, current_date + 30);
    raise exception 'Retry with changed terms was accepted';
  exception when unique_violation then null;
  end;
  begin
    update public.savings_groups set status = 'active' where id = group_id;
    raise exception 'Client could activate a draft directly';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);
  select count(*) into total from public.savings_groups where id = group_id;
  if total <> 0 then raise exception 'Outsider can read another group'; end if;
  select count(*) into total from public.group_members where group_members.group_id = (first_group->>'id')::uuid;
  if total <> 0 then raise exception 'Outsider can read group membership'; end if;
  begin
    insert into public.group_members(group_id, user_id, role)
      values ((first_group->>'id')::uuid, auth.uid(), 'member');
    raise exception 'Outsider could self-insert membership';
  exception when insufficient_privilege then null;
  end;
  -- A different caller using the same request id must get their own group.
  retry_group := public.create_savings_group(repeat('a',32), 'Other group', 100, 2, current_date + 30);
  if first_group->>'id' = retry_group->>'id' then raise exception 'Request ids leak across callers'; end if;

  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.create_savings_group(repeat('c',32), 'No user', 100, 2, current_date + 30);
    raise exception 'Missing identity was accepted';
  exception when insufficient_privilege then null;
  end;
  execute 'set local role anon';
  begin
    perform public.create_savings_group(repeat('c',32), 'Anonymous', 100, 2, current_date + 30);
    raise exception 'Anonymous caller could create a group';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.savings_groups;
    raise exception 'Anonymous caller could query groups';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';
  select count(*) into total from public.group_events where group_events.group_id = (first_group->>'id')::uuid;
  if total <> 1 then raise exception 'Creation audit event missing or duplicated'; end if;
end;
$$;
rollback;
