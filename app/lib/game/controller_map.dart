// 대륙 지도 (docs/content/WORLDMAP.md) · 바다 건너 지도 (docs/content/PART2.md 4장)
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

/// 지금 보는 지도가 「바다 건너」인지 (웹 wmSea, 저장하지 않음)
bool _mapSea = false;

extension GameMapX on GameController {
  /// 지금 보는 지도: false = 에르단(1~60), true = 바다 건너(61~) (웹 wmSea)
  bool get mapSea => _mapSea;

  void mapGo(double x, double y, double z) {
    camTx = x;
    camTy = y;
    camTz = z;
  }

  /// 카엘 자리로 (웹 wmFocusCur)
  void mapFocusCur([double z = 1.25]) {
    final p = wmPt(_mapSea, calc.mapCur(_mapSea));
    mapGo(p.$1, p.$2, z);
  }

  void _mapSnap() {
    camX = camTx;
    camY = camTy;
    camZ = camTz;
  }

  /// 지도 전환 칩 「에르단 · 바다 건너」 (웹 wmSetSea): 1부를 끝내기 전에는 바다 건너 🔒
  void mapSetSea(bool on, {bool quiet = false}) {
    final s = state;
    if (on && !calc.p2Open()) {
      haptic(const [8]);
      toast('1부를 끝내면 열려요');
      return;
    }
    if (on == _mapSea && !quiet) return;
    _mapSea = on;
    mapZoomR = -1;
    mapFocusCur();
    _mapSnap();
    _mapCapSeen = -1;
    if (on) mapReveal();
    if (on && !truthy(s.done['seaMap'])) {
      s.done['seaMap'] = true;
      scene('바다 건너 지도', '세 나라가 기다린다', const [
        'q:바다 건너 세 나라다. 왼쪽 섬이 엘프 왕국, 오른쪽이 사막 제국, 위가 북방 부족.',
        'k:배멀미 약은 챙겼나…',
        'sys:엘프 왕국 → 사막 제국 → 북방 부족 순서로 해방해요. 세 나라를 모두 해방하면 연합군이 모여요.',
      ], '지도를 본다');
    }
    save();
    refresh();
  }

  /// 지도 탭을 열 때: 처음 대사 · 걷힘 연출(처음 1번씩). 지금 영지가 61 이상이면 바다 건너부터 (웹 mapOpen)
  void mapOpen() {
    final s = state, c = calc;
    _mapSea = c.p2Open() && s.stage > maxLand;
    mapZoomR = -1;
    mapFocusCur();
    _mapSnap();
    if (c.mapIntroDue) {
      s.raw['mapIntro'] = 1;
      scene('대륙 지도', '안개 걷힌 에르단', const [
        'q:주인, 이게 에르단 대륙이다. 안개 낀 곳은 아직 마족의 땅이지.',
        'k:우리 마을이 저렇게 작았어?',
        'q:되찾을 때마다 안개가 걷힐 거다. 끝에는 왕도가 있다.',
        'k@smile:…끝까지 가면 은퇴할 수 있겠지?',
      ], '지도를 본다');
    }
    if (_mapSea && !truthy(s.done['seaMap'])) {
      _mapSea = false;
      mapSetSea(true, quiet: true);
    }
    mapReveal();
    save();
  }

  /// 걷힘 연출: 새로 가 본 영지(금빛 번쩍) · 지역 군단장(장수)을 처음 쓰러뜨린 곳(밝은 땅 번짐) · 이번 회차에 되찾은 영지.
  /// 지금 보는 지도의 것만 (웹 mapReveal)
  void mapReveal() {
    final s = state, c = calc, sea = _mapSea, now = DateTime.now().millisecondsSinceEpoch, f0 = c.fogSeen;
    if (f0 < s.best) {
      for (var st = math.max(2, f0 + 1); st <= math.min(wmStN(sea), s.best + 1); st++) {
        if (!wmOn(sea, st)) continue;
        final p = wmPt(sea, st);
        mapAnims.add((x: p.$1, y: p.$2, t0: now + 80 * math.max(1, st - math.max(f0, wmSt0(sea) - 1)), d: 800, k: 'fog'));
      }
      // 다른 지도 쪽 영지는 그 지도를 열 때 보이도록 남겨 둠
      if (s.best <= wmStN(sea) + 1) {
        s.raw['fogSeen'] = s.best;
      } else {
        s.raw['fogSeen'] = math.max(f0, math.min(s.best, wmStN(sea)));
      }
    }
    var delay = 0;
    for (var r = wmR0(sea); r < wmRN(sea); r++) {
      if (!c.mapRegCleared(r) || truthy(c.regSeen['$r'])) continue;
      c.regSeen['$r'] = 1;
      final ct = wmCtr(r), d0 = delay;
      mapAnims.add((x: ct.$1, y: ct.$2, t0: now + d0, d: 2000, k: 'reg'));
      Future.delayed(Duration(milliseconds: d0), () {
        if (tab != GameTab.mp) return;
        mapGo(ct.$1, ct.$2, 1.35);
        Future.delayed(const Duration(milliseconds: 1700), () {
          if (tab == GameTab.mp && mapZoomR < 0) mapFocusCur();
        });
      });
      final m = r >= seaR0 ? seaFogLines[r] : regFogLines[r];
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
        if (!wmOn(sea, st)) continue;
        final p = wmPt(sea, st);
        mapAnims.add((x: p.$1, y: p.$2, t0: now, d: 600, k: 'cap'));
      }
    }
    _mapCapSeen = cap;
  }

  /// 알림이 화면 위쪽에 붙는지 (웹 toast.hi: 창이 열렸거나 전체 화면 탭일 때)
  bool get toastHigh => modalOpen || (tab != null && (!tab!.half || pgFull));

  void refresh() => ui.value++;
}
