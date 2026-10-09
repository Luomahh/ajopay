begin;
-- One obligation per member and schedule period. Rejected reports can be corrected.
create table public.contributions (
 group_id uuid not null,
 period_number integer not null,
 user_id uuid not null,
 amount_kobo bigint not null check(amount_kobo > 0),
 payment_reference text not null check(char_length(payment_reference) between 3 and 120),
 paid_on date not null,
 status text not null check(status in ('pending','confirmed','rejected')),
 version integer not null check(version > 0),
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id),
 review_note text,
 primary key(group_id,period_number,user_id),
 foreign key(group_id,period_number) references public.group_periods(group_id,period_number),
 foreign key(group_id,user_id) references public.group_members(group_id,user_id)
);
create unique index contribution_reference_once on public.contributions(group_id,user_id,lower(payment_reference)) where status in ('pending','confirmed');
create table public.contribution_history (
 id uuid primary key default gen_random_uuid(),
 group_id uuid not null,
 period_number integer not null,
 user_id uuid not null,
 actor_id uuid not null references auth.users(id),
 status text not null,
 version integer not null,
 amount_kobo bigint not null,
 payment_reference text not null,
 paid_on date not null,
 note text,
 created_at timestamptz not null default now(),
 foreign key(group_id,period_number,user_id) references public.contributions(group_id,period_number,user_id)
);
alter table public.contributions enable row level security;
alter table public.contribution_history enable row level security;
-- RPC-only access; members see their own records, leaders see their group's records.
revoke all on public.contributions,public.contribution_history from public,anon,authenticated;
create function public.contribution_window_start(p_group_id uuid,p_period integer) returns date
language sql stable security definer set search_path='' as $$
 select coalesce((select due_date+1 from public.group_periods where group_id=p_group_id and period_number=p_period-1),
 case g.frequency when 'daily' then s.due_date when 'weekly' then s.due_date-6 else (s.due_date-interval '1 month')::date+1 end)
 from public.group_periods s join public.savings_groups g on g.id=s.group_id where s.group_id=p_group_id and s.period_number=p_period;
$$;
revoke all on function public.contribution_window_start(uuid,integer) from public,anon,authenticated;

create function public.get_contribution_tracker(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; rows jsonb; periods jsonb; history jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Access denied' using errcode='42501'; end if;
 select * into g from public.savings_groups where id=p_group_id;
 select coalesce(jsonb_agg(to_jsonb(c) order by c.period_number,c.user_id),'[]') into rows from public.contributions c where c.group_id=p_group_id and (g.created_by=auth.uid() or c.user_id=auth.uid());
 select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object('opens_on',public.contribution_window_start(p_group_id,s.period_number)) order by s.period_number),'[]') into periods from public.group_periods s where s.group_id=p_group_id;
 select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at desc,h.id),'[]') into history from public.contribution_history h where h.group_id=p_group_id and (g.created_by=auth.uid() or h.user_id=auth.uid());
 return jsonb_build_object('today',(now() at time zone 'Africa/Lagos')::date,'periods',periods,'contributions',rows,'history',history);
end; $$;

create function public.submit_contribution(p_group_id uuid,p_period integer,p_amount_kobo bigint,p_reference text,p_paid_on date,p_expected_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; c public.contributions; existing boolean; opening date; today date:=(now() at time zone 'Africa/Lagos')::date;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or not exists(select 1 from public.group_members where group_id=p_group_id and user_id=auth.uid()) then raise exception 'Access denied' using errcode='42501'; end if;
 if g.status<>'active' then raise exception 'Activate the group before recording contributions.' using errcode='22023'; end if;
 opening:=public.contribution_window_start(p_group_id,p_period);
 if opening is null or opening>today then raise exception 'This contribution period is not open yet.' using errcode='22023'; end if;
 if p_amount_kobo is null or p_amount_kobo<>g.contribution_kobo or p_reference is null or char_length(btrim(p_reference)) not between 3 and 120 or p_paid_on is null or p_paid_on<opening or p_paid_on>today or p_expected_version is null or p_expected_version<0 then raise exception 'Check the amount, payment date and reference.' using errcode='22023'; end if;
 select * into c from public.contributions where group_id=p_group_id and period_number=p_period and user_id=auth.uid(); existing:=found;
 -- A repeated identical request returns the existing record, even after review.
 if existing and c.version=p_expected_version+1 and c.amount_kobo=p_amount_kobo and c.payment_reference=btrim(p_reference) and c.paid_on=p_paid_on then return public.get_contribution_tracker(p_group_id); end if;
 if (existing and (c.status<>'rejected' or c.version<>p_expected_version)) or (not existing and p_expected_version<>0) then raise exception 'This payment changed. Refresh before trying again.' using errcode='22023'; end if;
 insert into public.contributions(group_id,period_number,user_id,amount_kobo,payment_reference,paid_on,status,version)
 values(p_group_id,p_period,auth.uid(),p_amount_kobo,btrim(p_reference),p_paid_on,'pending',p_expected_version+1)
 on conflict(group_id,period_number,user_id) do update set amount_kobo=excluded.amount_kobo,payment_reference=excluded.payment_reference,paid_on=excluded.paid_on,status='pending',version=excluded.version,submitted_at=now(),reviewed_at=null,reviewed_by=null,review_note=null returning * into c;
 insert into public.contribution_history(group_id,period_number,user_id,actor_id,status,version,amount_kobo,payment_reference,paid_on) values(c.group_id,c.period_number,c.user_id,auth.uid(),c.status,c.version,c.amount_kobo,c.payment_reference,c.paid_on);
 return public.get_contribution_tracker(p_group_id);
end; $$;

create function public.review_contribution(p_group_id uuid,p_period integer,p_user_id uuid,p_version integer,p_confirm boolean,p_note text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.savings_groups; c public.contributions; desired text;
begin
 select * into g from public.savings_groups where id=p_group_id for update;
 if not found or auth.uid() is null or g.created_by<>auth.uid() then raise exception 'Only the group leader can review payments.' using errcode='42501'; end if;
 if g.status<>'active' or p_confirm is null or p_version is null then raise exception 'This payment cannot be reviewed.' using errcode='22023'; end if;
 if (not p_confirm and (p_note is null or char_length(btrim(p_note))<3)) or char_length(coalesce(p_note,''))>300 then raise exception 'Give a reason of 3 to 300 characters when returning a payment.' using errcode='22023'; end if;
 desired:=case when p_confirm then 'confirmed' else 'rejected' end;
 select * into c from public.contributions where group_id=p_group_id and period_number=p_period and user_id=p_user_id;
 if not found or c.version<>p_version then raise exception 'This payment changed. Refresh before reviewing.' using errcode='22023'; end if;
 if c.status=desired and coalesce(c.review_note,'')=coalesce(nullif(btrim(p_note),''),'') then return public.get_contribution_tracker(p_group_id); end if;
 if c.status<>'pending' then raise exception 'This payment has already been reviewed.' using errcode='22023'; end if;
 update public.contributions set status=desired,reviewed_at=now(),reviewed_by=auth.uid(),review_note=nullif(btrim(p_note),'') where group_id=p_group_id and period_number=p_period and user_id=p_user_id returning * into c;
 insert into public.contribution_history(group_id,period_number,user_id,actor_id,status,version,amount_kobo,payment_reference,paid_on,note) values(c.group_id,c.period_number,c.user_id,auth.uid(),c.status,c.version,c.amount_kobo,c.payment_reference,c.paid_on,c.review_note);
 return public.get_contribution_tracker(p_group_id);
end; $$;
revoke all on function public.get_contribution_tracker(uuid),public.submit_contribution(uuid,integer,bigint,text,date,integer),public.review_contribution(uuid,integer,uuid,integer,boolean,text) from public,anon;
grant execute on function public.get_contribution_tracker(uuid),public.submit_contribution(uuid,integer,bigint,text,date,integer),public.review_contribution(uuid,integer,uuid,integer,boolean,text) to authenticated;
notify pgrst,'reload schema';
commit;
