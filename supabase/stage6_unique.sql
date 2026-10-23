-- 6단계: 유니크 등급 · 카엘 촌장 (2026-10-23, docs/companions/KAEL_CHIEF.md)
-- ① 랭킹 시즌 보상에 유니크 카드(ucard)를 더함: 1위 30 · 2~10위 15 · 상위 10% 8 · 상위 50% 3 · 참여 1
--    (황금 이삭·동료 카드·테두리·배지는 그대로. 이 SQL을 실행한 뒤 정산되는 시즌부터 적용)
-- ② 프로필 얼굴에 카엘 촌장(kael_chief)을 고를 수 있게 밑줄(_) 허용
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.

create or replace function public.kd_settle_due()
returns void language plpgsql security definer set search_path = public as $$
declare s int; cur int := public.kd_season(); n int;
begin
  if cur <= 1 then return; end if;
  for s in 1 .. cur - 1 loop
    continue when exists (select 1 from public.settlements where season = s);
    perform pg_advisory_xact_lock(424242);
    continue when exists (select 1 from public.settlements where season = s);

    with r as (
      select user_id, stage,
             row_number() over (order by stage desc, reached_at asc) as rk,
             count(*) over () as tot
      from public.records where season = s and not hidden
    )
    insert into public.mails (user_id, kind, title, body, reward, tag)
    select user_id, 'season',
      s || '시즌 랭킹 보상 · ' || rk || '위',
      s || '시즌을 ' || rk || '위로 마쳤어요. (참여 ' || tot || '명)',
      case
        when rk = 1 then '{"gem":500,"frame":"season","badge":"champ","ucard":30}'::jsonb
        when rk <= 10 then '{"gem":300,"badge":"top10","ucard":15}'::jsonb
        when rk <= ceil(tot * 0.1) then '{"gem":150,"cards":30,"ucard":8}'::jsonb
        when rk <= ceil(tot * 0.5) then '{"gem":50,"ucard":3}'::jsonb
        else '{"gem":20,"ucard":1}'::jsonb
      end,
      'season:' || s
    from r
    on conflict (user_id, tag) where tag is not null do nothing;
    get diagnostics n = row_count;

    -- 명예의 전당 1~3위 왕관 (정산 시점 기준, 왕관마다 한 번)
    with h as (
      select user_id, row_number() over (order by stage desc, reached_at asc) as rk
      from public.records where season = 0 and not hidden
    )
    insert into public.mails (user_id, kind, title, body, reward, tag)
    select user_id, 'hall',
      '명예의 전당 ' || rk || '위 왕관',
      '역대 최고 기록 ' || rk || '위에 이름을 올렸어요.',
      jsonb_build_object('badge', 'crown' || rk),
      'hall:crown' || rk
    from h where rk <= 3
    on conflict (user_id, tag) where tag is not null do nothing;

    insert into public.settlements (season, players) values (s, n);
  end loop;
end $$;

create or replace function public.kd_set_face(p_face text)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return 'auth'; end if;
  if p_face is null or p_face !~ '^[a-z_]{2,16}$' then return 'bad'; end if;
  update public.profiles set face = nullif(p_face, 'kael') where id = uid;
  return 'ok';
end $$;

revoke all on function public.kd_settle_due() from public, anon, authenticated;
