/// 원정 일지(시즌 패스) 창 · 상점 배너 — 웹 passSheet · passBanner (docs/content/SHOP.md 4장 · 2026-11-16 무료 줄 하나)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/actions.dart';
import '../core/data.dart';
import '../core/event.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../core/web_data.g.dart';
import '../game/controller.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _ink = Color(0xFF4A2A0E);

/// 남은 시간 글 (○일 남음 · ○시간 남음)
String passLeftTxt(GameController g) {
  final l = g.calc.seasonLeft();
  return l >= 1 ? '${l.ceil()}일 남음' : '${math.max(1, (l * 24).ceil())}시간 남음';
}

/// 원정 일지 열기: 처음이면 피트 대사부터
void openPass(GameController g) {
  final p = g.acts.passS();
  if (!truthy(p['intro'])) {
    p['intro'] = 1;
    g.save();
    g.scene('피트의 상점', '원정 일지 · 시즌 ${p['s']}', const [
      'm:피트|영주님! 이번 시즌 「원정 일지」예요. 평소처럼 싸우고 일하시면 칸이 채워져요.',
      'k:일기 쓰라는 거야?',
      'm:피트|아뇨, 쓰는 건 제가 해요. 영주님은 받기만!',
    ], '원정 일지 보기', onGo: () => Future.microtask(() => openPass(g)));
    return;
  }
  g.openSheet<void>((ctx) => _PassSheet(g, ctx));
}

class _PassSheet extends StatefulWidget {
  const _PassSheet(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_PassSheet> createState() => _PassSheetState();
}

class _PassSheetState extends State<_PassSheet> {
  final _sc = ScrollController();
  static const _cw = 66.0, _gap = 6.0, _pad = 10.0;

  @override
  void initState() {
    super.initState();
    // 창은 맨 위(원정 일지 간판)부터, 가로 줄은 받을 칸(없으면 지금 단계)이 가운데 오게 (대표님 제보 10-27)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final v = Scrollable.maybeOf(context);
      if (v != null && v.position.axis == Axis.vertical && v.position.pixels != 0) v.position.jumpTo(0);
      if (!_sc.hasClients) return;
      final a = widget.g.acts, steps = GameActions.passSteps;
      var at = a.passLv().clamp(0, steps - 1).toInt();
      for (var i = 0; i < steps; i++) {
        if (a.passCan('f', i)) {
          at = i;
          break;
        }
      }
      final vw = _sc.position.viewportDimension;
      _sc.jumpTo((_pad + at * (_cw + _gap) - vw / 2 + _cw / 2).clamp(0.0, _sc.position.maxScrollExtent).toDouble());
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Widget _cell(GameActions a, String row, int i, Map<String, dynamic> p) {
    final r = Map<String, dynamic>.from(wPassRew[i][row]!);
    final can = a.passCan(row, i), has = a.passHas(row, i);
    final ks = r.keys.toList(), multi = ks.length > 1;
    Widget ic(String k) {
      final (img, t) = switch (k) {
        'idle' => ('assets/game/ui/ui_gold.png', asNum(r['idle']) < 1 ? '${(asNum(r['idle']) * 60).round()}분' : '${fmt(asNum(r['idle']))}시간'),
        'ore' => ('assets/game/ui/item_ore.png', fmt(asNum(r['ore']))),
        'seed' => ('assets/game/ui/seed_wheat.png', '씨앗'),
        'gem' => (gemIcon, fmt(asNum(r['gem']))),
        'card' => ('assets/game/ui/card_pack3.png', '×${fmt(asNum(r['card']))}'),
        'box10' => ('assets/game/ui/item_box10ticket.png', '10연속'),
        'ucard' => ('assets/game/ui/card_unique.png', '×${fmt(asNum(r['ucard']))}'),
        _ => (frameAsset(GameActions.passFrameK(asNum(p['s']).toInt())), '테두리'),
      };
      return Column(mainAxisSize: MainAxisSize.min, children: [
        kdImg(img, w: 30, h: 30),
        Text(t, style: KdText.body(10.5, weight: FontWeight.w700)),
      ]);
    }

    return GestureDetector(
      onTap: () {
        if (can) {
          widget.g.act((x) => x.passClaim(row, i));
          setState(() {});
        }
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: ks.length > 2 ? 126 : multi ? 96 : _cw,
          height: 68,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: KdColors.panel2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: can ? const Color(0xFFFFD34A) : KdColors.line),
            boxShadow: can ? const [BoxShadow(color: Color(0x99FFD34A), blurRadius: 8)] : null,
          ),
          child: Opacity(
            opacity: has ? .45 : 1,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final k in ks) Flexible(child: ic(k))]),
          ),
        ),
        // 받은 칸: ✓ 는 칸 안 오른쪽 위
        if (has)
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFF2F8F55), shape: BoxShape.circle),
              child: const Text('✓', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, height: 1)),
            ),
          )
        else if (can)
          const Positioned(bottom: -5, left: 0, right: 0, child: Center(child: _Pill('받기', Color(0xFFFFD34A), Color(0xFF2A1A06)))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: widget.g.ui,
        builder: (_, __, ___) {
          final g = widget.g, a = g.acts, p = a.passS(), lv = a.passLv(), n = a.passCanN();
          final steps = GameActions.passSteps, per = GameActions.passPer;
          final pt = orNum(p['pt'], 0), inLv = lv >= steps ? per : pt % per;
          final left = passLeftTxt(g);
          return KdSheetBody(
            titleWidget: const _PassHd(),
            children: [
              Column(children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '시즌 ${p['s']}', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' · $left · '),
                    TextSpan(text: '$lv/$steps', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
                    const TextSpan(text: '단계'),
                  ]),
                  style: KdText.body(13, color: KdColors.muted),
                ),
                const SizedBox(height: 4),
                FractionallySizedBox(widthFactor: .7, child: XpBar((inLv / per).toDouble())),
                const SizedBox(height: 3),
                Text(lv >= steps ? '20단계를 모두 채웠어요!' : '${math.min(steps, lv + 1)}단계까지 ${fmt(per - inLv)}점', style: KdText.body(11.5, color: KdColors.muted)),
              ]),
              // 20칸 한 줄 가로 밀기 (2026-11-16 유료 줄 없앰)
              SizedBox(
                height: 18 + 6 + 68 + 12,
                child: Row(children: [
                  // 양끝을 흐리게 — 옆으로 더 있다는 표시 (대표님 제보 10-27)
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                        stops: [0, .06, .94, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: ListView.separated(
                      controller: _sc,
                      padding: const EdgeInsets.symmetric(horizontal: _pad),
                      scrollDirection: Axis.horizontal,
                      itemCount: steps,
                      separatorBuilder: (_, __) => const SizedBox(width: _gap),
                      itemBuilder: (_, i) => Column(children: [
                        Container(
                          width: 26,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i < lv ? const Color(0xFFC98A1E) : KdColors.panel2,
                            borderRadius: BorderRadius.circular(9),
                            border: i == lv ? Border.all(color: const Color(0xFFFFD34A), width: 2) : null,
                          ),
                          child: Text('${i + 1}', style: KdText.body(11, color: i < lv ? Colors.white : KdColors.muted, weight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 6),
                        _cell(a, 'f', i, p),
                      ]),
                    ),
                    ),
                  ),
                ]),
              ),
              Text('10단계·20단계에 유니크 카드 · 20단계에서 시즌 ${p['s']} 한정 테두리!', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
              const KdSec('오늘 얻은 점수', small: '할 일마다 하루 한도'),
              // 눈사람 대장 도전은 이벤트 기간에만 (웹 evPassSrc 의 PASS_SRC.snow · 맨 뒤에 붙음)
              for (final e in [...wPassSrc.entries, if (g.calc.evBossOn()) const MapEntry<String, List<Object>>('snow', [20, 20, '눈사람 대장 도전'])])
                Builder(builder: (_) {
                  final got = a.passToday(e.key), mx = asNum(e.value[1]);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0x08FFFFFF), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${e.value[2]} '),
                          TextSpan(text: '+${e.value[0]}', style: const TextStyle(color: Color(0xFFFFD34A), fontSize: 11)),
                        ]), style: KdText.body(12.5)),
                      ),
                      Text('${fmt(got)} / ${fmt(mx)}', style: KdText.figure(12.5, color: got >= mx ? const Color(0xFF9BE3A8) : KdColors.fg)),
                    ]),
                  );
                }),
            ],
            acts: KdActs(buttons: [
              if (n > 0) KdAct('$n개 받기', primary: true, claim: true, onTap: () => g.act((x) => x.passClaim())),
              KdAct('닫기', primary: n == 0, onTap: () => Navigator.of(widget.sheet).pop()),
            ]),
          );
        },
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.t, this.bg, this.fg);
  final String t;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: KdText.body(10, color: fg, weight: FontWeight.w700, height: 1.4)),
      );
}

/// 창 머리: 원정 일지 배너 위에 이름 (양피지라 짙은 갈색 글자)
class _PassHd extends StatelessWidget {
  const _PassHd();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: AspectRatio(
            aspectRatio: 720 / 208,
            child: Stack(fit: StackFit.expand, children: [
              kdImg('assets/game/ui/hd_pass.png', fit: BoxFit.contain),
              Center(child: Text('원정 일지', style: KdText.display(18, color: _ink))),
            ]),
          ),
        ),
      );
}

/// 피트의 가게(마을) 맨 위 배너: 시즌 · 남은 날 · 단계 + 진행 막대 (누르면 패스 창)
class PassBanner extends StatelessWidget {
  const PassBanner(this.g, {super.key});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final a = g.acts, p = a.passS(), lv = a.passLv(), n = a.passCanN();
    final total = GameActions.passSteps * GameActions.passPer;
    return GestureDetector(
      onTap: () => openPass(g),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A2216), Color(0xFF1D1810)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: Border.all(color: const Color(0xFF6B5420)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AspectRatio(
                aspectRatio: 720 / 208,
                child: Stack(fit: StackFit.expand, children: [
                  kdImg('assets/game/ui/hd_pass.png', fit: BoxFit.contain),
                  Center(child: Text('원정 일지', style: KdText.display(18, color: _ink))),
                ]),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '시즌 ${p['s']} · ${passLeftTxt(g)} · '),
                  TextSpan(text: '$lv/${GameActions.passSteps}', style: const TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700)),
                  const TextSpan(text: '단계'),
                  if (n > 0) TextSpan(text: ' · 받을 보상 $n', style: const TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700)),
                ]),
                style: KdText.body(12, color: const Color(0xFFE8D8B0)),
              ),
            ),
            const SizedBox(height: 5),
            FractionallySizedBox(widthFactor: .9, child: XpBar((orNum(p['pt'], 0) / total).clamp(0, 1).toDouble())),
          ]),
        ),
        if (n > 0) const Positioned(top: -4, left: 8, child: KdRedDot()),
      ]),
    );
  }
}
