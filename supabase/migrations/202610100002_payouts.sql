begin;

-- One scheduled payout per member. Slot 0 is the end-date distribution;
-- rotating groups use the existing agreed period number.
create table public.payouts (
  group_id uuid not null references public.savings_groups(id),
  slot integer not null check (slot >= 0),
  recipient_id uuid not null,
  amount_kobo bigint not null check (amount_kobo > 0),
  transfer_reference text not null check (char_length(transfer_reference) between 3 and 120),
  paid_on date not null,
  leader_note text,
  status text not null check (status in ('reported','disputed','confirmed')),
  version integer not null check (version > 0),
  recorded_by uuid not null references auth.users(id),
  recorded_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  recipient_note text,
  primary key (group_id,slot,recipient_id),
  unique (group_id,recipient_id),
  foreign key (group_id,recipient_id) references public.group_members(group_id,user_id)
);
create unique index payout_reference_once on public.payouts(group_id,lower(transfer_reference));
create table public.payout_history (
  id bigint generated always as identity primary key,
  group_id uuid not null,
  slot integer not null,
  recipient_id uuid not null,
  actor_id uuid not null references auth.users(id),
  status text not null,
  version integer not null,
  amount_kobo bigint not null,
  transfer_reference text not null,
  paid_on date not null,
  leader_note text,
  recipient_note text,
  created_at timestamptz not null default now(),
  foreign key (group_id,slot,recipient_id) references public.payouts(group_id,slot,recipient_id)
);
alter table public.payouts enable row level security;
alter table public.payout_history enable row level security;
revoke all on public.payouts,public.payout_history from public,anon,authenticated;

-- Internal only: all expected amounts come from frozen terms and schedules.
create function public.payout_entitlements(p_group_id uuid)
returns table(slot integer,recipient_id uuid,due_on date,amount_kobo bigint,
  expected_pool_kobo bigint,confirmed_pool_kobo bigint,funded boolean,previous_complete boolean)
language sql stable security definer set search_path='' as $$
 with g as (select * from public.savings_groups where id=p_group_id),
 slots as (
   select s.period_number as slot,s.recipient_id,s.due_date as due_on,
     g.contribution_kobo*g.member_limit as amount_kobo,
     g.contribution_kobo*g.member_limit as expected_pool_kobo
   from g join public.group_periods s on s.group_id=g.id where g.savings_mode='rotating'
   union all
   select 0,m.user_id,g.end_date,
     g.contribution_kobo*(select count(*) from public.group_periods where group_id=g.id),
     g.contribution_kobo*g.member_limit*(select count(*) from public.group_periods where group_id=g.id)
   from g join public.group_members m on m.group_id=g.id where g.savings_mode='target'
     and exists(select 1 from public.group_periods where group_id=g.id)
 ), totals as (
   select s.*,coalesce((select sum(c.amount_kobo) from public.contributions c
     where c.group_id=p_group_id and c.status='confirmed' and (s.slot=0 or c.period_number=s.slot)),0)::bigint as confirmed_pool_kobo,
     not exists(select 1 from public.group_periods gp cross join public.group_members gm
       where gp.group_id=p_group_id and gm.group_id=p_group_id and (s.slot=0 or gp.period_number=s.slot)
         and not exists(select 1 from public.contributions c join g on true
           where c.group_id=p_group_id and c.period_number=gp.period_number and c.user_id=gm.user_id
             and c.status='confirmed' and c.amount_kobo=g.contribution_kobo)) as all_confirmed
   from slots s
 )
 select t.slot,t.recipient_id,t.due_on,t.amount_kobo,t.expected_pool_kobo,t.confirmed_pool_kobo,
   t.all_confirmed and t.confirmed_pool_kobo=t.expected_pool_kobo,
   t.slot=0 or not exists(select 1 from public.group_periods gp where gp.group_id=p_group_id
     and gp.period_number<t.slot and not exists(select 1 from public.payouts p
       where p.group_id=gp.group_id and p.slot=gp.period_number and p.recipient_id=gp.recipient_id and p.status='confirmed'))
 from totals t;
$$;
revoke all on function public.payout_entitlements(uuid) from public,anon,authenticated;

create function public.get_payout_tracker(p_group_id uuid) returns jsonb
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
   'confirmed_pool_kobo',e.confirmed_pool_kobo,'shortfall_kobo',greatest(0,e.expected_pool_kobo-e.confirmed_pool_kobo),
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

create function public.record_payout(p_group_id uuid,p_slot integer,p_recipient_id uuid,
 p_amount_kobo bigint,p_reference text,p_paid_on date,p_expected_version integer,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; e record; p public.payouts; present boolean;
 today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then
   raise exception 'Only the group leader can record payouts.' using errcode='42501';
 end if;
 if p_expected_version is null or p_expected_version<0 or p_reference is null
   or char_length(btrim(p_reference)) not between 3 and 120 or char_length(coalesce(p_note,''))>500
   or p_paid_on is null or p_paid_on>today or p_amount_kobo is null then
   raise exception 'Check the payout reference, date and note.' using errcode='22023';
 end if;
 select * into e from public.payout_entitlements(p_group_id) where slot=p_slot and recipient_id=p_recipient_id;
 if not found or e.amount_kobo<>p_amount_kobo or p_paid_on<e.due_on then
   raise exception 'Use the scheduled recipient, full amount and a date on or after the payout date.' using errcode='22023';
 end if;
 p_note:=nullif(btrim(p_note),'');
 select * into p from public.payouts where group_id=p_group_id and slot=p_slot and recipient_id=p_recipient_id;
 present:=found;
 -- Retry remains safe after acknowledgement, including after group completion.
 if present and p.version=p_expected_version+1 and p.amount_kobo=p_amount_kobo
   and p.transfer_reference=btrim(p_reference) and p.paid_on=p_paid_on and p.leader_note is not distinct from p_note then
   return public.get_payout_tracker(p_group_id);
 end if;
 if g.status<>'active' or not e.funded or e.due_on>today or not e.previous_complete then
   raise exception 'Wait for the payout date, all confirmed contributions and earlier payout acknowledgements.' using errcode='22023';
 end if;
 if (present and (p.status<>'disputed' or p.version<>p_expected_version)) or (not present and p_expected_version<>0) then
   raise exception 'This payout changed. Refresh before recording it.' using errcode='22023';
 end if;
 insert into public.payouts(group_id,slot,recipient_id,amount_kobo,transfer_reference,paid_on,leader_note,status,version,recorded_by)
 values(p_group_id,p_slot,p_recipient_id,p_amount_kobo,btrim(p_reference),p_paid_on,p_note,'reported',p_expected_version+1,auth.uid())
 on conflict(group_id,slot,recipient_id) do update set transfer_reference=excluded.transfer_reference,
   paid_on=excluded.paid_on,leader_note=excluded.leader_note,status='reported',version=excluded.version,
   recorded_by=auth.uid(),recorded_at=now(),acknowledged_at=null,recipient_note=null returning * into p;
 insert into public.payout_history(group_id,slot,recipient_id,actor_id,status,version,amount_kobo,transfer_reference,paid_on,leader_note)
 values(p.group_id,p.slot,p.recipient_id,auth.uid(),p.status,p.version,p.amount_kobo,p.transfer_reference,p.paid_on,p.leader_note);
 return public.get_payout_tracker(p_group_id);
end; $$;

create function public.acknowledge_payout(p_group_id uuid,p_slot integer,p_version integer,p_received boolean,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; p public.payouts; desired text;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then
   raise exception 'Group access denied' using errcode='42501';
 end if;
 select * into p from public.payouts where group_id=p_group_id and slot=p_slot and recipient_id=auth.uid();
 if not found then raise exception 'Only the scheduled recipient can acknowledge this payout.' using errcode='42501'; end if;
 if p_version is null or p_version<>p.version or p_received is null
   or char_length(coalesce(p_note,''))>500 or (not p_received and char_length(btrim(coalesce(p_note,'')))<3) then
   raise exception 'Refresh the payout and give a reason when reporting a problem.' using errcode='22023';
 end if;
 p_note:=nullif(btrim(p_note),''); desired:=case when p_received then 'confirmed' else 'disputed' end;
 if p.status=desired and p.recipient_note is not distinct from p_note then return public.get_payout_tracker(p_group_id); end if;
 if g.status<>'active' or p.status='confirmed' or (not p_received and p.status<>'reported') then
   raise exception 'This payout has already been reviewed. Refresh to see its status.' using errcode='22023';
 end if;
 update public.payouts set status=desired,recipient_note=p_note,acknowledged_at=now()
   where group_id=p_group_id and slot=p_slot and recipient_id=auth.uid() returning * into p;
 insert into public.payout_history(group_id,slot,recipient_id,actor_id,status,version,amount_kobo,transfer_reference,paid_on,leader_note,recipient_note)
 values(p.group_id,p.slot,p.recipient_id,auth.uid(),p.status,p.version,p.amount_kobo,p.transfer_reference,p.paid_on,p.leader_note,p.recipient_note);
 if p_received and not exists(select 1 from public.payout_entitlements(p_group_id) e
   where not exists(select 1 from public.payouts q where q.group_id=p_group_id and q.slot=e.slot and q.recipient_id=e.recipient_id and q.status='confirmed')) then
   update public.savings_groups set status='completed' where id=p_group_id;
   insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'group_completed');
 end if;
 return public.get_payout_tracker(p_group_id);
end; $$;
revoke all on function public.get_payout_tracker(uuid),public.record_payout(uuid,integer,uuid,bigint,text,date,integer,text),public.acknowledge_payout(uuid,integer,integer,boolean,text) from public,anon;
grant execute on function public.get_payout_tracker(uuid),public.record_payout(uuid,integer,uuid,bigint,text,date,integer,text),public.acknowledge_payout(uuid,integer,integer,boolean,text) to authenticated;
notify pgrst,'reload schema';
commit;
