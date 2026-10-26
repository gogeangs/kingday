/// 게임 전체 화면 — 웹 .app (상단 바 · 전투 화면 · 탭 화면 · 하단 탭 · 제목 화면 · 알림)
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data.dart';
import '../core/profile_data.dart';
import '../game/controller.dart';
import '../ui/fx.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'pages.dart';
import 'social_sheets.dart';
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
                  KeyedSubtree(key: g.tabsKey, child: ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => _Tabs(g, bottom: pad.bottom))),
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

  static Widget _fit(double max, Widget w) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: FittedBox(fit: BoxFit.scaleDown, child: w),
      );

  @override
  Widget build(BuildContext context) {
    final s = g.state, ri = g.calc.rankIdx();
    // 이삭·골드 칸이 쓸 수 있는 최대 폭: 얼굴(52)·간격·이름 최소 70 을 빼고 나눔
    final pillMax = math.max(60.0, (math.min(480.0, MediaQuery.sizeOf(context).width) - 24 - 52 - 18 - 70) / 2);
    final badge = g.calc.curBadge();
    final frame = g.calc.curFrame();
    return Container(
      padding: EdgeInsets.fromLTRB(12, math.max(8, top), 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0D1220), KdColors.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(bottom: BorderSide(color: Color(0xFF2A3350))),
      ),
      child: Row(children: [
        // 얼굴 + 프로필 테두리 + ⚙
        GestureDetector(
          onTap: () => openProfile(g),
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
                  child: DecoratedBox(
                    decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3B5A8A), Color(0xFF1A2440)])),
                    child: g.photoOn ? Image.memory(g.photoBytes!, fit: BoxFit.cover, gaplessPlayback: true) : FaceImg(g.calc.pubFace()),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: isTallFrame(frame) ? -52 * .15625 : 0,
                height: isTallFrame(frame) ? 52 * 1.15625 : 52,
                child: kdImg(frameAsset(frame), fit: BoxFit.fill),
              ),
              // 처음엔 「꾸미기」, 새 테두리·배지를 얻으면 빨간 점 (웹 .face.newpf / .pfdot)
              if (g.calc.pfNewbie())
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(color: const Color(0xFFFF5A6E), borderRadius: BorderRadius.circular(8)),
                      child: Text('꾸미기', style: KdText.body(9.5, color: Colors.white, weight: FontWeight.w600, height: 1.45)),
                    ),
                  ),
                )
              else if (g.calc.pfDot())
                const Positioned(top: -2, left: -2, child: _Dot()),
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
            // 웹 .who{min-width:0}: 자리가 모자라면 줄여서 보여 줌
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('카엘', maxLines: 1, style: KdText.display(15)),
              if (badge != null) ...[const SizedBox(width: 5), kdImg(badgeAsset(badge), w: 20, h: 20)],
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: KdColors.gold, borderRadius: BorderRadius.circular(999)),
                child: Text(ranks[ri].n, maxLines: 1, style: KdText.body(11, color: KdColors.goldInk, weight: FontWeight.w600, height: 1.3)),
              ),
            ])),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: NumFlash(g.calc.power(), prefix: '⚔ ', style: KdText.figure(13, color: KdColors.gold)),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        // 황금 이삭 (누르면 상점) — 숫자가 길면 좁은 폰에서 줄여 보여 줌
        _fit(pillMax, GestureDetector(
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
                NumFlash(s.gem, style: KdText.figure(14, color: const Color(0xFFFFE08A))),
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
        )),
        const SizedBox(width: 6),
        // 골드
        _fit(pillMax, Container(
          padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A),
            border: Border.all(color: const Color(0xFF3A4568)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 20, height: 18, child: OverflowBox(maxWidth: 26, maxHeight: 26, child: kdImg('assets/game/ui/ui_gold.png', w: 26, h: 26))),
            const SizedBox(width: 3),
            NumFlash(s.gold, big: true, style: KdText.figure(16, color: KdColors.fg)),
          ]),
        )),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.opt = false, this.n = 0});
  final bool opt;

  /// 2 이상이면 숫자 (웹 .dot.n)
  final int n;

  @override
  Widget build(BuildContext context) => n > 1
      ? Container(
          constraints: const BoxConstraints(minWidth: 16),
          height: 16,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: opt ? KdColors.gold : KdColors.bad,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: opt ? const Color(0xFF6B4F12) : Colors.white),
          ),
          child: Text(n > 9 ? '9+' : '$n', style: KdText.body(10.5, color: opt ? KdColors.goldInk : Colors.white, weight: FontWeight.w700, height: 1)),
        )
      : Container(
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
          Positioned(top: 8, right: 8, child: ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => SocialFabs(g))),
          // 반쯤 열린 창 위 빈 곳을 누르면 닫힘 (웹 .pgshade)
          if (half) Positioned(left: 0, right: 0, top: 0, height: top, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => g.setTab(null))),
          if (t != null)
            Positioned(left: 0, right: 0, top: top, bottom: 0, child: KeyedSubtree(key: g.pageKey, child: PageSheet(key: ValueKey(t), g: g, tab: t, half: half))),
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
    final dots = {GameTab.pt: g.ptDot, GameTab.up: g.dotOn(GameTab.up), GameTab.vl: g.dotOn(GameTab.vl), GameTab.mp: g.dotOn(GameTab.mp)};
    final nums = {GameTab.pt: g.calc.cardReady().length, GameTab.vl: g.vReadyN()};
    return Container(
      padding: EdgeInsets.fromLTRB(8, 5, 8, math.max(6, bottom - 18)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1A2135), Color(0xFF0D1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(top: BorderSide(color: KdColors.brass, width: 2)),
      ),
      child: Row(children: [
        for (final t in [GameTab.eq, GameTab.pt, GameTab.up, GameTab.vl, GameTab.mp]) ...[
          if (t != GameTab.eq) const SizedBox(width: 4),
          Expanded(child: _tab(t, dots[t] ?? false, nums[t] ?? 0)),
        ],
      ]),
    );
  }

  Widget _tab(GameTab t, bool dot, int n) {
    final on = g.tab == t;
    Widget icon = kdImg('assets/game/ui/${t.icon}.png', w: 38, h: 38);
    icon = on ? Transform.scale(scale: 1.08, child: icon) : filtered(icon, sat: .75, bright: .9);
    // 칸 전체를 누를 수 있고, 아이콘·글자는 칸 가운데 (2026-10-26 「하단 메뉴가 왼쪽으로 치우침」)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => g.setTab(t),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: double.infinity,
          alignment: Alignment.center,
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
        // 점 규칙(UX 점검 10): 원정대·단련·지도(할 수 있는 일)는 금색, 마을(받을 보상)은 빨강
        // 칸이 넓어져도 점은 아이콘 오른쪽 위 (가운데 기준으로 오른쪽으로 밀기)
        if (dot)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(left: n > 1 ? 40 : 30, top: n > 1 ? 0 : 3),
                  child: _Dot(opt: t == GameTab.pt || t == GameTab.up || t == GameTab.mp, n: n),
                ),
              ),
            ),
          ),
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
        builder: (ctx, msg, __) {
          // 전투 화면: 초상화 줄 바로 위 (영지 이름표·보스 막대를 가리지 않게). 창이 열려 있으면 맨 위
          double? bottom;
          double? yOf(GlobalKey k) {
            final rb = k.currentContext?.findRenderObject();
            return rb is RenderBox && rb.hasSize && rb.attached ? rb.localToGlobal(Offset.zero).dy : null;
          }
          final h = MediaQuery.sizeOf(ctx).height;
          if (!g.toastHigh && g.tab == null) {
            final y = yOf(g.partyRowKey);
            if (y != null) bottom = h - y + 8;
          } else if (!g.modalOpen && g.tab != null) {
            // 탭이 열려 있으면 위쪽 재화 줄을 가리지 않게: 탭 창 바로 위, 창이 화면을 다 덮으면 아래 탭 줄 바로 위 (웹 toastPos)
            final py = yOf(g.pageKey), ty = yOf(g.tabsKey);
            if (py != null && py > 90) {
              bottom = h - py + 8;
            } else if (ty != null) {
              bottom = h - ty + 10;
            }
          }
          return Positioned(
          left: 16,
          right: 16,
          top: bottom == null ? (g.toastHigh ? 8 : 76) + top : null,
          bottom: bottom,
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
        );
        },
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
        // 웹은 그림이 어둡게 하는 막(gradient) 위에 그려져 밝게 보임 → 그림만
        kdImg('assets/game/illust/illust_title.jpg', fit: BoxFit.cover, align: const Alignment(0, .4)),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 56 + pad.top, 24, 48 + pad.bottom),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            FractionallySizedBox(
              widthFactor: .9,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                // 웹 filter: drop-shadow — 글자 모양 그대로 그림자 (네모 상자 그림자 아님)
                child: Stack(children: [
                  Transform.translate(
                    offset: const Offset(0, 8),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                      child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x80000000), BlendMode.srcIn), child: kdImg('assets/game/ui/logo.png')),
                    ),
                  ),
                  kdImg('assets/game/ui/logo.png'),
                ]),
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
