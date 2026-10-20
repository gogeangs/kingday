-- 왕이 되는 그날까지 · 임시 닉네임 + 환영 우편 (SQL Editor에 통째로 붙여 넣고 Run)
-- stage2_mail.sql 을 먼저 실행한 뒤에 실행하세요. 여러 번 실행해도 안전해요.

alter table public.profiles add column if not exists temp boolean not null default false;

-- 환영 우편 (계정마다 한 번)
create or replace function public.kd_welcome(uid uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.mails (user_id, kind, title, body, reward, tag)
  values (uid, 'notice', '왕국에 오신 것을 환영해요',
          '먼 길 오셨어요, 영주님! 피트가 작은 선물을 챙겨 뒀어요. 마족에게 빼앗긴 땅을 함께 되찾아요.',
          '{"gem":50}'::jsonb, 'welcome')
  on conflict (user_id, tag) where tag is not null do nothing;
$$;

-- 게임을 시작하면 계정을 준비해요: 닉네임이 없으면 임시 닉네임(영주12345)을 만들고 환영 우편을 보내요
create or replace function public.kd_ensure_profile(p_frame text default null, p_badge text default null, p_title text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); cur public.profiles; n text; i int := 0;
begin
  if uid is null then return null; end if;
  select * into cur from public.profiles where id = uid;
  if not found then
    loop
      i := i + 1;
      n := '영주' || lpad((floor(random() * 100000))::int::text, 5, '0');
      exit when not exists (select 1 from public.profiles where lower(nick) = lower(n));
      if i > 30 then n := '영주' || substr(replace(uid::text, '-', ''), 1, 8); exit; end if;
    end loop;
    insert into public.profiles (id, nick, frame, badge, title, nick_season, temp)
      values (uid, n, coalesce(p_frame, 'wood'), nullif(p_badge, ''), p_title, 0, true)
      returning * into cur;
  end if;
  perform public.kd_welcome(uid);
  return jsonb_build_object('nick', cur.nick, 'temp', cur.temp);
end $$;

-- 닉네임 정하기: 임시 닉네임은 시즌 제한 없이 한 번 바꿀 수 있어요
create or replace function public.kd_set_nick(p_nick text, p_frame text default null, p_badge text default null, p_title text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n text := btrim(p_nick); cur public.profiles;
begin
  if uid is null then return 'login'; end if;
  if char_length(n) < 2 or char_length(n) > 10 then return 'length'; end if;
  if n !~ '^[가-힣A-Za-z0-9_]+$' then return 'chars'; end if;
  if n ~* '(시발|씨발|ㅅㅂ|병신|ㅂㅅ|개새|좆|존나|fuck|shit|admin|운영자|관리자)' then return 'bad'; end if;
  if n ~ '^영주[0-9]{5}$' then return 'chars'; end if;
  select * into cur from public.profiles where id = uid;
  if found and not cur.temp and lower(cur.nick) <> lower(n) and cur.nick_season = public.kd_season() then return 'once'; end if;
  if exists (select 1 from public.profiles where lower(nick) = lower(n) and id <> uid) then return 'taken'; end if;
  insert into public.profiles (id, nick, frame, badge, title, nick_season, temp)
    values (uid, n, coalesce(p_frame,'wood'), p_badge, p_title, public.kd_season(), false)
  on conflict (id) do update set
    nick = excluded.nick,
    nick_season = case when public.profiles.temp then public.profiles.nick_season
                       when lower(public.profiles.nick) <> lower(excluded.nick) then public.kd_season()
                       else public.profiles.nick_season end,
    temp = false,
    frame = coalesce(p_frame, public.profiles.frame), badge = case when p_badge is null then public.profiles.badge else nullif(p_badge,'') end, title = coalesce(p_title, public.profiles.title);
  perform public.kd_welcome(uid);
  return 'ok';
end $$;

-- 이미 닉네임이 있는 영주님들께도 환영 우편을 보내요
select public.kd_welcome(id) from public.profiles;

revoke all on function public.kd_welcome(uuid) from public, anon, authenticated;
grant execute on function public.kd_ensure_profile(text,text,text), public.kd_set_nick(text,text,text,text) to anon, authenticated;
