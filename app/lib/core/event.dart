/// 정기 이벤트 (docs/content/EVENT_SNOW.md) — 웹 index.html 「정기 이벤트 틀」 구역(EVT·evS·evKill·눈사람 대장·출석·상점·
/// 크리스마스 주간·외형)을 그대로 옮긴 것. 표는 web_data.g.dart 의 wEvt·wMgev·wSkins(웹 evInstall 뒤의 표).
/// 표 안의 함수(보스 보상 win·mile, 끝 장면 대사 end, 외형 꼬리표 tag)는 JSON 으로 옮겨지지 않아 여기서 같은 식으로 둔다.
///
/// 저장: S.evs[이벤트 id] = { sf, day, boss, att, shop, seen, xm, mg, hi } (웹과 같은 칸) · S.skin · S.skins
/// 날짜: 서버 kd_event_list(서버 시각 포함)를 읽으면 그 값([EvClock]), 못 읽으면 표의 기본값.
library;

import 'dart:math' as math;

import 'actions.dart';
import 'attendance.dart';
import 'calc.dart';
import 'data.dart';
import 'js.dart';
import 'profile_data.dart';
import 'web_data.g.dart';

Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _ml(Object? v) => [for (final x in (v as List? ?? const [])) _m(x)];

/// 영지 10에 닿으면 열림 (웹 EV_OPEN)
final int evOpenLand = asNum(wEvc['open']).toInt();

/// 미리보기로 켜는 이벤트 (웹 EV_MAIN)
final String evMain = wEvc['main'] as String;

/// 마을 광장 트리 [x, 바닥 y, 너비] (웹 EV_TREE, 마을 그림 좌표)
final List<num> evTreePos = (wEvc['tree'] as List).cast<num>();

const evBackMsg = '날짜가 이상해요. 휴대폰 시간을 확인해 주세요.';

/// ISO 날짜 → ms (못 읽으면 null) (웹 evT)
int? evT(Object? s) {
  if (s is num) return s.isFinite ? s.toInt() : null;
  if (s is! String) return null;
  return DateTime.tryParse(s)?.millisecondsSinceEpoch;
}

/// 이벤트 날짜(한국 시간 자정 기준) 'Y-M-D' — today() 와 같은 모양 (웹 kstDay)
String kstDay(num t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t.toInt() + 9 * 3600000, isUtc: true);
  return '${d.year}-${d.month}-${d.day}';
}

/// 「12/24」 (웹 kstDate)
String kstDate(num t) {
  final d = DateTime.fromMillisecondsSinceEpoch(t.toInt() + 9 * 3600000, isUtc: true);
  return '${d.month}/${d.day}';
}

/// 'Y-M-D' → YYYYMMDD 숫자 (웹 dnum)
int dnum(String t) {
  final p = t.split('-').map(int.tryParse).toList();
  if (p.length != 3 || p.any((x) => x == null || x < 0)) return 0;
  return p[0]! * 10000 + p[1]! * 100 + p[2]!;
}

/// 서버 시각·서버 날짜 (웹 evSkew·evRows·evDemoOn). 앱 전체에서 하나
class EvClock {
  /// 서버 시간 − 기기 시간 (이번 접속에서 서버를 읽었을 때만)
  static int skew = 0;

  /// 서버 kd_events 줄 (마지막으로 읽은 것은 기기에 남겨 둠 — 저장 키 'kd-ev')
  static List<Map<String, dynamic>>? rows;

  /// 미리보기·시험용: 'snow'(기간 무시하고 켬) · 'xmas'(크리스마스 주간도) — 앱에서는 시험에서만 씀
  static String? demo;
}

class EvBossSk {
  EvBossSk(Map<String, dynamic> m) : n = m['n'], every = asNum(m['every']), warn = asNum(m['warn']), dmg = asNum(m['dmg']), slow = asNum(m['slow']);
  final String n;
  final num every, warn, dmg, slow;
}

class EvBossDef {
  EvBossDef(Map<String, dynamic> m)
      : n = m['n'],
        tries = asNum(m['tries']).toInt(),
        lim = asNum(m['lim']),
        ri = asNum(m['ri']).toInt(),
        hp0 = asNum(m['hp0']),
        hpG = asNum(m['hpG']),
        atk = asNum(m['atk']),
        atkG = m['atkG'] == null ? 1.05 : asNum(m['atkG']),
        lose = asNum(m['lose']).toInt(),
        santaX = asNum(m['santaX']),
        sk = EvBossSk(_m(m['sk'])),
        spr = _m(m['spr']),
        sprX = _m(m['sprX']),
        fx = m['fx'],
        sayStart = (_m(m['say'])['start'] as List).cast<String>(),
        sayWin = _m(m['say'])['win'],
        sayLose = _m(m['say'])['lose'];
  final String n, fx, sayWin, sayLose;
  final int tries, ri, lose;
  final num lim, hp0, hpG, atk, atkG, santaX;
  final EvBossSk sk;
  final Map<String, dynamic> spr, sprX;
  final List<String> sayStart;

  /// 이기면 받는 재화 (웹 boss.win: min(60, 20 + 2×단계))
  int win(int st) => math.min(60, 20 + 2 * st);

  /// 단계 첫 돌파 보상 (웹 boss.mile: 10단계마다 전설 만능 2장, 5단계마다 이삭 30)
  List<Map<String, dynamic>>? mile(int st) => st % 10 == 0
      ? [
          {'k': 'lcard', 'n': 2, 'alt': 60}
        ]
      : st % 5 == 0
          ? [
              {'k': 'gem', 'n': 30}
            ]
          : null;
}

class EvShopItem {
  EvShopItem(Map<String, dynamic> m) : k = m['k'], r = _ml(m['r']), p = asNum(m['p']).toInt(), lim = asNum(m['lim']).toInt(), hot = truthy(m['hot']);
  final String k;
  final List<Map<String, dynamic>> r;
  final int p, lim;
  final bool hot;
}

class EventDef {
  EventDef(this.m)
      : id = m['id'],
        n = m['n'],
        start = m['start'],
        end = m['end'],
        shopEnd = m['shopEnd'],
        xmas = (m['xmas'] as List?)?.cast<String>(),
        curN = _m(m['cur'])['n'],
        curImg = (_m(m['cur'])['img'] as String).replaceFirst('assets/', 'assets/game/'),
        shopN = m['shopN'],
        art = _m(m['art']).cast<String, String>(),
        bat = m['bat'] == null ? null : _m(m['bat']),
        att = [for (final d in (m['att'] as List? ?? const [])) _ml(d)],
        boss = m['boss'] == null ? null : EvBossDef(_m(m['boss'])),
        shop = [for (final x in (m['shop'] as List? ?? const [])) EvShopItem(_m(x))],
        comp = m['comp'],
        xm = m['xm'] == null ? null : _m(m['xm']),
        mg = m['mg'],
        lines = _m(m['lines']);
  final Map<String, dynamic> m;
  final String id, n, start, end, shopEnd, curN, curImg, shopN;
  final List<String>? xmas;
  final Map<String, String> art;
  final Map<String, dynamic>? bat, xm;
  final List<List<Map<String, dynamic>>> att;
  final EvBossDef? boss;
  final List<EvShopItem> shop;
  final String? comp, mg;
  final Map<String, dynamic> lines;

  List<String> line(String k) => ((lines[k] as List?) ?? const []).cast<String>();

  /// 끝 장면 대사 (웹 lines.end(own))
  List<String> endLines(bool own) => [
        own ? 'm:소복이|올해 눈꽃제도 끝이에요. 저는 계속 같이 있을게요, 소복!' : 'm:소복이|올해 눈꽃제도 끝이에요. 다음 겨울에 또 만나요, 소복!',
        'sys:눈꽃 상점은 1월 7일까지 열려 있어요. 남은 눈송이는 그 뒤에 사라져요',
      ];
}

/// 이벤트 표 (웹 EVT)
final Map<String, EventDef> evts = {for (final e in wEvt.entries) e.key: EventDef(_m(e.value))};

class MgEvDef {
  MgEvDef(this.k, Map<String, dynamic> m)
      : ev = m['ev'],
        n = m['n'],
        from = m['from'],
        to = m['to'],
        settle = m['settle'],
        year = asNum(m['year']).toInt(),
        daily = asNum(m['daily']).toInt(),
        ad = asNum(m['ad']).toInt(),
        rew = [for (final r in m['rew'] as List) ((r as List)[0] as String, r[1] as String)];
  final String k, ev, n, from, to, settle;
  final int year, daily, ad;
  final List<(String, String)> rew;
}

/// 미니게임 랭킹 표 (웹 MGEV)
final Map<String, MgEvDef> mgEvs = {for (final e in wMgev.entries) e.key: MgEvDef(e.key, _m(e.value))};

class SkinDef {
  SkinDef(this.k, Map<String, dynamic> m) : n = m['n'], spr = m['spr'], face = m['face'], how = m['how'];
  final String k, n, spr, face, how;

  /// 받은 해 꼬리표 (웹 SKINS.santa.tag)
  String tag(List<int> ys) => '${ys.join('·')} 선물 배달 TOP 10';
}

/// 외형 표 (웹 SKINS)
final Map<String, SkinDef> skinDefs = {for (final e in wSkins.entries) e.key: SkinDef(e.key, _m(e.value))};

/// 이벤트 한정 동료 (일반 카드 뽑기 제외, 웹 EVCARD)
final Set<String> evCards = {...wEvcard.keys};

typedef EvDates = ({num start, num end, num shop, num xs, num xe});

/// 보상 한 줄 (출석·상점·선물 공통 — 창에 보여 줄 것)
class EvRow {
  EvRow(this.kind, this.text, {this.sub = '', this.img});
  final String kind, text, sub;

  /// 칸 그림 (없으면 kind 로 고름)
  final String? img;
}

// ════════════════════ 계산 (화면 없이) ════════════════════
extension EventCalc on GameCalc {
  int get evNow => now + EvClock.skew;
  String evDay() => kstDay(evNow);

  /// 웹 evDates(E): 서버 날짜가 있으면 그 값, 없으면 표의 기본값
  EvDates evDates(EventDef e) {
    Map<String, dynamic>? r;
    for (final x in EvClock.rows ?? const <Map<String, dynamic>>[]) {
      if (x['id'] == e.id) r = x;
    }
    final x = asMap(r?['extra']) ?? const <String, dynamic>{};
    num pick(Object? a, Object? b) => (evT(a) ?? evT(b) ?? double.nan);
    final xl = x['xmas'] is List ? x['xmas'] as List : const [];
    var d = (
      start: pick(r?['start_at'], e.start),
      end: pick(r?['end_at'], e.end),
      shop: pick(r?['shop_end_at'], e.shopEnd),
      xs: e.xmas != null ? pick(xl.isNotEmpty ? xl[0] : null, e.xmas![0]) : double.nan,
      xe: e.xmas != null ? pick(xl.length > 1 ? xl[1] : null, e.xmas![1]) : double.nan,
    );
    final demo = EvClock.demo;
    if (demo != null && e.id == evMain) {
      final n = evNow;
      final end = n + 12.5 * 864e5;
      d = (
        start: n - 3 * 864e5,
        end: end,
        shop: end + 7 * 864e5,
        xs: demo != 'snow' ? n - 864e5 : n + 7 * 864e5,
        xe: demo != 'snow' ? n + 3.5 * 864e5 : n + 12 * 864e5,
      );
    }
    return d;
  }

  /// 'pre' 열리기 전 · 'on' 기간 중 · 'shop' 상점만 · 'off' 끝 (웹 evPhase)
  String evPhase(EventDef e) {
    final t = evNow, d = evDates(e);
    return t < d.start
        ? 'pre'
        : t < d.end
            ? 'on'
            : t < d.shop
                ? 'shop'
                : 'off';
  }

  /// 크리스마스 주간인지 (웹 evXmas)
  bool evXmas(EventDef e) {
    if (e.xm == null || evPhase(e) != 'on') return false;
    final d = evDates(e), t = evNow;
    return t >= d.xs && t < d.xe;
  }

  bool evOpen() => s.best >= evOpenLand;

  /// 지금 화면에 보일 이벤트 (기간 중 → 상점만 순, 웹 evList)
  List<EventDef> evList() => [for (final e in evts.values) if (const ['on', 'shop'].contains(evPhase(e))) e];

  EventDef? evCur() {
    final l = evList();
    for (final e in l) {
      if (evPhase(e) == 'on') return e;
    }
    return l.isEmpty ? null : l.first;
  }

  /// 이벤트 저장 칸 (모양이 깨졌으면 기본값, 웹 evS)
  Map<String, dynamic> evS(String id) {
    var all = s.raw['evs'];
    if (all is! Map) all = s.raw['evs'] = <String, dynamic>{};
    final evs = all;
    var e = evs[id];
    if (e is! Map) e = evs[id] = <String, dynamic>{};
    final em = e;
    Map<String, dynamic> d() => <String, dynamic>{
          'sf': 0,
          'day': <String, dynamic>{'d': '', 'bat': 0, 'kc': 0},
          'boss': <String, dynamic>{'d': '', 'n': 0, 'ad': 0, 'st': 1, 'best': 0, 'mile': <String, dynamic>{}, 'ref': 0},
          'att': <String, dynamic>{'last': '', 'cnt': 0},
          'shop': <String, dynamic>{},
          'seen': <String, dynamic>{'start': 0, 'end': 0, 'xmas': 0, 'mgEnd': 0, 'warn': ''},
          'xm': <String, dynamic>{'gift': <String, dynamic>{}, 'tree': '', 'days': <String, dynamic>{}},
          'mg': <String, dynamic>{'d': '', 'n': 0, 'ad': 0, 'best': 0},
          'hi': 0,
        };
    final def = d();
    bool sameType(Object? a, Object? b) => (a is num && b is num) || (a is String && b is String) || (a is Map && b is Map) || (a is bool && b is bool);
    for (final k in def.keys) {
      final v = em[k];
      if (v == null || !sameType(v, def[k]) || v is List) em[k] = def[k];
    }
    for (final k in const ['day', 'boss', 'seen', 'xm', 'mg']) {
      final sub = em[k] as Map, dd = def[k] as Map;
      for (final j in dd.keys) {
        final v = sub[j];
        if (v == null || !sameType(v, dd[j])) sub[j] = dd[j];
      }
    }
    num fl(Object? v) {
      final n = v is num ? v : num.tryParse('$v') ?? 0;
      return n.isFinite ? n.floor() : 0;
    }

    em['sf'] = math.min(1e7, math.max(0, fl(em['sf']))).toInt();
    final b = em['boss'] as Map;
    b['st'] = math.min(999, math.max(1, fl(b['st']))).toInt();
    b['best'] = math.min(999, math.max(0, fl(b['best']))).toInt();
    return em.cast<String, dynamic>();
  }

  /// 하루가 바뀌면 오늘 칸을 새로 (웹 evToday)
  Map<String, dynamic> evToday(Map<String, dynamic> e) {
    final t = evDay();
    if ((e['day'] as Map)['d'] != t) e['day'] = <String, dynamic>{'d': t, 'bat': 0, 'kc': 0};
    for (final k in const ['boss', 'mg']) {
      final b = e[k] as Map;
      if (b['d'] != t) {
        b['d'] = t;
        b['n'] = 0;
        b['ad'] = 0;
      }
    }
    return e;
  }

  /// 시계 되돌림: 이 이벤트에서 본 가장 늦은 날보다 앞이면 true (그날 보상 없음, 웹 evBack)
  bool evBack(Map<String, dynamic> e) => dnum(evDay()) < asNum(e['hi']);
  void evTouch(Map<String, dynamic> e) => e['hi'] = math.max(asNum(e['hi']).toInt(), dnum(evDay()));

  /// 이벤트 재화 더하기 (상점이 닫힌 이벤트는 무시, 웹 evAdd)
  int evAdd(String id, num n) {
    final e = evts[id];
    if (e == null || !(n > 0) || !const ['on', 'shop'].contains(evPhase(e))) return 0;
    final s0 = evS(id);
    s0['sf'] = asNum(s0['sf']) + n.floor();
    return n.floor();
  }

  /// 끝난 이벤트(상점까지 닫힘)·표에 없는 옛 이벤트 저장 지우기 (웹 evClean)
  void evClean() {
    final all = s.raw['evs'];
    if (all is! Map) return;
    for (final id in all.keys.toList()) {
      final e = evts[id];
      if (e == null || evPhase(e) == 'off') all.remove(id);
    }
  }

  // ── 전투 눈송이: 처치 25마리마다 1, 하루 100 (방치 포함) ──
  /// 웹 evKill(n): 켜 둔 전투 처치. 돌려주는 값 = 이번에 얻은 재화 수 (화면 「❄ +1」)
  int evKill([int n = 1]) {
    if (!truthy(s.raw['started']) || !evOpen()) return 0;
    var got = 0;
    for (final e in evList()) {
      final bat = e.bat;
      if (bat == null || evPhase(e) != 'on') continue;
      final x = evToday(evS(e.id)), day = x['day'] as Map, per = asNum(bat['per']), cap = asNum(bat['cap']);
      if (asNum(day['bat']) >= cap || evBack(x)) continue;
      evTouch(x);
      day['kc'] = asNum(day['kc']) + n;
      while (asNum(day['kc']) >= per && asNum(day['bat']) < cap) {
        day['kc'] = asNum(day['kc']) - per;
        day['bat'] = asNum(day['bat']) + 1;
        x['sf'] = asNum(x['sf']) + 1;
        got++;
      }
    }
    return got;
  }

  /// 방치(꺼 둔 동안) 처치 수: 방치 골드와 같은 계산 (웹 idleKills)
  num idleKills(num sec) {
    num dps = 0;
    for (final id in members()) {
      final t = stats(id);
      dps = dps + t.atk * t.aps * critE(t);
    }
    if (!(dps > 0)) return 0;
    return sec / (GameCalc.monHp(fightSt(), false) / dps + 1.2);
  }

  /// 웹 evIdle(sec): 방치 처치도 눈송이 (×idleK, 하루 한도 안). 돌려주는 값 = 얻은 재화
  int evIdle(num sec) {
    if (!evOpen()) return 0;
    var got = 0;
    for (final e in evList()) {
      final bat = e.bat;
      if (bat == null || evPhase(e) != 'on') continue;
      final x = evToday(evS(e.id)), day = x['day'] as Map, per = asNum(bat['per']), cap = asNum(bat['cap']), b0 = asNum(day['bat']);
      if (evBack(x)) continue;
      evTouch(x);
      day['kc'] = asNum(day['kc']) + idleKills(sec) * (bat['idleK'] == null ? 1 : asNum(bat['idleK']));
      while (asNum(day['kc']) >= per && asNum(day['bat']) < cap) {
        day['kc'] = asNum(day['kc']) - per;
        day['bat'] = asNum(day['bat']) + 1;
        x['sf'] = asNum(x['sf']) + 1;
      }
      if (asNum(day['bat']) >= cap) day['kc'] = 0;
      got += (asNum(day['bat']) - b0).toInt();
    }
    return got;
  }

  // ── 눈사람 대장 ──
  /// 기준 영지: 지금 되찾은 가장 먼 영지 (웹 evBossSt)
  int evBossSt() => math.max(1, math.min(s.best - 1, land));

  /// 이번 이벤트 첫 도전 때 고정한 기준 영지 (웹 evBossRef)
  int evBossRef(Map<String, dynamic>? e) {
    final r = e == null ? 0 : asNum((e['boss'] as Map)['ref']);
    return r > 0 ? math.min(r.toInt(), land) : evBossSt();
  }

  static num evBossHp(EvBossDef b, int stg, int ref) => GameCalc.monHp(ref, false) * Balance.bossHp * b.hp0 * math.pow(b.hpG, stg - 1);
  static num evBossAtk(EvBossDef b, int stg, int ref) => GameCalc.monAtk(ref, false) * Balance.bossAtk * b.atk * math.pow(b.atkG, stg - 1);
  int evTries(EventDef e, Map<String, dynamic> x) => e.boss!.tries + (truthy((x['boss'] as Map)['ad']) ? 1 : 0);
  int evTriesLeft(EventDef e) {
    final x = evToday(evS(e.id));
    return math.max(0, evTries(e, x) - asNum((x['boss'] as Map)['n']).toInt());
  }

  /// 눈사람 대장이 나오는 이벤트가 기간 중인지 (원정 일지 점수 「눈사람 대장 도전」, 웹 evPassSrc)
  bool evBossOn() => evts.values.any((e) => e.boss != null && evPhase(e) == 'on');

  // ── 이벤트 출석 14칸 ──
  bool evAttCan(EventDef e) {
    if (e.att.isEmpty || evPhase(e) != 'on' || !evOpen()) return false;
    final x = evS(e.id), a = x['att'] as Map;
    return asNum(a['cnt']) < e.att.length && a['last'] != evDay() && !evBack(x);
  }

  // ── 상점 ──
  int evShopLeft(EventDef e, EvShopItem it) => it.lim - orNum(asMap(evS(e.id)['shop'])?[it.k], 0).toInt();

  /// 테두리·배지는 이미 가진 사람에게는 「받음」 (웹 evShopOwned)
  bool evShopOwned(EvShopItem it) => it.r.any((r) => (r['k'] == 'frame' && pfHas(r['id'] as String)) || (r['k'] == 'badge' && bdHas(r['id'] as String)));

  /// 합류까지 남은 카드 (웹 evJoinLeft)
  int evJoinLeft(String id) => owned(id) ? 0 : math.max(0, 30 - orNum(asMap(s.raw['cards'])?[id], 0).toInt());

  // ── 크리스마스 주간 ──
  int evXmDay() => int.parse(evDay().split('-')[2]);

  /// 크리스마스 주간에 들어온 날 수 (배지 「메리 크리스마스」, 웹 evXmasCount)
  int evXmasCount() {
    var n = 0;
    final all = asMap(s.raw['evs']);
    if (all == null) return 0;
    for (final id in evts.keys) {
      final days = asMap(asMap(asMap(all[id])?['xm'])?['days']);
      if (days != null) n = math.max(n, days.length);
    }
    return n;
  }

  /// 크리스마스 트리가 서 있는 이벤트 (웹 evTreeE)
  EventDef? evTreeE() {
    if (!evOpen()) return null;
    for (final e in evts.values) {
      if (e.xm != null && evXmas(e)) return e;
    }
    return null;
  }

  // ── 미니게임 「선물 배달」 ──
  /// 판을 할 수 있는 때 (크리스마스 주간, 웹 evMgOn)
  bool evMgOn(EventDef e) => e.mg != null && mgEvs[e.mg] != null && (evXmas(e) || (EvClock.demo != null && EvClock.demo != 'snow' && e.id == evMain));

  /// 탭을 보일 때 (기록 시작 뒤 ~ 상점이 닫힐 때까지, 웹 evMgShow)
  bool evMgShow(EventDef e) => e.mg != null && mgEvs[e.mg] != null && evNow >= (evT(mgEvs[e.mg]!.from) ?? 0) && const ['on', 'shop'].contains(evPhase(e));

  int evMgLeft(EventDef e) {
    if (!evMgOn(e)) return 0;
    final mm = mgEvs[e.mg]!, x = evToday(evS(e.id)), g = x['mg'] as Map;
    return math.max(0, mm.daily + (truthy(g['ad']) ? mm.ad : 0) - asNum(g['n']).toInt());
  }

  /// 상단 버튼 빨간 점 (웹 evDot)
  bool evDot(EventDef e) {
    if (evPhase(e) != 'on') return false;
    final x = evToday(evS(e.id));
    if (evBack(x)) return false;
    final t = evDay(), xm = x['xm'] as Map;
    return evAttCan(e) || (e.boss != null && evTriesLeft(e) > 0) || (evXmas(e) && (!truthy(asMap(xm['gift'])?[t]) || xm['tree'] != t || evMgLeft(e) > 0));
  }

  // ── 외형 ──
  Map<String, dynamic> get _skins => asMap(s.raw['skins']) ?? (s.raw['skins'] = <String, dynamic>{});
  bool skinHas(String k) => s.raw['skins'] is Map && (s.raw['skins'] as Map)[k] is List && ((s.raw['skins'] as Map)[k] as List).isNotEmpty;

  /// 지금 입은 외형 (웹 skinOn)
  SkinDef? skinOn() {
    final k = s.raw['skin'];
    if (k is! String || k.isEmpty || skinDefs[k] == null || !skinHas(k)) return null;
    return skinDefs[k];
  }

  /// 그림 id: 카엘만 외형 그림 (카엘 촌장 제외, 웹 skinSpr·skinFace)
  String skinSpr(String id) => id == 'kael' ? (skinOn()?.spr ?? id) : id;
  String skinFace(String id) => id == 'kael' ? (skinOn()?.face ?? id) : id;

  /// 외형 받기 (y = 받은 해, 0 = 해 없음). 처음 받은 외형이면 바로 입음 (웹 skinGive)
  bool skinGive(String k, int y) {
    if (skinDefs[k] == null) return false;
    final sk = _skins;
    final a = sk[k] is List ? sk[k] as List : (sk[k] = <dynamic>[]);
    final nw = a.isEmpty;
    if (y > 0 && !a.contains(y)) {
      a.add(y);
      a.sort((p, q) => asNum(p).compareTo(asNum(q)));
    } else if (a.isEmpty) {
      a.add(0);
    }
    final cur = s.raw['skin'];
    if (nw && (cur is! String || cur.isEmpty)) s.raw['skin'] = k;
    return nw;
  }
}

// ════════════════════ 보상 주기 (출석·상점·선물·보스 첫 돌파 공통) ════════════════════
extension EventAct on GameActions {
  /// 웹 evGive(id, list): 보상을 넣고 보여 줄 줄을 돌려줌
  List<EvRow> evGive(String id, List<Map<String, dynamic>> list) {
    final e = evts[id]!;
    attA();
    final rows = <EvRow>[];
    for (final r in list) {
      final k = r['k'];
      if (k == 'sf') {
        final x = c.evS(id);
        x['sf'] = asNum(x['sf']) + asNum(r['n']);
        rows.add(EvRow('sf', '${e.curN} +${asNum(r['n']).toInt()}', img: e.curImg));
      } else if (k == 'evcard') {
        final cid = r['id'] as String, n = asNum(r['n']).toInt();
        final cards = asMap(s.raw['cards']) ?? (s.raw['cards'] = <String, dynamic>{});
        cards[cid] = orNum(cards[cid], 0) + n;
        c.stat('card', n);
        final left = c.evJoinLeft(cid);
        rows.add(EvRow('evcard', '${comps[cid]!.n} 카드 +$n',
            sub: left > 0 ? '합류까지 $left장' : c.owned(cid) ? '★ 올리기에 써요' : '원정대 카드 탭에서 맞이해요', img: 'assets/game/portraits/portrait_${cid}_idle.png'));
      } else if (k == 'frame') {
        final fid = r['id'] as String;
        final u = asMap(s.raw['pfUnl']) ?? (s.raw['pfUnl'] = <String, dynamic>{});
        if (!truthy(u[fid])) {
          u[fid] = 1;
          (asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{}))['f_$fid'] = 1;
        }
        rows.add(EvRow('frame', '테두리 「${decoName(pframes, fid)}」', sub: '프로필에서 쓸 수 있어요', img: frameAsset(fid)));
      } else if (k == 'badge') {
        final bid = r['id'] as String;
        final u = asMap(s.raw['bdUnl']) ?? (s.raw['bdUnl'] = <String, dynamic>{});
        if (!truthy(u[bid])) {
          u[bid] = 1;
          (asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{}))['b_$bid'] = 1;
        }
        rows.add(EvRow('badge', '배지 「${decoName(badges, bid)}」', sub: '프로필에서 대표 배지로 달 수 있어요', img: badgeAsset(bid)));
      } else {
        final g = attGive(r).$2;
        rows.add(EvRow(g.kind, g.text, sub: g.sub));
      }
    }
    c.pfCheck();
    return rows;
  }

  /// 눈사람 대장 도전 시작 (웹 evBossStart 의 확인·기록 부분). 막히면 알림 글, 되면 null
  ({String? err, int stg, bool santa, int ref}) evBossBegin(String id, {bool inCh = false}) {
    final e = evts[id];
    const none = (err: '', stg: 0, santa: false, ref: 0);
    if (e == null || e.boss == null) return none;
    if (!c.evOpen()) return (err: '${e.n}은(는) 영지 $evOpenLand부터 함께해요', stg: 0, santa: false, ref: 0);
    if (c.evPhase(e) != 'on') return (err: '눈사람 대장은 이벤트 기간에만 나와요', stg: 0, santa: false, ref: 0);
    final x = c.evToday(c.evS(id)), b = x['boss'] as Map;
    if (c.evBack(x)) return (err: evBackMsg, stg: 0, santa: false, ref: 0);
    if (asNum(b['n']) >= c.evTries(e, x)) return (err: '오늘 도전을 다 했어요. 내일 다시 와요', stg: 0, santa: false, ref: 0);
    if (inCh) return (err: '지금 하는 도전을 먼저 끝내요', stg: 0, santa: false, ref: 0);
    b['n'] = asNum(b['n']) + 1;
    if (!(asNum(b['ref']) > 0)) b['ref'] = c.evBossSt();
    c.evTouch(x);
    passAdd('snow');
    return (err: null, stg: asNum(b['st']).toInt(), santa: c.evXmas(e), ref: c.evBossRef(x));
  }

  /// 눈사람 대장 결과 (웹 evBossWin·evBossLose 의 보상 부분) → (받은 재화, 첫 돌파 보상 줄)
  (int, List<EvRow>) evBossResult(String id, bool won, int stg, bool santa) {
    final e = evts[id]!, b = e.boss!, x = c.evS(id), bs = x['boss'] as Map;
    if (!won) {
      x['sf'] = asNum(x['sf']) + b.lose;
      return (b.lose, const []);
    }
    final sf = (b.win(stg) * (santa ? b.santaX : 1)).toInt();
    x['sf'] = asNum(x['sf']) + sf;
    bs['st'] = math.max(asNum(bs['st']).toInt(), stg + 1);
    bs['best'] = math.max(asNum(bs['best']).toInt(), stg);
    final mile = asMap(bs['mile']) ?? (bs['mile'] = <String, dynamic>{});
    final mr = !truthy(mile['$stg']) ? b.mile(stg) : null;
    var rows = const <EvRow>[];
    if (mr != null) {
      mile['$stg'] = 1;
      rows = evGive(id, mr);
    }
    return (sf, rows);
  }

  /// 이벤트 출석 받기 (웹 evAttClaim) → (몇 번째, 받은 줄) 또는 알림 글
  ({String? err, int i, List<EvRow> rows}) evAttClaim(String id) {
    final e = evts[id]!, x = c.evS(id), a = x['att'] as Map;
    if (c.evBack(x)) return (err: evBackMsg, i: 0, rows: const []);
    if (!c.evAttCan(e)) return (err: asNum(a['cnt']) >= e.att.length ? '출석 ${e.att.length}칸을 모두 채웠어요' : '오늘은 이미 받았어요. 내일 또 만나요', i: 0, rows: const []);
    final i = asNum(a['cnt']).toInt();
    a['cnt'] = i + 1;
    a['last'] = c.evDay();
    c.evTouch(x);
    return (err: null, i: i, rows: evGive(id, e.att[i]));
  }

  /// 상점 사기 (웹 evBuy)
  ({String? err, List<EvRow> rows}) evBuy(String id, String k) {
    final e = evts[id]!, x = c.evS(id);
    EvShopItem? it;
    for (final s0 in e.shop) {
      if (s0.k == k) it = s0;
    }
    if (it == null || !const ['on', 'shop'].contains(c.evPhase(e))) return (err: '', rows: const []);
    if (c.evShopLeft(e, it) <= 0 || c.evShopOwned(it)) return (err: '더 살 수 없어요', rows: const []);
    if (it.r.any((r) => r['k'] == 'lcard') && !lcardCan()) return (err: '전설 동료 카드가 나오기 시작하면 살 수 있어요', rows: const []);
    if (it.r.any((r) => r['k'] == 'evcard' && c.recStar(r['id'] as String) >= c.starMax(r['id'] as String))) return (err: '별을 모두 모았어요', rows: const []);
    if (asNum(x['sf']) < it.p) return (err: '${e.curN}이(가) 부족해요', rows: const []);
    x['sf'] = asNum(x['sf']) - it.p;
    final shop = x['shop'] as Map;
    shop[k] = orNum(shop[k], 0) + 1;
    return (err: null, rows: evGive(id, it.r));
  }

  /// 크리스마스 주간 오늘 들어옴 기록 (배지 「메리 크리스마스」, 웹 evXmasCheck 앞부분) → 기록했으면 true
  bool evXmasMark(EventDef e) {
    if (!c.evXmas(e) || !c.evOpen()) return false;
    final x = c.evS(e.id), t = c.evDay(), days = (x['xm'] as Map)['days'] as Map;
    if (c.evBack(x) || truthy(days[t])) return false;
    days[t] = 1;
    c.evTouch(x);
    c.pfCheck();
    return true;
  }

  /// 산타 피트 오늘 선물 (25일은 큰 선물, 웹 evGiftSheet) → null 이면 줄 것 없음
  ({bool big, List<EvRow> rows})? evGift(String id) {
    final e = evts[id]!, x = c.evS(id), t = c.evDay(), gift = (x['xm'] as Map)['gift'] as Map;
    if (!c.evXmas(e) || truthy(gift[t]) || c.evBack(x)) return null;
    final xm = e.xm!, big = c.evXmDay() == asNum(_mm(xm['big'])['day']);
    gift[t] = 1;
    c.evTouch(x);
    return (big: big, rows: evGive(id, big ? _ml(_mm(xm['big'])['r']) : _ml(xm['gift'])));
  }

  /// 마을 광장 트리 선물 (하루 1번, 3가지 중 하나, 웹 evTreeHit) → 알림 글 또는 받은 줄
  ({String? err, List<EvRow> rows}) evTreeTake(EventDef e) {
    final x = c.evS(e.id), t = c.evDay(), xm = x['xm'] as Map;
    if (c.evBack(x)) return (err: evBackMsg, rows: const []);
    if (xm['tree'] == t) return (err: '🎄 오늘 선물은 받았어요. 내일 또 생겨요', rows: const []);
    xm['tree'] = t;
    c.evTouch(x);
    final opts = e.xm!['tree'] as List, r = _ml(opts[(rng.next() * opts.length).floor()]);
    return (err: null, rows: evGive(e.id, r));
  }
}

Map<String, dynamic> _mm(Object? v) => (v as Map).cast<String, dynamic>();

/// 테두리·배지 이름 (웹 PFN·BDN)
String decoName(List<Deco> l, String k) {
  for (final d in l) {
    if (d.k == k) return d.n;
  }
  return k;
}
