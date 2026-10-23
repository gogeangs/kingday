/// 탈환 보고서 (docs/content/FIRST_DAY.md 3-2, 웹 rpFlush): 같은 순간 생긴 이야기 창을 한 장에 모음
library;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// 보고서 한 칸: 얼굴 · 머리글 · 한 줄 제목 · 펼칠 대사
typedef ReportItem = ({String face, String eb, String t, List<String> p, String btn, Widget? titleWidget, VoidCallback? go});

/// 대사 중 처음 나오는 「m:이름|」의 얼굴, 없으면 카엘 (웹 rpFace)
String reportFace(List<String> ps) {
  for (final p in ps) {
    if (!p.startsWith('m:')) continue;
    final i = p.indexOf('|');
    final w = p.substring(2, i < 0 ? p.length : i).split('@').first;
    final id = Para.npcId(w);
    if (id != null) return 'assets/game/portraits/portrait_${id}_idle.png';
  }
  return 'assets/game/portraits/portrait_kael_idle.png';
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.items, required this.onDone});
  final List<ReportItem> items;
  final VoidCallback onDone;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _open = <int>{};

  Widget _row(int i, ReportItem it) {
    final on = _open.contains(i);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x59C9952A)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC9952A), width: 2),
              gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFF2C4A7A), KdColors.bg]),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: kdImg(it.face, fit: BoxFit.cover, align: const Alignment(0, -.5))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(it.eb, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(11, color: KdColors.gold)),
              Text(it.t, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.display(14)),
            ]),
          ),
          const SizedBox(width: 6),
          Pressable(
            onTap: () => setState(() => on ? _open.remove(i) : _open.add(i)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(8), border: Border.all(color: KdColors.line)),
              child: Text(on ? '접기' : '자세히 보기', style: KdText.body(12)),
            ),
          ),
        ]),
      ),
      if (on)
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            for (final p in it.p) Padding(padding: const EdgeInsets.only(bottom: 6), child: Para(p)),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => KdSheetBody(
        eyebrow: '영지 소식',
        title: '탈환 보고서',
        children: [
          for (var i = 0; i < widget.items.length; i++) _row(i, widget.items[i]),
        ],
        acts: KdActs(buttons: [KdAct('계속', primary: true, onTap: widget.onDone)]),
      );
}
