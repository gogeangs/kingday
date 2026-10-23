/// 도전 콘텐츠: 시련의 탑 · 요일 던전 (docs/content/CHALLENGE.md)
///
/// 웹 index.html 「도전」 구역과 같은 규칙·같은 저장 필드(S.chOpen, S.tower, S.dun).
/// 전투 진행은 battle/sim.dart 의 [ChState], 화면은 screens/challenge_sheet.dart.
library;

import 'dart:math' as math;

import 'calc.dart';
import 'data.dart';
import 'fmt.dart';
import 'js.dart';

/// 영지 20을 되찾으면 열림 (은퇴해도 유지: S.chOpen)
const int chOpenLand = 20;

// ───────────── 시련의 탑 ─────────────
class TowerRule {
  const TowerRule(this.n, this.d);
  final String n, d;
}

/// 5·15·25…층에 차례로 붙는 시련 규칙
const towerRules = [
  TowerRule('회복 금지', '원정대 회복 효과가 모두 막혀요'),
  TowerRule('쌍둥이', '보스 2마리 · 각각 체력 60%'),
  TowerRule('급한 전투', '제한 시간 20초 · 보스 체력 80%'),
  TowerRule('단단한 껍질', '보스가 받는 피해 −50% · 대신 공격 −50%'),
];
/// 추억 속 원정대: 이 배수부터 화면에 표시 (웹 PK_SHOW)
const num pkShow = 1.1;

/// 배수 글자 (웹 pmTag: 10 미만은 소수 한 자리)
String pmText(num pm) => pm < 10 ? pm.toStringAsFixed(1) : fmt(pm);

const int towerLim = 30, towerGateLim = 40, towerRushLim = 20, towerGem = 30;

/// 탑 보스 그림: 지역 번호(ri) + 군단장(lord)/발타사르(balt)/근위대장(guard)/잔영(ghost)
class TowerArt {
  const TowerArt({required this.ri, this.lord = false, this.balt = false, this.guard = false, this.ghost});
  final int ri;
  final bool lord, balt, guard;
  final int? ghost;
}

class TowerInfo {
  TowerInfo(this.f, this.s, this.gate, this.rule, this.art, this.name, this.face, this.hp, this.atk, this.lim);
  final int f, s, rule;
  final bool gate;
  final TowerArt art;
  final String name;
  final String? face;
  final num hp, atk;
  final int lim;
}

/// 층 f = 영지 단계 f+5 의 보스 수치. 10층마다 수문장(군단장 수치·40초), 100층마다 발타사르 그림 (웹 towerInfo)
TowerInfo towerInfo(int f) {
  final s = f + 5, gate = f % 10 == 0, rule = !gate && f % 5 == 0 ? ((f - 5) ~/ 10) % 4 : -1;
  late TowerArt art;
  late String name;
  String? face;
  if (f % 100 == 0) {
    art = const TowerArt(ri: 5, balt: true);
    name = '$f층 수문장 · 마왕 발타사르';
    face = 'baltasar';
  } else if (gate) {
    final ri = (f ~/ 10 - 1) % 5;
    art = TowerArt(ri: ri, lord: true);
    name = '$f층 수문장 · ${regions[ri].boss}';
    face = bossIds[ri];
  } else {
    final k = (f - 1) % 7;
    if (k < 5) {
      art = TowerArt(ri: k);
      name = '$f층 · ${regions[k].n}의 마족 성주';
    } else if (k == 5) {
      art = const TowerArt(ri: 5, guard: true);
      name = '$f층 · 마왕 근위대장';
    } else {
      final gi = ((f - 1) ~/ 7) % 5;
      art = TowerArt(ri: gi, ghost: gi);
      name = '$f층 · 잔영: ${regions[gi].boss}';
      face = bossIds[gi];
    }
  }
  final hp = GameCalc.monHp(s, false) * (gate ? Balance.lordHp : Balance.bossHp) * (rule == 2 ? .8 : 1) * (rule == 1 ? .6 : 1);
  final atk = GameCalc.monAtk(s, false) * (gate ? Balance.lordAtk : Balance.bossAtk) * (rule == 3 ? .5 : 1);
  return TowerInfo(f, s, gate, rule, art, name, face, hp, atk, gate ? towerGateLim : rule == 2 ? towerRushLim : towerLim);
}

num towerGold(int f) => GameCalc.reward(f + 5, true) * 3;
int towerOre(int f) => 5 + f ~/ 5;

// ───────────── 요일 던전 ─────────────
class DunDef {
  const DunDef(this.k, this.n, this.ic, this.ri, this.mri, this.alt, this.days, this.rw, this.npc, this.intro);
  final String k, n, ic, rw, npc, intro;

  /// 배경 지역(ri) · 마물 그림 지역(mri)
  final int ri, mri;
  final bool alt;
  final List<int> days;
}

const List<DunDef> duns = [
  DunDef('mine', '브론의 폐광', '⛏️', 2, 2, false, [1, 4], '광석', '브론', 'm:브론|무너진 갱도에 강철 골렘이 눌러앉았어. 부수면 광석이 한가득이지.'),
  DunDef('field', '마르타의 들판', '🌾', 0, 0, true, [2, 5], '씨앗', '마르타', 'm:마르타|허수아비가 씨앗을 다 훔쳐 갔어. 찾아오면 반은 네 거다.'),
  DunDef('vault', '고블린 금고', '💰', 1, 2, true, [3, 6], '골드', '피트', 'm:피트|고블린들이 금고를 털었대요. 되찾아 오시면 수고비 두둑이!'),
];
DunDef dunDef(String k) => duns.firstWhere((d) => d.k == k);

/// 별 기준·마물 수·간격·체력·공격 배수는 tools/challenge_sim.py 로 조정 (웹 DUN_STAR·DUNB 와 같음)
const int dunT = 180, dunTk = 2;
const List<int> dunStars = [30, 60, 95];
const List<num> dunRate = [0, .4, .7, 1];
const int dunLive = 3;
const num dunSp = .3, dunHpM = 1, dunAtkM = .5;

/// 보상 묶음 (골드·광석·씨앗 3종·황금 이삭)
typedef Reward = Map<String, num>;
const rewardNames = {
  'gold': ('골드', 'assets/game/ui/ui_gold.png'),
  'ore': ('광석', 'assets/game/ui/item_ore.png'),
  'wheat': ('밀 씨앗', 'assets/game/ui/seed_wheat.png'),
  'carrot': ('은빛 당근 씨앗', 'assets/game/ui/seed_carrot.png'),
  'pumpkin': ('달빛 호박 씨앗', 'assets/game/ui/seed_pumpkin.png'),
  'gem': ('황금 이삭', 'assets/game/gem/ui_gem.png'),
};
String rewardText(Reward r) => [
      for (final e in rewardNames.entries)
        if ((r[e.key] ?? 0) > 0) '${e.value.$1} +${r[e.key]!.round()}'
    ].join(' · ');

extension ChallengeCalc on GameCalc {
  Map<String, dynamic> _o(String k) {
    final v = asMap(s.raw[k]);
    if (v != null) return s.raw[k] = v;
    return s.raw[k] = <String, dynamic>{};
  }

  Map<String, dynamic> get towerS => _o('tower');
  Map<String, dynamic> get dunS {
    final d = _o('dun');
    d['star'] = asMap(d['star']) ?? <String, dynamic>{};
    final st = d['star'] as Map<String, dynamic>;
    for (final k in const ['mine', 'field', 'vault']) {
      st[k] = asMap(st[k]) ?? <String, dynamic>{};
    }
    d['seen'] = asMap(d['seen']) ?? <String, dynamic>{};
    return d;
  }

  bool get chOpen => truthy(s.raw['chOpen']);
  bool chCan() => math.min(s.best, maxLand + 1) - 1 >= chOpenLand;
  int towerTop() => orNum(towerS['top'], 0).toInt();

  /// 매일 탑 보급: 방치 보상 (30+최고 층)분 어치(최대 120분) + 광석 5+floor(최고 층/5)×2
  int supplyMin() => math.min(120, 30 + towerTop());
  int supplyOre() => 5 + (towerTop() ~/ 5) * 2;
  bool supplyCan() => chCan() && towerS['day'] != today();

  /// 오늘 요일 (웹 getDay: 0 = 일요일)
  int weekday() => DateTime.fromMillisecondsSinceEpoch(now).weekday % 7;

  Map<String, dynamic> dunDay() {
    final d = dunS;
    if (d['d'] != today()) {
      d['d'] = today();
      d['used'] = 0;
      d['ad'] = 0;
    }
    return d;
  }

  int dunLeft() {
    final d = dunDay();
    return math.max(0, dunTk + (truthy(d['ad']) ? 1 : 0) - orNum(d['used'], 0).toInt());
  }

  List<String> dunOpenK([int? wd]) {
    final w = wd ?? weekday();
    return [for (final d in duns) if (w == 0 || d.days.contains(w)) d.k];
  }

  int bestLand() => math.max(1, math.min(s.best, maxLand + 1) - 1);
  int dunL() => math.max(1, math.min(12, bestLand() ~/ 5));
  int dunMs() => math.max(1, bestLand() - 3);
  Map<String, dynamic> _star(String k) => asMap(asMap(dunS['star'])![k])!;
  int dunStar(String k, int l) => orNum(_star(k)['$l'], 0).toInt();

  /// 소탕: 지금 단계 이상에서 ★3을 받은 적이 있으면 지금 단계 ★3 보상
  bool sweepOk(String k) => _star(k).entries.any((e) => orNum(e.value, 0) >= 3 && (int.tryParse(e.key) ?? 0) >= dunL());

  void setDunStar(String k, int l, int star) => _star(k)['$l'] = math.max(dunStar(k, l), star);

  Reward dunReward(String k, int l, num rate, bool gob) {
    int fl(num x) => jsFloor(x * rate).toInt();
    if (k == 'mine') return {'ore': fl(20 + l * 5)};
    if (k == 'field') return {'wheat': fl(6 + l), 'carrot': fl(3 + l ~/ 2), 'pumpkin': fl(1 + l ~/ 4)};
    return {'gold': jsFloor(idleGold(3600) * rate * (gob ? 1.2 : 1))};
  }

  void rwGive(Reward r) {
    if ((r['gold'] ?? 0) > 0) s.gold = s.gold + r['gold']!;
    if ((r['ore'] ?? 0) > 0) s.items['ore'] = orNum(s.items['ore'], 0) + r['ore']!;
    for (final c in const ['wheat', 'carrot', 'pumpkin']) {
      if ((r[c] ?? 0) > 0) s.seeds[c] = orNum(s.seeds[c], 0) + r[c]!;
    }
    if ((r['gem'] ?? 0) > 0) s.gem = s.gem + r['gem']!;
  }

  // ───────────── 추억 속 원정대 (CHALLENGE.md 11장) ─────────────
  /// 탑·던전에서는 원정대 힘을 「지금」과 「역대 최고」 중 센 쪽으로.
  /// S.tower.pk = 역대 최고 전투력(요리 버프 빼고) ÷ 그때의 영구 배수(추억·날 선 괭이) (웹 pkPerm·pkCheck·chPm)
  num pkPerm() => memMul() * trAtk();

  /// 요리 버프·루카 빵 배달을 뺀 전투력 (웹 powNoBuff)
  num powNoBuff() {
    final b = s.raw['buffs'], bp = bakeProbe, ba = bakeActive, up = ulProbe;
    s.raw['buffs'] = <String, dynamic>{};
    bakeProbe = null;
    bakeActive = false;
    ulProbe = null;
    try {
      return power();
    } finally {
      s.raw['buffs'] = b;
      bakeProbe = bp;
      bakeActive = ba;
      ulProbe = up;
    }
  }

  void pkCheck() {
    final p = powNoBuff();
    if (!(p > 0)) return;
    final v = p / pkPerm();
    if (v > orNum(towerS['pk'], 0)) towerS['pk'] = v;
  }

  /// 역대 최고 원정대 전투력 (지금 추억·특성 기준)
  num pkPow() => orNum(towerS['pk'], 0) * pkPerm();

  /// 탑·던전 배수 = max(1, 역대 최고 ÷ 지금)
  num chPm() {
    final p = powNoBuff();
    return p > 0 ? math.max(1, pkPow() / p) : 1;
  }

  /// 도전 버튼 노란 점: 오늘 탑 보급을 안 받았거나 입장권이 남음
  bool chDot() => chOpen && (supplyCan() || dunLeft() > 0);

  /// 탑 보급 받기. 받았으면 (골드, 광석)
  (num, int)? claimSupply() {
    if (!supplyCan()) return null;
    final g = jsFloor(idleGold(60 * supplyMin())), o = supplyOre();
    s.gold = s.gold + g;
    s.items['ore'] = orNum(s.items['ore'], 0) + o;
    towerS['day'] = today();
    return (g, o);
  }
}
