/// 대륙 지도 「안개 걷힌 에르단」 (docs/content/WORLDMAP.md)
///
/// 웹 index.html 「대륙 지도」 구역(MAPPOS·mapSeen·mapTaken·wmHoles …)과 같은 좌표·같은 규칙.
/// 저장 필드: mapIntro(처음 대사), fogSeen(걷힘 연출을 보여 준 영지), regSeen(지역 전체 걷힘 연출 본 지역).
/// 2부 「바다 건너」 지도(영지 61~, 웹 SEAPOS·seaHoles·wm*)도 여기. 지도를 고르는 값(sea)은 GameController.mapSea.
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

/// 지역 확대 중심 6곳 (에르단)
final List<(double, double)> mapCtr = [
  for (final p in wMappos['ctr'] as List) (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())
];

/// 지역 전체 안개가 처음 걷힐 때 (토스트, 루미나르 한 줄)
final List<(String, String)?> regFogLines = [for (final x in wRegFog) x == null ? null : (x[0], x[1])];
final Map<String, String> part2Lands = wP2;

(double, double) _xy(Object? p) => (((p as List)[0] as num).toDouble(), (p[1] as num).toDouble());

// ── 바다 건너 지도 (2부, PART2.md 4장 · 웹 SEAPOS) ──
// 지도 두 장: 「에르단」(영지 1~60, MAPPOS) · 「바다 건너」(61~, SEAPOS). sea = 지금 보는 지도(웹 wmSea).
// 그림 assets/map/sea_map(_dark).jpg (1024×1536, 대륙 지도와 같은 규격). 왼쪽 섬 = 엘프 왕국, 오른쪽 = 사막 제국, 위 = 북방 부족

/// 바다 건너 영지 61~90 (지도 그림 픽셀)
final List<(double, double)> seaPts = [for (final p in wSeapos['pts'] as List) _xy(p)];

/// 보스 없이 사냥하는 자리(land+1): 1차 바다 안개(엘프 섬 앞바다) · 2부 완결 연합군 진영(에르단 항구 앞)
final (double, double) seaFogPt = _xy(wSeapos['fog']);
final (double, double) seaCampPt = _xy(wSeapos['camp']);

/// 뱃길: at = 이 영지를 가 보면 걷힘
final List<({int at, List<(double, double)> pts})> seaRoute = [
  for (final r in wSeapos['route'] as List) (at: ((r as Map)['at'] as num).toInt(), pts: [for (final q in r['pts'] as List) _xy(q)])
];

/// 바다 건너 명소: port(에르단 항구) · desert · north — 가운데 x,y · 누르는 반지름
final Map<String, (double, double, double)> seaSpot = {
  for (final e in (wSeapos['spot'] as Map).entries)
    e.key as String: (((e.value as List)[0] as num).toDouble(), ((e.value as List)[1] as num).toDouble(), ((e.value as List)[2] as num).toDouble())
};

/// 지역 가운데 (regions 6번부터)
final List<(double, double)> seaCtr = [for (final p in wSeapos['ctr'] as List) _xy(p)];

/// 나라 전체 안개가 처음 걷힐 때 (웹 SEA_FOG: 토스트, 루미나르 한 줄)
final Map<int, (String, String)> seaFogLines = {
  for (final e in wSeaFog.entries) int.parse(e.key): (e.value[0], e.value[1])
};

/// 사냥터 자리 (웹 seaHunt)
(double, double) seaHunt() => land >= p2Last ? seaCampPt : seaFogPt;

/// 지금 지도 기준: 첫 영지 · 마지막 영지 · 지역 번호 범위 · 영지 좌표 · 지역 가운데 (웹 wmSt0·wmStN·wmR0·wmRN·wmOn·wmPt·wmCtr)
int wmSt0(bool sea) => sea ? maxLand + 1 : 1;
int wmStN(bool sea) => sea ? land : maxLand;
int wmR0(bool sea) => sea ? seaR0 : 0;
int wmRN(bool sea) => sea ? regions.length : seaR0;
bool wmOn(bool sea, int st) => st >= wmSt0(sea) && st <= wmStN(sea);
(double, double) wmPt(bool sea, int st) => sea ? (st > land ? seaHunt() : seaPts[st - maxLand - 1]) : mapPts[st - 1];
(double, double) wmCtr(int r) => r >= seaR0 ? seaCtr[r - seaR0] : mapCtr[r];

/// 지역 r의 j번째(0~9) 영지 좌표 (어느 지도든, 웹 wmRegPt)
(double, double) wmRegPt(int r, int j) => r >= seaR0 ? seaPts[(r - seaR0) * 10 + j] : mapPts[r * 10 + j];

/// 확대 화면 점 사이 최소 거리(지도 좌표, 지역마다 · 웹 wmDmin)
final List<double> mapDmin = [
  for (var r = 0; r < regions.length; r++)
    () {
      var mn = 1e9;
      for (var a = 0; a < 10; a++) {
        for (var b = a + 1; b < 10; b++) {
          final p = wmRegPt(r, a), q = wmRegPt(r, b);
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
    final p = wmRegPt(r, j);
    x += p.$1;
    y += p.$2;
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
  bool mapSeen(int st) => st <= s.best + 1 || (st <= maxLand && mapAllClear()) || mapRegCleared((st - 1) ~/ 10);

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

  /// 바다 탐험: 61~land 중 안개 걷힌 영지 수 (웹 seaExplore)
  int seaExplore() {
    var n = 0;
    for (var st = maxLand + 1; st <= land; st++) {
      if (mapSeen(st) && st <= math.max(s.best, 0)) n++;
    }
    return n;
  }

  /// 카엘 자리: 에르단 지도에서는 1~60(2부에 가 있으면 알현실), 바다 건너에서는 61~(사냥터면 그 자리) (웹 wmCur)
  int mapCur([bool sea = false]) => sea ? math.max(maxLand + 1, math.min(land + 1, s.stage)) : math.max(1, math.min(maxLand, s.stage));

  /// 바다 건너: 에르단 항구 · 가 본 영지 + 다음 1곳 · 해방한(장수를 처음 쓰러뜨린) 나라 · 사냥터 자리 (웹 seaHoles)
  List<(double, double, double)> seaHoles() {
    final port = seaSpot['port']!, h = <(double, double, double)>[(port.$1, port.$2, 170)];
    for (final r in seaRoute) {
      if (s.best + 1 >= r.at) {
        for (final q in r.pts) {
          h.add((q.$1, q.$2, 75));
        }
      }
    }
    for (var st = maxLand + 1; st <= math.min(land, s.best + 1); st++) {
      final p = wmPt(true, st);
      h.add((p.$1, p.$2, fogR));
    }
    for (var r = seaR0; r < regions.length; r++) {
      if (!mapRegCleared(r)) continue;
      for (var j = 0; j < 10; j++) {
        final p = seaPts[(r - seaR0) * 10 + j];
        h.add((p.$1, p.$2, 130));
      }
      final ct = wmCtr(r);
      h.add((ct.$1, ct.$2, 230));
    }
    if (s.best > land) {
      final hp = seaHunt();
      h.add((hp.$1, hp.$2, 90));
    }
    return h;
  }

  /// 어둠을 지울 원 [x, y, 반지름]. 에르단 전체가 걷혔으면 null (웹 wmHoles)
  List<(double, double, double)>? mapHoles([bool sea = false]) {
    if (sea) return seaHoles();
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
