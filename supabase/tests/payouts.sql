-- Synthetic historical rounds only, entirely rolled back. No money is transferred.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000501','payout-leader@example.invalid','{"full_name":"Leader"}'),
 ('00000000-0000-4000-8000-000000000502','payout-member@example.invalid','{"full_name":"Member"}'),
 ('00000000-0000-4000-8000-000000000503','payout-peer@example.invalid','{"full_name":"Peer"}'),
 ('00000000-0000-4000-8000-000000000504','payout-outsider@example.invalid','{"full_name":"Outsider"}');
do $$
declare
 leader uuid:='00000000-0000-4000-8000-000000000501'; member uuid:='00000000-0000-4000-8000-000000000502';
 peer uuid:='00000000-0000-4000-8000-000000000503'; outsider uuid:='00000000-0000-4000-8000-000000000504';
 gid uuid:=gen_random_uuid(); target uuid:=gen_random_uuid(); today date:=(now() at time zone 'Africa/Lagos')::date;
 t jsonb; row_data jsonb; n integer;
begin
 -- Backdated fixtures allow deterministic full-round checks without changing real groups or the server clock.
 insert into public.savings_groups(id,created_by,request_id,name,contribution_kobo,member_limit,first_payout_date,status,savings_mode,frequency,order_prepared)
 values(gid,leader,repeat('a',32),'Payout test rotating',1000000,3,today-2,'active','rotating','daily',true);
 insert into public.group_members(group_id,user_id,role,rotation_position) values(gid,leader,'owner',3),(gid,member,'member',1),(gid,peer,'member',2);
 insert into public.group_periods values(gid,1,today-2,member),(gid,2,today-1,peer),(gid,3,today,leader);
 insert into public.contributions(group_id,period_number,user_id,amount_kobo,payment_reference,paid_on,status,version)
 select gid,s.period_number,m.user_id,1000000,'demo-'||s.period_number,s.due_date,
 case when s.period_number=1 and m.user_id=member then 'pending' else 'confirmed' end,1
 from public.group_periods s cross join public.group_members m where s.group_id=gid and m.group_id=gid;
 execute 'set local role authenticated';
 perform set_config('request.jwt.claim.sub',leader::text,true);
 t:=public.get_payout_tracker(gid);
 if t->'payouts'->0->>'status'<>'collecting' or (t->'payouts'->0->>'shortfall_kobo')::bigint<>1000000 then raise exception 'shortfall incorrect';end if;
 begin perform public.record_payout(gid,1,member,3000000,'payout-1',today,0,'');raise exception 'shortfall paid out';exception when invalid_parameter_value then null;end;
 perform public.review_contribution(gid,1,member,1,true,'');
 -- Fully funded but future-dated payouts stay blocked.
 execute 'reset role'; update public.group_periods set due_date=today+1 where group_id=gid and period_number=1;
 execute 'set local role authenticated';
 if public.get_payout_tracker(gid)->'payouts'->0->>'status'<>'scheduled' then raise exception 'future payout ready';end if;
 begin perform public.record_payout(gid,1,member,3000000,'payout-1',today,0,'');raise exception 'early payout allowed';exception when invalid_parameter_value then null;end;
 execute 'reset role';update public.group_periods set due_date=today-2 where group_id=gid and period_number=1;execute 'set local role authenticated';
 begin perform public.record_payout(gid,2,peer,3000000,'payout-2',today,0,'');raise exception 'payout order bypassed';exception when invalid_parameter_value then null;end;
 begin perform public.record_payout(gid,1,peer,3000000,'payout-1',today,0,'');raise exception 'wrong recipient';exception when invalid_parameter_value then null;end;
 begin perform public.record_payout(gid,1,member,2999999,'payout-1',today,0,'');raise exception 'wrong amount';exception when invalid_parameter_value then null;end;
 begin perform public.record_payout(gid,1,member,3000000,'payout-1',today+1,0,'');raise exception 'future transfer';exception when invalid_parameter_value then null;end;
 begin perform public.record_payout(gid,1,member,3000000,'payout-1',today-3,0,'');raise exception 'transfer before schedule';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub',member::text,true);
 begin perform public.record_payout(gid,1,member,3000000,'payout-1',today,0,'');raise exception 'member recorded payout';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',leader::text,true);
 t:=public.record_payout(gid,1,member,3000000,'payout-1',today,0,'Leader private note');
 t:=public.record_payout(gid,1,member,3000000,'payout-1',today,0,'Leader private note');
 if jsonb_array_length(t->'history')<>1 then raise exception 'duplicate payout event';end if;
 begin perform public.acknowledge_payout(gid,1,1,true,'');raise exception 'leader acknowledged member payout';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',peer::text,true);
 t:=public.get_payout_tracker(gid);
 if t->'payouts'->0->>'transfer_reference' is not null or t->'payouts'->0->>'leader_note' is not null or jsonb_array_length(t->'history')<>0 then raise exception 'peer private details leak';end if;
 begin perform 1 from public.payouts;raise exception 'direct payout read';exception when insufficient_privilege then null;end;
 begin update public.payouts set status='confirmed' where group_id=gid;raise exception 'direct mutation';exception when insufficient_privilege then null;end;
 begin perform * from public.payout_entitlements(gid);raise exception 'internal helper exposed';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',member::text,true);
 t:=public.get_payout_tracker(gid);
 if t->'payouts'->0->>'transfer_reference'<>'payout-1' then raise exception 'recipient cannot see reference';end if;
 begin perform public.acknowledge_payout(gid,1,1,false,' ');raise exception 'empty problem accepted';exception when invalid_parameter_value then null;end;
 t:=public.acknowledge_payout(gid,1,1,false,'Not received');
 t:=public.acknowledge_payout(gid,1,1,false,'Not received');
 if jsonb_array_length(t->'history')<>2 then raise exception 'duplicate dispute';end if;
 perform set_config('request.jwt.claim.sub',leader::text,true);
 begin perform public.record_payout(gid,2,peer,3000000,'payout-2',today,0,'');raise exception 'dispute did not block next';exception when invalid_parameter_value then null;end;
 t:=public.record_payout(gid,1,member,3000000,'payout-1-corrected',today,1,'Corrected reference');
 if jsonb_array_length(t->'history')<>3 then raise exception 'correction history missing';end if;
 perform set_config('request.jwt.claim.sub',member::text,true);
 begin perform public.acknowledge_payout(gid,1,1,true,'');raise exception 'stale confirmation';exception when invalid_parameter_value then null;end;
 t:=public.acknowledge_payout(gid,1,2,true,'Received');
 t:=public.acknowledge_payout(gid,1,2,true,'Received');
 if t->>'group_status'<>'active' or jsonb_array_length(t->'history')<>4 then raise exception 'early completion or duplicate acknowledgement';end if;
 begin perform public.acknowledge_payout(gid,1,2,false,'Changed mind');raise exception 'confirmed payout changed';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub',leader::text,true);
 begin perform public.record_payout(gid,2,peer,3000000,'payout-1-corrected',today,0,'');raise exception 'duplicate reference';exception when unique_violation then null;end;
 perform public.record_payout(gid,2,peer,3000000,'payout-2',today,0,'');
 perform set_config('request.jwt.claim.sub',peer::text,true);
 perform public.acknowledge_payout(gid,2,1,false,'Bank delay');
 perform public.acknowledge_payout(gid,2,1,true,'Arrived later');
 perform set_config('request.jwt.claim.sub',leader::text,true);
 perform public.record_payout(gid,3,leader,3000000,'payout-3',today,0,'');
 t:=public.acknowledge_payout(gid,3,1,true,'');
 if t->>'group_status'<>'completed' then raise exception 'round not completed';end if;
 perform public.acknowledge_payout(gid,3,1,true,'');
 perform public.record_payout(gid,3,leader,3000000,'payout-3',today,0,'');
 if jsonb_array_length(public.get_contribution_tracker(gid)->'contributions')<>9 then raise exception 'completed history inaccessible';end if;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 begin perform public.get_payout_tracker(gid);raise exception 'outsider read';exception when insufficient_privilege then null;end;
 begin perform public.acknowledge_payout(gid,1,2,true,'');raise exception 'outsider acknowledgement';exception when insufficient_privilege then null;end;
 execute 'set local role anon';
 begin perform public.get_payout_tracker(gid);raise exception 'anon read';exception when insufficient_privilege then null;end;
 execute 'reset role';
 select count(*) into n from public.group_events where group_id=gid and action='group_completed';if n<>1 then raise exception 'duplicate completion';end if;
 select count(*) into n from public.payout_history where group_id=gid;if n<>9 then raise exception 'incorrect rotating history count: %',n;end if;

 -- Target savings: each member receives principal only, once, at the end.
 insert into public.savings_groups(id,created_by,request_id,name,contribution_kobo,member_limit,first_payout_date,end_date,status,savings_mode,frequency)
 values(target,leader,repeat('b',32),'Payout test target',1000000,2,today-2,today,'active','target','daily');
 insert into public.group_members(group_id,user_id,role) values(target,leader,'owner'),(target,member,'member');
 insert into public.group_periods values(target,1,today-2,null),(target,2,today-1,null),(target,3,today,null);
 insert into public.contributions(group_id,period_number,user_id,amount_kobo,payment_reference,paid_on,status,version)
 select target,s.period_number,m.user_id,1000000,'target-'||s.period_number,s.due_date,
 case when s.period_number=3 and m.user_id=member then 'pending' else 'confirmed' end,1
 from public.group_periods s cross join public.group_members m where s.group_id=target and m.group_id=target;
 execute 'set local role authenticated';perform set_config('request.jwt.claim.sub',leader::text,true);
 t:=public.get_payout_tracker(target);
 if jsonb_array_length(t->'payouts')<>2 or (t->'payouts'->0->>'amount_kobo')::bigint<>3000000 or (t->'payouts'->0->>'expected_pool_kobo')::bigint<>6000000 then raise exception 'target principal incorrect';end if;
 begin perform public.record_payout(target,0,leader,3000000,'target-out-1',today,0,'');raise exception 'target shortfall bypassed';exception when invalid_parameter_value then null;end;
 perform public.review_contribution(target,3,member,1,true,'');
 execute 'reset role';update public.savings_groups set end_date=today+1 where id=target;execute 'set local role authenticated';
 begin perform public.record_payout(target,0,leader,3000000,'target-out-1',today,0,'');raise exception 'target early payout';exception when invalid_parameter_value then null;end;
 execute 'reset role';update public.savings_groups set end_date=today where id=target;execute 'set local role authenticated';
 perform public.record_payout(target,0,leader,3000000,'target-out-1',today,0,'');
 perform public.record_payout(target,0,member,3000000,'target-out-2',today,0,'');
 t:=public.acknowledge_payout(target,0,1,true,'');
 if t->>'group_status'<>'active' then raise exception 'target completed early';end if;
 perform set_config('request.jwt.claim.sub',member::text,true);
 t:=public.get_payout_tracker(target);
 select value into row_data from jsonb_array_elements(t->'payouts') where value->>'recipient_id'=leader::text;
 if row_data->>'transfer_reference' is not null then raise exception 'target peer privacy';end if;
 t:=public.acknowledge_payout(target,0,1,true,'');
 if t->>'group_status'<>'completed' then raise exception 'target not completed';end if;
 execute 'reset role';
 select count(*) into n from public.payout_history where group_id=target;if n<>4 then raise exception 'target history incorrect';end if;
end; $$;
rollback;
select 'PASS: rotating and target payouts, funding/date/order guards, privacy, disputes, retries and round completion' as result;
