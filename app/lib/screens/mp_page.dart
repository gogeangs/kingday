/// 지도 탭 — 웹 #p-mp 대륙 지도 「안개 걷힌 에르단」 (docs/content/WORLDMAP.md)
///
/// 위에서부터 탐험 막대 → 다음 목표 → 대륙 지도(점령 판 · 이번 회차에 되찾은 곳만 탈환 판 · 어둠 구름) → 랭킹·도전 버튼.
/// 지역을 누르면 확대 + 아래 창(MapRegionPanel, pages.dart 가 띄움).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/actions.dart';
import '../core/calc.dart';
import '../core/challenge.dart';
import '../core/data.dart';
import '../core/js.dart';
import '../core/worldmap.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/image_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'challenge_sheet.dart';
import 'pass_sheet.dart';
import 'social_sheets.dart';

const _rNode = ['erdan', 'dusk', 'canyon', 'frost', 'ash', 'capital'];
const _dunSpots = ['field', 'vault', 'mine'];

class MpPage extends StatelessWidget {
  const MpPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc, ex = c.mapExplore(), st = c.mapCur(), r = (st - 1) ~/ 10, j = (st - 1) % 10 + 1;
    final reg = regions[r];
    final next = s.stage > maxLand
        ? '🏰 1부 완결 · 왕궁 뜰에서 사냥 중'
        : '다음: ${reg.n} ${r + 1}-$j · ${GameCalc.terrName(st)} · ${j == 10 ? (r == 5 ? '마왕 발타사르' : '군단장 ${reg.boss.split(' ').last}') : '마족 성주'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 탐험 막대
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF241A34), Color(0xFF1A1428)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0xFF4A3A5A)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('대륙 탐험 ${(ex / maxLand * 100).round()}%', style: KdText.display(15, color: const Color(0xFFFFE08A))),
              const SizedBox(height: 4),
              XpBar(ex / maxLand, height: 6, bg: const Color(0x1AFFFFFF)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('이번 회차', style: KdText.body(11.5, color: const Color(0xFFD8D0EE), height: 1.15)),
            Text('${c.landCount()}/$maxLand', style: KdText.body(12, color: const Color(0xFF9BE3A8), weight: FontWeight.w700, height: 1.15)),
          ]),
          const SizedBox(width: 8),
          // 원정 일지 ○/20 (누르면 패스 창, docs/content/SHOP.md 4장)
          if (truthy(s.raw['started']))
            GestureDetector(
              onTap: () => openPass(g),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2A2216), border: Border.all(color: const Color(0xFF6B5420)), borderRadius: BorderRadius.circular(10)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('원정 일지', style: KdText.body(9.5, color: const Color(0xFFD8C89A), height: 1.15)),
                    Text('${g.acts.passLv()}/${GameActions.passSteps}', style: KdText.body(13, color: const Color(0xFFFFE08A), weight: FontWeight.w700, height: 1.15)),
                  ]),
                ),
                if (g.acts.passCanN() > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFFFD34A), shape: BoxShape.circle)),
                  ),
              ]),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => openRanking(g),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2A2216), border: Border.all(color: const Color(0xFF6B5420))),
              child: const Text('🏆', style: TextStyle(fontSize: 18)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // 다음 목표 (누르면 그 지역으로)
      GestureDetector(
        onTap: () {
          if (c.mapEntered(r)) mapZoomTo(g, r, MediaQuery.sizeOf(context).width - 32);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0x0AFFFFFF), border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text(next, style: KdText.body(13, color: const Color(0xFFD8D0EE)))),
            Text('›', style: KdText.body(14, color: KdColors.gold)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      WorldMap(g),
      const SizedBox(height: 10),
      // 랭킹 · 도전 (영지 20 탈환 전에는 잠김, 할 일이 남으면 노란 점)
      Row(children: [
        Expanded(child: KdBuy(text: '🏆 랭킹 보기', minWidth: 0, onTap: () => openRanking(g))),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(clipBehavior: Clip.none, children: [
            SizedBox(
              width: double.infinity,
              child: KdBuy(minWidth: 0, onTap: () => openChallenge(g), costIcon: 'assets/game/ui/icon_challenge.png', text: c.chOpen ? '도전' : '도전 🔒'),
            ),
            if (g.chDot)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFFFFD23A), shape: BoxShape.circle, border: Border.all(color: Colors.white), boxShadow: const [BoxShadow(color: Color(0xFFFFD23A), blurRadius: 6)]),
                ),
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      Text('지역을 누르면 크게 보여요 · 두 번 누르면 전체 지도', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
      if (g.mapZoomR >= 0) SizedBox(height: MediaQuery.sizeOf(context).height * .4),
    ]);
  }
}

/// 지역 확대 (웹 mzOpen): 배율은 점 사이가 화면에서 34px 이상 되게, 지역은 아래 창 위 보이는 부분에
void mapZoomTo(GameController g, int r, double viewW) {
  final z = mapZoomFor(r, viewW), m = mapRegMid(r), sc = viewW / (mapW / z), mh = viewW * 1.5;
  g.mapZoomR = r;
  g.mapGo(m.$1, m.$2 + (mh * .5 - mh * .36) / sc, z);
  g.refresh();
}

void mapZoomOut(GameController g) {
  g.mapZoomR = -1;
  g.mapGo(mapW / 2, mapH / 2, 1);
  g.refresh();
}

/// 보이는 부분 (지도 좌표) — 카메라를 지도 안으로
({double x, double y, double w, double h, double s}) mapView(GameController g, Size size) {
  final vw = mapW / g.camZ, vh = vw * size.height / size.width;
  final x = math.max(0.0, math.min(mapW - vw, g.camX - vw / 2)), y = math.max(0.0, math.min(mapH - vh, g.camY - vh / 2));
  return (x: x, y: y, w: vw, h: vh, s: size.width / vw);
}

class WorldMap extends StatelessWidget {
  const WorldMap(this.g, {super.key});
  final GameController g;

  void _tap(Offset p, Size size) {
    final c = g.calc, v = mapView(g, size), mx = v.x + p.dx / v.s, my = v.y + p.dy / v.s;
    bool hit(String k) {
      final sp = mapSpot[k]!;
      return math.sqrt(math.pow(mx - sp.$1, 2) + math.pow(my - sp.$2, 2)) < math.max(sp.$3, 22 / v.s);
    }

    // 확대 화면: 점 먼저 (누르는 영역 반지름 20px)
    if (g.mapZoomR >= 0) {
      var best = 0;
      var bd = 1e9;
      for (var st = g.mapZoomR * 10 + 1; st <= g.mapZoomR * 10 + 10; st++) {
        final q = mapPts[st - 1], d = math.sqrt(math.pow(mx - q.$1, 2) + math.pow(my - q.$2, 2));
        if (d < bd) {
          bd = d;
          best = st;
        }
      }
      if (best > 0 && bd * v.s <= 20) {
        if (!c.mapSeen(best)) return g.toast('아직 안개에 덮여 있어요');
        final i = (best - 1) ~/ 10 + 1, j = (best - 1) % 10 + 1;
        final st = best == c.mapCur() && g.state.stage <= maxLand
            ? '지금 싸우는 곳'
            : c.mapTaken(best)
                ? '이번 회차에 되찾음 ✓'
                : '마족 점령지';
        return g.toast('$i-$j ${GameCalc.terrName(best)} · $st${best % 10 == 0 ? ' · 군단장' : ''}');
      }
    }
    for (final k in part2Lands.keys) {
      if (hit(k)) {
        g.toast('2부 「흩어진 동맹」에서 열려요');
        Future.delayed(const Duration(milliseconds: 1900), () => g.toast('루미나르: 바다 건너에도 마족에 맞서는 이들이 있다.'));
        return;
      }
    }
    if (hit('village')) return g.setTab(GameTab.vl);
    if (hit('tower')) {
      if (!c.chOpen) return g.toast('영지 $chOpenLand을 되찾으면 열려요');
      openChallenge(g);
      return;
    }
    for (final k in _dunSpots) {
      if (c.chOpen && hit(k)) {
        openChallenge(g);
        return;
      }
    }
    if (hit('capital') && c.mapEntered(5)) return mapZoomTo(g, 5, size.width);
    if (g.mapZoomR >= 0) return mapZoomOut(g);
    var r = -1;
    var bd = 1e9;
    for (var i = 0; i < mapCtr.length; i++) {
      final d = math.sqrt(math.pow(mx - mapCtr[i].$1, 2) + math.pow(my - mapCtr[i].$2, 2));
      if (d < bd) {
        bd = d;
        r = i;
      }
    }
    if (r < 0) return;
    if (!c.mapEntered(r)) return g.toast('아직 안개에 덮여 있어요');
    mapZoomTo(g, r, size.width);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, cs) {
        final w = cs.maxWidth, size = Size(w, w * 1.5);
        return Container(
          height: size.height,
          decoration: BoxDecoration(color: const Color(0xFF1A1028), border: Border.all(color: const Color(0xFF4A3A5A)), borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(children: [
              GestureDetector(
                onTapUp: (d) => _tap(d.localPosition, size),
                onDoubleTap: () => mapZoomOut(g),
                child: CustomPaint(size: size, painter: _WorldPainter(g)),
              ),
              // 확대·한쪽으로 밀린 지도를 한 번에 되돌리기 (두 번 누르기를 모르는 경우, 대표님 제보 10-27)
              if (g.mapZoomR < 0 && g.camTz > 1.01)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    key: const ValueKey('mapAll'),
                    onTap: () => mapZoomOut(g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D1220),
                        border: Border.all(color: KdColors.gold),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('⤢ 전체 보기', style: KdText.body(12, color: KdColors.gold, weight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),
        );
      });
}

/// 캐시: 점령 판 + 되찾은 곳만 탈환 판(땅) / 어둠 구름 층 — 영지를 되찾거나 회차가 바뀔 때만 다시 만듦
class _MapCache {
  static String sig = '';
  static ui.Image? land, fog;
  static List<(double, double, double, double)> embers = [];

  static Paint _soft(double x, double y, double r, BlendMode m) => Paint()
    ..blendMode = m
    ..shader = ui.Gradient.radial(Offset(x, y), r, const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], const [0, .55, 1]);

  static bool ensure(GameController g) {
    final s = g.state, c = g.calc;
    final dark = ImageStore.get('assets/game/map/world_map_dark.jpg'), lit = ImageStore.get('assets/game/map/world_map.jpg');
    final fogs = [for (var i = 1; i <= 6; i++) ImageStore.get('assets/game/map/fog_$i.png')];
    if (dark == null || lit == null || fogs.any((x) => x == null)) return false;
    final key = '${s.best}|${s.stage}|${c.chOpen}';
    if (key == sig && land != null && fog != null) return true;
    sig = key;
    const full = Rect.fromLTWH(0, 0, mapW, mapH);
    // 땅
    {
      final rec = ui.PictureRecorder(), cv = Canvas(rec, full);
      drawImg(cv, dark, full);
      if (s.stage > maxLand) {
        drawImg(cv, lit, full);
      } else {
        cv.saveLayer(full, Paint());
        final v = mapSpot['village']!;
        cv.drawCircle(Offset(v.$1, v.$2), 130, _soft(v.$1, v.$2, 130, BlendMode.srcOver));
        for (var st = 1; st < s.stage; st++) {
          final p = mapPts[st - 1];
          cv.drawCircle(Offset(p.$1, p.$2), landR, _soft(p.$1, p.$2, landR, BlendMode.srcOver));
        }
        for (var r = 0; r < 6; r++) {
          if (s.stage > 10 * (r + 1)) cv.drawCircle(Offset(mapCtr[r].$1, mapCtr[r].$2), 210, _soft(mapCtr[r].$1, mapCtr[r].$2, 210, BlendMode.srcOver));
        }
        cv.drawImageRect(lit, Rect.fromLTWH(0, 0, lit.width.toDouble(), lit.height.toDouble()), full, Paint()..blendMode = BlendMode.srcIn);
        cv.restore();
      }
      land = rec.endRecording().toImageSync(mapW.toInt(), mapH.toInt());
    }
    // 어둠 구름
    {
      final rec = ui.PictureRecorder(), cv = Canvas(rec, full), holes = c.mapHoles();
      embers = [];
      if (holes != null) {
        var seed = 7;
        double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
        cv.saveLayer(full, Paint());
        cv.drawRect(full, Paint()..color = const Color(0xEB1C0E2C));
        for (var y = -120.0; y < mapH + 120; y += 150) {
          for (var x = -160.0; x < mapW + 160; x += 190) {
            final im = fogs[(rnd() * 6).floor()]!, sc = (.85 + rnd() * .4) * 1.05, w = im.width * sc, h = im.height * sc;
            drawImg(cv, im, Rect.fromLTWH(x + (rnd() - .5) * 80 - w / 2 + 95, y + (rnd() - .5) * 60 - h / 2 + 75, w, h));
          }
        }
        for (final (x, y, r) in holes) {
          cv.drawCircle(Offset(x, y), r, _soft(x, y, r, BlendMode.dstOut));
        }
        for (final (x, y, r) in holes) {
          cv.drawCircle(
            Offset(x, y),
            r * 1.15,
            Paint()
              ..blendMode = BlendMode.srcATop
              ..shader = ui.Gradient.radial(Offset(x, y), r * 1.15, const [Color(0x00FFD682), Color(0x00FFD682), Color(0x80FFD682), Color(0x00FFD682)], const [0, .39, .7, 1]),
          );
        }
        cv.restore();
        // 불씨: 구멍과 멀리 떨어진 짙은 어둠에만
        for (var i = 0; i < 400 && embers.length < 70; i++) {
          final x = rnd() * mapW, y = rnd() * mapH;
          if (holes.every((h) => math.sqrt(math.pow(x - h.$1, 2) + math.pow(y - h.$2, 2)) > h.$3 * 1.3)) embers.add((x, y, rnd() * 6.28, 1 + rnd() * 2));
        }
      }
      fog = rec.endRecording().toImageSync(mapW.toInt(), mapH.toInt());
    }
    return true;
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.g) : super(repaint: g.frame);
  final GameController g;

  double _w = 0;

  Size _pill(Canvas c, String t, double x, double y, double fs, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: 'PlexKR', fontSize: fs, fontWeight: FontWeight.w700, color: fg)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + fs * .9, h = fs * 1.5;
    // 지도 끝에서 이름표가 잘리지 않게 안쪽으로 (웹 wmPill · UI 점검 10-27 11번)
    if (_w > w + 6) x = x.clamp(w / 2 + 3, _w - w / 2 - 3).toDouble();
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: h), Radius.circular(h / 2)), Paint()..color = bg);
    tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2 + .5));
    return Size(w, h);
  }

  /// 작은 깃발 (흰 테두리)
  void _flag(Canvas c, double x, double y, double k, Color col) {
    final pole = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(Offset(x, y), Offset(x, y - 11 * k), pole
      ..color = Colors.white
      ..strokeWidth = 1.6 * k + 2);
    c.drawLine(Offset(x, y), Offset(x, y - 11 * k), pole
      ..color = const Color(0xFF5A3B22)
      ..strokeWidth = 1.6 * k);
    final path = Path()
      ..moveTo(x, y - 11 * k)
      ..lineTo(x + 8 * k, y - 8.3 * k)
      ..lineTo(x, y - 5.6 * k)
      ..close();
    c.drawPath(path, Paint()..color = col);
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white);
  }

  @override
  void paint(Canvas c, Size size) {
    _w = size.width;
    final s = g.state, cc = g.calc, t = g.sim.time.toDouble(), now = DateTime.now().millisecondsSinceEpoch;
    // 카메라를 목표로 부드럽게
    g.camX += (g.camTx - g.camX) * .19;
    g.camY += (g.camTy - g.camY) * .19;
    g.camZ += (g.camTz - g.camZ) * .19;
    if (!_MapCache.ensure(g)) {
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A1028));
      _pill(c, '지도를 펼치는 중…', size.width / 2, size.height / 2, 13, const Color(0x00000000), const Color(0xFFC9B8E8));
      return;
    }
    final v = mapView(g, size), sc = v.s, zoom = g.mapZoomR >= 0;
    Offset toS(double x, double y) => Offset((x - v.x) * sc, (y - v.y) * sc);
    final src = Rect.fromLTWH(v.x, v.y, v.w, v.h), dst = Offset.zero & size;
    c.drawImageRect(_MapCache.land!, src, dst, Paint()..filterQuality = FilterQuality.medium);
    // 2부 땅: 옅은 회색 바다 안개 (왕도를 깨면 조금 더 또렷)
    final clr = cc.mapAllClear();
    for (final k in part2Lands.keys) {
      final sp = mapSpot[k]!, p = toS(sp.$1, sp.$2), r = sp.$3 * 1.7 * sc;
      c.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p, r, [Color.fromRGBO(225, 230, 240, clr ? .42 : .62), const Color.fromRGBO(225, 230, 240, 0)]));
    }
    // 영지 점 · 군단장 · 왕도
    final fs = math.max(9.5, math.min(12.0, size.width * .028)).roundToDouble();
    for (var st = 1; st <= maxLand; st++) {
      if (!cc.mapSeen(st)) continue;
      final q = mapPts[st - 1], p = toS(q.$1, q.$2), taken = cc.mapTaken(st), r = (st - 1) ~/ 10, k = math.max(1.1, math.min(1.7, sc * 1.3));
      if (st == maxLand) {
        final z = math.max(44.0, 56 * sc), im = ImageStore.get('assets/game/map/capital_${s.stage > maxLand ? 'open' : 'locked'}.png');
        if (im != null) drawImg(c, im, Rect.fromLTWH(p.dx - z / 2, p.dy - z * .75, z, z));
        if (s.stage > maxLand) _pill(c, '왕궁 뜰', p.dx, p.dy + fs * 1.3, fs - 1, const Color(0xEBFFC94A), const Color(0xFF3A2A00));
      } else if (st % 10 == 0) {
        final z = math.max(30.0, 40 * sc), im = ImageStore.get('assets/game/map/${_rNode[r]}_boss.png');
        if (im != null) drawImg(c, im, Rect.fromLTWH(p.dx - z / 2, p.dy - z * .72, z, z));
        if (taken) _flag(c, p.dx + z * .28, p.dy - z * .35, k, const Color(0xFF3FBF5A));
      } else {
        _flag(c, p.dx, p.dy, k, taken ? const Color(0xFF3FBF5A) : const Color(0xFFD23A3A));
      }
      if (zoom && r == g.mapZoomR) _pill(c, GameCalc.terrName(st), p.dx, p.dy + fs * 1.25, fs - 1, const Color(0xB80A0812), Colors.white);
    }
    // 어둠 구름 + 불씨
    c.drawImageRect(_MapCache.fog!, src, dst, Paint()..filterQuality = FilterQuality.medium);
    for (final (x, y, ph, sz) in _MapCache.embers) {
      final p = toS(x, y), al = .35 + .45 * math.max(0.0, math.sin(t * 1.7 + ph));
      c.drawCircle(p, sz * math.min(1.6, sc), Paint()..color = Color.fromRGBO(255, 80 + (60 * al).floor(), 60, al));
    }
    // 명소: 시련의 탑(잠김 🔒) · 요일 던전(오늘 반짝)
    final tw = mapSpot['tower']!, tp = toS(tw.$1, tw.$2);
    if (!cc.chOpen) {
      _pill(c, '🔒 시련의 탑', tp.dx, tp.dy - 6, fs - 1, const Color(0xB30A0812), const Color(0xFFD8D0EE));
    } else {
      final open = cc.dunOpenK();
      for (final k in _dunSpots) {
        final sp = mapSpot[k]!, p = toS(sp.$1, sp.$2), on = open.contains(k), name = duns.firstWhere((d) => d.k == k).n;
        if (on) {
          final pr = (14 + math.sin(t * 4) * 3) * math.max(1.0, sc);
          c.drawCircle(
              p,
              pr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = Color.fromRGBO(255, 224, 138, .55 + .3 * math.sin(t * 4)));
          for (var i = 0; i < 4; i++) {
            final an = t * 1.5 + i * 1.57;
            c.drawCircle(p + Offset(math.cos(an), math.sin(an)) * (pr + 6), 1.6, Paint()..color = const Color(0xE6FFF0AA));
          }
        }
        _pill(c, '${on ? '오늘 · ' : ''}$name', p.dx, p.dy + 18 * math.max(1.0, sc), fs - 1.5, on ? const Color(0xF2FFC94A) : const Color(0x9914101E),
            on ? const Color(0xFF3A2A00) : const Color(0xBFDCDCEB));
      }
    }
    // 카엘 (지금 위치): 초상화 원 + 금빛 고리, 통통 튐
    {
      final q = mapPts[cc.mapCur() - 1], p = toS(q.$1, q.$2), rr = math.max(13.0, 17 * math.min(1.5, sc)).toDouble(), by = p.dy - rr - 6 - (math.sin(t * 3)).abs() * 3, ctr = Offset(p.dx, by);
      c.drawOval(Rect.fromCenter(center: p, width: rr * 1.6, height: rr * .56), Paint()..color = const Color(0x66000000));
      c.drawCircle(ctr, rr * 2.1, Paint()..shader = ui.Gradient.radial(ctr, rr * 2.1, const [Color(0x8CFFD66E), Color(0x00FFD66E)], const [.28, 1]));
      c.drawCircle(ctr, rr, Paint()..color = const Color(0xFF2A2216));
      final im = ImageStore.get('assets/game/portraits/portrait_kael_idle.png');
      if (im != null) {
        c.save();
        c.clipPath(Path()..addOval(Rect.fromCircle(center: ctr, radius: rr)));
        drawImg(c, im, Rect.fromLTWH(p.dx - rr * 1.15, by - rr * 1.05, rr * 2.3, rr * 2.3));
        c.restore();
      }
      c.drawCircle(
          ctr,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFC94A));
      c.drawCircle(
          ctr,
          rr + 4 + math.sin(t * 4) * 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Color.fromRGBO(255, 201, 74, .4 + .3 * math.sin(t * 4)));
    }
    // 지역 이름 (전체 지도)
    if (!zoom) {
      for (var r = 0; r < 6; r++) {
        final p = toS(mapCtr[r].$1, mapCtr[r].$2 - (r == 0 ? 150 : r == 5 ? 60 : 110));
        _pill(c, cc.mapEntered(r) ? regions[r].n : '???', p.dx, p.dy, fs, const Color(0x9908060E), Colors.white);
      }
    }
    // 연출: 걷힘(금빛 번쩍 + 흩어지는 구름) · 되찾음(밝은 땅 번짐)
    g.mapAnims.removeWhere((a) => now >= a.t0 + a.d);
    for (final an in g.mapAnims) {
      final tt = (now - an.t0) / an.d;
      if (tt < 0) continue;
      final p = toS(an.x, an.y), big = an.k == 'reg', rr = (big ? 260 : an.k == 'cap' ? landR : fogR) * sc * (.3 + tt * .9), al = math.max(0.0, 1 - tt);
      c.drawCircle(
          p,
          rr,
          Paint()
            ..shader = ui.Gradient.radial(p, rr, [
              an.k == 'cap' ? Color.fromRGBO(170, 255, 170, .55 * al) : Color.fromRGBO(255, 230, 150, .75 * al),
              const Color(0x00FFE696),
            ]));
      if (an.k != 'cap') {
        for (var i = 0; i < (big ? 14 : 7); i++) {
          final ang = i * 2.4 + an.x, d = rr * (.6 + tt * .8);
          c.drawCircle(p + Offset(math.cos(ang), math.sin(ang)) * d, (big ? 9 : 5) * (1 - tt) * math.max(1.0, sc), Paint()..color = Color.fromRGBO(40, 18, 60, .75 * al));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) => true;
}

/// 지역 확대 아래 창 (웹 #p-mz): 군단장 · 이번 회차 진행 · 영지 10곳 · 지역 소개
class MapRegionPanel extends StatelessWidget {
  const MapRegionPanel(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final r = g.mapZoomR, c = g.calc, reg = regions[r], bid = r < 5 ? bossIds[r] : 'baltasar';
    final got = [for (var j = 1; j <= 10; j++) c.mapTaken(r * 10 + j)].where((x) => x).length;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [KdColors.pageTop, KdColors.bg], stops: [0, .3], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: KdColors.brass, width: 2)),
        boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, -10))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xB337436A)))),
          child: Row(children: [
            Expanded(child: Text(reg.n, style: KdText.display(19))),
            GestureDetector(onTap: () => mapZoomOut(g), child: SizedBox(width: 36, height: 36, child: uiImg('btn_close', size: 36))),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
            Row(children: [
              ClipOval(child: Container(width: 54, height: 54, color: const Color(0xFF2A2216), child: FaceImg(bid))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(reg.boss, style: KdText.display(15)),
                  Text('되찾은 영지 $got/10 (이번 회차)', style: KdText.body(12, color: KdColors.muted)),
                  const SizedBox(height: 3),
                  XpBar(got / 10),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            for (var j = 1; j <= 10; j++)
              () {
                final st = r * 10 + j, seen = c.mapSeen(st), tk = c.mapTaken(st), cur = st == c.mapCur() && g.state.stage <= maxLand;
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: cur ? const Color(0x24FFC94A) : const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    SizedBox(width: 36, child: Text('${r + 1}-$j', style: KdText.figure(13, color: KdColors.muted, weight: FontWeight.w400))),
                    Expanded(child: Text(seen ? GameCalc.terrName(st) : '???', maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(13))),
                    Text(j == 10 ? '군단장' : '성주', style: KdText.body(11, color: KdColors.muted)),
                    SizedBox(
                      width: 52,
                      child: Text(cur ? '⚔ 지금' : tk ? '✓' : seen ? '' : '🌫',
                          textAlign: TextAlign.right, style: KdText.body(13, weight: FontWeight.w700, color: cur ? KdColors.gold : const Color(0xFF9BE3A8))),
                    ),
                  ]),
                );
              }(),
            const SizedBox(height: 8),
            for (final p in reg.lore) Para(p),
            const SizedBox(height: 8),
            KdBuy(text: '전체 지도', kind: BuyKind.ghost, minWidth: 0, onTap: () => mapZoomOut(g)),
          ]),
        ),
      ]),
    );
  }
}
