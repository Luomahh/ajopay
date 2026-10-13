begin;
alter table public.member_profiles add column home_address text not null default '' check(char_length(home_address)<=300), add column share_phone boolean not null default false;
-- Existing phone numbers remain private until the owner explicitly opts in.
create or replace function public.get_member_profile(p_group_id uuid,p_user_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=p_user_id) then raise exception 'Group access denied' using errcode='42501'; end if;
 return (select jsonb_strip_nulls(jsonb_build_object('display_name',coalesce(m.display_name,p.full_name,'Member'),'bio',coalesce(m.bio,''),'city',coalesce(m.city,''),'phone',case when m.share_phone then nullif(m.phone,'') end)) from public.profiles p left join public.member_profiles m on m.user_id=p.id where p.id=p_user_id);
end; $$;
create function public.seed_member_contact() returns trigger
language plpgsql security definer set search_path='' as $$
declare label text:=btrim(coalesce(new.raw_user_meta_data->>'full_name','')); contact text:=coalesce(new.raw_user_meta_data->>'contact_phone','');
begin
 if char_length(label) between 2 and 80 then
  insert into public.member_profiles(user_id,display_name,phone,share_phone)
  values(new.id,label,case when contact ~ '^\+[1-9][0-9]{7,14}$' then contact else '' end,coalesce(new.raw_user_meta_data->>'share_phone'='true',false)) on conflict(user_id) do nothing;
 end if;
 return new;
end; $$;
revoke all on function public.seed_member_contact() from public,anon,authenticated;
create trigger zz_seed_member_contact after insert on auth.users for each row execute function public.seed_member_contact();

create function public.get_group_statement(p_group_id uuid,p_from date default null,p_to date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare g public.savings_groups; entries jsonb;
begin
 select * into g from public.savings_groups where id=p_group_id;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise exception 'Choose a date range of up to one year' using errcode='22023'; end if;
 select coalesce(jsonb_agg(to_jsonb(rows) order by rows.paid_on,rows.recorded_at,rows.kind,rows.period,rows.user_id),'[]') into entries from (
  select 'contribution'::text as kind,c.user_id,coalesce(nullif(btrim(pr.full_name),''),'Member') as member_name,c.period_number as period,c.amount_kobo,c.paid_on,c.submitted_at as recorded_at,c.status,c.payment_reference as reference
  from public.contributions c left join public.profiles pr on pr.id=c.user_id where c.group_id=p_group_id and c.paid_on between p_from and p_to and (g.created_by=auth.uid() or c.user_id=auth.uid())
  union all
  select 'payout',p.recipient_id,coalesce(nullif(btrim(pr.full_name),''),'Member'),p.slot,p.amount_kobo,p.paid_on,p.recorded_at,p.status,p.transfer_reference
  from public.payouts p left join public.profiles pr on pr.id=p.recipient_id where p.group_id=p_group_id and p.paid_on between p_from and p_to and (g.created_by=auth.uid() or p.recipient_id=auth.uid())
 ) rows;
 if jsonb_array_length(entries)>5000 then raise exception 'Choose a shorter date range (maximum 5000 records)' using errcode='22023'; end if;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'group_id',g.id,'group_name',g.name,'group_status',g.status,'scope',case when g.created_by=auth.uid() then 'Group leader - all members' else 'Member - own records' end,'generated_at',now(),'entries',entries,'late_fees',(select coalesce(jsonb_agg(fee),'[]') from jsonb_array_elements(public.get_late_fees(p_group_id)) fee where (fee->>'due_date')::date between p_from and p_to));
end; $$;
revoke all on function public.get_group_statement(uuid,date,date) from public,anon;
grant execute on function public.get_group_statement(uuid,date,date) to authenticated;
notify pgrst,'reload schema';
commit;
