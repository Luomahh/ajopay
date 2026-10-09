begin;
alter table public.savings_groups
  add column terms_version integer not null default 1,
  add column order_prepared boolean not null default false,
  add column activated_at timestamptz;
alter table public.group_members
  add column rotation_position integer check(rotation_position > 0),
  add column accepted_terms_version integer,
  add column accepted_at timestamptz;
create unique index group_member_position on public.group_members(group_id,rotation_position) where rotation_position is not null;
create table public.group_periods(
 group_id uuid not null references public.savings_groups(id),
 period_number integer not null check(period_number > 0),
 due_date date not null,
 recipient_id uuid,
 primary key(group_id,period_number),
 foreign key(group_id,recipient_id) references public.group_members(group_id,user_id)
);
alter table public.group_periods enable row level security;
revoke all on public.group_periods from public,anon,authenticated;
grant select on public.group_periods to authenticated;
create policy member_periods on public.group_periods for select to authenticated using(exists(select 1 from public.group_members m where m.group_id=group_periods.group_id and m.user_id=(select auth.uid())));

-- Return only group-scoped display names, never contact details or trust scores.
create function public.get_group_details(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; members jsonb; periods jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select * into g from public.savings_groups where id=p_group_id;
 select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'name',coalesce(nullif(btrim(p.full_name),''),'Member'),'role',m.role,'rotation_position',m.rotation_position,'accepted_terms_version',m.accepted_terms_version) order by m.rotation_position nulls last,m.joined_at,m.user_id),'[]') into members from public.group_members m left join public.profiles p on p.id=m.user_id where m.group_id=p_group_id;
 select coalesce(jsonb_agg(to_jsonb(s) order by s.period_number),'[]') into periods from public.group_periods s where s.group_id=p_group_id;
 return jsonb_build_object('group',to_jsonb(g),'members',members,'periods',periods);
end; $$;

create function public.prepare_group_order(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then raise exception 'Only the group leader can prepare the order' using errcode='42501'; end if;
 if g.status<>'draft' then raise exception 'Group is no longer a draft' using errcode='22023'; end if;
 if g.order_prepared or g.savings_mode='target' then return public.get_group_details(p_group_id); end if;
 if (select count(*) from public.group_members where group_id=p_group_id)<>g.member_limit then raise exception 'All planned members must join first' using errcode='22023'; end if;
 with positions as(select user_id,row_number() over(order by random())::integer as position from public.group_members where group_id=p_group_id)
 update public.group_members m set rotation_position=p.position,accepted_terms_version=null,accepted_at=null from positions p where m.group_id=p_group_id and m.user_id=p.user_id;
 update public.savings_groups set order_prepared=true,terms_version=terms_version+1 where id=p_group_id;
 insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'order_prepared');
 return public.get_group_details(p_group_id);
end; $$;

create function public.accept_group_terms(p_group_id uuid,p_terms_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 if g.status<>'draft' or p_terms_version is null or p_terms_version<>g.terms_version then raise exception 'Refresh the group and review the current terms' using errcode='22023'; end if;
 if (select count(*) from public.group_members where group_id=p_group_id)<>g.member_limit or (g.savings_mode='rotating' and not g.order_prepared) then raise exception 'Wait until the membership and payout order are ready' using errcode='22023'; end if;
 update public.group_members set accepted_terms_version=g.terms_version,accepted_at=now() where group_id=p_group_id and user_id=auth.uid() and accepted_terms_version is distinct from g.terms_version;
 if found then insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'terms_accepted'); end if;
 return public.get_group_details(p_group_id);
end; $$;

create function public.activate_savings_group(p_group_id uuid,p_terms_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; i integer:=0; due date; recipient uuid;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then raise exception 'Only the group leader can activate' using errcode='42501'; end if;
 if p_terms_version is null or p_terms_version<>g.terms_version then raise exception 'Refresh and review the current terms' using errcode='22023'; end if;
 if g.status='active' then return public.get_group_details(p_group_id); end if;
 if g.status<>'draft' or g.first_payout_date<(now() at time zone 'UTC')::date then raise exception 'The group must be a draft with a current or future start date' using errcode='22023'; end if;
 if (select count(*) from public.group_members where group_id=p_group_id)<>g.member_limit then raise exception 'All planned members must join first' using errcode='22023'; end if;
 if (g.savings_mode='rotating' and not g.order_prepared) or exists(select 1 from public.group_members where group_id=p_group_id and accepted_terms_version is distinct from g.terms_version) then raise exception 'Every member must agree to the current terms' using errcode='22023'; end if;
 loop
  due:=case g.frequency when 'daily' then g.first_payout_date+i when 'weekly' then g.first_payout_date+7*i else (g.first_payout_date+make_interval(months=>i))::date end;
  exit when (g.savings_mode='rotating' and i>=g.member_limit) or (g.savings_mode='target' and due>g.end_date);
  recipient:=null;
  if g.savings_mode='rotating' then
   select user_id into recipient from public.group_members where group_id=p_group_id and rotation_position=i+1;
   if recipient is null then raise exception 'Incomplete payout order' using errcode='22023'; end if;
  end if;
  insert into public.group_periods(group_id,period_number,due_date,recipient_id) values(p_group_id,i+1,due,recipient);
  i:=i+1;
  if i>3661 then raise exception 'Schedule exceeds supported length' using errcode='22023'; end if;
 end loop;
 update public.savings_groups set status='active',activated_at=now() where id=p_group_id;
 insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'group_activated');
 return public.get_group_details(p_group_id);
end; $$;
revoke all on function public.get_group_details(uuid),public.prepare_group_order(uuid),public.accept_group_terms(uuid,integer),public.activate_savings_group(uuid,integer) from public,anon;
grant execute on function public.get_group_details(uuid),public.prepare_group_order(uuid),public.accept_group_terms(uuid,integer),public.activate_savings_group(uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
