// 정기 이벤트 「눈꽃제」 흐름 확인 (docs/content/EVENT_SNOW.md): 기간·잠김·시계 되돌림·전투 눈송이·눈사람 대장·출석·상점·
// 크리스마스 주간·소복이·외형·우편·망가진 저장·웹 저장 보존. 공식 값은 웹과 같은 식(core/event.dart)으로 계산.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/data.dart';
import 'package:kingday/core/event.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/profile_data.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

int kst(int y, int m, int d, [int h = 12]) => DateTime.utc(y, m, d, h - 9).millisecondsSinceEpoch;

void main() {
  var now = kst(2026, 12, 15);
  GameCalc calcFor(Map<String, dynamic> save) => GameCalc(GameState.hydrate(save, now, GameCalc.rankIdxOf), clock: () => now);
  final e = evts['snow2026']!;
  Map<String, dynamic> base([Map<String, dynamic>? x]) => {'gold': 1e9, 'stage': 30, 'best': 30, 'started': true, 'joined': {'bron': true, 'haral': true, 'riel': true, 'margo': true}, ...?x};

  setUp(() {
    now = kst(2026, 12, 15);
    EvClock.skew = 0;
    EvClock.rows = null;
    EvClock.demo = null;
  });

  test('표: 눈꽃제 12/11~12/31 · 상점 1/7 · 크리스마스 12/21~25 · 출석 14칸 · 상점 8줄', () {
    expect(e.n, '눈꽃제');
    expect(e.att.length, 14);
    expect(e.shop.length, 8);
    expect(e.boss!.win(1), 22);
    expect(e.boss!.win(30), 60);
    expect(e.boss!.mile(10)!.first['k'], 'lcard');
    expect(e.boss!.mile(5)!.first['k'], 'gem');
    expect(e.boss!.mile(7), isNull);
    expect(evCards, contains('sobok'));
    expect(GameCalc.cardIds(), isNot(contains('sobok')), reason: '일반 카드 뽑기에 안 나옴');
    expect(recruits['sobok']!.job, 'miner');
    expect(skinDefs['santa']!.n, '산타 카엘');
  });

  test('기간: 전 · 중 · 크리스마스 · 상점만 · 끝', () {
    final c = calcFor(base());
    String ph(int t) {
      now = t;
      return c.evPhase(e);
    }

    expect(ph(kst(2026, 12, 10, 23)), 'pre');
    expect(ph(kst(2026, 12, 11, 0) + 1000), 'on');
    expect(c.evXmas(e), isFalse);
    expect(ph(kst(2026, 12, 22)), 'on');
    expect(c.evXmas(e), isTrue);
    expect(ph(kst(2026, 12, 26)), 'on');
    expect(c.evXmas(e), isFalse);
    expect(ph(kst(2027, 1, 3)), 'shop');
    expect(ph(kst(2027, 1, 8, 1)), 'off');
    expect(c.evList(), isEmpty);
  });

  test('서버 날짜가 있으면 그 값 · 서버 시각 차이', () {
    final c = calcFor(base());
    EvClock.rows = [
      {'id': 'snow2026', 'start_at': '2026-12-01T00:00:00+09:00', 'end_at': '2026-12-05T00:00:00+09:00', 'shop_end_at': '2026-12-06T00:00:00+09:00', 'extra': {}}
    ];
    now = kst(2026, 12, 3);
    expect(c.evPhase(e), 'on');
    EvClock.skew = 3 * 86400000;
    expect(c.evPhase(e), 'off', reason: '서버 시각 기준 12/6');
  });

  test('영지 10 전에는 잠김 · 전투 눈송이 없음', () {
    final c = calcFor(base({'stage': 5, 'best': 5}));
    expect(c.evOpen(), isFalse);
    expect(c.evKill(100), 0);
    expect(c.evS('snow2026')['sf'], 0);
  });

  test('전투 눈송이: 25마리마다 1 · 하루 100 · 다음 날 다시', () {
    final c = calcFor(base());
    var got = 0;
    for (var i = 0; i < 24; i++) {
      got += c.evKill();
    }
    expect(got, 0);
    expect(c.evKill(), 1);
    expect(c.evKill(5000), 99, reason: '하루 100까지');
    expect(c.evS('snow2026')['sf'], 100);
    now += 86400000;
    expect(c.evKill(25), 1);
  });

  test('방치 눈송이: 처치 ×0.03 · 하루 한도', () {
    final c = calcFor(base());
    final k = c.idleKills(3600 * 8);
    expect(k, greaterThan(0));
    final got = c.evIdle(3600 * 8);
    expect(got, _min(100, (k * .03 / 25).floor()));
  });

  test('시계 되돌림: 본 날보다 앞이면 출석·전투·도전 없음', () {
    final c = calcFor(base()), a = GameActions(c, rng: Mulberry32(1));
    expect(a.evAttClaim('snow2026').err, isNull);
    now = kst(2026, 12, 13);
    expect(c.evBack(c.evS('snow2026')), isTrue);
    expect(c.evKill(100), 0);
    expect(a.evAttClaim('snow2026').err, evBackMsg);
    expect(a.evBossBegin('snow2026').err, evBackMsg);
  });

  test('출석 14칸: 하루 1칸 · 7칸째 동료 카드 · 14칸째 소복이 10장', () {
    final c = calcFor(base()), a = GameActions(c, rng: Mulberry32(1));
    for (var i = 0; i < 14; i++) {
      final r = a.evAttClaim('snow2026');
      expect(r.err, isNull, reason: '${i + 1}칸');
      expect(a.evAttClaim('snow2026').err, isNotNull, reason: '같은 날 두 번');
      now += 86400000;
    }
    expect(asNum(asMap(c.s.raw['cards'])!['sobok']), 10);
    expect(a.evAttClaim('snow2026').err, contains('14칸'));
  });

  test('상점: 한도 · 재화 부족 · 테두리는 한 번 · 소복이 30장 → 합류', () {
    final c = calcFor(base()), a = GameActions(c, rng: Mulberry32(1));
    c.evS('snow2026')['sf'] = 5000;
    for (var i = 0; i < 3; i++) {
      expect(a.evBuy('snow2026', 'sobok').err, isNull);
    }
    expect(a.evBuy('snow2026', 'sobok').err, '더 살 수 없어요');
    expect(asNum(asMap(c.s.raw['cards'])!['sobok']), 30);
    expect(c.evJoinLeft('sobok'), 0);
    expect(a.evBuy('snow2026', 'frame').err, isNull);
    expect(c.pfHas('snow'), isTrue);
    expect(a.evBuy('snow2026', 'frame').err, '더 살 수 없어요');
    c.evS('snow2026')['sf'] = 10;
    expect(a.evBuy('snow2026', 'gem').err, '눈송이이(가) 부족해요');
    // 소복이 맞이하기: 30장이면 모집 동료처럼 합류 (일반 카드 규칙)
    expect(c.cardList(), contains('sobok'));
    expect(c.cardOpen('sobok'), isTrue, reason: '브론이 있으면 카드 탭에 열림');
  });

  test('눈사람 대장: 하루 3번(+광고 1) · 기준 영지 고정 · 단계·첫 돌파 보상', () {
    final c = calcFor(base({'best': 31})), a = GameActions(c, rng: Mulberry32(1));
    final r1 = a.evBossBegin('snow2026');
    expect(r1.err, isNull);
    expect(r1.stg, 1);
    expect(r1.ref, 30, reason: '처음 도전 때 최고 영지로 고정');
    c.s.best = 51;
    expect(c.evBossRef(c.evS('snow2026')), 30, reason: '영지를 넓혀도 그대로');
    final hp1 = EventCalc.evBossHp(e.boss!, 1, 30), hp2 = EventCalc.evBossHp(e.boss!, 2, 30);
    expect(hp2 / hp1, closeTo(1.1, 1e-9));
    expect(hp1, closeTo(GameCalc.monHp(30, false) * Balance.bossHp * .7, 1e-6));
    final (sf, rows) = a.evBossResult('snow2026', true, 1, false);
    expect(sf, 22);
    expect(rows, isEmpty);
    expect(c.evS('snow2026')['boss']['st'], 2);
    final (sf5, rows5) = a.evBossResult('snow2026', true, 5, true);
    expect(sf5, 60, reason: '산타 눈사람 2배');
    expect(rows5.single.kind, 'gem');
    final (lose, _) = a.evBossResult('snow2026', false, 6, false);
    expect(lose, 10);
    expect(a.evBossBegin('snow2026').err, isNull);
    expect(a.evBossBegin('snow2026').err, isNull);
    expect(a.evBossBegin('snow2026').err, contains('오늘 도전'));
    (c.evS('snow2026')['boss'] as Map)['ad'] = 1;
    expect(c.evTriesLeft(e), 1);
  });

  test('눈사람 대장 전투: 이기면 끝 사건 · 지면 끝 사건 (영지는 그대로)', () {
    final c = calcFor(base({'wave': 4})), a = GameActions(c, rng: Mulberry32(1));
    final b = BattleSim(c, rng: Mulberry32(3), gobT: 1e9)..syncParty();
    final r = a.evBossBegin('snow2026');
    b.evBossStart('snow2026', r.stg, r.santa, r.ref);
    for (var i = 0; i < 40; i++) {
      b.step(.05);
    }
    expect(b.mons.where((m) => m.boss && m.snow == 'snow2026').length, 1);
    for (final m in b.mons) {
      m.hp = 0;
    }
    b.step(.05);
    expect(b.events.whereType<EvBossEndEvent>().single.won, isTrue);
    expect([c.s.stage, c.s.wave], [30, 4]);
    b.chExit();
    b.events.clear();
    b.evBossStart('snow2026', 2, false, 30);
    for (var i = 0; i < 40 && b.mons.isEmpty; i++) {
      b.step(.05);
    }
    b.bossT = .01;
    for (var i = 0; i < 400 && b.events.whereType<EvBossEndEvent>().isEmpty; i++) {
      b.step(.05);
    }
    expect(b.events.whereType<EvBossEndEvent>().single.won, isFalse);
  });

  test('크리스마스 주간: 피트 선물(25일 큰 선물) · 트리 하루 1번 · 배지 3일', () {
    now = kst(2026, 12, 21);
    final c = calcFor(base()), a = GameActions(c, rng: Mulberry32(1));
    for (var d = 21; d <= 25; d++) {
      now = kst(2026, 12, d);
      expect(a.evXmasMark(e), isTrue);
      final g = a.evGift('snow2026')!;
      expect(g.big, d == 25);
      expect(a.evGift('snow2026'), isNull, reason: '하루 1번');
      expect(a.evTreeTake(e).err, isNull);
      expect(a.evTreeTake(e).err, isNotNull);
    }
    expect(c.evXmasCount(), 5);
    expect(c.bdHas('xmas'), isTrue);
  });

  test('선물 배달: 크리스마스 주간에만 · 하루 3판(+광고 1)', () {
    final c = calcFor(base());
    expect(c.evMgOn(e), isFalse);
    now = kst(2026, 12, 22);
    expect(c.evMgOn(e), isTrue);
    expect(c.evMgLeft(e), 3);
    (c.evS('snow2026')['mg'] as Map)['n'] = 3;
    expect(c.evMgLeft(e), 0);
    (c.evS('snow2026')['mg'] as Map)['ad'] = 1;
    expect(c.evMgLeft(e), 1);
  });

  test('외형: 받으면 바로 입음 · 카엘만 · 해 꼬리표', () {
    final c = calcFor(base());
    expect(c.skinGive('santa', 2026), isTrue);
    expect(c.skinOn()?.k, 'santa');
    expect(c.skinSpr('kael'), 'kael_santa');
    expect(c.skinSpr('kael_chief'), 'kael_chief');
    expect(c.skinGive('santa', 2027), isFalse);
    expect(skinDefs['santa']!.tag(((c.s.raw['skins'] as Map)['santa'] as List).cast<int>()), '2026·2027 선물 배달 TOP 10');
    c.s.raw['skin'] = '';
    expect(c.skinSpr('kael'), 'kael');
  });

  test('우편 재화(evc): 상점이 닫힌 이벤트는 무시', () {
    final c = calcFor(base());
    expect(c.evAdd('snow2026', 100), 100);
    now = kst(2027, 1, 9);
    expect(c.evAdd('snow2026', 100), 0);
    expect(c.evAdd('nope', 100), 0);
  });

  test('망가진 저장: 이벤트 칸·외형·별·카드', () {
    final c = calcFor(base({
      'evs': {'snow2026': {'sf': 1e300, 'boss': {'st': 1e9}, 'day': 'x', 'xm': {'gift': null}}},
      'skins': {'santa': 'x', 'pirate': [2026]}, 'skin': 'pirate', 'rec': {'sobok': 9}, 'cards': {'sobok': 'many'},
    }));
    final x = c.evS('snow2026');
    expect(x['sf'], 10000000);
    expect((x['boss'] as Map)['st'], 999);
    expect((x['day'] as Map)['bat'], 0);
    expect(c.s.raw['skins'], <String, dynamic>{});
    expect(c.s.raw['skin'], '');
    expect(c.s.rec!['sobok'], c.starMax('sobok'));
    expect((c.s.raw['cards'] as Map)['sobok'], 0);
    expect(c.starMul('sobok'), isA<num>());
  });

  test('웹에서 쌓은 이벤트 저장을 앱이 그대로 저장 (지우지 않음)', () {
    final web = base({
      'evs': {'snow2026': {'sf': 777, 'att': {'last': '2026-12-14', 'cnt': 4}, 'shop': {'gem': 2}, 'hi': 20261214, 'mg': {'d': '', 'n': 0, 'ad': 0, 'best': 1480}}},
      'skin': 'santa', 'skins': {'santa': [2026]}, 'mgHint': 1, 'mgPlayed': 1,
    });
    final c = calcFor(jsonDecode(jsonEncode(web)) as Map<String, dynamic>);
    final back = jsonDecode(jsonEncode(c.s.raw)) as Map<String, dynamic>;
    expect(back['evs']['snow2026']['sf'], 777);
    expect(back['evs']['snow2026']['att']['cnt'], 4);
    expect(back['evs']['snow2026']['mg']['best'], 1480);
    expect(back['skin'], 'santa');
    expect(back['skins'], {'santa': [2026]});
    expect(back['mgHint'], 1);
    c.evClean();
    expect(asMap(c.s.raw['evs'])!.containsKey('snow2026'), isTrue, reason: '기간 중에는 지우지 않음');
    now = kst(2027, 2, 1);
    c.evClean();
    expect(asMap(c.s.raw['evs'])!.containsKey('snow2026'), isFalse, reason: '상점까지 닫히면 지움');
  });

  test('원정 일지: 이벤트 기간에만 「눈사람 대장 도전」 +20', () {
    final c = calcFor(base()), a = GameActions(c, rng: Mulberry32(1));
    expect(a.passAdd('snow'), 20);
    expect(a.passAdd('snow'), 0, reason: '하루 20까지');
    now = kst(2026, 11, 20);
    final c2 = calcFor(base()), a2 = GameActions(c2, rng: Mulberry32(1));
    expect(a2.passAdd('snow'), 0);
  });
}

num _min(num a, num b) => a < b ? a : b;
