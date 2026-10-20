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

/// 화면이 해야 할 일 (창 띄우기·알림)
sealed class ActResult {}

class ActToast extends ActResult {
  ActToast(this.msg);
  final String msg;
}

/// 성유물 상자 레벨 장면 (Lv.5·Lv.10)
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
class ActRecruitScene extends ActResult {
  ActRecruitScene(this.id);
  final String id;
}

class ActHaptic extends ActResult {
  ActHaptic(this.pattern);
  final List<int> pattern;
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
  /// gainBoxXp(): 상자를 열 때마다 경험치, 다 차면 상자 레벨 업 (최대 10)
  void gainBoxXp() {
    if (s.boxLv >= 10) return;
    s.boxXp = s.boxXp + 1;
    if (s.boxXp >= c.xpNeed()) {
      s.boxXp = 0;
      s.boxLv = s.boxLv + 1;
      if (s.boxLv == 5 || s.boxLv == 10) {
        out.add(ActBoxLevelScene(s.boxLv));
      } else {
        _toast('피트가 더 좋은 물건을 들여왔어요. 성유물 상자 Lv.${s.boxLv}');
      }
    }
  }

  /// openBox(auto)
  void openBox(bool auto) {
    if (!auto) out.add(ActHaptic(const [12]));
    final cost = c.boxCost();
    if (s.gold < cost || pending != null) return;
    if (!truthy(s.done['pete'])) {
      s.done['pete'] = true;
      out.add(ActPeteIntro());
      return;
    }
    s.gold = s.gold - cost;
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
    if (!spendGem(gem10)) return;
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
    if (l >= enMax || orNum(s.items['ore'], 0) < cost) return false;
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
    if (!s.isJoined(id) || l >= cwMax || orNum(s.items['ore'], 0) < o || s.gold < g) return false;
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
      final cc = GameCalc.upgradeCost(u.k, l + n);
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
      final cost = GameCalc.upgradeCost(k, s.upLv(k));
      if (s.gold < cost) break;
      s.gold = s.gold - cost;
      s.up[k] = s.upLv(k) + 1;
      if (k == 'hp') onHpAdd?.call('kael', 20);
      n++;
    }
    if (n == 0) _toast('골드가 부족해요');
    return n;
  }

  /// 추천 단련: 골드 1당 전투력이 가장 많이 오르는 것 (웹 renderAll 의 .best)
  String? bestUpgrade() {
    final p0 = c.power();
    String? best;
    num bv = 0;
    for (final u in upgrades) {
      final l = s.upLv(u.k);
      final cost = GameCalc.upgradeCost(u.k, l);
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
    if (cur != null) onSwap?.call(cur, id);
    if (!quiet) _toast('${comps[id]!.n}이(가) ${jobName[j]} 자리로 출전해요');
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
}
