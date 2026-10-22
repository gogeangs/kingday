/// 프로필 꾸미기 — 테두리·배지 (웹 PFRAMES · BADGES · pfCheck)
library;

import 'attendance.dart';
import 'calc.dart';
import 'data.dart';
import 'js.dart';

class Deco {
  const Deco(this.k, this.n, this.d, this.ok, {this.rare = false, this.rk = false, this.tall = false});
  final String k, n, d;

  /// 얻는 조건
  final bool Function(GameCalc c) ok;

  /// 황금 고블린 희귀 전리품 / 랭킹 보상 / 위로 솟은 큰 테두리
  final bool rare, rk, tall;
}

num _st(GameCalc c, String k) => orNum(asMap(c.s.raw['stat'])?[k], 0);
bool _no(GameCalc c) => false;

final List<Deco> pframes = [
  Deco('wood', '나무 울타리', '처음부터', (c) => true),
  Deco('straw', '밀짚 화환', '칭호 마을 지킴이', (c) => c.rankIdx() >= 1),
  Deco('harvest', '풍년 수확', '밭 Lv.5', (c) => orNum(c.s.bld['farm'], 0) >= 5),
  Deco('silver', '은빛 기사', '칭호 기사', (c) => c.rankIdx() >= 2),
  Deco('gold', '황금 영주', '칭호 영주', (c) => c.rankIdx() >= 3),
  Deco('amethyst', '자수정 장식', '전설 성유물 착용', (c) => c.s.eq.values.any((it) => it is Map && asNum(it['g']) >= 4)),
  Deco('holy', '성검의 가호', '첫 은퇴', (c) => c.s.retires >= 1),
  Deco('royal', '붉은 왕관', '칭호 공작', (c) => c.rankIdx() >= 5),
  const Deco('goblin', '황금 고블린', '황금 고블린 희귀 전리품', _no, rare: true, tall: true),
  const Deco('season', '시즌 왕관', '시즌 랭킹 1위 보상', _no, rk: true, tall: true),
  const Deco('conquer', '정복자', '영지 50곳 탈환 · 명예의 전당 보상', _no, rk: true, tall: true),
  Deco('capital', '왕도의 별', '마왕 발타사르 처치 (1부 완결)', (c) => orNum(c.s.raw['capClears'], 0) >= 1, tall: true),
  Deco('tower', '시련의 탑', '시련의 탑 50층', (c) => _top(c) >= 50, tall: true),
  Deco('retire', '은퇴의 정원', '은퇴 10번', (c) => c.s.retires >= 10, tall: true),
];

/// 시련의 탑 최고 층 (S.tower.top)
num _top(GameCalc c) => orNum(asMap(c.s.raw['tower'])?['top'], 0);

final List<Deco> badges = [
  Deco('pumpkin', '첫 달빛 호박', '달빛 호박 수확', (c) => _st(c, 'pump') >= 1),
  Deco('basket', '풍년 농부', '작물 100개 수확', (c) => _st(c, 'harv') >= 100),
  Deco('stew', '마고의 단골', '요리 10번', (c) => _st(c, 'cook') >= 10),
  Deco('rebuild', '마을 재건', '건물 6채 모두 재건', (c) => c.s.bld.values.where((l) => asNum(l) > 0).length >= 6),
  Deco('chest', '상자 사냥꾼', '성유물 상자 Lv.10', (c) => c.s.boxLv >= 10),
  Deco('horns', '군단장 사냥꾼', '군단장 처치', (c) => (asMap(c.s.raw['gemLord'])?.length ?? 0) >= 1),
  Deco('retire', '은퇴 전문가', '은퇴 3번', (c) => c.s.retires >= 3),
  Deco('retire5', '노련한 은퇴자', '은퇴 5번', (c) => c.s.retires >= 5),
  Deco('retire20', '전설의 은퇴자', '은퇴 20번', (c) => c.s.retires >= 20),
  // 왕도가 생겨도 50곳 기준 그대로
  Deco('king', '농부 왕', '영지 50곳 모두 탈환', (c) => c.s.best > 50),
  Deco('part1', '1부 완결', '마왕 발타사르 처치', (c) => orNum(c.s.raw['capClears'], 0) >= 1),
  Deco('tower25', '탑 25층', '시련의 탑 25층', (c) => _top(c) >= 25),
  Deco('tower100', '탑의 주인', '시련의 탑 100층', (c) => _top(c) >= 100),
  Deco('primal', '태초의 손길', '태초 장비 착용', (c) => c.s.eq.values.any((it) => it is Map && asNum(it['g']) >= 6)),
  const Deco('goblin', '고블린 사냥꾼', '황금 고블린 희귀 전리품', _no, rare: true),
  const Deco('champ', '시즌 챔피언', '시즌 랭킹 1위 보상', _no, rk: true),
  const Deco('top10', '시즌 10강', '시즌 랭킹 2~10위 보상', _no, rk: true),
  const Deco('crown1', '전당의 금관', '명예의 전당 1위 보상', _no, rk: true),
  const Deco('crown2', '전당의 은관', '명예의 전당 2위 보상', _no, rk: true),
  const Deco('crown3', '전당의 동관', '명예의 전당 3위 보상', _no, rk: true),
];

Deco? frameOf(String k) => pframes.where((f) => f.k == k).firstOrNull;
Deco? badgeOf(String k) => badges.where((b) => b.k == k).firstOrNull;
String frameName(String k) => frameOf(k)?.n ?? k;
String badgeName(String k) => isAttBadge(k) ? attBadgeName(k) : badgeOf(k)?.n ?? k;

/// 출석 배지 att_YYYYMM (그달 28회 출석)
bool isAttBadge(String k) => RegExp(r'^att_\d{6}$').hasMatch(k);

/// 배지 그림 경로 (출석 배지는 월별 그림 → 공용 그림)
String badgeAsset(String k) => isAttBadge(k) ? attBadgeAsset(k) : 'assets/game/profile/badge_$k.png';
bool isTallFrame(String k) => frameOf(k)?.tall ?? false;

extension ProfileCalc on GameCalc {
  /// 웹 pubFace(): 다른 영주에게 보이는 얼굴 (카엘 또는 합류한 동료)
  String pubFace() {
    final f = s.raw['face'];
    return f is String && comps.containsKey(f) && owned(f) ? f : 'kael';
  }

  bool bdHas(String k) => truthy(asMap(s.raw['bdUnl'])?[k]);
  bool pfHas(String k) => k == 'wood' || truthy(asMap(s.raw['pfUnl'])?[k]);

  /// 끼운 테두리 (없으면 나무 울타리)
  String curFrame() => s.raw['pf'] is String ? s.raw['pf'] as String : 'wood';

  /// 단 배지 (얻은 것만)
  String? curBadge() {
    final b = s.raw['badge'];
    return b is String && bdHas(b) ? b : null;
  }

  /// 웹 pfCheck(): 조건을 채운 테두리·배지를 열고 NEW 표시
  void pfCheck() {
    final pf = asMap(s.raw['pfUnl']) ?? (s.raw['pfUnl'] = <String, dynamic>{});
    final bd = asMap(s.raw['bdUnl']) ?? (s.raw['bdUnl'] = <String, dynamic>{});
    final started = truthy(s.raw['started']);
    Map<String, dynamic> nw() => asMap(s.raw['pfNew']) ?? (s.raw['pfNew'] = <String, dynamic>{});
    for (final f in pframes) {
      if (!truthy(pf[f.k]) && f.ok(this)) {
        pf[f.k] = 1;
        if (f.k != 'wood' && started) nw()['f_${f.k}'] = 1;
      }
    }
    for (final b in badges) {
      if (!truthy(bd[b.k]) && b.ok(this)) {
        bd[b.k] = 1;
        if (started) nw()['b_${b.k}'] = 1;
      }
    }
  }

  /// 얻은 출석 배지 (오래된 달부터)
  List<Deco> attBadges() {
    final ks = (asMap(s.raw['bdUnl'])?.keys ?? const <String>[]).where(isAttBadge).toList()..sort();
    return [for (final k in ks) Deco(k, attBadgeName(k), '그달 28회 출석', _no, rare: true)];
  }

  /// 얼굴 위 표시: 처음엔 「꾸미기」, 그 뒤엔 새로 얻은 게 있으면 빨간 점
  bool pfNewbie() => !truthy(s.raw['pfSeen']);
  bool pfDot() => !pfNewbie() && (asMap(s.raw['pfNew'])?.isNotEmpty ?? false);
}
