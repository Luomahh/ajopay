-- Run as postgres; synthetic records only. All changes roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
('00000000-0000-4000-8000-000000000601','rules-leader@example.invalid','{"full_name":"Leader"}'),
('00000000-0000-4000-8000-000000000602','rules-member@example.invalid','{"full_name":"Member"}'),
('00000000-0000-4000-8000-000000000603','rules-outsider@example.invalid','{"full_name":"Outsider"}');
do $$
declare
 leader uuid:='00000000-0000-4000-8000-000000000601'; member uuid:='00000000-0000-4000-8000-000000000602'; outsider uuid:='00000000-0000-4000-8000-000000000603';
 g jsonb; d jsonb; gid uuid; v integer; t uuid:=gen_random_uuid(); rot uuid:=gen_random_uuid(); n integer; e record; total bigint;
 today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 execute 'set local role authenticated'; perform set_config('request.jwt.claim.sub',leader::text,true);
 g:=public.create_savings_group_v3(repeat('6',32),'Weekly monthly circle',1000000,2,today+1,'rotating','weekly',null,'monthly',today+29);gid:=(g->>'id')::uuid;
 if (g->>'rules_version')::int<>2 or (g->>'late_fee_kobo')::bigint<>20000 then raise exception 'new terms missing';end if;
 if public.create_savings_group_v3(repeat('6',32),'Weekly monthly circle',1000000,2,today+1,'rotating','weekly',null,'monthly',today+29)->>'id'<>gid::text then raise exception 'retry duplicated';end if;
 begin perform public.create_savings_group_v3(repeat('6',32),'Weekly monthly circle',1000000,2,today+1,'rotating','weekly',null,'monthly',today+28);raise exception 'changed schedule retry allowed';exception when unique_violation then null;end;
 begin perform public.create_savings_group_v3(repeat('7',32),'Invalid pace',1000000,2,today+1,'rotating','monthly',null,'weekly',today+1);raise exception 'faster payout allowed';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub',member::text,true);perform public.join_savings_group(g->>'invite_code');
 begin perform public.set_group_bank_account(gid,'Test Bank','Leader Name','1234567890');raise exception 'member changed account';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',leader::text,true);d:=public.prepare_group_order(gid);v:=(d->'group'->>'terms_version')::int;
 perform public.accept_group_terms(gid,v);
 perform public.set_group_bank_account(gid,'Test Bank','Leader Name','1234567890');d:=public.get_group_details(gid);
 if (d->'group'->>'terms_version')::int<>v+1 or exists(select 1 from jsonb_array_elements(d->'members') m where m->>'accepted_terms_version' is not null) then raise exception 'bank change did not reset consent';end if;
 perform public.set_group_bank_account(gid,'Test Bank','Leader Name','1234567890');d:=public.get_group_details(gid);if (d->'group'->>'terms_version')::int<>v+1 then raise exception 'account retry reset terms';end if;
 v:=v+1;perform public.accept_group_terms(gid,v);
 perform set_config('request.jwt.claim.sub',member::text,true);perform public.accept_group_terms(gid,v);
 select count(*) into n from public.group_bank_accounts where group_id=gid;if n<>1 then raise exception 'member cannot read bank';end if;
 perform set_config('request.jwt.claim.sub',leader::text,true);d:=public.activate_savings_group(gid,v);
 if jsonb_array_length(d->'periods')<8 then raise exception 'contributions still tied to member count';end if;
 select count(*) into n from public.group_payout_schedule where group_id=gid;if n<>2 then raise exception 'payout count incorrect';end if;
 begin perform public.set_group_bank_account(gid,'Other Bank','Leader Name','0987654321');raise exception 'active account changed';exception when invalid_parameter_value then null;end;
 insert into public.member_profiles(user_id,display_name,phone,city,bio) values(leader,'Updated Leader','08012345678','Lagos','Saving for a goal');
 perform set_config('request.jwt.claim.sub',member::text,true);d:=public.get_member_profile(gid,leader);
 if d->>'display_name'<>'Updated Leader' or d ? 'phone' then raise exception 'profile sharing wrong';end if;
 select count(*) into n from public.member_profiles where user_id=leader;if n<>0 then raise exception 'private profile leak';end if;
 begin insert into public.member_profiles(user_id,display_name) values(outsider,'Forged');raise exception 'profile spoofed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 select count(*) into n from public.group_bank_accounts where group_id=gid;if n<>0 then raise exception 'bank account leak';end if;
 begin perform public.get_member_profile(gid,leader);raise exception 'outsider profile read';exception when insufficient_privilege then null;end;
 begin perform public.get_late_fees(gid);raise exception 'outsider fee read';exception when insufficient_privilege then null;end;
 execute 'reset role';
 -- Historical target fixture: extras belong to the member and never include fees.
 insert into public.savings_groups(id,created_by,request_id,name,contribution_kobo,member_limit,first_payout_date,end_date,status,savings_mode,frequency,rules_version,late_fee_kobo)
 values(t,leader,repeat('8',32),'Flexible target',1000000,2,today-1,today,'active','target','daily',2,20000);
 insert into public.group_members(group_id,user_id,role) values(t,leader,'owner'),(t,member,'member');
 insert into public.group_periods values(t,1,today-1,null),(t,2,today,null);
 execute 'set local role authenticated';perform set_config('request.jwt.claim.sub',member::text,true);
 begin perform public.submit_contribution_v2(t,1,999999,'short',today,0,null,null);raise exception 'underpayment accepted';exception when invalid_parameter_value then null;end;
 perform public.submit_contribution_v2(t,1,1500000,'extra-one',today,0,null,null);
 perform public.submit_contribution_v2(t,1,1500000,'extra-one',today,0,null,null);
 perform public.submit_contribution_v2(t,2,1200000,'extra-two',today,0,null,null);
 perform set_config('request.jwt.claim.sub',leader::text,true);
 perform public.submit_contribution_v2(t,1,1000000,'leader-one',today-1,0,null,null);
 perform public.submit_contribution_v2(t,2,1000000,'leader-two',today,0,null,null);
 perform public.review_contribution(t,1,member,1,true,'');perform public.review_contribution(t,2,member,1,true,'');
 perform public.review_contribution(t,1,leader,1,true,'');perform public.review_contribution(t,2,leader,1,true,'');
 d:=public.get_late_fees(t);if jsonb_array_length(d)<>1 or (d->0->>'amount_kobo')::int<>20000 or d->0->>'user_id'<>member::text or d->0->>'status'<>'due' then raise exception 'fee amount/date/duplicate error';end if;
 perform set_config('request.jwt.claim.sub',member::text,true);if jsonb_array_length(public.get_late_fees(t))<>1 then raise exception 'member fee hidden';end if;
 execute 'reset role';
 select * into e from public.payout_entitlements(t) where recipient_id=member;
 if e.amount_kobo<>2700000 or e.confirmed_pool_kobo<>4700000 or not e.funded then raise exception 'extra savings entitlement wrong';end if;
 select sum(amount_kobo) into total from public.payout_entitlements(t);if total<>4700000 then raise exception 'payout conservation failed';end if;
 execute 'set local role authenticated';perform set_config('request.jwt.claim.sub',leader::text,true);
 perform public.record_payout(t,0,member,2700000,'target-full-extra',today,0,null);
 execute 'reset role';
 -- Five weekly deadlines in January and four in February: no flattened four-week assumption.
 insert into public.savings_groups(id,created_by,request_id,name,contribution_kobo,member_limit,first_payout_date,status,savings_mode,frequency,rules_version,payout_frequency,first_collection_date)
 values(rot,leader,repeat('9',32),'Calendar weeks',1000000,2,'2026-01-01','active','rotating','weekly',2,'monthly','2026-01-31');
 insert into public.group_members(group_id,user_id,role) values(rot,leader,'owner'),(rot,member,'member');
 insert into public.group_periods select rot,i+1,'2026-01-01'::date+7*i,null from generate_series(0,8) i;
 insert into public.group_payout_schedule values(rot,1,leader,'2026-01-31'),(rot,2,member,'2026-02-28');
 execute 'set local role authenticated';perform set_config('request.jwt.claim.sub',leader::text,true);
 begin perform public.submit_contribution_v2(rot,1,1000100,'overpay',today,0,null,null);raise exception 'rotating overpayment accepted';exception when invalid_parameter_value then null;end;
 execute 'reset role';
 insert into public.contributions(group_id,period_number,user_id,amount_kobo,payment_reference,paid_on,status,version)
 select rot,p.period_number,m.user_id,1000000,'week-'||p.period_number,p.due_date,'confirmed',1 from public.group_periods p cross join public.group_members m where p.group_id=rot and m.group_id=rot;
 select * into e from public.payout_entitlements(rot) where slot=1;if e.amount_kobo<>10000000 or not e.funded then raise exception 'five week payout wrong';end if;
 select * into e from public.payout_entitlements(rot) where slot=2;if e.amount_kobo<>8000000 or not e.funded or e.previous_complete then raise exception 'four week payout/order wrong';end if;
 execute 'set local role authenticated';perform set_config('request.jwt.claim.sub',leader::text,true);
 perform public.record_payout(rot,1,leader,10000000,'january-pot',today,0,null);perform public.acknowledge_payout(rot,1,1,true,null);
 perform public.record_payout(rot,2,member,8000000,'february-pot',today,0,null);
 perform set_config('request.jwt.claim.sub',member::text,true);d:=public.acknowledge_payout(rot,2,1,true,null);if d->>'group_status'<>'completed' then raise exception 'new round not complete';end if;
 execute 'reset role';
end; $$;
rollback;
select 'PASS: independent schedules, actual weeks, minimum/exact amounts, extra savings payouts, separate late fees, profile privacy, account consent and locking' as result;
