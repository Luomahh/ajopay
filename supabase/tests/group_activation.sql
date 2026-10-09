-- Run as postgres; synthetic fixtures and all writes roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-8000-000000000201','ajo-owner@example.invalid','{"full_name":"Ada"}'),
('00000000-0000-4000-8000-000000000202','ajo-member@example.invalid','{"full_name":"Tunde"}'),
('00000000-0000-4000-8000-000000000203','ajo-outsider@example.invalid','{"full_name":"Outsider"}');
do $$
declare g jsonb; d jsonb; prior jsonb; gid uuid; code text; n integer;
begin
execute 'set local role authenticated';
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
g:=public.create_savings_group_v2(repeat('e',32),'Test circle',500000,2,current_date+30,'rotating','monthly',null);
gid:=(g->>'id')::uuid; code:=g->>'invite_code';
if public.create_savings_group_v2(repeat('e',32),'Test circle',500000,2,current_date+30,'rotating','monthly',null)->>'id'<>g->>'id' then raise exception 'duplicate create'; end if;
begin perform public.create_savings_group_v2(repeat('e',32),'Changed',500000,2,current_date+30,'rotating','monthly',null); raise exception 'changed retry allowed'; exception when unique_violation then null; end;
begin perform public.prepare_group_order(gid); raise exception 'partial order allowed'; exception when invalid_parameter_value then null; end;
begin perform public.activate_savings_group(gid,1); raise exception 'partial activation allowed'; exception when invalid_parameter_value then null; end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000202',true);
begin perform public.get_group_details(gid); raise exception 'outsider details allowed'; exception when insufficient_privilege then null; end;
begin perform public.join_savings_group('invalid'); raise exception 'invalid invite allowed'; exception when invalid_parameter_value then null; end;
perform public.join_savings_group(code); perform public.join_savings_group(code);
d:=public.get_group_details(gid);
if jsonb_array_length(d->'members')<>2 then raise exception 'join duplicated'; end if;
begin perform public.prepare_group_order(gid); raise exception 'member prepared order'; exception when insufficient_privilege then null; end;
begin perform public.activate_savings_group(gid,1); raise exception 'member activated'; exception when insufficient_privilege then null; end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000203',true);
begin perform public.join_savings_group(code); raise exception 'capacity exceeded'; exception when invalid_parameter_value then null; end;
select count(*) into n from public.savings_groups where id=gid; if n<>0 then raise exception 'RLS group leak'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
d:=public.prepare_group_order(gid); prior:=public.prepare_group_order(gid);
if d<>prior or (d->'group'->>'terms_version')::int<>2 then raise exception 'reshuffled'; end if;
begin perform public.accept_group_terms(gid,1); raise exception 'stale agreement allowed'; exception when invalid_parameter_value then null; end;
perform public.accept_group_terms(gid,2); perform public.accept_group_terms(gid,2);
begin perform public.activate_savings_group(gid,2); raise exception 'missing agreement allowed'; exception when invalid_parameter_value then null; end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000202',true);
perform public.accept_group_terms(gid,2);
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
d:=public.activate_savings_group(gid,2); prior:=public.activate_savings_group(gid,2);
if d<>prior or d->'group'->>'status'<>'active' or jsonb_array_length(d->'periods')<>2 then raise exception 'activation or retry wrong'; end if;
select count(distinct recipient_id) into n from public.group_periods where group_id=gid; if n<>2 then raise exception 'recipient schedule wrong'; end if;
begin update public.savings_groups set status='draft' where id=gid; raise exception 'direct write allowed'; exception when insufficient_privilege then null; end;
begin update public.group_members set accepted_terms_version=99 where group_id=gid; raise exception 'agreement tampering allowed'; exception when insufficient_privilege then null; end;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000203',true);
begin perform public.join_savings_group(code); raise exception 'active join allowed'; exception when invalid_parameter_value then null; end;
select count(*) into n from public.group_periods where group_id=gid; if n<>0 then raise exception 'schedule RLS leak'; end if;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
g:=public.create_savings_group_v2(repeat('f',32),'Weekly target',2000000,2,current_date+30,'target','weekly',current_date+44);
gid:=(g->>'id')::uuid;
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000202',true);
perform public.join_savings_group(g->>'invite_code'); perform public.accept_group_terms(gid,1);
perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
perform public.accept_group_terms(gid,1); d:=public.activate_savings_group(gid,1);
if jsonb_array_length(d->'periods')<>3 then raise exception 'weekly inclusive schedule wrong'; end if;
select count(*) into n from public.group_periods where group_id=gid and recipient_id is not null; if n<>0 then raise exception 'target recipient wrong'; end if;
perform set_config('request.jwt.claim.sub','',true);
begin perform public.get_group_details(gid); raise exception 'missing identity allowed'; exception when insufficient_privilege then null; end;
execute 'set local role anon';
begin perform public.get_group_details(gid); raise exception 'anonymous details allowed'; exception when insufficient_privilege then null; end;
execute 'reset role';
end; $$;
rollback;
select 'PASS: creation, joining, membership privacy, consent, activation, retries and schedules' as result;
