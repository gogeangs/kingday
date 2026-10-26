/// 단련 탭 — 웹 #p-up (×1 · ×10 · 최대, 꾹 누르면 계속 강화, 추천 표시)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/retire.dart';
import '../game/controller.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 웹 UPI: 아이콘·이름·값 보여 주기
const _upi = {
  'atk': ('upg_atk', '공격력'),
  'hp': ('upg_hp', '체력'),
  'spd': ('upg_spd', '속도'),
  'crit': ('upg_crit', '치명타'),
};

String _val(String k, Stats t) => switch (k) {
      'atk' => fmt(t.atk),
      'hp' => fmt(t.hp),
      'spd' => '${t.aps.toStringAsFixed(2)}회/초',
      _ => '${(t.crit * 100).round()}%',
    };

class UpPage extends StatelessWidget {
  const UpPage(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final mul = g.acts.upMul, best = g.acts.bestUpgrade();
    // 후반(공격·체력 Lv.100 이상)에 ×1이면 「최대」 추천 (웹 .upmul .rec)
    final rec = mul == 1 && math.max(g.state.upLv('atk'), g.state.upLv('hp')) >= 100;
    // 숫자 단위 설명: 처음 한 번 펼치고, 그 뒤엔 「한 번에」 줄 왼쪽 작은 「? aa·ab」로 접음 (웹 #upHelp · UI 점검 10-27 5번)
    final big = g.state.gold >= 1e15 || upgrades.any((u) => g.state.upLv(u.k) < u.max && g.calc.upgradeCost(u.k, g.state.upLv(u.k)) >= 1e15);
    final bigOpen = big && (g.helpSeen['bigu'] == null || (g.helpOpen['bigu'] ?? false));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (big && !bigOpen) ...[
          GestureDetector(
            onTap: () {
              g.helpOpen['bigu'] = true;
              g.refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(999)),
              child: Text('? aa·ab', style: KdText.body(12, color: KdColors.muted, weight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
        ],
        Text('한 번에', style: KdText.body(12, color: KdColors.muted)),
        for (final (v, n) in const [(1, '×1'), (10, '×10'), ('max', '최대')]) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              g.state.raw['upMul'] = v;
              g.save();
              g.refresh();
            },
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
              constraints: const BoxConstraints(minWidth: 46),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mul == v ? KdColors.gold : KdColors.panel2,
                border: Border.all(color: mul == v ? KdColors.gold : KdColors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(n, style: KdText.body(13, color: mul == v ? const Color(0xFF1A1206) : KdColors.fg, weight: FontWeight.w600)),
            ),
              if (rec && v == 'max')
                Positioned(
                  top: -9,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE0563B), borderRadius: BorderRadius.circular(6)),
                    child: Text('추천', style: KdText.body(10.5, color: Colors.white, height: 1)),
                  ),
                ),
            ]),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      // 숫자 단위 aa·ab 안내 (웹 helpNote('bigu'), UX 점검 13)
      if (bigOpen) ...[
        HelpNote(
          k: 'bigu',
          title: '숫자 단위 aa·ab는?',
          seen: g.helpSeen,
          open: g.helpOpen,
          body: Text('K = 천 · M = 백만 · B = 10억 · T = 1조. 그보다 크면 알파벳 두 글자 aa(1,000T) → ab(1,000aa) → ac … 처럼 한 칸 갈 때마다 1,000배예요.',
              style: KdText.body(12.5, color: KdColors.muted)),
        ),
        const SizedBox(height: 8),
      ],
      for (final u in upgrades) ...[_UpRow(g, u, best: u.k == best), const SizedBox(height: 8)],
      const SizedBox(height: 4),
      // 처음 온 영주(은퇴 전·영지 10 전)에게는 아직 안 보여 줌 (웹 renderRetire · UI 점검 10-27 10번)
      if (g.state.retires > 0 || g.state.memory > 0 || g.state.best >= 10) _RetireBox(g, key: g.retireKey),
    ]);
  }
}

class _UpRow extends StatefulWidget {
  const _UpRow(this.g, this.u, {required this.best});
  final GameController g;
  final UpgradeDef u;
  final bool best;

  @override
  State<_UpRow> createState() => _UpRowState();
}

class _UpRowState extends State<_UpRow> {
  Timer? _hold;
  bool _repeated = false;
  double _delay = 260;
  int _flash = 0;

  GameController get g => widget.g;

  bool _fire() {
    final n = g.act((a) => a.upFire(widget.u.k));
    if (n > 0) {
      g.sound('up');
      setState(() => _flash = DateTime.now().millisecondsSinceEpoch);
    }
    return n > 0;
  }

  /// 꾹 누르기: 0.4초 뒤부터 점점 빠르게 (웹 upHold)
  void _down() {
    _stop();
    _repeated = false;
    _delay = 260;
    _hold = Timer(const Duration(milliseconds: 400), _tick);
  }

  void _tick() {
    _repeated = true;
    if (!_fire()) return _stop();
    _delay = math.max(70, _delay * .82);
    _hold = Timer(Duration(milliseconds: _delay.round()), _tick);
  }

  void _up() {
    final once = !_repeated;
    _stop();
    if (once) _fire();
  }

  void _stop() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u, s = g.state, l = s.upLv(u.k), mx = l >= u.max;
    final (ic, nm) = _upi[u.k]!;
    final t = g.calc.kStats();
    String? next;
    final plan = g.acts.upPlan(u);
    if (!mx) {
      // 「한 번에」 ×10·최대면 그만큼 올린 뒤 값 (웹 upNext(k, n) · UI 점검 10-27 2번)
      final pn = math.max(1, math.min(plan.n, u.max - l));
      s.up[u.k] = l + pn;
      final n = g.calc.kStats();
      s.up[u.k] = l;
      next = _val(u.k, n);
      // 후반에 숫자가 커서 「454K → 454K」처럼 차이가 안 보이면 오르는 비율로 (웹 upGain, UX 점검 13)
      if (next == _val(u.k, t) && (u.k == 'atk' || u.k == 'hp')) {
        final x = u.k == 'atk' ? t.atk : t.hp, y = u.k == 'atk' ? n.atk : n.hp, p = x > 0 ? (y / x - 1) * 100 : 0;
        next = p >= .01 ? '+${p.toStringAsFixed(p >= 1 ? 1 : 2)}%' : '<0.01%';
      }
    }
    final can = !mx && s.gold >= g.calc.upgradeCost(u.k, l);
    final age = DateTime.now().millisecondsSinceEpoch - _flash;
    final flash = age < 350 ? 1 - age / 350 : 0.0;
    // 할 일 「추천 강화 하기」로 왔을 때 추천 줄 반짝임 (웹 .upr.flash)
    final ha = DateTime.now().millisecondsSinceEpoch - g.upHintAt;
    final hint = g.upHintK == u.k && ha < 1400 ? .5 - .5 * math.cos(ha / 1400 * 6 * math.pi) : 0.0;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(KdColors.panel, const Color(0xFF3A3A20), flash),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.best ? KdColors.gold : Colors.transparent),
          boxShadow: [
            if (widget.best) const BoxShadow(color: Color(0x59FFC94A), blurRadius: 14),
            if (hint > 0) BoxShadow(color: Color.fromRGBO(255, 201, 74, .85 * hint), spreadRadius: 3 * hint),
          ],
        ),
        child: Row(children: [
          uiImg(ic, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(u.n, overflow: TextOverflow.ellipsis, style: KdText.display(15))),
                const SizedBox(width: 4),
                Text('Lv.$l', style: KdText.body(12, color: KdColors.gold)),
              ]),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$nm '),
                    TextSpan(text: _val(u.k, t), style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
                    if (mx)
                      const TextSpan(text: ' · 최대')
                    else ...[
                      const TextSpan(text: ' → '),
                      TextSpan(text: next, style: const TextStyle(color: KdColors.good, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  style: KdText.figure(12.5, color: KdColors.muted, weight: FontWeight.w400),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            // 안의 버튼이 IgnorePointer 라서, 이 줄이 없으면 손가락이 닿아도 아무도 받지 않음 (2026-10-26 「강화가 안 눌려요」)
            behavior: HitTestBehavior.opaque,
            onTapDown: can ? (_) => _down() : null,
            onTapUp: can ? (_) => _up() : null,
            onTapCancel: _stop,
            // 버튼 모양만 빌려 씀 (누르기는 바깥에서 받아 꾹 누르기를 처리)
            child: IgnorePointer(
              child: KdBuy(
                label: mx ? null : (plan.n > 1 ? '강화 ×${plan.n}' : '강화'),
                text: mx ? '최대' : null,
                cost: mx ? null : plan.c,
                costIcon: mx ? null : goldIcon,
                onTap: can ? () {} : null,
              ),
            ),
          ),
        ]),
      ),
      if (widget.best)
        Positioned(
          top: -8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: KdColors.gold, borderRadius: BorderRadius.circular(6)),
            child: Text('추천', style: KdText.body(10, color: const Color(0xFF1A1206), weight: FontWeight.w600, height: 1.6)),
          ),
        ),
    ]);
  }
}

/// 카엘의 은퇴 계획 (웹 renderRetire): 요약 + 「은퇴 일기」·「은퇴하기」
class _RetireBox extends StatelessWidget {
  const _RetireBox(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc, t = c.retireTarget(), pts = c.retirePts(), can = c.retCan(), mp = c.memPts(), dot = c.trCanAny();
    final need = s.stage < 20 ? '영지 19곳을 되찾으면 은퇴할 수 있어요' : '이번 회차에 영지 ${10 - c.retRun()}곳을 더 되찾으면 은퇴할 수 있어요';
    return KdBox(children: [
      const KdSec('카엘의 은퇴 계획'),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: '은퇴의 추억 '),
          TextSpan(text: '${fmt(s.memory)}개', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' · 모든 능력치·골드 '),
          TextSpan(text: '+${fmt(s.memory * 5)}%', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' · 쓸 수 있는 포인트 '),
          TextSpan(text: '$mp', style: TextStyle(color: mp > 0 ? const Color(0xFFFFD34A) : KdColors.fg, fontWeight: FontWeight.w700)),
        ]),
        key: const ValueKey('rtSum'),
        style: KdText.body(13, color: KdColors.muted, height: 1.5),
      ),
      if (can)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1AFFC94A),
            border: Border.all(color: const Color(0x73FFC94A)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '지금 은퇴하면 추억 '),
              TextSpan(text: '+$pts', style: const TextStyle(color: KdColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
              const TextSpan(text: ' → 모든 능력치·골드 '),
              TextSpan(text: '+${fmt((s.memory + pts) * 5)}%', style: const TextStyle(color: KdColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
              const TextSpan(text: ' · 포인트 '),
              TextSpan(text: '+$pts', style: const TextStyle(color: KdColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            textAlign: TextAlign.center,
            style: KdText.body(13),
          ),
        ),
      KdKv('은퇴 자금', '${fmt(s.gold)} / ${fmt(t)}'),
      XpBar(math.min(1, s.gold / t).toDouble()),
      const KdNote('영지를 되찾을수록 목표 금액이 올라가요. 카엘은 아직 이 사실을 몰라요.'),
      if (orNum(s.raw['capClears'], 0) > 0)
        Text('👑 왕도 재탈환 보너스: 다음 회차에 왕도를 되찾으면 은퇴의 추억 +$capMem', style: KdText.body(12, color: const Color(0xFFFFD77A))),
      Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          KdBuy(
            key: const ValueKey('diaryBtn'),
            text: '은퇴 일기',
            // 노란 버튼은 하나만: 은퇴할 수 없고 찍을 포인트가 있을 때만 노란색 (웹 diaryBtn .alt, UX 점검 15)
            kind: !can && mp > 0 ? BuyKind.gold : BuyKind.ghost,
            minWidth: 0,
            onTap: g.openDiary,
          ),
          if (dot)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: KdColors.gold, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
              ),
            ),
        ]),
        const SizedBox(width: 6),
        Expanded(
          child: KdBuy(
            key: const ValueKey('retireBtn'),
            text: can ? '은퇴하기 · 추억 +$pts' : need,
            minWidth: 0,
            onTap: can ? g.askRetire : null,
          ),
        ),
      ]),
    ]);
  }
}
