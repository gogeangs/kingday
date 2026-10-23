// 빨간 점 · 탭 점
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameDotsX on GameController {
  String ptAct() {
    final parts = <String>[for (final id in calc.cardReady()) 'c$id${calc.recStar(id)}'];
    for (final j in jobSlots) {
      if (j == 'kael' || !calc.betterBench(j)) continue;
      final ms = calc.jobMembers(j);
      var best = ms.first;
      for (final x in ms.skip(1)) {
        if (calc.cPow(x) > calc.cPow(best)) best = x;
      }
      parts.add('b$j$best');
    }
    return parts.join(',');
  }

  void dotSeen() => state.raw['dotSeen'] = ptAct();

  /// 원정대 탭 점: 지금 누르면 바로 이득이고, 아직 확인하지 않았을 때
  bool get ptDot {
    final a = ptAct();
    if (tab == GameTab.pt) {
      if (a != state.raw['dotSeen']) state.raw['dotSeen'] = a;
      return false;
    }
    return a.isNotEmpty && a != state.raw['dotSeen'];
  }

  /// 마을 탭 점 (웹 vDot): 수확 · 납품 · 축복 · 공사 완료 · 마을 레벨 보상 · 강화 가능 · 일꾼 빈칸(하루 한 번)
  bool get vlDot {
    final s = state, c = calc;
    if (truthy(s.bld['farm']) && s.plots.any((p) => c.plotState(p).st == 'ready')) return true;
    if (c.ordReady() > 0 || c.blessLeft() > 0 || vNewDone.isNotEmpty || c.vlRw()) return true;
    if (truthy(s.bld['forge']) && (onForgeCan?.call() ?? false)) return true;
    return s.raw['workDot'] != c.today() && c.wkOpen() && c.idleIds().isNotEmpty && buildings.any((b) => c.wkSlots(b.k) > c.wkIds(b.k).length);
  }

  /// 마을에서 바로 받을 수 있는 것 수 (웹 vReadyN): 다 자란 밭 + 납품할 주문 + 다 된 공사 + 마을 레벨 보상
  int vReadyN() {
    final s = state, c = calc;
    final ready = truthy(s.bld['farm']) ? s.plots.where((p) => c.plotState(p).st == 'ready').length : 0;
    return ready + c.ordReady() + vNewDone.length + (c.vlRw() ? 1 : 0);
  }

  /// 탭 점 서명 (웹 dotSig, U-2 ②): 「지금 누르면 바로 이득」인 이유들. 탭을 열면 본 것으로 기록
  String dotSig(GameTab t) {
    final c = calc;
    switch (t) {
      case GameTab.up:
        return c.trCanAny() ? 'm${c.memPts()}' : '';
      case GameTab.vl:
        if (!vlDot) return '';
        final s = state;
        final w = s.raw['workDot'] != c.today() && c.wkOpen() && c.idleIds().isNotEmpty;
        return [
          vReadyN(),
          c.ordReady(),
          c.blessLeft() > 0 ? 'b${c.today()}' : '',
          (vNewDone.toList()..sort()).join('.'),
          c.vlRw() ? 'r${c.vLv()}' : '',
          truthy(s.bld['forge']) && (onForgeCan?.call() ?? false) ? 'f' : '',
          w ? 'w' : '',
        ].join('|');
      case GameTab.mp:
        return c.chDot() ? 'c${c.supplyCan() ? 1 : 0}.${c.dunLeft()}.${c.today()}' : '';
      case GameTab.sh:
        final d = c.daily();
        final claim = asMap(d['claim']) ?? const <String, dynamic>{};
        final n = missions.where((m) => orNum(d[m.k], 0) >= m.goal && !truthy(claim[m.k])).length +
            (missions.every((m) => truthy(claim[m.k])) && !truthy(claim['all']) ? 1 : 0) +
            (c.subOn() && asMap(state.raw['sub'])?['last'] != c.today() ? 1 : 0);
        final a = acts.adKeys().any((k) => c.adLeft(k) > 0);
        return n > 0 || a ? 's$n${a ? 'a' : ''}${c.today()}' : '';
      default:
        return '';
    }
  }

  bool dotOn(GameTab t) {
    final sig = dotSig(t);
    if (sig.isEmpty) return false;
    final seen = asMap(state.raw['dotSeen2']) ?? (state.raw['dotSeen2'] = <String, dynamic>{});
    if (tab == t) {
      seen[t.name] = sig;
      return false;
    }
    return sig != seen[t.name];
  }

  /// 이삭 점: 받을 수 있는 할 일 보상이나 정기 배송이 있을 때 (웹 gemDot)
  bool get gemDot {
    final d = calc.daily();
    final claim = asMap(d['claim']) ?? const <String, dynamic>{};
    bool can(MissionDef m) => orNum(d[m.k], 0) >= m.goal && !truthy(claim[m.k]);
    final all = missions.every((m) => truthy(claim[m.k])) && !truthy(claim['all']);
    final sub = asMap(state.raw['sub']);
    return missions.any(can) || all || (calc.subOn() && sub?['last'] != calc.today());
  }
}
