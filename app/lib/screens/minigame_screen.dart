/// 미니게임 「선물 배달」 화면 (docs/content/EVENT_SNOW.md 3-9~3-11) — 웹 #mgOv · mgDraw · mgLoop · mgTap · mgX · mgEnd 의 결과 판,
/// 랭킹 결과 창(evMgResultSheet)·외형 고르기 창(skinSheet)의 모양.
///
/// 판 계산은 core/minigame.dart (MgGame, 1/60초 고정 단위), 판 수·보상·서버는 game/controller_mg.dart 가 [MgHost] 로 맡는다.
/// 화면이 몇 번 그려지든 실제 흐른 시간만큼 고정 단위로 진행하므로 기기 빠르기와 관계없이 같은 판이 된다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/calc.dart';
import '../core/event.dart';
import '../core/fmt.dart';
import '../core/minigame.dart';
import '../game/controller.dart';
import '../ui/image_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_sheet.dart' show HdBanner;

/// 판 하나의 준비 결과 (웹 evMgStart 가 MGS 에 넣던 값)
class MgPlan {
  const MgPlan({required this.seed, required this.practice, this.tok, this.hint = false, this.demo = false});
  final int seed;
  final bool practice;

  /// 서버 판 번호 (kd_mg_start 의 id). 없으면 랭킹에 안 올라감
  final Object? tok;

  /// 처음 판 안내 손가락 (웹 !S.mgPlayed)
  final bool hint;

  /// 미리보기(기록 안 함, 웹 noSave)
  final bool demo;
}

/// 판이 끝난 뒤 결과 판에 보일 것 (웹 mgEnd 의 #mgPan)
class MgEnd {
  MgEnd({required this.title, required this.score, required this.best, required this.practice, this.sf = 0, this.curImg = '', this.curN = '', required this.left, ValueNotifier<String>? rank})
      : rank = rank ?? ValueNotifier<String>('');
  final String title, curImg, curN;
  final int score, sf, left;
  final bool best, practice;

  /// 랭킹 기록 줄 (서버 답이 오면 바뀜, 웹 #mgRk)
  final ValueNotifier<String> rank;
}

/// 화면이 게임 쪽에 부탁하는 일
abstract class MgHost {
  ValueListenable<String?> get toastMsg;
  void toast(String m);
  void haptic(List<int> p);

  /// 판 준비 (보상 판이면 판 수를 쓰고 서버에서 판 번호를 받음). plan 이 null 이면 시작 못 함(알림은 host 가 띄움),
  /// close 가 true 면 화면을 닫음. [gone] 이 true 면 기다리는 사이 화면이 닫힌 것 → 판을 돌려줌
  Future<(MgPlan?, bool)> prepare(bool practice, bool Function() gone);

  /// 판 끝: 보상·최고 기록·서버 제출 (웹 mgEnd)
  MgEnd finish(MgPlan plan, int score);

  /// 「랭킹」 · 「닫기」(이벤트 창으로): 화면이 닫힌 뒤 할 일을 정해 둠
  void rank();
  void done();
}

/// 선물 배달 화면 (웹 .mgov). [seed] 는 시험용(판 번호 고정)
class MinigameScreen extends StatefulWidget {
  const MinigameScreen({super.key, required this.host, required this.practice, this.seed});
  final MgHost host;
  final bool practice;
  final int? seed;

  @override
  State<MinigameScreen> createState() => _MgState();
}

class _MgState extends State<MinigameScreen> with SingleTickerProviderStateMixin {
  late final Ticker _tk;
  MgGame _g = MgGame(1);
  MgPlan? _plan;

  /// 'wait' 준비 중 · 'ready' 3-2-1 · 'play' 진행 · 'end' 결과
  String _ph = 'wait';
  double _cd = 3, _acc = 0, _clock = 0;
  Duration? _last;
  String? _wait;
  MgEnd? _end;
  int _xT = -100000;
  bool _gone = false, _busy = false;
  final _rep = ValueNotifier<int>(0);

  bool get practice => _plan?.practice ?? widget.practice;

  @override
  void initState() {
    super.initState();
    _tk = createTicker(_tick)..start();
    _wait = widget.practice ? null : '썰매 준비 중…';
    _busy = true;
    _prep(widget.practice, 'wait', null);
  }

  @override
  void dispose() {
    _gone = true;
    _tk.dispose();
    super.dispose();
  }

  /// 웹 evMgStart 의 화면 쪽: 준비 → 새 판 → 3초 세기
  Future<void> _begin(bool pr) async {
    if (_busy) return;
    _busy = true;
    final prevPh = _ph, prevEnd = _end;
    setState(() {
      _ph = 'wait';
      _end = null;
      _wait = pr ? null : '썰매 준비 중…';
    });
    await _prep(pr, prevPh, prevEnd);
  }

  Future<void> _prep(bool pr, String prevPh, MgEnd? prevEnd) async {
    final (plan, close) = await widget.host.prepare(pr, () => _gone || !mounted);
    _busy = false;
    if (!mounted || _gone) return;
    if (plan == null) {
      if (close || prevEnd == null) {
        _close();
        return;
      }
      setState(() {
        _ph = prevPh;
        _end = prevEnd;
        _wait = null;
      });
      return;
    }
    setState(() {
      _plan = plan;
      _g = MgGame(widget.seed ?? plan.seed);
      _ph = 'ready';
      _cd = 3;
      _acc = 0;
      _wait = null;
    });
  }

  /// 웹 mgLoop: 실제 흐른 시간(최대 0.1초)을 모아 1/60초 단위로 진행
  void _tick(Duration el) {
    final real = _last == null ? 0.0 : ((el - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1).toDouble();
    _last = el;
    _clock += real;
    if (_ph == 'ready') {
      _cd -= real;
      if (_cd <= 0) _ph = 'play';
    } else if (_ph == 'play') {
      final dt = Mgc.dt.toDouble();
      _acc += real;
      while (_acc >= dt && !_g.over) {
        _acc -= dt;
        _g.step();
      }
      if (_g.over) _finish();
    }
    _rep.value++;
  }

  void _finish() {
    if (_ph == 'end' || _plan == null) return;
    _ph = 'end';
    final end = widget.host.finish(_plan!, _g.score);
    widget.host.haptic(const [30, 40, 70]);
    setState(() => _end = end);
  }

  void _tap() {
    if (_ph == 'play') _g.tap();
  }

  /// 웹 mgX: 보상 판 도중에는 2.5초 안에 한 번 더 눌러야 나감 (이번 판은 0점)
  void _x() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_ph == 'play' && !practice && now - _xT > 2500) {
      _xT = now;
      widget.host.toast('한 번 더 누르면 나가요 · 이번 판은 0점이에요');
      return;
    }
    _close();
  }

  void _close() {
    if (_gone) return;
    _gone = true;
    _tk.stop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _x();
      },
      child: Material(
        color: const Color(0xFF070B1C),
        child: SafeArea(
          child: LayoutBuilder(builder: (ctx, bc) {
            final w = math.min(math.min(bc.maxWidth, 480.0), (bc.maxHeight - 8) * .8), h = w / .8;
            return Stack(children: [
              Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(children: [
                    Positioned.fill(
                      child: Listener(
                        key: const ValueKey('mgCanvas'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => _tap(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CustomPaint(painter: _MgPainter(this, _rep), size: Size(w, h)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        key: const ValueKey('mgX'),
                        onTap: _x,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x99080C1E),
                            border: Border.all(color: const Color(0x59FFFFFF)),
                          ),
                          child: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ),
                    if (_ph == 'wait' && _wait != null) Center(child: _panel(w, [Text(_wait!, textAlign: TextAlign.center, style: KdText.body(14, color: KdColors.muted))])),
                    if (_ph == 'end' && _end != null) Center(child: _panel(w, _endKids(_end!))),
                  ]),
                ),
              ),
              _toast(),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _panel(double w, List<Widget> kids) => Container(
        width: math.min(w * .92, 360),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xF0141A30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B5385)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: kids),
      );

  /// 결과 판 (웹 mgEnd 의 #mgPan)
  List<Widget> _endKids(MgEnd d) {
    final pr = d.practice, left = d.left;
    Widget btn(String t, VoidCallback? on, {bool pri = false, Key? key}) => Opacity(
          opacity: on == null ? .45 : 1,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: on,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pri ? KdColors.gold : KdColors.panel2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pri ? KdColors.gold : KdColors.line),
              ),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, style: KdText.body(13.5, color: pri ? KdColors.goldInk : KdColors.fg, weight: FontWeight.w700))),
            ),
          ),
        );
    void leave(VoidCallback f) {
      f();
      _close();
    }

    return [
      Text(d.title, style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${fmt(d.score)}점'),
          if (d.best) TextSpan(text: ' 최고 기록!', style: KdText.body(13, color: const Color(0xFFFF9A3C), weight: FontWeight.w700)),
        ]),
        key: const ValueKey('mgScore'),
        textAlign: TextAlign.center,
        style: KdText.display(30, color: const Color(0xFFFFE08A)),
      ),
      Text('굴뚝 ${_g.hits}개 · 딱 맞음 ${_g.perfN}번 · 최대 ${_g.maxC}연속', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted)),
      if (pr)
        Text('연습판은 보상·기록이 없어요', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted))
      else ...[
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (d.curImg.isNotEmpty) kdImg(d.curImg, w: 26, h: 26),
          const SizedBox(width: 4),
          Text('+${d.sf}', style: KdText.figure(18, color: KdColors.gold)),
          const SizedBox(width: 6),
          Flexible(child: Text('${d.curN} (점수 ÷ 10, 최대 100)', style: KdText.body(12, color: KdColors.muted))),
        ]),
        ValueListenableBuilder<String>(
          valueListenable: d.rank,
          builder: (_, v, __) => v.isEmpty ? const SizedBox.shrink() : Text(v, textAlign: TextAlign.center, style: KdText.body(12.5, color: KdColors.muted)),
        ),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: btn(pr ? '연습 다시' : left > 0 ? '한 판 더 ($left)' : '오늘 판 끝', !pr && left <= 0 ? null : () => _begin(pr), key: const ValueKey('mgAgain'))),
        const SizedBox(width: 6),
        Expanded(child: pr ? btn('보상 판 ($left)', left > 0 ? () => _begin(false) : null) : btn('연습', () => _begin(true))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: btn('랭킹', () => leave(widget.host.rank))),
        const SizedBox(width: 6),
        Expanded(child: btn('닫기', () => leave(widget.host.done), pri: true, key: const ValueKey('mgDone'))),
      ]),
    ];
  }

  /// 알림 (게임 화면의 알림은 이 화면에 가려지므로 여기서도 보여 줌)
  Widget _toast() => ValueListenableBuilder<String?>(
        valueListenable: widget.host.toastMsg,
        builder: (_, msg, __) => Positioned(
          left: 16,
          right: 16,
          top: 50,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: msg == null ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xF0141A29), borderRadius: BorderRadius.circular(999), border: Border.all(color: KdColors.line)),
                  child: Text(msg ?? '', textAlign: TextAlign.center, style: KdText.body(14)),
                ),
              ),
            ),
          ),
        ),
      );
}

// ════════════════════ 그리기 (웹 mgDraw, 512×640 좌표) ════════════════════
class _MgPainter extends CustomPainter {
  _MgPainter(this.st, Listenable rep) : super(repaint: rep);
  final _MgState st;

  static ui.Image? _im(String n) => ImageStore.get('assets/game/mini/$n${n == 'bg_night' ? '.jpg' : '.png'}');
  static Color _al(Color c, double a) => c.withValues(alpha: c.a * a.clamp(0.0, 1.0).toDouble());

  /// 글자 (y = 글자 바닥선, 웹 fillText 와 같게). stroke 가 있으면 테두리 먼저
  static void _txt(Canvas c, String s, double x, double y,
      {required double size, required Color color, FontWeight w = FontWeight.w700, String family = KdFonts.body, TextAlign align = TextAlign.left, Color? stroke, double sw = 0}) {
    TextPainter mk(Paint? fg) => TextPainter(
          text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, fontWeight: w, color: fg == null ? color : null, foreground: fg)),
          textDirection: TextDirection.ltr,
        )..layout();
    final tp = mk(null);
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = align == TextAlign.center
        ? -tp.width / 2
        : align == TextAlign.right
            ? -tp.width
            : 0.0;
    final o = Offset(x + dx, y - base);
    if (stroke != null) {
      final sp = mk(Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeJoin = StrokeJoin.round
        ..color = stroke);
      sp.paint(c, o);
      sp.dispose();
    }
    tp.paint(c, o);
    tp.dispose();
  }

  static void _img(Canvas c, ui.Image im, Rect src, Rect dst, [double a = 1]) => c.drawImageRect(
      im,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0).toDouble()));

  @override
  void paint(Canvas c, Size size) {
    final W = Mgc.W.toDouble(), H = Mgc.H.toDouble(), ground = Mgc.ground.toDouble();
    final sledX = Mgc.sledX.toDouble(), sledY = Mgc.sledY.toDouble(), dropY = Mgc.dropY.toDouble();
    final g = st._g, tt = g.t.toDouble(), gx = g.x.toDouble();
    c.save();
    c.scale(size.width / W);
    // 밤하늘·먼 마을 (가로로 이어짐)
    final bg = _im('bg_night');
    if (bg != null && bg.width > 1) {
      final bw = bg.width * H / bg.height, off = (gx * .25) % bw;
      for (var bx = -off; bx < W; bx += bw) {
        _img(c, bg, Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()), Rect.fromLTWH(bx, 0, bw + 1, H));
      }
    } else {
      c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0xFF101A3C));
    }
    // 땅 눈
    c.drawRect(
        Rect.fromLTWH(0, ground - 20, W, H - ground + 20),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, ground - 20), Offset(0, H), const [Color(0x00E1ECFA), Color(0xFFE3EDF8), Color(0xFFB9CBE2)], const [0, .35, 1]));
    // 집
    for (final h in g.hs) {
      final im = _im('house_${h.ty.startsWith('h') ? h.ty.substring(1) : h.ty}');
      final sx = (h.wx - gx).toDouble(), hw = h.w.toDouble(), hh = h.h.toDouble();
      if (sx < -hw || sx > W + hw) continue;
      if (im != null && im.width > 1) _img(c, im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), Rect.fromLTWH(sx - hw / 2, ground - hh + 6, hw, hh));
      if (h.done && h.ty != 'smoke') {
        _txt(c, '✔', (h.cx - gx).toDouble(), (h.cy - 14).toDouble(), size: 15, color: const Color(0xE6FFE678), family: KdFonts.body, align: TextAlign.center);
      }
    }
    // 썰매 (위아래로 살짝 흔들림 — 선물 떨어지는 높이는 그대로)
    final sl = _im('sled');
    if (sl != null && sl.width > 1) {
      final fw = sl.width / 4, sw = 156.0, sh = sw * sl.height / fw, fr = (tt * 10).floor() % 4;
      _img(c, sl, Rect.fromLTWH(fr * fw, 0, fw, sl.height.toDouble()), Rect.fromLTWH(sledX - sw / 2, sledY - sh / 2 + math.sin(tt * 3) * 3, sw, sh));
    }
    // 선물
    for (final q in g.gifts) {
      final im = _im('gift_${q.k + 1}');
      c.save();
      c.translate(q.x.toDouble(), q.y.toDouble());
      c.rotate(math.sin(q.r) * .3);
      if (im != null && im.width > 1) {
        _img(c, im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), const Rect.fromLTWH(-15, -15, 30, 30));
      } else {
        c.drawRect(const Rect.fromLTWH(-12, -12, 24, 24), Paint()..color = const Color(0xFFE04A5A));
      }
      c.restore();
    }
    // 쏙! · 퍽 · 콜록
    for (final v in g.ev) {
      final a = tt - v.t.toDouble();
      if (a > .9 || a < 0) continue;
      final sx = (v.x - (gx - v.gx)).toDouble(), vy = v.y.toDouble(), al = 1 - a / .9;
      if (v.k == 'in') {
        final fi = _im('fx_in');
        if (fi != null && fi.width > 1 && a < .36) {
          final fw = fi.width / 3, f = math.min(2, (a / .12).floor());
          _img(c, fi, Rect.fromLTWH(f * fw, 0, fw, fi.height.toDouble()), Rect.fromLTWH(sx - 40, vy - 70, 80, 80 * (fi.height / fw)), al);
        }
        final tx = '+${fmt(v.p)}${v.pf ? ' 딱 맞음!' : ''}';
        _txt(c, tx, sx, vy - 40 - a * 50,
            size: v.pf ? 22 : 19,
            w: FontWeight.w800,
            family: KdFonts.display,
            align: TextAlign.center,
            color: _al(v.gold ? const Color(0xFFFFD34A) : v.pf ? const Color(0xFF9CF0FF) : const Color(0xFFFFF3C4), al),
            stroke: _al(const Color(0xFF1B0F04), al),
            sw: 4);
      } else {
        final smoke = v.k == 'smoke';
        _txt(c, smoke ? '콜록! 연속 끊김' : '퍽!', sx, vy - 20 - a * 30,
            size: 16, align: TextAlign.center, color: _al(smoke ? const Color(0xFFC9C9C9) : const Color(0xFFBCD6FF), al), stroke: _al(const Color(0xFF0B1230), al), sw: 3);
      }
    }
    // 위쪽: 점수 · 남은 시간 · 연속 배수
    final T = Mgc.T.toDouble(), left = math.max(0.0, T - tt);
    c.drawRect(Rect.fromLTWH(0, 0, W, 46), Paint()..color = const Color(0x8C080C1E));
    c.drawRect(Rect.fromLTWH(12, 38, W - 24, 5), Paint()..color = const Color(0xFF2A3A66));
    c.drawRect(Rect.fromLTWH(12, 38, (W - 24) * (left / T), 5), Paint()..color = left < 5 ? const Color(0xFFFF6B7D) : const Color(0xFF9CD8FF));
    _txt(c, fmt(g.score), 14, 29, size: 24, w: FontWeight.w800, family: KdFonts.display, color: const Color(0xFFFFE08A));
    _txt(c, '${st.practice ? '연습 · ' : ''}${left.ceil()}초', W / 2, 27, size: 15, align: TextAlign.center, color: const Color(0xFFE6EEFF));
    if (g.combo > 0) {
      final m = mgMul(g.combo);
      _txt(c, '${g.combo}연속 ×$m', W - 54, 29,
          size: 18,
          w: FontWeight.w800,
          family: KdFonts.display,
          align: TextAlign.right,
          color: m >= 5
              ? const Color(0xFFFF9A3C)
              : m >= 3
                  ? const Color(0xFFFFD34A)
                  : const Color(0xFFBFE8FF));
    }
    // 처음 판 안내 손가락
    final plan = st._plan;
    if (plan != null && plan.hint && st._ph != 'end' && st._ph != 'wait' && tt < 7) {
      MgHouse? nx;
      for (final h in g.hs) {
        if (!h.done && h.ty != 'smoke' && h.cx - gx > sledX + 20) {
          nx = h;
          break;
        }
      }
      c.drawRect(Rect.fromLTWH(W / 2 - 170, 250, 340, 34), Paint()..color = const Color(0xB3080C1E));
      _txt(c, '굴뚝이 오기 조금 전에 눌러요', W / 2, 273, size: 16, align: TextAlign.center, color: const Color(0xFFFFF6D6));
      _txt(c, '👆', sledX + 6, dropY + 60 + math.sin(st._clock * 8) * 6, size: 34, w: FontWeight.w400, align: TextAlign.center, color: const Color(0xF2FFFFFF));
      if (nx != null) {
        final p = Paint()
          ..color = const Color(0xCCFFF0AA)
          ..strokeWidth = 1;
        for (var y = dropY; y < ground - 40; y += 10) {
          c.drawLine(Offset(sledX + 4, y), Offset(sledX + 4, math.min(y + 5, ground - 40)), p);
        }
      }
    }
    if (st._ph == 'ready') {
      c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0x73080C1E));
      final n = math.max(1, st._cd.ceil());
      _txt(c, '$n', W / 2, H / 2, size: 72, w: FontWeight.w800, family: KdFonts.display, align: TextAlign.center, color: const Color(0xFFFFE08A), stroke: const Color(0xFF1B0F04), sw: 6);
      _txt(c, st.practice ? '연습판 · 보상·기록 없음' : '화면을 누르면 선물이 떨어져요', W / 2, H / 2 + 44, size: 17, align: TextAlign.center, color: Colors.white);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_MgPainter old) => true;
}

// ════════════════════ 랭킹 결과 창 (웹 evMgResultSheet) ════════════════════
class MgResultBody extends StatelessWidget {
  const MgResultBody({super.key, required this.e, required this.rank, required this.total, required this.score, required this.rw, required this.top, required this.nw, required this.onRank, required this.onMail});
  final EventDef e;
  final int rank, total, score;

  /// 순위 보상 글 (없으면 '')
  final String rw;
  final bool top, nw;
  final VoidCallback onRank, onMail;

  @override
  Widget build(BuildContext context) {
    final hd = e.art['hd'] ?? '';
    final hdName = hd.split('/').last.replaceAll('.png', '');
    return KdSheetBody(
      titleWidget: HdBanner(hdName.isEmpty ? 'hd_rank' : hdName, '선물 배달 랭킹', size: 17),
      children: [
        if (top) Center(child: kdImg('assets/game/portraits/portrait_kael_santa_laugh.png', w: 120, h: 120)),
        Text('선물 배달 $rank위!', textAlign: TextAlign.center, style: KdText.display(20)),
        Text('${fmt(score)}점 · ${fmt(total)}명 참여', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted)),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: KdColors.line)),
          child: Column(children: [
            if (rw.isNotEmpty) Text(rw, textAlign: TextAlign.center, style: KdText.body(14, color: KdColors.gold, weight: FontWeight.w700)),
            Text('참가 보상 ${e.curN} 100${rw.isEmpty ? ' (모두에게)' : ''}', textAlign: TextAlign.center, style: KdText.body(12.5, color: KdColors.muted)),
          ]),
        ),
        if (top)
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '외형 「산타 카엘」을 받았어요!${nw ? ' 지금 카엘이 산타 옷을 입었어요' : ''}\n'),
              TextSpan(text: '장비 탭 카엘 칸 「외형」에서 바꿀 수 있어요', style: KdText.body(12, color: KdColors.muted)),
            ]),
            textAlign: TextAlign.center,
            style: KdText.body(13.5, color: const Color(0xFFFFD34A)),
          ),
        Text('보상은 우편함에서 받아요', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted)),
      ],
      acts: KdActs(buttons: [
        KdAct('랭킹 보기', onTap: onRank),
        KdAct('우편함', primary: true, onTap: onMail),
      ]),
    );
  }
}

// ════════════════════ 외형 고르기 (웹 skinSheet · 장비 탭 카엘 칸 「외형」) ════════════════════
class SkinSheetBody extends StatefulWidget {
  const SkinSheetBody(this.g, this.sheet, {super.key});
  final GameController g;
  final BuildContext sheet;

  @override
  State<SkinSheetBody> createState() => _SkinSheetState();
}

class _SkinSheetState extends State<SkinSheetBody> {
  GameController get g => widget.g;

  String get _cur => g.state.raw['skin'] is String ? g.state.raw['skin'] as String : '';

  void _pick(String k) {
    g.state.raw['skin'] = k;
    g.haptic();
    g.save();
    g.refresh();
    setState(() {});
  }

  Widget _row(String k, String n, String face, Widget sub, bool ok) {
    final on = _cur == k;
    return Opacity(
      opacity: ok ? 1 : .55,
      child: GestureDetector(
        key: ValueKey('skin_$k'),
        behavior: HitTestBehavior.opaque,
        onTap: ok && !on ? () => _pick(k) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0x26FFC94A) : KdColors.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? KdColors.gold : KdColors.line),
          ),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 52, height: 52, child: kdImg('assets/game/portraits/portrait_${face}_idle.png', fit: BoxFit.cover))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n, style: KdText.body(15, weight: FontWeight.w700)),
                DefaultTextStyle.merge(style: KdText.body(12.5, color: KdColors.muted), child: sub),
              ]),
            ),
            const SizedBox(width: 6),
            Text(on ? '쓰는 중' : ok ? '고르기' : '🔒', style: KdText.body(13, color: on ? KdColors.gold : KdColors.fg, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = g.calc, skins = g.state.raw['skins'];
    return KdSheetBody(
      eyebrow: '카엘',
      title: '외형',
      children: [
        Text('겉모습만 바뀌어요. 능력은 그대로예요${c.owned(GameCalc.chiefId) ? ' · 카엘 촌장에는 적용되지 않아요' : ''}', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted)),
        _row('', '기본 카엘', 'kael', const Text('밀짚모자 농부 용사'), true),
        for (final sk in skinDefs.values)
          () {
            final has = c.skinHas(sk.k);
            final raw = skins is Map && skins[sk.k] is List ? skins[sk.k] as List : const [];
            final ys = [for (final y in raw) if (y is num && y > 0) y.toInt()];
            return _row(
              sk.k,
              sk.n,
              sk.face,
              has
                  ? ys.isNotEmpty
                      ? Text(sk.tag(ys), style: KdText.body(12.5, color: const Color(0xFFFFD34A), weight: FontWeight.w700))
                      : const Text('받은 외형')
                  : Text(sk.how),
              has,
            );
          }(),
      ],
      acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop())]),
    );
  }
}
