// 미니게임 「선물 배달」·랭킹 결과·외형 화면 쪽 (docs/content/EVENT_SNOW.md 3-9~3-11) — 웹 evMgStart·mgEnd·evMgResult·skinSheet 를 옮김.
// 판 계산은 core/minigame.dart (MgGame), 저장·규칙은 core/event.dart. 화면 모양은 screens/minigame_screen.dart.
part of 'controller.dart';

/// 지금 열린 선물 배달 화면 (웹 MGS — 한 번에 하나)
_MgHost? _mgOn;

/// 랭킹 결과 확인 중 (웹 evRkBusy)
bool _mgRkBusy = false;

extension GameMgX on GameController {
  /// 시작할 수 없으면 알림 글 (웹 evMgStart 앞부분)
  String? _mgErr(EventDef? e, bool practice) {
    if (e == null || !calc.evMgOn(e)) return '선물 배달은 크리스마스 주간에만 열려요';
    if (!calc.evOpen()) return '${e.n}은(는) 영지 $evOpenLand부터 함께해요';
    if (!practice) {
      final x = calc.evToday(calc.evS(e.id));
      if (calc.evBack(x)) return evBackMsg;
      if (calc.evMgLeft(e) <= 0) return '오늘 판을 다 했어요. 연습판은 계속 할 수 있어요';
    }
    return null;
  }

  /// 선물 배달 시작 (웹 evMgStart). practice = 연습판(보상·기록 없음)
  Future<void> evMgStart(String id, bool practice) async {
    final e = evts[id];
    final err = _mgErr(e, practice);
    if (err != null) {
      toast(err);
      return;
    }
    if (_mgOn != null) return;
    // 처음 한 번은 안내 장면 (웹 S.mgHint)
    if (!truthy(state.raw['mgHint'])) {
      state.raw['mgHint'] = 1;
      save();
      scene('선물 배달', '굴뚝에 선물을 넣어요', e!.line('mg'), '시작!', onGo: () => evMgStart(id, practice));
      return;
    }
    final h = _mgOn = _MgHost(this, id);
    // 창 대기열로 띄움: 떠 있는 동안 다른 창은 기다리고, 닫히면 「랭킹」·「닫기」 뒤 창을 이어서 엶 (웹 mgOpen·mgClose)
    queueFirst((ctx) async {
      try {
        await Navigator.of(ctx).push<void>(PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 160),
          reverseTransitionDuration: const Duration(milliseconds: 120),
          pageBuilder: (_, __, ___) => MinigameScreen(host: h, practice: practice),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ));
      } finally {
        if (identical(_mgOn, h)) _mgOn = null;
        if (h.after != null) _next = h.after;
      }
    });
  }

  /// 랭킹 결과 창 확인 (웹 evMgResult): 정산 뒤 처음 1번. 시작·돌아올 때 부름
  void evMgResultCheck() {
    for (final e in calc.evList()) {
      unawaited(_evMgResult(e));
    }
  }

  Future<void> _evMgResult(EventDef e) async {
    final mm = e.mg == null ? null : mgEvs[e.mg];
    if (mm == null || _mgRkBusy) return;
    final x = calc.evS(e.id), seen = x['seen'] as Map, mg = x['mg'] as Map;
    if (calc.evNow < (evT(mm.settle) ?? 0) || truthy(seen['mgEnd']) || !(asNum(mg['best']) > 0) || !online.on || online.nick == null) return;
    _mgRkBusy = true;
    try {
      final rows = await online.rpc('kd_mg_ranking', {'p_game': e.mg});
      if (rows is! List || rows.isEmpty || rows.first is! Map || !truthy((rows.first as Map)['settled'])) return;
      final me = rows.whereType<Map>().where((r) => r['me'] == true).firstOrNull;
      (calc.evS(e.id)['seen'] as Map)['mgEnd'] = 1;
      save();
      if (me != null) {
        final rank = asNum(me['rank']).toInt(), total = asNum(me['total']).toInt(), score = asNum(me['score']).toInt();
        queue((ctx) => _evMgResultSheet(ctx, e, rank, total, score));
      }
    } catch (_) {
    } finally {
      _mgRkBusy = false;
    }
  }

  /// 웹 evMgResultSheet: TOP 10 은 외형 「산타 카엘」, 1위는 배지 「선물 배달왕」 (우편으로도 오지만 같은 것 두 번 안 줌)
  Future<void> _evMgResultSheet(BuildContext ctx, EventDef e, int rank, int total, int score) {
    final mm = mgEvs[e.mg]!, top = rank <= 10, pct = rank <= (total * .3).ceil();
    var nw = false;
    if (top) nw = calc.skinGive('santa', mm.year);
    if (rank == 1) {
      act((a) => a.evGive(e.id, [
            {'k': 'badge', 'id': 'delivery'}
          ]));
    }
    save();
    refresh();
    haptic(const [30, 40, 70]);
    final rw = rank == 1
        ? mm.rew[0].$2
        : top
            ? mm.rew[1].$2
            : rank <= 100
                ? mm.rew[2].$2
                : pct
                    ? mm.rew[3].$2
                    : '';
    return showKdSheet<void>(ctx,
        builder: (c) => MgResultBody(
              e: e,
              rank: rank,
              total: total,
              score: score,
              rw: rw,
              top: top,
              nw: nw,
              onRank: () => chainSheet(c, () => openRanking(this, 'mg')),
              onMail: () => chainSheet(c, () => openMail(this)),
            ));
  }

  /// 외형 고르기 창 (웹 skinSheet · 장비 탭 카엘 칸 「외형」)
  void openSkinSheet() {
    openSheet<void>((c) => SkinSheetBody(this, c));
  }
}

/// 화면 ↔ 게임 (웹 MGS 의 판 수·보상·서버 부분)
class _MgHost implements MgHost {
  _MgHost(this.g, this.id);
  final GameController g;
  final String id;

  /// 화면이 닫힌 뒤 할 일 (랭킹·이벤트 창)
  VoidCallback? after;

  EventDef get e => evts[id]!;
  MgEvDef get mm => mgEvs[e.mg]!;

  @override
  ValueNotifier<String?> get toastMsg => g.toastMsg;

  @override
  void toast(String m) => g.toast(m);

  @override
  void haptic(List<int> p) => g.haptic(p);

  @override
  Future<(MgPlan?, bool)> prepare(bool practice, bool Function() gone) async {
    final err = g._mgErr(evts[id], practice);
    if (err != null) {
      g.toast(err);
      return (null, false);
    }
    final hint = !truthy(g.state.raw['mgPlayed']);
    var seed = math.Random().nextInt(1 << 32);
    if (practice) return (MgPlan(seed: seed, practice: true, hint: hint), false);
    final x = g.calc.evToday(g.calc.evS(id)), mg = x['mg'] as Map;
    mg['n'] = asNum(mg['n']).toInt() + 1;
    g.calc.evTouch(x);
    g.save();
    Object? tok;
    final o = g.online;
    if (o.on && !g.noSave) {
      try {
        await o.ensure();
        final r = await o.rpc('kd_mg_start', {'p_game': e.mg});
        if (r is Map && r['id'] != null) {
          tok = r['id'];
          seed = asNum(r['seed']).toInt() & 0xFFFFFFFF;
        } else if (r is Map && r['err'] == 'limit') {
          mg['n'] = math.max(asNum(mg['n']).toInt(), mm.daily + (truthy(mg['ad']) ? mm.ad : 0));
          g.save();
          g.toast('오늘 판을 다 했어요 (다른 기기 포함). 연습판은 계속 할 수 있어요');
          return (null, true);
        }
      } catch (_) {}
    }
    // 준비하는 사이 닫았으면 판을 돌려줌
    if (gone()) {
      if (tok == null) mg['n'] = math.max(0, asNum(mg['n']).toInt() - 1);
      g.save();
      return (null, true);
    }
    return (MgPlan(seed: seed, practice: false, hint: hint, tok: tok, demo: g.noSave), false);
  }

  @override
  MgEnd finish(MgPlan p, int score) {
    g.state.raw['mgPlayed'] = 1;
    final x = g.calc.evS(id), mg = x['mg'] as Map;
    final sf = p.practice ? 0 : math.min(100, (score / 10).floor());
    final nb = !p.practice && score > asNum(mg['best']);
    final rank = ValueNotifier<String>('');
    if (!p.practice) {
      x['sf'] = asNum(x['sf']).toInt() + sf;
      mg['best'] = math.max(asNum(mg['best']).toInt(), score);
      rank.value = p.demo
          ? '미리보기: 기록은 서버에 보내지 않아요'
          : p.tok != null
              ? '랭킹에 기록하는 중…'
              : '서버에 연결되지 않아 이번 판은 랭킹에 기록되지 않았어요';
      if (p.tok != null) unawaited(_submit(p.tok!, score, rank));
    }
    g.save();
    g.refresh();
    return MgEnd(
      title: p.practice ? '연습판' : mm.n,
      score: score,
      best: nb,
      practice: p.practice,
      sf: sf,
      curImg: e.curImg,
      curN: e.curN,
      left: g.calc.evMgLeft(e),
      rank: rank,
    );
  }

  /// 웹 kd_mg_submit → mgRankLine
  Future<void> _submit(Object tok, int score, ValueNotifier<String> line) async {
    final o = g.online;
    String r;
    try {
      final v = await o.rpc('kd_mg_submit', {'p_id': tok, 'p_score': score});
      r = v is String ? v : '$v';
    } catch (_) {
      r = 'net';
    }
    if (r == 'ok') {
      try {
        final rows = await o.rpc('kd_mg_ranking', {'p_game': e.mg});
        final me = rows is List ? rows.whereType<Map>().where((x) => x['me'] == true).firstOrNull : null;
        line.value = me != null ? '랭킹에 기록했어요 · 내 최고 ${fmt(asNum(me['score']))}점 · ${me['rank']}위 / ${fmt(asNum(me['total']))}명' : '랭킹에 기록했어요';
      } catch (_) {
        line.value = '랭킹에 기록했어요';
      }
      return;
    }
    line.value = const ['range', 'early', 'used'].contains(r)
        ? '이 판 기록은 랭킹에 올리지 못했어요 (확인되지 않은 기록)'
        : const ['closed', 'late'].contains(r)
            ? '랭킹 기록 시간이 지났어요'
            : '서버에 연결되지 않아 랭킹에 기록하지 못했어요';
  }

  @override
  void rank() => after = () => openRanking(g, 'mg');

  /// 웹 mgDone: 닫고 이벤트 창 「선물 배달」 탭 (screens/event_sheet.dart)
  @override
  void done() => after = () => openEventSheet(g, id, 'mg');
}
