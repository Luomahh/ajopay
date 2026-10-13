begin;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-8000-000000000801','chat-owner@example.invalid','{"full_name":"Owner"}'),
('00000000-0000-4000-8000-000000000802','chat-member@example.invalid','{"full_name":"Member"}'),
('00000000-0000-4000-8000-000000000803','chat-outsider@example.invalid','{"full_name":"Outsider"}');
do $$
declare g jsonb; gid uuid; seq bigint; messages jsonb;
begin
execute 'set local role authenticated';
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000801',true);
g:=public.create_savings_group_v2(repeat('e',32),'Chat test',1000000,2,current_date+3,'target','weekly',current_date+10); gid:=(g->>'id')::uuid;
seq:=public.send_group_message(gid,repeat('f',32),'Keep this 😀');
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000802',true);
perform public.join_savings_group(g->>'invite_code');
begin perform public.remove_group_message(gid,seq,true); raise exception 'member unsent peer message'; exception when insufficient_privilege then null; end;
perform public.remove_group_message(gid,seq,false);
perform public.remove_group_message(gid,seq,false);
messages:=public.list_group_messages(gid,null);
if messages->0->>'hidden'<>'true' or messages->0->>'body'<>'' then raise exception 'hide failed'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000801',true);
messages:=public.list_group_messages(gid,null);
if messages->0->>'body'<>'Keep this 😀' or messages->0->>'hidden'<>'false' then raise exception 'hide affected other users'; end if;
perform public.remove_group_message(gid,seq,true);
perform public.remove_group_message(gid,seq,true);
messages:=public.list_group_messages(gid,null);
if messages->0->>'body'<>'Message removed' or messages->0->>'removed'<>'true' then raise exception 'unsend failed'; end if;
begin perform public.send_group_message(gid,repeat('f',32),'Keep this 😀'); raise exception 'retry revived removed message'; exception when invalid_parameter_value then null; end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000803',true);
begin perform public.remove_group_message(gid,seq,false); raise exception 'outsider hid message'; exception when insufficient_privilege then null; end;
begin perform 1 from public.group_message_hides; raise exception 'raw hides readable'; exception when insufficient_privilege then null; end;
execute 'set local role anon';
begin perform public.remove_group_message(gid,seq,true); raise exception 'anonymous unsend'; exception when insufficient_privilege then null; end;
execute 'reset role';
if (select body from public.group_messages where sequence=seq)<>'Message removed' then raise exception 'original text retained'; end if;
end; $$;
rollback;
select 'PASS: sender-only unsend, private per-user hide, retry safety, outsider denial and original text removal' as result;
