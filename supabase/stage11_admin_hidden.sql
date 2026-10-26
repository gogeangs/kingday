-- 11단계: 관리 페이지에서 「숨긴 랭킹 기록」 보기·되돌리기 (2026-10-27 전체 QA)
-- 속도 검사에 걸린 기록(시즌·명예의 전당 records, 황금 고블린 goblin_weeks, 시련의 탑 tower_records·tower_weeks)은
-- hidden = true 로 랭킹에서 빠짐. 지금까지는 SQL로만 볼 수 있었음 → 관리자만 부를 수 있는 함수 2개.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전. (stage8_inquiry.sql 의 kd_is_admin 필요)

-- ── 숨긴 기록 목록 (최근 것 먼저, 최대 300개) ──
-- kind: season(시즌 영지) · hall(명예의 전당) · goblin(황금 고블린 주간) · tower(탑 역대) · tower_week(탑 주간)
-- key: season 은 시즌 번호, hall 은 0, goblin·tower_week 는 주 번호, tower 는 0
create or replace function public.kd_adm_hidden_list()
returns table (kind text, key int, user_id uuid, nick text, value bigint, at timestamptz,
               best int, gem bigint, email text, guest boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.kd_is_admin() then raise exception 'not admin' using errcode = '42501'; end if;
  return query
    with h as (
      select case when r.season = 0 then 'hall' else 'season' end as kind, r.season as key, r.user_id, r.stage::bigint as value, r.reached_at as at
        from public.records r where r.hidden
      union all
      select 'goblin', g.week, g.user_id, g.kills::bigint, g.updated_at from public.goblin_weeks g where g.hidden
      union all
      select 'tower', 0, t.user_id, t.top::bigint, t.reached_at from public.tower_records t where t.hidden
      union all
      select 'tower_week', w.week, w.user_id, w.top::bigint, w.reached_at from public.tower_weeks w where w.hidden
    )
    select h.kind, h.key, h.user_id, p.nick, h.value, h.at,
           (select r0.stage from public.records r0 where r0.user_id = h.user_id and r0.season = 0),
           s.gem,
           (select i.identity_data ->> 'email' from auth.identities i
             where i.user_id = h.user_id and coalesce(i.identity_data ->> 'email', '') <> '' limit 1),
           coalesce((select u.is_anonymous from auth.users u where u.id = h.user_id), true)
    from h
    left join public.profiles p on p.id = h.user_id
    left join public.saves s on s.user_id = h.user_id
    order by h.at desc
    limit 300;
end $$;

-- ── 기록 숨김 켜고 끄기 → 'ok' · 'none'(그런 기록 없음) · 'bad' ──
-- 되돌리면(p_hidden=false) 다음 랭킹 조회부터 바로 보임. 이미 끝난 시즌·주의 보상은 다시 주지 않음(필요하면 관리 페이지 문의 답변으로 이삭 보내기).
create or replace function public.kd_adm_hidden_set(p_kind text, p_key int, p_user uuid, p_hidden boolean)
returns text language plpgsql security definer set search_path = public as $$
declare n int := 0;
begin
  if not public.kd_is_admin() then raise exception 'not admin' using errcode = '42501'; end if;
  if p_kind in ('season', 'hall') then
    update public.records set hidden = p_hidden where user_id = p_user and season = (case when p_kind = 'hall' then 0 else p_key end);
  elsif p_kind = 'goblin' then
    update public.goblin_weeks set hidden = p_hidden where user_id = p_user and week = p_key;
  elsif p_kind = 'tower' then
    update public.tower_records set hidden = p_hidden where user_id = p_user;
  elsif p_kind = 'tower_week' then
    update public.tower_weeks set hidden = p_hidden where user_id = p_user and week = p_key;
  else
    return 'bad';
  end if;
  get diagnostics n = row_count;
  return case when n > 0 then 'ok' else 'none' end;
end $$;

revoke all on function public.kd_adm_hidden_list() from public, anon;
revoke all on function public.kd_adm_hidden_set(text, int, uuid, boolean) from public, anon;
grant execute on function public.kd_adm_hidden_list() to authenticated;
grant execute on function public.kd_adm_hidden_set(text, int, uuid, boolean) to authenticated;
