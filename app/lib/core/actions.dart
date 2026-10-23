/// 누르면 일어나는 일 — 웹 index.html 의 openBox()/open10()/upFire()/recruitUp()/setMember()/autoForm()/
/// 동료 레벨업/대장간 강화를 그대로 옮긴 것.
///
/// 저장 데이터만 바꾸고, 창·알림은 [ActResult] 로 돌려줘 화면 쪽이 띄운다.
/// 같은 난수로 웹과 같은 결과가 나오는지 test/actions_parity_test.dart 가 확인한다.
library;

import 'dart:math' as math;

import 'calc.dart';
import 'data.dart';
import 'fmt.dart';
import 'js.dart';
import 'rng.dart';
import 'state.dart';
import 'village.dart';
import 'web_data.g.dart';

/// 화면이 해야 할 일 (창 띄우기·알림)
sealed class ActResult {}

class ActToast extends ActResult {
  ActToast(this.msg);
  final String msg;
}

/// 성유물 상자 레벨 장면 (Lv.5·Lv.10, 31 = 태초가 처음 열림)
class ActBoxLevelScene extends ActResult {
  ActBoxLevelScene(this.lv);
  final int lv;
}

/// 피트 첫 만남 (보고 나면 상자를 다시 연다)
class ActPeteIntro extends ActResult {}

/// 상자에서 나온 성유물: 장착/판매를 고르게 함 (웹 showItem)
class ActShowItem extends ActResult {
  ActShowItem(this.it, this.cur);
  final Relic it;
  final Relic? cur;
}

/// 자동 열기로 바로 장착 (부위 반짝)
class ActFlashSlot extends ActResult {
  ActFlashSlot(this.slot);
  final String slot;
}

/// 10연속 결과
class ActOpen10 extends ActResult {
  ActOpen10(this.items, this.equipped, this.sold);
  final List<Relic> items;
  final List<Relic> equipped;
  final num sold;
}

/// 새 동료 맞이 장면
/// 카엘 촌장 합류 장면 (src: pay · retire · mail)
class ActChiefScene extends ActResult {
  ActChiefScene(this.src);
  final String src;
}

class ActRecruitScene extends ActResult {
  ActRecruitScene(this.id);
  final String id;
}

class ActHaptic extends ActResult {
  ActHaptic(this.pattern);
  final List<int> pattern;
}

/// 첫 공사 안내 (황금 이삭 10개 선물, 「이삭으로 바로 완료」)
class ActBuildTutorial extends ActResult {
  ActBuildTutorial(this.k, this.lv);
  final String k;
  final num lv;
}

/// 황금 밭 일구기 확인 창
class ActGemPlotAsk extends ActResult {
  ActGemPlotAsk(this.n, this.cost);
  final int n;
  final num cost;
}

/// 카드를 받았어요 창 (웹 cardReveal)
class ActCardReveal extends ActResult {
  ActCardReveal(this.got, this.title, [this.gold = 0]);
  /// 별을 다 채운 동료 카드가 바뀐 골드
  final num gold;
  final List<(String, int)> got;
  final String title;
}

/// 첫 거래 특가: 이야기 창 → 전설 성유물 비교 창
class ActStarter extends ActResult {
  ActStarter(this.it, this.cur);
  final Relic it;
  final Relic? cur;
}

/// 조금 뒤에 띄우는 알림 (웹 setTimeout(()=>toast(..), ms))
class ActLaterToast extends ActResult {
  ActLaterToast(this.msg, this.ms);
  final String msg;
  final int ms;
}

/// 원정대 교체로 전투 중 체력을 옮겨 줘야 할 때 (웹 P[cur] → P[id])
typedef PartySwap = void Function(String cur, String id);

class GameActions {
  GameActions(this.c, {KdRandom? rng}) : rng = rng ?? SystemRandom();
  final GameCalc c;
  KdRandom rng;
  GameState get s => c.s;

  /// 전투 화면과 연결 (보스전 중인지, 전투 중 체력)
  bool Function() bossFight = () => false;
  PartySwap? onSwap;
  void Function(String id, num addHp)? onHpAdd;

  /// 웹 pending: 고르는 중인 성유물이 있으면 상자를 못 연다
  Relic? pending;

  final List<ActResult> out = [];
  void _toast(String m) => out.add(ActToast(m));

  void dailyAdd(String k, num n) {
    final d = c.daily();
    d[k] = orNum(d[k], 0) + n;
  }

  /// spendGem(n)
  bool spendGem(num n) {
    if (s.gem < n) {
      _toast('황금 이삭이 부족해요. 피트의 상점에서 구할 수 있어요');
      return false;
    }
    s.gem = s.gem - n;
    return true;
  }

  // ════════════════════ 장비 ════════════════════
  /// 태초가 처음 열릴 때 피트 대사: 상자 Lv.31 + 첫 은퇴 뒤, 둘 중 나중에 채워지는 때 한 번 (웹 primalIntro)
  void primalIntro() {
    if (truthy(s.done['primalIntro']) || s.boxLv < 31 || !c.primalOn()) return;
    s.done['primalIntro'] = 1;
    out.add(ActBoxLevelScene(31));
  }

  /// gainBoxXp(): 상자를 열 때마다 경험치, 다 차면 상자 레벨 업 (상한 없음, RELIC_BOX.md)
  void gainBoxXp() {
    s.boxXp = s.boxXp + 1;
    if (s.boxXp >= c.xpNeed()) {
      s.boxXp = 0;
      s.boxLv = s.boxLv + 1;
      if (s.boxLv == 5 || s.boxLv == 10) {
        out.add(ActBoxLevelScene(s.boxLv));
      } else if (s.boxLv >= 31 && c.primalOn() && !truthy(s.done['primalIntro'])) {
        primalIntro();
      } else {
        _toast('${s.boxLv > 10 ? '피트가 더 귀한 물건을 들여왔어요' : '피트가 더 좋은 물건을 들여왔어요'}. 성유물 상자 Lv.${s.boxLv}');
      }
    }
  }

  /// 출석 무료권 수 (S.tickets.box · box10)
  int ticketN(String k) => orNum(asMap(s.raw['tickets'])?[k], 0).toInt();
  void _useTicket(String k) {
    final t = asMap(s.raw['tickets']) ?? (s.raw['tickets'] = <String, dynamic>{'box': 0, 'box10': 0});
    t[k] = ticketN(k) - 1;
  }

  /// openBox(auto): 직접 열 때는 출석 무료 개봉권을 골드보다 먼저 씀 (자동 열기·광고 상자 제외)
  void openBox(bool auto, {bool noTicket = false}) {
    if (!auto) out.add(ActHaptic(const [12]));
    final cost = c.boxCost(), tk = !auto && !noTicket && ticketN('box') > 0;
    if ((!tk && s.gold < cost) || pending != null) return;
    if (!truthy(s.done['pete'])) {
      s.done['pete'] = true;
      out.add(ActPeteIntro());
      return;
    }
    if (tk) {
      _useTicket('box');
      _toast('상자 무료 개봉권 사용 · 남은 ${ticketN('box')}장');
    } else {
      s.gold = s.gold - cost;
    }
    gainBoxXp();
    dailyAdd('box', 1);
    final it = c.rollItem(rng), cur = c.equipped(it.slot);
    if (auto) {
      if (GameCalc.score(it) > GameCalc.score(cur)) {
        if (cur != null) s.gold = s.gold + cur.price;
        s.eq[it.slot] = it.toJson();
        out.add(ActFlashSlot(it.slot));
      } else {
        s.gold = s.gold + it.price;
      }
      return;
    }
    if (truthy(s.raw['autoSell']) && cur != null && GameCalc.score(it) <= GameCalc.score(cur)) {
      s.gold = s.gold + it.price;
      _toast('${itemGrades[it.g].n} ${slotDef(it.slot).n} 판매 +${fmt(it.price)}');
      return;
    }
    pending = it;
    out.add(ActShowItem(it, cur));
  }

  /// 고른 성유물 장착 (웹 mEq): 끼고 있던 것은 판다
  void equip(Relic it) {
    final cur = c.equipped(it.slot);
    if (cur != null) s.gold = s.gold + cur.price;
    s.eq[it.slot] = it.toJson();
    pending = null;
    out.add(ActFlashSlot(it.slot));
    if (cur != null) _toast('이전 장비 판매 +${fmt(cur.price)}');
  }

  /// 고른 성유물 판매 (웹 mSell)
  void sell(Relic it) {
    s.gold = s.gold + it.price;
    pending = null;
  }

  /// open10(): 황금 이삭 100개로 10연속, 영웅 이상 1개 확정. 더 좋은 건 바로 끼고 나머지는 판다.
  void open10() {
    if (pending != null) return;
    if (ticketN('box10') > 0) {
      _useTicket('box10');
      _toast('10연속 무료권 사용 · 남은 ${ticketN('box10')}장');
    } else if (!spendGem(gem10)) {
      return;
    }
    final its = <Relic>[];
    for (var i = 0; i < 10; i++) {
      gainBoxXp();
      dailyAdd('box', 1);
      its.add(c.rollItem(rng));
    }
    if (!its.any((x) => x.g >= 3)) its[9] = c.rollItem(rng, 3);
    num sold = 0;
    final eq = <Relic>[];
    for (final it in its) {
      final cur = c.equipped(it.slot);
      if (GameCalc.score(it) > GameCalc.score(cur)) {
        if (cur != null) sold += cur.price;
        s.eq[it.slot] = it.toJson();
        eq.add(it);
      } else {
        sold += it.price;
      }
    }
    s.gold = s.gold + sold;
    out.add(ActOpen10(its, eq, sold));
  }

  /// 브론의 대장간: 부위 강화 (광석)
  bool enhanceSlot(String k) {
    final l = c.enLv(k), cost = c.enCost(l);
    if (!truthy(s.bld['forge']) || l >= c.enMax() || orNum(s.items['ore'], 0) < cost) return false;
    s.items['ore'] = asNum(s.items['ore']) - cost;
    final en = asMap(s.raw['slotEn']) ?? (s.raw['slotEn'] = <String, dynamic>{});
    en[k] = l + 1;
    out.add(ActFlashSlot(k));
    _toast('${slotDef(k).n} +${l + 1} 강화! 능력치 +${(l + 1) * 10}%');
    return true;
  }

  /// 동료 전용 무기 강화 (광석 + 골드)
  bool enhanceWeapon(String id) {
    final l = c.cwLv(id), o = c.cwOre(l), g = c.cwGold(l);
    if (!truthy(s.bld['forge']) || !s.isJoined(id) || l >= c.enMax() || orNum(s.items['ore'], 0) < o || s.gold < g) return false;
    s.items['ore'] = asNum(s.items['ore']) - o;
    s.gold = s.gold - g;
    final en = asMap(s.raw['cwEn']) ?? (s.raw['cwEn'] = <String, dynamic>{});
    en[id] = l + 1;
    _toast('${comps[id]!.n}의 ${compWeapon[id]} +${l + 1} 강화! 공격·체력 +${(l + 1) * 8}%');
    return true;
  }

  // ════════════════════ 단련 ════════════════════
  /// S.upMul: 1 | 10 | 'max'
  Object get upMul => s.raw['upMul'] == 'max' ? 'max' : orNum(s.raw['upMul'], 1);
  num get _want => upMul == 'max' ? 1e9 : upMul as num;

  /// upPlan(u): 지금 배수로 누르면 몇 번 올리고 얼마 드는지
  ({int n, num c}) upPlan(UpgradeDef u) {
    final l = s.upLv(u.k);
    var n = 0;
    num cost = 0;
    while (n < _want && l + n < u.max && n < 5000) {
      final cc = c.upgradeCost(u.k, l + n);
      if (upMul == 'max' && n > 0 && cost + cc > s.gold) break;
      cost += cc;
      n++;
    }
    return (n: math.max(1, n), c: cost);
  }

  /// upFire(k): 골드가 되는 만큼 올림. 올린 횟수를 돌려줌
  int upFire(String k) {
    final u = upgrades.firstWhere((x) => x.k == k);
    if (s.upLv(k) >= u.max) return 0;
    var n = 0;
    while (n < _want && s.upLv(k) < u.max && n < 5000) {
      final cost = c.upgradeCost(k, s.upLv(k));
      if (s.gold < cost) break;
      s.gold = s.gold - cost;
      s.up[k] = s.upLv(k) + 1;
      if (k == 'hp') onHpAdd?.call(c.slotMember('kael')!, 20);
      n++;
    }
    if (n == 0) _toast('골드가 부족해요');
    return n;
  }

  /// 추천 단련: 골드 1당 전투력이 가장 많이 오르는 것 (웹 renderAll 의 .best)
  /// 단련 탭 「추천」 배지 = 길잡이와 같은 줄 (calc.upBest)
  String? bestUpgrade() => c.upBest();

  /// 지금 골드로 살 수 있는 것 중 비용 대비 전투력이 가장 많이 오르는 단련 (긴 플레이 시험의 웹 봇과 같은 고르기)
  String? bestBuyable() {
    final p0 = c.power();
    String? best;
    num bv = 0;
    for (final u in upgrades) {
      final l = s.upLv(u.k);
      final cost = c.upgradeCost(u.k, l);
      if (l >= u.max || s.gold < cost) continue;
      s.up[u.k] = l + 1;
      final g = (c.power() - p0) / cost;
      s.up[u.k] = l;
      if (g > bv) {
        bv = g;
        best = u.k;
      }
    }
    return best;
  }

  // ════════════════════ 원정대 ════════════════════
  /// 동료 레벨업 (웹 lv-<id>): 전투 중 체력도 늘어난 만큼 더해 줌
  bool levelUp(String id) {
    final lv = orNum(s.lv[id], 1), cost = GameCalc.compCost(lv);
    if (s.gold < cost) return false;
    final h0 = c.stats(id).hp;
    s.gold = s.gold - cost;
    s.lv[id] = lv + 1;
    onHpAdd?.call(id, c.stats(id).hp - h0);
    return true;
  }

  /// setMember(j,id,quiet): 그 직업 자리에 출전시킬 동료 바꾸기
  bool setMember(String j, String id, {bool quiet = false}) {
    final cur = c.slotMember(j);
    if (cur == id) return true;
    if (bossFight()) {
      _toast('보스전이 끝나면 바꿀 수 있어요');
      return false;
    }
    final party = asMap(s.raw['party']) ?? (s.raw['party'] = <String, dynamic>{});
    party[j] = id;
    // 일하던 동료를 출전 편성에 넣으면 일꾼 칸에서 빠짐
    final wasW = c.working()[id];
    if (wasW != null) c.work[wasW] = [for (final x in c.work[wasW] as List) if (x != id) x];
    if (cur != null) onSwap?.call(cur, id);
    if (wasW != null) {
      _toast('${comps[id]!.n}이(가) 원정대로 돌아갔어요');
    } else if (!quiet) {
      _toast('${comps[id]!.n}이(가) ${jobName[j]} 자리로 출전해요');
    }
    return true;
  }

  /// 카엘 자리 바꾸기 (웹 setKaelSeat): 체력 비율을 그대로 옮기므로 보스전 중에도 바꿈
  bool setKaelSeat(String id) {
    final cur = c.slotMember('kael')!;
    if (cur == id || (id == GameCalc.chiefId && !c.owned(id))) return false;
    final party = asMap(s.raw['party']) ?? (s.raw['party'] = <String, dynamic>{});
    party['kael'] = id;
    onSwap?.call(cur, id);
    _toast('${comps[id]!.n}이(가) 카엘 자리로 출전해요');
    s.last = c.now;
    return true;
  }

  /// autoForm(): 자리마다 가장 강한 동료로
  void autoForm() {
    if (bossFight()) {
      _toast('보스전이 끝나면 바꿀 수 있어요');
      return;
    }
    var n = 0;
    for (final j in jobSlots) {
      if (j == 'kael') continue;
      final ms = c.jobMembers(j);
      if (ms.isEmpty) continue;
      var best = ms.first;
      for (final b in ms.skip(1)) {
        if (c.cPow(b) > c.cPow(best)) best = b;
      }
      if (best != c.slotMember(j)) {
        setMember(j, best, quiet: true);
        n++;
      }
    }
    _toast(n > 0 ? '추천 편성: 자리 $n곳을 가장 강한 동료로 바꿨어요' : '이미 가장 강한 편성이에요');
  }

  /// recruitUp(id): 카드를 모아 맞이하기 / ★ 올리기
  bool recruitUp(String id) {
    final stv = c.recStar(id), need = c.starNeed(id), n = orNum(s.cards?[id], 0);
    if (stv >= c.starMax(id) || need == null || n < need) return false;
    out.add(ActHaptic(const [25, 40, 25]));
    s.cardsW[id] = n - need;
    s.recW[id] = stv + 1;
    if (!truthy(s.lv[id])) s.lv[id] = 1;
    if (stv == 0) {
      out.add(ActRecruitScene(id));
    } else {
      final skUp = GameCalc.isRec(id) && (stv + 1 == 3 || stv + 1 == 5);
      _toast('${comps[id]!.n} ★${stv + 1}! 능력치 +${((starMulTable[stv + 1] - 1) * 100).round()}%${skUp ? ' · 스킬 강화' : ''}');
    }
    return true;
  }

  /// ♡ 희망 동료 (카드가 절반 확률로 이 동료로)
  void toggleWish(String id) {
    s.wish = s.wish == id ? null : id;
    _toast(s.wish != null ? '${comps[id]!.n} 카드가 더 잘 나와요 (절반)' : '희망 동료를 해제했어요');
  }

  // ════════════════════ 밭 (웹 「밭 · 부엌 · 마을」) ════════════════════
  /// ensurePlots(): 밭 칸 수만큼 빈 칸을 채움 (웹은 밭 화면을 그릴 때 부름)
  void ensurePlots() {
    final n = c.plotCount();
    while (s.plots.length < n) {
      s.plots.add(null);
    }
  }

  /// plotTag(i): 그 칸 전용 작물 (없으면 자유)
  String? plotTag(int i) {
    final t = s.raw['plotTag'];
    if (t is List && i < t.length && t[i] is String) return t[i] as String;
    return null;
  }

  List<dynamic> _tags() => s.raw['plotTag'] is List ? s.raw['plotTag'] as List : (s.raw['plotTag'] = <dynamic>[]);

  void _setTag(int i, String? k) {
    final t = _tags();
    while (t.length <= i) {
      t.add(null);
    }
    t[i] = k;
  }

  /// cycleTag(i): 밭 지정 — 자유 → 밀 → 은빛 당근 → 달빛 호박
  void cycleTag(int i) {
    final order = <String?>[null, ...crops.map((x) => x.k)];
    _setTag(i, order[(order.indexOf(plotTag(i)) + 1) % order.length]);
  }

  /// plant(i,k)
  bool plant(int i, String k) {
    if (orNum(s.seeds[k], 0) <= 0 || (i < s.plots.length && s.plots[i] != null)) return false;
    s.seeds[k] = asNum(s.seeds[k]) - 1;
    final p = <String, dynamic>{'k': k, 'at': c.now};
    s.plots[i] = p;
    // 황금 고블린의 발자국: 보통 밭 8% · 황금 밭 12% 확률로 그 칸 수확 2배
    if (rng.next() < (isGemPlot(i) ? asNum(wGobPlot['gem']) : asNum(wGobPlot['n']))) p['g'] = 1;
    return true;
  }

  /// 이삭으로 늘린 황금 밭 칸인지 (웹 isGemPlot)
  bool isGemPlot(int i) => i >= 2 + orNum(s.bld['farm'], 0);

  /// 방금 수확한 칸에 고블린이 다녀갔는지 (웹 harvGob)
  int harvGob = 0;

  /// 씨앗 고르기 창에서 심기 (전용 밭으로 지정할 수도)
  void plantChosen(int i, String k, {bool tag = false}) {
    if (tag) {
      _setTag(i, k);
      _toast('${crops.firstWhere((x) => x.k == k).n} 전용 밭으로 지정했어요');
    }
    plant(i, k);
  }

  /// chooseSeed(i): 전용 밭이면 바로 심고 true, 아니면 false (화면이 씨앗 고르기 창을 띄움)
  bool chooseSeedTagged(int i) {
    final tg = plotTag(i);
    if (tg == null) return false;
    final cn = crops.firstWhere((x) => x.k == tg).n;
    if (orNum(s.seeds[tg], 0) > 0) {
      plant(i, tg);
    } else {
      _toast('$cn 전용 밭이에요. $cn 씨앗이 없어요');
    }
    return true;
  }

  /// harvest(i): 2개, 30% 확률로 3개
  int harvest(int i) {
    final ps = c.plotState(s.plots[i]);
    harvGob = 0;
    if (ps.st != 'ready') return 0;
    final gb = truthy(asMap(s.plots[i])?['g']) ? 2 : 1;
    final bp = c.tl('bumper') != 0 && rng.next() < .05 * c.tl('bumper') ? 2 : 1; // 풍년의 기억
    final n = (2 + (rng.next() < .3 ? 1 : 0)) * gb * bp, k = ps.c!.k;
    harvGob = gb > 1 ? 1 : 0;
    s.items[k] = asNum(s.items[k]) + n;
    s.plots[i] = null;
    dailyAdd('harv', n);
    c.stat('harv', n);
    if (k == 'pumpkin') c.stat('pump', n);
    return n;
  }

  /// 밭 칸을 눌렀을 때 (빈 칸은 화면이 씨앗 고르기, 다 자랐으면 수확, 자라는 중이면 남은 시간)
  void tapPlot(int i) {
    final ps = c.plotState(s.plots[i]);
    if (ps.st == 'ready') {
      final n = harvest(i);
      if (harvGob > 0) {
        _toast('황금 고블린이 다녀갔어요! ${ps.c!.n} ×2 · $n개 수확');
        out.add(ActHaptic(const [20, 30, 20]));
      } else {
        _toast('${ps.c!.n} $n개 수확. 카엘이 행복해 보여요');
      }
    } else if (ps.st == 'grow') {
      _toast('${ps.c!.n} · ${mmss(ps.left!)} 뒤에 수확');
    }
  }

  void harvestAll() {
    var t = 0, gb = 0;
    for (var i = 0; i < s.plots.length; i++) {
      t += harvest(i);
      gb += harvGob;
    }
    _toast('작물 $t개 수확${gb > 0 ? ' (고블린 2배 $gb칸)' : ''}');
    if (gb > 0) out.add(ActHaptic(const [20, 30, 20]));
  }

  void plantAll() {
    for (var i = 0; i < s.plots.length; i++) {
      if (s.plots[i] != null) continue;
      final t = plotTag(i);
      if (t != null) {
        if (orNum(s.seeds[t], 0) > 0) plant(i, t);
        continue;
      }
      for (final cr in crops.reversed) {
        if (orNum(s.seeds[cr.k], 0) > 0) {
          plant(i, cr.k);
          break;
        }
      }
    }
  }

  /// 황금 밭 일구기: 확인 창부터
  void askGemPlot() {
    final n = s.gemPlots.toInt();
    if (n >= gemPlotCost.length) return;
    out.add(ActGemPlotAsk(n, gemPlotCost[n]));
  }

  /// buyGemPlot 의 「이삭으로 일구기」
  void buyGemPlot(int n, num cost) {
    if (!spendGem(cost)) return;
    s.raw['gemPlots'] = n + 1;
    ensurePlots();
    _toast('황금 밭 1칸이 생겼어요!');
  }

  /// growNow(): 자라는 작물 바로 키우기 (칸마다 이삭 5)
  void growNow() {
    final g = [for (final p in s.plots) if (c.plotState(p).st == 'grow') p as Map];
    if (g.isEmpty) return;
    if (!spendGem(g.length * gemPlot)) return;
    for (final p in g) {
      p['at'] = 0;
    }
    _toast('리엘의 벌들이 밭을 도왔어요. 모두 다 자랐어요');
  }

  /// 광고 보상: 자라는 작물 바로 키우기 (adFarm 의 보상 부분)
  void growByAd() {
    for (final p in s.plots) {
      if (c.plotState(p).st == 'grow') (p as Map)['at'] = 0;
    }
    _toast('리엘의 벌들이 밭을 도왔어요. 모두 다 자랐어요');
  }

  // ════════════════════ 식당 ════════════════════
  bool canCook(RecipeDef r) => r.need.entries.every((e) => orNum(s.items[e.key], 0) >= e.value);

  /// 요리: 재료를 쓰고 10분 버프 (이미 있으면 10분 더)
  void cook(String k) {
    final r = recipes.firstWhere((x) => x.k == k);
    if (!canCook(r)) return;
    for (final e in r.need.entries) {
      s.items[e.key] = asNum(s.items[e.key]) - e.value;
    }
    s.buffs[r.buff] = math.max(c.now, orNum(s.buffs[r.buff], 0)) + c.cookMs();
    c.stat('cook', 1);
    _toast('${r.n} 완성! ${r.desc}');
  }

  /// 창고 물건 값 합계 (「주문 재료 남기기」면 주문에 필요한 수는 빼고)
  num storeValue() {
    final keep = c.ordKeep();
    num v = 0;
    for (final k in s.items.keys) {
      v = v + math.max(0, orNum(s.items[k], 0) - (keep[k] ?? 0)) * c.itemPrice(k);
    }
    return v;
  }

  void sellAll() {
    final kp = c.ordKeep();
    num v = 0;
    for (final k in s.items.keys.toList()) {
      final n = math.max(0, orNum(s.items[k], 0) - (kp[k] ?? 0));
      v = v + n * c.itemPrice(k);
      s.items[k] = asNum(s.items[k]) - n;
    }
    s.gold = s.gold + v;
    _toast('창고 판매 +${fmt(v)}${kp.isNotEmpty ? ' · 주문 재료는 남겼어요' : ''}');
  }

  // ════════════════════ 마을 확장: 모두 수확·주문·축복·일꾼·마을 레벨 (docs/content/VILLAGE.md) ════════════════════
  /// 모두 수확 + 빈 칸에 같은 씨앗 다시 심기 (마을 할 일 줄)
  void harvestReplant() {
    var t = 0, gb = 0, re = 0;
    for (var i = 0; i < s.plots.length; i++) {
      final ps = c.plotState(s.plots[i]);
      if (ps.st != 'ready') continue;
      final ck = ps.c!.k;
      t += harvest(i);
      gb += harvGob;
      final sk = plotTag(i) ?? ck;
      if (orNum(s.seeds[sk], 0) > 0) {
        plant(i, sk);
        re++;
      }
    }
    _toast('작물 $t개 수확${gb > 0 ? ' (고블린 2배 $gb칸)' : ''}${re > 0 ? ' · $re칸 다시 심기' : ''}');
    if (gb > 0) out.add(ActHaptic(const [20, 30, 20]));
  }

  /// 주문 납품 (웹 ordDeliver)
  void ordDeliver(int i) {
    final os = c.orders;
    if (i >= os.length || !c.ordCan(os[i])) return;
    final o = asMap(os[i])!;
    for (final e in (o['need'] as Map).entries) {
      s.items[e.key] = asNum(s.items[e.key]) - (e.value as num);
    }
    final g = c.ordGold(o);
    s.gold = s.gold + g;
    var ex = '';
    final e = asMap(o['extra']) ?? const <String, dynamic>{};
    final ek = e['k'], en = orNum(e['n'], 0);
    if (ek == 'gem') {
      final d = c.ordDay(), gv = math.min(math.max(0, ordGemCap - orNum(d['gem'], 0)), en);
      if (gv > 0) {
        d['gem'] = orNum(d['gem'], 0) + gv;
        s.gem = s.gem + gv;
        ex = '황금 이삭 +$gv';
      }
      if (gv < en) {
        final ore = (en - gv) * 5;
        s.items['ore'] = orNum(s.items['ore'], 0) + ore;
        ex += '${ex.isNotEmpty ? ' · ' : ''}광석 +$ore';
        if (gv == 0) out.add(ActLaterToast('오늘 주문으로 받을 수 있는 이삭은 다 받았어요', 1800));
      }
    } else if (ek == 'ore') {
      s.items['ore'] = orNum(s.items['ore'], 0) + en;
      ex = '광석 +$en';
    } else if (ek == 'seed') {
      s.seeds['wheat'] = orNum(s.seeds['wheat'], 0) + 6;
      s.seeds['carrot'] = orNum(s.seeds['carrot'], 0) + 3;
      s.seeds['pumpkin'] = orNum(s.seeds['pumpkin'], 0) + 1;
      ex = '씨앗 묶음(밀 6·당근 3·호박 1)';
    } else if (ek == 'card') {
      final id = c.gainCard(rng, en.toInt(), 'battle');
      if (id != null && id.isNotEmpty) {
        ex = '${comps[id]!.n} 카드 +$en';
      } else if (id == '') {
        ex = '골드 +${fmt(c.cardGoldLast)}';
      } else {
        s.items['ore'] = orNum(s.items['ore'], 0) + 20;
        ex = '광석 +20';
      }
    }
    os[i] = <String, dynamic>{'at': c.now + ordWait};
    c.stat('order', 1);
    out.add(ActHaptic(const [18]));
    _toast('${villagePeople[o['who']] ?? comps[o['who']]?.n ?? o['who']}의 주문 완료! 골드 +${fmt(g)}${ex.isNotEmpty ? ' · $ex' : ''}');
  }

  /// 다른 주문 받기: 칸마다 하루 1번 바로, 그다음은 1시간 기다림
  void ordSkip(int i) {
    final d = c.ordDay(), sk = asMap(d['skip'])!;
    if (!truthy(sk['$i'])) {
      sk['$i'] = 1;
      c.orders[i] = c.ordNew(rng, i);
      _toast('다른 주문을 받았어요');
    } else {
      c.orders[i] = <String, dynamic>{'at': c.now + ordWait};
      _toast('1시간 뒤에 새 주문이 와요');
    }
  }

  /// 축복 고르기
  void blessPick(String k) {
    if (c.blessLeft() == 0 || !c.blessOpts(rng).contains(k)) return;
    final b = c.bless;
    b['k'] = k;
    b['until'] = c.now + c.blessMs();
    b['used'] = orNum(b['used'], 0) + 1;
    b['opts'] = <dynamic>[];
    out.add(ActHaptic(const [18]));
    _toast('${blessDef(k).n}이 함께해요 · ${fmtT(c.blessMs() / 1000)}');
  }

  /// 광고 보고 축복 한 번 더 (광고 횟수는 화면 쪽 watchAd 가 셈)
  void blessAdGrant() {
    c.blessDay()['ad'] = 1;
    c.bless['opts'] = <dynamic>[];
  }

  /// 일꾼 넣기 (다른 건물에 있던 동료면 옮김)
  void wkPut(String k, int i, String id) {
    final w = c.work;
    for (final b in w.keys.toList()) {
      w[b] = [for (final x in w[b] as List) if (x != id) x];
    }
    final a = c.wkIds(k);
    if (i < a.length) {
      a[i] = id;
    } else {
      a.add(id);
    }
    w[k] = a.take(c.wkSlots(k)).toList();
    final pct = (wkReal(k, c.wkOne(k, id)) * 100).round();
    _toast(c.wkMatch(k, id) ? '${comps[id]!.n}: ${workLine(id) ?? '이건 내 전문이지!'} · +$pct%' : '${comps[id]!.n}이(가) ${buildingDef(k).n}에서 일해요 · +$pct%');
  }

  void wkOut(String k, String id) {
    c.work[k] = c.wkIds(k).where((x) => x != id).toList();
    _toast('${comps[id]!.n}이(가) 쉬러 갔어요');
  }

  void wkClear() {
    s.raw['work'] = <String, dynamic>{};
    _toast('일꾼을 모두 쉬게 했어요');
  }

  /// 추천 일꾼: 빈 칸에 효과가 큰 순서로 (all = 모두 다시 배치)
  int wkAuto(bool all) {
    c.wkClean();
    final w = c.work;
    if (all) {
      for (final b in w.keys.toList()) {
        w[b] = <dynamic>[];
      }
    }
    final pool = c.idleIds(), holes = <String>[];
    for (final b in buildings) {
      final n = c.wkSlots(b.k) - c.wkIds(b.k).length;
      for (var j = 0; j < n; j++) {
        holes.add(b.k);
      }
    }
    var n = 0;
    while (holes.isNotEmpty && pool.isNotEmpty) {
      var bh = 0, bp = 0;
      num bv = -1;
      for (var h = 0; h < holes.length; h++) {
        for (var p = 0; p < pool.length; p++) {
          final v = c.wkOne(holes[h], pool[p]);
          if (v > bv) {
            bv = v;
            bh = h;
            bp = p;
          }
        }
      }
      final k = holes.removeAt(bh), id = pool.removeAt(bp);
      w[k] = [...c.wkIds(k), id];
      n++;
    }
    _toast(n > 0 ? '${all ? '모두 다시 배치: ' : '추천 일꾼: '}$n명이 일하러 갔어요' : '채울 빈칸이나 쉬는 동료가 없어요');
    return n;
  }

  /// 마을 레벨 보상 받기: 올린 레벨 목록(보상 창·에피소드는 화면 쪽에서) — (레벨, 이번에 처음 보는 동료 마을 에피소드인지)
  List<(int, bool)> vlClaim() {
    final got = <(int, bool)>[];
    while (c.vlvGot < c.vLv()) {
      final l = c.vlvGot + 1;
      s.raw['vlv'] = l;
      s.gem = s.gem + vlvGem[l];
      final ep = asMap(s.raw['ep']) ?? (s.raw['ep'] = <String, dynamic>{});
      final first = villageEpisodes.containsKey(l) && !truthy(ep['$l']);
      if (first) ep['$l'] = 1;
      got.add((l, first));
    }
    if (got.isNotEmpty) _toast('마을 Lv.${c.vlvGot}! 방치 골드 +${2 * c.vLv()}%');
    return got;
  }

  // ════════════════════ 건물 공사 ════════════════════
  bool inBuild(String k) {
    final bd = c.building();
    return (bd != null && bd['k'] == k) || c.bq().contains(k);
  }

  num buildLeft() {
    final bd = c.building();
    return bd == null ? 0 : math.max(0, (asNum(bd['end']) - c.now) / 1000);
  }

  void _built(BuildingDef b, num l) => _toast('${b.n}${l > 0 ? ' 확장' : ' 재건'} 완료! ${c.bldEff(b.k, l + 1)}');

  /// orderBuild(b): 공사 시작, 공사 중이면 예약(2개까지)
  void orderBuild(String k) {
    final b = buildingDef(k), l = s.bldLv(k), cost = GameCalc.bldCost(b, l), o = c.bldOre(b, l);
    if (l >= b.max || s.gold < cost || inBuild(k)) return;
    if (!c.oreOk(b, l)) return _toast('광석이 $o개 필요해요. 광산에서 브론이 캐 와요');
    if (c.building() != null) {
      if (c.bq().length >= buildQueueMax) return;
      s.gold = s.gold - cost;
      s.items['ore'] = asNum(s.items['ore']) - o;
      c.bq().add(k);
      _toast('${b.n} 공사를 예약했어요 · 앞 공사가 끝나면 시작해요');
      return;
    }
    s.gold = s.gold - cost;
    s.items['ore'] = asNum(s.items['ore']) - o;
    s.raw['build'] = <String, dynamic>{'k': k, 'end': c.now + c.bldTime(b, l) * 1000, 'dur': c.bldTime(b, l)};
    if (!truthy(s.done['tutBuild'])) {
      s.done['tutBuild'] = true;
      s.gem = s.gem + tutGem;
      out.add(ActBuildTutorial(k, l));
    } else {
      _toast('${b.n}${l > 0 ? ' 확장' : ' 재건'} 공사를 시작했어요 · ${fmtT(c.bldTime(b, l))}');
    }
  }

  /// cancelQueued(k): 예약 취소 (골드·광석 돌려받음)
  void cancelQueued(String k) {
    final q = c.bq(), i = q.indexOf(k);
    if (i < 0) return;
    q.removeAt(i);
    final b = buildingDef(k), l = s.bldLv(k), o = c.bldOre(b, l);
    s.gold = s.gold + GameCalc.bldCost(b, l);
    s.items['ore'] = asNum(s.items['ore']) + o;
    _toast('${b.n} 예약을 취소했어요. 골드${o > 0 ? '와 광석을' : '를'} 돌려받았어요');
  }

  /// 황금 이삭으로 바로 짓기 (공사비 + 시간)
  void buildByGem(String k) {
    final b = buildingDef(k), l = s.bldLv(k);
    if (l >= b.max || inBuild(k)) return;
    if (!c.oreOk(b, l)) return _toast('광석이 ${c.bldOre(b, l)}개 필요해요. 광산에서 브론이 캐 와요');
    if (!spendGem(c.bldGem(GameCalc.bldCost(b, l)) + GameCalc.timeGem(c.bldTime(b, l)))) return;
    s.items['ore'] = asNum(s.items['ore']) - c.bldOre(b, l);
    s.bld[k] = l + 1;
    if (l == 0) s.prod[k] = c.now;
    _built(b, l);
  }

  /// 공사 중인 건물 황금 이삭으로 바로 완료 (남은 3분당 1)
  void finishByGem() {
    final bd = c.building();
    if (bd == null || !spendGem(GameCalc.timeGem(buildLeft()))) return;
    final k = bd['k'] as String, l = s.bldLv(k);
    c.finishBuild();
    _built(buildingDef(k), l);
  }

  // ════════════════════ 피트의 상점 (웹 renderShop) ════════════════════
  /// 결제 연동 전 (웹 TEST_PAY): 결제 없이 바로 지급. 9단계에서 인앱결제로 바꿈
  static const testPay = true;

  Map<String, dynamic> get buys => asMap(s.raw['buys']) ?? (s.raw['buys'] = <String, dynamic>{});
  Map<String, dynamic> get sub => asMap(s.raw['sub']) ?? (s.raw['sub'] = <String, dynamic>{'until': 0, 'last': ''});

  /// misCan(m): 할 일 보상을 받을 수 있는지 (m 이 null 이면 「모두 끝내기」)
  bool misCan(MissionDef? m) {
    final d = c.daily(), cl = asMap(d['claim']) ?? (d['claim'] = <String, dynamic>{});
    if (m != null) return orNum(d[m.k], 0) >= m.goal && !truthy(cl[m.k]);
    return missions.every((x) => truthy(cl[x.k])) && !truthy(cl['all']);
  }

  /// gainGem(n,why)
  void gainGem(num n, String why) {
    out.add(ActHaptic(const [18]));
    s.gem = s.gem + n;
    _toast('황금 이삭 +${n is double && n == n.roundToDouble() ? n.toInt() : n}${why.isNotEmpty ? ' · $why' : ''}');
  }

  /// 할 일 보상 받기 (k: kill · box · harv · all)
  void claimMission(String k) {
    final m = missions.where((x) => x.k == k).firstOrNull;
    if (k != 'all' && m == null) return;
    if (!misCan(m)) return;
    (asMap(c.daily()['claim'])!)[k] = true;
    if (k == 'all') {
      final cid = c.gainCard(rng, 5, 'shop');
      final t = cardToastText(cid, 5);
      if (t != null) out.add(ActLaterToast(t, 1200));
    }
    gainGem(m?.r ?? missionAllReward, m?.n ?? '오늘의 할 일 완료');
  }

  /// 무료 선물 종류 (동료 카드는 카드 동료가 생긴 뒤부터)
  List<String> adKeys() => ['box', 'gem', if (GameCalc.cardIds().any(c.cardOpen)) 'card'];

  /// 광고 보상: 성유물 상자 1회 무료 (웹 adBox)
  void adBoxGive() {
    s.gold = s.gold + c.boxCost();
    openBox(false, noTicket: true);
  }

  /// 광고 보상: 황금 이삭 +5 (웹 adGem)
  void adGemGive() {
    s.gem = s.gem + 5;
    _toast('피트의 선물! 황금 이삭 +5');
  }

  /// 광고 보상: 동료 카드 3장 (웹 adCard)
  void adCardGive() {
    final r = c.gainCards(rng, 3, 'shop', 1);
    if (r == null) {
      _toast('아직 모을 수 있는 동료 카드가 없어요');
      return;
    }
    out.add(ActCardReveal(r.got, '피트의 선물', r.gold));
  }

  /// 웹 cardToast(cid,n): 카드 한 묶음 결과 알림 문장
  String? cardToastText(String? cid, int n) {
    if (cid == null) return null;
    if (cid.isNotEmpty) return '${comps[cid]!.n} 카드 +$n';
    return '동료 카드 → 골드 +${fmt(c.cardGoldLast)} (별을 다 채운 동료)';
  }

  /// 골드 바꾸기 (웹 buyGoldX)
  void buyGoldX(String k) {
    final x = goldExchanges.firstWhere((v) => v.k == k), g = c.goldX(x);
    if (!spendGem(x.gem)) return;
    s.gold = s.gold + g;
    _toast('${x.n} 구매! 골드 +${fmt(g)}');
  }

  /// 동료 카드 묶음 (i: 0 = 1장씩 3번, 1 = 5장씩 6번 · 여러 동료 무작위)
  void buyCardPack(int i) {
    final cp = cardPacks[i], n = asNum(cp['n']).toInt();
    if (!GameCalc.cardIds().any((x) => c.cardOpen(x) && c.recStar(x) < c.starMax(x))) {
      _toast('모을 수 있는 동료 카드가 없어요');
      return;
    }
    if (!spendGem(asNum(cp['gem']))) return;
    final r = c.gainCards(rng, n, 'shop', n >= 30 ? 5 : 1);
    out.add(ActCardReveal(r?.got ?? const [], '카드 $n장', r?.gold ?? 0));
  }

  /// 결제 (웹 pay): 지금은 시험용으로 바로 지급
  bool _pay(String id, void Function() give) {
    if (!testPay) {
      _toast('결제 준비 중이에요');
      return false;
    }
    buys[id] = orNum(buys[id], 0) + 1;
    give();
    // 웹 pay() 끝의 save(): 마지막 접속 시각도 이때 적힘
    s.last = c.now;
    return true;
  }

  /// 황금 이삭 꾸러미 (첫 구매 2배)
  void buyPack(String k) {
    final first = !truthy(buys[k]);
    _pay(k, () => _givePack(k, first));
  }

  /// 스토어 결제 확인 우편으로 받은 꾸러미 (구매 기록도 여기서)
  void grantPack(String k) {
    final first = !truthy(buys[k]);
    buys[k] = orNum(buys[k], 0) + 1;
    _givePack(k, first);
  }

  void _givePack(String k, bool first) {
    final p = gemPacks.firstWhere((x) => x.k == k), n = p.gem * (first ? 2 : 1), u = GameCalc.ucardPack[k] ?? 0;
    s.gem = s.gem + n;
    s.raw['ucard'] = c.ucard + u;
    _toast('황금 이삭 +${fmt(n)}${first ? ' (첫 구매 2배)' : ''}${u > 0 ? ' · 유니크 카드 +$u' : ''}');
  }

  /// 첫 거래 특가: 전설 성유물 1개 + 이삭 100 (한 번만)
  void buyStarter() {
    if (truthy(buys['starter'])) return;
    _pay('starter', grantStarter);
  }

  void grantStarter({bool count = false}) {
    if (count) buys['starter'] = orNum(buys['starter'], 0) + 1;
    s.gem = s.gem + asNum(starterPack['gem']);
    final it = c.rollItem(rng, 4), cur = c.equipped(it.slot);
    out.add(ActStarter(it, cur));
  }

  /// 정기 배송 시작·연장
  void buySub() => _pay('sub', grantSub);

  void grantSub({bool count = false, num days = 0}) {
    if (count) buys['sub'] = orNum(buys['sub'], 0) + 1;
    final base = math.max(c.now, orNum(sub['until'], 0));
    sub['until'] = base + (days > 0 ? days : asNum(subscription['days'])) * 864e5;
    sub['last'] = c.today();
    final g = asNum(subscription['now']) + asNum(subscription['day']);
    s.gem = s.gem + g;
    _toast('정기 배송 시작! 황금 이삭 +${fmt(g)}${_subCardTxt(_subCard())}');
  }

  /// 웹 subCard(): 정기 배송 유니크 카드는 3일마다 1장 (배송 받은 횟수 1·4·7…번째)
  bool _subCard() {
    final cn = orNum(sub['cn'], 0).toInt() + 1;
    sub['cn'] = cn;
    if (cn % 3 != 1) return false;
    s.raw['ucard'] = c.ucard + 1;
    return true;
  }

  String _subCardTxt(bool u) => u ? ' · 유니크 카드 +1' : ' · 유니크 카드까지 ${3 - ((orNum(sub['cn'], 0).toInt() - 1) % 3)}일';

  /// 정기 배송 오늘 받기
  void claimSub() {
    if (!c.subOn() || sub['last'] == c.today()) return;
    sub['last'] = c.today();
    s.gem = s.gem + asNum(subscription['day']);
    _toast('피트의 마차가 도착했어요. 황금 이삭 +${fmt(asNum(subscription['day']))}${_subCardTxt(_subCard())}');
  }

  // ───────────── 카엘 촌장 (웹 chiefJoin · chiefCheck · chiefUp · buyChief) ─────────────
  /// 합류: ★1 + 장면. 카엘 자리 출전은 장면 버튼에서 (화면 쪽 setKaelSeat)
  bool chiefJoin(String src) {
    const id = GameCalc.chiefId;
    if (c.owned(id)) return false;
    s.joined[id] = true;
    s.recW[id] = math.max(1, orNum(s.rec?[id], 0).toInt());
    s.last = c.now;
    out.add(ActHaptic(const [30, 40, 30]));
    out.add(ActChiefScene(src));
    return true;
  }

  /// 은퇴 10번이면 무료로 찾아옴
  bool chiefCheck() => !c.owned(GameCalc.chiefId) && orNum(s.raw['retires'], 0) >= GameCalc.chiefRet && chiefJoin('retire');

  /// 500원 상품 (첫 은퇴 뒤 상점)
  void buyChief() {
    if (!c.chiefShop()) return;
    _pay('chief', () => chiefJoin('pay'));
  }

  /// 스토어 결제 확인 우편으로 받은 카엘 촌장
  void grantChief() {
    buys['chief'] = orNum(buys['chief'], 0) + 1;
    chiefJoin('pay');
  }

  /// 유니크 카드로 ★ 올리기
  bool chiefUp() {
    const id = GameCalc.chiefId;
    if (!c.chiefCan()) return false;
    final need = c.starNeed(id)!, h0 = c.stats(id).hp;
    s.raw['ucard'] = c.ucard - need;
    s.recW[id] = c.recStar(id) + 1;
    onHpAdd?.call(id, c.stats(id).hp - h0);
    s.last = c.now;
    out.add(ActHaptic(const [25, 40, 25]));
    final st = c.recStar(id);
    _toast('카엘 촌장 ★$st! 카엘 능력치 +${pctTxt(GameCalc.chiefBonus[st] * 100)}% · 새벽 종소리 +${pctTxt(GameCalc.chPct(st))}%');
    return true;
  }

  /// 남은 정기 배송 일수
  int subLeft() => math.max(0, ((orNum(sub['until'], 0) - c.now) / 864e5).ceil());
}
