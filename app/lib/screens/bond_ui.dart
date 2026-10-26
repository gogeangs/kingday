// 원정대의 정 (docs/content/BOND.md 4장): 하트 줄 · 동료 창 호감도 한 줄 · 원정대 일기
// (웹 affHearts · affLine · bondDiary)
import 'package:flutter/material.dart';

import '../core/bond.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../game/controller.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _pink = Color(0xFFFF7A9C), _off = Color(0xFF6B7393), _gold = Color(0xFFFFD34A);

/// 하트 줄 5칸 (웹 .hearts) — ♥5 단짝은 금빛
class AffHearts extends StatelessWidget {
  const AffHearts(this.lv, {super.key, this.size = 11});
  final int lv;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '호감도 $lv',
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: '♥' * lv,
                style: TextStyle(color: lv >= 5 ? _gold : _pink, shadows: lv >= 5 ? const [Shadow(color: Color(0x99FFD34A), blurRadius: 6)] : null)),
            TextSpan(text: '♡' * (5 - lv), style: const TextStyle(color: _off)),
          ]),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: size, height: 1.15, letterSpacing: -1),
        ),
      );
}

/// 동료 창 한 줄: 「호감도 ♥3 · 다음 ♥까지 62% · 공격·체력 +6%」 + 「?」 (웹 affLine)
class AffLine extends StatefulWidget {
  const AffLine(this.c, this.id, {super.key});
  final GameCalc c;
  final String id;

  @override
  State<AffLine> createState() => _AffLineState();
}

class _AffLineState extends State<AffLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c, id = widget.id, l = c.affLv(id);
    final pc = c.affPct(id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Text('호감도 ', style: KdText.body(13, color: KdColors.muted)),
        AffHearts(l, size: 12),
        const Spacer(),
        Text('공격·체력 +${l * 2}%', key: const ValueKey('affLine'), maxLines: 1, style: KdText.figure(12.5, weight: FontWeight.w600)),
        const SizedBox(width: 6),
        GestureDetector(
          key: const ValueKey('affQ'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Semantics(
            label: '호감도 오르는 방법',
            button: true,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KdColors.line), color: KdColors.panel2),
              child: Text('?', style: KdText.body(12, color: KdColors.muted, weight: FontWeight.w700, height: 1)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      // 다음 ♥까지 진행 막대 (♥5 단짝이면 꽉 참)
      Row(children: [
        Expanded(child: XpBar(pc / 100, color: _pink)),
        const SizedBox(width: 8),
        Text(l >= 5 ? '단짝 · ♥5' : '다음 ♥까지 $pc%', key: const ValueKey('affNext'), style: KdText.body(11.5, color: KdColors.muted)),
      ]),
      if (_open)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('함께 싸우거나 마을 일꾼으로 일하면 5분마다 1점, 마을 길 위에서 말을 걸면 하루 1번 +10점. ♥마다 공격·체력 +2%, ♥5는 단짝. 은퇴해도 남아요.',
              style: KdText.body(12, color: KdColors.muted, height: 1.45)),
        ),
    ]);
  }
}

/// 원정대 탭 「📖 원정대 일기 n/6」 (새 장면이 열렸으면 점)
class BondDiaryButton extends StatelessWidget {
  const BondDiaryButton(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final c = g.calc, nw = c.bondNew().isNotEmpty;
    return Stack(clipBehavior: Clip.none, children: [
      KdBuy(
        key: const ValueKey('bdDiary'),
        kind: BuyKind.ghost,
        text: '📖 원정대 일기 ${c.bondSeenN()}/${bonds.length}',
        onTap: () => bondDiary(g),
      ),
      if (nw)
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            key: const ValueKey('bdDot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: KdColors.gold, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6B4F12))),
          ),
        ),
    ]);
  }
}

/// 원정대 일기 창: 6칸 (본 장면 다시 보기 / 흐리게 + 두 동료 ♥ / 합류 전 실루엣) (웹 bondDiary)
void bondDiary(GameController g) {
  g.openSheet<void>((ctx) => ValueListenableBuilder<int>(
        valueListenable: g.ui,
        builder: (ctx, __, ___) {
          final c = g.calc;
          Widget cell(BondDef b) {
            final ok = c.bondOpen(b), seen = c.bondSeen['${b.k}'] != null && c.bondSeen['${b.k}'] != 0;
            final miss = [b.a, b.b].where((id) => !c.owned(id)).toList();
            final sub = seen
                ? '다시 보기'
                : ok
                    ? '새 이야기 · 눌러서 보기'
                    : miss.isNotEmpty
                    ? '${miss.map((id) => '${comps[id]!.n}${GameCalc.josa(comps[id]!.n, '을', '를')}').join(' · ')} 만나면 열려요'
                    : '${comps[b.a]!.n} ♥${c.affLv(b.a)} · ${comps[b.b]!.n} ♥${c.affLv(b.b)}${ok ? '' : ' · 둘 다 ♥3'}';
            Widget face(String id) => CompFrame(id, w: 38, h: 44, hidden: !c.owned(id), dim: c.owned(id) && !seen);
            final tap = seen || ok;
            return GestureDetector(
              key: ValueKey('bd-${b.k}'),
              onTap: tap
                  ? () {
                      Navigator.of(ctx).pop();
                      g.act((a) => a.bondPlay(b.k));
                    }
                  : null,
              child: Opacity(
                opacity: tap ? 1 : .62,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: KdColors.panel2,
                    border: Border.all(color: seen ? _pink : ok ? const Color(0xFFFFD34A) : KdColors.line),
                    boxShadow: !seen && ok ? const [BoxShadow(color: Color(0x59FFD34A), blurRadius: 10)] : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [face(b.a), const SizedBox(width: 2), face(b.b)]),
                    const SizedBox(height: 5),
                    Text(seen || miss.isEmpty ? b.t : '???',
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: KdText.display(13)),
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: KdText.body(11, color: !seen && ok ? const Color(0xFFFFD34A) : KdColors.muted, height: 1.3)),
                  ]),
                ),
              ),
            );
          }

          return KdSheetBody(
            eyebrow: '원정대의 정',
            title: '원정대 일기',
            children: [
              Text('짝이 있는 동료가 둘 다 ♥3이 되면 이야기가 열려요',
                  textAlign: TextAlign.center, style: KdText.body(12.5, color: KdColors.muted)),
              LayoutBuilder(builder: (_, cs) {
                final w = (cs.maxWidth - 8) / 2;
                return Wrap(spacing: 8, runSpacing: 8, children: [for (final b in bonds) SizedBox(width: w, child: cell(b))]);
              }),
            ],
            acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(ctx).pop())]),
          );
        },
      ));
}
