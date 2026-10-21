/// 출석체크 「피트의 출석부」 — 웹 index.html 의 attDo()/attAdDo()/attGive()/attCards() 를 그대로 옮긴 것.
/// 기획: docs/content/ATTENDANCE.md · 저장 필드 S.att · S.tickets (웹과 같은 이름)
///
/// 하루 한 번 출석 → 7일 판(7칸 반복)·한달 판(매달 1일 새로, 최대 31칸)에 동시에 도장.
/// 같은 난수로 웹과 같은 결과가 나오는지 test/actions_parity_test.dart (attend·attendFresh) 가 확인한다.
library;

import 'dart:math' as math;

import 'actions.dart';
import 'calc.dart';
import 'data.dart';
import 'fmt.dart';
import 'js.dart';

/// 7일 판 보상 (1~7칸)
const List<List<Map<String, Object>>> attWeek = [
  [{'k': 'gold', 'h': 1}],
  [{'k': 'gem', 'n': 10}],
  [{'k': 'tbox', 'n': 3}],
  [{'k': 'ore', 'n': 20}],
  [{'k': 'gem', 'n': 10}],
  [{'k': 'card', 'n': 3, 'alt': 30}],
  [{'k': 'gem', 'n': 30}, {'k': 'tbox10', 'n': 1}],
];

/// 한달 판 큰 보상 (7·14·21·28회)
const Map<int, List<Map<String, Object>>> attBig = {
  7: [{'k': 'card', 'n': 10, 'alt': 100}],
  14: [{'k': 'gem', 'n': 100}],
  21: [{'k': 'ecard', 'n': 10, 'alt': 100}],
  28: [{'k': 'gem', 'n': 100}, {'k': 'badge'}],
};
const _attG = [1, 4, 10, 13, 17, 20, 24, 27], _attS = [2, 5, 9, 12, 16, 19, 23, 26];

/// 한달 판 n회째 보상
List<Map<String, Object>> attMonth(int n) =>
    attBig[n] ??
    (n >= 29
        ? const [{'k': 'gold', 'h': 1}]
        : _attG.contains(n)
            ? const [{'k': 'gold', 'h': .5}]
            : _attS.contains(n)
                ? const [{'k': 'seed'}]
                : const [{'k': 'ore', 'n': 10}]);

/// today() 형식('2026-1-5', 0 없음)을 숫자로 바꿔 비교
int attDnum(String? t) {
  final p = (t ?? '').split('-');
  if (p.length != 3) return 0;
  final n = p.map(int.tryParse).toList();
  if (n.any((x) => x == null || x < 0)) return 0;
  return n[0]! * 10000 + n[1]! * 100 + n[2]!;
}

String attYm(String t) {
  final p = t.split('-');
  return '${p[0]}-${p[1].padLeft(2, '0')}';
}

/// 그 달의 날짜 수
int attDim(String t) {
  final p = t.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1] + 1, 0).day;
}

/// 월별 배지 그림이 있는 달 (웹 ATT_BDM). 없는 달은 공용 그림
const attBadgeMonths = ['11', '12', '01'];
String attBadgeAsset(String k) {
  final m = k.length >= 10 ? k.substring(8) : '';
  return 'assets/game/profile/badge_att${attBadgeMonths.contains(m) ? '_$m' : ''}.png';
}

/// 「2026년 11월 출석」
String attBadgeName(String k) => '${k.substring(4, 8)}년 ${int.parse(k.substring(8))}월 출석';

/// 받은 보상 한 줄 (창에 보여 줄 것)
class AttRow {
  AttRow(this.kind, this.text, [this.sub = '', this.again = false, this.badge]);
  final String kind; // gold · gem · ore · seed · tbox · tbox10 · card · badge
  final String text, sub;
  final bool again;
  final String? badge;
}

class AttResult {
  AttResult(this.wd, this.md, this.rows);
  final int wd, md;
  final List<AttRow> rows;
}

/// 판에 쓰는 짧은 이름
String attShort(Map r) => switch (r['k']) {
      'gold' => asNum(r['h']) < 1 ? '골드½' : '골드',
      'gem' => '이삭 ${r['n']}',
      'ore' => '광석 ${r['n']}',
      'seed' => '씨앗',
      'tbox' => '개봉권 ${r['n']}',
      'tbox10' => '10연권',
      'card' => '카드 ${r['n']}',
      'ecard' => '영웅 ${r['n']}',
      'badge' => '배지',
      _ => '',
    };

/// 판 칸 설명 (긴 이름)
String attName(Map r) => switch (r['k']) {
      'gold' => r['g'] != null ? '골드 +${fmt(asNum(r['g']))}' : '골드 ${asNum(r['h']) < 1 ? '30분' : '${r['h']}시간'}치',
      'gem' => '이삭 ${r['n']}',
      'ore' => '광석 ${r['n']}',
      'seed' => '씨앗 묶음',
      'tbox' => '무료 개봉권 ${r['n']}장',
      'tbox10' => '10연속 무료권',
      'card' => '동료 카드 ${r['n']}장',
      'ecard' => '영웅↑ 카드 ${r['n']}장',
      'badge' => '출석 배지',
      _ => '',
    };

extension Attendance on GameActions {
  /// S.att (없으면 기본값)
  Map<String, dynamic> attA() {
    var a = asMap(s.raw['att']);
    if (a == null) s.raw['att'] = a = <String, dynamic>{};
    const d = {'last': '', 'w': 0, 'ym': '', 'm': 0, 'ad': '', 'intro': 0, 'tab': 'w'};
    for (final e in d.entries) {
      a[e.key] ??= e.value;
    }
    if (a['got'] is! List) a['got'] = <dynamic>[];
    if (asMap(s.raw['tickets']) == null) s.raw['tickets'] = <String, dynamic>{'box': 0, 'box10': 0};
    return a;
  }

  Map<String, dynamic> get tickets {
    attA();
    return asMap(s.raw['tickets'])!;
  }

  int tkN(String k) => orNum(tickets[k], 0).toInt();

  /// 'done' 오늘 받음 · 'back' 날짜가 거꾸로 · 'ok' 받을 수 있음
  String attStatusAt(String t) {
    final a = attA();
    if (a['last'] == t) return 'done';
    final last = a['last'] as String? ?? '';
    if (last.isNotEmpty && attDnum(t) < attDnum(last)) return 'back';
    return 'ok';
  }

  /// 이번 달 출석 횟수
  int attMonthN(String t) {
    final a = attA();
    return a['ym'] == attYm(t) ? orNum(a['m'], 0).toInt() : 0;
  }

  /// 웹 attDo(t): 그날 출석 → 두 판 보상 지급. 결과 또는 'done'/'back'
  Object attDo(String t) {
    final a = attA(), st = attStatusAt(t);
    if (st != 'ok') return st;
    final ym = attYm(t);
    if (a['ym'] != ym) {
      a['ym'] = ym;
      a['m'] = 0;
    }
    final wd = orNum(a['w'], 0).toInt() % 7, md = math.min(31, orNum(a['m'], 0).toInt() + 1);
    final rows = <AttRow>[], got = <dynamic>[];
    for (final r in [...attWeek[wd], ...attMonth(md)]) {
      final g = _attGive(r);
      got.add(g.$1);
      rows.add(g.$2);
    }
    a['w'] = (wd + 1) % 7;
    a['m'] = md;
    a['last'] = t;
    a['got'] = got;
    c.stat('att', 1);
    return AttResult(wd, md, rows);
  }

  /// 웹 attAdDo(t): 광고 2배 — 그날 받은 보상을 한 번 더 (배지 제외). 못 받으면 null
  List<AttRow>? attAdDo(String t) {
    final a = attA();
    if (attStatusAt(t) != 'done' || a['ad'] == t) return null;
    final rows = <AttRow>[];
    for (final r in (a['got'] as List)) {
      final m = asMap(r)!;
      if (m['k'] == 'badge') continue;
      rows.add(_attGive(m, again: true).$2);
    }
    a['ad'] = t;
    return rows;
  }

  /// 카드: 받을 카드가 없으면 null. 영웅↑ 카드는 영웅·전설 중에서, 없으면 일반 규칙
  ({List<(String, int)> got, num gold})? _attCards(int n, bool epic) {
    if (epic) {
      final pool = GameCalc.cardIds().where((x) => c.cardCan(x) && (gradeOf[x] == 'epic' || gradeOf[x] == 'legend')).toList();
      if (pool.isNotEmpty) {
        final got = <(String, int)>[];
        final e = pool.where((x) => gradeOf[x] == 'epic').toList(), l = pool.where((x) => gradeOf[x] == 'legend').toList();
        final w0 = s.wish, wish = w0 != null && pool.contains(w0) ? w0 : null;
        final cards = s.cardsW;
        for (final cn in GameCalc.cardChunks(n, 5)) {
          String id;
          if (wish != null && rng.next() < .5) {
            id = wish;
          } else {
            final g = l.isNotEmpty && (e.isEmpty || rng.next() < 1 / 11) ? l : e;
            id = g[(rng.next() * g.length).floor()];
          }
          cards[id] = orNum(cards[id], 0) + cn;
          c.stat('card', cn);
          got.add((id, cn));
        }
        return (got: got, gold: 0);
      }
    }
    if (!GameCalc.cardIds().any(c.cardCan)) return null;
    return c.gainCards(rng, n, 'shop', n >= 10 ? 5 : 1);
  }

  /// 보상 하나 지급 → (저장용 항목, 보여 줄 한 줄)
  (Map<String, dynamic>, AttRow) _attGive(Map r, {bool again = false}) {
    var it = Map<String, dynamic>.from(r);
    final k = r['k'] as String;
    switch (k) {
      case 'gold':
        final h = asNum(r['h']);
        final g = r['g'] != null ? asNum(r['g']) : math.max(100, jsFloor(c.goldRate() * 3600 * h));
        s.gold = s.gold + g;
        it = {'k': 'gold', 'g': g, 'h': r['h']};
        return (it, AttRow('gold', '골드 +${fmt(g)}', '방치 보상 ${h < 1 ? '30분' : '$h시간'}치', again));
      case 'gem':
        s.gem = s.gem + asNum(r['n']);
        return (it, AttRow('gem', '황금 이삭 +${r['n']}', '', again));
      case 'ore':
        s.items['ore'] = orNum(s.items['ore'], 0) + asNum(r['n']);
        return (it, AttRow('ore', '광석 +${r['n']}', '', again));
      case 'seed':
        s.seeds['wheat'] = orNum(s.seeds['wheat'], 0) + 5;
        s.seeds['carrot'] = orNum(s.seeds['carrot'], 0) + 3;
        s.seeds['pumpkin'] = orNum(s.seeds['pumpkin'], 0) + 1;
        return (it, AttRow('seed', '씨앗 묶음', '밀 5 · 은빛 당근 3 · 달빛 호박 1', again));
      case 'tbox':
        tickets['box'] = tkN('box') + asNum(r['n']);
        return (it, AttRow('tbox', '상자 무료 개봉권 +${r['n']}장', '장비 탭 「상자 열기」에서 골드 대신 먼저 써요', again));
      case 'tbox10':
        tickets['box10'] = tkN('box10') + asNum(r['n']);
        return (it, AttRow('tbox10', '상자 10연속 무료권 +${r['n']}장', '영웅 등급 이상 1개 확정', again));
      case 'card':
      case 'ecard':
        final n = asNum(r['n']).toInt();
        final res = _attCards(n, k == 'ecard');
        if (res == null || (res.got.isEmpty && res.gold == 0)) {
          s.gem = s.gem + asNum(r['alt']);
          return (it, AttRow('gem', '황금 이삭 +${r['alt']}', '받을 동료 카드가 없어서 이삭으로 대신 드려요', again));
        }
        final sub = [
          ...res.got.map((g) => '${comps[g.$1]!.n} +${g.$2}'),
          if (res.gold > 0) '별 다 채운 몫 골드 +${fmt(res.gold)}',
        ].join(' · ');
        return (it, AttRow('card', '${k == 'ecard' ? '영웅 이상 동료 카드 ' : '동료 카드 '}$n장', sub, again));
      default: // badge
        final id = 'att_${(attA()['ym'] as String).replaceAll('-', '')}';
        final bd = asMap(s.raw['bdUnl']) ?? (s.raw['bdUnl'] = <String, dynamic>{});
        if (!truthy(bd[id])) {
          bd[id] = 1;
          final nw = asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{});
          nw['b_$id'] = 1;
        }
        return ({'k': 'badge', 'id': id}, AttRow('badge', '${attBadgeName(id)} 배지', '프로필에서 대표 배지로 달 수 있어요', false, id));
    }
  }
}
