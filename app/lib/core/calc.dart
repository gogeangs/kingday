/// 게임 공식 — 웹 index.html 의 「능력치」「밸런스 손잡이」「데이터」 공식을 그대로 옮긴 것.
///
/// **웹과 같은 공식·같은 숫자**가 원칙이다. 계산 순서(곱하는 순서까지)도 웹과 같게 두어
/// 소수점 끝자리까지 같은 값이 나오게 했다. 값이 맞는지는 test/parity_test.dart 가
/// 웹 코드에서 뽑은 정답 값(test/fixtures/web_parity.json)과 비교해 확인한다.
///
/// 웹 함수 이름을 주석으로 붙여 두었으니, 웹 공식을 바꾸면 같은 이름을 찾아 함께 고친다.
library;

import 'dart:math' as math;

import 'data.dart';
import 'js.dart';
import 'rng.dart';
import 'state.dart';
import 'web_data.g.dart';

/// 공격·체력·공속·치명
class Stats {
  const Stats(this.atk, this.hp, this.aps, this.crit);
  final num atk, hp, aps, crit;
  Map<String, num> toJson() => {'atk': atk, 'hp': hp, 'aps': aps, 'crit': crit};
}

/// 성유물 (웹: {slot,g,lv,atk,hp,price})
class Relic {
  const Relic({required this.slot, required this.g, required this.lv, required this.atk, required this.hp, required this.price});
  factory Relic.fromJson(Map<String, dynamic> m) => Relic(
      slot: m['slot'], g: asNum(m['g']).toInt(), lv: asNum(m['lv']).toInt(),
      atk: asNum(m['atk']), hp: asNum(m['hp']), price: asNum(m['price']));
  final String slot;
  final int g, lv;
  final num atk, hp, price;
  Map<String, dynamic> toJson() => {'slot': slot, 'g': g, 'lv': lv, 'atk': atk, 'hp': hp, 'price': price};
}

/// 저장 데이터 하나에 대한 공식 묶음.
/// 웹은 전역 S 와 Date.now() 를 직접 읽지만, 앱은 둘 다 여기로 넘겨받는다.
class GameCalc {
  GameCalc(this.s, {int Function()? clock}) : _clock = clock ?? _wallClock;
  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final GameState s;
  final int Function() _clock;
  int get now => _clock();

  /// 루카 스킬 「아침 빵 배달」 공속 증가 중인지 (웹 SKX.bake>0).
  /// 전투 시뮬레이션이 [bakeProbe] 로 알려 준다.
  bool bakeActive = false;
  bool Function()? bakeProbe;
  bool get _bake => bakeProbe?.call() ?? bakeActive;

  // ───────────── 영지 ─────────────
  /// 61 이상은 왕도에 머묾 (웹 region: % 대신 최댓값)
  static RegionDef region(int st) => regions[regionIndex(st)];
  static int regionIndex(int st) => math.max(0, math.min((st - 1) ~/ 10, regions.length - 1));
  static String terrName(int st) => st > maxLand ? '왕궁 뜰' : region(st).terr[(st - 1) % 10];
  static bool isLord(int st) => st % 10 == 0;

  // 왕도 (51~60): 홀수 = 군단장 잔영, 짝수 = 마왕 근위대장, 60 = 마왕 발타사르, 61 = 왕궁 뜰
  static const int cap0 = maxLand - 10;
  static bool isCap(int st) => st > cap0 && st <= maxLand;
  static bool isDemon(int st) => st == maxLand;
  static bool isGhost(int st) => isCap(st) && st % 2 == 1;
  static int ghostIdx(int st) => (st - cap0 - 1) ~/ 2;
  static bool isGuard(int st) => isCap(st) && st % 2 == 0 && !isDemon(st);
  static String bossName(int st) => isDemon(st)
      ? '마왕 발타사르'
      : isGhost(st)
          ? '잔영: ${regions[ghostIdx(st)].boss}'
          : isGuard(st)
              ? '${terrName(st)}의 마왕 근위대장'
              : isLord(st)
                  ? region(st).boss
                  : '${terrName(st)}의 마족 성주';
  /// 보스 제한 시간 (성주 30 · 군단장 40 · 마왕 60)
  static int bossLim(int st) => isDemon(st) ? 60 : isLord(st) ? 40 : 30;
  /// 61 왕궁 뜰은 60단계 몬스터 (웹 fightSt)
  int fightSt() => math.min(s.stage, maxLand);
  int landCount() => math.min(maxLand, s.stage - 1);

  /// rankIdx(s): 되찾은 영지 수로 정하는 칭호 단계
  static int rankIdxOf(GameState st) {
    final c = math.min(maxLand, st.stage - 1);
    var i = 0;
    for (var j = 0; j < ranks.length; j++) {
      if (c >= ranks[j].at) i = j;
    }
    return i;
  }

  int rankIdx() => rankIdxOf(s);

  // ───────────── 밸런스 손잡이 (BAL) ─────────────
  /// monHp(st,b)
  static num monHp(int st, bool boss) =>
      20 * math.pow(Balance.hpG, st - 1) * (boss ? (isDemon(st) ? Balance.demHp : isLord(st) ? Balance.lordHp : Balance.bossHp) : 1);

  /// monAtk(st,b)
  static num monAtk(int st, bool boss) =>
      4 * math.pow(Balance.atkG, st - 1) * (boss ? (isDemon(st) ? Balance.demAtk : isLord(st) ? Balance.lordAtk : Balance.bossAtk) : 1);

  /// reward(st,b): 마물 1마리 골드
  static num reward(int st, bool boss) => 3 * math.pow(Balance.goldG, st - 1) * (boss ? 10 : 1);

  /// boxCost(): 성유물 상자 가격
  num boxCost() => jsFloor(20 * math.pow(Balance.boxG, s.stage - 1));
  int xpNeed() => s.boxLv * 10;

  /// odds(): 성유물 등급별 확률(%)
  List<num> odds() {
    final w = [for (var g = 0; g < baseOdds.length; g++) baseOdds[g] * math.pow(1 + .35 * (s.boxLv - 1), g)];
    num t = w.first;
    for (var i = 1; i < w.length; i++) {
      t = t + w[i];
    }
    return [for (final x in w) x / t * 100];
  }

  static num score(Relic? it) => it == null ? 0 : it.atk * 6 + it.hp;

  /// itemPrice(k): 작물·생산품 판매가
  num itemPrice(String k) => math.max(1, jsFloor(baseSell(k) * math.pow(1.16, s.best - 1)));

  // ───────────── 버프·칭호·추억 ─────────────
  /// buff(k): 요리 버프가 켜져 있는지
  bool buff(String k) => orNum(s.buffs[k], 0) > now;
  num memMul() => 1 + .05 * s.memory;
  num allMul() => (1 + .04 * rankIdx()) * memMul();
  bool subOn() {
    final sub = asMap(s.raw['sub']);
    return sub != null && asNum(sub['until']) > now;
  }

  // ───────────── 동료 등급·별 ─────────────
  static bool isRec(String id) => recruits.containsKey(id);
  static CompGrade gr(String id) => compGrades[gradeOf[id] ?? 'common']!;

  /// 웹 CARDIDS(): 이야기 동료 4 + 모집 동료
  static List<String> cardIds() => [...storyOf.values, ...recruits.keys];

  int recStar(String id) {
    final r = s.rec;
    final v = r == null ? 0 : orNum(r[id], 0);
    if (isRec(id)) return v.toInt();
    return s.isJoined(id) ? math.max(1, v.toInt()) : 0;
  }

  /// starNeed(id): 다음 별까지 필요한 카드 (최대 별이면 null)
  int? starNeed(String id) {
    if (isRec(id) && recStar(id) == 0) return 30;
    final need = gr(id).need, st = recStar(id);
    return st < need.length ? need[st].toInt() : null;
  }

  int starMax(String id) => gr(id).max;
  bool owned(String id) => id == 'kael' || (isRec(id) ? recStar(id) > 0 : s.isJoined(id));
  bool cardOpen(String id) => isRec(id) ? s.isJoined(storyOf[recruits[id]!.job]!) : s.isJoined(id);
  num starMul(String id) => id == 'kael' ? 1 : gr(id).mul * starMulTable[recStar(id)];

  /// skPow(id): 모집 동료 스킬 강화 (★3 1.3배, ★5 1.6배)
  num skPow(String id) {
    if (!isRec(id)) return 1;
    final st = recStar(id);
    return st >= 5 ? 1.6 : st >= 3 ? 1.3 : 1;
  }

  // ───────────── 전설 동료 마을 스킬 ─────────────
  static num vpPct(int st) => jsRound(50 + (st - 1) * 12.5);
  int vpSt(String id) => villageSkillName.containsKey(id) && owned(id) ? recStar(id) : 0;
  num vpMine() => vpSt('brida') != 0 ? 1 + vpPct(vpSt('brida')) / 100 : 1;

  /// 막례 「물질 대장」: 낚시터 생선 생산 (웹 vpFish)
  num vpFish() => vpSt('makrye') != 0 ? 1 + vpPct(vpSt('makrye')) / 100 : 1;

  /// 말봉 「말벌 퇴치반」: 양봉장 꿀 생산 (웹 vpHoney)
  num vpHoney() => vpSt('malbong') != 0 ? 1 + vpPct(vpSt('malbong')) / 100 : 1;

  /// 덕배 「수라간의 손맛」: 요리 버프 시간 (웹 vpCook)
  num vpCook() => vpSt('deokbae') != 0 ? 1 + vpPct(vpSt('deokbae')) / 100 : 1;
  num vpTime() => 1;
  num vpOre() => 1;

  // ───────────── 편성 ─────────────
  /// slotMember(j): 그 직업 자리에 출전 중인 동료
  String? slotMember(String j) {
    if (j == 'kael') return 'kael';
    final p = s.party;
    final pk = p?[j];
    if (pk is String && pk.isNotEmpty && owned(pk)) return pk;
    final st = storyOf[j]!;
    return s.isJoined(st) ? st : null;
  }

  /// jobMembers(j): 그 직업 자리에 설 수 있는(보유한) 동료
  List<String> jobMembers(String j) =>
      [storyOf[j]!, ...recruits.values.where((r) => r.job == j).map((r) => r.id)].where(owned).toList();

  /// members(): 출전 중인 원정대 (자리 순서)
  List<String> members() => [for (final j in jobSlots) slotMember(j)].whereType<String>().toList();

  // ───────────── 능력치 ─────────────
  int enLv(String k) => orNum(s.slotEn?[k], 0).toInt();
  num enMul(String k) => 1 + .1 * enLv(k);

  /// enCost(l): 브론의 대장간 부위 강화 광석
  num enCost(int l) => jsCeil(5 * math.pow(1.35, l) * vpOre());

  Relic? equipped(String k) {
    final m = asMap(s.eq[k]);
    return m == null ? null : Relic.fromJson(m);
  }

  /// kStats(): 카엘 능력치
  Stats kStats() {
    num ga = 0, gh = 0;
    for (final sl in slots) {
      final it = equipped(sl.k);
      if (it != null) {
        ga += it.atk * enMul(sl.k);
        gh += it.hp * enMul(sl.k);
      }
    }
    final fm = 1 + .06 * s.bldLv('mine'), m = allMul();
    return Stats(
      (10 + s.upLv('atk') * 3 + ga * fm) * (buff('atk') ? 1.2 : 1) * m,
      (100 + s.upLv('hp') * 20 + gh * fm) * (1 + .05 * s.bldLv('diner')) * m,
      (1 + s.upLv('spd') * .05) * (buff('spd') ? 1.2 : 1),
      (5 + s.upLv('crit')) / 100 + (buff('crit') ? .1 : 0),
    );
  }

  /// gearSum(): 카엘 장비 합(광산 보너스 포함) — 동료가 일부를 받음(성검의 축복)
  ({num a, num h}) gearSum() {
    num a = 0, h = 0;
    for (final sl in slots) {
      final it = equipped(sl.k);
      if (it != null) {
        a += it.atk * enMul(sl.k);
        h += it.hp * enMul(sl.k);
      }
    }
    final fm = 1 + .06 * s.bldLv('mine');
    return (a: a * fm, h: h * fm);
  }

  /// cwLv(id): 동료 전용 무기 강화 단계 (같은 직업 이야기 동료 기준으로 저장)
  int cwLv(String id) {
    final key = storyOf[jobOf[id]] ?? id;
    return orNum(s.cwEn?[key], 0).toInt();
  }

  num cwMul(String id) => 1 + .08 * cwLv(id);
  num cwOre(int l) => jsCeil(8 * math.pow(1.35, l) * vpOre());
  num cwGold(int l) => jsCeil(reward(math.max(1, s.best), false) * 12 * (l + 1));

  /// cStats(id): 동료 능력치
  Stats cStats(String id) {
    final c = comps[id]!, base = c.base!;
    final l = orNum(s.lv[id], 1);
    final m = allMul() * cwMul(id) * starMul(id), g = math.pow(compGrow, l - 1), gs = gearSum();
    return Stats(
      (base.atk * g + gs.a * bless) * (1 + .08 * s.bldLv('apiary')) * (buff('atk') ? 1.2 : 1) * m,
      (base.hp * g + gs.h * bless) * (1 + .05 * s.bldLv('diner')) * m,
      base.aps! * (buff('spd') ? 1.2 : 1) * (_bake ? 1.3 : 1),
      .05 + (buff('crit') ? .1 : 0),
    );
  }

  Stats stats(String id) => id == 'kael' ? kStats() : cStats(id);

  /// cPow(id): 동료 한 명 전투력 (편성 추천에 씀)
  num cPow(String id) {
    final t = stats(id);
    return (t.atk * 6 + t.hp) * (1 + t.crit) * t.aps * (jobOf[id] == 'keeper' ? 1.4 : 1);
  }

  /// power(): 원정대 전투력
  num power() {
    num a = 0;
    for (final id in members()) {
      final t = stats(id);
      a = a + (t.atk * 6 + t.hp) * (1 + t.crit) * t.aps * (jobOf[id] == 'keeper' ? 1.4 : 1);
    }
    return jsRound(a);
  }

  /// betterBench(j): 대기 중인 동료 중 더 강한 동료가 있는지
  bool betterBench(String j) {
    final a = slotMember(j);
    if (a == null) return false;
    final pa = cPow(a);
    return jobMembers(j).any((x) => x != a && cPow(x) > pa * 1.001);
  }

  // ───────────── 비용 ─────────────
  /// compCost(l): 동료 레벨업 골드
  static num compCost(num l) => jsFloor(25 * math.pow(1.16, l - 1));

  /// UPG[k].cost(l): 단련 비용 (화면에서 내림해서 씀)
  static num upgradeCost(String k, num l) => switch (k) {
        'atk' || 'hp' => 10 * math.pow(1.15, l),
        'spd' => 50 * math.pow(1.4, l),
        'crit' => 40 * math.pow(1.35, l),
        _ => throw ArgumentError(k),
      };

  /// bldCost(b,l)
  static num bldCost(BuildingDef b, num l) => jsFloor(b.base * math.pow(2.2, l));

  /// bldOre(b,l): 광산 재건 후, 광산 외 건물 Lv.6 이상에 필요한 광석
  num bldOre(BuildingDef b, num l) =>
      truthy(s.bld['mine']) && b.k != 'mine' && l >= 5 ? jsCeil(15 * math.pow(1.5, l - 5)) : 0;
  bool oreOk(BuildingDef b, num l) => orNum(s.items['ore'], 0) >= bldOre(b, l);

  /// bldTime(b,l): 공사 시간(초), 최대 12시간
  num bldTime(BuildingDef b, num l) =>
      math.min(12 * 3600, jsRound(60 * math.sqrt(b.base / 120) * math.pow(2, l) * vpTime()));

  /// timeGem(sec): 남은 3분당 황금 이삭 1
  static num timeGem(num sec) => math.max(1, jsCeil(sec / 180));

  /// gemGold(): 이삭 1개 ≈ 마물 20마리 골드
  num gemGold() => reward(s.stage, false) * 20;
  num bldGem(num c) => math.max(5, jsCeil(c / gemGold()));

  /// 건물이 열렸는지 (BLD[].open)
  bool bldOpen(String k) => switch (k) {
        'inn' => true,
        'farm' => truthy(s.done['marta']),
        'diner' => s.isJoined('margo'),
        'dock' => s.isJoined('haral'),
        'apiary' => s.isJoined('riel'),
        'mine' => s.isJoined('bron'),
        _ => false,
      };

  /// 건물 효과 문구 (BLD[].eff)
  String bldEff(String k, num l) {
    switch (k) {
      case 'inn':
        return '방치 보상 최대 ${6 + l}시간';
      case 'farm':
        return '밭 ${2 + l}칸';
      case 'diner':
        return '원정대 체력 +${l * 5}%';
      case 'dock':
        final vf = vpFish();
        final nf = vf > 1 ? _jsNumStr(num.parse((l * vf).toStringAsFixed(1))) : _jsNumStr(l);
        return '생선 $nf마리/2분${vf > 1 ? ' (물질 대장)' : ''}';
      case 'apiary':
        final vh = vpHoney();
        final nh = vh > 1 ? _jsNumStr(num.parse((l * vh).toStringAsFixed(1))) : _jsNumStr(l);
        return '동료 공격력 +${l * 8}% · 꿀 $nh병/2분${vh > 1 ? ' (말벌 퇴치반)' : ''}';
      case 'mine':
        final vm = vpMine();
        final n = vm > 1 ? _jsNumStr(num.parse((l * vm).toStringAsFixed(1))) : _jsNumStr(l);
        return '카엘 장비 +${l * 6}% · 광석 $n개/2분${vm > 1 ? ' (여왕의 대장간)' : ''}';
    }
    throw ArgumentError(k);
  }

  /// JS 의 숫자→문자 (정수면 소수점 없이)
  static String _jsNumStr(num v) => v == v.truncate() ? v.truncate().toString() : v.toString();

  int plotCount() => truthy(s.bld['farm']) ? (2 + s.bldLv('farm') + s.gemPlots).toInt() : 0;

  /// retireTarget(): 은퇴 자금 목표
  num retireTarget() => jsFloor(reward(s.stage, false) * 400);

  /// retirePts(): 은퇴하면 얻는 추억
  int retirePts() => math.max(0, ((s.stage - 10) / 5).floor());

  // ───────────── 골드 수입 ─────────────
  /// 원정대 초당 피해 합(치명 포함)
  num _dps() {
    num a = 0;
    for (final id in members()) {
      final t = stats(id);
      a = a + t.atk * t.aps * (1 + t.crit);
    }
    return a;
  }

  /// goldRate(): 지금 영지에서 1초에 버는 골드(추정)
  num goldRate() {
    final tpk = monHp(s.stage, false) / math.max(1, _dps()) + 1.2;
    return reward(s.stage, false) / tpk * memMul();
  }

  /// goldX(x): 황금 이삭 → 골드 바꾸기
  num goldX(GoldExchange x) => math.max(100, jsFloor(goldRate() * 3600 * x.h));

  /// 방치 보상: sec초 동안의 골드 (방치 보상·탑 보급·고블린 금고가 같이 씀, 웹 idleGold)
  num idleGold(num sec) {
    final tpk = monHp(fightSt(), false) / _dps() + 1.2;
    return sec / tpk * reward(fightSt(), false) * .5 * memMul() * (subOn() ? 1.5 : 1);
  }

  num idleGoldPerSec() => idleGold(1);

  /// offline(): 게임을 꺼 둔 동안 쌓인 골드. 60초 미만이면 0.
  ({num sec, num cap, num gold}) offlineReward() {
    final cap = (6 + s.bldLv('inn')) * 3600;
    final sec = math.min(cap, (now - s.last) / 1000);
    if (sec < 60) return (sec: sec, cap: cap, gold: 0);
    final g = jsFloor(idleGold(sec));
    return (sec: sec, cap: cap, gold: g > 0 ? g : 0);
  }

  // ───────────── 오늘의 할 일·광고 ─────────────
  /// today(): 기기 현지 날짜 'Y-M-D' (월·일 앞자리 0 없음, 웹과 같음)
  String today() {
    final t = DateTime.fromMillisecondsSinceEpoch(now);
    return '${t.year}-${t.month}-${t.day}';
  }

  /// daily(): 오늘의 기록 (날짜가 바뀌면 새로 시작)
  Map<String, dynamic> daily() {
    final d = asMap(s.raw['daily']);
    if (d == null || d['d'] != today()) {
      s.raw['daily'] = <String, dynamic>{
        'd': today(), 'kill': 0, 'box': 0, 'harv': 0, 'claim': <String, dynamic>{}, 'ad': <String, dynamic>{}
      };
    }
    final cur = s.raw['daily'] as Map<String, dynamic>;
    if (!truthy(cur['ad'])) cur['ad'] = <String, dynamic>{};
    return cur;
  }

  int adLeft(String k) => math.max(0, ads[k]!.n - orNum(asMap(daily()['ad'])![k], 0).toInt());

  // ───────────── 카드·목표 ─────────────
  /// cardReady(): 별을 올릴 수 있는 동료
  List<String> cardReady() => cardIds()
      .where((id) => cardOpen(id) && recStar(id) < starMax(id) && orNum(s.cards?[id], 0) >= (starNeed(id) ?? double.nan))
      .toList();

  /// nextGoal(): 원정대 탭 「다음 목표」
  Map<String, dynamic>? nextGoal() {
    final js = jobSlots.where((j) => j != 'kael' && !s.isJoined(storyOf[j]!)).toList();
    if (js.isNotEmpty) {
      final id = storyOf[js[0]]!;
      return {'id': id, 'job': js[0], 'face': false, 'title': '다음 동료 · ${jobName[js[0]]}', 'name': '???', 'desc': comps[id]!.join};
    }
    final cand = stableSorted(
      recruits.keys.where((id) => cardOpen(id) && recStar(id) < starMax(id)).map((id) =>
          (id: id, n: orNum(s.cards?[id], 0), need: starNeed(id)!)),
      (a, b) {
        final d = b.n / b.need - a.n / a.need;
        if (d != 0) return d.sign.toInt();
        return (gr(a.id).w - gr(b.id).w).sign.toInt();
      },
    );
    if (cand.isEmpty) return null;
    final c = cand.first, st = recStar(c.id);
    return {
      'id': c.id, 'job': jobOf[c.id], 'face': true,
      'title': '${st != 0 ? '★${st + 1} 올리기' : '새 동료 맞이하기'} · ${gr(c.id).n}',
      'name': comps[c.id]!.n, 'n': c.n, 'need': c.need, 'can': c.n >= c.need,
    };
  }

  // ───────────── 기록 ─────────────
  /// stat(k,n): 누적 기록 (S.stat)
  void stat(String k, num n) {
    final m = asMap(s.raw['stat']) ?? (s.raw['stat'] = <String, dynamic>{});
    m[k] = orNum(m[k], 0) + n;
  }

  // ───────────── 난수가 드는 것 ─────────────
  /// rollItem(fg): 성유물 상자에서 나오는 장비. fg 를 주면 그 등급으로 고정(난수는 똑같이 소모).
  Relic rollItem(KdRandom rng, [int? fg]) {
    final o = odds();
    var r = rng.next() * 100;
    var g = 0;
    for (; g < 5; g++) {
      if (r < o[g]) break;
      r -= o[g];
    }
    if (fg != null) g = fg;
    final sl = slots[(rng.next() * slots.length).floor()];
    final lv = math.max(1, s.stage + (rng.next() * 4).floor() - 2);
    final m = itemGrades[g].m;
    num v() => .9 + rng.next() * .2;
    final atk = jsRound(3 * m * lv * sl.a * v());
    final hp = jsRound(20 * m * lv * sl.h * v());
    return Relic(slot: sl.k, g: g, lv: lv, atk: atk, hp: hp, price: jsFloor(boxCost() * .25 * (1 + g)));
  }

  // ───── 카드 뽑기 (2026-10-21 규칙, 웹 cardPick/gainCard/gainCards) ─────
  // 영웅·전설은 등급 확률 고정(상점 영웅 10%·전설 1%, 전투 영웅 10%·전설 0%),
  // 일반·희귀는 동료마다 비중(일반 10·희귀 8). 별을 다 채운 동료 몫은 골드로.

  /// 이번에 골드로 바뀐 금액 (웹 cardGoldLast)
  num cardGoldLast = 0;

  bool cardCan(String id) => cardOpen(id) && recStar(id) < starMax(id);
  num cardGoldOf(int n) => jsFloor(reward(s.stage, false) * 3 * n);
  static num _cardW(String id) => (wCardW[gradeOf[id]] as num?) ?? 0;
  static Map<String, num> _fix(String src) => ((wCardFix[src] ?? wCardFix['shop']) as Map).cast<String, num>();

  /// 웹 cardPick(src): 동료 id, 골드로 바뀌면 '', 열린 동료가 없으면 null
  String? cardPick(KdRandom rng, String src) {
    final open = cardIds().where(cardOpen).toList();
    if (open.isEmpty) return null;
    final fx = _fix(src);
    final w0 = s.wish;
    final wish = (w0 != null && cardCan(w0)) ? w0 : null;
    final r = rng.next();
    final g = r < fx['legend']! ? 'legend' : r < fx['legend']! + fx['epic']! ? 'epic' : null;
    if (g != null) {
      final pool = open.where((x) => gradeOf[x] == g && cardCan(x)).toList();
      if (pool.isEmpty) return '';
      if (wish != null && gradeOf[wish] == g && rng.next() < .5) return wish;
      return pool[(rng.next() * pool.length).floor()];
    }
    if (wish != null && _cardW(wish) > 0 && rng.next() < .5) return wish;
    final cr = open.where((x) => _cardW(x) > 0).toList();
    if (cr.isEmpty) return '';
    num tot = 0;
    for (final x in cr) {
      tot += _cardW(x);
    }
    var q = rng.next() * tot;
    var id = cr.last;
    for (final x in cr) {
      q -= _cardW(x);
      if (q < 0) {
        id = x;
        break;
      }
    }
    return cardCan(id) ? id : '';
  }

  /// 웹 gainCard(n,src): 동료 카드 n장을 한 동료에게. 열린 동료가 없으면 null, 골드로 바뀌면 ''.
  String? gainCard(KdRandom rng, int n, [String src = 'shop']) {
    final id = cardPick(rng, src);
    cardGoldLast = 0;
    if (id == null) return null;
    if (id.isEmpty) {
      final g = cardGoldOf(n);
      s.gold = s.gold + g;
      cardGoldLast = g;
      return '';
    }
    final cards = s.cardsW;
    cards[id] = orNum(cards[id], 0) + n;
    stat('card', n);
    return id;
  }

  /// 웹 cardChunks(n,size)
  static List<int> cardChunks(int n, int size) {
    if (n < size) return [n];
    final k = n ~/ size;
    final a = List<int>.filled(k, size);
    a[k - 1] += n - size * k;
    return a;
  }

  /// 웹 gainCards(n,src,size): 여러 묶음으로 나눠 뽑기. 열린 동료가 없으면 null.
  ({List<(String, int)> got, num gold})? gainCards(KdRandom rng, int n, String src, int size) {
    final got = <(String, int)>[];
    num gold = 0;
    for (final c in cardChunks(n, size)) {
      final id = gainCard(rng, c, src);
      if (id == null) return null;
      if (id.isNotEmpty) {
        got.add((id, c));
      } else {
        gold += cardGoldLast;
      }
    }
    return (got: got, gold: gold);
  }

  /// 웹 cardOdds(src): 카드 한 묶음이 각 동료에게 갈 확률 (희망 동료 제외), 골드로 바뀌는 몫
  ({Map<String, num> o, num gold}) cardOdds(String src) {
    final open = cardIds().where(cardOpen).toList();
    final fx = _fix(src);
    final o = <String, num>{};
    num gold = 0;
    for (final g in ['legend', 'epic']) {
      final p = fx[g]!;
      final pool = open.where((x) => gradeOf[x] == g && cardCan(x)).toList();
      if (pool.isNotEmpty) {
        for (final x in pool) {
          o[x] = p / pool.length;
        }
      } else {
        gold += p;
      }
    }
    final rest = 1 - fx['legend']! - fx['epic']!;
    final cr = open.where((x) => _cardW(x) > 0).toList();
    num tot = 0;
    for (final x in cr) {
      tot += _cardW(x);
    }
    if (tot == 0) {
      gold += rest;
    } else {
      for (final x in cr) {
        final p = rest * _cardW(x) / tot;
        if (cardCan(x)) {
          o[x] = p;
        } else {
          gold += p;
        }
      }
    }
    return (o: o, gold: gold);
  }

  // ───────────── 밭·생산·공사 ─────────────
  /// plotState(p)
  ({String st, CropDef? c, num? left, num? ratio}) plotState(Object? p) {
    final m = asMap(p);
    if (m == null) return (st: 'empty', c: null, left: null, ratio: null);
    final c = crops.firstWhere((x) => x.k == m['k']);
    final left = c.t - (now - asNum(m['at'])) / 1000;
    return left <= 0
        ? (st: 'ready', c: c, left: null, ratio: null)
        : (st: 'grow', c: c, left: left, ratio: 1 - left / c.t);
  }

  Map<String, dynamic>? building() {
    final b = asMap(s.raw['build']);
    return b != null && truthy(b['k']) ? b : null;
  }

  List<dynamic> bq() => s.raw['bq'] is List ? s.raw['bq'] as List : (s.raw['bq'] = <dynamic>[]);

  void _startNext(num at) {
    final q = bq();
    if (q.isEmpty) return;
    final k = q.removeAt(0) as String;
    final b = buildingDef(k), l = s.bldLv(k);
    if (l >= b.max) return _startNext(at);
    s.raw['build'] = <String, dynamic>{'k': k, 'end': at + bldTime(b, l) * 1000, 'dur': bldTime(b, l)};
  }

  /// finishBuild(): 공사 하나 끝내기. 끝난 건물 키를 돌려준다(알림은 화면 쪽에서).
  String? finishBuild() {
    final bd = building();
    if (bd == null) return null;
    final k = bd['k'] as String, l = s.bldLv(k), end = asNum(bd['end']);
    s.raw['build'] = null;
    s.bld[k] = l + 1;
    if (l == 0) s.prod[k] = now;
    final at = math.min(now, math.max(end, 0));
    _startNext(at != 0 ? at : now);
    return k;
  }

  /// checkBuild(): 시간이 다 된 공사를 끝낸다(한 번에 최대 10개)
  List<String> checkBuild() {
    final done = <String>[];
    var n = 0;
    while (building() != null && now >= asNum(building()!['end']) && n++ < 10) {
      final k = finishBuild();
      if (k != null) done.add(k);
    }
    return done;
  }

  /// produce(): 낚시터·양봉장·광산 생산 (2분마다 레벨만큼)
  List<String> produce() {
    final done = checkBuild();
    final t = now;
    for (final g in goods) {
      final l = s.bldLv(g.b);
      if (l == 0) {
        s.prod[g.b] = t;
        continue;
      }
      final iv = 120000 / l / (g.b == 'mine' ? vpMine() : g.b == 'dock' ? vpFish() : g.b == 'apiary' ? vpHoney() : 1);
      if (!truthy(s.prod[g.b])) s.prod[g.b] = t;
      final n = math.min(2000, ((t - asNum(s.prod[g.b])) / iv).floor());
      if (n > 0) {
        s.items[g.k] = asNum(s.items[g.k]) + n;
        s.prod[g.b] = asNum(s.prod[g.b]) + n * iv;
      }
    }
    return done;
  }

  // ───────────── 다음 할 일 안내 (웹 GUIDE / renderGuide) ─────────────
  /// 처음 하는 사람을 위한 안내 문구 (순서대로 하나씩)
  static const guideTexts = [
    '성유물 상자를 열어 장비를 얻어요',
    '단련에서 공격력을 3번 올려요',
    '1-10 성주를 쓰러뜨려요',
    '마을에 여관을 재건해요',
    '원정대에서 동료 레벨을 올려요',
    '마을에 밭을 일궈요',
    '밭에 씨앗을 심고 수확해요',
    '피트의 상점에서 오늘의 할 일 보상을 받아요',
    '단련 탭에서 첫 은퇴를 해 봐요',
  ];

  /// 지금 보여 줄 안내 번호. 다 했거나(은퇴했거나 31영지 이상) 없으면 -1
  int guideIndex() {
    if (s.retires > 0 || s.best > 30) return -1;
    final checks = <bool Function()>[
      () => s.eq.values.any(truthy),
      () => s.upLv('atk') >= 3,
      () => s.best > 10,
      () => s.bldLv('inn') >= 1,
      () => !s.isJoined('margo') || s.lv.keys.any((k) => s.isJoined(k) && orNum(s.lv[k], 0) > 1),
      () => !truthy(s.done['marta']) || s.bldLv('farm') >= 1,
      () => !truthy(s.bld['farm']) || orNum(asMap(s.raw['stat'])?['harv'], 0) > 0,
      () => (asMap(daily()['claim']) ?? const <String, dynamic>{}).values.any(truthy),
      () => s.best < 20 || s.retires > 0,
    ];
    for (var j = 0; j < checks.length; j++) {
      if (!checks[j]() && !(j < 3 && s.best > 12)) return j;
    }
    return -1;
  }

  // ───────────── 은퇴 ─────────────
  /// retire(p): 처음부터 다시(추억 +p). 전투 화면 정리는 화면 쪽에서.
  void retire(int p) {
    s.memory = s.memory + p;
    s.retires = s.retires + 1;
    s.raw['capBonus'] = 0; // 왕도 재탈환 보너스: 회차마다 1번
    s.gold = 60;
    s.stage = 1;
    s.wave = 0;
    s.raw['eq'] = <String, dynamic>{};
    s.raw['up'] = <String, dynamic>{'atk': 0, 'hp': 0, 'spd': 0, 'crit': 0};
    for (final k in s.lv.keys.toList()) {
      s.lv[k] = 1;
    }
    s.raw['rankSeen'] = 0;
  }
}
