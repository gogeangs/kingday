// QA 0.0.7 (2026-11-08): 눈꽃제 무작위 시험 — 망가진 이벤트 저장 + 날짜를 앞뒤로 마구 옮기며 모든 이벤트 동작을 수천 번.
// 어떤 경우에도 멈추지(예외) 않고, 눈송이·출석·상점·도전 횟수가 한도를 넘거나 음수·NaN 이 되지 않아야 한다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/battle/sim.dart';
import 'package:kingday/core/actions.dart';
import 'package:kingday/core/calc.dart';
import 'package:kingday/core/event.dart';
import 'package:kingday/core/js.dart';
import 'package:kingday/core/minigame.dart';
import 'package:kingday/core/rng.dart';
import 'package:kingday/core/state.dart';

int kst(int y, int m, int d, [int h = 12]) => DateTime.utc(y, m, d, h - 9).millisecondsSinceEpoch;

/// 망가진 이벤트 저장들 (웹에서 쌓였거나 손으로 고친 저장)
final Map<String, Map<String, dynamic>> _bad = {
  '정상': {},
  'evs 가 글자': {'evs': 'x'},
  'evs 가 목록': {'evs': [1, 2]},
  '이벤트 칸이 목록': {'evs': {'snow2026': []}},
  '하위 칸 모두 이상': {
    'evs': {
      'snow2026': {
        'sf': 'many', 'att': [], 'shop': [], 'hi': 'x', 'day': {'bat': -5, 'kc': 'z', 'd': 3},
        'boss': {'mile': [], 'ref': 'a', 'n': -9, 'ad': 'yes', 'st': -3, 'best': 'b'},
        'xm': {'gift': [], 'days': 'x', 'tree': 5}, 'mg': {'best': -1, 'n': -100, 'ad': 7}, 'seen': 3,
      }
    }
  },
  '출석 칸 수가 이상(음수)': {'evs': {'snow2026': {'att': {'cnt': -1, 'last': 5}}}},
  '출석 칸 수가 이상(소수)': {'evs': {'snow2026': {'att': {'cnt': 2.5, 'last': ''}}}},
  '출석 칸 수가 이상(글자)': {'evs': {'snow2026': {'att': {'cnt': '3', 'last': null}}}},
  '출석 칸 수가 아주 큼': {'evs': {'snow2026': {'att': {'cnt': 99}}}},
  '상점 기록이 이상': {'evs': {'snow2026': {'shop': {'gem': 99, 'sobok': -1, 'frame': 'y', 'x': {}}}}},
  '도전 횟수 음수': {'evs': {'snow2026': {'boss': {'n': -50, 'd': '2026-12-15'}, 'mg': {'n': -50, 'd': '2026-12-22'}}}},
  '오늘 눈송이 음수': {'evs': {'snow2026': {'day': {'d': '2026-12-15', 'bat': -1000, 'kc': -5}}}},
  '아주 먼 미래를 본 기록': {'evs': {'snow2026': {'hi': 99991231}}},
  '첫 돌파 기록이 이상': {'evs': {'snow2026': {'boss': {'mile': {'5': 'x', 'a': 1}, 'st': 1e300, 'ref': 1e9}}}},
  '옛 이벤트·모르는 이벤트': {'evs': {'old2025': {'sf': 5}, 'snow2026': {'sf': 1e12}}},
  '외형 이상': {'skins': {'santa': [-1, 'x', 2026.7, null], 'zzz': [2026]}, 'skin': 'santa'},
  '외형 목록이 글자': {'skins': 'santa', 'skin': 'santa'},
  '소복이 카드·별 이상': {'cards': {'sobok': -30}, 'rec': {'sobok': 99}},
};

void _sane(GameCalc c, String where) {
  void walk(Object? v, String p) {
    if (v is double) {
      expect(v.isNaN, isFalse, reason: '$where: $p NaN');
      expect(v.isInfinite, isFalse, reason: '$where: $p 무한');
    } else if (v is Map) {
      v.forEach((k, x) => walk(x, '$p.$k'));
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        walk(v[i], '$p[$i]');
      }
    }
  }

  walk(c.s.raw, 'S');
  expect(() => jsonEncode(c.s.raw), returnsNormally, reason: '$where: JSON 저장 불가');
  expect(c.s.gem, greaterThanOrEqualTo(0), reason: '$where: 이삭 음수');
  final all = asMap(c.s.raw['evs']);
  if (all == null) return;
  for (final id in evts.keys) {
    if (all[id] is! Map) continue;
    final E = evts[id]!, x = c.evS(id);
    expect(asNum(x['sf']), inInclusiveRange(0, 1e7), reason: '$where: 눈송이 범위');
    final att = asNum((x['att'] as Map)['cnt']);
    expect(att, inInclusiveRange(0, E.att.length), reason: '$where: 출석 칸 $att');
    for (final it in E.shop) {
      expect(c.evShopLeft(E, it), inInclusiveRange(0, it.lim), reason: '$where: 상점 ${it.k} 남은 수');
    }
    expect(c.evTriesLeft(E), inInclusiveRange(0, E.boss!.tries + 1), reason: '$where: 남은 도전');
    expect(c.evMgLeft(E), inInclusiveRange(0, 4), reason: '$where: 남은 선물 배달');
    final day = x['day'] as Map;
    expect(asNum(day['bat']), inInclusiveRange(0, asNum(E.bat!['cap'])), reason: '$where: 오늘 전투 눈송이');
  }
}

void main() {
  var now = kst(2026, 12, 15);
  setUp(() {
    EvClock.skew = 0;
    EvClock.rows = null;
    EvClock.demo = null;
  });

  for (final b in _bad.entries) {
    test('망가진 저장 + 날짜 앞뒤로 · ${b.key}', () {
      for (var seed = 1; seed <= 6; seed++) {
        final r = Mulberry32(seed * 7919 + b.key.length);
        now = kst(2026, 12, 9);
        final save = <String, dynamic>{
          'gold': 1e9, 'gem': 500, 'stage': 30, 'best': 31, 'started': true,
          'joined': {'bron': true, 'haral': true, 'riel': true, 'margo': true},
          ...jsonDecode(jsonEncode(b.value)) as Map<String, dynamic>,
        };
        final c = GameCalc(GameState.hydrate(save, now, GameCalc.rankIdxOf), clock: () => now);
        final a = GameActions(c, rng: Mulberry32(seed));
        final e = evts['snow2026']!;
        final where = '${b.key} #$seed';
        _sane(c, '$where 불러온 직후');
        for (var i = 0; i < 400; i++) {
          // 날짜: 대부분 앞으로, 가끔 뒤로(시계 되돌림)·크게 건너뜀
          final p = r.next();
          if (p < .55) {
            now += (r.next() * 6 * 3600000).floor();
          } else if (p < .7) {
            now -= (r.next() * 3 * 86400000).floor();
          } else if (p < .75) {
            now += (r.next() * 20 * 86400000).floor();
          }
          if (now > kst(2027, 1, 12) || now < kst(2026, 12, 1)) now = kst(2026, 12, 8 + (r.next() * 30).floor());
          final act = (r.next() * 16).floor();
          switch (act) {
            case 0:
              c.evKill((r.next() * 60).floor());
            case 1:
              c.evIdle(r.next() < .1 ? 1e9 : r.next() * 36000);
            case 2:
              a.evAttClaim('snow2026');
            case 3:
              c.evS('snow2026')['sf'] = asNum(c.evS('snow2026')['sf']) + (r.next() * 400).floor();
              a.evBuy('snow2026', e.shop[(r.next() * e.shop.length).floor()].k);
            case 4:
              final g = a.evBossBegin('snow2026');
              if (g.err == null) a.evBossResult('snow2026', r.next() < .6, g.stg, g.santa);
            case 5:
              a.evXmasMark(e);
            case 6:
              a.evGift('snow2026');
            case 7:
              a.evTreeTake(e);
            case 8:
              c.evAdd('snow2026', r.next() * 50);
            case 9:
              c.skinGive('santa', 2026);
            case 10:
              c.evClean();
            case 11:
              (c.evS('snow2026')['boss'] as Map)['ad'] = 1;
              (c.evS('snow2026')['mg'] as Map)['ad'] = 1;
            case 12:
              if (c.evMgLeft(e) > 0) (c.evS('snow2026')['mg'] as Map)['n'] = asNum((c.evS('snow2026')['mg'] as Map)['n']) + 1;
            case 13:
              c.s.best = 1 + (r.next() * 90).floor();
            default:
              for (final E in c.evList()) {
                c.evDot(E);
                c.evMgShow(E);
                c.evMgOn(E);
                c.evDates(E);
              }
              c.evCur();
              c.evTreeE();
              c.evXmasCount();
              c.skinOn();
              c.skinFace('kael');
              c.cardList();
          }
          _sane(c, '$where 동작 $i($act)');
        }
      }
    });
  }

  test('눈사람 대장 전투: 단계 1~999 · 기준 영지 1~91 · 산타 — 체력·공격 숫자 정상, 멈추지 않음', () {
    final now0 = kst(2026, 12, 22);
    for (final ref in [1, 10, 50, 61, 91]) {
      for (final stg in [1, 10, 100, 999]) {
        final c = GameCalc(
            GameState.hydrate({'gold': 1e9, 'stage': 30, 'best': 31, 'started': true, 'joined': {'bron': true, 'sobok': true}}, now0, GameCalc.rankIdxOf),
            clock: () => now0);
        final hp = EventCalc.evBossHp(evts['snow2026']!.boss!, stg, ref), atk = EventCalc.evBossAtk(evts['snow2026']!.boss!, stg, ref);
        expect(hp.isFinite && hp > 0, isTrue, reason: '체력 $stg/$ref = $hp');
        expect(atk.isFinite && atk > 0, isTrue, reason: '공격 $stg/$ref = $atk');
        final sim = BattleSim(c, rng: Mulberry32(stg + ref), gobT: 1e9)..syncParty();
        sim.evBossStart('snow2026', stg, true, ref);
        for (var i = 0; i < 2400 && sim.events.whereType<EvBossEndEvent>().isEmpty; i++) {
          sim.step(.05);
        }
        for (final m in sim.mons) {
          expect(m.hp.isNaN, isFalse);
        }
      }
    }
  });

  test('소복이는 희망 동료가 될 수 없음 · 옛 저장에 희망이 소복이여도 일반 뽑기에 안 나옴', () {
    final now0 = kst(2026, 12, 15);
    final c = GameCalc(
        GameState.hydrate({'gold': 1e9, 'stage': 30, 'best': 31, 'started': true, 'joined': {'bron': true, 'sobok': true}, 'cards': {'sobok': 3}}, now0, GameCalc.rankIdxOf),
        clock: () => now0);
    final a = GameActions(c, rng: Mulberry32(1));
    a.toggleWish('sobok');
    expect(c.s.wish, isNull);
    c.s.wish = 'sobok';
    final r = Mulberry32(9);
    for (var i = 0; i < 3000; i++) {
      expect(c.cardPick(r, 'shop'), isNot('sobok'));
    }
  });

  test('선물 배달: 마구 누르기·아무것도 안 누르기 · 점수·보상 범위', () {
    for (var seed = 1; seed <= 30; seed++) {
      final r = Mulberry32(seed);
      final g = MgGame(seed * 1013);
      var steps = 0;
      while (!g.over && steps < 60 * 400) {
        if (seed % 3 == 0 ? r.next() < .5 : seed % 3 == 1 ? false : r.next() < .03) g.tap();
        g.step();
        steps++;
      }
      expect(g.score, greaterThanOrEqualTo(0));
      expect(g.reward, inInclusiveRange(0, 100));
    }
  });
}
