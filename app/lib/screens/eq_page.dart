/// 장비 탭 — 웹 #p-eq (장비 칸 6개 + 카엘, 성유물 상자, 능력치, 브론의 대장간)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/battle_data.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/village.dart';
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
    final s = g.state, c = g.calc, odds = c.odds(), cost = c.boxCost();
    final tb = g.acts.ticketN('box'), t10 = g.acts.ticketN('box10');
    final can = (s.gold >= cost || tb > 0) && g.acts.pending == null;
    return KdBox(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text('성유물 상자 Lv.${s.boxLv}', style: KdText.display(16))),
        Text('${s.boxXp} / ${c.xpNeed()}', style: KdText.figure(13, color: KdColors.muted, weight: FontWeight.w400)),
      ]),
      XpBar(s.boxXp / c.xpNeed()),
      Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var i = 0; i < itemGrades.length; i++)
          if (odds[i] > 0 || i < 6) oddsChip(gradeColor(i), '${itemGrades[i].n} ${_oddsTxt(odds[i])}%'),
        GestureDetector(
          key: const ValueKey('oddsAll'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _oddsSheet(),
          // 누르는 범위만 넓힘 (웹 #oddsAll::after)
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('레벨별 확률표', style: KdText.body(12, color: KdColors.gold).copyWith(decoration: TextDecoration.underline, decorationColor: KdColors.gold))),
        ),
      ]),
      Wrap(spacing: 14, runSpacing: 8, children: [
        _toggle('약한 장비 바로 판매', 'autoSell'),
        _toggle('자동 열기', 'autoOpen'),
      ]),
      _openBtn(
        '상자 열기',
        tb > 0
            ? Text('무료권 $tb장', style: KdText.body(14, weight: FontWeight.w700, color: KdColors.goldInk.withValues(alpha: .75)))
            : iconNum(goldIcon, fmt(cost), size: 20, style: KdText.figure(14, color: can ? KdColors.goldInk.withValues(alpha: .75) : KdColors.muted)),
        can ? () => g.openBox() : null,
      ),
      _openBtn(
        '10연속 열기',
        t10 > 0
            ? Text('무료권 $t10장', style: KdText.body(14, weight: FontWeight.w700, color: const Color(0xBFFFE08A)))
            : iconNum(gemIcon, '$gem10', size: 20, style: KdText.figure(14, color: const Color(0xBFFFE08A))),
        g.acts.pending == null ? () => g.act((a) => a.open10()) : null,
        gem: true,
      ),
      const KdNote('10연속은 영웅 등급 이상 1개 확정이에요. 등급별 확률은 위와 같아요. 더 좋은 장비는 바로 장착하고 나머지는 팔아요.'),
      const KdNote('행상인 피트의 성유물은 카엘만 착용해요.'),
    ]);
  }

  static String _oddsTxt(num v) => v < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);

  /// 레벨별 확률표 (유료 확률형 아이템 확률 공개, 웹 oddsSheet)
  void _oddsSheet() {
    final c = g.calc, cur = g.state.boxLv;
    final ls = {1, 5, 10, 20, 31, 40, 50, cur}.toList()..sort();
    TableRow row(String lv, List<num> o, {bool hi = false}) => TableRow(
          decoration: BoxDecoration(color: hi ? const Color(0x1FFFC94A) : null, border: const Border(bottom: BorderSide(color: Color(0x0FFFFFFF)))),
          children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(lv, style: KdText.figure(11.5, color: hi ? const Color(0xFFFFE7A6) : KdColors.muted, weight: FontWeight.w400))),
            for (final v in o)
              Text(v > 0 ? _oddsTxt(v) : '—', textAlign: TextAlign.right, style: KdText.figure(11.5, color: hi ? const Color(0xFFFFE7A6) : KdColors.fg, weight: FontWeight.w400)),
          ],
        );
    g.openSheet((ctx) => KdSheetBody(
          eyebrow: '성유물 상자',
          title: '레벨별 확률표',
          children: [
            Table(
              key: const ValueKey('oddsTable'),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FlexColumnWidth(.8)},
              children: [
                TableRow(children: [
                  Text('Lv', style: KdText.body(11.5, color: KdColors.muted)),
                  for (var i = 0; i < itemGrades.length; i++)
                    Text(itemGrades[i].n, textAlign: TextAlign.right, style: KdText.body(11.5, color: gradeColor(i), weight: FontWeight.w600)),
                ]),
                for (final l in ls) row('$l', c.odds(l, true), hi: l == cur),
                row('끝', c.odds(9999, true)),
              ],
            ),
            KdNote('단위 %. 상자 레벨은 끝이 없고, Lv.11부터 좋은 등급이 조금씩 더 잘 나오지만 「끝」 줄을 넘지 않아요. 「태초」는 첫 은퇴를 한 뒤 Lv.31부터 나와요${c.primalOn() ? '' : ' (아직 은퇴 전이라 지금은 안 나와요)'}. 다음 레벨까지 상자 (지금 레벨 × 10)번.'),
          ],
          acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(ctx).pop())]),
        ));
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
                      child: Text('+$en', style: KdText.body(11, color: Colors.white, weight: FontWeight.w600, height: 1.5)),
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
                        style: KdText.body(11, color: it != null ? Colors.white : const Color(0xFFC9CBD6), weight: FontWeight.w600, height: 1.5)),
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
          final sl = slotDef(k), it = g.calc.equipped(k), l = g.calc.enLv(k), mx = l >= g.calc.enMax(), cost = g.calc.enCost(l);
          final ore = orNum(g.state.items['ore'], 0), open = truthy(g.state.bld['forge']);
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
                const KdNote('마을에서 브론의 대장간을 재건하면 강화할 수 있어요.')
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

/// 브론의 대장간 (웹 #forge): 장비 탭에는 버튼 한 줄, 누르면 대장간 창(성유물 강화 | 동료 무기)
class _Forge extends StatelessWidget {
  const _Forge(this.g);
  final GameController g;

  static bool canEn(GameController g) {
    final s = g.state, c = g.calc, ore = orNum(s.items['ore'], 0);
    return truthy(s.bld['forge']) && slots.any((sl) => c.enLv(sl.k) < c.enMax() && ore >= c.enCost(c.enLv(sl.k)));
  }

  static bool canCw(GameController g) {
    final s = g.state, c = g.calc, ore = orNum(s.items['ore'], 0);
    return truthy(s.bld['forge']) &&
        compWeapon.keys.any((id) => s.isJoined(id) && c.cwLv(id) < c.enMax() && ore >= c.cwOre(c.cwLv(id)) && s.gold >= c.cwGold(c.cwLv(id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = g.state, mine = truthy(s.bld['mine']), open = truthy(s.bld['forge']), ore = orNum(s.items['ore'], 0), dot = open && (canEn(g) || canCw(g));
    return KdBox(children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!mine) return g.toast('마을에 광산을 재건하면 브론의 대장간 빈터가 열려요');
          if (!open) {
            g.toast('마을에서 대장간을 재건해요');
            return g.vlSelect('forge', tab: 'info');
          }
          showForgeSheet(g);
        },
        child: Opacity(
          opacity: open ? 1 : .6,
          child: Stack(clipBehavior: Clip.none, children: [
            Row(children: [
              kdImg('assets/game/village/forge_${open ? 'built' : 'ruin'}.png', w: 44, h: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: '브론의 대장간'),
                    if (open) TextSpan(text: '  마을 · Lv.${s.bldLv('forge')}', style: KdText.body(11, color: KdColors.gold, weight: FontWeight.w700)),
                  ]), style: KdText.display(16)),
                  Text(open ? '광석 ${fmt(ore)} · 성유물 강화 · 동료 무기' : mine ? '마을에서 대장간을 재건해요' : '마을에 광산을 재건하면 열려요',
                      style: KdText.body(12, color: KdColors.muted)),
                ]),
              ),
              Text(open ? '열기 ›' : mine ? '마을 ›' : '🔒', style: KdText.body(13, color: KdColors.gold, weight: FontWeight.w700)),
            ]),
            if (dot) const Positioned(top: -2, right: -2, child: KdRedDot()),
          ]),
        ),
      ),
    ]);
  }
}

/// 대장간 창에서 마지막에 본 탭 ('en' 성유물 강화 · 'cw' 동료 무기)
String _forgeTab = 'en';

/// 대장간 「강화」 내용 (장비 탭 바로가기 창과 마을 대장간 창이 같이 씀). [set] 은 다시 그리기
List<Widget> forgeContent(GameController g, void Function(void Function()) set) {
  final s = g.state, c = g.calc, ore = orNum(s.items['ore'], 0), ce = _Forge.canEn(g), cc = _Forge.canCw(g);
  final cut = ((1 - c.forgeCut()) * 100).round();
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
  Widget tab(String k, String label, bool dot) => Expanded(
        child: GestureDetector(
          onTap: () => set(() => _forgeTab = k),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _forgeTab == k ? KdColors.gold : KdColors.panel2,
                border: Border.all(color: _forgeTab == k ? KdColors.gold : KdColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label, style: KdText.body(14, weight: FontWeight.w700, color: _forgeTab == k ? KdColors.goldInk : KdColors.muted)),
            ),
            if (dot) const Positioned(top: -2, right: -2, child: KdRedDot()),
          ]),
        ),
      );
  return [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      iconNum(oreIcon, '광석 ${fmt(ore)}', style: KdText.body(13, weight: FontWeight.w600)),
      const SizedBox(width: 14),
      iconNum(goldIcon, '골드 ${fmt(s.gold)}', style: KdText.body(13, weight: FontWeight.w600)),
    ]),
    Text('대장간 Lv.${s.bldLv('forge')} · 강화 최대 +${c.enMax()}${cut > 0 ? ' · 광석 −$cut%' : ''}${c.workBonus('forge') > 0 ? ' (일꾼 포함)' : ''}',
        style: KdText.body(12, color: const Color(0xFFFFD9A8))),
    Row(children: [tab('en', '성유물 강화', ce), const SizedBox(width: 6), tab('cw', '동료 무기', cc)]),
    if (_forgeTab == 'en') ...[
      const KdNote('부위마다 강화할 때마다 그 부위 성유물 능력치가 10%씩 올라요. 장비를 바꿔도 강화는 부위에 남아요.'),
      grid([
        for (final sl in slots)
          () {
            final l = c.enLv(sl.k), mx = l >= c.enMax(), cost = c.enCost(l);
            return fg(
              icon: uiImg(slotImg[sl.k]!, size: 30),
              name: nm(sl.n, l),
              cost: mx ? Text('최대', style: costStyle) : iconNum(oreIcon, '$cost', style: costStyle),
              onTap: mx || ore < cost
                  ? null
                  : () {
                      g.act((a) => a.enhanceSlot(sl.k));
                      set(() {});
                    },
            );
          }(),
      ], 3),
    ] else ...[
      const KdNote('단계마다 그 동료 공격·체력 +8%. 광석과 골드가 들어요.'),
      grid([
        for (final id in compWeapon.keys)
          () {
            final j = s.isJoined(id), l = c.cwLv(id), mx = l >= c.enMax(), o = c.cwOre(l), gd = c.cwGold(l);
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
              onTap: !j || mx || ore < o || s.gold < gd
                  ? null
                  : () {
                      g.act((a) => a.enhanceWeapon(id));
                      set(() {});
                    },
            );
          }(),
      ], 2),
    ],
  ];
}

/// 강화할 수 있는지 (마을 할 일 줄 「⚒ 강화 가능」·건물 배지)
bool forgeCanAny(GameController g) => _Forge.canEn(g) || _Forge.canCw(g);

/// 웹 forgeSheet(tab): 장비 탭 바로가기. 창을 닫지 않고 연달아 강화
void showForgeSheet(GameController g) {
  g.openSheet<void>((ctx) => StatefulBuilder(
        builder: (ctx, set) => KdSheetBody(
          eyebrow: '마을 · 대장간 Lv.${g.state.bldLv('forge')}',
          title: '브론의 대장간',
          children: forgeContent(g, set),
          acts: KdActs(buttons: [
            KdAct('닫기', onTap: () => Navigator.of(ctx).pop()),
            KdAct('마을에서 보기', primary: true, onTap: () {
              Navigator.of(ctx).pop();
              g.vlSelect('forge', tab: 'forge');
            }),
          ]),
        ),
      ));
}
