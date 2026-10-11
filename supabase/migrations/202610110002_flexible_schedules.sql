begin;
-- Existing groups keep their previously accepted exact amounts and fee-free terms.
alter table public.savings_groups add column rules_version integer not null default 1 check(rules_version in (1,2)),
 add column payout_frequency text check(payout_frequency in ('daily','weekly','monthly')),
 add column first_collection_date date,
 add column late_fee_kobo bigint not null default 0 check(late_fee_kobo in (0,20000));
create function public.savings_date(p_first date,p_frequency text,p_index integer) returns date
language sql immutable set search_path='' as $$
 select case p_frequency when 'daily' then p_first+p_index when 'weekly' then p_first+7*p_index else (p_first+make_interval(months=>p_index))::date end;
$$;
create table public.group_payout_schedule(
 group_id uuid not null references public.savings_groups(id), slot integer not null check(slot>0),
 recipient_id uuid not null, due_on date not null,
 primary key(group_id,slot), unique(group_id,recipient_id),
 foreign key(group_id,recipient_id) references public.group_members(group_id,user_id)
);
insert into public.group_payout_schedule select p.group_id,p.period_number,p.recipient_id,p.due_date from public.group_periods p join public.savings_groups g on g.id=p.group_id where g.savings_mode='rotating';
alter table public.group_payout_schedule enable row level security;
revoke all on public.group_payout_schedule from public,anon,authenticated;
grant select on public.group_payout_schedule to authenticated;
create policy members_read_payout_schedule on public.group_payout_schedule for select to authenticated using(exists(select 1 from public.group_members m where m.group_id=group_payout_schedule.group_id and m.user_id=(select auth.uid())));
create function public.create_savings_group_v3(
  p_request_id text,
  p_name text,
  p_contribution_kobo bigint,
  p_member_limit integer,
  p_first_payout_date date,
  p_savings_mode text,
  p_frequency text,
  p_end_date date,
  p_payout_frequency text,
  p_first_collection_date date
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
    or p_payout_frequency is null or p_payout_frequency not in ('daily','weekly','monthly')
    or p_first_collection_date is null or p_first_collection_date < p_first_payout_date
    or (p_savings_mode='rotating' and (
      (p_frequency='monthly' and p_payout_frequency<>'monthly') or
      (p_frequency='weekly' and p_payout_frequency='daily') or
      p_first_collection_date > public.savings_date(p_first_payout_date,p_payout_frequency,1)))
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
      or created.end_date is distinct from p_end_date
      or created.rules_version<>2 or created.payout_frequency<>p_payout_frequency
      or created.first_collection_date<>p_first_collection_date then
      raise exception 'Request already used with different terms' using errcode = '23505';
    end if;
    return to_jsonb(created);
  end if;

  -- Accept today in UTC to accommodate a future local calendar date.
  if p_first_payout_date < (now() at time zone 'UTC')::date then
    raise exception 'First payout date is in the past' using errcode = '22023';
  end if;
  insert into public.savings_groups
    (created_by, request_id, name, contribution_kobo, member_limit, first_payout_date, savings_mode, frequency, end_date, rules_version, payout_frequency, first_collection_date, late_fee_kobo)
    values (caller, p_request_id, btrim(p_name), p_contribution_kobo, p_member_limit, p_first_payout_date, p_savings_mode, p_frequency, p_end_date, 2, p_payout_frequency, p_first_collection_date, 20000)
    returning * into created;
  insert into public.group_members (group_id, user_id, role)
    values (created.id, caller, 'owner');
  insert into public.group_events (group_id, actor_id, action)
    values (created.id, caller, 'group_created');
  return to_jsonb(created);
end;
$$;

revoke all on function public.create_savings_group_v3(text, text, bigint, integer, date, text, text, date, text, date) from public, anon;
grant execute on function public.create_savings_group_v3(text, text, bigint, integer, date, text, text, date, text, date) to authenticated;

create or replace function public.activate_savings_group(p_group_id uuid,p_terms_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; i integer:=0; due date; recipient uuid; last_due date; collection date; n integer;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then raise exception 'Only the group leader can activate' using errcode='42501'; end if;
 if p_terms_version is null or p_terms_version<>g.terms_version then raise exception 'Refresh and review the current terms' using errcode='22023'; end if;
 if g.status='active' then return public.get_group_details(p_group_id); end if;
 if g.status<>'draft' or g.first_payout_date<(now() at time zone 'UTC')::date then raise exception 'The group must be a draft with a current or future start date' using errcode='22023'; end if;
 if (select count(*) from public.group_members where group_id=p_group_id)<>g.member_limit then raise exception 'All planned members must join first' using errcode='22023'; end if;
 if (g.savings_mode='rotating' and not g.order_prepared) or exists(select 1 from public.group_members where group_id=p_group_id and accepted_terms_version is distinct from g.terms_version) then raise exception 'Every member must agree to the current terms' using errcode='22023'; end if;
 if g.rules_version=2 and not exists(select 1 from public.group_bank_accounts where group_id=p_group_id) then raise exception 'Add the group bank account before activation' using errcode='22023'; end if;
 last_due:=case when g.savings_mode='target' then g.end_date when g.rules_version=2 then public.savings_date(g.first_collection_date,g.payout_frequency,g.member_limit-1) else public.savings_date(g.first_payout_date,g.frequency,g.member_limit-1) end;
 loop
  due:=public.savings_date(g.first_payout_date,g.frequency,i);
  exit when due>last_due;
  recipient:=null;
  if g.savings_mode='rotating' and g.rules_version=1 then
   select user_id into recipient from public.group_members where group_id=p_group_id and rotation_position=i+1;
  end if;
  insert into public.group_periods(group_id,period_number,due_date,recipient_id) values(p_group_id,i+1,due,recipient);
  i:=i+1;
  if i>3661 then raise exception 'Schedule exceeds supported length' using errcode='22023'; end if;
 end loop;
 if g.savings_mode='rotating' then
  for n in 1..g.member_limit loop
   collection:=case when g.rules_version=2 then public.savings_date(g.first_collection_date,g.payout_frequency,n-1) else public.savings_date(g.first_payout_date,g.frequency,n-1) end;
   select user_id into recipient from public.group_members where group_id=p_group_id and rotation_position=n;
   if recipient is null then raise exception 'Incomplete payout order' using errcode='22023'; end if;
   insert into public.group_payout_schedule(group_id,slot,recipient_id,due_on) values(p_group_id,n,recipient,collection);
  end loop;
 end if;
 update public.savings_groups set status='active',activated_at=now() where id=p_group_id;
 insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'group_activated');
 return public.get_group_details(p_group_id);
end; $$;
create or replace function public.submit_contribution_v2(p_group_id uuid,p_period integer,p_amount_kobo bigint,p_reference text,p_paid_on date,p_expected_version integer,p_receipt_path text,p_payment_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; c public.contributions; existing boolean; opening date; today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Access denied' using errcode='42501'; end if;
 if g.status<>'active' then raise exception 'Activate the group before recording contributions.' using errcode='22023'; end if;
 opening:=public.contribution_window_start(p_group_id,p_period);
 if opening is null or opening>today then raise exception 'This contribution period is not open yet.' using errcode='22023'; end if;
 if p_amount_kobo is null or (p_amount_kobo>100000000 or case when g.rules_version=2 and g.savings_mode='target' then p_amount_kobo<g.contribution_kobo else p_amount_kobo<>g.contribution_kobo end) or p_reference is null or char_length(btrim(p_reference)) not between 3 and 120 or p_paid_on is null or p_paid_on<opening or p_paid_on>today or p_expected_version is null or p_expected_version<0 then raise exception 'Check the amount, payment date and reference.' using errcode='22023'; end if;
 if char_length(coalesce(p_payment_note,''))>500 then raise exception 'Payment note is too long' using errcode='22023'; end if;
 p_payment_note:=nullif(btrim(p_payment_note),'');
 if p_receipt_path is not null and (split_part(p_receipt_path,'/',1)<>p_group_id::text or split_part(p_receipt_path,'/',2)<>auth.uid()::text or not exists(select 1 from storage.objects where bucket_id='payment-receipts' and name=p_receipt_path)) then raise exception 'Receipt access denied' using errcode='42501'; end if;
 select * into c from public.contributions where group_id=p_group_id and period_number=p_period and user_id=auth.uid(); existing:=found;
 -- A repeated identical request returns the existing record, even after review.
 if existing and c.version=p_expected_version+1 and c.amount_kobo=p_amount_kobo and c.payment_reference=btrim(p_reference) and c.paid_on=p_paid_on and c.receipt_path is not distinct from p_receipt_path and c.payment_note is not distinct from p_payment_note then return public.get_contribution_tracker(p_group_id); end if;
 if (existing and (c.status<>'rejected' or c.version<>p_expected_version)) or (not existing and p_expected_version<>0) then raise exception 'This payment changed. Refresh before trying again.' using errcode='22023'; end if;
 insert into public.contributions(group_id,period_number,user_id,amount_kobo,payment_reference,paid_on,status,version,receipt_path,payment_note)
 values(p_group_id,p_period,auth.uid(),p_amount_kobo,btrim(p_reference),p_paid_on,'pending',p_expected_version+1,p_receipt_path,p_payment_note)
 on conflict(group_id,period_number,user_id) do update set amount_kobo=excluded.amount_kobo,payment_reference=excluded.payment_reference,paid_on=excluded.paid_on,status='pending',version=excluded.version,submitted_at=now(),reviewed_at=null,reviewed_by=null,review_note=null,receipt_path=excluded.receipt_path,payment_note=excluded.payment_note returning * into c;
 insert into public.contribution_history(group_id,period_number,user_id,actor_id,status,version,amount_kobo,payment_reference,paid_on) values(c.group_id,c.period_number,c.user_id,auth.uid(),c.status,c.version,c.amount_kobo,c.payment_reference,c.paid_on);
 return public.get_contribution_tracker(p_group_id);
end; $$;


alter function public.payout_entitlements(uuid) rename to payout_entitlements_legacy;
create function public.payout_entitlements_v2(p_group_id uuid)
returns table(slot integer,recipient_id uuid,due_on date,amount_kobo bigint,expected_pool_kobo bigint,confirmed_pool_kobo bigint,funded boolean,previous_complete boolean)
language sql stable security definer set search_path='' as $$
 with g as (select * from public.savings_groups where id=p_group_id),
 slots as (
  select s.slot,s.recipient_id,s.due_on,coalesce((select max(prev.due_on) from public.group_payout_schedule prev where prev.group_id=g.id and prev.slot<s.slot),'-infinity'::date) as after_date
  from g join public.group_payout_schedule s on s.group_id=g.id where g.savings_mode='rotating'
  union all
  select 0,m.user_id,g.end_date,'-infinity'::date from g join public.group_members m on m.group_id=g.id where g.savings_mode='target' and exists(select 1 from public.group_periods where group_id=g.id)
 ), totals as (
  select s.*,g.savings_mode,g.rules_version,g.contribution_kobo,
   g.contribution_kobo*(select count(*) from public.group_periods gp where gp.group_id=g.id and gp.due_date>s.after_date and gp.due_date<=s.due_on) as minimum_member,
   g.member_limit,
   coalesce((select sum(c.amount_kobo) from public.contributions c join public.group_periods gp on gp.group_id=c.group_id and gp.period_number=c.period_number where c.group_id=g.id and c.status='confirmed' and gp.due_date>s.after_date and gp.due_date<=s.due_on),0)::bigint as collected,
   coalesce((select sum(c.amount_kobo) from public.contributions c where c.group_id=g.id and c.user_id=s.recipient_id and c.status='confirmed'),0)::bigint as own_total,
   not exists(select 1 from public.group_periods gp cross join public.group_members gm where gp.group_id=g.id and gm.group_id=g.id and gp.due_date>s.after_date and gp.due_date<=s.due_on and not exists(select 1 from public.contributions c where c.group_id=g.id and c.period_number=gp.period_number and c.user_id=gm.user_id and c.status='confirmed' and (case when g.rules_version=2 and g.savings_mode='target' then c.amount_kobo>=g.contribution_kobo else c.amount_kobo=g.contribution_kobo end))) as all_confirmed
  from slots s cross join g
 )
 select t.slot,t.recipient_id,t.due_on,
  case when t.savings_mode='rotating' then t.minimum_member*t.member_limit when t.rules_version=2 then t.own_total else t.minimum_member end,
  t.minimum_member*t.member_limit,t.collected,
  t.minimum_member>0 and t.all_confirmed and t.collected>=t.minimum_member*t.member_limit,
  t.slot=0 or not exists(select 1 from public.group_payout_schedule prev where prev.group_id=p_group_id and prev.slot<t.slot and not exists(select 1 from public.payouts p where p.group_id=p_group_id and p.slot=prev.slot and p.recipient_id=prev.recipient_id and p.status='confirmed'))
 from totals t;
$$;
revoke all on function public.payout_entitlements_v2(uuid) from public,anon,authenticated;
create function public.payout_entitlements(p_group_id uuid)
returns table(slot integer,recipient_id uuid,due_on date,amount_kobo bigint,expected_pool_kobo bigint,confirmed_pool_kobo bigint,funded boolean,previous_complete boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if (select rules_version from public.savings_groups where id=p_group_id)=2 then
  return query select * from public.payout_entitlements_v2(p_group_id);
 else
  return query select * from public.payout_entitlements_legacy(p_group_id);
 end if;
end; $$;
revoke all on function public.payout_entitlements(uuid) from public,anon,authenticated;
-- A fee is separate from contribution principal. Manual dates require leader review.
-- No collection API is exposed: a provider must confirm settlement before any fee is called paid.
create function public.get_late_fees(p_group_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare g public.savings_groups; result jsonb;
begin
 select * into g from public.savings_groups where id=p_group_id;
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'period_number',p.period_number,'due_date',p.due_date,'amount_kobo',g.late_fee_kobo,'status',case when c.status='confirmed' then 'due' else 'awaiting_payment_review' end) order by p.period_number,m.user_id),'[]') into result
 from public.group_periods p cross join public.group_members m left join public.contributions c on c.group_id=p.group_id and c.period_number=p.period_number and c.user_id=m.user_id
 where p.group_id=p_group_id and m.group_id=p_group_id and (g.created_by=auth.uid() or m.user_id=auth.uid()) and g.late_fee_kobo>0 and p.due_date<(now() at time zone 'Africa/Lagos')::date and (c.status is distinct from 'confirmed' or c.paid_on>p.due_date);
 return result;
end; $$;
revoke all on function public.get_late_fees(uuid) from public,anon;
grant execute on function public.get_late_fees(uuid) to authenticated;
create or replace function public.get_payout_tracker(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; rows jsonb; history jsonb;
  today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then
   raise exception 'Group access denied' using errcode='42501';
 end if;
 select * into g from public.savings_groups where id=p_group_id;
 select coalesce(jsonb_agg(jsonb_build_object(
   'slot',e.slot,'recipient_id',e.recipient_id,'recipient_name',coalesce(nullif(btrim(pr.full_name),''),'Member'),
   'due_on',e.due_on,'amount_kobo',e.amount_kobo,'expected_pool_kobo',e.expected_pool_kobo,
   'confirmed_pool_kobo',e.confirmed_pool_kobo,'shortfall_kobo',case when g.rules_version=1 then greatest(0,e.expected_pool_kobo-e.confirmed_pool_kobo) else
 (select count(*)*g.contribution_kobo from public.group_periods gp cross join public.group_members gm
 where gp.group_id=g.id and gm.group_id=g.id and gp.due_date<=e.due_on and (e.slot=0 or gp.due_date>coalesce((select max(prev.due_on) from public.group_payout_schedule prev where prev.group_id=g.id and prev.slot<e.slot),'-infinity'::date))
 and not exists(select 1 from public.contributions c where c.group_id=g.id and c.period_number=gp.period_number and c.user_id=gm.user_id and c.status='confirmed')) end,
   'status',coalesce(p.status,case when not e.funded then 'collecting' when e.due_on>today then 'scheduled'
     when not e.previous_complete then 'waiting_previous' else 'ready' end),
   'can_record',g.status='active' and e.funded and e.due_on<=today and e.previous_complete and (p.status is null or p.status='disputed'),
   'version',coalesce(p.version,0),
   'transfer_reference',case when g.created_by=auth.uid() or e.recipient_id=auth.uid() then p.transfer_reference end,
   'paid_on',case when g.created_by=auth.uid() or e.recipient_id=auth.uid() then p.paid_on end,
   'leader_note',case when g.created_by=auth.uid() or e.recipient_id=auth.uid() then p.leader_note end,
   'recipient_note',case when g.created_by=auth.uid() or e.recipient_id=auth.uid() then p.recipient_note end,
   'acknowledged_at',p.acknowledged_at
 ) order by e.slot,e.recipient_id),'[]') into rows
 from public.payout_entitlements(p_group_id) e left join public.payouts p
   on p.group_id=p_group_id and p.slot=e.slot and p.recipient_id=e.recipient_id
 left join public.profiles pr on pr.id=e.recipient_id;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.id desc),'[]') into history from public.payout_history h
   where h.group_id=p_group_id and (g.created_by=auth.uid() or h.recipient_id=auth.uid());
 return jsonb_build_object('group_name',g.name,'group_status',g.status,'owner_id',g.created_by,
   'mode',g.savings_mode,'today',today,'payouts',rows,'history',history);
end; $$;


notify pgrst,'reload schema';
commit;
