-- Designed prerequisite for an EMPTY fresh project; not an export of hosted DDL.
-- Apply as database owner before application migrations. Never apply to a linked
-- existing project. Deliberately fails on conflicting objects instead of replacing.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 phone text not null default '',
 trust_score integer not null default 0,
 created_at timestamptz not null default now()
);
comment on column public.profiles.trust_score is 'Legacy server-owned placeholder, not verified identity or creditworthiness.';
alter table public.profiles enable row level security;
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (id, full_name, phone) on public.profiles to authenticated;
grant update (full_name, phone) on public.profiles to authenticated;
create policy profiles_read_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
 label text := btrim(coalesce(new.raw_user_meta_data->>'full_name', ''));
 contact text := coalesce(new.raw_user_meta_data->>'contact_phone', '');
begin
 -- Untrusted metadata never controls score, timestamp or verification claims.
 -- Incomplete OAuth metadata must not prevent account creation.
 insert into public.profiles(id, full_name, phone)
 values (new.id, left(label, 80), case when contact ~ '^\+[1-9][0-9]{7,14}$' then contact else '' end);
 return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
-- PostgreSQL orders same-event triggers alphabetically. This runs before the
-- later zz_seed_member_contact trigger, whose profile sync needs this row.
create trigger on_auth_user_created after insert on auth.users
 for each row execute function public.handle_new_user();
commit;
