-- 10단계: 새 문의 메일 알림 (2026-10-26, 대표님 결정: 메일로)
-- 게임이 문의를 보낸 직후 Edge Function 「kd-inq-notify」 를 부름 → 이 함수로 「아직 알리지 않은 방금 문의」를 하나 꺼냄 → 대표님 메일로.
-- 이 함수는 서버(Edge Function, service_role)만 부를 수 있음. 게임·페이지에서는 못 부름.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (stage8_inquiry.sql 다음)

alter table public.inquiries add column if not exists notified_at timestamptz;

-- p_user 의 10분 안에 보낸, 아직 알리지 않은 문의를 하나 꺼내고 「알림 보냄」으로 표시 (두 번 알리지 않음)
create or replace function public.kd_inq_take_notify(p_user uuid)
returns table (id bigint, kind text, body text, has_photo boolean, nick text, platform text, app_ver text, created_at timestamptz, open_count bigint)
language plpgsql security definer set search_path = public as $$
declare qid bigint;
begin
  update public.inquiries q set notified_at = now()
   where q.id = (select q2.id from public.inquiries q2
                  where q2.user_id = p_user and q2.notified_at is null and q2.created_at > now() - interval '10 minutes'
                  order by q2.created_at desc limit 1 for update skip locked)
  returning q.id into qid;
  if qid is null then return; end if;
  return query
    select q.id, q.kind, q.body, q.photo is not null, q.nick, q.platform, q.app_ver, q.created_at,
           (select count(*) from public.inquiries x where x.status = 'new')
    from public.inquiries q where q.id = qid;
end $$;

revoke all on function public.kd_inq_take_notify(uuid) from public, anon, authenticated;
grant execute on function public.kd_inq_take_notify(uuid) to service_role;
