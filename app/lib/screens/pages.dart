/// 탭 화면 틀 — 웹 .page / .page.half / .phead (반쯤 열리기·크게 보기·아래로 끌어 닫기)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'eq_page.dart';
import 'mp_page.dart';
import 'pt_page.dart';
import 'shop_page.dart';
import 'up_page.dart';
import 'vl_page.dart';

/// 탭 내용. 4~6단계에서 하나씩 실제 화면으로 바뀐다.
Widget pageBody(GameController g, GameTab t) => switch (t) {
      GameTab.eq => EqPage(g),
      GameTab.pt => PtPage(g),
      GameTab.up => UpPage(g),
      GameTab.vl => VlPage(g),
      GameTab.mp => MpPage(g),
      GameTab.sh => ShopPage(g),
    };

/// 탭 화면 한 장. [half] 면 위쪽이 비어 전투가 보이고, 머리를 아래로 끌면 닫힘.
class PageSheet extends StatefulWidget {
  const PageSheet({super.key, required this.g, required this.tab, required this.half});
  final GameController g;
  final GameTab tab;
  final bool half;

  @override
  State<PageSheet> createState() => _PageSheetState();
}

class _PageSheetState extends State<PageSheet> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g, t = widget.tab, half = widget.half;
    final head = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: half ? (d) => setState(() => _drag = math.max(0, _drag + d.delta.dy)) : null,
      onVerticalDragEnd: half
          ? (_) {
              if (_drag > 50) {
                g.setTab(null);
              } else {
                setState(() => _drag = 0);
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: KdColors.pageTop,
          borderRadius: half ? const BorderRadius.vertical(top: Radius.circular(18)) : null,
          border: const Border(bottom: BorderSide(color: Color(0xB337436A))),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 10, offset: Offset(0, 6), spreadRadius: -6)],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          if (half)
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: Center(
                child: Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(2))),
              ),
            ),
          Row(children: [
            Expanded(child: Text(t.title, style: KdText.display(20))),
            if (t.half)
              GestureDetector(
                onTap: g.togglePgFull,
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1C2A4F),
                    border: Border.all(color: const Color(0xFFC99A2E), width: 2),
                  ),
                  child: Text(g.pgFull ? '⤡' : '⤢', style: const TextStyle(color: KdColors.gold, fontSize: 15)),
                ),
              ),
            GestureDetector(
              onTap: () => g.setTab(null),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 2))]),
                child: uiImg('btn_close', size: 36),
              ),
            ),
          ]),
        ]),
      ),
    );
    return Transform.translate(
      offset: Offset(0, _drag),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [KdColors.pageTop, KdColors.bg], stops: [0, .3], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: half ? const BorderRadius.vertical(top: Radius.circular(18)) : null,
          border: half ? const Border(top: BorderSide(color: KdColors.brass, width: 2)) : null,
          boxShadow: half ? const [BoxShadow(color: Color(0x8C000000), blurRadius: 24, offset: Offset(0, -10))] : null,
        ),
        child: Column(children: [
          head,
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: g.ui,
              builder: (_, __, ___) {
                final list = ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [pageBody(g, t)],
                );
                // 마을: 건물을 누르면 아래에서 올라오는 건물 창 (웹 #p-vb, ⤢ 로 크게)
                // 지도: 지역을 누르면 아래 반 창 (웹 #p-mz)
                if (t == GameTab.mp && g.mapZoomR >= 0) {
                  return LayoutBuilder(
                    builder: (_, cs) => Stack(children: [
                      list,
                      Positioned(left: 0, right: 0, bottom: 0, height: cs.maxHeight * .38, child: MapRegionPanel(g)),
                    ]),
                  );
                }
                if (t != GameTab.vl || !g.vbOpen) return list;
                return LayoutBuilder(
                  builder: (_, cs) => Stack(children: [
                    list,
                    Positioned(left: 0, right: 0, bottom: 0, height: g.vbFull ? cs.maxHeight : cs.maxHeight * .58, child: VbWindow(g)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
