/// 탭 화면 틀 — 웹 .page / .page.half / .phead (반쯤 열리기·크게 보기·아래로 끌어 닫기)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 탭 내용. 4~6단계에서 하나씩 실제 화면으로 바뀐다.
Widget pageBody(GameController g, GameTab t) => switch (t) {
      GameTab.eq => _soon(g, '성유물 상자 · 장비 칸 · 브론의 대장간', '4단계'),
      GameTab.pt => _soon(g, '편성 · 동료 · 동료 카드', '4단계'),
      GameTab.up => _soon(g, '단련(연속 강화) · 은퇴', '4·6단계'),
      GameTab.vl => _soon(g, '마을 풍경 · 건물 · 밭 · 식당', '5단계'),
      GameTab.mp => _MapInfo(g),
      GameTab.sh => _soon(g, '오늘의 할 일 · 피트의 무료 선물 · 골드 바꾸기 · 카드 · 상품', '4·9단계'),
    };

Widget _soon(GameController g, String what, String when) => KdBox(children: [
      KdSec(what),
      KdNote('이 화면은 $when 에서 웹과 똑같이 옮겨 와요. 지금은 화면 틀(반쯤 열리기 · 크게 보기 · 아래로 끌어 닫기)만 들어 있어요.'),
    ]);

/// 지도 아래 정보 (웹 renderMapInfo) — 지도 그림은 5단계
class _MapInfo extends StatelessWidget {
  const _MapInfo(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc.landCount(), ri = g.calc.rankIdx(), r = GameCalc.region(s.stage);
    final nx = ri + 1 < ranks.length ? ranks[ri + 1] : null;
    return KdBox(children: [
      KdSec('${s.stage > maxLand ? '왕도 아스테리온' : GameCalc.terrName(s.stage)} 탈환 중', small: '${r.n} · ${(s.stage - 1) % 10 + 1}/10'),
      KdKv('되찾은 영지', '$c / $maxLand'),
      KdKv('지금 칭호', '${ranks[ri].n} (원정대 +${ri * 4}%)'),
      KdKv('다음 칭호', nx != null ? '${nx.n}까지 ${nx.at - c}곳' : '왕도 탈환만 남았어요'),
      KdKv('이 지역의 지배자', r.boss),
      const KdNote('영지마다 마족 성주가 지키고, 지역의 마지막 영지에는 군단장이 있어요. 다섯 군단을 모두 몰아내면 왕도로 가는 길이 열려요.'),
      const KdNote('영지 지도 그림은 5단계에서 옮겨 와요.'),
    ]);
  }
}

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
              builder: (_, __, ___) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [pageBody(g, t)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
