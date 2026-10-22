/// 대륙 지도 「안개 걷힌 에르단」 (docs/content/WORLDMAP.md)
///
/// 웹 index.html 「대륙 지도」 구역(MAPPOS·mapSeen·mapTaken·wmHoles …)과 같은 좌표·같은 규칙.
/// 저장 필드: mapIntro(처음 대사), fogSeen(걷힘 연출을 보여 준 영지), regSeen(지역 전체 걷힘 연출 본 지역).
library;

import 'dart:math' as math;

import 'calc.dart';
import 'data.dart';
import 'js.dart';
import 'web_data.g.dart';

const double mapW = 1024, mapH = 1536, fogR = 82, landR = 80;

/// 영지 60곳 (지도 그림 픽셀)
final List<(double, double)> mapPts = [
  for (final p in wMappos['pts'] as List) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())
];

/// 명소 9곳: 가운데 x,y · 누르는 반지름
final Map<String, (double, double, double)> mapSpot = {
  for (final e in (wMappos['spot'] as Map).entries)
    e.key as String: (((e.value as List)[0] as num).toDouble(), ((e.value as List)[1] as num).toDouble(), ((e.value as List)[2] as num).toDouble())
};

/// 지역 확대 중심 6곳
final List<(double, double)> mapCtr = [
  for (final p in wMappos['ctr'] as List) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())
];

/// 지역 전체 안개가 처음 걷힐 때 (토스트, 루미나르 한 줄)
final List<(String, String)?> regFogLines = [for (final x in wRegFog) x == null ? null : (x[0], x[1])];
final Map<String, String> part2Lands = wP2;

/// 확대 화면 점 사이 최소 거리(지도 좌표, 지역마다)
final List<double> mapDmin = [
  for (var r = 0; r < 6; r++)
    () {
      var mn = 1e9;
      for (var a = 0; a < 10; a++) {
        for (var b = a + 1; b < 10; b++) {
          final p = mapPts[r * 10 + a], q = mapPts[r * 10 + b];
          mn = math.min(mn, math.sqrt(math.pow(p.$1 - q.$1, 2) + math.pow(p.$2 - q.$2, 2)));
        }
      }
      return mn;
    }()
];

/// 지역 확대 배율: 기본 1.8배, 점이 가까운 지역은 화면에서 점 사이가 34px 이상 되게 (웹 wmZoomFor)
double mapZoomFor(int r, double viewW) => math.max(1.8, math.min(3.0, 34 * mapW / (math.max(1.0, viewW) * mapDmin[r])));

/// 지역 점들의 가운데 (웹 wmRegMid)
(double, double) mapRegMid(int r) {
  var x = 0.0, y = 0.0;
  for (var j = 0; j < 10; j++) {
    x += mapPts[r * 10 + j].$1;
    y += mapPts[r * 10 + j].$2;
  }
  return (x / 10, y / 10);
}

extension WorldMapCalc on GameCalc {
  /// 그 지역 군단장을 처음 쓰러뜨림 → 지역 전체 안개 걷힘
  bool mapRegCleared(int r) => s.best > 10 * (r + 1);

  /// 왕도(60)를 깸 → 에르단 전체
  bool mapAllClear() => s.best > maxLand;
  bool mapEntered(int r) => s.best >= 10 * r + 1;

  /// 안개 밖 영지 (가 본 곳 + 다음 1곳)
  bool mapSeen(int st) => st <= s.best + 1 || mapAllClear() || mapRegCleared((st - 1) ~/ 10);

  /// 이번 회차에 되찾음 (지름길 시작 앞 영지 포함)
  bool mapTaken(int st) => st < s.stage;

  /// 대륙 탐험: 안개 걷힌 영지 수
  int mapExplore() {
    if (mapAllClear()) return maxLand;
    var n = 0;
    for (var st = 1; st <= maxLand; st++) {
      if (mapSeen(st) && st <= math.max(s.best, 0)) n++;
    }
    return math.min(maxLand, n);
  }

  /// 지금 위치 (61 왕궁 뜰은 60 자리)
  int mapCur() => math.max(1, math.min(maxLand, s.stage));

  /// 어둠을 지울 원 [x, y, 반지름]. 에르단 전체가 걷혔으면 null (웹 wmHoles)
  List<(double, double, double)>? mapHoles() {
    final sp = mapSpot, h = <(double, double, double)>[(sp['village']!.$1, sp['village']!.$2, 150)];
    if (mapAllClear()) return null;
    for (var st = 1; st <= math.min(maxLand, s.best + 1); st++) {
      h.add((mapPts[st - 1].$1, mapPts[st - 1].$2, fogR));
    }
    for (var r = 0; r < 6; r++) {
      if (!mapRegCleared(r)) continue;
      for (var j = 0; j < 10; j++) {
        h.add((mapPts[r * 10 + j].$1, mapPts[r * 10 + j].$2, 130));
      }
      h.add((mapCtr[r].$1, mapCtr[r].$2, 230));
    }
    if (truthy(s.raw['chOpen'])) {
      h.add((sp['tower']!.$1, sp['tower']!.$2 - 30, 95));
      for (final k in const ['field', 'vault', 'mine']) {
        h.add((sp[k]!.$1, sp[k]!.$2, 58));
      }
    }
    return h;
  }

  /// 처음 대사를 아직 안 봤는지
  bool get mapIntroDue => !truthy(s.raw['mapIntro']);
  int get fogSeen => orNum(s.raw['fogSeen'], 1).toInt();
  Map<String, dynamic> get regSeen {
    final r = s.raw['regSeen'];
    if (r is Map<String, dynamic>) return r;
    if (r is Map) return s.raw['regSeen'] = r.cast<String, dynamic>();
    return s.raw['regSeen'] = <String, dynamic>{};
  }
}
