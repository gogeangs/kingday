// 대륙 지도 (docs/content/WORLDMAP.md)
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameMapX on GameController {
  void mapGo(double x, double y, double z) {
    camTx = x;
    camTy = y;
    camTz = z;
  }

  void mapFocusCur([double z = 1.25]) {
    final p = mapPts[calc.mapCur() - 1];
    mapGo(p.$1, p.$2, z);
  }

  /// 지도 탭을 열 때: 처음 대사 · 걷힘 연출(처음 1번씩) (웹 mapOpen)
  void mapOpen() {
    final s = state, c = calc, now = DateTime.now().millisecondsSinceEpoch;
    mapZoomR = -1;
    mapFocusCur();
    camX = camTx;
    camY = camTy;
    camZ = camTz;
    if (c.mapIntroDue) {
      s.raw['mapIntro'] = 1;
      scene('대륙 지도', '안개 걷힌 에르단', const [
        'q:주인, 이게 에르단 대륙이다. 안개 낀 곳은 아직 마족의 땅이지.',
        'k:우리 마을이 저렇게 작았어?',
        'q:되찾을 때마다 안개가 걷힐 거다. 끝에는 왕도가 있다.',
        'k@smile:…끝까지 가면 은퇴할 수 있겠지?',
      ], '지도를 본다');
    }
    final fs = c.fogSeen;
    if (fs < s.best) {
      for (var st = math.max(2, fs + 1); st <= math.min(maxLand, s.best + 1); st++) {
        mapAnims.add((x: mapPts[st - 1].$1, y: mapPts[st - 1].$2, t0: now + 80 * (st - fs), d: 800, k: 'fog'));
      }
      s.raw['fogSeen'] = s.best;
    }
    var delay = 0;
    for (var r = 0; r < 6; r++) {
      if (!c.mapRegCleared(r) || truthy(c.regSeen['$r'])) continue;
      c.regSeen['$r'] = 1;
      final ct = mapCtr[r], d0 = delay;
      mapAnims.add((x: ct.$1, y: ct.$2, t0: now + d0, d: 2000, k: 'reg'));
      Future.delayed(Duration(milliseconds: d0), () {
        if (tab != GameTab.mp) return;
        mapGo(ct.$1, ct.$2, 1.35);
        Future.delayed(const Duration(milliseconds: 1700), () {
          if (tab == GameTab.mp && mapZoomR < 0) mapFocusCur();
        });
      });
      final m = regFogLines[r];
      if (m != null) {
        Future.delayed(Duration(milliseconds: d0 + 400), () {
          toast(m.$1);
          Future.delayed(const Duration(milliseconds: 1900), () => toast('루미나르: ${m.$2.replaceFirst(RegExp(r'^q(@\w+)?:'), '')}'));
        });
      }
      delay += 2200;
    }
    final cap = c.landCount();
    if (_mapCapSeen >= 0 && cap > _mapCapSeen) {
      for (var st = _mapCapSeen + 1; st <= cap; st++) {
        mapAnims.add((x: mapPts[st - 1].$1, y: mapPts[st - 1].$2, t0: now, d: 600, k: 'cap'));
      }
    }
    _mapCapSeen = cap;
    save();
  }

  /// 알림이 화면 위쪽에 붙는지 (웹 toast.hi: 창이 열렸거나 전체 화면 탭일 때)
  bool get toastHigh => modalOpen || (tab != null && (!tab!.half || pgFull));

  void refresh() => ui.value++;
}
