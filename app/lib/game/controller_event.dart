// 정기 이벤트 「눈꽃제」 화면 쪽 (docs/content/EVENT_SNOW.md) — 웹 evSheet·evBossEnd·evScenes·evXmasCheck·evGiftSheet·
// evWarnCheck·evFetch·evBoot 를 옮김. 규칙·저장은 core/event.dart (EventCalc·EventAct), 창 모양은 screens/event_sheet.dart.
part of 'controller.dart';

/// 진행 담당마다: 마지막으로 본 이벤트 날 (웹 evHudDay) · 산타 선물 창을 줄 세웠는지 (웹 evGiftQ)
final _evDayK = Expando<String>('evDay');
final _evGiftQ = Expando<bool>('evGiftQ');

/// 서버 날짜를 읽을 때 (시작 1.8초 뒤, 웹 setTimeout(evFetch, 1800)) — 타이머 대신 0.4초 주기에서 확인
final _evFetchAt = Expando<int>('evFetchAt');

extension GameEventX on GameController {
  /// 시작할 때 (웹 evBoot): 기기에 남긴 서버 날짜 → 지난 이벤트 지우기 → 저장 칸 만들기 → (새 게임이 아니면) 장면 → 1.8초 뒤 서버 날짜
  void _evBoot(bool isNew) {
    if (EvClock.rows == null) {
      try {
        final c = jsonDecode(store.prefs.getString('kd-ev') ?? 'null');
        if (c is Map && c['rows'] is List) {
          EvClock.rows = [for (final x in c['rows'] as List) if (x is Map) x.cast<String, dynamic>()];
        }
      } catch (_) {}
    }
    calc.evClean();
    for (final e in calc.evList()) {
      calc.evS(e.id);
    }
    if (!isNew) evScenes();
    if (online.on) _evFetchAt[this] = DateTime.now().millisecondsSinceEpoch + 1800;
  }

  /// 서버 날짜 읽기 (웹 evFetch · supabase kd_event_list, 로그인 없이). 못 읽으면 표의 기본값 그대로
  Future<void> evFetch() async {
    final sv = online.sv;
    if (sv == null || EvClock.demo != null) return;
    try {
      final (j, t0, t1) = await sv.rpcAnon('kd_event_list');
      if (j is! Map || j['events'] is! List) return;
      final at = DateTime.tryParse('${j['now']}')?.millisecondsSinceEpoch;
      if (at != null) EvClock.skew = (at - (t0 + t1) / 2).round();
      final rows = [for (final x in j['events'] as List) if (x is Map) x.cast<String, dynamic>()];
      EvClock.rows = rows;
      try {
        await store.prefs.setString('kd-ev', jsonEncode({'at': t1, 'rows': rows}));
      } catch (_) {}
      calc.evClean();
      refresh();
      evScenes();
    } catch (_) {}
  }

  /// 시작·끝 장면 (웹 evScenes): 기간 중 처음 → 시작 장면 → 이벤트 창 / 상점만 열린 뒤 처음 → 끝 장면 → 상점
  void evScenes() {
    if (!calc.evOpen()) return;
    for (final e in calc.evList()) {
      final x = calc.evS(e.id), seen = x['seen'] as Map, ph = calc.evPhase(e);
      if (ph == 'on' && !truthy(seen['start'])) {
        seen['start'] = 1;
        save();
        scene('정기 이벤트', '${e.n}가 열렸어요', e.line('start'), '이벤트 보기', illust: e.art['illust'], onGo: () => queueEventSheet(this, e.id));
      } else if (ph == 'shop' && !truthy(seen['end'])) {
        seen['end'] = 1;
        seen['start'] = 1;
        save();
        scene(e.n, '${e.n}가 끝났어요', e.endLines(e.comp != null && calc.owned(e.comp!)), '${e.shopN} 가기', onGo: () => queueEventSheet(this, e.id, 'shop'));
      }
      evXmasCheck(e);
      evWarnCheck(e);
    }
    evMgResultCheck(); // 선물 배달 랭킹 결과 창 (웹 evScenes 의 evMgResult, controller_mg.dart)
  }

  /// 0.4초마다 (웹 evHud 의 날짜 바뀜): 날이 바뀌면 크리스마스 선물·눈송이 사라짐 알림
  void _evTick() {
    final fa = _evFetchAt[this];
    if (fa != null && DateTime.now().millisecondsSinceEpoch >= fa) {
      _evFetchAt[this] = null;
      evFetch();
    }
    if (titleOpen || !truthy(state.raw['started'])) return;
    final t = calc.evDay();
    if (_evDayK[this] == t) return;
    _evDayK[this] = t;
    for (final e in calc.evList()) {
      evXmasCheck(e);
      evWarnCheck(e);
    }
  }

  /// 크리스마스 주간 (웹 evXmasCheck): 오늘 들어옴 기록 → 첫날 산타 피트 장면 → 오늘 선물 창
  void evXmasCheck(EventDef e) {
    if (!calc.evXmas(e) || !calc.evOpen()) return;
    final x = calc.evS(e.id);
    if (calc.evBack(x)) return;
    if (acts.evXmasMark(e)) save();
    final seen = x['seen'] as Map, t = calc.evDay();
    if (!truthy(seen['xmas'])) {
      seen['xmas'] = 1;
      save();
      scene('크리스마스 주간', '산타 피트가 왔어요', e.line('xmas'), '선물 받기', onGo: () => queueFirst((ctx) => _evGiftShow(ctx, e.id)));
      return;
    }
    if (!truthy(((x['xm'] as Map)['gift'] as Map)[t]) && _evGiftQ[this] != true) {
      _evGiftQ[this] = true;
      queue((ctx) {
        _evGiftQ[this] = false;
        return _evGiftShow(ctx, e.id);
      });
    }
  }

  /// 산타 피트 오늘 선물 창 (웹 evGiftSheet) — 시험·미리보기에서도 부름
  void evGiftQueue(String id) => queue((ctx) => _evGiftShow(ctx, id));

  Future<void> _evGiftShow(BuildContext ctx, String id) async {
    final e = evts[id];
    if (e == null) return;
    final r = act((a) => a.evGift(id));
    if (r == null) return;
    save();
    haptic(const [30, 40, 70]);
    sound('gem');
    await showKdSheet<void>(ctx, builder: (c) => evGiftBody(this, c, e, r.big, r.rows));
  }

  /// 상점이 닫히기 3일 전부터 하루 한 번 「눈송이를 써 주세요」 (웹 evWarnCheck)
  void evWarnCheck(EventDef e) {
    if (calc.evPhase(e) != 'shop' || !calc.evOpen()) return;
    final x = calc.evS(e.id), seen = x['seen'] as Map, left = (calc.evDates(e).shop - calc.evNow) / 864e5;
    if (!left.isFinite || left > 3 || asNum(x['sf']) <= 0 || seen['warn'] == calc.evDay()) return;
    seen['warn'] = calc.evDay();
    save();
    final n = math.max(1, left.ceil());
    queue((_) async => toast('❄ ${e.curN}이(가) $n일 뒤 사라져요. ${e.shopN}에서 써 주세요'));
  }

  /// 상단 눈꽃제 버튼 (웹 evBtnTap): 영지 10 전이면 안내, 아니면 이벤트 창
  void evBtnTap() {
    final e = calc.evCur();
    if (e == null) return;
    haptic(const [8]);
    if (!calc.evOpen()) {
      openEventLock(this, e);
      return;
    }
    openEventSheet(this, e.id);
  }

  /// 눈사람 대장 도전 (웹 evBossStart): 확인·횟수 기록은 acts.evBossBegin, 전투는 sim
  void evBossGo(String id) {
    final r = act((a) => a.evBossBegin(id, inCh: sim.ch != null));
    if (r.err != null) {
      if (r.err!.isNotEmpty) toast(r.err!);
      return;
    }
    sim.evBossStart(id, r.stg, r.santa, r.ref);
    save();
    _chShow();
  }

  /// 광고 보고 +1 (이벤트마다 하루 1번 — 광고 표 ADS 는 건드리지 않고 이벤트 저장에 기록, 웹 evAdWatch) → 이벤트 창 다시
  Future<void> evAdWatch(String id, String k) async {
    final x = calc.evToday(calc.evS(id));
    if (truthy((x[k] as Map)['ad'])) {
      toast('오늘은 다 봤어요. 내일 다시 받을 수 있어요');
      return;
    }
    if (!await playAd()) return;
    (calc.evToday(calc.evS(id))[k] as Map)['ad'] = 1;
    toast(k == 'boss' ? '눈사람 대장 도전 +1' : '선물 배달 +1판');
    save();
    refresh();
    await openEventSheet(this, id, k);
  }

  /// 마을 광장 트리 누름 (웹 evTreeHit) — 트리 자리를 눌렀으면 true
  bool evTreeTap(double mx, double my) {
    final e = calc.evTreeE();
    if (e == null) return false;
    final x = evTreePos[0], y = evTreePos[1], w = evTreePos[2];
    if ((mx - x).abs() > w * .4 || my > y || my < y - w * .95) return false;
    final r = act((a) => a.evTreeTake(e));
    if (r.err != null) {
      toast(r.err!);
      return true;
    }
    save();
    haptic(const [30, 40, 70]);
    sound('gem');
    openSheet<void>((c) => evTreeBody(c, r.rows));
    return true;
  }

  /// 눈사람 대장 끝 (웹 evBossWin·evBossLose → evBossEnd): 보상을 넣고, 이기면 1.3초 뒤 나가서 결과 창
  void _evBossEnd(EvBossEndEvent e) {
    final (sf, rows) = acts.evBossResult(e.ev, e.won, e.stg, e.santa);
    save();
    refresh();
    void end() {
      final h = sim.ch;
      if (h == null || h.mode != 'ev') return;
      sim.chExit();
      frame.value++;
      refresh();
      queue((ctx) => showKdSheet<void>(ctx,
          builder: (c) => evBossResultBody(this, c, id: e.ev, won: e.won, stg: e.stg, santa: e.santa, sf: sf, rows: rows)));
    }

    if (e.won) {
      Timer(const Duration(milliseconds: 1300), end);
    } else {
      end();
    }
  }
}
