/// 원정대 탭 — 웹 #p-pt (편성 · 동료 · 카드) + 동료 정보 창(compSheet) + 자리 고르기 창(seatSheet)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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

class PtPage extends StatelessWidget {
  const PtPage(this.g, {super.key});
  final GameController g;

  String get _sub => g.state.raw['ptTab'] is String ? g.state.raw['ptTab'] as String : 'form';

  @override
  Widget build(BuildContext context) {
    final sub = _sub;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 하위 탭 (웹 .subtabs)
      Row(children: [
        for (final (k, n) in const [('form', '편성'), ('list', '동료'), ('card', '카드')]) ...[
          if (k != 'form') const SizedBox(width: 6),
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
        'list' => _list(),
        'card' => _cards(),
        _ => _form(),
      },
    ]);
  }

  // ════════ 편성 ════════
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
      const SizedBox(height: 6),
      ..._nextGoal(),
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
  List<Widget> _list() {
    final c = g.calc;
    // 카엘(·촌장) → 출전 중(자리 순) → 대기·일꾼(등급 높은 순 → 별 → 전투력) → 아직 합류 전 (웹 partyOrder)
    const grk = {'legend': 3, 'epic': 2, 'rare': 1, 'common': 0};
    final on = [for (final j in jobSlots.where((j) => j != 'kael')) c.slotMember(j)].whereType<String>().toList();
    final bench = stableSorted(
      [for (final j in jobSlots.where((j) => j != 'kael')) ...c.jobMembers(j)].where((x) => !on.contains(x)),
      (a, b) {
        final g = (grk[gradeOf[b]] ?? 0) - (grk[gradeOf[a]] ?? 0);
        if (g != 0) return g;
        final st = c.recStar(b) - c.recStar(a);
        if (st != 0) return st;
        return c.cPow(b).compareTo(c.cPow(a));
      },
    );
    final ids = <String>[
      'kael',
      if (c.owned(GameCalc.chiefId) || c.chiefShop()) GameCalc.chiefId,
      ...on,
      ...bench,
      for (final j in jobSlots.where((j) => j != 'kael' && c.slotMember(j) == null)) storyOf[j]!,
    ];
    final grid = g.state.raw['ptGrid'] == true;
    Widget seg(String k, String n) => GestureDetector(
          onTap: () {
            g.state.raw['ptGrid'] = k == 'grid';
            g.refresh();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: (k == 'grid') == grid ? KdColors.gold : null,
            child: Text(n,
                style: KdText.body(12.5, color: (k == 'grid') == grid ? KdColors.goldInk : KdColors.muted, weight: (k == 'grid') == grid ? FontWeight.w700 : FontWeight.w400)),
          ),
        );
    return [
      Row(children: [
        const Expanded(child: KdNote('동료를 누르면 자세한 정보·스킬·출전을 볼 수 있어요.')),
        const SizedBox(width: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [seg('list', '목록'), seg('grid', '격자')]),
        ),
      ]),
      const SizedBox(height: 8),
      if (grid)
        LayoutBuilder(builder: (_, cs) {
          final w = (cs.maxWidth - 16) / 3;
          return Wrap(spacing: 8, runSpacing: 8, children: [for (final id in ids) SizedBox(width: w, child: _gcell(id))]);
        })
      else
        for (final id in ids) _crow(id),
    ];
  }

  /// 격자 칸 (U-1, 웹 gcell): 얼굴 + 등급 테두리 + ★ + Lv. 출전 중 금테, 🔨 일꾼, ★ 올리기 가능 노란 점, 합류 전 어둡게 ???
  Widget _gcell(String id) {
    final c = g.calc, cd = comps[id]!, has = c.owned(id), kael = id == 'kael', chief = id == GameCalc.chiefId;
    final on = kael || (chief ? c.chiefOn() : c.slotMember(jobOf[id]!) == id);
    final wk = !kael && !chief && c.working()[id] != null;
    final up = chief ? c.chiefCan() : c.cardReady().contains(id);
    final named = has || chief;
    final sub = kael
        ? ranks[c.rankIdx()].n
        : has
            ? '${chief ? '' : 'Lv.${orNum(g.state.lv[id], 1)} '}${'★' * c.recStar(id)}'
            : chief
                ? '유니크'
                : '합류 전';
    return GestureDetector(
      onTap: !named
          ? null
          : () => kael
              ? g.setTab(GameTab.eq)
              : chief
                  ? chiefSheet(g)
                  : compSheet(g, id),
      child: Opacity(
        opacity: has || chief ? 1 : .5,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 7),
          decoration: BoxDecoration(
            color: KdColors.panel2,
            border: Border.all(color: on && has ? KdColors.gold : KdColors.line),
            borderRadius: BorderRadius.circular(12),
            boxShadow: on && has ? const [BoxShadow(color: Color(0x40FFC94A), blurRadius: 10)] : null,
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: CompFrame(id, w: 56, h: 66, hidden: !named, dim: chief && !has)),
              const SizedBox(height: 4),
              Text(named ? cd.n : '???', maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.display(13.5)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(12.5, color: KdColors.muted)),
            ]),
            if (up)
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

  Widget _crow(String id) {
    final c = g.calc, cd = comps[id]!;
    if (id == GameCalc.chiefId) {
      final has = c.owned(id), on = c.chiefOn();
      return GestureDetector(
        onTap: () => chiefSheet(g),
        child: _crowBox(
          face: FaceImg(id),
          title: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
            Text(cd.n, style: KdText.display(15)),
            GradeTag(id),
            if (has) Stars(c, id),
          ]),
          sub: has ? '${on ? '출전' : '대기'} · 카엘 자리 · 카엘 능력치 +${pctTxt(GameCalc.chiefBonus[c.recStar(id)] * 100)}%' : cd.join ?? '',
          right: has && c.chiefCan()
              ? KdBuy(text: '★ 올리기', small: true, glow: true, minWidth: 74, onTap: () => g.act((a) => a.chiefUp()))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(8)),
                  child: Text(has ? (on ? '출전' : '대기') : '보기', style: KdText.body(12, color: KdColors.muted)),
                ),
        ),
      );
    }
    if (!c.owned(id)) {
      return _crowBox(
        locked: true,
        face: const ColoredBox(color: KdColors.panel),
        title: Text('???', style: KdText.display(15)),
        sub: '${cd.role} · ${cd.join ?? ''}',
      );
    }
    final on = id == 'kael' || c.slotMember(jobOf[id]!) == id;
    final lv = orNum(g.state.lv[id], 1);
    return GestureDetector(
      onTap: () => id == 'kael' ? g.setTab(GameTab.eq) : compSheet(g, id),
      child: _crowBox(
        face: FaceImg(id),
        title: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 5, children: [
          Text(cd.n, style: KdText.display(15)),
          if (id != 'kael') ...[GradeTag(id), Stars(c, id)],
        ]),
        sub: id == 'kael'
            ? '${ranks[c.rankIdx()].n} · 원정대 전투력 ${fmt(c.power())}'
            : '${on ? '출전' : c.working()[id] != null ? '🔨 ${buildingDef(c.working()[id]!).n}' : '대기'} · Lv.$lv · 전투력 ${fmt(c.cPow(id))}',
        right: id == 'kael'
            ? KdBuy(text: '장비', kind: BuyKind.ghost, small: true, minWidth: 0, onTap: () => g.setTab(GameTab.eq))
            : on
                ? KdBuy(
                    label: 'Lv↑',
                    cost: GameCalc.compCost(lv),
                    costIcon: goldIcon,
                    small: true,
                    minWidth: 74,
                    onTap: g.state.gold >= GameCalc.compCost(lv) ? () => g.act((a) => a.levelUp(id)) : null,
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(8)),
                    child: Text(c.working()[id] != null ? '🔨 일꾼' : '대기', style: KdText.body(12, color: KdColors.muted)),
                  ),
      ),
    );
  }

  Widget _crowBox({required Widget face, required Widget title, required String sub, Widget? right, bool locked = false}) => Opacity(
        opacity: locked ? .5 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: face)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                title,
                const SizedBox(height: 2),
                // 웹 .crow small: 좁은 폭에서도 숫자가 잘리지 않게 두 줄까지
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: KdText.body(12, color: KdColors.muted)),
              ]),
            ),
            if (right != null) ...[const SizedBox(width: 8), right],
          ]),
        ),
      );

  // ════════ 카드 ════════
  List<Widget> _cards() {
    final c = g.calc;
    final ids = stableSorted(GameCalc.cardIds(), (a, b) {
      int key(String x) => (c.cardOpen(x) ? 2 : 0) + (c.owned(x) ? 1 : 0);
      final d = key(b) - key(a);
      return d != 0 ? d : (GameCalc.gr(a).w - GameCalc.gr(b).w).sign.toInt();
    });
    TextSpan gt(String n, int col) => TextSpan(text: n, style: TextStyle(color: Color(col), fontWeight: FontWeight.w700));
    final uc = c.owned(GameCalc.chiefId) || c.chiefShop() || c.ucard > 0;
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
      if (uc) _ucard(),
      for (final id in ids) _ccard(id),
    ];
  }

  /// 유니크 카드 줄 (웹 ucRow): 카엘 촌장 별 올리기
  Widget _ucard() {
    const id = GameCalc.chiefId;
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
              Text('카엘 자리', style: KdText.body(11.5, color: KdColors.muted)),
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
              Text('유니크 카드 $n장 모아 둠 · ${cd.join ?? ''}', style: KdText.body(12, color: KdColors.muted))
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
          child: KdBuy(
            text: has && !mx ? '★ 올리기' : '보기',
            glow: c.chiefCan(),
            minWidth: 0,
            onTap: () => c.chiefCan() ? g.act((a) => a.chiefUp()) : chiefSheet(g),
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
