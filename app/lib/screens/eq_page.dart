/// 장비 탭 — 웹 #p-eq (장비 칸 6개 + 카엘, 성유물 상자, 능력치, 브론의 대장간)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_data.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class EqPage extends StatelessWidget {
  const EqPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stage(),
        const SizedBox(height: 12),
        _box(),
        const SizedBox(height: 12),
        _stats(),
        const SizedBox(height: 12),
        _Forge(g),
      ]);

  // ── 장비 칸 + 카엘 (웹 .eqstage) ──
  Widget _stage() {
    Widget col(List<String> ks) => Column(children: [
          for (final k in ks) ...[
            if (k != ks.first) const SizedBox(height: 8),
            _Slot(g, k),
          ],
        ]);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const RadialGradient(center: Alignment(0, .2), radius: .9, colors: [Color(0xFF3A2A1A), Color(0xFF1A1410)], stops: [0, .7]),
        border: Border.all(color: const Color(0xFF4A3A22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(flex: 10, child: col(['weapon', 'armor', 'gloves'])),
        const SizedBox(width: 8),
        Expanded(flex: 16, child: SizedBox(height: 190, child: _Hero(g))),
        const SizedBox(width: 8),
        Expanded(flex: 10, child: col(['helm', 'boots', 'ring'])),
      ]),
    );
  }

  // ── 성유물 상자 (웹 .box: 레벨·경험치·확률·자동·열기·10연속) ──
  Widget _box() {
    final s = g.state, c = g.calc, maxed = s.boxLv >= 10, odds = c.odds(), cost = c.boxCost();
    final can = s.gold >= cost && g.acts.pending == null;
    return KdBox(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text('성유물 상자 Lv.${s.boxLv}${maxed ? ' (최대)' : ''}', style: KdText.display(16))),
        Text(maxed ? '최대 레벨' : '${s.boxXp} / ${c.xpNeed()}', style: KdText.figure(13, color: KdColors.muted, weight: FontWeight.w400)),
      ]),
      XpBar(maxed ? 1 : s.boxXp / c.xpNeed()),
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (var i = 0; i < itemGrades.length; i++)
          oddsChip(gradeColor(i), '${itemGrades[i].n} ${odds[i] < 1 ? odds[i].toStringAsFixed(2) : odds[i].toStringAsFixed(1)}%'),
      ]),
      Wrap(spacing: 14, runSpacing: 8, children: [
        _toggle('약한 장비 바로 판매', 'autoSell'),
        _toggle('자동 열기', 'autoOpen'),
      ]),
      _openBtn(
        '상자 열기',
        iconNum(goldIcon, fmt(cost), size: 20, style: KdText.figure(14, color: can ? KdColors.goldInk.withValues(alpha: .75) : KdColors.muted)),
        can ? () => g.openBox() : null,
      ),
      _openBtn(
        '10연속 열기',
        iconNum(gemIcon, '$gem10', size: 20, style: KdText.figure(14, color: const Color(0xBFFFE08A))),
        g.acts.pending == null ? () => g.act((a) => a.open10()) : null,
        gem: true,
      ),
      const KdNote('10연속은 영웅 등급 이상 1개 확정이에요. 등급별 확률은 위와 같아요. 더 좋은 장비는 바로 장착하고 나머지는 팔아요.'),
      const KdNote('행상인 피트의 성유물은 카엘만 착용해요.'),
    ]);
  }

  Widget _toggle(String label, String key) {
    final on = truthy(g.state.raw[key]);
    return GestureDetector(
      onTap: () {
        g.state.raw[key] = !on;
        g.refresh();
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: on ? KdColors.gold : Colors.transparent,
            border: Border.all(color: on ? KdColors.gold : KdColors.muted, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: on ? const Icon(Icons.check, size: 13, color: KdColors.goldInk) : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: KdText.body(13, color: KdColors.muted)),
      ]),
    );
  }

  /// 웹 .open / .open.gemopen
  Widget _openBtn(String label, Widget cost, VoidCallback? onTap, {bool gem = false}) {
    final off = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: off ? KdColors.panel2 : gem ? null : KdColors.gold,
          gradient: !off && gem ? const LinearGradient(colors: [Color(0xFF2C4A8C), Color(0xFF1D3366)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
          border: gem && !off ? Border.all(color: const Color(0xFF5A7AC8)) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: off ? null : [BoxShadow(color: gem ? const Color(0xFF14234A) : const Color(0xFFB9850F), offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: KdText.display(19, color: off ? KdColors.muted : gem ? const Color(0xFFFFE08A) : KdColors.goldInk)),
          const SizedBox(width: 8),
          cost,
        ]),
      ),
    );
  }

  // ── 카엘 능력치 (웹 #eqStats) ──
  Widget _stats() {
    final k = g.calc.kStats();
    Widget kv(String n, String v) => Row(children: [
          Expanded(child: Text(n, style: KdText.body(13, color: KdColors.muted))),
          Text(v, style: KdText.figure(13)),
        ]);
    return KdBox(gap: 4, children: [
      Row(children: [Expanded(child: kv('공격력', fmt(k.atk))), const SizedBox(width: 12), Expanded(child: kv('체력', fmt(k.hp)))]),
      Row(children: [
        Expanded(child: kv('공격 속도', k.aps.toStringAsFixed(2))),
        const SizedBox(width: 12),
        Expanded(child: kv('치명타', '${(k.crit * 100).round()}%')),
      ]),
    ]);
  }
}

/// 카엘 서 있는 모습 (웹 drawEqHero: idle 4칸, 초당 5칸)
class _Hero extends StatelessWidget {
  const _Hero(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth, h = c.maxHeight, s = math.min(2.05, w / 88), k = (66 * s / sprFig).toDouble();
        final size = sprFrame * k, x = w * .42, y = h - 12;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: w * .45 - w * .32,
            top: h - 14 - 8,
            width: w * .64,
            height: 16,
            child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x59000000), borderRadius: BorderRadius.all(Radius.elliptical(100, 8)))),
          ),
          Positioned(
            left: x - size / 2,
            top: y - sprFoot * k,
            child: ValueListenableBuilder<int>(
              valueListenable: g.frame,
              builder: (_, __, ___) => SpriteFrame('assets/game/characters/kael_idle.png',
                  frames: charSheets['kael']!.idle, index: (g.sim.time * 5).floor() % charSheets['kael']!.idle, size: size),
            ),
          ),
        ]);
      });
}

/// 장비 칸 (웹 .slot): 등급 테두리·그림·강화 표·레벨
class _Slot extends StatelessWidget {
  const _Slot(this.g, this.k);
  final GameController g;
  final String k;

  @override
  Widget build(BuildContext context) {
    final it = g.calc.equipped(k), en = g.calc.enLv(k);
    final flash = g.flashAt[k];
    final age = flash == null ? 1e9 : DateTime.now().millisecondsSinceEpoch - flash;
    final scale = age < 260 ? 1.12 - .12 * age / 260 : 1.0;
    return GestureDetector(
      onTap: () => _sheet(),
      child: Transform.scale(
        scale: scale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 76),
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth;
              return Stack(children: [
                Positioned.fill(child: uiImg('frame_${frameNames[it?.g ?? 0]}', size: w)),
                Positioned.fill(
                  left: w * (it != null ? .12 : .16),
                  top: w * (it != null ? .12 : .16),
                  right: w * (it != null ? .12 : .16),
                  bottom: w * (it != null ? .12 : .16),
                  child: it != null
                      ? kdImg(relicSrc(it))
                      : Opacity(opacity: .35, child: filtered(uiImg(slotImg[k]!, size: w * .68), gray: 1)),
                ),
                if (en > 0)
                  Positioned(
                    top: w * .06,
                    right: w * .08,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF9A3A), Color(0xFFC95A10)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                      child: Text('+$en', style: KdText.body(10, color: Colors.white, weight: FontWeight.w600, height: 1.5)),
                    ),
                  ),
                Positioned(
                  left: w * (it != null ? .24 : .18),
                  right: w * (it != null ? .24 : .18),
                  bottom: w * .17,
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(999)),
                    alignment: Alignment.center,
                    child: Text(it != null ? 'Lv.${it.lv}' : '비어 있음',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: KdText.body(it != null ? 10 : 9.5, color: it != null ? Colors.white : const Color(0xFFC9CBD6), weight: FontWeight.w600, height: 1.5)),
                  ),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  /// 칸을 누르면 (웹 slotSheet): 착용 장비 + 이 칸 강화
  void _sheet() {
    g.openSheet<void>((ctx) => StatefulBuilder(builder: (ctx, set) {
          final sl = slotDef(k), it = g.calc.equipped(k), l = g.calc.enLv(k), mx = l >= enMax, cost = g.calc.enCost(l);
          final ore = orNum(g.state.items['ore'], 0), open = truthy(g.state.bld['mine']);
          String? after;
          if (it != null && !mx) {
            final m = 1 + .1 * (l + 1), p = <String>[];
            if (it.atk != 0) p.add('공격 +${fmt(it.atk * m)}');
            if (it.hp != 0) p.add('체력 +${fmt(it.hp * m)}');
            after = '강화 후 ${p.join(' · ')}';
          }
          return KdSheetBody(
            eyebrow: '${sl.n} 칸',
            title: it != null ? '${itemGrades[it.g].n} ${sl.n} Lv.${it.lv}' : '${sl.n} · 비어 있음',
            children: [
              Center(child: SizedBox(width: 180, child: RelicCard(it, '착용 중', g.calc))),
              if (it == null) const KdNote('성유물 상자를 열면 이 칸의 장비가 나와요.', center: true),
              KdSec('브론의 대장간', small: '광석 ${fmt(ore)}'),
              if (!open)
                const KdNote('마을에 광산을 재건하면 강화할 수 있어요.')
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${sl.n} +$l', style: KdText.display(15)),
                        Text('이 칸 장비 능력치 +${l * 10}%${mx ? ' (최대)' : ' → 다음 +${(l + 1) * 10}%'}', style: KdText.body(12, color: KdColors.muted)),
                        if (after != null) Text(after, style: KdText.body(12, color: KdColors.muted)),
                      ]),
                    ),
                    KdBuy(
                      label: mx ? null : '강화',
                      text: mx ? '최대' : null,
                      cost: mx ? null : cost,
                      costIcon: mx ? null : oreIcon,
                      onTap: mx || ore < cost
                          ? null
                          : () {
                              g.act((a) => a.enhanceSlot(k));
                              set(() {});
                            },
                    ),
                  ]),
                ),
                const KdNote('강화는 장비가 아니라 칸에 남아요. 더 좋은 장비로 바꿔도 그대로예요.'),
              ],
            ],
            acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(ctx).pop())]),
          );
        }));
  }
}

/// 브론의 대장간 (웹 #forge, 접었다 펼치기)
class _Forge extends StatefulWidget {
  const _Forge(this.g);
  final GameController g;

  @override
  State<_Forge> createState() => _ForgeState();
}

class _ForgeState extends State<_Forge> {
  bool fold = true;

  @override
  Widget build(BuildContext context) {
    final g = widget.g, s = g.state, c = g.calc, ore = orNum(s.items['ore'], 0);
    final head = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: truthy(s.bld['mine']) ? () => setState(() => fold = !fold) : null,
      child: Row(children: [
        Expanded(child: KdSec('브론의 대장간', small: truthy(s.bld['mine']) ? '광석 ${fmt(ore)}' : '잠김')),
        if (truthy(s.bld['mine']))
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(fold ? '▾ 펼치기' : '▴', style: KdText.body(fold ? 12 : 14, color: KdColors.muted)),
          ),
      ]),
    );
    if (!truthy(s.bld['mine'])) {
      return KdBox(children: [head, const KdNote('마을에 광산을 재건하면 브론이 캐낸 광석으로 성유물을 강화할 수 있어요.')]);
    }
    if (fold) return KdBox(children: [head]);
    Widget grid(List<Widget> items, int cols) => LayoutBuilder(builder: (_, cs) {
          final w = (cs.maxWidth - 6 * (cols - 1)) / cols;
          return Wrap(spacing: 6, runSpacing: 6, children: [for (final i in items) SizedBox(width: w, child: i)]);
        });
    Widget fg({required Widget icon, required Widget name, required Widget cost, VoidCallback? onTap}) => GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .5 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [icon, const SizedBox(height: 2), name, const SizedBox(height: 2), cost]),
            ),
          ),
        );
    Widget nm(String n, int l) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '$n '),
            TextSpan(text: '+$l', style: const TextStyle(color: Color(0xFFFF9A3A))),
          ]),
          textAlign: TextAlign.center,
          style: KdText.body(12, weight: FontWeight.w600),
        );
    final costStyle = KdText.figure(12, color: const Color(0xFFD8DCEF));
    return KdBox(children: [
      head,
      const KdNote('부위마다 강화할 때마다 그 부위 성유물 능력치가 10%씩 올라요. 장비를 바꿔도 강화는 부위에 남아요.'),
      grid([
        for (final sl in slots)
          () {
            final l = c.enLv(sl.k), mx = l >= enMax, cost = c.enCost(l);
            return fg(
              icon: uiImg(slotImg[sl.k]!, size: 30),
              name: nm(sl.n, l),
              cost: mx ? Text('최대', style: costStyle) : iconNum(oreIcon, '$cost', style: costStyle),
              onTap: mx || ore < cost ? null : () => g.act((a) => a.enhanceSlot(sl.k)),
            );
          }(),
      ], 3),
      const KdSec('동료 전용 무기', small: '단계마다 그 동료 공격·체력 +8%'),
      grid([
        for (final id in compWeapon.keys)
          () {
            final j = s.isJoined(id), l = c.cwLv(id), mx = l >= cwMax, o = c.cwOre(l), gd = c.cwGold(l);
            return fg(
              icon: j
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 40, height: 40, child: FaceImg(id)))
                  : const SizedBox(width: 40, height: 40, child: Center(child: Text('🔒', style: TextStyle(fontSize: 22)))),
              name: j ? nm('${comps[id]!.n}의 ${compWeapon[id]}', l) : nm('???', l),
              cost: !j
                  ? Text('합류 전', style: costStyle)
                  : mx
                      ? Text('최대', style: costStyle)
                      : Column(children: [iconNum(oreIcon, '$o', style: costStyle), iconNum(goldIcon, fmt(gd), style: costStyle)]),
              onTap: !j || mx || ore < o || s.gold < gd ? null : () => g.act((a) => a.enhanceWeapon(id)),
            );
          }(),
      ], 2),
    ]);
  }
}
