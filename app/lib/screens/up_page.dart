/// 단련 탭 — 웹 #p-up (×1 · ×10 · 최대, 꾹 누르면 계속 강화, 추천 표시)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('한 번에', style: KdText.body(12, color: KdColors.muted)),
        for (final (v, n) in const [(1, '×1'), (10, '×10'), ('max', '최대')]) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              g.state.raw['upMul'] = v;
              g.save();
              g.refresh();
            },
            child: Container(
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
          ),
        ],
      ]),
      const SizedBox(height: 12),
      for (final u in upgrades) ...[_UpRow(g, u, best: u.k == best), const SizedBox(height: 8)],
      const SizedBox(height: 4),
      _RetireBox(g),
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
    if (!mx) {
      s.up[u.k] = l + 1;
      next = _val(u.k, g.calc.kStats());
      s.up[u.k] = l;
    }
    final plan = g.acts.upPlan(u);
    final can = !mx && s.gold >= GameCalc.upgradeCost(u.k, l);
    final age = DateTime.now().millisecondsSinceEpoch - _flash;
    final flash = age < 350 ? 1 - age / 350 : 0.0;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(KdColors.panel, const Color(0xFF3A3A20), flash),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.best ? KdColors.gold : Colors.transparent),
          boxShadow: widget.best ? const [BoxShadow(color: Color(0x59FFC94A), blurRadius: 14)] : null,
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

/// 카엘의 은퇴 계획 (웹 renderRetire)
class _RetireBox extends StatelessWidget {
  const _RetireBox(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc, t = c.retireTarget(), pts = c.retirePts(), can = s.stage >= 20;
    return KdBox(children: [
      const KdSec('카엘의 은퇴 계획'),
      KdKv('은퇴의 추억 ${fmt(s.memory)}개', '모든 능력치·골드 +${fmt(s.memory * 5)}%'),
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
              const TextSpan(text: '지금 은퇴하면 '),
              TextSpan(text: '+${pts * 5}%', style: const TextStyle(color: KdColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
              const TextSpan(text: ' → 모든 능력치·골드 '),
              TextSpan(text: '+${fmt((s.memory + pts) * 5)}%', style: const TextStyle(color: KdColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            textAlign: TextAlign.center,
            style: KdText.body(13),
          ),
        ),
      KdKv('은퇴 자금', '${fmt(s.gold)} / ${fmt(t)}'),
      XpBar(math.min(1, s.gold / t).toDouble()),
      const KdNote('영지를 되찾을수록 목표 금액이 올라가요. 카엘은 아직 이 사실을 몰라요.'),
      KdBuy(
        text: can ? '은퇴하기 · 추억 +$pts' : '영지 19곳을 되찾으면 은퇴할 수 있어요',
        minWidth: 0,
        onTap: can ? g.askRetire : null,
      ),
    ]);
  }
}
