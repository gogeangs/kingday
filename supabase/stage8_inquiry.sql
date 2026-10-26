-- 8단계: 문의하기 (2026-10-26)
-- 게임 안 문의 창(웹·앱) → 이 표에 저장 → 대표님 관리 페이지(admin.html)에서 보고 답 → 답은 게임 우편함으로.
-- Supabase → SQL Editor 에 통째로 붙여 넣고 Run. 여러 번 실행해도 안전.
-- 실행 뒤 맨 아래 「관리자 등록」 한 줄을 대표님 구글 이메일로 바꿔서 한 번 더 Run.

-- ── 문의 표 ──
create table if not exists public.inquiries (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,   -- 계정을 지우면 문의도 같이 지워짐
  kind text not null check (kind in ('pay', 'bug', 'account', 'etc')), -- 결제 · 버그 · 계정 · 기타
  body text not null,
  photo text,                       -- 사진 저장소(inquiry) 안의 경로 「계정번호/파일이름」
  nick text,                        -- 보낼 때의 닉네임
  app_ver text,                     -- 앱 버전 (웹은 web-xxxx)
  device text,                      -- 기기·브라우저
  platform text,                    -- web / android / ios
  status text not null default 'new' check (status in ('new', 'answered', 'closed')),
  answer text,
  answered_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists inquiries_user_idx on public.inquiries (user_id, created_at desc);
create index if not exists inquiries_status_idx on public.inquiries (status, created_at desc);
alter table public.inquiries enable row level security;   -- 정책 없음: 아래 함수로만 쓰고 읽어요

-- ── 관리자 목록: 여기 적힌 이메일의 구글·애플 계정만 관리 페이지를 쓸 수 있어요 ──
create table if not exists public.kd_admins (
  email text primary key
);
alter table public.kd_admins enable row level security;   -- 정책 없음: 게임·페이지에서 못 읽음

-- 지금 로그인한 사람이 관리자인지 (구글·애플로 확인된 이메일만 인정 · 게스트는 아님)
create or replace function public.kd_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1
    from auth.identities i
    join public.kd_admins a on lower(a.email) = lower(i.identity_data ->> 'email')
    where i.user_id = auth.uid() and i.provider in ('google', 'apple')
  )
$$;

-- ── 사진 저장소: 비공개 · 3MB · 그림 파일만 ──
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('inquiry', 'inquiry', false, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 하루에 올린 사진이 5장 미만일 때만 더 올릴 수 있음 (도배 방지)
create or replace function public.kd_inq_upload_ok()
returns boolean language sql stable security definer set search_path = public, storage as $$
  select auth.uid() is not null and (
    select count(*) from storage.objects o
    where o.bucket_id = 'inquiry'
      and (storage.foldername(o.name))[1] = auth.uid()::text
      and o.created_at > now() - interval '1 day'
  ) < 5
$$;

drop policy if exists "kd inquiry upload" on storage.objects;
create policy "kd inquiry upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'inquiry' and (storage.foldername(name))[1] = auth.uid()::text and public.kd_inq_upload_ok());

drop policy if exists "kd inquiry read" on storage.objects;
create policy "kd inquiry read" on storage.objects for select to authenticated
  using (bucket_id = 'inquiry' and ((storage.foldername(name))[1] = auth.uid()::text or public.kd_is_admin()));

drop policy if exists "kd inquiry delete" on storage.objects;
create policy "kd inquiry delete" on storage.objects for delete to authenticated
  using (bucket_id = 'inquiry' and public.kd_is_admin());

-- ── 문의 보내기 → 'ok' · 'auth' 로그인 필요 · 'bad' 잘못된 값 · 'short' 5자 미만 · 'long' 1000자 넘음 · 'limit' 하루 3번 넘음 ──
create or replace function public.kd_inq_send(p_kind text, p_body text, p_photo text default null,
                                              p_ver text default null, p_device text default null, p_platform text default null)
returns text language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); b text := btrim(coalesce(p_body, '')); n int;
begin
  if uid is null then return 'auth'; end if;
  if p_kind is null or p_kind not in ('pay', 'bug', 'account', 'etc') then return 'bad'; end if;
  if char_length(b) < 5 then return 'short'; end if;
  if char_length(b) > 1000 then return 'long'; end if;
  if p_photo is not null and p_photo !~ ('^' || uid::text || '/[A-Za-z0-9_-]{6,40}\.(jpg|png|webp)$') then return 'bad'; end if;
  select count(*) into n from public.inquiries where user_id = uid and created_at > now() - interval '1 day';
  if n >= 3 then return 'limit'; end if;
  insert into public.inquiries (user_id, kind, body, photo, nick, app_ver, device, platform)
  values (uid, p_kind, b, p_photo, (select pr.nick from public.profiles pr where pr.id = uid),
          left(p_ver, 40), left(p_device, 200), left(p_platform, 20));
  -- 개인정보처리방침: 답변·처리 후 1년이 지난 문의는 지움
  delete from public.inquiries where status <> 'new' and coalesce(closed_at, answered_at) < now() - interval '1 year';
  return 'ok';
end $$;

-- ── 내 문의 목록 (최근 30개) ──
create or replace function public.kd_inq_mine()
returns table (id bigint, kind text, body text, has_photo boolean, status text, answer text, created_at timestamptz, answered_at timestamptz)
language sql stable security definer set search_path = public as $$
  select q.id, q.kind, q.body, q.photo is not null, q.status, q.answer, q.created_at, q.answered_at
  from public.inquiries q
  where q.user_id = auth.uid()
  order by q.created_at desc
  limit 30
$$;

-- ── 관리 페이지: 문의 목록 (처리 전 → 답변함 → 처리 완료, 같은 칸 안에서는 최근 것 먼저) ──
create or replace function public.kd_adm_inq_list(p_status text default null, p_kind text default null)
returns table (id bigint, kind text, body text, photo text, nick text, user_id uuid, app_ver text, device text, platform text,
               status text, answer text, created_at timestamptz, answered_at timestamptz, closed_at timestamptz,
               email text, guest boolean, stage int, gem bigint, buys jsonb, inq_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.kd_is_admin() then raise exception 'not admin' using errcode = '42501'; end if;
  return query
    select q.id, q.kind, q.body, q.photo, coalesce(p.nick, q.nick), q.user_id, q.app_ver, q.device, q.platform,
           q.status, q.answer, q.created_at, q.answered_at, q.closed_at,
           (select i.identity_data ->> 'email' from auth.identities i
             where i.user_id = q.user_id and coalesce(i.identity_data ->> 'email', '') <> '' limit 1),
           coalesce((select u.is_anonymous from auth.users u where u.id = q.user_id), true),
           s.stage, s.gem,
           (select coalesce(jsonb_agg(jsonb_build_object('product', b.product_id, 'platform', b.platform, 'order', b.order_id, 'at', b.created_at)
                                      order by b.created_at desc), '[]'::jsonb)
              from (select * from public.purchases pu where pu.user_id = q.user_id order by pu.created_at desc limit 10) b),
           (select count(*) from public.inquiries q2 where q2.user_id = q.user_id)
    from public.inquiries q
    left join public.profiles p on p.id = q.user_id
    left join public.saves s on s.user_id = q.user_id
    where (p_status is null or q.status = p_status) and (p_kind is null or q.kind = p_kind)
    order by case q.status when 'new' then 0 when 'answered' then 1 else 2 end, q.created_at desc
    limit 300;
end $$;

-- ── 관리 페이지: 답 보내기 → 우편함으로 (보상은 선택, 예: {"gem":100}) ──
create or replace function public.kd_adm_inq_answer(p_id bigint, p_answer text, p_reward jsonb default '{}'::jsonb)
returns text language plpgsql security definer set search_path = public as $$
declare q public.inquiries; a text := btrim(coalesce(p_answer, ''));
  kn text;
begin
  if not public.kd_is_admin() then return 'admin'; end if;
  if char_length(a) < 1 or char_length(a) > 1000 then return 'bad'; end if;
  select * into q from public.inquiries where id = p_id;
  if not found then return 'none'; end if;
  kn := case q.kind when 'pay' then '결제' when 'bug' then '버그' when 'account' then '계정' else '기타' end;
  insert into public.mails (user_id, kind, title, body, reward, expires_at)
  values (q.user_id, 'reply', '문의 답변 · ' || kn, a, coalesce(p_reward, '{}'::jsonb), now() + interval '30 days');
  update public.inquiries set status = 'answered', answer = a, answered_at = now() where id = p_id;
  return 'ok';
end $$;

-- ── 관리 페이지: 처리 완료 / 다시 열기. p_photo_gone=true 면 사진 경로도 지움(사진 파일은 페이지가 먼저 지움) ──
create or replace function public.kd_adm_inq_status(p_id bigint, p_status text, p_photo_gone boolean default false)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not public.kd_is_admin() then return 'admin'; end if;
  if p_status not in ('new', 'answered', 'closed') then return 'bad'; end if;
  update public.inquiries
     set status = p_status,
         closed_at = case when p_status = 'closed' then now() else null end,
         photo = case when p_photo_gone then null else photo end
   where id = p_id;
  if not found then return 'none'; end if;
  return 'ok';
end $$;

revoke all on function public.kd_inq_upload_ok() from public, anon;
grant execute on function public.kd_inq_upload_ok() to authenticated;
grant execute on function public.kd_is_admin(), public.kd_inq_send(text, text, text, text, text, text), public.kd_inq_mine(),
  public.kd_adm_inq_list(text, text), public.kd_adm_inq_answer(bigint, text, jsonb), public.kd_adm_inq_status(bigint, text, boolean)
  to anon, authenticated;

-- ── 관리자 등록: 아래 이메일을 대표님이 관리 페이지에서 로그인할 구글 이메일로 바꿔서 Run ──
-- insert into public.kd_admins (email) values ('대표님구글이메일@example.com') on conflict do nothing;
