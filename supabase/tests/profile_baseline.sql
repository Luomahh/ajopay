-- After the fresh baseline and ALL migrations. Synthetic fixtures roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000991','baseline-owner@example.invalid','{"full_name":"Baseline Owner","contact_phone":"+2348012345678","trust_score":100,"created_at":"2000-01-01"}'),
 ('00000000-0000-4000-8000-000000000992','baseline-other@example.invalid','{"full_name":"Baseline Other"}'),
 ('00000000-0000-4000-8000-000000000993','baseline-oauth@example.invalid','{}');
do $$
declare n integer;
begin
 if not exists(select 1 from public.profiles where id='00000000-0000-4000-8000-000000000991' and full_name='Baseline Owner' and phone='+2348012345678' and trust_score=0 and created_at=transaction_timestamp()) then raise exception 'Signup defaults or metadata isolation failed'; end if;
 if not exists(select 1 from public.member_profiles where user_id='00000000-0000-4000-8000-000000000991' and display_name='Baseline Owner' and phone='+2348012345678' and not share_phone) then raise exception 'Contact signup trigger did not run'; end if;
 if not exists(select 1 from public.profiles where id='00000000-0000-4000-8000-000000000993' and full_name='' and phone='' and trust_score=0) then raise exception 'Incomplete OAuth signup failed'; end if;
 if exists(select 1 from public.member_profiles where user_id='00000000-0000-4000-8000-000000000993') then raise exception 'Incomplete signup unexpectedly completed contact profile'; end if;
 if has_function_privilege('authenticated','public.handle_new_user()','EXECUTE') or has_function_privilege('anon','public.handle_new_user()','EXECUTE') then raise exception 'Signup function directly executable'; end if;
 execute 'set local role authenticated';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000991',true);
 select count(*) into n from public.profiles;
 if n<>1 then raise exception 'Own-profile read scope failed'; end if;
 update public.profiles set full_name='Updated Owner', phone='+2348098765432' where id='00000000-0000-4000-8000-000000000991';
 if not exists(select 1 from public.profiles where full_name='Updated Owner' and phone='+2348098765432') then raise exception 'Own fields not editable'; end if;
 update public.profiles set full_name='Intrusion' where id='00000000-0000-4000-8000-000000000992';
 get diagnostics n = row_count;
 if n<>0 then raise exception 'Outsider update allowed'; end if;
 begin update public.profiles set trust_score=100; raise exception 'Score spoof accepted'; exception when insufficient_privilege then null; end;
 begin update public.profiles set created_at='2000-01-01'; raise exception 'Timestamp spoof accepted'; exception when insufficient_privilege then null; end;
 begin update public.profiles set id='00000000-0000-4000-8000-000000000992'; raise exception 'Identity change accepted'; exception when insufficient_privilege then null; end;
 begin delete from public.profiles; raise exception 'Client delete accepted'; exception when insufficient_privilege then null; end;
 execute 'reset role';
 -- Remove only a synthetic baseline row to exercise the permitted fallback insert.
 delete from public.profiles where id='00000000-0000-4000-8000-000000000993';
 execute 'set local role authenticated';
 begin insert into public.profiles(id,full_name) values('00000000-0000-4000-8000-000000000993','Intrusion'); raise exception 'Outsider insert accepted'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000993',true);
 begin insert into public.profiles(id,trust_score) values('00000000-0000-4000-8000-000000000993',100); raise exception 'Insert score spoof accepted'; exception when insufficient_privilege then null; end;
 insert into public.profiles(id,full_name,phone) values('00000000-0000-4000-8000-000000000993','Completed OAuth','');
 if not exists(select 1 from public.profiles where full_name='Completed OAuth' and trust_score=0) then raise exception 'Own fallback insert failed'; end if;
 execute 'reset role';
 execute 'set local role anon';
 begin perform 1 from public.profiles; raise exception 'Anonymous read accepted'; exception when insufficient_privilege then null; end;
 begin insert into public.profiles(id) values('00000000-0000-4000-8000-000000000993'); raise exception 'Anonymous write accepted'; exception when insufficient_privilege then null; end;
 execute 'reset role';
end;
$$;
rollback;
select 'PASS: profile baseline, signup triggers, OAuth defaults, owner scope and server-owned fields' as result;
