// 이야기 창 묶기: 새 소식 · 탈환 보고서 · 첫 은퇴 권하기
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameStoryX on GameController {
  void _nwAdd(ReportItem r, {VoidCallback? later, required VoidCallback one}) => _nwBuf.add((r: r, later: later, one: one));

  /// 1개면 원래 창 그대로, 2개 이상이면 칸마다 「보러 가기」. 고르지 않은 것은 나중에(later)
  void _nwFlush() {
    // 제목 화면에서는 모아 두기만 (처음 들어올 때 탑·새 빈터가 따로 뜨지 않게, 웹 nwFlush)
    if (_nwBuf.isEmpty || titleOpen) return;
    final b = List.of(_nwBuf);
    _nwBuf.clear();
    if (b.length == 1) return b.first.one();
    void later(int skip) {
      for (var i = 0; i < b.length; i++) {
        if (i != skip) b[i].later?.call();
      }
    }

    queue((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, builder: (c) => ReportSheet(
              items: [for (final x in b) x.r],
              onDone: () {
                Navigator.of(c).pop();
                later(-1);
              },
              onGo: (i) {
                Navigator.of(c).pop();
                later(i);
                b[i].r.go?.call();
              },
            ));
      } finally {
        _sceneDone();
      }
    });
  }

  void _rpAdd(ReportItem it) => _rpBuf.add(it);

  /// 모인 이야기 창이 1개면 그 창 그대로, 2개 이상이면 「탈환 보고서」 한 장
  void _rpFlush() {
    if (_rpBuf.isEmpty) return;
    final b = List<ReportItem>.of(_rpBuf);
    _rpBuf.clear();
    if (b.length == 1) {
      final it = b.first;
      scene(it.eb, it.t, it.p, it.btn, titleWidget: it.titleWidget, onGo: it.go);
      return;
    }
    queue((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, builder: (c) => ReportSheet(items: b, onDone: () => Navigator.of(c).pop()));
      } finally {
        _sceneDone();
      }
    });
  }

  /// 단련 탭을 열고 은퇴 계획 상자로 내림 (웹 retGo)
  void retGo() {
    if (tab != GameTab.up) setTab(GameTab.up);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final ctx = retireKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 300));
    });
  }

  /// 은퇴 전 처음 영지 25를 되찾으면 한 번 (숫자는 그대로, 은퇴 루프를 일찍 배움)
  void _retHint() {
    final d = state.done;
    if (truthy(d['retHint']) || state.retires > 0 || state.best < 25 || !calc.retCan()) return;
    d['retHint'] = 1;
    _nwAdd(
      (face: 'assets/game/portraits/portrait_luminar_proud.png', eb: '루미나르의 제안', t: '한 번 은퇴해 볼까?', p: GameController.retHintLines, btn: '은퇴 계획 보기', titleWidget: null, go: retGo),
      one: () => scene('루미나르의 제안', '한 번 은퇴해 볼까?', GameController.retHintLines, '은퇴 계획 보기', altLabel: '나중에', onGo: retGo),
    );
  }

  void _vlTick() {
    calc.ordTick(acts.rng);
    _retHint();
    final back = calc.wkClean();
    if (back.isNotEmpty && tab != GameTab.pt) {
      for (final id in back) {
        toast('${comps[id]!.n}이(가) 원정대로 돌아갔어요');
      }
    }
    final done = state.done;
    for (final k in const ['forge', 'market', 'ranch', 'chapel']) {
      if (truthy(done['vo_$k']) || !calc.bldOpen(k)) continue;
      done['vo_$k'] = 1;
      final b = buildingDef(k), mv = k == 'forge' && state.bldLv('forge') > 0;
      final eb = mv ? '마을 · 이사' : '마을 · 새 빈터', t = mv ? '브론의 대장간 이사' : b.n;
      final ps = mv
          ? forgeMoveLines
          : [
              ...villageOpenLines[k]!,
              'sys:마을에 ${b.n} 빈터가 열렸어요. ${k == 'forge' ? '재건하면 성유물·동료 무기를 강화할 수 있어요.' : '마을 탭에서 재건해요.'}',
            ];
      _nwAdd((face: reportFace(ps), eb: eb, t: t, p: ps, btn: '마을에서 보기', titleWidget: null, go: () => vlSelect(k)),
          one: () => scene(eb, t, ps, '마을에서 보기', altLabel: '나중에', onGo: () => vlSelect(k)));
    }
    if (!truthy(state.raw['workIntro']) && calc.restIds().isNotEmpty && state.bldLv('inn') > 0) {
      state.raw['workIntro'] = 1;
      const ps = [
        'm:마르타|원정 안 나가는 동료들, 마을에서 놀고먹기만 할 거냐? 일 좀 시켜.',
        'k:다들 쉬고 싶을 텐데…',
        'q:주인이 쉬고 싶은 거겠지.',
        'k@flustered:…들켰네.',
        'sys:출전하지 않는 동료를 건물 일꾼으로 넣으면 건물 효과가 올라요. 직업이 맞으면 2배!',
      ];
      void go() => act((a) => a.wkAuto(false));
      _nwAdd((face: reportFace(ps), eb: '마을 일꾼', t: '쉬는 동료에게 일을', p: ps, btn: '추천 일꾼 넣기', titleWidget: null, go: go),
          one: () => scene('마을 일꾼', '쉬는 동료에게 일을', ps, '추천 일꾼 넣기', altLabel: '나중에', onGo: go));
    }
  }
}
