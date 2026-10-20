-- 왕이 되는 그날까지 · 랭킹 2단계: 우편함 + 시즌 정산 (SQL Editor에 통째로 붙여 넣고 Run)
-- 여러 번 실행해도 안전하게 만들었어요.

-- ── 우편: 서버에서만 만들고, 받기도 서버가 확인해요 ──
create table if not exists public.mails (
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'notice',          -- season / hall / notice
  title text not null,
  body text,
  reward jsonb not null default '{}'::jsonb,    -- {"gem":500,"cards":30,"frame":"season","badge":"champ"}
  tag text,                                     -- 같은 보상을 두 번 보내지 않도록 (예: season:1)
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  claimed_at timestamptz
);
create unique index if not exists mails_tag_key on public.mails (user_id, tag) where tag is not null;
create index if not exists mails_user_idx on public.mails (user_id, claimed_at, expires_at);
alter table public.mails enable row level security;   -- 정책 없음: 아래 함수로만 읽고 받아요

create table if not exists public.settlements (
  season int primary key,
  players int,
  done_at timestamptz default now()
);
alter table public.settlements enable row level security;

-- ── 시즌 정산: 끝난 시즌을 한 번만 정산해 보상 우편을 보내요 (우편함을 열 때 자동 실행) ──
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
        when rk = 1 then '{"gem":500,"frame":"season","badge":"champ"}'::jsonb
        when rk <= 10 then '{"gem":300,"badge":"top10"}'::jsonb
        when rk <= ceil(tot * 0.1) then '{"gem":150,"cards":30}'::jsonb
        when rk <= ceil(tot * 0.5) then '{"gem":50}'::jsonb
        else '{"gem":20}'::jsonb
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

-- ── 우편 목록 (안 받은 것, 기간 안 지난 것) ──
create or replace function public.kd_mail_list()
returns table (id bigint, kind text, title text, body text, reward jsonb, created_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  perform public.kd_settle_due();
  return query
    select m.id, m.kind, m.title, m.body, m.reward, m.created_at, m.expires_at
    from public.mails m
    where m.user_id = auth.uid() and m.claimed_at is null and m.expires_at > now()
    order by m.created_at desc
    limit 100;
end $$;

-- ── 우편 받기: p_id 가 null 이면 모두 받기. 받은 우편들의 보상을 돌려줘요 ──
create or replace function public.kd_mail_claim(p_id bigint default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare out jsonb;
begin
  if auth.uid() is null then return '[]'::jsonb; end if;
  with c as (
    update public.mails set claimed_at = now()
    where user_id = auth.uid() and claimed_at is null and expires_at > now()
      and (p_id is null or id = p_id)
    returning id, title, reward
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'title', title, 'reward', reward)), '[]'::jsonb) into out from c;
  return out;
end $$;

-- ── 기록 보내기: 50곳을 모두 되찾으면 「정복자」 테두리 우편 (한 번) ──
create or replace function public.kd_submit(p_stage int, p_power bigint default 0, p_frame text default null, p_badge text default null, p_title text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s int := public.kd_season(); age_min numeric; b int; sus boolean;
begin
  if uid is null then return 'login'; end if;
  if not exists (select 1 from public.profiles where id = uid) then return 'nick'; end if;
  if p_stage < 1 or p_stage > 61 then return 'range'; end if;
  update public.profiles set base_stage = p_stage, base_at = now() where id = uid and base_stage is null;
  select extract(epoch from (now() - base_at)) / 60, base_stage into age_min, b from public.profiles where id = uid;
  sus := p_stage - b > 5 and age_min < (p_stage - b) * 1.5;
  update public.profiles set frame = coalesce(p_frame, frame), badge = case when p_badge is null then badge else nullif(p_badge,'') end, title = coalesce(p_title, title) where id = uid;
  insert into public.records (user_id, season, stage, power, hidden) values (uid, s, p_stage, p_power, sus)
    on conflict (user_id, season) do update set stage = excluded.stage, power = excluded.power, reached_at = now(), hidden = public.records.hidden or excluded.hidden
    where excluded.stage > public.records.stage;
  insert into public.records (user_id, season, stage, power, hidden) values (uid, 0, p_stage, p_power, sus)
    on conflict (user_id, season) do update set stage = excluded.stage, power = excluded.power, reached_at = now(), hidden = public.records.hidden or excluded.hidden
    where excluded.stage > public.records.stage;
  if p_stage > 50 and not sus then
    insert into public.mails (user_id, kind, title, body, reward, tag, expires_at)
    values (uid, 'hall', '정복자의 테두리', '영지 50곳을 모두 되찾았어요. 명예의 전당이 당신을 기억할 거예요.', '{"frame":"conquer"}'::jsonb, 'hall:conquer', now() + interval '365 days')
    on conflict (user_id, tag) where tag is not null do nothing;
  end if;
  return 'ok';
end $$;

-- ── 운영 우편 보내기 (대표님 전용: SQL Editor에서만 실행돼요, 게임에서는 못 불러요) ──
-- 예) 모두에게:   select public.kd_admin_mail(null, '점검 보상', '기다려 주셔서 고마워요!', '{"gem":100}');
-- 예) 한 명에게: select public.kd_admin_mail('농부', '축하해요', '첫 1위!', '{"gem":50}');
create or replace function public.kd_admin_mail(p_nick text, p_title text, p_body text, p_reward jsonb default '{}'::jsonb, p_days int default 30)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into public.mails (user_id, kind, title, body, reward, expires_at)
  select id, 'notice', p_title, p_body, coalesce(p_reward, '{}'::jsonb), now() + make_interval(days => p_days)
  from public.profiles where p_nick is null or lower(nick) = lower(p_nick);
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.kd_admin_mail(text,text,text,jsonb,int) from public, anon, authenticated;
revoke all on function public.kd_settle_due() from public, anon, authenticated;
grant execute on function public.kd_mail_list(), public.kd_mail_claim(bigint), public.kd_submit(int,bigint,text,text,text) to anon, authenticated;
