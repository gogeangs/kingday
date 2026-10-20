/// 마을 탭 — 웹 #p-vl (마을 풍경 · 고른 건물 · 밭 · 식당)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/game_widgets.dart';
import '../ui/image_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 마을 풍경 속 건물 자리 (가로 위치 비율, 웹 VSLOT)
const vSlots = [('farm', .098), ('inn', .257), ('diner', .413), ('dock', .573), ('apiary', .739), ('mine', .902)];

const _vNote = {
  'inn': '원정대가 쉬는 곳이에요. 레벨이 오를수록 게임을 꺼 둔 동안 더 오래 세금이 쌓여요.',
  'dock': '잡은 생선은 창고에 쌓여요. 식당에서 요리 재료로 쓰거나 팔 수 있어요.',
  'apiary': '모은 꿀은 창고에 쌓여요. 식당에서 요리 재료로 쓰거나 팔 수 있어요.',
  'mine': '캐낸 광석은 창고에 쌓여요. 식당에서 팔 수 있어요.',
};

class VlPage extends StatelessWidget {
  const VlPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final sel = g.vlSel, farm = truthy(g.state.bld['farm']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VillageScene(g),
      const SizedBox(height: 6),
      Text('건물을 눌러 관리해요 · 좌우로 밀어 마을을 둘러봐요', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
      const SizedBox(height: 12),
      _BuildingRow(g, sel),
      if (_vNote[sel] != null) ...[const SizedBox(height: 12), KdNote(_vNote[sel]!)],
      if (sel == 'farm' && farm) ...[const SizedBox(height: 12), _Farm(g)],
      if (sel == 'diner' && farm) ...[const SizedBox(height: 12), _Kitchen(g)],
    ]);
  }
}

// ════════════════════ 마을 풍경 (웹 drawVillage) ════════════════════
class VillageScene extends StatefulWidget {
  const VillageScene(this.g, {super.key});
  final GameController g;

  @override
  State<VillageScene> createState() => _VillageSceneState();
}

class _VillageSceneState extends State<VillageScene> {
  final _sc = ScrollController();
  String? _scrolledTo;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scrollTo(String k, double vw, double view, {bool smooth = true}) {
    final fx = vSlots.firstWhere((s) => s.$1 == k).$2;
    final to = math.max(0.0, math.min(vw * fx - view / 2, vw - view));
    if (!_sc.hasClients) return;
    if (smooth) {
      _sc.animateTo(to, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _sc.jumpTo(to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final vh = math.min(330.0, math.max(220.0, MediaQuery.sizeOf(context).height * .4)), vw = vh * 3;
    return LayoutBuilder(builder: (_, c) {
      if (_scrolledTo != g.vlSel) {
        final first = _scrolledTo == null;
        _scrolledTo = g.vlSel;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(g.vlSel, vw, c.maxWidth, smooth: !first));
      }
      return Container(
        height: vh,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4A3A22)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SingleChildScrollView(
            controller: _sc,
            scrollDirection: Axis.horizontal,
            child: GestureDetector(
              onTapUp: (d) {
                final x = d.localPosition.dx / vw;
                String? best;
                var bd = .08;
                for (final (k, fx) in vSlots) {
                  if ((fx - x).abs() < bd) {
                    bd = (fx - x).abs();
                    best = k;
                  }
                }
                if (best != null) g.vlSelect(best);
              },
              child: CustomPaint(size: Size(vw, vh), painter: _VillagePainter(g)),
            ),
          ),
        ),
      );
    });
  }
}

class _VillagePainter extends CustomPainter {
  _VillagePainter(this.g) : super(repaint: g.frame);
  final GameController g;

  /// vBadge(): 건물 위 말풍선 (공사 중·예약·수확!·심기·재건 가능·▲ 확장)
  (String, Color)? _badge(String k, BuildingDef b, num lv, bool open) {
    final c = g.calc, s = g.state, a = g.acts;
    if (!open) return null;
    final bd = c.building();
    if (bd != null && bd['k'] == k) return ('공사 중 ${fmtT(a.buildLeft())}', const Color(0xFF9CC3FF));
    if (c.bq().contains(k)) return ('예약 ${c.bq().indexOf(k) + 1}', const Color(0xFFC9D6F2));
    if (k == 'farm' && lv > 0 && s.plots.any((p) => c.plotState(p).st == 'ready')) return ('수확!', const Color(0xFF7BE08F));
    if (k == 'farm' && lv > 0 && s.plots.any((p) => p == null) && crops.any((x) => orNum(s.seeds[x.k], 0) > 0)) {
      return ('심기', const Color(0xFF9BE3C0));
    }
    if (!a.inBuild(k) && !(bd != null && c.bq().length >= buildQueueMax) && lv < b.max && s.gold >= GameCalc.bldCost(b, lv) && c.oreOk(b, lv)) {
      return (lv > 0 ? '▲ 확장' : '재건 가능', const Color(0xFFFFC94A));
    }
    return null;
  }

  void _pill(Canvas c, String t, double cx, double cy, double h, double font, Color bg, Color fg, {bool pointer = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: 'PlexKR', fontSize: font, fontWeight: FontWeight.w600, color: fg)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 14, p = Paint()..color = bg;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), Radius.circular(h / 2)), p);
    if (pointer) {
      c.drawPath(
          Path()
            ..moveTo(cx - 5, cy + h / 2 - 1)
            ..lineTo(cx, cy + h / 2 + 5)
            ..lineTo(cx + 5, cy + h / 2 - 1)
            ..close(),
          p);
    }
    tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2 + .5));
  }

  @override
  void paint(Canvas c, Size size) {
    final vw = size.width, vh = size.height, t = g.sim.time.toDouble(), s = g.state;
    final bg = ImageStore.get('assets/game/village/village_bg.jpg');
    if (bg != null) {
      drawImg(c, bg, Offset.zero & size);
    } else {
      c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF557F5C));
    }
    final hr = DateTime.now().hour;
    if (hr >= 19 || hr < 6) c.drawRect(Offset.zero & size, Paint()..color = const Color(0x610A1030));
    final bw = vw * .155, base = vh * .64;
    for (final (k, fx) in vSlots) {
      final lv = s.bldLv(k), b = buildingDef(k), cx = vw * fx, open = lv > 0 || g.calc.bldOpen(k);
      final im = ImageStore.get('assets/game/village/${k}_${lv > 0 ? 'built' : 'ruin'}.png');
      if (im != null) {
        final z = (bw * (1 + math.min(lv, 10) * .012)).toDouble();
        drawImg(c, im, Rect.fromLTWH(cx - z / 2, base - z * .99, z, z), alpha: open ? 1 : .55);
      }
      final sel = k == g.vlSel;
      final label = lv > 0 ? '${b.n} Lv.$lv' : open ? '${b.n} · 폐허' : '${b.n} · 잠김';
      final font = math.min(14.0, math.max(11.0, vh * .045)).roundToDouble(), th = math.min(24.0, math.max(18.0, vh * .075)).roundToDouble();
      if (sel) {
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, base - bw * .04), width: bw * 1.04, height: bw * .26),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Color.fromRGBO(255, 201, 74, .55 + .25 * math.sin(t * 3)),
        );
      }
      _pill(
        c, label, cx, vh * .74, th, font,
        sel ? const Color(0xF2FFC94A) : lv > 0 ? const Color(0xC71E160A) : const Color(0xB31E1E28),
        sel ? const Color(0xFF3A2A00) : lv > 0 ? const Color(0xFFFFE6A8) : const Color(0xFFC9CBD6),
      );
      final bd = _badge(k, b, lv, open);
      if (bd != null) {
        final by = base - bw * 1.02 + math.sin(t * 3 + fx * 9) * 3;
        _pill(c, bd.$1, cx, by, (th * .95).roundToDouble(), math.min(13.0, math.max(10.0, vh * .042)).roundToDouble(), bd.$2,
            const Color(0xFF1A1406),
            pointer: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VillagePainter old) => true;
}

// ════════════════════ 고른 건물 (웹 renderBlds) ════════════════════
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
    if (!op) {
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
        XpBar((1 - a.buildLeft() / orNum(bd!['dur'], time)).toDouble(), color: const Color(0xFF6FA8FF)),
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
        Expanded(child: KdBuy(text: '모두 수확', minWidth: 0, onTap: anyReady ? () => g.act((a) => a.harvestAll()) : null)),
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
          border: Border.all(color: edit ? KdColors.gold : ready ? KdColors.gold : const Color(0xFF5A4030), width: edit || ready ? 2 : 1),
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
                        Text('자라는 시간 ${mmss(cr.t)} · 씨앗 ${fmt(orNum(g.state.seeds[cr.k], 0))}개', style: KdText.figure(12, color: KdColors.muted, weight: FontWeight.w400)),
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
      for (final r in recipes)
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
                  Text('${r.desc} · 10분', style: KdText.body(12, color: KdColors.muted)),
                  Text('재료: $need', style: KdText.body(12, color: KdColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              KdBuy(text: '요리', minWidth: 64, onTap: ok ? () => g.act((a) => a.cook(r.k)) : null),
            ]),
          );
        }(),
      KdBuy(text: '창고 물건 모두 판매 +${fmt(val)}', kind: BuyKind.ghost, minWidth: 0, onTap: val > 0 ? () => g.act((a) => a.sellAll()) : null),
    ]);
  }

  Widget _chip(String k, String n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(999)),
        child: iconNum('assets/game/ui/item_$k.png', '$n ${fmt(orNum(g.state.items[k], 0))}', style: KdText.figure(12, weight: FontWeight.w400)),
      );
}
