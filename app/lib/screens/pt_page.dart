/// 원정대 탭 — 웹 #p-pt (편성 · 동료 · 카드) + 동료 정보 창(compSheet) + 자리 고르기 창(seatSheet)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/attendance.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/village.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'shop_page.dart' show won;

class PtPage extends StatelessWidget {
  const PtPage(this.g, {super.key});
  final GameController g;

  String get _sub => ptTeam(g) ? 'team' : 'card';

  @override
  Widget build(BuildContext context) {
    final sub = _sub;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 하위 탭 (웹 .subtabs)
      Row(children: [
        // B안 (대표님 결정 10-27): 「원정대 / 카드 도감」 두 탭
        for (final (k, n) in const [('team', '원정대'), ('card', '카드 도감')]) ...[
          if (k != 'team') const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                g.state.raw['ptTab'] = k;
                g.refresh();
              },
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sub == k ? KdColors.gold : KdColors.panel2,
                    border: Border.all(color: sub == k ? KdColors.gold : KdColors.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(n, style: KdText.body(14, color: sub == k ? const Color(0xFF1A1206) : KdColors.muted, weight: FontWeight.w600)),
                ),
                if (k == 'card' && g.calc.cardReady().isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: KdColors.gold, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6B4F12))),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      ...switch (sub) {
        'card' => _cards(),
        _ => _team(),
      },
    ]);
  }

  // ════════ 원정대 (B안): 위 출전 자리 · 동료 얼굴 격자 (★ 별 올리기 · ▲ 출전하면 더 셈) · 아래 상세는 PtPanel ════════
  List<Widget> _team() {
    final c = g.calc, ids = ptOrder(g), sel = ptSelId(g);
    final bb = ptBenchBest(g);
    return [
      ..._form(),
      const SizedBox(height: 6),
      Row(children: [
        Text('동료 ${ids.where(c.owned).length}명', style: KdText.body(14, weight: FontWeight.w700)),
        const Spacer(),
        Text.rich(TextSpan(children: const [
          TextSpan(text: '★', style: TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700)),
          TextSpan(text: ' 별 올리기 · '),
          TextSpan(text: '▲', style: TextStyle(color: Color(0xFF7BE08F), fontWeight: FontWeight.w700)),
          TextSpan(text: ' 출전하면 더 셈'),
        ]), style: KdText.body(11.5, color: KdColors.muted)),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (_, cs) {
        final w = (cs.maxWidth - 18) / 4;
        return Wrap(spacing: 6, runSpacing: 10, children: [for (final id in ids) SizedBox(width: w, child: _gcell(id, pick: true, sel: id == sel, better: bb.contains(id)))]);
      }),
      const SizedBox(height: 4),
      ..._nextGoal(),
    ];
  }

  List<Widget> _form() {
    final c = g.calc;
    final multi = jobSlots.any((j) => j != 'kael' && c.jobMembers(j).length > 1);
    return [
      const KdSec('편성', small: '자리를 눌러 동료를 바꿔요'),
      const SizedBox(height: 8),
      Row(children: [
        for (final j in jobSlots) ...[
          if (j != jobSlots.first) const SizedBox(width: 6),
          Expanded(child: _seat(j)),
        ],
      ]),
      const SizedBox(height: 8),
      KdBuy(text: '추천 편성 · 가장 강한 동료로', kind: BuyKind.ghost, onTap: multi ? () => g.act((a) => a.autoForm()) : null),
    ];
  }

  Widget _seat(String j) {
    final c = g.calc, id = c.slotMember(j);
    final multi = j == 'kael' ? c.owned(GameCalc.chiefId) : c.jobMembers(j).length > 1, better = j != 'kael' && c.betterBench(j);
    return GestureDetector(
      onTap: () {
        if (j == 'kael') return c.owned(GameCalc.chiefId) ? kaelSeatSheet(g) : g.setTab(GameTab.eq);
        if (c.jobMembers(j).length > 1) return seatSheet(g, j);
        g.toast(id != null ? '${comps[id]!.n} · 같은 직업 동료가 더 생기면 바꿀 수 있어요' : '${jobName[j]} 자리 동료가 아직 없어요');
      },
      child: Opacity(
        opacity: id == null ? .55 : 1,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              SizedBox(
                width: 50,
                height: 58,
                child: id != null
                    ? CompFrame(id, w: 50, h: 58)
                    : Center(child: Opacity(opacity: .45, child: filtered(jobIcon(j, size: 40), gray: .7))),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (j != 'kael') ...[jobIcon(j, size: 14), const SizedBox(width: 2)],
                  Text(j == 'kael' ? '카엘' : jobName[j]!, style: KdText.body(12, weight: FontWeight.w600)),
                ]),
              ),
              // ★★★ 대신 ★3, 길면 두 줄까지 (웹 .seat small, UX 점검 14)
              SizedBox(
                width: double.infinity,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: id == null ? '합류 전' : id == 'kael' ? '용사' : comps[id]!.n),
                    if (id != null && id != 'kael' && c.recStar(id) > 0)
                      TextSpan(text: ' ★${c.recStar(id)}', style: const TextStyle(color: KdColors.gold, fontSize: 11)),
                  ]),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: KdText.body(11.5, color: KdColors.muted, height: 1.2),
                ),
              ),
            ]),
          ),
          if (multi) Positioned(top: 4, left: 5, child: Text('⇄', style: KdText.body(12, color: KdColors.gold))),
          if (better)
            Positioned(
              top: 4,
              right: 5,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: KdColors.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }

  /// 다음 목표 (웹 ngoalHtml)
  List<Widget> _nextGoal() {
    final n = g.calc.nextGoal();
    if (n == null) return const [];
    final face = n['face'] == true, id = n['id'] as String, job = n['job'] as String;
    final can = n['can'] == true;
    return [
      const KdSec('다음 목표'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          SizedBox(
            width: 64,
            height: 64,
            child: face ? CompFrame(id, w: 64, h: 64) : Center(child: Opacity(opacity: .45, child: filtered(jobIcon(job, size: 40), gray: .7))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n['title'] as String, style: KdText.body(12.5, color: KdColors.muted)),
              Text(n['name'] as String, style: KdText.display(15)),
              if (face) ...[
                const SizedBox(height: 4),
                XpBar((n['n'] as num) / (n['need'] as num)),
                const SizedBox(height: 4),
                Text('카드 ${n['n']} / ${n['need']}', style: KdText.body(12.5, color: KdColors.muted)),
              ] else
                Text(n['desc'] as String? ?? '', style: KdText.body(12.5, color: KdColors.muted)),
            ]),
          ),
          if (face) ...[
            const SizedBox(width: 8),
            KdBuy(
              text: can ? (g.calc.recStar(id) > 0 ? '★ 올리기' : '맞이하기') : '카드 보기',
              glow: can,
              minWidth: 0,
              onTap: () {
                if (can) {
                  g.act((a) => a.recruitUp(id));
                } else {
                  g.state.raw['ptTab'] = 'card';
                  g.refresh();
                }
              },
            ),
          ],
        ]),
      ),
    ];
  }

  // ════════ 동료 목록 ════════
  /// 격자 칸 (U-1, 웹 gcell): 얼굴 + 등급 테두리 + ★ + Lv. 출전 중 금테, 🔨 일꾼, ★ 올리기 가능 노란 점, 합류 전 어둡게 ???
  Widget _gcell(String id, {bool pick = false, bool sel = false, bool better = false}) {
    final c = g.calc, cd = comps[id]!, has = c.owned(id), kael = id == 'kael', chief = id == GameCalc.chiefId;
    final on = kael || (chief ? c.chiefOn() : c.slotMember(jobOf[id]!) == id);
    final wk = !kael && !chief && c.working()[id] != null;
    final up = chief ? c.chiefCan() : gradeOf[id] == 'unique' ? c.uqCan(id) : c.cardReady().contains(id);
    final named = has || chief;
    final sub = kael
        ? ranks[c.rankIdx()].n
        : has
            ? '${chief ? '' : 'Lv.${orNum(g.state.lv[id], 1)} '}${'★' * c.recStar(id)}'
            : chief
                ? '유니크'
                : '합류 전';
    return GestureDetector(
      key: pick ? ValueKey('tsel-$id') : null,
      onTap: !named
          ? null
          : pick
              ? () {
                  g.ptSel = id;
                  g.refresh();
                }
              : () => kael
                  ? g.setTab(GameTab.eq)
                  : chief
                      ? chiefSheet(g)
                      : compSheet(g, id),
      child: Opacity(
        opacity: has || chief ? 1 : .5,
        child: Container(
          padding: pick ? const EdgeInsets.fromLTRB(2, 9, 2, 5) : const EdgeInsets.fromLTRB(4, 10, 4, 7),
          decoration: BoxDecoration(
            color: KdColors.panel2,
            border: Border.all(color: sel ? Colors.white : on && has ? KdColors.gold : KdColors.line, width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel
                ? const [BoxShadow(color: Color(0x73FFC94A), blurRadius: 12, spreadRadius: 1)]
                : on && has
                    ? const [BoxShadow(color: Color(0x40FFC94A), blurRadius: 10)]
                    : null,
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: CompFrame(id, w: pick ? 48 : 56, h: pick ? 56 : 66, hidden: !named, dim: chief && !has)),
              const SizedBox(height: 4),
              Text(named ? cd.n : '???', maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.display(pick ? 12.5 : 13.5)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(pick ? 11 : 12.5, color: KdColors.muted)),
            ]),
            // 원정대 격자: ★ 별 올리기 · ▲ 출전하면 더 셈 (웹 .gbd)
            if (pick && (up || better))
              Positioned(
                top: -14,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(color: up ? const Color(0xFFFFD34A) : const Color(0xFF7BE08F), borderRadius: BorderRadius.circular(999)),
                  child: Text(up ? '★' : '▲', style: KdText.body(11, color: const Color(0xFF1A1406), weight: FontWeight.w700, height: 1.45)),
                ),
              ),
            if (up && !pick)
              Positioned(
                top: -4,
                right: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFFFFD23A), shape: BoxShape.circle, border: Border.all(color: Colors.white), boxShadow: const [BoxShadow(color: Color(0xFFFFD23A), blurRadius: 6)]),
                ),
              ),
            if (wk) const Positioned(top: -6, left: 2, child: Text('🔨', style: TextStyle(fontSize: 13))),
            if (on && has && !kael)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(color: KdColors.gold, borderRadius: BorderRadius.circular(6)),
                    child: Text('출전', style: KdText.body(10.5, color: KdColors.goldInk, weight: FontWeight.w700, height: 1.4)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ════════ 카드 ════════
  List<Widget> _cards() {
    final c = g.calc;
    // 별 올리기 찾기 (대표님 결정 10-27 ①②③, 웹 cupBar·cmax): 올릴 수 있는 동료 맨 위 · 별을 다 모은 동료는 맨 아래 작은 줄
    final ready = c.cardReady();
    final sorted = stableSorted(stableSorted(GameCalc.cardIds(), (a, b) {
      int key(String x) => (c.cardOpen(x) ? 2 : 0) + (c.owned(x) ? 1 : 0);
      final d = key(b) - key(a);
      return d != 0 ? d : (GameCalc.gr(a).w - GameCalc.gr(b).w).sign.toInt();
    }), (a, b) => (ready.contains(b) ? 1 : 0) - (ready.contains(a) ? 1 : 0));
    bool full(String x) => c.cardOpen(x) && c.recStar(x) >= c.starMax(x);
    bool uqFull(String x) => c.owned(x) && c.recStar(x) >= c.starMax(x);
    final ids = sorted.where((x) => !full(x)).toList();
    final upN = ready.length + (c.chiefCan() ? 1 : 0) + (c.uqCan(GameCalc.ttukId) ? 1 : 0) + (c.uqCan(GameCalc.lucId) ? 1 : 0);
    TextSpan gt(String n, int col) => TextSpan(text: n, style: TextStyle(color: Color(col), fontWeight: FontWeight.w700));
    final uc = c.owned(GameCalc.chiefId) || c.chiefShop() || c.ucard > 0;
    final maxed = [
      for (final u in [GameCalc.chiefId, GameCalc.ttukId, GameCalc.lucId])
        if (uqFull(u)) u,
      ...sorted.where(full),
    ];
    return [
      HelpNote(
        k: 'cardgr',
        title: '카드 등급·얻는 곳',
        seen: g.helpSeen,
        open: g.helpOpen,
        body: Text.rich(
        TextSpan(children: [
          const TextSpan(text: '카드 등급: '),
          gt('일반', 0xFFB8C0CC),
          const TextSpan(text: '(★3까지) · '),
          gt('희귀', 0xFF5AA8FF),
          const TextSpan(text: '(★4) · '),
          gt('영웅', 0xFFB07BFF),
          const TextSpan(text: '(★5) · '),
          gt('전설', 0xFFFFC23A),
          const TextSpan(
              text: '(★5). 높은 등급일수록 드물게 나오고 기본 능력치가 높아요. 마물·성주·군단장·황금 고블린·오늘의 할 일·피트의 상점에서 카드를 얻어요. '
                  '♡ 희망을 눌러 두면 그 동료 카드가 절반 확률로 나와요. 은퇴해도 카드와 별은 남아요.'),
          if (uc) ...[
            const TextSpan(text: ' '),
            gt('유니크', 0xFF3EE08F),
            const TextSpan(text: '(★5)는 카드 뽑기에 나오지 않고, 유니크 카드로만 별을 올려요.'),
          ],
        ]),
        style: KdText.body(12, color: KdColors.muted, height: 1.6),
      ),
      ),
      // 전설 만능 카드 보유 줄 (웹 .lcbar)
      if (g.acts.lcard > 0)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x14FFC23A),
            border: Border.all(color: const Color(0x99FFC23A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            kdImg('assets/game/ui/card_back.png', w: 30, h: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('전설 만능 카드 ${g.acts.lcard}장', style: KdText.body(14, color: const Color(0xFFFFC23A), weight: FontWeight.w700)),
                Text(g.acts.lcardCan() ? '전설 동료 줄의 「만능 … 넣기」로 원하는 동료에게 넣어요' : '전설 동료 카드가 나오기 시작하면 넣을 수 있어요',
                    style: KdText.body(12, color: KdColors.muted)),
              ]),
            ),
          ]),
        ),
      if (upN > 0) _upBar(upN, ready.isNotEmpty),
      if (uc && !uqFull(GameCalc.chiefId)) _ucard(GameCalc.chiefId),
      if (!uqFull(GameCalc.ttukId)) _ucard(GameCalc.ttukId),
      if (!uqFull(GameCalc.lucId)) _ucard(GameCalc.lucId),
      for (final id in ids) _ccard(id),
      if (maxed.isNotEmpty) ...[
        const SizedBox(height: 4),
        KdSec('별을 모두 모은 동료', small: '${maxed.length}명'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final id in maxed)
            GestureDetector(
              key: ValueKey('cmax-$id'),
              onTap: () => id == GameCalc.chiefId ? chiefSheet(g) : compSheet(g, id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: compColor(id)), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(comps[id]!.n, style: KdText.body(12, weight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text('★${c.recStar(id)}', style: KdText.body(11, color: const Color(0xFFFFD34A))),
                ]),
              ),
            ),
        ]),
      ],
    ];
  }

  /// 「★ 올릴 수 있는 동료 N명 · 모두 올리기」 (웹 .cupbar). 유니크 카드는 여러 동료가 나눠 쓰므로 한 명씩 골라 올림
  Widget _upBar(int n, bool cards) => Container(
        key: const ValueKey('cupBar'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0x29FFD34A), Color(0x0AFFD34A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0xFFFFD34A)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '★ 올릴 수 있는 동료 '),
                TextSpan(text: '$n명', style: const TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700)),
              ]), style: KdText.body(13)),
              if (!cards) Text('유니크 카드는 한 동료씩 골라 올려요', style: KdText.body(11, color: KdColors.muted)),
            ]),
          ),
          if (cards) KdBuy(key: const ValueKey('cupAll'), text: '모두 올리기', glow: true, minWidth: 0, onTap: () => ptUpAll(g)),
        ]),
      );

  /// 유니크 카드 줄 (웹 ucRow·ttRow): 카엘 촌장·뚝딱이 별 올리기
  Widget _ucard(String id) {
    final chief = id == GameCalc.chiefId;
    final c = g.calc, cd = comps[id]!, has = c.owned(id), stv = c.recStar(id), n = c.ucard;
    final mx = has && stv >= c.starMax(id), need = c.starNeed(id) ?? 1;
    final col = compColor(id);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: col.withValues(alpha: .55)), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        CompFrame(id, dim: !has),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, runSpacing: 2, children: [
              Text(cd.n, style: KdText.display(15)),
              GradeTag(id),
              Text(chief ? '카엘 자리' : '${jobName[jobOf[id]]} 자리', style: KdText.body(11.5, color: KdColors.muted)),
              if (stv > 0) Stars(c, id),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                uiImg('village_skill', size: 16),
                const SizedBox(width: 3),
                Flexible(child: Text('마을 스킬 · ${villageSkillName[id]}', style: KdText.body(12, color: const Color(0xFFFFC23A)))),
              ]),
            ),
            if (!has)
              Text(chief ? '유니크 카드 $n장 모아 둠 · ${cd.join ?? ''}' : '피트의 상점 ${won(id == GameCalc.lucId ? GameCalc.lucWon : GameCalc.ttukWon)}', style: KdText.body(12, color: KdColors.muted))
            else if (mx)
              Text('별을 모두 모았어요', style: KdText.body(12, color: KdColors.muted))
            else ...[
              const SizedBox(height: 6),
              XpBar(n / need),
              const SizedBox(height: 2),
              Row(children: [
                uiImg('card_unique', size: 16),
                const SizedBox(width: 3),
                Flexible(child: Text('유니크 카드 $n / $need', style: KdText.figure(12, color: KdColors.muted, weight: FontWeight.w400))),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: chief
              ? KdBuy(
                  text: has && c.chiefCan() ? '★ 올리기' : '보기', // 카드가 모자라면 「보기」 (대표님 제보 10-27)
                  glow: c.chiefCan(),
                  minWidth: 0,
                  onTap: () => c.chiefCan() ? g.act((a) => a.chiefUp()) : chiefSheet(g),
                )
              : KdBuy(
                  text: !has ? '상점 보기' : c.uqCan(id) ? '★ 올리기' : '보기',
                  glow: c.uqCan(id),
                  minWidth: 0,
                  onTap: () => !has
                      ? g.setTab(GameTab.sh)
                      : c.uqCan(id)
                          ? g.act((a) => a.uqUp(id))
                          : compSheet(g, id),
                ),
        ),
      ]),
    );
  }

  Widget _ccard(String id) {
    final c = g.calc, cd = comps[id]!, op = c.cardOpen(id), stv = c.recStar(id);
    final n = orNum(g.state.cards?[id], 0), need = c.starNeed(id), mx = stv >= c.starMax(id);
    final col = compColor(id);
    Widget info;
    if (!op) {
      info = Text(GameCalc.isRec(id) ? '${comps[storyOf[recruits[id]!.job]]!.n}이(가) 합류하면 카드가 나오기 시작해요' : cd.join ?? '',
          style: KdText.body(12, color: KdColors.muted));
    } else if (mx) {
      info = Text('별을 모두 모았어요', style: KdText.body(12, color: KdColors.muted));
    } else {
      info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        XpBar(n / need!),
        const SizedBox(height: 2),
        Text('카드 $n / $need', style: KdText.figure(12, color: KdColors.muted, weight: FontWeight.w400)),
      ]);
    }
    return Opacity(
      opacity: op ? 1 : .6,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: col.withValues(alpha: .55)), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          CompFrame(id, dim: stv == 0, hidden: !op),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, runSpacing: 2, children: [
                Text(op ? cd.n : '???', style: KdText.display(15)),
                GradeTag(id),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    jobIcon(jobOf[id]!, size: 14),
                    const SizedBox(width: 2),
                    Text(jobName[jobOf[id]]!, style: KdText.body(11.5, color: KdColors.muted)),
                  ]),
                ),
                if (stv > 0) Stars(c, id),
              ]),
              if (villageSkillName.containsKey(id))
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    uiImg('village_skill', size: 16),
                    const SizedBox(width: 3),
                    Flexible(child: Text('마을 스킬 · ${villageSkillName[id]}', style: KdText.body(12, color: const Color(0xFFFFC23A)))),
                  ]),
                ),
              info,
            ]),
          ),
          if (op && !mx) ...[
            const SizedBox(width: 8),
            SizedBox(width: 92, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              KdBuy(
                text: stv > 0 ? '★ 올리기' : '맞이하기',
                glow: n >= need!,
                minWidth: 0,
                onTap: n >= need ? () => g.act((a) => a.recruitUp(id)) : null,
              ),
              // 전설 만능 카드 넣기 (웹 #lc-id · CONTENT_ATTENDANCE_2.md): 모자란 만큼만
              if (gradeOf[id] == 'legend' && g.acts.lcard > 0 && n < need) ...[
                const SizedBox(height: 6),
                KdBuy(
                  text: '만능 ${math.min(g.acts.lcard, need - n)}장 넣기',
                  small: true,
                  minWidth: 0,
                  onTap: () {
                    final k = g.act((a) => a.lcardUse(id));
                    if (k > 0) {
                      g.toast('${cd.n} 카드 +$k (전설 만능 카드)');
                      g.save();
                    }
                  },
                ),
              ],
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => g.act((a) => a.toggleWish(id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: g.state.wish == id ? const Color(0xFFFF8FB1) : KdColors.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(g.state.wish == id ? '♥ 희망 중' : '♡ 희망',
                      style: KdText.body(12, color: g.state.wish == id ? const Color(0xFFFF8FB1) : KdColors.muted)),
                ),
              ),
            ])),
          ],
        ]),
      ),
    );
  }
}

/// 동료 정보 창 (웹 compSheet): 능력치·스킬·레벨업·출전
void compSheet(GameController g, String id) {
  g.openSheet<void>((ctx) => ValueListenableBuilder<int>(
        valueListenable: g.ui,
        builder: (ctx, __, ___) {
          final c = g.calc, cd = comps[id]!, t = c.stats(id), job = jobOf[id]!;
          final on = c.slotMember(job) == id, lv = orNum(g.state.lv[id], 1), cost = GameCalc.compCost(lv);
          return KdSheetBody(
            titleWidget: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                jobIcon(job),
                const SizedBox(width: 3),
                Text('${jobName[job]} 동료', style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                CompFrame(id),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cd.n, style: KdText.display(22)),
                    Row(children: [GradeTag(id), const SizedBox(width: 4), Stars(c, id)]),
                    Text('${cd.role} · Lv.$lv · ${on ? '출전 중' : '대기'}', style: KdText.body(12, color: KdColors.muted)),
                  ]),
                ),
              ]),
            ]),
            children: [
              Text(cd.desc, style: KdText.body(13, color: KdColors.muted, height: 1.5)),
              KdKv('공격 · 체력', '${fmt(t.atk)} · ${fmt(t.hp)}'),
              KdKv('전투력', fmt(c.cPow(id))),
              SkillBox(id),
              VillageSkillBox(c, id),
              if (gradeOf[id] == 'unique' && c.recStar(id) < c.starMax(id))
                KdActs(buttons: [
                  KdAct('★ 올리기 · 유니크 카드 ${c.ucard} / ${c.starNeed(id) ?? 0}',
                      primary: c.uqCan(id), onTap: c.uqCan(id) ? () => g.act((a) => a.uqUp(id)) : null),
                ]),
            ],
            acts: KdActs(buttons: [
              on
                  ? KdAct('닫기', onTap: () => Navigator.of(ctx).pop())
                  : KdAct('출전시키기', onTap: () => g.act((a) => a.setMember(job, id))),
              KdAct(
                '레벨업',
                primary: true,
                onTap: g.state.gold >= cost ? () => g.act((a) => a.levelUp(id)) : null,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('레벨업', style: KdText.body(11, color: KdColors.goldInk.withValues(alpha: .8), weight: FontWeight.w600, height: 1.2)),
                  iconNum(goldIcon, fmt(cost), style: KdText.figure(15, color: KdColors.goldInk)),
                ]),
              ),
            ]),
          );
        },
      ));
}

/// 자리 고르기 창 (웹 seatSheet): 같은 직업 동료를 전투력 순으로
void seatSheet(GameController g, String j) {
  final c = g.calc, cur = c.slotMember(j);
  if (cur == null) {
    g.toast('${jobName[j]} 자리 동료가 아직 없어요');
    return;
  }
  final cp = c.cPow(cur);
  final ms = c.jobMembers(j)..sort((a, b) => c.cPow(b).compareTo(c.cPow(a)));
  g.openSheet<void>((ctx) => KdSheetBody(
        titleWidget: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            jobIcon(j),
            const SizedBox(width: 3),
            Text('${jobName[j]} 자리', style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
          ]),
          const SizedBox(height: 8),
          Text('누구를 출전시킬까요?', textAlign: TextAlign.center, style: KdText.display(22)),
        ]),
        children: [
          for (final id in ms)
            () {
              final d = (c.cPow(id) - cp).round(), on = id == cur;
              return GestureDetector(
                onTap: () {
                  if (g.act((a) => a.setMember(j, id))) Navigator.of(ctx).pop();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KdColors.panel2,
                    border: Border.all(color: on ? KdColors.gold : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    CompFrame(id),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(comps[id]!.n, style: KdText.display(15)),
                        Row(children: [GradeTag(id), const SizedBox(width: 4), Stars(c, id)]),
                        Text('Lv.${orNum(g.state.lv[id], 1)} · ${skills[id]!.n}', style: KdText.body(12, color: KdColors.muted)),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '전투력 ${fmt(c.cPow(id))} '),
                            on
                                ? const TextSpan(text: '출전 중', style: TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700))
                                : TextSpan(
                                    text: '${d > 0 ? '▲' : '▼'} ${fmt(d.abs())}',
                                    style: TextStyle(color: d > 0 ? KdColors.good : const Color(0xFFFF8A7A), fontWeight: FontWeight.w700)),
                          ]),
                          style: KdText.body(12, color: KdColors.muted),
                        ),
                      ]),
                    ),
                  ]),
                ),
              );
            }(),
          const KdNote('교체한 동료는 나간 동료의 체력 비율을 이어받고, 스킬 게이지는 처음부터 채워요.'),
        ],
        acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(ctx).pop())]),
      ));
}

/// 카엘 촌장 정보 창 (웹 chiefSheet): 능력치·스킬·마을 스킬·유니크 카드·출전
void chiefSheet(GameController g) {
  const id = GameCalc.chiefId;
  g.openSheet<void>((ctx) => ValueListenableBuilder<int>(
        valueListenable: g.ui,
        builder: (ctx, __, ___) {
          final c = g.calc, cd = comps[id]!, has = c.owned(id), st = c.recStar(id), mx = st >= c.starMax(id);
          final need = c.starNeed(id) ?? 1, n = c.ucard, t = c.stats(id), on = c.chiefOn();
          return KdSheetBody(
            titleWidget: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('카엘 자리 · 유니크 동료', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
              const SizedBox(height: 10),
              Row(children: [
                CompFrame(id),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cd.n, style: KdText.display(22)),
                    Row(children: [GradeTag(id), if (has) ...[const SizedBox(width: 4), Stars(c, id)]]),
                    Text('${cd.role}${has ? ' · ${on ? '출전 중' : '대기'}' : ''}', style: KdText.body(12, color: KdColors.muted)),
                  ]),
                ),
              ]),
            ]),
            children: [
              Text(cd.desc, style: KdText.body(13, color: KdColors.muted, height: 1.5)),
              if (!has)
                KdNote(
                    '맞이하는 법: ${c.chiefShop() ? '피트의 상점 ₩${GameCalc.chiefWon}' : '첫 은퇴 뒤 피트의 상점'} · 또는 은퇴 ${math.min(orNum(g.state.raw['retires'], 0), GameCalc.chiefRet)} / ${GameCalc.chiefRet}번'),
              KdKv('능력치', '카엘 +${pctTxt(GameCalc.chiefBonus[math.max(1, st)] * 100)}%'),
              if (has) KdKv('공격 · 체력', '${fmt(t.atk)} · ${fmt(t.hp)}'),
              KdKv('장비·칭호', '카엘 것 그대로'),
              SkillBox(id),
              VillageSkillBox(c, id),
              KdKv('유니크 카드', has ? (mx ? '$n장 · ★ 모두 모음' : '$n / $need장') : '$n장 모아 둠'),
              if (has && !mx) XpBar(n / need),
              const KdNote('유니크 카드는 황금 이삭 상품(5,500원 이상)의 덤, 피트의 정기 배송(3일마다 1장), 랭킹 시즌 보상으로 받아요. 원하는 유니크 동료를 골라 별을 올려요.'),
            ],
            acts: KdActs(buttons: [
              if (has)
                KdAct(on ? '카엘로 바꾸기' : '카엘 자리에 출전', onTap: () => g.act((a) => a.setKaelSeat(on ? 'kael' : id)))
              else
                KdAct('닫기', onTap: () => Navigator.of(ctx).pop()),
              if (has)
                KdAct(mx ? '★ 모두 모음' : '★ 올리기', primary: true, onTap: c.chiefCan() ? () => g.act((a) => a.chiefUp()) : null)
              else if (c.chiefShop())
                KdAct('상점 가기', primary: true, onTap: () {
                  Navigator.of(ctx).pop();
                  g.setTab(GameTab.sh);
                }),
            ]),
          );
        },
      ));
}

/// 카엘 자리 고르기 (웹 kaelSeatSheet): 카엘 · 카엘 촌장
void kaelSeatSheet(GameController g) {
  g.openSheet<void>((ctx) => ValueListenableBuilder<int>(
        valueListenable: g.ui,
        builder: (ctx, __, ___) {
          final c = g.calc, cur = c.slotMember('kael');
          return KdSheetBody(
            titleWidget: Column(children: [
              Text('카엘 자리', style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
              const SizedBox(height: 8),
              Text('누가 출전할까요?', textAlign: TextAlign.center, style: KdText.display(22)),
            ]),
            children: [
              for (final id in const ['kael', GameCalc.chiefId])
                GestureDetector(
                  onTap: () => g.act((a) => a.setKaelSeat(id)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KdColors.panel2,
                      border: Border.all(color: cur == id ? KdColors.gold : Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      CompFrame(id),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(comps[id]!.n, style: KdText.display(15)),
                            if (id != 'kael') ...[GradeTag(id), Stars(c, id)],
                          ]),
                          Text('${id == 'kael' ? '추수의 일격' : '다 함께 울력 · 새벽 종소리'} · 공격 ${fmt(c.stats(id).atk)} · 체력 ${fmt(c.stats(id).hp)}',
                              style: KdText.body(12, color: KdColors.muted)),
                          if (cur == id) Text('출전 중', style: KdText.body(12, color: KdColors.gold, weight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              const KdNote('장비·칭호·강화는 둘이 함께 써요.'),
            ],
            acts: KdActs(buttons: [
              KdAct('닫기', onTap: () => Navigator.of(ctx).pop()),
              KdAct('장비 보기', primary: true, onTap: () {
                Navigator.of(ctx).pop();
                g.setTab(GameTab.eq);
              }),
            ]),
          );
        },
      ));
}


// ════════ 원정대 B안 공통 (웹 partyOrder · benchBest · ptSel · tpanelHtml · lvAll) ════════
/// 원정대 하위 탭이 「원정대」인지 (옛 저장의 'form'·'list' 도 원정대)
bool ptTeam(GameController g) => g.state.raw['ptTab'] != 'card';

/// 카엘(·촌장) → 출전 중(자리 순) → 대기·일꾼(등급 높은 순 → 별 → 전투력) → 아직 합류 전 (웹 partyOrder)
List<String> ptOrder(GameController g) {
  final c = g.calc;
  const grk = {'legend': 3, 'epic': 2, 'rare': 1, 'common': 0};
  final on = [for (final j in jobSlots.where((j) => j != 'kael')) c.slotMember(j)].whereType<String>().toList();
  final bench = stableSorted(
    [for (final j in jobSlots.where((j) => j != 'kael')) ...c.jobMembers(j)].where((x) => !on.contains(x)),
    (a, b) {
      final d = (grk[gradeOf[b]] ?? 0) - (grk[gradeOf[a]] ?? 0);
      if (d != 0) return d;
      final st = c.recStar(b) - c.recStar(a);
      if (st != 0) return st;
      return c.cPow(b).compareTo(c.cPow(a));
    },
  );
  return <String>[
    'kael',
    if (c.owned(GameCalc.chiefId) || c.chiefShop()) GameCalc.chiefId,
    ...on,
    ...bench,
    for (final j in jobSlots.where((j) => j != 'kael' && c.slotMember(j) == null)) storyOf[j]!,
  ];
}

/// 자리마다 대기 중인 더 센 동료 (▲)
List<String> ptBenchBest(GameController g) {
  final c = g.calc;
  return [
    for (final j in jobSlots.where((j) => j != 'kael' && c.betterBench(j))) c.jobMembers(j).reduce((a, x) => c.cPow(x) > c.cPow(a) ? x : a),
  ];
}

/// 출전 중 동료 (카엘 제외)
List<String> ptOnIds(GameController g) => [for (final j in jobSlots.where((j) => j != 'kael')) g.calc.slotMember(j)].whereType<String>().toList();

/// 고른 동료: 없으면 ★ 올릴 동료 → 더 센 대기 동료 → 첫 출전 동료 → 카엘
String ptSelId(GameController g) {
  final c = g.calc, ids = ptOrder(g), cur = g.ptSel;
  if (ids.contains(cur) && (c.owned(cur) || cur == GameCalc.chiefId)) return cur;
  final ready = c.cardReady();
  final bb = ptBenchBest(g), on = ptOnIds(g);
  return g.ptSel = ids.firstWhere(ready.contains, orElse: () => bb.isNotEmpty ? bb.first : on.isNotEmpty ? on.first : 'kael');
}

/// 카드가 충분한 동료를 모두 맞이하기·★ 올리기 (웹 cardUpAll)
void ptUpAll(GameController g) {
  final got = <String, int>{};
  for (var k = 0; k < 200; k++) {
    final r = g.calc.cardReady();
    if (r.isEmpty) break;
    for (final id in r) {
      g.act((a) => a.recruitUp(id, quiet: true));
      got[id] = g.calc.recStar(id);
    }
  }
  if (got.isEmpty) return;
  g.save();
  final e = got.entries.toList();
  g.toast(e.length == 1 ? '${comps[e.first.key]!.n} ★${e.first.value}!' : '동료 ${e.length}명 ★ 올리기 · ${e.map((x) => '${comps[x.key]!.n} ★${x.value}').join(', ')}');
}

/// 출전 동료 모두 한 단계씩 — 골드가 다 있을 때만 (웹 lvAll)
void ptLvAll(GameController g) {
  final ids = ptOnIds(g), cost = ids.fold<num>(0, (a, id) => a + GameCalc.compCost(orNum(g.state.lv[id], 1)));
  if (ids.isEmpty) return;
  if (g.state.gold < cost) return g.toast('골드가 모자라요 (${fmt(cost)} 필요)');
  for (final id in ids) {
    g.act((a) => a.levelUp(id));
  }
  g.haptic(const [20]);
  g.toast('출전 동료 ${ids.length}명 레벨업');
  g.save();
}

/// 원정대 탭 아래 고른 동료 상세 (웹 tpanelHtml): 레벨업 · ★ 올리기 · 출전 + 모두 올리기 · 모두 레벨업. 나중에 이야기·호감도 자리
class PtPanel extends StatelessWidget {
  const PtPanel(this.g, {super.key});
  final GameController g;

  Widget _btn(String k, String top, String bottom, {VoidCallback? onTap, BuyKind kind = BuyKind.gold, bool glow = false, String? icon}) => KdBuy(
        key: ValueKey(k),
        kind: kind,
        glow: glow,
        minWidth: 0,
        small: true,
        label: top,
        text: bottom,
        costIcon: icon,
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final c = g.calc, id = ptSelId(g), cd = comps[id]!, kael = id == 'kael', chief = id == GameCalc.chiefId, has = c.owned(id);
    final lv = orNum(g.state.lv[id], 1), j = jobOf[id];
    final on = kael || (chief ? c.chiefOn() : c.slotMember(j!) == id);
    final wk = !kael && !chief ? c.working()[id] : null;
    String sub;
    List<Widget> acts;
    if (kael) {
      sub = '${ranks[c.rankIdx()].n} · 원정대 전투력 ${fmt(c.power())}';
      acts = [Expanded(child: _btn('tpEq', '카엘은 장비로 강해져요', '장비 탭 가기', onTap: () => g.setTab(GameTab.eq)))];
    } else if (chief) {
      final n = c.ucard, need = c.starNeed(id) ?? 1, mx = has && c.recStar(id) >= c.starMax(id);
      sub = has ? '${on ? '출전 중' : '대기'} · 카엘 자리 · 카엘 능력치 +${pctTxt(GameCalc.chiefBonus[c.recStar(id)] * 100)}%' : cd.join ?? '';
      acts = has
          ? [
              Expanded(child: _btn('tpStar', '★ 올리기', mx ? '별 모두 모음' : '유니크 $n/$need', glow: c.chiefCan(), onTap: c.chiefCan() ? () => g.act((a) => a.chiefUp()) : null)),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: _btn('tpSeat', on ? '출전 중' : '대기', '카엘 자리 바꾸기', kind: BuyKind.ghost, onTap: () => kaelSeatSheet(g))),
            ]
          : [Expanded(child: _btn('tpMore2', '카엘 촌장', '맞이하는 법 보기', kind: BuyKind.ghost, onTap: () => chiefSheet(g)))];
    } else {
      final uq = gradeOf[id] == 'unique';
      final n = uq ? c.ucard : orNum(g.state.cards?[id], 0), need = c.starNeed(id) ?? 1, mx = c.recStar(id) >= c.starMax(id);
      final can = uq ? c.uqCan(id) : !mx && n >= need;
      final jj = j!, cur = c.slotMember(jj), cost = GameCalc.compCost(lv);
      sub = '${on ? '출전 중' : wk != null ? '🔨 ${buildingDef(wk).n} 일꾼' : '대기'} · ${jobName[jj]} 자리 · Lv.$lv · 전투력 ${fmt(c.cPow(id))}';
      acts = [
        Expanded(
          child: _btn('tpLv', '레벨업 $lv→${lv + 1}', fmt(cost), icon: goldIcon, onTap: () {
            if (g.state.gold < cost) return g.toast('골드가 모자라요');
            g.act((a) => a.levelUp(id));
          }),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _btn('tpStar', c.recStar(id) > 0 ? '★ 올리기' : '맞이하기', mx ? '별 모두 모음' : '${uq ? '유니크' : '카드'} $n/$need',
              glow: can, onTap: can ? () => g.act((a) => uq ? a.uqUp(id) : a.recruitUp(id)) : null),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _btn('tpGo', on ? '출전 중' : '출전', on || cur == null ? '${jobName[jj]} 자리' : '${comps[cur]!.n}와 바꾸기',
              kind: BuyKind.ghost, onTap: on ? null : () => g.act((a) => a.setMember(jj, id))),
        ),
      ];
    }
    final rn = c.cardReady().length, onIds = ptOnIds(g);
    final lvCost = onIds.fold<num>(0, (a, x) => a + GameCalc.compCost(orNum(g.state.lv[x], 1)));
    return Container(
      key: const ValueKey('tpanel'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: KdColors.panel,
        border: Border(top: BorderSide(color: Color(0xFF8A6A2A), width: 1.5)),
        boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CompFrame(id, w: 48, h: 56, hidden: !(has || chief), dim: chief && !has),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, runSpacing: 2, children: [
                Text(cd.n, style: KdText.display(16)),
                if (!kael) ...[GradeTag(id), if (has) Stars(c, id)],
              ]),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: KdText.body(11.5, color: KdColors.muted)),
            ]),
          ),
          if (!kael) ...[
            const SizedBox(width: 6),
            KdBuy(key: const ValueKey('tpMore'), kind: BuyKind.ghost, small: true, minWidth: 0, text: '자세히', onTap: () => chief ? chiefSheet(g) : compSheet(g, id)),
          ],
        ]),
        const SizedBox(height: 8),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: acts)),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _btn('tpStarAll', '카드가 모인 동료', rn > 0 ? '★ 모두 올리기 ($rn)' : '★ 모두 올리기',
                  kind: rn > 0 ? BuyKind.gold : BuyKind.ghost, glow: rn > 0, onTap: rn > 0 ? () => ptUpAll(g) : null),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _btn('tpLvAll', '출전 동료 모두 레벨업', fmt(lvCost), icon: goldIcon, kind: BuyKind.ghost, onTap: onIds.isEmpty ? null : () => ptLvAll(g)),
            ),
          ]),
        ),
      ]),
    );
  }
}
