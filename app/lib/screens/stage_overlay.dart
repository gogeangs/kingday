/// 전투 화면 위 표시 — 웹 .ovtop(영지 표시줄·보스 막대·버프) / .ovbottom(원정대 초상화·빠른 버튼)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/sim.dart';
import '../core/calc.dart';
import '../core/challenge.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/village.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

double _c01(num v) => v.isNaN ? 0 : v < 0 ? 0 : v > 1 ? 1 : v.toDouble();

// ════════════════════ 위: 영지·보스·버프 ════════════════════
class StageTop extends StatelessWidget {
  const StageTop(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, st = s.stage, r = GameCalc.region(st), boss = g.sim.boss, h = g.sim.ch;
    var label = st > maxLand ? '왕궁 뜰' : '${(st - 1) ~/ 10 + 1}-${(st - 1) % 10 + 1} ${r.n}';
    var sub = st > maxLand ? '보스 없이 사냥 중 · 1부 완결' : '${GameCalc.terrName(st)} 탈환전';
    // 도전 중: 탑 층·규칙 / 던전 남은 시간·처치 수·별 (웹 chHud)
    if (h != null && h.mode == 'tower') {
      final i = h.info!;
      label = '시련의 탑 ${i.f}층';
      sub = (i.gate ? '수문장' : i.rule >= 0 ? '시련 · ${towerRules[i.rule].n}' : '최고 ${g.calc.towerTop()}층') + (h.pm >= pkShow ? ' · 추억 ×${pmText(h.pm)}' : '');
    } else if (h != null) {
      label = '${dunDef(h.k).n} · 단계 ${h.l}';
      sub = '⏱ ${mmss(math.max(0, h.t))} · ${h.kills}마리${h.pm >= pkShow ? ' · 추억 ×${pmText(h.pm)}' : ''}';
    }
    final gd = g.state.raw['guideOff'] == true ? null : g.calc.guideNow();
    // 오른쪽 위에 우편함·랭킹 버튼이 있으면 그만큼 비움 (웹 .ovtop padding-inline:8px 58px)
    return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 58, 0), // 오른쪽 위 버튼 줄(상점은 늘 있음)
        child: Column(
          children: [
            // .toprow: 영지 표시줄 + 다음 할 일
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
            IgnorePointer(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xE00A0E1A), Color(0xD1141A29)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                border: Border.all(color: const Color(0x8CFFC94A)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.display(14).copyWith(letterSpacing: .3)),
                    if (sub.isNotEmpty)
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(11.5, color: KdColors.muted, height: 1.2)),
                  ]),
                ),
                if (h == null) ...[const SizedBox(width: 8), _pips(s.wave, boss != null, st <= maxLand)],
                if (h != null && h.mode == 'dun') ...[
                  const SizedBox(width: 8),
                  for (final n in dunStars)
                    Text('★', style: TextStyle(fontSize: 13, height: 1, color: h.kills >= n ? KdColors.gold : const Color(0x40FFFFFF))),
                ],
              ]),
            )),
            if (h != null) _ChBtn('나가기', onTap: g.chExitTap),
            if (h != null && h.mode == 'tower' && h.st == 'win') _ChBtn('다음 층 ▶', gold: true, onTap: g.chNextTap),
            if (gd != null && h == null) _GuidePill(g, gd.k, gd.t),
            ]),
            if (boss != null) ...[const SizedBox(height: 6), IgnorePointer(child: _BossBar(g, boss))],
            const SizedBox(height: 6),
            IgnorePointer(child: _Buffs(g)),
          ],
        ),
    );
  }

  Widget _pips(int wave, bool boss, bool hasBoss) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 10; i++)
          Container(
            width: 8,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: i < wave ? KdColors.gold : const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(3)),
          ),
        // 61 왕궁 뜰은 보스 칸 없음
        if (hasBoss) Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: boss ? KdColors.bad : const Color(0xFF3A1420),
            shape: BoxShape.circle,
            border: Border.all(color: KdColors.bad, width: 2),
            boxShadow: boss ? const [BoxShadow(color: KdColors.bad, blurRadius: 10)] : null,
          ),
          child: OverflowBox(maxWidth: 20, maxHeight: 20, child: uiImg('ui_boss_mark', size: 20)),
        ),
      ]);
}

/// 도전 중 위쪽 버튼 (웹 .chx)
class _ChBtn extends StatelessWidget {
  const _ChBtn(this.t, {required this.onTap, this.gold = false});
  final String t;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: gold ? null : const Color(0xE00A0E1A),
            gradient: gold ? const LinearGradient(colors: [Color(0xFFFFCF4A), Color(0xFFE9A91C)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            border: Border.all(color: gold ? const Color(0xFFFFE08A) : const Color(0x99FFC94A)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(t, style: KdText.body(13, color: gold ? const Color(0xFF3A2300) : const Color(0xFFFFE08A), weight: FontWeight.w700, height: 1.2)),
        ),
      );
}

/// 다음 할 일 (웹 .guide, FIRST_DAY 3-3): 문구는 늘 보이고 넘치면 말줄임. 누르면 그곳으로
class _GuidePill extends StatelessWidget {
  const _GuidePill(this.g, this.k, this.t);
  final GameController g;
  final String k, t;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          g.haptic(const [8]);
          g.guideGo(k);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            color: const Color(0xE00A0E1A),
            border: Border.all(color: const Color(0x997BE08F)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: KdColors.good, borderRadius: BorderRadius.circular(999)),
              child: Text('할 일', style: KdText.body(10.5, color: const Color(0xFF0D1A10), weight: FontWeight.w600, height: 1.2)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(12, color: const Color(0xFFE9F4EA), height: 1.2)),
            ),
            const SizedBox(width: 6),
            Text('›', style: KdText.body(13, color: KdColors.good, weight: FontWeight.w600, height: 1.1)),
          ]),
        ),
      );
}

class _BossBar extends StatelessWidget {
  const _BossBar(this.g, this.b);
  final GameController g;
  final Mon b;

  @override
  Widget build(BuildContext context) {
    // 왕도: 잔영은 군단장처럼 보라, 마왕은 1단계 보라 → 2단계 금 (웹 .bossbar.cmd/.dem/.gold)
    final st = g.calc.fightSt(), h = g.sim.ch, ti = h?.info;
    // 시련의 탑: 층 태그·층 이름, 수문장·잔영은 보라 (웹 towerSpawn)
    final cmd = ti != null ? (ti.gate || ti.art.ghost != null) : GameCalc.isLord(st) || b.ghost != null, gold = b.dem && b.ph2;
    final left = math.max(0, g.sim.bossT), hurry = left <= 10;
    final tag = ti != null ? '${ti.f}층' : b.dem ? '마왕' : b.ghost != null ? '잔영' : b.guard ? '근위대장' : cmd ? '군단장' : '성주';
    final faceId = ti != null ? (ti.face ?? 'baltasar') : b.dem ? 'baltasar' : b.ghost != null ? bossIds[b.ghost!] : bossIds[GameCalc.regionIndex(st) % bossIds.length];
    final showFace = ti != null ? ti.face != null : cmd;
    // 쌍둥이: 보스 2마리 체력 합
    num bhp = 0, bmax = 0;
    for (final m in g.sim.mons) {
      if (m.boss) {
        bhp += math.max(0, m.hp);
        bmax += m.max;
      }
    }
    final blink = hurry && (g.sim.time * 4).floor().isEven;
    return Container(
      width: math.min(320, MediaQuery.sizeOf(context).width * .92),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cmd ? const [Color(0xEB240E34), Color(0xEB0E0818)] : const [Color(0xE6280810), Color(0xE60E0814)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: hurry ? const Color(0xFFFF4D63) : gold ? const Color(0xFFFFD34A) : cmd ? const Color(0xFFC9A2FF) : const Color(0xB3FF6B7D)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 4)),
          if (cmd) const BoxShadow(color: Color(0x59AA6EFF), blurRadius: 14),
        ],
      ),
      child: Row(children: [
        if (showFace)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 38,
                height: 38,
                // 잔영은 보랏빛 반투명, 마왕은 1단계 「검은 왕」 → 2단계 「옛 왕」 얼굴
                child: b.ghost != null
                    ? Opacity(opacity: .8, child: filtered(FaceImg(faceId, mood: gold ? 'laugh' : 'idle'), sat: 1.6, bright: .9, gray: .4))
                    : FaceImg(faceId, mood: gold ? 'laugh' : 'idle'),
              ),
            ),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: cmd ? null : const Color(0xFFB8233A),
                  gradient: gold
                      ? const LinearGradient(colors: [Color(0xFFFFD34A), Color(0xFFC98A12)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                      : cmd
                          ? const LinearGradient(colors: [Color(0xFFA35CFF), Color(0xFF6A2FC0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                          : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(tag, style: KdText.body(10, color: gold ? const Color(0xFF2A1A00) : Colors.white, weight: FontWeight.w600, height: 1.3)),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(ti != null ? ti.name : GameCalc.bossName(st), overflow: TextOverflow.ellipsis, style: KdText.display(12))),
              Opacity(
                opacity: blink ? .35 : 1,
                child: Text('${left.ceil()}초', style: KdText.figure(12, color: hurry ? const Color(0xFFFF4D63) : const Color(0xFFFFD6DC))),
              ),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                height: 13,
                child: Stack(fit: StackFit.expand, children: [
                  const ColoredBox(color: Color(0x1FFFFFFF)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _c01(bmax > 0 ? bhp / bmax : 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gold
                              ? const [Color(0xFFFFE58A), Color(0xFFD99A1C)]
                              : cmd
                                  ? const [Color(0xFFD6A6FF), Color(0xFF8A3FE0)]
                                  : const [Color(0xFFFF8A98), Color(0xFFE0344C)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // 마왕: 체력바 가운데 50% 눈금
                  if (b.dem) const Align(child: SizedBox(width: 2, child: ColoredBox(color: Color(0xBFFFFFFF)))),
                  Center(
                    child: Text('${fmt(bhp)} / ${fmt(bmax)}',
                        style: KdText.figure(10, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 2)])),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            XpBar(_c01(left / g.sim.bossLimit), height: 2, color: KdColors.gold, bg: const Color(0x1AFFFFFF)),
          ]),
        ),
      ]),
    );
  }
}

/// 요리 버프·스킬 지속 시간 (웹 #buffs)
class _Buffs extends StatelessWidget {
  const _Buffs(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    // (그림, 이름, 남은 시간, 스킬?) — 3개 이상이면 이름은 빼고 그림 + 시간만 한 줄로 (웹 .buff.sm, UX 점검 9)
    final now = g.calc.now, items = <(Widget, String, String, bool)>[];
    for (final b in buffName.keys) {
      if (!g.calc.buff(b)) continue;
      final dish = recipes.firstWhere((r) => r.buff == b).k;
      items.add((
        Image.asset('assets/game/ui/buff_$b.png', width: 26, height: 26,
            errorBuilder: (_, __, ___) => kdImg('assets/game/ui/dish_$dish.png', w: 26, h: 26)),
        buffName[b]!,
        mmss((asNum(g.state.buffs[b]) - now) / 1000),
        false,
      ));
    }
    // 예배당 축복 (요리 버프와 따로, 함께 적용)
    final bk = g.calc.blessK();
    if (bk.isNotEmpty) {
      final left = ((orNum(asMap(g.state.raw['bless'])?['until'], 0) - now) / 1000).ceil();
      final h = left ~/ 3600, hm = h > 0 ? '$h:${'${left % 3600 ~/ 60}'.padLeft(2, '0')}:${'${left % 60}'.padLeft(2, '0')}' : mmss(left);
      items.add((kdImg('assets/game/ui/bless_$bk.png', w: 26, h: 26), blessDef(bk).s, hm, false));
    }
    final sk = g.sim.skx;
    for (final (v, id) in [(sk.shield, 'bron'), (sk.honey, 'riel'), (sk.feast, 'margo')]) {
      if (v > 0) items.add((kdImg('assets/game/skills/skill_$id.png', w: 26, h: 26), skills[id]!.n, '${v.ceil()}초', true));
    }
    if (items.isEmpty) return const SizedBox();
    final sm = items.length >= 3;
    return Wrap(alignment: WrapAlignment.center, spacing: sm ? 3 : 4, runSpacing: 4, children: [
      for (final (icon, n, t, skill) in items) _chip(icon, sm ? t : '$n $t', skill, sm),
    ]);
  }

  Widget _chip(Widget icon, String t, bool skill, bool sm) => Container(
        padding: EdgeInsets.fromLTRB(sm ? 1 : 2, 2, sm ? 6 : 8, 2),
        decoration: BoxDecoration(
          color: const Color(0x8C000000),
          border: Border.all(color: skill ? const Color(0xFF9CC3FF) : const Color(0x99FFC94A)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: sm ? 20 : 22, height: 18, child: OverflowBox(maxWidth: sm ? 22 : 26, maxHeight: sm ? 22 : 26, child: icon)),
          SizedBox(width: sm ? 2 : 4),
          Text(t, style: KdText.figure(sm ? 10.5 : 11, color: skill ? const Color(0xFFDBE8FF) : KdColors.gold, weight: FontWeight.w400)),
        ]),
      );
}

// ════════════════════ 아래: 원정대·빠른 버튼 ════════════════════
class StageBottom extends StatelessWidget {
  const StageBottom(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final ids = g.calc.members(), manual = g.state.raw['autoSkill'] == false;
    final cost = g.calc.boxCost(), tb = g.acts.ticketN('box'), canBox = g.state.gold >= cost || tb > 0;
    final x2 = g.game.speed == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x000A0E1A), Color(0xD90A0E1A), Color(0xD90A0E1A)],
          stops: [0, .4, 1],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: LayoutBuilder(key: g.partyRowKey, builder: (_, c) {
            final w = math.min(52.0, c.maxWidth * .17);
            return Row(children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                SizedBox(width: w, child: i < ids.length ? _MemberCard(g, ids[i], manual) : const _EmptyCard()),
              ],
            ]);
          }),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          _QBtn(
            round: true,
            img: 'relic_chest',
            label: tb > 0 ? '무료 $tb' : fmt(cost),
            dim: !canBox,
            hint: DateTime.now().millisecondsSinceEpoch - g.hintBoxAt < 2500,
            onTap: () => g.openBox(),
          ),
          const SizedBox(height: 10),
          _QBtn(img: 'btn_auto', label: manual ? '자동 끔' : '자동 켬', dim: manual, on: !manual, onTap: () {
            g.state.raw['autoSkill'] = manual;
            g.toast(manual ? '스킬 자동 사용 켜짐' : '스킬 자동 사용 꺼짐 · 빛나는 초상화를 눌러 쓰세요');
            g.refresh();
          }),
          const SizedBox(height: 10),
          _QBtn(img: x2 ? 'btn_x2' : 'btn_x1', label: x2 ? 'x2' : 'x1', on: x2, onTap: () {
            g.state.raw['speed'] = x2 ? 1 : 2;
            g.refresh();
          }),
        ]),
      ]),
    );
  }
}

class _QBtn extends StatelessWidget {
  const _QBtn({required this.img, required this.label, required this.onTap, this.on = false, this.dim = false, this.round = false, this.hint = false});
  final String img, label;
  final VoidCallback onTap;
  final bool on, dim, round;

  /// 안내: 초록 고리로 깜빡 (웹 .qbtn.hint)
  final bool hint;

  @override
  Widget build(BuildContext context) {
    Widget pic = round
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC9952A), width: 2),
              gradient: const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3A2A12), Color(0xFF16110A)]),
              boxShadow: [
                hint
                    ? BoxShadow(color: const Color(0xCC7BE08F), spreadRadius: 4 + 2 * math.sin(DateTime.now().millisecondsSinceEpoch / 100))
                    : const BoxShadow(color: Color(0x59000000), spreadRadius: 3),
              ],
            ),
            alignment: Alignment.center,
            child: uiImg(img, size: 34),
          )
        : Container(
            decoration: on ? const BoxDecoration(boxShadow: [BoxShadow(color: Color(0xCCFFD23C), blurRadius: 6)], shape: BoxShape.circle) : null,
            child: uiImg(img, size: 50),
          );
    if (dim) pic = filtered(pic, gray: round ? .8 : .85, bright: round ? .7 : .65);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 50,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: round ? 46 : 50, child: Center(child: pic)),
          const SizedBox(height: 2),
          // 글자 자리를 따로 잡고 어두운 바탕을 깔아 다음 버튼·배경과 겹치지 않게 (웹 .qbtn small)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: const Color(0xD10A0E1A), borderRadius: BorderRadius.circular(8)),
            child: Text(label, maxLines: 1, style: KdText.figure(10, weight: FontWeight.w600).copyWith(height: 1.45)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(3),
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x4D000000),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF3A4568)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      );
}

/// 원정대 초상화 (웹 .pcard) — 둘레 금색 고리가 스킬 게이지
class _MemberCard extends StatelessWidget {
  const _MemberCard(this.g, this.id, this.manual);
  final GameController g;
  final String id;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final p = g.sim.party[id], sk = skills[id]!;
    final hp = p == null ? 1.0 : _c01(p.hp / g.calc.stats(id).hp);
    final gauge = p == null ? 0.0 : _c01(p.sg / sk.need);
    final ready = g.sim.skFull(id), down = p?.down ?? false;
    final bob = ready ? math.sin(g.sim.time * 7) * 1.5 : 0.0;
    Widget pic = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFC9952A)),
        gradient: const LinearGradient(colors: [Color(0xFF2C4A7A), Color(0xFF18233D)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: FaceImg(id)),
    );
    if (down) pic = filtered(pic, gray: 1, bright: .6);
    return GestureDetector(
      onTap: _tap,
      onLongPress: () => _info(),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Transform.translate(
          offset: Offset(0, bob),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(clipBehavior: Clip.none, children: [
              // 고리
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: ready
                        ? const LinearGradient(colors: [Color(0xFFFFF2B0), KdColors.gold, Color(0xFFFF9A3A)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                        : SweepGradient(
                            transform: const GradientRotation(-math.pi / 2),
                            colors: const [KdColors.gold, KdColors.gold, Color(0x24FFFFFF), Color(0x24FFFFFF)],
                            stops: [0, gauge, gauge, 1],
                          ),
                    boxShadow: ready ? const [BoxShadow(color: Color(0xE6FFC94A), blurRadius: 12)] : null,
                  ),
                ),
              ),
              Positioned.fill(child: Padding(padding: const EdgeInsets.all(3), child: pic)),
              // 스킬 아이콘
              Positioned(
                right: -7,
                bottom: -7,
                width: 22,
                height: 22,
                child: Transform.scale(
                  scale: ready ? 1.2 : 1,
                  child: ready
                      ? Container(
                          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: KdColors.gold, blurRadius: 5)], shape: BoxShape.circle),
                          child: kdImg('assets/game/skills/skill_$id.png'),
                        )
                      : filtered(kdImg('assets/game/skills/skill_$id.png'), gray: .6, bright: .85),
                ),
              ),
              if (ready && manual)
                Positioned(
                  top: -10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: KdColors.gold,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1))],
                      ),
                      child: Text('탭!', style: KdText.body(10, color: KdColors.goldInk, weight: FontWeight.w600, height: 1.5)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        XpBar(hp, height: 4, color: down ? Colors.grey : KdColors.good, bg: const Color(0x26FFFFFF)),
      ]),
    );
  }

  void _tap() {
    final p = g.sim.party[id], sk = skills[id]!;
    if (g.sim.skFull(id) && g.sim.engaged) {
      g.sim.castSkill(id);
      g.haptic();
      return;
    }
    if (p != null && p.down) {
      g.toast('${comps[id]!.n}은(는) 쓰러져 있어요');
    } else if (!g.sim.engaged && g.sim.skFull(id)) {
      g.toast('싸우는 중에만 쓸 수 있어요');
    } else {
      g.toast('${sk.n} · 게이지 ${((p?.sg ?? 0) / sk.need * 100).floor()}%');
    }
  }

  /// 길게 누르기: 스킬 설명 (웹 skTip)
  void _info() {
    final p = g.sim.party[id], sk = skills[id]!;
    g.openSheet<void>((c) => KdSheetBody(
          eyebrow: '${comps[id]!.n} 특수 스킬',
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              kdImg('assets/game/skills/skill_$id.png', w: 56, h: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sk.n, style: KdText.display(18, color: KdColors.gold)),
                  const SizedBox(height: 4),
                  Text(sk.d, style: KdText.body(13, height: 1.5)),
                  const SizedBox(height: 8),
                  XpBar(_c01((p?.sg ?? 0) / sk.need)),
                ]),
              ),
            ]),
            Para('m:${comps[id]!.n}|${sk.line}'),
          ],
          acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(c).pop())]),
        ));
  }
}
