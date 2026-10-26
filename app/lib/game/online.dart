/// 온라인 기능 담당 — 계정·닉네임·랭킹 제출·황금 고블린 주간·우편함·클라우드 저장.
///
/// 웹 index.html 의 sbEnsure · rankSubmit · gobSubmit · mailFetch · mailApply · resultPop · cloudPut 자리.
/// 서버가 없거나(시험) 인터넷이 끊겨도 게임은 그대로 돌아가야 하므로, 실패는 모두 조용히 넘긴다.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../core/server.dart';
import '../core/state.dart';
import '../screens/social_sheets.dart';
import 'controller.dart';
import 'login.dart';

/// 시즌·주차가 시작된 때 (2026-10-19 월 0시 KST, 웹 SEAS0 · WEEK0)
const int seasonZero = 1792335600000;

/// 지금 시즌이 끝나는 때 (2주 단위, 웹 seasonEnd)
int seasonEndAt(int now) => seasonZero + (((now - seasonZero) / 12096e5).floor() + 1) * 1209600000;

/// 영지 번호 → 「3-7」 (웹 stgName)
String stgName(num st) => st > maxLand ? '왕궁 뜰' : '${((st - 1) / 10).floor() + 1}-${((st - 1) % 10).toInt() + 1}';

/// 닉네임 오류 (웹 NICKERR)
const nickErr = {
  'length': '2~10글자로 정해 주세요',
  'chars': '한글·영문·숫자·_ 만 쓸 수 있어요',
  'bad': '쓸 수 없는 단어가 들어 있어요',
  'taken': '이미 누가 쓰고 있어요',
  'once': '닉네임은 시즌마다 한 번만 바꿀 수 있어요',
  'login': '연결에 실패했어요. 잠시 후 다시 해 주세요',
};

class Online {
  Online(this.g, this.sv);
  final GameController g;

  /// null 이면 온라인 기능을 끔 (웹 sbOn() === false)
  final Server? sv;
  bool get on => sv != null;

  GameState get s => g.state;
  GameCalc get c => g.calc;

  String? get nick => s.raw['nick'] is String && (s.raw['nick'] as String).isNotEmpty ? s.raw['nick'] as String : null;
  bool get nickTemp => truthy(s.raw['nickTemp']);

  /// 우편이 바뀌면 +1 (우편함 창·빨간 점이 다시 그림)
  final ValueNotifier<int> ver = ValueNotifier(0);
  void _bump() {
    ver.value++;
    g.refresh();
  }

  final List<Timer> _timers = [];

  /// 마지막으로 난 연결 오류 (시험·문제 찾기용)
  Object? lastError;
  bool _dead = false;

  void start() {
    if (!on) return;
    _timers
      ..add(Timer(const Duration(milliseconds: 1500), boot))
      ..add(Timer.periodic(const Duration(seconds: 30), (_) {
        rankSubmit(false);
        gobSubmit();
      }))
      ..add(Timer.periodic(const Duration(minutes: 5), (_) {
        if (!g.backgrounded) mailFetch();
      }))
      ..add(Timer.periodic(const Duration(minutes: 3), (_) {
        if (!g.backgrounded) cloudPut(false);
      }));
  }

  void dispose() {
    _dead = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  Future<dynamic> rpc(String fn, [Map<String, dynamic>? a]) => sv!.rpc(fn, a);

  /// 서버에 보내는 꾸미기 정보 (웹 rkMeta)
  Map<String, dynamic> meta() => {
        'p_frame': c.curFrame(),
        'p_badge': s.raw['badge'] is String ? s.raw['badge'] : '',
        'p_title': ranks[c.rankIdx()].n,
      };

  // ── 시작 ──
  /// 웹 sbBoot(): 계정 준비 → 계정 확인 → 클라우드에 한 번 저장
  Future<void> boot() async {
    if (!on || _dead) return;
    await ensure();
    await acctFetch();
    await cloudPut(false);
  }

  Future<void>? _ens;

  /// 웹 sbEnsure(): 계정·닉네임 준비 (처음이면 임시 닉네임 「영주12345」)
  Future<void> ensure() {
    if (!on) return Future.value();
    return _ens ??= () async {
      try {
        final r = await rpc('kd_ensure_profile', meta());
        if (r is Map && r['nick'] is String) {
          final temp = r['temp'] == true;
          if (nick != null && temp && nick != r['nick']) {
            // 웹에서 정한 닉네임이 있는데 서버엔 임시 → 서버에 다시 알림
            var ok = false;
            try {
              ok = await rpc('kd_set_nick', {'p_nick': nick, ...meta()}) == 'ok';
            } catch (_) {}
            if (ok) {
              s.raw['nickTemp'] = false;
            } else {
              s.raw['nick'] = r['nick'];
              s.raw['nickTemp'] = true;
            }
          } else {
            s.raw['nick'] = r['nick'];
            s.raw['nickTemp'] = temp;
          }
          g.save();
          rankSubmit(false);
        }
      } catch (e) {
        lastError = e;
      } finally {
        _ens = null;
      }
      await mailFetch();
    }();
  }

  // ── 랭킹 ──
  int rkSent = 0;
  bool _rkBusy = false;

  /// 웹 rankSubmit(force): 더 멀리 갔을 때만 기록 제출
  Future<void> rankSubmit(bool force) async {
    if (!on || nick == null || _rkBusy) return;
    final st = math.min(s.stage, maxLand + 1).toInt();
    if (!force && st <= rkSent) return;
    _rkBusy = true;
    try {
      final r = await rpc('kd_submit', {'p_stage': st, 'p_power': jsRound(c.power()).toInt(), ...meta()});
      if (r == 'ok') rkSent = st;
    } catch (_) {
    } finally {
      _rkBusy = false;
    }
    faceSync();
  }

  String? _faceSent;

  /// 고른 동료 얼굴을 서버에 알림 (supabase/stage5_face.sql 실행 전이면 조용히 무시)
  Future<void> faceSync() async {
    if (!on || nick == null) return;
    final f = c.pubFace();
    if (f == _faceSent) return;
    try {
      final r = await rpc('kd_set_face', {'p_face': f});
      if (r == 'ok') _faceSent = f;
    } catch (_) {
      _faceSent = f;
    }
  }

  bool gobDirty = true;
  bool _gobBusy = false;

  /// 웹 gobSubmit(): 이번 주 황금 고블린 처치 수 제출
  Future<void> gobSubmit() async {
    if (!on || nick == null || _gobBusy || !gobDirty) return;
    final w = g.sim.gobWeek();
    if (asNum(w['n']) < 1) {
      gobDirty = false;
      return;
    }
    _gobBusy = true;
    try {
      final r = await rpc('kd_gob_submit', {'p_week': asNum(w['w']).toInt(), 'p_kills': asNum(w['n']).toInt()});
      if (r == 'ok' || r == 'week' || r == 'range') gobDirty = false;
    } catch (_) {
    } finally {
      _gobBusy = false;
    }
  }

  /// 웹 gobRankToast(): 고블린을 잡고 2.6초 뒤 「이번 주 N마리 · 지금 M위」
  Future<void> gobRankToast() async {
    final n = asNum(g.sim.gobWeek()['n']);
    int? r;
    if (on && nick != null) {
      try {
        gobDirty = true;
        await gobSubmit();
        final rows = await rpc('kd_gob_ranking', {});
        if (rows is List) {
          final me = rows.whereType<Map>().where((x) => x['me'] == true).firstOrNull;
          if (me != null) r = asNum(me['rank']).toInt();
        }
      } catch (_) {}
    }
    if (_dead) return;
    g.toast('황금 고블린 이번 주 ${fmt(n)}마리${r != null ? ' · 지금 $r위' : ''}');
  }

  /// 닉네임 정하기 (웹 nickSheet 의 정하기). 성공하면 null, 아니면 보여 줄 오류
  Future<String?> setNick(String n) async {
    try {
      final r = await rpc('kd_set_nick', {'p_nick': n, ...meta()});
      if (r == 'ok') {
        s.raw['nick'] = n;
        s.raw['nickTemp'] = false;
        g.save();
        rkSent = 0;
        await rankSubmit(true);
        g.toast('닉네임을 「$n」(으)로 정했어요');
        mailFetch();
        return null;
      }
      return nickErr[r] ?? '다시 시도해 주세요';
    } catch (_) {
      return '인터넷 연결이 필요해요';
    }
  }

  /// 랭킹 표 받아 오기 (tab: season · hall · goblin)
  Future<List<Map<String, dynamic>>> ranking(String tab) async {
    dynamic rows;
    if (tab == 'goblin') {
      gobDirty = true;
      await gobSubmit();
      rows = await rpc('kd_gob_ranking', {});
    } else {
      await rankSubmit(false);
      rows = await rpc('kd_ranking', {'p_season': tab == 'hall' ? 0 : null});
    }
    return rows is List ? [for (final x in rows) if (x is Map) x.cast<String, dynamic>()] : const [];
  }

  // ── 우편함 ──
  List<Map<String, dynamic>> mails = [];
  bool _mailBusy = false;

  /// 웹 mailFetch()
  Future<List<Map<String, dynamic>>> mailFetch() async {
    if (!on || nick == null) {
      _bump();
      return mails;
    }
    try {
      final r = await rpc('kd_mail_list', {});
      if (r is List) mails = [for (final x in r) if (x is Map) x.cast<String, dynamic>()];
    } catch (_) {}
    if (_dead) return mails;
    _bump();
    try {
      resultPop();
    } catch (_) {}
    return mails;
  }

  /// 웹 mailClaim(id): id 가 null 이면 모두 받기
  Future<void> mailClaim(int? id) async {
    if (_mailBusy) return;
    _mailBusy = true;
    try {
      final r = await rpc('kd_mail_claim', {'p_id': id});
      if (r is List && r.isNotEmpty) mailApply([for (final x in r) if (x is Map) x.cast<String, dynamic>()]);
      await mailFetch();
    } catch (_) {
      g.toast('인터넷 연결이 필요해요');
    } finally {
      _mailBusy = false;
      _bump();
    }
  }

  /// 웹 mailApply(list): 받은 우편 보상을 게임에 넣기
  void mailApply(List<Map<String, dynamic>> list) {
    num gem = 0, cgold = 0;
    final got = <(String, int)>[];
    final items = <String>[];
    for (final m in list) {
      final r = asMap(m['reward']) ?? const {};
      // 스토어 결제 확인 우편 (kd-iap): 꾸러미는 첫 구매 2배 계산까지 게임 규칙대로
      final pk = r['pack'];
      if (pk is String && gemPacks.any((p) => p.k == pk)) {
        g.act((a) => a.grantPack(pk));
        continue;
      }
      if (truthy(r['starter'])) g.act((a) => a.grantStarter(count: true));
      if (asNum(r['sub_days']) > 0) g.act((a) => a.grantSub(count: true, days: asNum(r['sub_days'])));
      if (truthy(r['chief'])) g.act((a) => a.grantChief());
      if (truthy(r['ttuk'])) g.act((a) => a.grantTtuk());
      if (truthy(r['lucian'])) g.act((a) => a.grantLucian());
      // 상점·패스 (docs/content/SHOP.md): 원정 일지 {pass: 시즌} · 영주의 첫걸음 {grow: 1}
      if (truthy(r['pass'])) g.act((a) => a.passOpen(asNum(r['pass']).toInt()));
      if (truthy(r['grow'])) g.act((a) => a.growGive());
      if (asNum(r['ucard']) > 0) {
        final u = math.min(asNum(r['ucard']).floor(), 1000);
        s.raw['ucard'] = c.ucard + u;
        items.add('유니크 카드 +$u');
      }
      if (asNum(r['gem']) > 0) gem += math.min(asNum(r['gem']), 100000);
      final cards = asNum(r['cards']);
      if (cards > 0) {
        // 5장씩 나눠 여러 동료에게 (웹 gainCards(n,'shop',5))
        final res = c.gainCards(g.acts.rng, cards.toInt(), 'shop', 5);
        if (res != null) {
          got.addAll(res.got);
          cgold += res.gold;
        } else {
          gem += jsRound(cards * 3);
        }
      }
      final f = r['frame'];
      if (f is String && frameOf(f) != null) {
        final u = asMap(s.raw['pfUnl']) ?? (s.raw['pfUnl'] = <String, dynamic>{});
        if (!truthy(u[f])) {
          u[f] = 1;
          (asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{}))['f_$f'] = 1;
        }
        items.add('${frameName(f)} 테두리');
      }
      final b = r['badge'];
      if (b is String && badgeOf(b) != null) {
        final u = asMap(s.raw['bdUnl']) ?? (s.raw['bdUnl'] = <String, dynamic>{});
        if (!truthy(u[b])) {
          u[b] = 1;
          (asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{}))['b_$b'] = 1;
        }
        items.add('${badgeName(b)} 배지');
      }
    }
    if (gem > 0) s.gem = s.gem + gem;
    g.haptic(const [25]);
    c.pfCheck();
    g.save();
    g.refresh();
    final msg = [if (gem > 0) '황금 이삭 +${fmt(gem)}', ...items].join(' · ');
    if (msg.isNotEmpty) g.toast(msg);
    if (got.isNotEmpty || cgold > 0) g.queue((ctx) => showCardReveal(ctx, g, got, '우편 보상', gold: cgold));
  }

  /// 결제 확인 우편(kind=shop)을 바로 받기
  Future<void> claimShopMails() async {
    await mailFetch();
    for (final m in List.of(mails)) {
      if (m['kind'] == 'shop') await mailClaim(asNum(m['id']).toInt());
    }
  }

  static final _seasonRe = RegExp(r'^(\d+)시즌 랭킹 보상 · (\d+)위');
  static final _gobRe = RegExp(r'^(\d+)주차 황금 고블린 랭킹 · (\d+)위');

  /// 웹 resultPop(): 시즌·주간 결과 우편이 오면 한 번만 축하 창
  void resultPop() {
    for (final m in mails) {
      final title = m['title'] is String ? m['title'] as String : '';
      var t = _seasonRe.firstMatch(title);
      var k = 's', big = true;
      if (t == null) {
        t = _gobRe.firstMatch(title);
        k = 'g';
        big = false;
      }
      if (t == null) continue;
      final no = int.parse(t[1]!), rk = int.parse(t[2]!);
      final seen = asMap(s.raw['resSeen']) ?? (s.raw['resSeen'] = <String, dynamic>{});
      if (orNum(seen[k], 0) >= no) continue;
      seen[k] = no;
      g.save();
      g.queue((ctx) => showResultSheet(ctx, g, no: no, rank: rk, big: big, body: m['body'] is String ? m['body'] as String : ''));
      g.haptic(const [40, 40, 80]);
    }
  }

  // ── 문의하기 (supabase/stage8_inquiry.sql) ──
  /// 문의 보내기 → (서버 답, 사진을 못 올렸는지). 서버 답: ok · short · long · limit · auth · bad · net(인터넷 없음)
  Future<(String, bool)> inqSend({required String kind, required String body, List<int>? photo, required String ver, required String device, required String platform}) async {
    if (!on) return ('net', false);
    try {
      if (nick == null) await ensure();
      String? path;
      var photoFail = false;
      if (photo != null) {
        try {
          final png = photo.length > 3 && photo[0] == 0x89 && photo[1] == 0x50;
          final name = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 30).toRadixString(36)}';
          path = await sv!.upload('inquiry', '$name.${png ? 'png' : 'jpg'}', photo, png ? 'image/png' : 'image/jpeg');
        } catch (_) {
          photoFail = true;
        }
      }
      final r = await rpc('kd_inq_send', {
        'p_kind': kind,
        'p_body': body,
        'p_photo': path,
        'p_ver': ver,
        'p_device': device.length > 200 ? device.substring(0, 200) : device,
        'p_platform': platform,
      });
      return (r is String ? r : 'bad', photoFail);
    } catch (e) {
      lastError = e;
      return ('net', false);
    }
  }

  /// 내 문의 목록 (최근 30개). 인터넷이 없으면 null
  Future<List<Map<String, dynamic>>?> inqMine() async {
    if (!on) return null;
    try {
      final r = await rpc('kd_inq_mine', {});
      return r is List ? [for (final x in r) if (x is Map) x.cast<String, dynamic>()] : const [];
    } catch (e) {
      lastError = e;
      return null;
    }
  }

  // ── 계정·클라우드 저장 ──
  ({bool anon, String email})? acct;
  bool _linkGiftAsked = false;

  /// 웹 acctFetch(): 계정 확인 (구글로 연결된 계정이면 연결 선물 요청)
  Future<({bool anon, String email})?> acctFetch() async {
    if (!on) return null;
    try {
      final u = await sv!.user();
      if (u != null) acct = u;
      if (acct != null && !acct!.anon && !_linkGiftAsked) {
        _linkGiftAsked = true;
        rpc('kd_link_reward', {}).then((r) {
          if (r == 'ok') mailFetch();
        }).catchError((_) {
          _linkGiftAsked = false;
        });
      }
    } catch (_) {}
    return acct;
  }

  /// 구글·애플 계정으로 로그인 (웹 linkGoogle·loginGoogle 자리).
  /// 그 계정에 클라우드 기록이 있으면 「어느 기록으로 할까요?」 창, 없으면 이 기기 기록을 그 계정에 저장.
  Future<void> loginWith(String which) async {
    if (!on) return;
    final name = which == 'apple' ? '애플' : '구글';
    try {
      await cloudPut(true);
      final r = which == 'apple' ? await Login.apple() : await Login.google();
      if (r == null) return;
      if (!await sv!.signInWithIdToken(r.$1, r.$2, nonce: r.$3)) {
        g.toast('$name 로그인에 실패했어요. 잠시 뒤에 다시 해 주세요');
        return;
      }
      acct = null;
      _linkGiftAsked = false;
      rkSent = 0;
      cloudAt = 0;
      await acctFetch();
      dynamic cl;
      try {
        cl = await rpc('kd_save_get', {});
      } catch (_) {}
      if (cl is Map && GameState.looksLikeSave(cl['data'])) {
        g.queue((ctx) => showCloudPick(ctx, g, cl.cast<String, dynamic>()));
      } else {
        await ensure();
        await cloudPut(true);
      }
      try {
        await rpc('kd_link_reward', {});
      } catch (_) {}
      await mailFetch();
      g.toast('$name 계정으로 연결했어요${(acct?.email ?? '').isNotEmpty ? ' · ${acct!.email}' : ''}');
      g.refresh();
    } catch (_) {
      g.toast('$name 로그인에 실패했어요. 잠시 뒤에 다시 해 주세요');
    }
  }

  num cloudAt = 0;
  bool _cloudBusy = false;

  Map<String, dynamic> cloudBody() => {
        'p_data': s.raw,
        'p_stage': math.min(s.stage, maxLand + 1).toInt(),
        'p_power': jsRound(c.power()).toInt(),
        'p_gem': jsFloor(s.gem).toInt(),
      };

  /// 웹 cloudPut(force): 마지막 저장보다 새 기록이면 클라우드에 저장 (3분마다·앱을 벗어날 때)
  Future<bool> cloudPut(bool force) async {
    if (!on || !truthy(s.raw['started']) || g.noSave || _cloudBusy || nick == null) return false;
    final t = s.last;
    if (!force && t <= cloudAt) return false;
    _cloudBusy = true;
    try {
      final r = await rpc('kd_save_put', cloudBody());
      if (r == 'ok') {
        cloudAt = t;
        s.raw['cloudAt'] = DateTime.now().millisecondsSinceEpoch;
        return true;
      }
    } catch (_) {
    } finally {
      _cloudBusy = false;
    }
    return false;
  }
}

/// 「3분 전」 (웹 ago)
String agoText(Object? t) {
  int? ms;
  if (t is num) ms = t.toInt();
  if (t is String) ms = DateTime.tryParse(t)?.millisecondsSinceEpoch;
  if (ms == null || ms == 0) return '아직 없음';
  final m = (DateTime.now().millisecondsSinceEpoch - ms) / 6e4;
  return m < 1
      ? '방금 전'
      : m < 60
          ? '${m.floor()}분 전'
          : m < 1440
              ? '${(m / 60).floor()}시간 전'
              : '${(m / 1440).floor()}일 전';
}
