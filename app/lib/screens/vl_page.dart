/// 마을 탭 — 웹 #p-vl (마을 Lv 막대 · 할 일 줄 · 지도 한 장 · 일꾼 버튼) + #p-vb (아래 건물 창)
///
/// 2026-10-23 마을 확장 (docs/content/VILLAGE.md 4장): 가로 밀기를 없애고 지도 한 장 위에 건물 10채.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../battle/battle_data.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/village.dart';
import '../core/web_data.g.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/game_widgets.dart';
import '../ui/image_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'eq_page.dart';

// ════════════════════ 지도 좌표 (웹 VPOS · VBB · WSPOT) ════════════════════
const double _mapW = 1024;

/// 지도 좌표: 건물 그림 가운데 x · 바닥 y · 그림 폭 · 좌우 뒤집기
({double x, double y, double w, bool flip}) vPos(String k) {
  final p = wVpos[k] as List;
  return (x: (p[0] as num).toDouble(), y: (p[1] as num).toDouble(), w: (p[2] as num).toDouble(), flip: p.length > 3 && p[3] == 1);
}

/// 그림(512칸) 안 실제 그림 범위 [왼쪽, 오른쪽, 위]
List<double> _vbb(String k, String t) {
  final m = (wVbb[t] as Map)[k] ?? (t == 'ruin' ? const [10, 502, 65] : (wVbb['built'] as Map)[k]);
  return [for (final x in m as List) (x as num).toDouble()];
}

/// 위(먼) 건물부터 그리기
final List<String> vOrder = (wVpos.keys.toList()..sort((a, b) => vPos(a).y.compareTo(vPos(b).y)));

/// 건물의 실제 그림 사각형(지도 좌표) — 그리기·누르기 공통 (웹 vRect)
({double x0, double x1, double y0, double y1, double cx, double cy}) vRect(String k) {
  final p = vPos(k), bb = _vbb(k, 'built'), sc = p.w / (bb[1] - bb[0]), h = (506 - bb[2]) * sc;
  return (x0: p.x - p.w / 2, x1: p.x + p.w / 2, y0: p.y - h, y1: p.y, cx: p.x, cy: p.y - h * .45);
}

/// 누르는 영역: 조금 줄인 그림 사각형, 겹치는 곳은 가운데가 더 가까운 건물 (웹 vHit)
String? vHit(double mx, double my) {
  String? best;
  var bd = 1e9;
  for (final k in vOrder) {
    final r = vRect(k), w = r.x1 - r.x0, h = r.y1 - r.y0;
    if (mx < r.x0 + w * .08 || mx > r.x1 - w * .08 || my < r.y0 + h * .12 || my > r.y1) continue;
    final d = math.sqrt(math.pow(mx - r.cx, 2) + math.pow((my - r.cy) * 1.2, 2));
    if (d < bd) {
      bd = d;
      best = k;
    }
  }
  return best;
}

final List<(double, double)> _wSpot = [for (final p in wWspot) (p[0].toDouble(), p[1].toDouble())];

/// 길 위 사람 (마을 사람 3 + 쉬는 동료 6 + 건물 옆 일꾼)
List<({String id, double x, double y, bool ppl, String? wk})> vWalkers(GameController g) {
  final c = g.calc, out = <({String id, double x, double y, bool ppl, String? wk})>[];
  const ppl = ['marta', 'timo', 'pete'];
  for (var i = 0; i < 3; i++) {
    out.add((id: ppl[i], x: _wSpot[i].$1, y: _wSpot[i].$2, ppl: true, wk: null));
  }
  final ws = c.walkersToday(g.acts.rng);
  for (var i = 0; i < ws.length && 3 + i < _wSpot.length; i++) {
    out.add((id: ws[i], x: _wSpot[3 + i].$1, y: _wSpot[3 + i].$2, ppl: false, wk: null));
  }
  c.working().forEach((id, k) {
    final p = vPos(k), i = c.wkIds(k).indexOf(id);
    out.add((id: id, x: p.x + (i > 0 ? -1 : 1) * p.w * .44, y: p.y - 6, ppl: false, wk: k));
  });
  return out;
}

String _short(String n) => n.replaceAll('브론의 ', '').replaceAll('피트의 ', '').replaceAll('별빛 ', '');

/// 건물 창 탭 이름 (웹 VTABN)
final Map<String, String> _tabName = wVtabn.cast<String, String>();
final Map<String, String> _vNote = wVnote.cast<String, String>();

// ════════════════════ 마을 탭 ════════════════════
class VlPage extends StatelessWidget {
  const VlPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    g.onWorkSheet = () => showWorkSheet(g);
    g.onForgeCan = () => forgeCanAny(g);
    final c = g.calc, todos = g.vTodos();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _LvBar(g),
      if (todos.isNotEmpty) ...[
        const SizedBox(height: 8),
        // 좁은 폭에서 잘리지 않게 줄바꿈 (웹 .vtodo flex-wrap, UX 점검 12)
        Wrap(runSpacing: 6, children: [
          for (final (k, t, go) in todos) ...[
            _Chip(t, gold: k == 'lv', onTap: go),
            if (k == 'farm') _Chip('모두 수확', all: true, onTap: () => g.act((a) => a.harvestReplant())),
          ],
        ]),
      ],
      const SizedBox(height: 10),
      VillageMap(g),
      if (c.wkOpen()) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: KdBuy(text: '🔨 일꾼 관리', kind: BuyKind.ghost, minWidth: 0, onTap: () => showWorkSheet(g))),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () => g.act((a) => a.wkAuto(true)),
              child: KdBuy(text: '추천 일꾼', minWidth: 0, onTap: () => g.act((a) => a.wkAuto(false))),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 6),
      Text('건물을 누르면 아래에 관리 창이 열려요 · 길 위 사람을 누르면 한마디', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
      if (g.vbOpen) SizedBox(height: MediaQuery.sizeOf(context).height * .5),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.t, {this.gold = false, this.all = false, required this.onTap});
  final String t;
  final bool gold, all;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: all ? KdColors.gold : gold ? const Color(0xFFE8B43A) : const Color(0x1FFFC94A),
            border: Border.all(color: all || gold ? KdColors.gold : const Color(0x73FFC94A)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(t, style: KdText.body(12.5, weight: FontWeight.w700, color: all || gold ? KdColors.goldInk : const Color(0xFFFFE6A8))),
        ),
      );
}

/// 마을 Lv 막대 (누르면 마을 레벨 창)
class _LvBar extends StatelessWidget {
  const _LvBar(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final c = g.calc, l = c.vLv(), s = c.bldSum(), nx = l < vlvNeed.length ? vlvNeed[l] : null;
    final ratio = nx == null ? 1.0 : ((s - vlvNeed[l - 1]) / (nx - vlvNeed[l - 1])).clamp(0, 1).toDouble();
    return GestureDetector(
      onTap: () => showVlSheet(g),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A2410), Color(0xFF1D1A10)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0xFF6B5420)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('마을 Lv.$l', style: KdText.display(15, color: KdColors.gold)),
              const Spacer(),
              Text('방치 골드 +${2 * l}%', style: KdText.body(12.5, color: const Color(0xFFE9DCB8))),
            ]),
            const SizedBox(height: 4),
            XpBar(ratio, height: 7, bg: const Color(0x1AFFFFFF)),
            const SizedBox(height: 3),
            Text(nx != null ? '건물 레벨 $s / $nx' : '최대 레벨', style: KdText.body(11, color: KdColors.muted)),
          ]),
          if (c.vlRw()) const Positioned(top: -4, right: -6, child: KdRedDot()),
        ]),
      ),
    );
  }
}

// ════════════════════ 마을 지도 (웹 drawVillage) ════════════════════
class VillageMap extends StatelessWidget {
  const VillageMap(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, cs) {
        final w = cs.maxWidth, h = w * 1.5, k = w / _mapW;
        return Container(
          height: h,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF4A3A22))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: GestureDetector(
              onTapUp: (d) {
                final mx = d.localPosition.dx / k, my = d.localPosition.dy / k;
                ({String id, double x, double y, bool ppl, String? wk})? hit;
                var bd = 48.0;
                for (final p in vWalkers(g)) {
                  final dd = math.sqrt(math.pow(mx - p.x, 2) + math.pow(my - (p.y - 34), 2));
                  if (dd < bd) {
                    bd = dd;
                    hit = p;
                  }
                }
                if (hit != null) {
                  final lines = villageTalk(hit.id);
                  g.vTalk = (id: hit.id, line: lines[math.Random().nextInt(lines.length)], x: hit.x, y: hit.y, end: DateTime.now().millisecondsSinceEpoch + 3200);
                  return;
                }
                final b = vHit(mx, my);
                if (b != null) g.vlSelect(b);
              },
              child: CustomPaint(size: Size(w, h), painter: _MapPainter(g)),
            ),
          ),
        );
      });
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.g) : super(repaint: g.frame);
  final GameController g;

  /// 상태 배지 (웹 vBadge): 공사 · 예약 · 완공! · 수확! · 주문 · 축복 · ⚒ · 🔨빈칸 · ▲ / 재건
  (String, Color)? _badge(String k) {
    final c = g.calc, s = g.state, a = g.acts, b = buildingDef(k), lv = s.bldLv(k), open = lv > 0 || c.bldOpen(k);
    if (!open) return null;
    final bd = c.building();
    if (bd != null && bd['k'] == k) return ('공사 ${mmss(a.buildLeft())}', const Color(0xFF9CC3FF));
    if (c.bq().contains(k)) return ('예약 ${c.bq().indexOf(k) + 1}', const Color(0xFFC9D6F2));
    if (g.vNewDone.contains(k)) return ('완공!', const Color(0xFFFFE08A));
    if (k == 'farm' && lv > 0 && s.plots.any((p) => c.plotState(p).st == 'ready')) return ('수확!', const Color(0xFF7BE08F));
    if (k == 'market' && c.ordReady() > 0) return ('주문 ${c.ordReady()}', const Color(0xFFFFB27A));
    if (k == 'chapel' && c.blessLeft() > 0) return ('축복', const Color(0xFFE7C8FF));
    if (k == 'forge' && lv > 0 && forgeCanAny(g)) return ('⚒', const Color(0xFFFFC94A));
    final hole = c.wkOpen() && c.idleIds().isNotEmpty ? c.wkSlots(k) - c.wkIds(k).length : 0;
    if (hole > 0) return ('🔨$hole', const Color(0xFFD6E6FF));
    if (!a.inBuild(k) && !(bd != null && c.bq().length >= buildQueueMax) && lv < b.max && s.gold >= GameCalc.bldCost(b, lv) && c.oreOk(b, lv)) {
      return (lv > 0 ? '▲' : '재건', const Color(0xFFFFC94A));
    }
    return null;
  }

  Size _pill(Canvas c, String t, double cx, double cy, double fs, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: 'PlexKR', fontSize: fs, fontWeight: FontWeight.w700, color: fg)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + fs * .9, h = fs * 1.55;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), Radius.circular(h / 2)), Paint()..color = bg);
    tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2 + .5));
    return Size(w, h);
  }

  void _building(Canvas c, String b, double k) {
    final p = vPos(b), lv = g.state.bldLv(b), open = lv > 0 || g.calc.bldOpen(b);
    if (!open) return;
    final t = lv > 0 ? 'built' : 'ruin', im = ImageStore.get('assets/game/village/${b}_$t.png');
    if (im == null) return;
    final bb = _vbb(b, t), sc = p.w / (bb[1] - bb[0]) * k, cx = (bb[0] + bb[1]) / 2;
    c.save();
    c.translate(p.x * k, 0);
    if (p.flip) c.scale(-1, 1);
    drawImg(c, im, Rect.fromLTWH((p.flip ? -(512 - cx) : -cx) * sc, p.y * k - 506 * sc, 512 * sc, 512 * sc));
    c.restore();
  }

  @override
  void paint(Canvas c, Size size) {
    final vw = size.width, k = vw / _mapW, t = g.sim.time.toDouble(), s = g.state;
    final map = ImageStore.get('assets/game/village/village_map.jpg');
    if (map != null) {
      drawImg(c, map, Offset.zero & size);
    } else {
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF557F5C));
    }
    for (final b in vOrder) {
      _building(c, b, k);
      if (b == g.vlSel && g.vbOpen) {
        final p = vPos(b);
        c.drawOval(
          Rect.fromCenter(center: Offset(p.x * k, (p.y - 12) * k), width: p.w * .92 * k, height: p.w * .24 * k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Color.fromRGBO(255, 201, 74, .5 + .3 * math.sin(t * 4)),
        );
      }
    }
    final hr = DateTime.now().hour;
    if (hr >= 19 || hr < 6) {
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0x700A1030));
      for (final b in vOrder) {
        if (s.bldLv(b) == 0) continue;
        final r = vRect(b);
        for (var i = 0; i < 2; i++) {
          final gx = (r.cx + (i == 1 ? .18 : -.16) * (r.x1 - r.x0)) * k, gy = (r.y1 - (r.y1 - r.y0) * (.32 + i * .08)) * k, rad = 27 * k;
          c.drawCircle(
              Offset(gx, gy),
              rad,
              Paint()
                ..blendMode = BlendMode.plus
                ..shader = ui.Gradient.radial(Offset(gx, gy), rad, [const Color(0x8CFFC86E), const Color(0x00FFC86E)]));
        }
      }
    }
    // 길 위 사람들 (길 자리에만 서서 건물을 가리지 않음)
    final fr = (t * 4).floor();
    final ws = vWalkers(g)..sort((a, b) => a.y.compareTo(b.y));
    for (final p in ws) {
      final px = p.x * k, py = p.y * k + math.sin(t * 2 + p.x) * 1.2;
      c.drawOval(Rect.fromCenter(center: Offset(px, py), width: 48 * k, height: 15 * k), Paint()..color = const Color(0x47000000));
      final sheet = charSheets[p.id], spr = p.ppl ? null : ImageStore.get('assets/game/characters/${p.id}_idle.png');
      if (sheet != null && spr != null) {
        final s0 = math.max(.32, vw / 760), kk = (66 * s0 / sprFig).toDouble(), n = sheet.frames('idle'), cw = spr.width / n;
        c.drawImageRect(spr, Rect.fromLTWH((fr % n) * cw, 0, cw, sprFrame.toDouble()),
            Rect.fromLTWH(px - cw / 2 * kk, py - sprFoot * kk, cw * kk, sprFrame * kk), Paint()..filterQuality = FilterQuality.medium);
      } else {
        final im = ImageStore.get('assets/game/portraits/portrait_${p.id}_idle.png'), r = math.max(10.0, vw * .034), cc = Offset(px, py - r - 2);
        c.drawCircle(cc, r, Paint()..color = const Color(0xFF2A2216));
        if (im != null) {
          c.save();
          c.clipPath(Path()..addOval(Rect.fromCircle(center: cc, radius: r)));
          drawImg(c, im, Rect.fromCircle(center: cc, radius: r));
          c.restore();
        }
        c.drawCircle(
            cc,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = p.ppl ? const Color(0xFFFFE08A) : const Color(0xFFCFE0FF));
      }
      if (p.wk != null) _pill(c, '🔨', px, py - math.max(30, vw * .1), math.max(9, vw * .026), const Color(0xCC1E160A), const Color(0xFFFFE08A));
    }
    // 이름표 · 상태 배지
    final fs = math.min(12.0, math.max(9.5, vw * .029)).roundToDouble();
    for (final b in vOrder) {
      final p = vPos(b), lv = s.bldLv(b), def = buildingDef(b), open = lv > 0 || g.calc.bldOpen(b), sel = b == g.vlSel && g.vbOpen, r = vRect(b);
      if (!open) {
        final lk = ImageStore.get('assets/game/ui/icon_lock.png'), cx = p.x * k, cy = (p.y - 60) * k, z = math.max(20.0, vw * .06);
        if (lk != null) drawImg(c, lk, Rect.fromCenter(center: Offset(cx, cy), width: z, height: z), alpha: .9);
        _pill(c, '잠김', cx, cy + math.max(18, vw * .05), fs - 1, const Color(0xBF14141E), const Color(0xFFC9CBD6));
        continue;
      }
      final nm = lv > 0 ? '${_short(def.n)} $lv' : _short(def.n);
      _pill(c, nm, p.x * k, (p.y - 4) * k, fs, sel ? const Color(0xF5FFC94A) : lv > 0 ? const Color(0xCC1E160A) : const Color(0xCC282834),
          sel ? const Color(0xFF3A2A00) : lv > 0 ? const Color(0xFFFFE6A8) : const Color(0xFFC9CBD6));
      final bg = _badge(b);
      if (bg != null) _pill(c, bg.$1, p.x * k, math.max(fs, r.y0 * k + fs * .6 + math.sin(t * 3 + p.x) * 2), fs, bg.$2, const Color(0xFF1A1406));
    }
    final tk = g.vTalk;
    if (tk != null) {
      final left = (tk.end - DateTime.now().millisecondsSinceEpoch) / 1000;
      if (left <= 0) {
        g.vTalk = null;
      } else {
        final txt = '${villagePeople[tk.id] ?? comps[tk.id]?.n ?? tk.id}: ${tk.line}';
        final tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(fontFamily: 'PlexKR', fontSize: fs, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
        final hw = tp.width / 2 + fs, tx = math.min(vw - hw, math.max(hw, tk.x * k)), ty = tk.y * k - math.max(48, vw * .14);
        _pill(c, txt, tx, ty, fs, Color.fromRGBO(255, 250, 235, .96 * math.min(1, left * 2)), const Color(0xFF2A1A08));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

// ════════════════════ 건물 창 (웹 #p-vb: 아래 반 창 + 건물별 탭) ════════════════════
class VbWindow extends StatefulWidget {
  const VbWindow(this.g, {super.key});
  final GameController g;

  @override
  State<VbWindow> createState() => _VbWindowState();
}

class _VbWindowState extends State<VbWindow> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g, k = g.vlSel, b = buildingDef(k), l = g.state.bldLv(k), tabs = g.vbTabs(k), tab = g.vbTab(k);
    final head = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => setState(() => _drag = math.max(0, _drag + d.delta.dy)),
      onVerticalDragEnd: (_) {
        if (_drag > 50) g.vbClose();
        setState(() => _drag = 0);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: const BoxDecoration(
          color: KdColors.pageTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(bottom: BorderSide(color: Color(0xB337436A))),
        ),
        child: Row(children: [
          Expanded(child: Text('${b.n}${l > 0 ? ' · Lv.$l' : g.calc.bldOpen(k) ? ' · 폐허' : ' · 잠김'}', style: KdText.display(19))),
          GestureDetector(
            onTap: () {
              g.vbFull = !g.vbFull;
              g.refresh();
            },
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1C2A4F), border: Border.all(color: const Color(0xFFC99A2E), width: 2)),
              child: Text(g.vbFull ? '⤡' : '⤢', style: const TextStyle(color: KdColors.gold, fontSize: 15)),
            ),
          ),
          GestureDetector(onTap: g.vbClose, child: SizedBox(width: 36, height: 36, child: uiImg('btn_close', size: 36))),
        ]),
      ),
    );
    final body = switch (tab) {
      'farm' => _Farm(g),
      'kitchen' => _Kitchen(g),
      'forge' => _ForgeTab(g),
      'order' => _Orders(g),
      'bless' => _Bless(g),
      'work' => _WorkTab(g, k),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _BuildingRow(g, k),
          if (_vNote[k] != null) ...[const SizedBox(height: 10), KdNote(_vNote[k]!)],
        ]),
    };
    return Transform.translate(
      offset: Offset(0, _drag),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [KdColors.pageTop, KdColors.bg], stops: [0, .3], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: KdColors.brass, width: 2)),
          boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, -10))],
        ),
        child: Column(children: [
          head,
          if (tabs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                for (final t in tabs) ...[
                  if (t != tabs.first) const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => g.vbTabSet(k, t),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t == tab ? KdColors.gold : KdColors.panel2,
                          border: Border.all(color: t == tab ? KdColors.gold : KdColors.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_tabName[t] ?? t, style: KdText.body(13.5, weight: FontWeight.w700, color: t == tab ? KdColors.goldInk : KdColors.muted)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          Expanded(child: ListView(key: ValueKey('vb-$k-$tab'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [body])),
        ]),
      ),
    );
  }
}

class _ForgeTab extends StatelessWidget {
  const _ForgeTab(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) => KdBox(children: forgeContent(g, (f) {
        f();
        g.refresh();
      }));
}

// ════════════════════ 시장 「주문」 ════════════════════
String _exTxt(Map<String, dynamic>? e) => e == null
    ? ''
    : switch (e['k']) {
        'ore' => '광석 ${e['n']}',
        'seed' => '🌱 씨앗 묶음',
        'card' => '🃏 동료 카드 ${e['n']}장',
        _ => '이삭 ${e['n']}',
      };

class _Orders extends StatelessWidget {
  const _Orders(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final c = g.calc, s = g.state, d = c.ordDay(), skip = asMap(d['skip']) ?? const <String, dynamic>{}, os = c.orders;
    final gemFull = orNum(d['gem'], 0) >= ordGemCap;
    return KdBox(children: [
      KdSec('피트의 주문 게시판', small: '오늘 덤 이삭 ${fmt(orNum(d['gem'], 0))} / $ordGemCap'),
      for (var i = 0; i < os.length; i++)
        () {
          final o = asMap(os[i]);
          if (o == null || !truthy(o['need'])) {
            final left = (orNum(o?['at'], 0) - c.now) / 1000;
            return Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const SizedBox(width: 44, child: Center(child: Text('📜', style: TextStyle(fontSize: 26)))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('빈 칸', style: KdText.display(14)),
                    Text('새 주문까지 ${fmtT(left)}', style: KdText.body(12, color: KdColors.muted)),
                  ]),
                ),
              ]),
            );
          }
          final can = c.ordCan(o), who = o['who'] as String, ex = asMap(o['extra']);
          final shown = ex != null && ex['k'] == 'gem' && gemFull ? <String, dynamic>{'k': 'ore', 'n': orNum(ex['n'], 0) * 5} : ex;
          return Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: KdColors.panel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: can ? const Color(0x997BE08F) : Colors.transparent),
            ),
            child: Row(children: [
              ClipOval(child: Container(width: 44, height: 44, color: const Color(0xFF2A2216), child: FaceImg(who))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${villagePeople[who] ?? comps[who]?.n ?? who}의 주문', style: KdText.display(14)),
                  const SizedBox(height: 3),
                  Wrap(spacing: 8, runSpacing: 2, children: [
                    for (final e in (o['need'] as Map).entries)
                      iconNum('assets/game/ui/item_${e.key}.png', '${itemName[e.key]} ${fmt(math.min(orNum(s.items[e.key], 0), e.value as num))}/${fmt(e.value as num)}',
                          size: 16,
                          style: KdText.figure(12, weight: FontWeight.w600, color: orNum(s.items[e.key], 0) >= (e.value as num) ? const Color(0xFF9BE3A8) : const Color(0xFFFFB0A0))),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    iconNum(goldIcon, fmt(c.ordGold(o)), size: 15, style: KdText.figure(12, color: KdColors.gold)),
                    Flexible(child: Text(' · 덤 ${_exTxt(shown)}', overflow: TextOverflow.ellipsis, style: KdText.body(12, color: KdColors.muted))),
                  ]),
                ]),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 76,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  KdBuy(text: '납품', minWidth: 0, onTap: can ? () => g.act((a) => a.ordDeliver(i)) : null),
                  const SizedBox(height: 5),
                  KdBuy(text: truthy(skip['$i']) ? '버리기' : '다른 주문', kind: BuyKind.ghost, small: true, minWidth: 0, onTap: () => g.act((a) => a.ordSkip(i))),
                ]),
              ),
            ]),
          );
        }(),
      KdNote('납품하면 재료 판매가의 $ordMul배 × (1 + 시장 Lv×3%${c.workBonus('market') > 0 ? ' + 일꾼' : ''}) 골드와 덤을 받아요. 덤 이삭은 하루 $ordGemCap개까지(넘으면 광석). 「다른 주문」은 칸마다 하루 1번 바로 바뀌고, 그다음은 1시간 기다려요.'),
    ]);
  }
}

// ════════════════════ 예배당 「축복」 (주인 리엘 — 출전 중이어도 그대로) ════════════════════
class _Bless extends StatelessWidget {
  const _Bless(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final c = g.calc, b = c.blessDay(), k = c.blessK(), left = c.blessLeft(), opts = c.blessOpts(g.acts.rng);
    final say = left > 0
        ? '오늘은 어떤 축복이 필요해? 하나만 골라.'
        : k.isNotEmpty
            ? '${blessDef(k).n}이 함께하고 있어. 별빛이 오래 머물 거야.'
            : '오늘 축복은 다 나눠 줬어. 내일 또 와.';
    return KdBox(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: const SizedBox(width: 52, height: 52, child: FaceImg('riel'))),
        const SizedBox(width: 10),
        Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: '리엘  ', style: KdText.body(12, color: KdColors.muted)), TextSpan(text: say)]), style: KdText.body(14, color: const Color(0xFFFFD9A8)))),
      ]),
      if (k.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0x1AE7C8FF), border: Border.all(color: const Color(0x73E7C8FF)), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            uiImg('bless_$k', size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(blessDef(k).n, style: KdText.display(15)),
                Text(blessDef(k).d, style: KdText.body(12, color: KdColors.muted)),
                Text('남은 시간 ${fmtT((orNum(b['until'], 0) - c.now) / 1000)}', style: KdText.body(12, color: KdColors.muted)),
              ]),
            ),
          ]),
        ),
      if (left > 0) ...[
        LayoutBuilder(builder: (_, cs) {
          final n = opts.length, w = (cs.maxWidth - 6 * (n - 1)) / n;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final o in opts) ...[
              if (o != opts.first) const SizedBox(width: 6),
              GestureDetector(
                onTap: () => g.act((a) => a.blessPick(o)),
                child: Container(
                  width: w,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  decoration: BoxDecoration(
                    color: KdColors.panel2,
                    border: Border.all(color: o == k ? KdColors.gold : const Color(0x66E7C8FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    uiImg('bless_$o', size: 52),
                    Text(blessDef(o).n, textAlign: TextAlign.center, style: KdText.body(12, weight: FontWeight.w700)),
                    Text(blessDef(o).d, textAlign: TextAlign.center, style: KdText.body(10.5, color: KdColors.muted, height: 1.35)),
                  ]),
                ),
              ),
            ],
          ]);
        }),
        KdNote('고른 축복은 ${fmtT(c.blessMs() / 1000)} 동안 이어져요${c.workBonus('chapel') > 0 ? ' (일꾼 포함)' : ''}. 다른 축복을 받으면 바뀌고, 같은 축복이면 시간만 새로 시작해요.'),
      ] else if (truthy(b['ad']) || c.adLeft('bless') <= 0)
        const KdNote('오늘 받을 수 있는 축복을 모두 받았어요. 내일 0시에 다시 받을 수 있어요.')
      else
        KdBuy(kind: BuyKind.ad, minWidth: 0, text: '▶ 광고 보고 축복 한 번 더', onTap: () => g.watchAd('bless', () => g.act((a) => a.blessAdGrant()))),
    ]);
  }
}

// ════════════════════ 일꾼 (탭 · 고르기 · 관리 창) ════════════════════
int _pct(GameController g, String k, String id) => (wkReal(k, g.calc.wkOne(k, id)) * 100).round();

Widget _face(String id, double z) => ClipOval(child: Container(width: z, height: z, color: const Color(0xFF2A2216), child: FaceImg(id)));

class _WorkTab extends StatelessWidget {
  const _WorkTab(this.g, this.k);
  final GameController g;
  final String k;

  @override
  Widget build(BuildContext context) {
    final c = g.calc, n = c.wkSlots(k), ids = c.wkIds(k), tot = (wkReal(k, c.workBonus(k)) * 100).round();
    return KdBox(children: [
      KdSec('일꾼', small: '${wEffName[k]} +$tot%'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 2; i++) ...[
          if (i == 1) const SizedBox(width: 8),
          Expanded(
            child: i >= n
                ? Container(
                    height: 116,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: KdColors.line)),
                    child: Opacity(opacity: .6, child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🔒', style: TextStyle(fontSize: 20)), Text('건물 Lv.5에 열려요', maxLines: 1, style: KdText.body(11, color: KdColors.muted))])),
                  )
                : GestureDetector(
                    onTap: () => i < ids.length ? wkSlotSheet(g, k, i) : wkPick(g, k, i),
                    child: Container(
                      height: 116,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: KdColors.panel2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: i < ids.length ? const Color(0x80FFC94A) : KdColors.line),
                      ),
                      child: i < ids.length
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              _face(ids[i], 46),
                              Text(comps[ids[i]]!.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(13, weight: FontWeight.w700)),
                              Text('${GameCalc.gr(ids[i]).n} ${'★' * c.recStar(ids[i])} · ${jobName[jobOf[ids[i]]]}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(10.5, color: KdColors.muted)),
                              Text('+${_pct(g, k, ids[i])}%${c.wkMatch(k, ids[i]) ? ' · 잘 맞음' : ''}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(11.5, weight: FontWeight.w700, color: const Color(0xFF9BE3A8))),
                            ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('+', style: KdText.display(26, color: KdColors.gold)),
                              Text('일꾼 넣기', maxLines: 1, style: KdText.body(13, weight: FontWeight.w700)),
                              Text('쉬는 동료 ${c.idleIds().length}명', maxLines: 1, style: KdText.body(11, color: KdColors.muted)),
                            ]),
                    ),
                  ),
          ),
        ],
      ]),
      KdNote('${workJob[k] != null ? '잘 맞는 직업: ${jobName[workJob[k]]} (효과 2배)' : '누구나 같은 효과예요'}${k == 'inn' || k == 'forge' || k == 'market' ? ' · 이 건물은 효과의 절반이 적용돼요' : ''}. 효과 = 등급(일반 10·희귀 15·영웅 20·전설 30%) + 별마다 2%. 출전하지 않는 동료만 일할 수 있어요.'),
    ]);
  }
}

/// 일꾼 고르기 (쉬는 동료, 효과 큰 순서)
void wkPick(GameController g, String k, int i, [VoidCallback? back]) {
  final c = g.calc, cur = i < c.wkIds(k).length ? c.wkIds(k)[i] : null;
  final list = c.idleIds().where((id) => id != cur).toList()..sort((a, b) => c.wkOne(k, b).compareTo(c.wkOne(k, a)));
  g.openSheet<void>((ctx) => KdSheetBody(
        eyebrow: '${buildingDef(k).n} · 일꾼 ${i + 1}번 칸',
        title: '누구에게 맡길까요?',
        children: [
          if (list.isEmpty) const KdNote('쉬는 동료가 없어요. 동료를 더 모으거나 원정대에서 빼면 일할 수 있어요.'),
          for (final id in list)
            GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                g.act((a) => a.wkPut(k, i, id));
                back?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  _face(id, 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${comps[id]!.n}  ${GameCalc.gr(id).n} ${'★' * c.recStar(id)}', style: KdText.display(14)),
                      Text('${jobName[jobOf[id]]}${c.wkMatch(k, id) ? ' · 잘 맞음 ×2' : ''}', style: KdText.body(12, color: KdColors.muted)),
                      Text('${wEffName[k]} +${_pct(g, k, id)}%', style: KdText.body(12, weight: FontWeight.w700, color: const Color(0xFF9BE3A8))),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
        acts: KdActs(buttons: [
          KdAct('닫기', primary: true, onTap: () {
            Navigator.of(ctx).pop();
            back?.call();
          }),
        ]),
      ));
}

/// 일꾼 칸을 누르면: 빼기 / 바꾸기
void wkSlotSheet(GameController g, String k, int i, [VoidCallback? back]) {
  final ids = g.calc.wkIds(k);
  if (i >= ids.length) return wkPick(g, k, i, back);
  final id = ids[i];
  g.openSheet<void>((ctx) => KdSheetBody(
        eyebrow: '${buildingDef(k).n} · 일꾼',
        title: comps[id]!.n,
        children: [KdNote('${wEffName[k]} +${_pct(g, k, id)}%${g.calc.wkMatch(k, id) ? ' · 잘 맞는 직업' : ''}', center: true)],
        acts: KdActs(buttons: [
          KdAct('빼기', onTap: () {
            Navigator.of(ctx).pop();
            g.act((a) => a.wkOut(k, id));
            back?.call();
          }),
          KdAct('바꾸기', primary: true, onTap: () {
            Navigator.of(ctx).pop();
            wkPick(g, k, i, back);
          }),
        ]),
      ));
}

/// 일꾼 관리 창 (4-3): 줄 = 건물 10채, 칸 = 일꾼 1·2, 오른쪽 효과 합
void showWorkSheet(GameController g) {
  void re() => showWorkSheet(g);
  final c = g.calc, rest = c.idleIds();
  g.openSheet<void>((ctx) => KdSheetBody(
        eyebrow: '마을',
        title: '일꾼 관리',
        children: [
          for (final b in buildings)
            () {
              final l = g.state.bldLv(b.k), n = c.wkSlots(b.k), ids = c.wkIds(b.k);
              return Opacity(
                opacity: l > 0 ? 1 : .45,
                child: Row(children: [
                  kdImg('assets/game/village/${b.k}_${l > 0 ? 'built' : 'ruin'}.png', w: 26, h: 26),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_short(b.n), maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(12.5, weight: FontWeight.w700))),
                  for (var i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: i >= n
                          ? SizedBox(width: 38, height: 38, child: Center(child: Text(l > 0 ? 'Lv.5' : '—', style: KdText.body(10, color: KdColors.muted))))
                          : GestureDetector(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                if (i < ids.length) {
                                  wkSlotSheet(g, b.k, i, re);
                                } else {
                                  wkPick(g, b.k, i, re);
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: KdColors.panel2,
                                  border: Border.all(color: i < ids.length ? const Color(0x99FFC94A) : KdColors.line, width: i < ids.length ? 2 : 1),
                                ),
                                child: i < ids.length ? _face(ids[i], 34) : Text('+', style: KdText.body(18, color: KdColors.gold)),
                              ),
                            ),
                    ),
                  SizedBox(
                    width: 50,
                    child: Text(ids.isNotEmpty ? '+${(wkReal(b.k, c.workBonus(b.k)) * 100).round()}%' : '',
                        textAlign: TextAlign.right, style: KdText.body(12, weight: FontWeight.w700, color: const Color(0xFF9BE3A8))),
                  ),
                ]),
              );
            }(),
          KdSec('쉬는 동료 ${rest.length}명', small: '출전하지 않고 일도 안 하는 동료'),
          if (rest.isEmpty) const KdNote('없어요') else Wrap(spacing: 4, runSpacing: 4, children: [for (final id in rest) _face(id, 34)]),
          Row(children: [
            for (final (t, f) in [
              ('추천 일꾼', () => g.act((a) => a.wkAuto(false))),
              ('모두 다시 배치', () => g.act((a) => a.wkAuto(true))),
              ('모두 빼기', () => g.act((a) => a.wkClear())),
            ]) ...[
              if (t != '추천 일꾼') const SizedBox(width: 6),
              Expanded(
                child: KdBuy(
                  text: t,
                  kind: BuyKind.ghost,
                  small: true,
                  minWidth: 0,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    f();
                    re();
                  },
                ),
              ),
            ],
          ]),
        ],
        acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(ctx).pop())]),
      ));
}

/// 마을 레벨 창 (레벨 표 · 보상 받기)
void showVlSheet(GameController g) {
  final c = g.calc, l = c.vLv(), s = c.bldSum();
  g.openSheet<void>((ctx) => KdSheetBody(
        eyebrow: '마을',
        title: '마을 Lv.$l',
        children: [
          KdNote('모든 건물 레벨 합 $s · 방치 골드 +${2 * l}%', center: true),
          for (var i = 0; i < vlvNeed.length; i++)
            () {
              final lv = i + 1, ok = s >= vlvNeed[i], got = c.vlvGot >= lv, ep = villageEpisodes[lv];
              final col = ok ? const Color(0xFFFFE6A8) : KdColors.muted;
              return Row(children: [
                SizedBox(width: 42, child: Text('Lv.$lv', style: KdText.body(12, weight: FontWeight.w700, color: col))),
                SizedBox(width: 26, child: Text('${vlvNeed[i]}', style: KdText.figure(12, color: col))),
                Expanded(
                  child: Text(
                      lv > 1 ? '이삭 ${vlvGem[lv]}${lv == 5 ? ' · 배지' : lv == 10 ? ' · 테두리' : ''}${ep != null ? ' · 📖 ${ep.$1}' : ''}' : '—',
                      style: KdText.body(11.5, color: col)),
                ),
                SizedBox(width: 30, child: Text(lv > 1 ? (got ? '✓' : ok ? '받기' : '') : '', textAlign: TextAlign.right, style: KdText.body(12, weight: FontWeight.w700, color: const Color(0xFF7BE08F)))),
              ]);
            }(),
        ],
        acts: KdActs(buttons: [
          KdAct('닫기', onTap: () => Navigator.of(ctx).pop()),
          KdAct(c.vlRw() ? '보상 받기' : '다음 레벨까지 ${l < vlvNeed.length ? vlvNeed[l] - s : 0}', primary: true, claim: true, onTap: c.vlRw()
              ? () {
                  Navigator.of(ctx).pop();
                  g.vlClaimUi();
                }
              : null),
        ]),
      ));
}

// ════════════════════ 고른 건물 정보 (웹 renderBlds) ════════════════════
class _BuildingRow extends StatelessWidget {
  const _BuildingRow(this.g, this.k);
  final GameController g;
  final String k;

  Widget _img(num lv, {bool dim = false}) {
    final w = kdImg('assets/game/village/${k}_${lv > 0 ? 'built' : 'ruin'}.png', w: 64, h: 64);
    return dim ? filtered(w, bright: .6) : w;
  }

  Widget _role(String who) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(999)),
        child: Text(who, style: KdText.body(11.5, color: KdColors.muted)),
      );

  @override
  Widget build(BuildContext context) {
    final c = g.calc, a = g.acts, s = g.state, b = buildingDef(k), l = s.bldLv(k), op = c.bldOpen(k), mx = l >= b.max;
    final deco = BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF2A2A3A), KdColors.panel], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      border: Border.all(color: const Color(0x73FFC94A)),
      borderRadius: BorderRadius.circular(12),
    );
    Text line(String t, {Color color = KdColors.muted}) => Text(t, style: KdText.figure(12, color: color, weight: FontWeight.w400));
    Widget head(String tag) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(b.n, style: KdText.display(15)),
          if (b.who.isNotEmpty) _role(b.who),
          if (tag.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4), child: Text(tag, style: KdText.body(12, color: KdColors.gold))),
        ]);
    if (!op && l == 0) {
      return Opacity(
        opacity: .6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: deco,
          child: Row(children: [
            _img(0, dim: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                head(''),
                line(b.lock),
                line('재건하면: ${c.bldEff(k, 1)}', color: const Color(0xFFC9D2EA)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(999)),
              child: Text('잠김', style: KdText.body(12, color: KdColors.muted, weight: FontWeight.w600)),
            ),
          ]),
        ),
      );
    }
    final bd = c.building(), here = bd != null && bd['k'] == k, queued = c.bq().contains(k), full = bd != null && c.bq().length >= buildQueueMax;
    final cost = GameCalc.bldCost(b, l), ore = c.bldOre(b, l), time = c.bldTime(b, l);
    final gemNow = c.bldGem(cost) + GameCalc.timeGem(time);
    final info = <Widget>[
      head(l > 0 ? 'Lv.$l' : '폐허'),
      if (l > 0) ...[
        line('지금: ${c.bldEff(k, l)}'),
        line(mx ? '최대 레벨' : '다음: ${c.bldEff(k, l + 1)}', color: const Color(0xFFC9D2EA)),
      ] else ...[
        line('무너져 있어요'),
        line('재건하면: ${c.bldEff(k, 1)}', color: const Color(0xFFC9D2EA)),
      ],
      if (here) ...[
        const SizedBox(height: 4),
        XpBar((1 - a.buildLeft() / orNum(bd['dur'], time)).toDouble(), color: const Color(0xFF6FA8FF)),
        const SizedBox(height: 3),
        Text('${l > 0 ? '확장' : '재건'} 공사 중 · ${fmtT(a.buildLeft())} 남음', style: KdText.body(12, color: const Color(0xFF9CC3FF))),
      ] else if (queued) ...[
        const SizedBox(height: 4),
        Text('공사 예약 ${c.bq().indexOf(k) + 1}번째 · 앞 공사가 끝나면 ${fmtT(time)} 동안 지어요', style: KdText.body(12, color: const Color(0xFF9CC3FF))),
      ] else if (!mx)
        line('공사 시간 ${fmtT(time)}'),
    ];
    final buys = <Widget>[
      if (here)
        KdBuy(kind: BuyKind.gem, minWidth: 0, onTap: () => g.act((a) => a.finishByGem()), extra: null, label: '바로 완료', cost: GameCalc.timeGem(a.buildLeft()), costIcon: gemIcon)
      else if (queued)
        KdBuy(text: '예약 취소', kind: BuyKind.ghost, minWidth: 0, onTap: () => g.act((a) => a.cancelQueued(k)))
      else ...[
        KdBuy(
          label: mx ? null : full ? '예약이 가득 찼어요' : bd != null ? '예약' : l > 0 ? '확장' : '재건',
          text: mx ? '최대' : null,
          cost: mx || full ? null : cost,
          costIcon: goldIcon,
          minWidth: 0,
          extra: !mx && !full && ore > 0
              ? iconNum(oreIcon, '$ore', style: KdText.figure(15, color: c.oreOk(b, l) ? KdColors.goldInk : const Color(0xFFFF8A7A)))
              : null,
          onTap: mx || full || s.gold < cost || !c.oreOk(b, l) ? null : () => g.act((a) => a.orderBuild(k)),
        ),
        if (!mx) ...[
          const SizedBox(height: 4),
          KdBuy(kind: BuyKind.gem, small: true, minWidth: 0, label: '바로', cost: gemNow, costIcon: gemIcon, onTap: () => g.act((a) => a.buildByGem(k))),
        ],
      ],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: deco,
      child: Row(children: [
        _img(l),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: info)),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: buys),
        ),
      ]),
    );
  }
}
// ════════════════════ 밭 (웹 renderFarm) ════════════════════
class _Farm extends StatelessWidget {
  const _Farm(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final a = g.acts, c = g.calc, s = g.state;
    a.ensurePlots();
    final edit = g.plotEdit, gp = s.gemPlots.toInt();
    final nGrow = s.plots.where((p) => c.plotState(p).st == 'grow').length;
    final anyReady = s.plots.any((p) => c.plotState(p).st == 'ready');
    final anyEmpty = [
      for (var i = 0; i < s.plots.length; i++)
        s.plots[i] == null && (a.plotTag(i) != null ? orNum(s.seeds[a.plotTag(i)!], 0) > 0 : crops.any((x) => orNum(s.seeds[x.k], 0) > 0))
    ].any((x) => x);
    return KdBox(children: [
      KdSec('카엘의 밭', small: 'Lv.${s.bldLv('farm')} · ${s.plots.length}칸${gp > 0 ? ' (황금 밭 $gp칸)' : ''} · 카엘의 진짜 꿈'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final cr in crops) _chip('assets/game/ui/seed_${cr.k}.png', '${cr.n} 씨앗 ${fmt(orNum(s.seeds[cr.k], 0))}'),
      ]),
      if (edit)
        Text('밭을 누를 때마다 자유 → 밀 → 은빛 당근 → 달빛 호박 순서로 바뀌어요. 지정한 밭에는 그 작물만 심어져요.',
            style: KdText.body(12, color: const Color(0xFFFFE08A), height: 1.6)),
      LayoutBuilder(builder: (_, cs) {
        final w = (cs.maxWidth - 18) / 4;
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < s.plots.length; i++) SizedBox(width: w, child: _plot(i, w)),
          if (gp < gemPlotCost.length) SizedBox(width: w, child: _gemPlot(w, gemPlotCost[gp])),
        ]);
      }),
      if (gemPlotCost.length - gp > 1) KdNote('🔒 황금 밭 ${gemPlotCost.length - gp - 1}칸 더 열 수 있어요 · 앞의 밭부터 차례로', center: true),
      Row(children: [
        Expanded(
          child: KdBuy(
            text: edit ? '지정 끝내기' : '밭 지정',
            kind: BuyKind.ghost,
            minWidth: 0,
            onTap: () {
              g.plotEdit = !edit;
              g.refresh();
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: KdBuy(text: '모두 심기', kind: BuyKind.ghost, minWidth: 0, onTap: anyEmpty && !edit ? () => g.act((a) => a.plantAll()) : null)),
        const SizedBox(width: 6),
        Expanded(child: KdBuy(kind: BuyKind.claim, text: '모두 수확', minWidth: 0, onTap: anyReady ? () => g.act((a) => a.harvestAll()) : null)),
      ]),
      if (nGrow > 0) ...[
        KdBuy(
          kind: BuyKind.gem,
          minWidth: 0,
          text: '${nGrow * gemPlot}로 자라는 작물 $nGrow칸 바로 키우기',
          onTap: () => g.act((a) => a.growNow()),
        ),
        if (c.adLeft('farm') > 0)
          KdBuy(
            kind: BuyKind.ad,
            minWidth: 0,
            text: '▶ 광고 보고 바로 키우기 · 오늘 ${c.adLeft('farm')}회',
            onTap: () => g.watchAd('farm', () => g.act((a) => a.growByAd())),
          ),
      ],
      const KdNote('씨앗은 마물이 가끔 떨어뜨려요. 작물은 게임을 꺼 둔 동안에도 자라요.'),
    ]);
  }

  Widget _chip(String icon, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(999)),
        child: iconNum(icon, t, style: KdText.figure(12, weight: FontWeight.w400)),
      );

  /// 밭 한 칸 (웹 .plot.art): 그림(118%로 크게)·이름·시간/수확·진행 막대·지정 표시
  Widget _plot(int i, double w) {
    final a = g.acts, c = g.calc, s = g.state, ps = c.plotState(s.plots[i]), edit = g.plotEdit, tag = a.plotTag(i);
    String img, name, act;
    double? ratio;
    if (ps.st == 'empty') {
      img = 'plot_empty';
      name = tag != null ? '${crops.firstWhere((x) => x.k == tag).n} 밭' : '빈 밭';
      act = edit ? '바꾸기' : '심기';
    } else if (ps.st == 'ready') {
      img = 'crop_${ps.c!.k}_4';
      name = ps.c!.n;
      act = '수확';
    } else {
      final r = ps.ratio!.toDouble();
      img = 'crop_${ps.c!.k}_${r < .25 ? 1 : r < .6 ? 2 : 3}';
      name = ps.c!.n;
      act = mmss(ps.left!);
      ratio = r;
    }
    final ready = ps.st == 'ready';
    // 황금 고블린이 다녀간 칸: 수확 2배 (웹 .plot.gob · .pgob)
    final gob = ps.st != 'empty' && truthy(asMap(s.plots[i])?['g']);
    if (gob && ready) name = '$name ×2';
    return GestureDetector(
      onTap: () {
        if (edit) return g.act((a) => a.cycleTag(i));
        if (ps.st == 'empty') return _chooseSeed(i);
        g.act((a) => a.tapPlot(i));
      },
      child: Container(
        height: w * 1.25,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2C3B2A), Color(0xFF3A2A20)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: edit ? KdColors.gold : ready ? KdColors.gold : gob ? const Color(0x8CFFD23C) : const Color(0xFF5A4030), width: edit || ready || gob ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(children: [
            Positioned(
              left: -w * .09,
              right: -w * .09,
              top: -w * .16,
              height: w * 1.18,
              child: Container(
                decoration: ready ? const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x40FFD66B), blurRadius: 12)]) : null,
                child: kdImg('assets/game/crops/$img.png'),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Column(children: [
                Text(name, maxLines: 1, overflow: TextOverflow.clip, style: KdText.body(11, height: 1.3).copyWith(shadows: const [Shadow(blurRadius: 2)])),
                Text(act,
                    style: KdText.figure(12, color: ready ? KdColors.gold : KdColors.fg).copyWith(height: 1.2, shadows: const [Shadow(blurRadius: 2)])),
                if (ratio != null)
                  Padding(padding: EdgeInsets.fromLTRB(w * .11, 3, w * .11, 0), child: XpBar(ratio, height: 4, color: KdColors.good, bg: const Color(0x73000000))),
              ]),
            ),
            if (gob)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0xE6FFD23C), blurRadius: 8)], shape: BoxShape.circle),
                  child: uiImg('icon_goblin', size: 22),
                ),
              ),
            if (tag != null)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Color(0xB30A0E1A), shape: BoxShape.circle),
                  child: kdImg('assets/game/ui/item_$tag.png'),
                ),
              )
            else if (edit)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xB30A0E1A), borderRadius: BorderRadius.circular(999)),
                  child: Text('자유', style: KdText.body(9, color: const Color(0xFFC9CBD6), weight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _gemPlot(double w, num cost) => GestureDetector(
        onTap: () => g.act((a) => a.askGemPlot()),
        child: Container(
          height: w * 1.25,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3A3020), Color(0xFF2A2018)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC9A24A)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(children: [
              Positioned(
                left: -w * .09,
                right: -w * .09,
                top: -w * .16,
                height: w * 1.18,
                child: filtered(kdImg('assets/game/crops/plot_empty.png'), gray: .6, bright: .6),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Column(children: [
                  Text('새 밭 일구기', maxLines: 1, style: KdText.body(11, height: 1.3)),
                  iconNum(gemIcon, '$cost', size: 14, style: KdText.figure(12, color: const Color(0xFFFFE08A))),
                ]),
              ),
            ]),
          ),
        ),
      );

  /// 씨앗 고르기 창 (웹 chooseSeed)
  void _chooseSeed(int i) {
    if (g.act((a) => a.chooseSeedTagged(i))) return;
    var tag = false;
    g.openSheet<void>((ctx) => StatefulBuilder(
          builder: (ctx, set) => KdSheetBody(
            title: '무엇을 심을까요?',
            children: [
              for (final cr in crops)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    uiImg('seed_${cr.k}'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cr.n, style: KdText.display(15)),
                        Text('자라는 시간 ${mmss(g.calc.cropT(cr))} · 씨앗 ${fmt(orNum(g.state.seeds[cr.k], 0))}개', style: KdText.figure(12, color: KdColors.muted, weight: FontWeight.w400)),
                      ]),
                    ),
                    KdBuy(
                      text: '심기',
                      minWidth: 64,
                      onTap: orNum(g.state.seeds[cr.k], 0) > 0
                          ? () {
                              g.act((a) => a.plantChosen(i, cr.k, tag: tag));
                              Navigator.of(ctx).pop();
                            }
                          : null,
                    ),
                  ]),
                ),
              GestureDetector(
                onTap: () => set(() => tag = !tag),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 1, right: 8),
                    decoration: BoxDecoration(
                      color: tag ? const Color(0xFFF6C445) : Colors.transparent,
                      border: Border.all(color: tag ? const Color(0xFFF6C445) : KdColors.muted, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: tag ? const Icon(Icons.check, size: 14, color: KdColors.goldInk) : null,
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('이 칸을 고른 작물 전용 밭으로 지정', style: KdText.body(14)),
                      Text("다음부터 '모두 심기'를 해도 이 칸엔 그 작물만 심어져요", style: KdText.body(12, color: KdColors.fg.withValues(alpha: .7))),
                    ]),
                  ),
                ]),
              ),
            ],
            acts: KdActs(buttons: [KdAct('닫기', onTap: () => Navigator.of(ctx).pop())]),
          ),
        ));
  }
}

// ════════════════════ 식당 (웹 renderKitchen) ════════════════════
class _Kitchen extends StatelessWidget {
  const _Kitchen(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final a = g.acts, c = g.calc, s = g.state, now = c.now, val = a.storeValue();
    return KdBox(children: [
      KdSec(s.isJoined('margo') ? '마고의 식당' : '마을 부엌', small: '요리하면 원정대가 강해져요'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final cr in crops) _chip(cr.k, cr.n),
        for (final gd in goods)
          if (orNum(s.items[gd.k], 0) > 0 || truthy(s.bld[gd.b])) _chip(gd.k, gd.n),
      ]),
      for (final r in recipes.where((r) => !r.ranch || s.bldLv('ranch') > 0))
        () {
          final ok = a.canCook(r), left = (orNum(s.buffs[r.buff], 0) - now) / 1000;
          final need = r.need.entries.map((e) => '${itemName[e.key]} ${e.value}').join(', ');
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              kdImg('assets/game/ui/dish_${r.k}.png', w: 56, h: 56),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                    Text(r.n, style: KdText.display(15)),
                    if (left > 0) Text('${mmss(left)} 남음', style: KdText.figure(12, color: KdColors.gold, weight: FontWeight.w400)),
                  ]),
                  Text('${r.desc} · ${(g.calc.cookMs() / 60000).round()}분${g.calc.vpCook() > 1 ? ' (수라간의 손맛)' : ''}${g.calc.trCook() > 0 ? ' (오래 끓인 국)' : ''}${g.calc.workBonus('diner') > 0 ? ' (일꾼)' : ''}', style: KdText.body(12, color: KdColors.muted)),
                  Text('재료: $need', style: KdText.body(12, color: KdColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              KdBuy(text: '요리', minWidth: 64, onTap: ok ? () => g.act((a) => a.cook(r.k)) : null),
            ]),
          );
        }(),
      KdBuy(text: '창고 물건 모두 판매 +${fmt(val)}', kind: BuyKind.ghost, minWidth: 0, onTap: val > 0 ? () => g.act((a) => a.sellAll()) : null),
      if (truthy(s.bld['market']))
        GestureDetector(
          onTap: () {
            s.raw['keepOrder'] = truthy(s.raw['keepOrder']) ? 0 : 1;
            g.refresh();
          },
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1, right: 8),
              decoration: BoxDecoration(
                color: truthy(s.raw['keepOrder']) ? const Color(0xFFF6C445) : Colors.transparent,
                border: Border.all(color: truthy(s.raw['keepOrder']) ? const Color(0xFFF6C445) : KdColors.muted, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: truthy(s.raw['keepOrder']) ? const Icon(Icons.check, size: 14, color: KdColors.goldInk) : null,
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('주문에 필요한 재료는 남기기', style: KdText.body(14)),
                Text('시장 주문 게시판에 올라온 재료 수만큼은 팔지 않아요', style: KdText.body(12, color: KdColors.fg.withValues(alpha: .7))),
              ]),
            ),
          ]),
        ),
    ]);
  }

  Widget _chip(String k, String n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(999)),
        child: iconNum('assets/game/ui/item_$k.png', '$n ${fmt(orNum(g.state.items[k], 0))}', style: KdText.figure(12, weight: FontWeight.w400)),
      );
}
