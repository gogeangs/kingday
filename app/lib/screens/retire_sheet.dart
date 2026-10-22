/// 은퇴 일기 창 — 웹 diarySheet(): 특성 · 기록 · 다음 보상 (docs/content/RETIRE.md 4장)
library;

import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/js.dart';
import '../core/retire.dart';
import '../game/controller.dart';
import '../game/online.dart' show stgName;
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 창 안에서 고른 탭·갈래 (웹 diaryTab·diaryBr)
String _tab = 'tr', _br = 'sword';

/// 은퇴 일기 창 열기 (처음 대사는 GameController.openDiary 가 먼저 보여 줌)
Future<void> openDiarySheet(GameController g) async {
  await g.openSheet((ctx) => ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => _Diary(g, ctx)));
}

Widget _dot({Color c = KdColors.gold, Color b = const Color(0xFF6B4F12), double s = 8}) => Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: b)),
    );

class _Diary extends StatefulWidget {
  const _Diary(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_Diary> createState() => _DiaryState();
}

class _DiaryState extends State<_Diary> {
  GameController get g => widget.g;
  bool _askReset = false;

  void _set(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) {
    final c = g.calc, mp = c.memPts();
    if (_askReset) return _resetAsk();
    return KdSheetBody(
      titleWidget: SizedBox(
        height: 78,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: kdImg('assets/game/ui/hd_retire.png')),
          FractionallySizedBox(
            widthFactor: .62,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final w in const ['은퇴', '일기'])
                Text(w, style: KdText.display(19, color: const Color(0xFF5A3412)).copyWith(shadows: const [Shadow(color: Color(0xCCFFF0C8), offset: Offset(0, 1))])),
            ]),
          ),
        ]),
      ),
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '쓸 수 있는 추억 포인트 '),
            TextSpan(text: '$mp', style: const TextStyle(color: Color(0xFFFFD34A), fontSize: 17, fontWeight: FontWeight.w700)),
            TextSpan(text: ' · 받은 추억 ${fmtN(g.state.memory)}개', style: const TextStyle(fontSize: 12)),
          ]),
          key: const ValueKey('dyPts'),
          textAlign: TextAlign.center,
          style: KdText.body(13, color: KdColors.muted),
        ),
        _tabs(),
        ...switch (_tab) {
          'log' => _log(),
          'rw' => _rw(),
          _ => _traits(mp),
        },
      ],
      acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop())]),
    );
  }

  Widget _tabs() => Row(children: [
        for (final (k, n) in const [('tr', '특성'), ('log', '기록'), ('rw', '다음 보상')]) ...[
          if (k != 'tr') const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              key: ValueKey('dyTab-$k'),
              onTap: () => _set(() => _tab = k),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == k ? KdColors.gold : KdColors.panel2,
                    border: Border.all(color: _tab == k ? KdColors.gold : KdColors.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(n, style: KdText.body(14, color: _tab == k ? const Color(0xFF1A1206) : KdColors.muted, weight: FontWeight.w600)),
                ),
                if (k == 'tr' && g.calc.trCanAny()) Positioned(top: 4, right: 10, child: _dot(c: const Color(0xFFE5483B), b: Colors.white)),
              ]),
            ),
          ),
        ],
      ]);

  List<Widget> _traits(int mp) {
    final c = g.calc, b = memBranches.firstWhere((x) => x.k == _br), sp = c.trSpent(b.k);
    return [
      Row(children: [
        for (final x in memBranches) ...[
          if (x.k != 'sword') const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              key: ValueKey('dyBr-${x.k}'),
              onTap: () => _set(() => _br = x.k),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: x.k == _br ? const LinearGradient(colors: [Color(0x2EFFC94A), Color(0x0DFFC94A)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                    color: x.k == _br ? null : KdColors.panel2,
                    border: Border.all(color: x.k == _br ? KdColors.gold : const Color(0x1FFFFFFF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 40, height: 40, child: Image.asset('assets/game/ui/trait_branch_${x.k}.png', errorBuilder: (_, __, ___) => Center(child: Text(x.ic, style: const TextStyle(fontSize: 26))))),
                    Text(x.n, style: KdText.body(12, weight: FontWeight.w700)),
                    Text('${c.trSpent(x.k)}P', style: KdText.body(11, color: KdColors.muted)),
                  ]),
                ),
                if (memTraits.any((t) => t.b == x.k && c.trOpen(t) && c.trNext(t) != null && c.trNext(t)! <= mp))
                  Positioned(top: 4, right: 6, child: _dot(s: 9)),
              ]),
            ),
          ),
        ],
      ]),
      Text.rich(TextSpan(children: [
        TextSpan(text: '${b.ic} ${b.n} · ${b.d} · 이 갈래에 쓴 포인트 '),
        TextSpan(text: '$sp', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
      ]), textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
      for (final r in const [1, 2, 3]) _row(b.k, r, sp, mp),
      KdBuy(
        key: const ValueKey('dyReset'),
        text: '특성 초기화 · ${c.trResetGem() > 0 ? '황금 이삭 100' : '무료'}',
        kind: BuyKind.ghost,
        minWidth: 0,
        onTap: c.trSpent() > 0 ? () => _set(() => _askReset = true) : null,
      ),
    ];
  }

  Widget _row(String br, int r, int sp, int mp) {
    final ts = memTraits.where((t) => t.b == br && t.r == r).toList(), open = sp >= memRow[r];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (!open)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('🔒 이 갈래에 ${memRow[r] - sp}포인트 더 쓰면 열려요', textAlign: TextAlign.center, style: KdText.body(12, color: const Color(0xFFFFB36B))),
        ),
      Opacity(
        opacity: open ? 1 : .45,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < ts.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _card(ts[i], open, mp)),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _card(MemTrait t, bool open, int mp) {
    final l = g.calc.tl(t.k), nx = g.calc.trNext(t), can = open && nx != null && nx <= mp;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: KdColors.panel2,
        border: Border.all(color: l >= t.max ? const Color(0x8CFFC94A) : const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          kdImg('assets/game/ui/trait_${t.k}.png', w: 36, h: 36),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.n, style: KdText.body(13, weight: FontWeight.w700, height: 1.2)),
              Text('$l/${t.max}', style: KdText.body(11, color: KdColors.gold)),
            ]),
          ),
        ]),
        const SizedBox(height: 3),
        Text(l > 0 ? t.e(l) : '아직 안 찍음', style: KdText.body(12, color: const Color(0xFF9FE0A6), height: 1.35)),
        Expanded(child: Text(nx != null ? '다음: ${t.e(l + 1)}' : '최대 단계', style: KdText.body(11, color: KdColors.muted, height: 1.35))),
        if (nx != null) ...[
          const SizedBox(height: 4),
          KdBuy(key: ValueKey('dyTr-${t.k}'), text: '찍기 · $nx포인트', minWidth: 0, small: true, onTap: can ? () => g.trBuy(t.k) : null),
        ],
      ]),
    );
  }

  List<Widget> _log() {
    final s = g.state, c = g.calc;
    Widget li(String a, String b) => Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x0FFFFFFF)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: KdText.body(13, color: KdColors.muted)),
            const SizedBox(width: 10),
            Expanded(child: Text(b, textAlign: TextAlign.right, style: KdText.body(13, weight: FontWeight.w600))),
          ]),
        );
    final best = (s.best < maxLand + 1 ? s.best : maxLand + 1) - 1;
    return [
      _panel([
        li('은퇴 횟수', '${s.retires.toInt()}번'),
        li('받은 은퇴의 추억', '${fmtN(s.memory)}개 (모든 능력치·골드 +${fmtN(s.memory * 5)}%)'),
        li('쓴 추억 포인트', '${c.trSpent()} / $memTotal'),
        li('가장 멀리 간 영지', '$best곳'),
        li('시련의 탑 최고 층', '${orNum(asMap(s.raw['tower'])?['top'], 0).toInt()}층'),
        li('왕도 탈환', '${orNum(s.raw['capClears'], 0).toInt()}번'),
        li('이번 회차 시작', stgName(c.runStart)),
      ]),
    ];
  }

  List<Widget> _rw() {
    final s = g.state, done = asMap(s.raw['retRw']) ?? const <String, dynamic>{};
    return [
      _panel([
        for (final r in retRewards)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x0FFFFFFF)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${truthy(done['${r.n}']) ? '✅' : '⬜'} 은퇴 ${r.n}회', style: KdText.body(13, color: KdColors.muted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('황금 이삭 ${r.gem}${r.t != null ? ' · ${r.t}' : ''}',
                    textAlign: TextAlign.right,
                    style: KdText.body(13, weight: FontWeight.w600, color: truthy(done['${r.n}']) ? const Color(0xFF9FE0A6) : KdColors.fg)),
              ),
            ]),
          ),
      ]),
      KdNote('지금 ${s.retires.toInt()}번 은퇴했어요', center: true),
    ];
  }

  Widget _panel(List<Widget> kids) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
      );

  Widget _resetAsk() {
    final gcost = g.calc.trResetGem();
    return KdSheetBody(
      eyebrow: '은퇴 일기',
      title: '특성 초기화',
      children: [
        KdNote('찍은 포인트를 모두 돌려받아요. ${gcost > 0 ? '황금 이삭 $gcost' : '무료'}', center: true),
        if (gcost == 0) const KdNote('첫 1번은 무료, 그다음부터 황금 이삭 100', center: true),
      ],
      acts: KdActs(buttons: [
        KdAct('취소', onTap: () => _set(() => _askReset = false)),
        KdAct('초기화', primary: true, onTap: () {
          g.trReset();
          _set(() => _askReset = false);
        }),
      ]),
    );
  }
}

/// 소수 없는 숫자 문자
String fmtN(num v) => v.toInt().toString();
