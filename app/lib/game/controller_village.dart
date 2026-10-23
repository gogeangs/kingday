// 마을
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameVillageX on GameController {
  Map<String, dynamic> get helpSeen => asMap(state.raw['helpSeen']) ?? (state.raw['helpSeen'] = <String, dynamic>{});

  /// 건물 창 탭 (웹 vbTabs): 기능 탭 → 정보 → 일꾼
  List<String> vbTabs(String k) {
    final l = state.bldLv(k), fn = GameController._vFn[k];
    return [
      if (fn != null && (k == 'diner' ? truthy(state.bld['farm']) : l > 0)) fn,
      'info',
      if (l > 0 && calc.wkOpen()) 'work',
    ];
  }

  String vbTab(String k) {
    final t = vbTabs(k), m = vbTabM[k];
    if (m != null && t.contains(m)) return m;
    // 아직 안 지은 건물은 「정보」(재건 버튼) 탭부터 (3회차 리뷰 11: 식당이 부엌 탭으로 열림)
    return state.bldLv(k) <= 0 && t.contains('info') ? 'info' : t.first;
  }

  /// 건물 고르기: 마을 탭으로 가서 아래 건물 창을 연다 (웹 vlSelect)
  void vlSelect(String k, {String? tab}) {
    vlSel = k;
    vbOpen = true;
    if (tab != null) vbTabM[k] = tab;
    vNewDone.remove(k);
    if (this.tab != GameTab.vl) setTab(GameTab.vl);
    refresh();
  }

  void vbClose() {
    vbOpen = false;
    refresh();
  }

  void vbTabSet(String k, String t) {
    vbTabM[k] = t;
    refresh();
  }

  /// 마을 할 일 (웹 vTodos): (키, 글자, 누르면)
  List<(String, String, VoidCallback)> vTodos() {
    final s = state, c = calc, t = <(String, String, VoidCallback)>[];
    final ready = truthy(s.bld['farm']) ? s.plots.where((p) => c.plotState(p).st == 'ready').length : 0;
    if (c.vlRw()) t.add(('lv', '🎁 마을 Lv 보상', vlClaimUi));
    if (ready > 0) t.add(('farm', '🌾 수확 $ready', () => vlSelect('farm', tab: 'farm')));
    if (c.ordReady() > 0) t.add(('market', '📋 납품 ${c.ordReady()}', () => vlSelect('market', tab: 'order')));
    if (c.blessLeft() > 0) t.add(('chapel', '✨ 축복 받기', () => vlSelect('chapel', tab: 'bless')));
    for (final b in vNewDone) {
      t.add((b, '🏗 공사 완료 · ${buildingDef(b).n}', () => vlSelect(b, tab: 'info')));
    }
    if (c.wkOpen() && c.idleIds().isNotEmpty) {
      final h = buildings.fold<int>(0, (a, b) => a + math.max(0, c.wkSlots(b.k) - c.wkIds(b.k).length));
      if (h > 0) t.add(('work', '🔨 일꾼 빈칸 $h', () => onWorkSheet?.call()));
    }
    if (truthy(s.bld['forge']) && (onForgeCan?.call() ?? false)) t.add(('forge', '⚒ 강화 가능', () => vlSelect('forge', tab: 'forge')));
    return t;
  }

  /// 마을 레벨 보상 받기 → 보상 창 · 처음 보는 동료 마을 에피소드
  void vlClaimUi() {
    final got = act((a) => a.vlClaim());
    for (final (l, ep) in got) {
      final g = vlvGem[l];
      scene('마을 Lv.$l', '마을이 살아나요', [
        'sys:마을 Lv.$l! 방치 골드 +${2 * l}%',
        'sys:황금 이삭 +$g${l == 5 ? ' · 배지 「마을의 영웅」' : l == 10 ? ' · 테두리 「에르단 마을」' : ''}',
      ], '좋아요');
      if (ep) {
        final e = villageEpisodes[l]!;
        scene('동료 마을 이야기', e.$1, e.$2, '마을로');
      }
    }
    if (got.isNotEmpty) {
      calc.pfCheck();
      save();
    }
  }
}
