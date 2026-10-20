/// 게임 전체 화면 — 웹 .app (상단 바 · 전투 화면 · 탭 화면 · 하단 탭 · 제목 화면 · 알림)
library;

import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data.dart';
import '../core/fmt.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'pages.dart';
import 'stage_overlay.dart';

class GameShell extends ConsumerWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: KdColors.deep,
      body: Center(
        child: ConstrainedBox(
          // 웹 .app max-width:480px
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: g,
            builder: (context, _) => Stack(children: [
              ColoredBox(
                color: KdColors.bg,
                child: Column(children: [
                  ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => _Hud(g, top: pad.top)),
                  Expanded(child: _StageArea(g)),
                  ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => _Tabs(g, bottom: pad.bottom)),
                ]),
              ),
              _ToastView(g, top: pad.top),
              if (g.titleOpen) _Title(g),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════ 상단 바 (웹 .hud) ════════════════════
class _Hud extends StatelessWidget {
  const _Hud(this.g, {required this.top});
  final GameController g;
  final double top;

  @override
  Widget build(BuildContext context) {
    final s = g.state, ri = g.calc.rankIdx();
    final badge = s.raw['badge'] is String ? s.raw['badge'] as String : null;
    final frame = s.raw['pf'] is String ? s.raw['pf'] as String : 'wood';
    return Container(
      padding: EdgeInsets.fromLTRB(12, math.max(8, top), 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0D1220), KdColors.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(bottom: BorderSide(color: Color(0xFF2A3350))),
      ),
      child: Row(children: [
        // 얼굴 + 프로필 테두리 + ⚙
        GestureDetector(
          onTap: () => _profile(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                left: 52 * .11,
                top: 52 * .11,
                right: 52 * .11,
                bottom: 52 * .11,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(52 * .78 * .16),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3B5A8A), Color(0xFF1A2440)])),
                    child: FaceImg('kael'),
                  ),
                ),
              ),
              Positioned.fill(child: kdImg('assets/game/profile/frame_$frame.png')),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFF0D1220), shape: BoxShape.circle, border: Border.all(color: KdColors.gold)),
                  child: const Text('⚙', style: TextStyle(color: KdColors.gold, fontSize: 11, height: 1)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: Text('카엘', maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: KdText.display(15))),
              if (badge != null) ...[const SizedBox(width: 5), kdImg('assets/game/profile/badge_$badge.png', w: 20, h: 20)],
              const SizedBox(width: 5),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: KdColors.gold, borderRadius: BorderRadius.circular(999)),
                  child: Text(ranks[ri].n,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KdText.body(11, color: KdColors.goldInk, weight: FontWeight.w600, height: 1.3)),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text('⚔ ${fmt(g.calc.power())}', maxLines: 1, overflow: TextOverflow.clip, style: KdText.figure(13, color: KdColors.gold)),
          ]),
        ),
        const SizedBox(width: 6),
        // 황금 이삭 (누르면 상점)
        GestureDetector(
          onTap: () => g.setTab(GameTab.sh),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1406),
                border: Border.all(color: const Color(0xFF8A6A1A)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 22, height: 16, child: OverflowBox(maxWidth: 24, maxHeight: 24, child: kdImg('assets/game/gem/ui_gem.png', w: 24, h: 24))),
                const SizedBox(width: 3),
                Text(fmt(s.gem), style: KdText.figure(14, color: const Color(0xFFFFE08A))),
                const SizedBox(width: 2),
                Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: KdColors.gold, shape: BoxShape.circle),
                  child: const Text('+', style: TextStyle(color: Color(0xFF1A1206), fontSize: 11, fontWeight: FontWeight.w900, height: 1)),
                ),
              ]),
            ),
            if (g.gemDot) const Positioned(top: -2, right: -2, child: _Dot()),
          ]),
        ),
        const SizedBox(width: 6),
        // 골드
        Container(
          padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A),
            border: Border.all(color: const Color(0xFF3A4568)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 20, height: 18, child: OverflowBox(maxWidth: 26, maxHeight: 26, child: kdImg('assets/game/ui/ui_gold.png', w: 26, h: 26))),
            const SizedBox(width: 3),
            Text(fmt(s.gold), style: KdText.figure(16)),
          ]),
        ),
      ]),
    );
  }

  /// 얼굴을 누르면 프로필 (꾸미기·닉네임·설정은 8단계)
  void _profile() {
    final s = g.state, ri = g.calc.rankIdx();
    g.openSheet<void>((c) => KdSheetBody(
          eyebrow: '프로필',
          titleWidget: Column(children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(children: [
                const Positioned.fill(
                  left: 10,
                  top: 10,
                  right: 10,
                  bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3B5A8A), Color(0xFF1A2440)])),
                      child: FaceImg('kael'),
                    ),
                  ),
                ),
                Positioned.fill(child: kdImg('assets/game/profile/frame_${s.raw['pf'] is String ? s.raw['pf'] : 'wood'}.png')),
              ]),
            ),
            const SizedBox(height: 6),
            Text('${ranks[ri].n} 카엘', textAlign: TextAlign.center, style: KdText.display(22)),
          ]),
          children: [
            KdBox(children: [
              KdKv('원정대 전투력', fmt(g.calc.power())),
              KdKv('되찾은 영지', '${g.calc.landCount()} / $maxLand'),
              KdKv('가장 멀리 간 영지', '${s.best}'),
              KdKv('은퇴', '${s.retires}번 · 추억 ${fmt(s.memory)}'),
            ]),
            const KdNote('닉네임 · 프로필 테두리 · 배지 · 설정은 8단계에서 옮겨 와요.', center: true),
          ],
          acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(c).pop())]),
        ));
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.opt = false});
  final bool opt;

  @override
  Widget build(BuildContext context) => Container(
        width: opt ? 8 : 9,
        height: opt ? 8 : 9,
        decoration: BoxDecoration(
          color: opt ? KdColors.gold : KdColors.bad,
          shape: BoxShape.circle,
          border: Border.all(color: opt ? const Color(0xFF6B4F12) : Colors.white),
        ),
      );
}

// ════════════════════ 전투 화면 + 탭 화면 ════════════════════
class _StageArea extends StatelessWidget {
  const _StageArea(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final t = g.tab, half = t != null && t.half && !g.pgFull;
        final top = half ? math.min(c.maxHeight * .38, 300.0) : 0.0;
        return Stack(children: [
          Positioned.fill(child: GameWidget(game: g.game)),
          Positioned(left: 0, right: 0, top: 8, child: ValueListenableBuilder<int>(valueListenable: g.frame, builder: (_, __, ___) => StageTop(g))),
          Positioned(left: 0, right: 0, bottom: 0, child: ValueListenableBuilder<int>(valueListenable: g.frame, builder: (_, __, ___) => StageBottom(g))),
          // 반쯤 열린 창 위 빈 곳을 누르면 닫힘 (웹 .pgshade)
          if (half) Positioned(left: 0, right: 0, top: 0, height: top, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => g.setTab(null))),
          if (t != null)
            Positioned(left: 0, right: 0, top: top, bottom: 0, child: PageSheet(key: ValueKey(t), g: g, tab: t, half: half)),
        ]);
      });
}

// ════════════════════ 하단 탭 (웹 .tabs) ════════════════════
class _Tabs extends StatelessWidget {
  const _Tabs(this.g, {required this.bottom});
  final GameController g;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final dots = {GameTab.pt: g.ptDot, GameTab.vl: g.vlDot};
    return Container(
      padding: EdgeInsets.fromLTRB(8, 5, 8, math.max(6, bottom - 18)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1A2135), Color(0xFF0D1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(top: BorderSide(color: KdColors.brass, width: 2)),
      ),
      child: Row(children: [
        for (final t in [GameTab.eq, GameTab.pt, GameTab.up, GameTab.vl, GameTab.mp]) ...[
          if (t != GameTab.eq) const SizedBox(width: 4),
          Expanded(child: _tab(t, dots[t] ?? false)),
        ],
      ]),
    );
  }

  Widget _tab(GameTab t, bool dot) {
    final on = g.tab == t;
    Widget icon = kdImg('assets/game/ui/${t.icon}.png', w: 38, h: 38);
    icon = on ? Transform.scale(scale: 1.08, child: icon) : filtered(icon, sat: .75, bright: .9);
    return GestureDetector(
      onTap: () => g.setTab(t),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(colors: [Color(0xFF5A4515), Color(0xFF2A2010)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? KdColors.gold : Colors.transparent),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(height: 1),
            Text(t.label, style: KdText.display(12, color: on ? KdColors.gold : KdColors.muted).copyWith(height: 1.2)),
          ]),
        ),
        // 원정대 점은 금색(선택), 마을 점은 빨강
        if (dot) Positioned(top: 3, right: 10, child: _Dot(opt: t == GameTab.pt)),
      ]),
    );
  }
}

// ════════════════════ 알림 (웹 .toast) ════════════════════
class _ToastView extends StatelessWidget {
  const _ToastView(this.g, {required this.top});
  final GameController g;
  final double top;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: g.toastMsg,
        builder: (_, msg, __) => Positioned(
          left: 16,
          right: 16,
          top: (g.toastHigh ? 8 : 76) + top,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: msg == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xF0141A29),
                    border: Border.all(color: const Color(0x8CFFC94A)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Text(msg ?? '', textAlign: TextAlign.center, style: KdText.body(12.5, height: 1.4)),
                ),
              ),
            ),
          ),
        ),
      );
}

// ════════════════════ 제목 화면 (웹 .title) ════════════════════
class _Title extends StatelessWidget {
  const _Title(this.g);
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Positioned.fill(
      child: Stack(fit: StackFit.expand, children: [
        kdImg('assets/game/illust/illust_title.jpg', fit: BoxFit.cover, align: const Alignment(0, .4)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xF00A0E1A), Color(0x330A0E1A), Color(0x330A0E1A), Color(0xFA0A0E1A)],
              stops: [0, .34, .52, .78],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 56 + pad.top, 24, 48 + pad.bottom),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            FractionallySizedBox(
              widthFactor: .9,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 8))]),
                  child: kdImg('assets/game/ui/logo.png'),
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x990A0E1A), borderRadius: BorderRadius.circular(999)),
                child: Text('마족에게 빼앗긴 땅을 되찾는 농부의 여정',
                    textAlign: TextAlign.center,
                    style: KdText.display(14, color: Colors.white, weight: FontWeight.w500).copyWith(shadows: const [Shadow(blurRadius: 4)])),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: g.startFromTitle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD66B), Color(0xFFE0A020)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    border: Border.all(color: const Color(0xFFFFF3C4), width: 2),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFA8700A), offset: Offset(0, 5)),
                      BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Text('게임 시작', style: KdText.display(22, color: KdColors.goldInk)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
