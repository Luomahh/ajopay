begin;
alter table public.group_messages add column reply_to bigint references public.group_messages(sequence);
create function public.send_group_reply(p_group_id uuid,p_request_id text,p_body text,p_reply_to bigint default null) returns bigint
language plpgsql security definer set search_path='' as $$
declare existing public.group_messages; result bigint;
begin
 perform 1 from public.savings_groups where id=p_group_id for update;
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select * into existing from public.group_messages where group_id=p_group_id and user_id=auth.uid() and request_id=p_request_id;
 if found and existing.reply_to is distinct from p_reply_to then raise exception 'Reply request already used' using errcode='22023'; end if;
 if p_reply_to is not null and not exists(select 1 from public.group_messages m where m.sequence=p_reply_to and m.group_id=p_group_id and m.deleted_at is null and not exists(select 1 from public.group_message_hides h where h.message_sequence=m.sequence and h.user_id=auth.uid())) then raise exception 'Reply message is no longer available' using errcode='22023'; end if;
 result:=public.send_group_message(p_group_id,p_request_id,p_body);
 update public.group_messages set reply_to=p_reply_to where sequence=result;
 return result;
end; $$;
revoke all on function public.send_group_reply(uuid,text,text,bigint) from public,anon;
grant execute on function public.send_group_reply(uuid,text,text,bigint) to authenticated;
create or replace function public.list_group_messages(p_group_id uuid,p_before bigint default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select coalesce(jsonb_agg(to_jsonb(page) order by sequence),'[]') into result from (
 select m.sequence,m.group_id,m.user_id,
 case when h.user_id is not null then '' when m.deleted_at is not null then 'Message removed' else m.body end as body,
 m.deleted_at is not null as removed,h.user_id is not null as hidden,m.created_at,
 coalesce(nullif(btrim(p.full_name),''),'Member') as sender_name,(m.user_id=g.created_by) as is_leader,
 case when m.deleted_at is null and h.user_id is null then m.reply_to end as reply_to,
 case when m.deleted_at is not null or h.user_id is not null then null
 when parent.deleted_at is not null or ph.user_id is not null then 'Message unavailable'
 else left(parent.body,160) end as reply_body
 from public.group_messages m join public.savings_groups g on g.id=m.group_id left join public.profiles p on p.id=m.user_id
 left join public.group_message_hides h on h.message_sequence=m.sequence and h.user_id=auth.uid()
 left join public.group_messages parent on parent.sequence=m.reply_to
 left join public.group_message_hides ph on ph.message_sequence=parent.sequence and ph.user_id=auth.uid()
 where m.group_id=p_group_id and (p_before is null or m.sequence<p_before) order by m.sequence desc limit 50
 ) page;
 return result;
end; $$;

create table public.notification_preferences (
 user_id uuid primary key references auth.users(id),email_enabled boolean not null default false,sms_enabled boolean not null default false,updated_at timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;
grant select,insert,update on public.notification_preferences to authenticated;
create policy own_notification_preferences on public.notification_preferences for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create table public.member_notifications (
 id bigint generated always as identity primary key,user_id uuid not null references auth.users(id),group_id uuid not null references public.savings_groups(id),
 kind text not null, dedupe_key text not null,title text not null,body text not null,
 message_sequence bigint references public.group_messages(sequence),period_number integer,
 created_at timestamptz not null default now(),read_at timestamptz,unique(user_id,dedupe_key)
);
create index member_notifications_feed on public.member_notifications(user_id,id desc);
alter table public.member_notifications enable row level security;
revoke all on public.member_notifications from public,anon,authenticated;
create table public.notification_outbox (
 id bigint generated always as identity primary key,notification_id bigint not null references public.member_notifications(id),channel text not null check(channel in ('email','sms')),
 state text not null default 'queued' check(state in ('queued','sent','cancelled')),created_at timestamptz not null default now(),sent_at timestamptz,unique(notification_id,channel)
);
alter table public.notification_outbox enable row level security;
revoke all on public.notification_outbox from public,anon,authenticated;
grant select,update on public.notification_outbox to service_role;
grant select on public.member_notifications,public.notification_preferences to service_role;
create function public.enqueue_notification_channels() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Group chat alerts remain in-app; reminders and payment updates may use opted-in channels.
 if new.kind<>'chat' then
  insert into public.notification_outbox(notification_id,channel)
  select new.id,'email' from public.notification_preferences where user_id=new.user_id and email_enabled
  union all select new.id,'sms' from public.notification_preferences where user_id=new.user_id and sms_enabled;
 end if;
 return new;
end; $$;
create trigger enqueue_notification_channels after insert on public.member_notifications for each row execute function public.enqueue_notification_channels();
create function public.notify_chat_message() returns trigger language plpgsql security definer set search_path='' as $$
declare group_name text; sender text;
begin
 select name into group_name from public.savings_groups where id=new.group_id;
 select full_name into sender from public.profiles where id=new.user_id;
 insert into public.member_notifications(user_id,group_id,kind,dedupe_key,title,body,message_sequence)
 select user_id,new.group_id,'chat','chat:'||new.sequence,group_name,coalesce(sender,'A member')||' sent a message.',new.sequence
 from public.group_members where group_id=new.group_id and user_id<>new.user_id;
 return new;
end; $$;
create trigger notify_chat_message after insert on public.group_messages for each row execute function public.notify_chat_message();
create function public.notify_contribution_change() returns trigger language plpgsql security definer set search_path='' as $$
declare group_name text; leader uuid;
begin
 if tg_op='UPDATE' then if new.status=old.status and new.version=old.version then return new; end if; end if;
 select name,created_by into group_name,leader from public.savings_groups where id=new.group_id;
 insert into public.member_notifications(user_id,group_id,kind,dedupe_key,title,body,period_number)
 values(new.user_id,new.group_id,'payment','payment:'||new.group_id||':'||new.period_number||':'||new.user_id||':'||new.version||':'||new.status,
 case new.status when 'pending' then 'Payment reported' when 'confirmed' then 'Payment confirmed by leader' else 'Payment needs correction' end,
 'NGN '||to_char(new.amount_kobo/100.0,'FM999999999990.00')||' · '||group_name||' · period '||new.period_number||case new.status when 'pending' then '. Awaiting leader review; this is not bank confirmation.' when 'confirmed' then '. Your leader confirmed receipt.' else '. Open your record to review the feedback.' end,new.period_number) on conflict do nothing;
 if new.status='pending' and leader<>new.user_id then
  insert into public.member_notifications(user_id,group_id,kind,dedupe_key,title,body,period_number)
  values(leader,new.group_id,'review','review:'||new.group_id||':'||new.period_number||':'||new.user_id||':'||new.version,'Payment awaiting review',group_name||' has a new payment report.',new.period_number) on conflict do nothing;
 end if;
 if new.status in ('pending','confirmed') then
  update public.member_notifications set read_at=coalesce(read_at,now()) where user_id=new.user_id and group_id=new.group_id and period_number=new.period_number and kind='reminder';
  update public.notification_outbox o set state='cancelled' from public.member_notifications n where o.notification_id=n.id and n.user_id=new.user_id and n.group_id=new.group_id and n.period_number=new.period_number and n.kind='reminder' and o.state='queued';
 end if;
 return new;
end; $$;
create trigger notify_contribution_change after insert or update on public.contributions for each row execute function public.notify_contribution_change();

-- Private helper: cadence is calculated from each contribution window in Nigeria time.
create function public.prepare_member_reminders(p_user uuid,p_today date) returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.member_notifications(user_id,group_id,kind,dedupe_key,title,body,period_number)
 select distinct on (g.id) p_user,g.id,'reminder','reminder:'||g.id||':'||p_today,
 case when p.due_date<p_today then 'Contribution overdue' when p.due_date=p_today then 'Contribution due today' else 'Contribution reminder' end,
 g.name||' · NGN '||to_char(g.contribution_kobo/100.0,'FM999999999990.00')||' · due '||p.due_date||'. Record your transfer after paying.',p.period_number
 from public.group_members m join public.savings_groups g on g.id=m.group_id join public.group_periods p on p.group_id=g.id
 where m.user_id=p_user and g.status='active' and p_today>=public.contribution_window_start(g.id,p.period_number)
 and not exists(select 1 from public.contributions c where c.group_id=g.id and c.period_number=p.period_number and c.user_id=p_user and c.status in ('pending','confirmed'))
 and (case when p_today>p.due_date then (p_today-p.due_date-1)%7=0
 when g.frequency='daily' then p_today=p.due_date
 when g.frequency='weekly' then p.due_date-p_today in (6,3,0)
 else (p_today-public.contribution_window_start(g.id,p.period_number))%7=0 or p_today=p.due_date end)
 order by g.id,(p.due_date=p_today) desc,p.due_date desc
 on conflict do nothing;
end; $$;
create function public.prepare_scheduled_reminders() returns void language plpgsql security definer set search_path='' as $$
declare u uuid;
begin
 for u in select distinct m.user_id from public.group_members m join public.savings_groups g on g.id=m.group_id where g.status='active' loop
  perform public.prepare_member_reminders(u,(now() at time zone 'Africa/Lagos')::date);
 end loop;
end; $$;
revoke all on function public.prepare_scheduled_reminders() from public,anon,authenticated;
grant execute on function public.prepare_scheduled_reminders() to service_role;
create function public.get_member_notifications() returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb; unread integer;
begin
 if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
 perform public.prepare_member_reminders(auth.uid(),(now() at time zone 'Africa/Lagos')::date);
 select count(*) into unread from public.member_notifications n where n.user_id=auth.uid() and n.read_at is null and exists(select 1 from public.group_members m where m.group_id=n.group_id and m.user_id=auth.uid());
 select coalesce(jsonb_agg(to_jsonb(x) order by id desc),'[]') into rows from (
 select n.* from public.member_notifications n where n.user_id=auth.uid() and exists(select 1 from public.group_members m where m.group_id=n.group_id and m.user_id=auth.uid()) order by id desc limit 100) x;
 return jsonb_build_object('items',rows,'unread',unread);
end; $$;
create function public.mark_notification_read(p_id bigint default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in required' using errcode='42501'; end if;
 update public.member_notifications set read_at=coalesce(read_at,now()) where user_id=auth.uid() and (p_id is null or id=p_id);
end; $$;
create function public.mark_chat_read(p_group_id uuid,p_through bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 update public.member_notifications set read_at=coalesce(read_at,now()) where user_id=auth.uid() and group_id=p_group_id and kind='chat' and message_sequence<=p_through;
end; $$;
revoke all on function public.enqueue_notification_channels(),public.notify_chat_message(),public.notify_contribution_change(),public.prepare_member_reminders(uuid,date) from public,anon,authenticated;
revoke all on function public.get_member_notifications(),public.mark_notification_read(bigint),public.mark_chat_read(uuid,bigint) from public,anon;
grant execute on function public.get_member_notifications(),public.mark_notification_read(bigint),public.mark_chat_read(uuid,bigint) to authenticated;
create function public.cancel_disabled_notifications() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.notification_outbox o set state='cancelled' from public.member_notifications n
 where o.notification_id=n.id and n.user_id=new.user_id and o.state='queued'
 and ((o.channel='email' and not new.email_enabled) or (o.channel='sms' and not new.sms_enabled));
 return new;
end; $$;
revoke all on function public.cancel_disabled_notifications() from public,anon,authenticated;
create trigger cancel_disabled_notifications after update on public.notification_preferences for each row execute function public.cancel_disabled_notifications();
notify pgrst,'reload schema';
commit;
