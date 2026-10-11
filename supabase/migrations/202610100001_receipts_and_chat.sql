begin;
alter table public.contributions add column receipt_path text, add column payment_note text check(char_length(payment_note)<=500);
alter table public.contribution_history add column receipt_path text, add column payment_note text;
create index contribution_history_receipt on public.contribution_history(receipt_path) where receipt_path is not null;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('payment-receipts','payment-receipts',false,5242880,array['image/png','image/jpeg','image/webp']);
create function public.can_upload_receipt(p_name text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and split_part(p_name,'/',2)=auth.uid()::text and p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f]{32}\.(png|jpg|webp)$' and exists(select 1 from public.group_members m join public.savings_groups g on g.id=m.group_id where m.user_id=auth.uid() and g.id::text=split_part(p_name,'/',1) and g.status='active');
$$;
create function public.can_read_receipt(p_name text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.group_members m join public.savings_groups g on g.id=m.group_id where m.user_id=auth.uid() and g.id::text=split_part(p_name,'/',1) and (split_part(p_name,'/',2)=auth.uid()::text or (g.created_by=auth.uid() and exists(select 1 from public.contribution_history h where h.group_id=g.id and h.receipt_path=p_name))));
$$;
revoke all on function public.can_upload_receipt(text),public.can_read_receipt(text) from public,anon;
grant execute on function public.can_upload_receipt(text),public.can_read_receipt(text) to authenticated;
create policy receipt_insert on storage.objects for insert to authenticated with check(bucket_id='payment-receipts' and public.can_upload_receipt(name));
create policy receipt_select on storage.objects for select to authenticated using(bucket_id='payment-receipts' and public.can_read_receipt(name));
-- No update/delete policy: submitted evidence cannot be silently replaced.
create function public.snapshot_contribution_evidence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 select receipt_path,payment_note into new.receipt_path,new.payment_note from public.contributions where group_id=new.group_id and period_number=new.period_number and user_id=new.user_id and version=new.version;
 return new;
end; $$;
revoke all on function public.snapshot_contribution_evidence() from public,anon,authenticated;
create trigger contribution_evidence_history before insert on public.contribution_history for each row execute function public.snapshot_contribution_evidence();
create function public.submit_contribution_v2(p_group_id uuid,p_period integer,p_amount_kobo bigint,p_reference text,p_paid_on date,p_expected_version integer,p_receipt_path text,p_payment_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; c public.contributions; existing boolean; opening date; today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Access denied' using errcode='42501'; end if;
 if g.status<>'active' then raise exception 'Activate the group before recording contributions.' using errcode='22023'; end if;
 opening:=public.contribution_window_start(p_group_id,p_period);
 if opening is null or opening>today then raise exception 'This contribution period is not open yet.' using errcode='22023'; end if;
 if p_amount_kobo is null or p_amount_kobo<>g.contribution_kobo or p_reference is null or char_length(btrim(p_reference)) not between 3 and 120 or p_paid_on is null or p_paid_on<opening or p_paid_on>today or p_expected_version is null or p_expected_version<0 then raise exception 'Check the amount, payment date and reference.' using errcode='22023'; end if;
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

-- Keep old clients compatible; a corrected report explicitly clears old evidence.
create or replace function public.submit_contribution(p_group_id uuid,p_period integer,p_amount_kobo bigint,p_reference text,p_paid_on date,p_expected_version integer) returns jsonb language sql security definer set search_path='' as $$
 select public.submit_contribution_v2(p_group_id,p_period,p_amount_kobo,p_reference,p_paid_on,p_expected_version,null,null);
$$;
revoke all on function public.submit_contribution_v2(uuid,integer,bigint,text,date,integer,text,text) from public,anon;
grant execute on function public.submit_contribution_v2(uuid,integer,bigint,text,date,integer,text,text) to authenticated;

create table public.group_messages(
 sequence bigint generated always as identity primary key,
 group_id uuid not null references public.savings_groups(id),
 user_id uuid not null references auth.users(id),
 request_id text not null check(request_id ~ '^[0-9a-f]{32}$'),
 body text not null check(char_length(btrim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 unique(group_id,user_id,request_id),
 foreign key(group_id,user_id) references public.group_members(group_id,user_id)
);
create index group_messages_page on public.group_messages(group_id,sequence desc);
alter table public.group_messages enable row level security;
revoke all on public.group_messages from public,anon,authenticated;
create function public.list_group_messages(p_group_id uuid,p_before bigint default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select coalesce(jsonb_agg(to_jsonb(page) order by sequence),'[]') into result from (
 select m.sequence,m.group_id,m.user_id,m.body,m.created_at,coalesce(nullif(btrim(p.full_name),''),'Member') as sender_name,(m.user_id=g.created_by) as is_leader
 from public.group_messages m join public.savings_groups g on g.id=m.group_id left join public.profiles p on p.id=m.user_id where m.group_id=p_group_id and (p_before is null or m.sequence<p_before) order by m.sequence desc limit 50
 ) page;
 return result;
end; $$;
create function public.send_group_message(p_group_id uuid,p_request_id text,p_body text) returns bigint language plpgsql security definer set search_path='' as $$
declare existing public.group_messages; result bigint;
begin
 perform 1 from public.savings_groups where id=p_group_id for update;
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 if p_request_id is null or p_request_id !~ '^[0-9a-f]{32}$' or p_body is null or char_length(btrim(p_body)) not between 1 and 2000 then raise exception 'Write a message between 1 and 2000 characters' using errcode='22023'; end if;
 select * into existing from public.group_messages where group_id=p_group_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
 if existing.body<>btrim(p_body) then raise exception 'Message request already used' using errcode='22023'; end if;
 return existing.sequence;
 end if;
 if (select count(*) from public.group_messages where group_id=p_group_id and user_id=auth.uid() and created_at>now()-interval '1 minute')>=30 then raise exception 'Please wait before sending more messages' using errcode='22023'; end if;
 insert into public.group_messages(group_id,user_id,request_id,body) values(p_group_id,auth.uid(),p_request_id,btrim(p_body)) returning sequence into result;
 return result;
end; $$;
revoke all on function public.list_group_messages(uuid,bigint),public.send_group_message(uuid,text,text) from public,anon;
grant execute on function public.list_group_messages(uuid,bigint),public.send_group_message(uuid,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
