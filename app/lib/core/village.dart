/// 마을 확장 「다시 살아나는 에르단 마을」 (docs/content/VILLAGE.md)
///
/// 웹 index.html 「마을 확장 규칙」 구역(workBonus·prodMul·ordNew·blessOpts·vLv …)을 같은 이름·같은 계산 순서로 옮긴 것.
/// 저장 필드도 웹과 같다: bld.forge/market/ranch/chapel, items.egg/milk, orders, ordDay, bless, vlv, ep, walkers,
/// keepOrder, work, workIntro, workDot. 은퇴해도 모두 유지된다.
library;

import 'dart:math' as math;

import 'calc.dart';
import 'data.dart';
import 'js.dart';
import 'rng.dart';
import 'web_data.g.dart';

/// 일꾼과 잘 맞는 직업 (건물 → 직업)
final Map<String, String> workJob = wWjob.cast<String, String>();
final Map<String, num> wBase = wWbase.cast<String, num>();
final Map<String, String> wEffName = wWeff.cast<String, String>();
final Map<String, String> villagePeople = wVppl.cast<String, String>();
final List<int> vlvNeed = List<int>.of(wVlv);
final List<int> vlvGem = List<int>.of(wVlvGem);
final int ordGemCap = (wOrd['gem'] as num).toInt();
final int ordWait = (wOrd['wait'] as num).toInt();
final num ordMul = wOrd['mul'] as num, ordLvPct = wOrd['lv'] as num;

/// 축복 5종 (이름·짧은 이름·효과)
class BlessDef {
  const BlessDef(this.k, this.n, this.s, this.d);
  final String k, n, s, d;
}

final List<BlessDef> blessings = [
  for (final e in wBls.entries) BlessDef(e.key, e.value['n']!, e.value['s']!, e.value['d']!)
];
BlessDef blessDef(String k) => blessings.firstWhere((b) => b.k == k);

/// 동료 마을 에피소드 (마을 Lv.2·4·6·8·10)
final Map<int, (String, List<String>)> villageEpisodes = {
  for (final e in wVep.entries) int.parse(e.key): (e.value[0] as String, [for (final x in e.value[1] as List) x as String])
};

/// 건물 열림 대사 (5-1), 대장간 이사 대사
final Map<String, List<String>> villageOpenLines = {for (final e in wVopen.entries) e.key: e.value};
final List<String> forgeMoveLines = wVmove;

/// 마을 길 위·일꾼 한마디
List<String> villageTalk(String id) => wVtalk[id] ?? wVtalk[jobOf[id]] ?? const ['…'];

String? workLine(String id) => wWline[id];

/// 효과의 절반만 적용되는 건물 (여관 방치 골드·대장간 비용 감소·시장 주문 골드)
num wkReal(String k, num v) => k == 'inn' || k == 'forge' || k == 'market' ? v / 2 : v;

/// 주문 칸 수 (시장 레벨)
int ordN(num l) => l > 0 ? math.min(5, 2 + (l / 3).floor()) : 0;

/// 축복 시간(초): 2시간 + 10분 × 예배당 레벨
num blessSec(num l) => 7200 + 600 * l;

/// 대장간 레벨 l의 강화 최대 단계
int enMaxL(num l) => 20 + (l / 2).floor();

extension VillageCalc on GameCalc {
  // ───────────── 일꾼 ─────────────
  Map<String, dynamic> get work {
    final w = s.raw['work'];
    if (w is Map<String, dynamic>) return w;
    if (w is Map) return s.raw['work'] = w.cast<String, dynamic>();
    return s.raw['work'] = <String, dynamic>{};
  }

  int wkSlots(String k) {
    final l = orNum(s.bld[k], 0);
    return l <= 0 ? 0 : l >= 5 ? 2 : 1;
  }

  bool wkMatch(String k, String id) => workJob[k] != null && jobOf[id] == workJob[k];
  num wkOne(String k, String id) => (wBase[gradeOf[id] ?? 'common']! + .02 * recStar(id)) * (wkMatch(k, id) ? 2 : 1);

  /// 그 건물 일꾼 (가진 동료만, 칸 수까지)
  List<String> wkIds(String k) {
    final w = work[k];
    if (w is! List) return [];
    return [for (final id in w) if (id is String && id.isNotEmpty && id != 'kael' && id != GameCalc.chiefId && comps.containsKey(id) && owned(id)) id].take(wkSlots(k)).toList();
  }

  /// 건물 k의 일꾼 효과 합(0.4 = +40%). 생산·비용·시간·방치 골드 계산은 모두 이 함수로
  num workBonus(String k) {
    final ids = wkIds(k);
    if (ids.isEmpty) return 0;
    final mem = members();
    num a = 0;
    for (final id in ids) {
      a = a + (mem.contains(id) ? 0 : wkOne(k, id));
    }
    return a;
  }

  /// 일하는 동료 → 건물
  Map<String, String> working() {
    final m = <String, String>{};
    for (final k in work.keys) {
      for (final id in wkIds(k)) {
        m[id] = k;
      }
    }
    return m;
  }

  /// 쉬는 동료(일꾼 포함)
  List<String> restIds() {
    final mem = members();
    return GameCalc.compIds().where((id) => owned(id) && !mem.contains(id)).toList();
  }

  /// 일도 안 하는 동료
  List<String> idleIds() {
    final w = working();
    return restIds().where((id) => !w.containsKey(id)).toList();
  }

  bool wkOpen() => restIds().isNotEmpty || working().isNotEmpty;

  /// 출전 편성에 들어간 동료·잃은 동료를 일꾼 칸에서 정리. 빠진 동료 목록을 돌려줌 (웹 wkClean)
  List<String> wkClean() {
    final w = work, mem = members(), seen = <String>{}, back = <String>[];
    for (final k in w.keys.toList()) {
      if (!buildings.any((b) => b.k == k) || w[k] is! List) {
        w.remove(k);
        continue;
      }
      final keep = <String>[];
      for (final id in w[k] as List) {
        if (id is! String || id.isEmpty || id == 'kael' || !comps.containsKey(id) || !owned(id) || seen.contains(id)) continue;
        if (mem.contains(id)) {
          back.add(id);
          continue;
        }
        if (keep.length >= wkSlots(k)) continue;
        seen.add(id);
        keep.add(id);
      }
      w[k] = keep;
    }
    return back;
  }

  // ───────────── 효과 배수 ─────────────
  /// 생산 배수: 전설 동료 마을 스킬 × 은퇴 특성 × (1+일꾼) × 일꾼의 축복
  num prodMul(String b) =>
      (b == 'mine' ? vpMine() : b == 'dock' ? vpFish() : b == 'apiary' ? vpHoney() : 1) *
      vpChief() *
      trProd() *
      (1 + workBonus(b)) *
      (blOn('work') && const ['dock', 'apiary', 'mine', 'ranch'].contains(b) ? 1.5 : 1);

  /// 요리 버프 시간(ms): 덕배 마을 스킬·은퇴 특성·식당 일꾼을 더함
  num cookMs() => 600000 * (vpCook() + trCook() + workBonus('diner'));
  num vHp() => (buff('hp') ? 1.3 : 1) * (1 + .03 * orNum(s.bld['ranch'], 0));
  num vBrave() => blOn('brave') ? 1.2 : 1;

  /// 방치 골드: 마을 레벨 +2%/Lv · 여관 일꾼 효과의 절반
  num vIdle() => 1 + .02 * vLv() + workBonus('inn') / 2;

  /// 대장간: 강화 최대 단계·광석 비용 배수(최대 −50%)
  int enMax() => enMaxL(orNum(s.bld['forge'], 0));
  num forgeCut() => math.max(.5, 1 - .03 * math.max(0, orNum(s.bld['forge'], 1) - 1) - workBonus('forge') / 2);

  // ───────────── 마을 레벨 ─────────────
  int bldSum() {
    num a = 0;
    for (final b in buildings) {
      a = a + orNum(s.bld[b.k], 0);
    }
    return a.toInt();
  }

  int vLv() {
    final sm = bldSum();
    var l = 1;
    for (var i = 0; i < vlvNeed.length; i++) {
      if (sm >= vlvNeed[i]) l = i + 1;
    }
    return l;
  }

  int get vlvGot => orNum(s.raw['vlv'], 1).toInt();
  bool vlRw() => vLv() > vlvGot;

  // ───────────── 피트의 시장 — 주문 게시판 ─────────────
  List<dynamic> get orders => s.raw['orders'] is List ? s.raw['orders'] as List : (s.raw['orders'] = <dynamic>[]);

  List<String> ordMats() => [
        if (truthy(s.bld['farm'])) ...crops.map((c) => c.k),
        for (final g in goods)
          if (orNum(s.bld[g.b], 0) > 0) g.k,
      ];

  /// 그 재료 2분 생산량(건물 레벨 기준). 작물은 밭 칸을 세 작물이 나눠 쓴다고 봄
  num per2(String k) {
    for (final g in goods) {
      if (g.k == k) return orNum(s.bld[g.b], 0) * 2 / g.m;
    }
    final c = crops.firstWhere((x) => x.k == k);
    return plotCount() * 2.3 * 120 / c.t / 3;
  }

  static int _rint(KdRandom r, int a, int b) => a + (r.next() * (b - a + 1)).floor();

  num ordQty(KdRandom r, String k, [bool two = false]) {
    num n = per2(k) * _rint(r, 10, 25) * (two ? .6 : 1);
    n = math.max(3, jsRound(n));
    return n >= 20 ? jsRound(n / 5) * 5 : n;
  }

  Map<String, dynamic> ordDay() {
    final o = asMap(s.raw['ordDay']) ?? (s.raw['ordDay'] = <String, dynamic>{'d': '', 'gem': 0, 'skip': <String, dynamic>{}});
    if (o['d'] != today()) {
      o['d'] = today();
      o['gem'] = 0;
      o['skip'] = <String, dynamic>{};
    }
    return o;
  }

  Map<String, dynamic> ordNew(KdRandom r, int i) {
    final mats = ordMats();
    if (mats.isEmpty) return <String, dynamic>{'at': now + ordWait};
    final used = <String, int>{};
    final os = orders;
    for (var j = 0; j < os.length; j++) {
      final o = asMap(os[j]);
      if (j != i && o != null && truthy(o['need'])) {
        for (final k in (o['need'] as Map).keys) {
          used[k as String] = (used[k] ?? 0) + 1;
        }
      }
    }
    final okM = mats.where((k) => (used[k] ?? 0) < 2).toList(), pool = okM.isNotEmpty ? okM : mats;
    final whos = [...GameCalc.compIds().where(owned), 'marta', 'timo', 'pete'];
    final who = whos[(r.next() * whos.length).floor()];
    final likeRaw = wLike[who] ?? (who == 'pete' ? pool : wLike[jobOf[who]]) ?? const <String>[];
    final lk = [for (final k in likeRaw) if (pool.contains(k)) k];
    final from = lk.isNotEmpty ? lk : pool;
    final a = from[(r.next() * (lk.isNotEmpty ? lk.length : pool.length)).floor()];
    final two = r.next() < .35 && pool.length > 1;
    final need = <String, dynamic>{};
    if (two) {
      final rest = pool.where((k) => k != a).toList(), b = rest[(r.next() * rest.length).floor()];
      need[a] = ordQty(r, a, true);
      need[b] = ordQty(r, b, true);
    } else {
      need[a] = ordQty(r, a);
    }
    final x = r.next();
    final extra = x < .4
        ? <String, dynamic>{'k': 'ore', 'n': _rint(r, 10, 30)}
        : x < .7
            ? <String, dynamic>{'k': 'seed', 'n': 1}
            : x < .85
                ? <String, dynamic>{'k': 'card', 'n': 2}
                : <String, dynamic>{'k': 'gem', 'n': _rint(r, 3, 5)};
    return <String, dynamic>{'who': who, 'need': need, 'gold': 0, 'extra': extra, 'at': 0};
  }

  /// 빈 칸은 1시간 뒤 새 주문(접속하지 않아도 시간은 흐름). 시장 레벨이 오르면 칸이 늘어남
  void ordTick(KdRandom r) {
    final n = ordN(orNum(s.bld['market'], 0));
    if (n == 0) return;
    final os = orders;
    while (os.length < n) {
      os.add(null);
    }
    for (var i = 0; i < os.length; i++) {
      final o = asMap(os[i]);
      if (o == null || (!truthy(o['need']) && now >= orNum(o['at'], 0))) os[i] = ordNew(r, i);
    }
  }

  num ordGold(Map<String, dynamic> o) {
    num a = 0;
    for (final e in (o['need'] as Map).entries) {
      a = a + itemPrice(e.key as String) * (e.value as num);
    }
    return jsFloor(a * ordMul * (1 + ordLvPct * orNum(s.bld['market'], 0) + wkReal('market', workBonus('market'))));
  }

  bool ordCan(Object? x) {
    final o = asMap(x);
    if (o == null || !truthy(o['need'])) return false;
    return (o['need'] as Map).entries.every((e) => orNum(s.items[e.key], 0) >= (e.value as num));
  }

  int ordReady() => truthy(s.bld['market']) ? orders.where(ordCan).length : 0;

  /// 창고 판매 때 남길 재료 (주문 재료 남기기)
  Map<String, num> ordKeep() {
    final m = <String, num>{};
    if (truthy(s.raw['keepOrder']) && truthy(s.bld['market'])) {
      for (final x in orders) {
        final o = asMap(x);
        if (o != null && truthy(o['need'])) {
          for (final e in (o['need'] as Map).entries) {
            m[e.key as String] = (m[e.key] ?? 0) + (e.value as num);
          }
        }
      }
    }
    return m;
  }

  // ───────────── 별빛 예배당 — 축복 ─────────────
  Map<String, dynamic> get bless => asMap(s.raw['bless']) ?? (s.raw['bless'] = <String, dynamic>{'d': '', 'used': 0, 'ad': 0, 'k': '', 'until': 0, 'opts': <dynamic>[]});

  String blessK() {
    final b = asMap(s.raw['bless']);
    if (b == null) return '';
    final k = b['k'];
    return k is String && k.isNotEmpty && blessings.any((x) => x.k == k) && orNum(b['until'], 0) > now ? k : '';
  }

  bool blOn(String k) => blessK() == k;
  num blessMs() => blessSec(orNum(s.bld['chapel'], 0)) * 1000 * (1 + workBonus('chapel'));

  Map<String, dynamic> blessDay() {
    final b = bless;
    if (b['d'] != today()) {
      b['d'] = today();
      b['used'] = 0;
      b['ad'] = 0;
      b['opts'] = <dynamic>[];
    }
    return b;
  }

  int blessLeft() {
    if (!truthy(s.bld['chapel'])) return 0;
    final b = blessDay();
    return math.max(0, 1 + (truthy(b['ad']) ? 1 : 0) - orNum(b['used'], 0)).toInt();
  }

  List<String> blessOpts(KdRandom r) {
    final b = blessDay();
    if (blessLeft() > 0 && (b['opts'] is! List || (b['opts'] as List).isEmpty)) {
      b['opts'] = shuf(r, blessings.map((x) => x.k).toList()).take(orNum(s.bld['chapel'], 0) >= 5 ? 4 : 3).toList();
    }
    return blessLeft() > 0 ? [for (final x in b['opts'] as List) x as String] : [];
  }

  /// 웹 shuf: 뒤에서부터 바꾸기
  static List<T> shuf<T>(KdRandom r, List<T> a0) {
    final a = [...a0];
    for (var i = a.length - 1; i > 0; i--) {
      final j = (r.next() * (i + 1)).floor();
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    return a;
  }

  // ───────────── 길 위 사람 ─────────────
  /// 오늘 길 위에 서 있는 쉬는 동료(매일 0시에 바뀜, 최대 6)
  List<String> walkersToday(KdRandom r) {
    final w = asMap(s.raw['walkers']) ?? (s.raw['walkers'] = <String, dynamic>{'d': '', 'ids': <dynamic>[]});
    final idle = idleIds();
    if (w['d'] != today()) {
      w['d'] = today();
      w['ids'] = shuf(r, idle).take(6).toList();
    }
    final ids = w['ids'] is List ? w['ids'] as List : (w['ids'] = <dynamic>[]);
    final cur = [for (final id in ids) if (idle.contains(id)) id as String];
    for (final id in idle) {
      if (cur.length >= 6) break;
      if (!ids.contains(id)) {
        ids.add(id);
        cur.add(id);
      }
    }
    return cur.take(6).toList();
  }
}
