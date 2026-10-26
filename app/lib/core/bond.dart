/// 원정대의 정 (docs/content/BOND.md): 호감도 ♥0~5 · 관계 이야기 6장면
///
/// 웹 index.html 「원정대의 정」 구역(affOk·affLv·affMul·affAdd·affTick·affUp·bondOpen·bondNew·bondPlay·affTalk)을
/// 같은 이름·같은 계산 순서로 옮긴 것. 저장 필드도 웹과 같다: aff, affTalk, bond (은퇴해도 유지).
/// 출전 동료·마을 일꾼 5분마다 1점(방치 포함) · 길 위에서 말 걸기 하루 1번 +10 · ♥마다 공격·체력 +2%.
library;

import 'actions.dart';
import 'calc.dart';
import 'data.dart';
import 'js.dart';
import 'village.dart';
import 'web_data.g.dart';

/// 관계 이야기 한 장면 (웹 BONDS)
class BondDef {
  BondDef._(Map m)
      : k = (m['k'] as num).toInt(),
        a = m['a'] as String,
        b = m['b'] as String,
        t = m['t'] as String,
        lines = (m['lines'] as List).cast<String>();
  final int k;
  final String a, b, t;
  final List<String> lines;
}

final List<num> affNeed = wAffNeed.cast<num>();
const num affSec = wAffSec;
final List<BondDef> bonds = [for (final m in wBonds) BondDef._(m as Map)];
final List<String> bondIntro = wBondIntro.cast<String>();
final Map<String, String> bond5 = wBond5.cast<String, String>();
final Map<String, String> bond5j = wBond5j.cast<String, String>();

extension BondCalc on GameCalc {
  Map<String, dynamic> get _aff => s.raw['aff'] is Map ? (s.raw['aff'] as Map).cast<String, dynamic>() : (s.raw['aff'] = <String, dynamic>{});
  Map<String, dynamic> get bondW {
    if (s.raw['bond'] is! Map) s.raw['bond'] = <String, dynamic>{'seen': <String, dynamic>{}, 'intro': 0, 'five': <String, dynamic>{}};
    return (s.raw['bond'] as Map).cast<String, dynamic>();
  }

  Map get bondSeen => bondW['seen'] is Map ? bondW['seen'] as Map : (bondW['seen'] = <String, dynamic>{});

  bool affOk(String id) => comps[id]?.base != null && id != 'kael' && id != GameCalc.chiefId;
  num affPt(String id) {
    final m = s.raw['aff'];
    return m is Map ? orNum(m[id], 0) : 0;
  }

  int affLv(String id) {
    final p = affPt(id);
    var l = 0;
    while (l < 5 && p >= affNeed[l + 1]) {
      l++;
    }
    return l;
  }

  num affMul(String id) => 1 + .02 * affLv(id);

  /// 다음 ♥까지 몇 % (♥5면 100)
  int affPct(String id) {
    final l = affLv(id);
    return l >= 5 ? 100 : jsFloor((affPt(id) - affNeed[l]) / (affNeed[l + 1] - affNeed[l]) * 100).toInt();
  }

  /// 점수만 더함. ♥가 오르면 새 ♥, 아니면 0 (웹 affAdd 앞부분)
  int affAdd0(String id, num n) {
    if (!(n > 0) || !affOk(id) || !owned(id)) return 0;
    final l0 = affLv(id);
    _aff[id] = affPt(id) + n;
    final l1 = affLv(id);
    return l1 > l0 ? l1 : 0;
  }

  /// 출전 동료(카엘·촌장 제외)와 마을 일꾼에게 sec초만큼. ♥가 오른 동료 목록 (웹 affTick 순서)
  List<(String, int)> affTick0(num sec) {
    final ids = members().where(affOk).toList();
    for (final id in working().keys) {
      if (affOk(id) && !ids.contains(id)) ids.add(id);
    }
    final up = <(String, int)>[];
    for (final id in ids) {
      final l = affAdd0(id, sec / affSec);
      if (l > 0) up.add((id, l));
    }
    return up;
  }

  bool bondOpen(BondDef b) => owned(b.a) && owned(b.b) && affLv(b.a) >= 3 && affLv(b.b) >= 3;
  List<BondDef> bondNew() => bonds.where((b) => bondOpen(b) && !truthy(bondSeen['${b.k}'])).toList();
  int bondSeenN() => bonds.where((b) => truthy(bondSeen['${b.k}'])).length;

  bool affTalked(String id) {
    final t = s.raw['affTalk'];
    return t is Map && t['d'] == today() && t['ids'] is Map && truthy((t['ids'] as Map)[id]);
  }

  /// ♥5 단짝 전용 한 줄 (5-3)
  String bond5Line(String id) => bond5[id] ?? bond5j[jobOf[id]] ?? '';
}

extension BondAct on GameActions {
  void affAdd(String id, num n) {
    final l = c.affAdd0(id, n);
    if (l > 0) affUp(id, l);
  }

  void affTick(num sec) {
    for (final (id, l) in c.affTick0(sec)) {
      affUp(id, l);
    }
  }

  /// ♥ 오를 때: 토스트(♥5 처음이면 단짝) · 처음이면 루미나르 안내 · 관계 이야기 확인 (웹 affUp)
  void affUp(String id, int l) {
    final n = comps[id]!.n, bd = c.bondW;
    if (bd['five'] is! Map) bd['five'] = <String, dynamic>{};
    final five = bd['five'] as Map;
    if (l >= 5 && !truthy(five[id])) {
      five[id] = 1;
      out.add(ActToast('$n${GameCalc.josa(n, '와', '과')} 단짝이 되었어요!'));
    } else {
      out.add(ActToast('$n의 호감도 ♥$l!'));
    }
    if (!truthy(bd['intro'])) {
      bd['intro'] = 1;
      out.add(ActAffIntro());
    }
    for (final b in c.bondNew()) {
      out.add(ActBondOpen(b.k));
    }
  }

  /// 장면 보기: 처음이면 황금 이삭 20 (장면마다 1번) (웹 bondPlay)
  void bondPlay(int k) {
    if (!bonds.any((x) => x.k == k)) return;
    final seen = c.bondSeen, first = !truthy(seen['$k']);
    seen['$k'] = 1;
    if (first) s.gem = s.gem + 20;
    out.add(ActBondScene(k, first));
    if (first) out.add(ActToast('황금 이삭 +20 · 원정대 일기'));
  }

  /// 길 위 대화: 동료마다 하루 1번 +10 (웹 affTalk)
  bool affTalk(String id) {
    if (!c.affOk(id) || !c.owned(id) || c.affTalked(id)) return false;
    final t = c.today();
    final at = s.raw['affTalk'];
    if (at is! Map || at['d'] != t) s.raw['affTalk'] = <String, dynamic>{'d': t, 'ids': <String, dynamic>{}};
    final m = s.raw['affTalk'] as Map;
    if (m['ids'] is! Map) m['ids'] = <String, dynamic>{};
    (m['ids'] as Map)[id] = 1;
    affAdd(id, 10);
    return true;
  }
}
