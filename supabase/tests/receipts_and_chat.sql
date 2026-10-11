-- Metadata-only Storage policy tests; fixtures and records all roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-8000-000000000401','receipt-leader@example.invalid','{"full_name":"Leader"}'),
('00000000-0000-4000-8000-000000000402','receipt-member@example.invalid','{"full_name":"Member"}'),
('00000000-0000-4000-8000-000000000403','receipt-peer@example.invalid','{"full_name":"Peer"}'),
('00000000-0000-4000-8000-000000000404','receipt-outsider@example.invalid','{"full_name":"Outsider"}');
do $$
declare g jsonb; t jsonb; gid uuid; path text; other_path text; seq bigint; n integer; today date:=(now() at time zone 'Africa/Lagos')::date; member_id uuid:='00000000-0000-4000-8000-000000000402';
begin
if not exists(select 1 from storage.buckets where id='payment-receipts' and public=false and file_size_limit=5242880 and allowed_mime_types=array['image/png','image/jpeg','image/webp']) then raise exception 'bucket constraints wrong';end if;
execute 'set local role authenticated';
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',true);
g:=public.create_savings_group_v2(repeat('6',32),'Evidence circle',1000000,3,today+2,'target','weekly',today+9);gid:=(g->>'id')::uuid;
perform set_config('request.jwt.claim.sub',member_id::text,true);
perform public.join_savings_group(g->>'invite_code');
path:=gid::text||'/'||member_id::text||'/'||repeat('a',32)||'.png';
other_path:=gid::text||'/00000000-0000-4000-8000-000000000401/'||repeat('b',32)||'.png';
begin insert into storage.objects(bucket_id,name) values('payment-receipts',path);raise exception 'draft upload allowed';exception when insufficient_privilege then null;end;
seq:=public.send_group_message(gid,repeat('1',32),'Hello leader');
if public.send_group_message(gid,repeat('1',32),'Hello leader')<>seq then raise exception 'duplicate chat';end if;
begin perform public.send_group_message(gid,repeat('1',32),'Changed message');raise exception 'changed retry accepted';exception when invalid_parameter_value then null;end;
begin perform public.send_group_message(gid,repeat('2',32),'   ');raise exception 'empty chat accepted';exception when invalid_parameter_value then null;end;
begin perform public.send_group_message(gid,repeat('2',32),repeat('x',2001));raise exception 'oversize chat accepted';exception when invalid_parameter_value then null;end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000403',true);
perform public.join_savings_group(g->>'invite_code');perform public.accept_group_terms(gid,1);
perform set_config('request.jwt.claim.sub',member_id::text,true);perform public.accept_group_terms(gid,1);
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',true);perform public.accept_group_terms(gid,1);perform public.activate_savings_group(gid,1);
perform set_config('request.jwt.claim.sub',member_id::text,true);
begin insert into storage.objects(bucket_id,name) values('payment-receipts',other_path);raise exception 'spoofed upload';exception when insufficient_privilege then null;end;
begin insert into storage.objects(bucket_id,name) values('payment-receipts',replace(path,'.png','.html'));raise exception 'invalid upload type';exception when insufficient_privilege then null;end;
insert into storage.objects(bucket_id,name,metadata) values('payment-receipts',path,'{"mimetype":"image/png","size":100}');
if not public.can_read_receipt(path) then raise exception 'uploader cannot view';end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',true);
if public.can_read_receipt(path) then raise exception 'leader saw unsubmitted receipt';end if;
perform set_config('request.jwt.claim.sub',member_id::text,true);
begin perform public.submit_contribution_v2(gid,1,1000000,'receipt-ref',today,0,other_path,'note');raise exception 'foreign receipt accepted';exception when insufficient_privilege then null;end;
begin perform public.submit_contribution_v2(gid,1,1000000,'receipt-ref',today,0,path,repeat('x',501));raise exception 'oversize note accepted';exception when invalid_parameter_value then null;end;
t:=public.submit_contribution_v2(gid,1,1000000,'receipt-ref',today,0,path,' Paid Thursday ');
t:=public.submit_contribution_v2(gid,1,1000000,'receipt-ref',today,0,path,'Paid Thursday');
if jsonb_array_length(t->'history')<>1 or t->'contributions'->0->>'receipt_path'<>path or t->'history'->0->>'payment_note'<>'Paid Thursday' then raise exception 'evidence or retry failed';end if;
begin perform public.submit_contribution_v2(gid,1,1000000,'receipt-ref',today,0,path,'Edited after submit');raise exception 'evidence changed after submit';exception when invalid_parameter_value then null;end;
update storage.objects set metadata='{}' where bucket_id='payment-receipts' and name=path;get diagnostics n=row_count;if n<>0 then raise exception 'receipt mutable';end if;
begin
delete from storage.objects where bucket_id='payment-receipts' and name=path;get diagnostics n=row_count;if n<>0 then raise exception 'receipt deletable';end if;
exception when insufficient_privilege then null;end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',true);
select count(*) into n from storage.objects where bucket_id='payment-receipts' and name=path;if n<>1 then raise exception 'leader cannot read receipt';end if;
t:=public.review_contribution(gid,1,member_id,1,false,'Please correct reference');
if jsonb_array_length(t->'history')<>2 then raise exception 'review history missing';end if;
perform set_config('request.jwt.claim.sub',member_id::text,true);
t:=public.submit_contribution_v2(gid,1,1000000,'corrected-ref',today,1,null,null);
if t->'contributions'->0->>'receipt_path' is not null then raise exception 'correction failed to remove receipt';end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',true);
if not public.can_read_receipt(path) then raise exception 'historical receipt lost';end if;
perform public.send_group_message(gid,repeat('3',32),'Welcome');
t:=public.list_group_messages(gid,null);if jsonb_array_length(t)<>2 or t->1->>'is_leader'<>'true' then raise exception 'chat sender or ordering wrong';end if;
t:=public.list_group_messages(gid,(t->1->>'sequence')::bigint);if jsonb_array_length(t)<>1 then raise exception 'chat cursor failed';end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000403',true);
select count(*) into n from storage.objects where bucket_id='payment-receipts' and name=path;if n<>0 then raise exception 'peer saw receipt';end if;
if public.can_read_receipt(path) then raise exception 'peer receipt helper leak';end if;
if jsonb_array_length(public.list_group_messages(gid,null))<>2 then raise exception 'peer cannot chat';end if;
begin perform 1 from public.group_messages;raise exception 'raw chat read allowed';exception when insufficient_privilege then null;end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000404',true);
begin perform public.list_group_messages(gid,null);raise exception 'outsider read chat';exception when insufficient_privilege then null;end;
begin perform public.send_group_message(gid,repeat('4',32),'Outsider');raise exception 'outsider sent chat';exception when insufficient_privilege then null;end;
if public.can_read_receipt(path) then raise exception 'outsider receipt leak';end if;
execute 'set local role anon';
begin perform public.list_group_messages(gid,null);raise exception 'anon read chat';exception when insufficient_privilege then null;end;
execute 'reset role';
end; $$;
rollback;
select 'PASS: private receipts, immutable evidence, notes, history, member-only chat, retries and pagination' as result;
