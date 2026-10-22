/// 지도 탭 — 웹 #p-mp (영지 지도 그림 drawMap + 랭킹 버튼 + 정보 상자)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../game/controller.dart';
import '../ui/image_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'social_sheets.dart';

const _rNode = ['erdan', 'dusk', 'canyon', 'frost', 'ash', 'capital'];

class MpPage extends StatelessWidget {
  const MpPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc.landCount(), ri = g.calc.rankIdx(), r = GameCalc.region(s.stage);
    final nx = ri + 1 < ranks.length ? ranks[ri + 1] : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 440,
        decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(borderRadius: BorderRadius.circular(11), child: CustomPaint(painter: _MapPainter(g), size: Size.infinite)),
      ),
      const SizedBox(height: 12),
      KdBuy(text: '🏆 랭킹 보기', minWidth: 0, onTap: () => openRanking(g)),
      const SizedBox(height: 12),
      KdBox(children: [
        s.stage > maxLand
            ? const KdSec('왕궁 뜰에서 사냥 중', small: '1부 완결 · 보스 없음')
            : KdSec('${GameCalc.terrName(s.stage)} 탈환 중', small: '${r.n} · ${(s.stage - 1) % 10 + 1}/10'),
        KdKv('되찾은 영지', '$c / $maxLand'),
        KdKv('지금 칭호', '${ranks[ri].n} (원정대 +${ri * 4}%)'),
        KdKv('다음 칭호', nx != null ? '${nx.n}까지 ${nx.at - c}곳' : '모든 칭호를 얻었어요'),
        KdKv('이 지역의 지배자', r.boss),
        const KdNote('영지마다 마족 성주가 지키고, 지역의 마지막 영지에는 군단장이 있어요. 다섯 군단을 모두 몰아내면 왕도 아스테리온이 열리고, 알현실에는 마왕이 기다려요.'),
      ]),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.g) : super(repaint: g.frame);
  final GameController g;

  void _text(Canvas c, String t, double x, double y, double size, Color col, {bool display = false, FontWeight w = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: display ? 'Hahmlet' : 'PlexKR', fontSize: size, fontWeight: w, color: col, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x, y - tp.height * .85));
  }

  double _w(String t, double size, bool display, FontWeight w) => (TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontFamily: display ? 'Hahmlet' : 'PlexKR', fontSize: size, fontWeight: w)),
        textDirection: TextDirection.ltr,
      )..layout())
          .width;

  @override
  void paint(Canvas c, Size size) {
    final mw = size.width, mh = size.height, t = g.sim.time.toDouble();
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A2034));
    final rows = regions.length, cap = ImageStore.get('assets/game/map/capital_${g.state.stage - 1 >= maxLand ? 'open' : 'locked'}.png');
    const top = 10.0;
    // 왕도는 6번째 줄, 성 아이콘은 마지막 칸(알현실) — 아래 여백 없음
    const bottomPad = 8.0;
    final rh = (mh - top - bottomPad) / rows, padX = 22.0, dx = (mw - padX * 2) / 9;
    final cur = g.state.stage - 1, rad0 = math.min(dx * .34, 11.0);
    final pts = <(double, double, int, int)>[
      for (var i = 0; i < rows; i++)
        for (var j = 0; j < 10; j++) (padX + (i.isOdd ? 9 - j : j) * dx, top + i * rh + rh * .64, i, j)
    ];
    // 지역 띠
    for (var i = 0; i < rows; i++) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(4, top + i * rh + 2, mw - 8, rh - 4), const Radius.circular(10)),
        Paint()..color = Color(hexColor(regions[i].hill)).withValues(alpha: .35),
      );
    }
    // 길
    for (var k = 0; k < pts.length - 1; k++) {
      c.drawLine(
        Offset(pts[k].$1, pts[k].$2),
        Offset(pts[k + 1].$1, pts[k + 1].$2),
        Paint()
          ..strokeWidth = 3
          ..color = k < cur ? const Color(0xFF5FAE6B) : const Color(0xFF4A2232),
      );
    }
    // 영지 표
    final captured = ImageStore.get('assets/game/ui/node_captured.png');
    for (var k = 0; k < pts.length; k++) {
      final (x, y, i, j) = pts[k];
      final lord = j == 9, rad = lord ? rad0 * 1.25 : rad0;
      if (k == pts.length - 1) {
        final z = math.min(rh * 1.05, 64.0);
        if (k == cur) {
          c.drawCircle(Offset(x, y - z * .12), z * .42 + math.sin(t * 4) * 2,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = const Color(0xFFFFC94A));
        }
        if (cap != null) {
          drawImg(c, cap, Rect.fromLTWH(x - z / 2, y - z * .7, z, z));
        } else {
          c.drawCircle(Offset(x, y), rad, Paint()..color = cur >= maxLand ? const Color(0xFFFFC94A) : const Color(0xFF6A5A8C));
        }
        continue;
      }
      final rn = i < _rNode.length ? ImageStore.get('assets/game/map/${_rNode[i]}_${lord ? 'boss' : 'enemy'}.png') : null;
      final im = k < cur ? captured : rn;
      final z = math.min(rh * .78, rad * (k == cur ? 2.9 : lord ? 2.5 : 2.4));
      if (k == cur) {
        c.drawCircle(
          Offset(x, y),
          rad + 5 + math.sin(t * 4) * 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0x80FFC94A),
        );
      }
      if (im != null) {
        final bob = k == cur ? (math.sin(t * 3)).abs() * 3 : 0.0;
        drawImg(c, im, Rect.fromLTWH(x - z / 2, y - z * .62 - bob, z, z));
      } else {
        c.drawCircle(Offset(x, y), rad, Paint()..color = k < cur ? const Color(0xFF5FAE6B) : const Color(0xFF4A1F2C));
      }
    }
    // 지역 이름 (웹 regionLabels)
    for (var i = 0; i < rows; i++) {
      final r = regions[i], name = '${r.n}  ';
      final nw = _w(name, 12, true, FontWeight.w700), bw = _w(r.boss, 10, false, FontWeight.w500);
      final lx = mw / 2 - (nw + bw) / 2, ly = top + i * rh + 15;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx - 8, ly - 12, nw + bw + 16, 17), const Radius.circular(8)),
          Paint()..color = const Color(0xB80D1220));
      _text(c, r.n, lx, ly, 12, const Color(0xFFDFE5F2), display: true, w: FontWeight.w700);
      _text(c, r.boss, lx + nw, ly, 10, const Color(0xFF97A2C3));
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
