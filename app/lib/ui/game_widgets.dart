/// 게임 전용 부품 — 성유물 아이콘·장비 비교 카드·동료 초상 틀·등급 표·별·스킬 상자·스프라이트 한 칸
library;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import 'fx.dart';
import 'theme.dart';
import 'widgets.dart';

const frameNames = ['normal', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];
const slotImg = {'weapon': 'slot_weapon', 'helm': 'slot_hat', 'armor': 'slot_armor', 'gloves': 'slot_gloves', 'boots': 'slot_boots', 'ring': 'slot_ring'};

Color gradeColor(int g) => Color(hexColor(itemGrades[g].color));
Color compColor(String id) => id == 'kael' ? const Color(0xFFFFD34A) : Color(hexColor(GameCalc.gr(id).color));

/// relicSrc(it): 등급 단계별 성유물 그림 (1 기본 · 2 정예 · 3 전설)
String relicSrc(Relic it) => 'assets/game/relic/relic_${it.slot}_${it.g < 2 ? 1 : it.g < 4 ? 2 : 3}.png';

/// 성유물 아이콘 (웹 relicIcon): 등급 테두리 + 그림
class RelicIcon extends StatelessWidget {
  const RelicIcon(this.it, {super.key, this.size = 76});
  final Relic? it;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          Positioned.fill(child: Opacity(opacity: it == null ? .45 : 1, child: uiImg('frame_${frameNames[it?.g ?? 0]}', size: size))),
          if (it != null)
            Positioned.fill(
              left: size * .14,
              top: size * .14,
              right: size * .14,
              bottom: size * .14,
              child: Container(
                decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x73000000), blurRadius: 3, offset: Offset(0, 2))], shape: BoxShape.circle),
                child: kdImg(relicSrc(it!)),
              ),
            ),
        ]),
      );
}

/// 장비 비교 카드 (웹 card(it,cap,vs)) — [vs] 를 주면 능력치 옆에 ▲▼ 차이
class RelicCard extends StatelessWidget {
  const RelicCard(this.it, this.cap, this.c, {super.key, this.vs, this.compare = false});
  final Relic? it;
  final String cap;
  final GameCalc c;
  final Relic? vs;
  final bool compare;

  @override
  Widget build(BuildContext context) {
    final r = it;
    final col = r == null ? KdColors.line : gradeColor(r.g);
    Widget statRow(String n, num v, num? d) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(n, style: KdText.body(12, color: KdColors.muted)),
            const SizedBox(width: 4),
            Text('+${fmt(v)}', style: KdText.figure(12)),
            if (d != null && d.abs() >= 1) ...[
              const SizedBox(width: 4),
              Text('${d > 0 ? '▲' : '▼'}${fmt(d.abs())}', style: KdText.figure(11, color: d > 0 ? KdColors.good : const Color(0xFFFF8A7A))),
            ],
          ],
        ));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: col, width: 2)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(cap, style: KdText.body(12, color: KdColors.muted).copyWith(letterSpacing: .7)),
        const SizedBox(height: 4),
        RelicIcon(r),
        const SizedBox(height: 4),
        if (r == null) ...[
          Text('비어 있음', style: KdText.display(15, color: KdColors.muted)),
          Text('빈 칸', style: KdText.body(12, color: KdColors.muted)),
        ] else ...[
          Text(itemGrades[r.g].n, style: KdText.body(12, color: col)),
          Text('${slotDef(r.slot).n} Lv.${r.lv}', textAlign: TextAlign.center, style: KdText.display(15)),
          const SizedBox(height: 2),
          () {
            final m = c.enMul(r.slot);
            num? d(num v, num? o) => compare ? v * m - (o ?? 0) * m : null;
            return Column(children: [
              statRow('공격', r.atk * m, d(r.atk, vs?.atk)),
              statRow('체력', r.hp * m, d(r.hp, vs?.hp)),
            ]);
          }(),
          if (c.enLv(r.slot) > 0) Text('대장간 +${c.enLv(r.slot)} 적용', style: KdText.body(11, color: const Color(0xFFFFB35A))),
        ],
      ]),
    );
  }
}

/// 스프라이트 시트에서 한 칸 (가로로 이어 붙인 정사각형 칸)
class SpriteFrame extends StatelessWidget {
  const SpriteFrame(this.asset, {super.key, required this.frames, required this.index, required this.size});
  final String asset;
  final int frames, index;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: size * frames,
            minWidth: size * frames,
            maxHeight: size,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(-index * size, 0),
              child: Image.asset(asset, width: size * frames, height: size, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
          ),
        ),
      );
}

/// 동료 초상 + 등급 테두리 (웹 .cfr)
class CompFrame extends StatelessWidget {
  const CompFrame(this.id, {super.key, this.w = 62, this.h = 74, this.dim = false, this.hidden = false});
  final String id;
  final double w, h;

  /// 흑백 (아직 맞이하지 않음)
  final bool dim;

  /// 검게 (아직 모름)
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fr = id == 'kael' ? 'legendary' : GameCalc.gr(id).frame;
    Widget face = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: w - 10,
        height: h - 12,
        color: KdColors.panel2,
        child: hidden ? const ColoredBox(color: Color(0xFF0D1220)) : FaceImg(id),
      ),
    );
    if (dim) face = filtered(face, gray: .85, bright: .75);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        face,
        Positioned(left: -4, top: -4, right: -4, bottom: -4, child: kdImg('assets/game/ui/frame_$fr.png', fit: BoxFit.fill)),
      ]),
    );
  }
}

/// 등급 표 (웹 .gtag)
class GradeTag extends StatelessWidget {
  const GradeTag(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final g = GameCalc.gr(id), col = Color(hexColor(g.color));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(border: Border.all(color: col), borderRadius: BorderRadius.circular(6)),
      child: Text(g.n, style: KdText.body(11, color: col, weight: FontWeight.w600, height: 1.45)),
    );
  }
}

/// ★★☆ (웹 starTxt)
class Stars extends StatelessWidget {
  const Stars(this.c, this.id, {super.key});
  final GameCalc c;
  final String id;

  @override
  Widget build(BuildContext context) {
    final st = c.recStar(id), mx = c.starMax(id);
    return Text('${'★' * st}${'☆' * (mx - st)}', style: const TextStyle(color: Color(0xFFFFD34A), fontSize: 12, letterSpacing: 1));
  }
}

/// 직업 아이콘 (웹 .jobi)
Widget jobIcon(String job, {double size = 16}) => kdImg('assets/game/ui/job_$job.png', w: size, h: size);

/// 스킬 상자 (웹 .skl)
class SkillBox extends StatelessWidget {
  const SkillBox(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context) => _skl(kdImg('assets/game/skills/skill_$id.png', w: 28, h: 28), skills[id]!.n, skills[id]!.d, false);
}

/// 전설 동료 마을 스킬 (웹 vpBox)
class VillageSkillBox extends StatelessWidget {
  const VillageSkillBox(this.c, this.id, {super.key});
  final GameCalc c;
  final String id;

  @override
  Widget build(BuildContext context) {
    final name = villageSkillName[id];
    if (name == null) return const SizedBox.shrink();
    final st = c.recStar(id) < 1 ? 1 : c.recStar(id);
    final d = switch (id) {
      'brida' => '광산 광석 생산 +${GameCalc.vpPct(st)}%',
      'makrye' => '낚시터 생선 생산 +${GameCalc.vpPct(st)}%',
      'malbong' => '양봉장 꿀 생산 +${GameCalc.vpPct(st)}%',
      'deokbae' => '요리 버프 시간 +${GameCalc.vpPct(st)}%',
      'kael_chief' => '마을 건물 생산 +${pctTxt(GameCalc.chPct(st))}%',
      _ => '',
    };
    return _skl(uiImg('village_skill', size: 28), '마을 스킬 · $name', '$d${c.owned(id) ? ' · 출전하지 않아도 늘 적용' : ' · 합류하면 적용'}', true);
  }
}

Widget _skl(Widget icon, String n, String d, bool village) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: village ? const Color(0x14FFC23A) : const Color(0x14FFC94A),
        border: Border.all(color: village ? const Color(0x99FFC23A) : const Color(0x40FFC94A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        icon,
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: KdText.body(12, color: village ? const Color(0xFFFFC23A) : KdColors.gold, weight: FontWeight.w600)),
            Text(d, style: KdText.body(12, color: KdColors.muted)),
          ]),
        ),
      ]),
    );

/// 아이콘 + 숫자 (웹 costBtn 의 .bc / chip)
/// 자리가 모자라면 줄여서 보여 줌 (좁은 폰·큰 숫자)
Widget iconNum(String icon, String v, {double size = 18, TextStyle? style}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        kdImg(icon, w: size, h: size),
        const SizedBox(width: 3),
        Text(v, style: style ?? KdText.figure(13)),
      ]),
    );

const goldIcon = 'assets/game/ui/ui_gold.png';
const gemIcon = 'assets/game/gem/ui_gem.png';
const oreIcon = 'assets/game/ui/item_ore.png';

/// 등급 확률·개수 칩 (웹 .odds span: 색 네모 + 글자)
Widget oddsChip(Color c, String t, {double size = 12}) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(t, style: KdText.figure(size, weight: FontWeight.w400)),
    ]);
