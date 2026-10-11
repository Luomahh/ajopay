begin;
-- Contact details remain private. No NIN or self-issued identity badges.
create table public.member_profiles (
 user_id uuid primary key references auth.users(id),
 display_name text not null check(char_length(btrim(display_name)) between 2 and 80),
 phone text not null default '' check(char_length(phone)<=24),
 bio text not null default '' check(char_length(bio)<=240),
 city text not null default '' check(char_length(city)<=80),
 updated_at timestamptz not null default now()
);
alter table public.member_profiles enable row level security;
revoke all on public.member_profiles from public,anon,authenticated;
grant select,insert,update on public.member_profiles to authenticated;
create policy own_profile_read on public.member_profiles for select to authenticated using(user_id=(select auth.uid()));
create policy own_profile_insert on public.member_profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy own_profile_update on public.member_profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create function public.sync_member_display_name() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.profiles set full_name=new.display_name where id=new.user_id;
 new.updated_at=now(); return new;
end; $$;
revoke all on function public.sync_member_display_name() from public,anon,authenticated;
create trigger sync_member_display_name before insert or update on public.member_profiles for each row execute function public.sync_member_display_name();

create table public.group_bank_accounts (
 group_id uuid primary key references public.savings_groups(id),
 bank_name text not null check(char_length(btrim(bank_name)) between 2 and 80),
 account_name text not null check(char_length(btrim(account_name)) between 2 and 120),
 account_number text not null check(account_number ~ '^[0-9]{10}$'),
 updated_at timestamptz not null default now()
);
alter table public.group_bank_accounts enable row level security;
revoke all on public.group_bank_accounts from public,anon,authenticated;
grant select on public.group_bank_accounts to authenticated;
create policy members_read_account on public.group_bank_accounts for select to authenticated using(exists(select 1 from public.group_members m where m.group_id=group_bank_accounts.group_id and m.user_id=(select auth.uid())));
create function public.set_group_bank_account(p_group_id uuid,p_bank_name text,p_account_name text,p_account_number text) returns void
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then raise exception 'Only the leader can set the account' using errcode='42501'; end if;
 if g.status<>'draft' then raise exception 'The account is locked after activation' using errcode='22023'; end if;
 if p_bank_name is null or char_length(btrim(p_bank_name)) not between 2 and 80 or p_account_name is null or char_length(btrim(p_account_name)) not between 2 and 120 or p_account_number is null or p_account_number !~ '^[0-9]{10}$' then raise exception 'Check the bank details' using errcode='22023'; end if;
 if exists(select 1 from public.group_bank_accounts where group_id=p_group_id and bank_name=btrim(p_bank_name) and account_name=btrim(p_account_name) and account_number=p_account_number) then return; end if;
 insert into public.group_bank_accounts(group_id,bank_name,account_name,account_number) values(p_group_id,btrim(p_bank_name),btrim(p_account_name),p_account_number)
 on conflict(group_id) do update set bank_name=excluded.bank_name,account_name=excluded.account_name,account_number=excluded.account_number,updated_at=now();
 update public.savings_groups set terms_version=terms_version+1 where id=p_group_id;
 update public.group_members set accepted_terms_version=null,accepted_at=null where group_id=p_group_id;
 insert into public.group_events(group_id,actor_id,action) values(p_group_id,auth.uid(),'bank_account_updated');
end; $$;
revoke all on function public.set_group_bank_account(uuid,text,text,text) from public,anon;
grant execute on function public.set_group_bank_account(uuid,text,text,text) to authenticated;
-- Only explicitly shared profile information is visible to fellow members.
create function public.get_member_profile(p_group_id uuid,p_user_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=p_user_id) then raise exception 'Group access denied' using errcode='42501'; end if;
 return (select jsonb_build_object('display_name',coalesce(m.display_name,p.full_name,'Member'),'bio',coalesce(m.bio,''),'city',coalesce(m.city,'')) from public.profiles p left join public.member_profiles m on m.user_id=p.id where p.id=p_user_id);
end; $$;
revoke all on function public.get_member_profile(uuid,uuid) from public,anon;
grant execute on function public.get_member_profile(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
