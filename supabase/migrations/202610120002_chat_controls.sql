begin;
alter table public.group_messages add column deleted_at timestamptz;
create table public.group_message_hides (
 user_id uuid not null references auth.users(id),
 message_sequence bigint not null references public.group_messages(sequence),
 primary key(user_id,message_sequence)
);
alter table public.group_message_hides enable row level security;
revoke all on public.group_message_hides from public,anon,authenticated;
create function public.remove_group_message(p_group_id uuid,p_sequence bigint,p_everyone boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare m public.group_messages;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select * into m from public.group_messages where group_id=p_group_id and sequence=p_sequence for update;
 if not found then raise exception 'Message unavailable' using errcode='22023'; end if;
 if p_everyone then
  if m.user_id<>auth.uid() then raise exception 'Only the sender can unsend' using errcode='42501'; end if;
  update public.group_messages set body='Message removed',deleted_at=coalesce(deleted_at,now()) where sequence=p_sequence;
 else
  insert into public.group_message_hides(user_id,message_sequence) values(auth.uid(),p_sequence) on conflict do nothing;
 end if;
end; $$;
create or replace function public.list_group_messages(p_group_id uuid,p_before bigint default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Group access denied' using errcode='42501'; end if;
 select coalesce(jsonb_agg(to_jsonb(page) order by sequence),'[]') into result from (
 select m.sequence,m.group_id,m.user_id,
 case when h.user_id is not null then '' when m.deleted_at is not null then 'Message removed' else m.body end as body,
 m.deleted_at is not null as removed,h.user_id is not null as hidden,
 m.created_at,coalesce(nullif(btrim(p.full_name),''),'Member') as sender_name,(m.user_id=g.created_by) as is_leader
 from public.group_messages m join public.savings_groups g on g.id=m.group_id left join public.profiles p on p.id=m.user_id
 left join public.group_message_hides h on h.message_sequence=m.sequence and h.user_id=auth.uid()
 where m.group_id=p_group_id and (p_before is null or m.sequence<p_before) order by m.sequence desc limit 50
 ) page;
 return result;
end; $$;
revoke all on function public.remove_group_message(uuid,bigint,boolean) from public,anon;
grant execute on function public.remove_group_message(uuid,bigint,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
