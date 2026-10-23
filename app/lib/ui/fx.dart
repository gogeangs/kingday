/// 그림 효과 — 웹 CSS filter(grayscale·brightness·saturate)와 얼굴 확대(faceTo)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import 'widgets.dart';

/// CSS filter: grayscale(g) brightness(b) saturate(s) 를 색 행렬로
ColorFilter cssFilter({double gray = 0, double bright = 1, double sat = 1}) {
  // saturate: 0 이면 흑백, 1 이면 그대로. grayscale(g) == saturate(1-g)
  final s = sat * (1 - gray);
  const lr = .2126, lg = .7152, lb = .0722;
  final a = (1 - s) * lr, b = (1 - s) * lg, c = (1 - s) * lb;
  final m = <double>[
    a + s, b, c, 0, 0, //
    a, b + s, c, 0, 0,
    a, b, c + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
  for (var i = 0; i < 15; i++) {
    if (i % 5 < 3) m[i] *= bright;
  }
  return ColorFilter.matrix(m);
}

Widget filtered(Widget child, {double gray = 0, double bright = 1, double sat = 1}) =>
    gray == 0 && bright == 1 && sat == 1 ? child : ColorFiltered(colorFilter: cssFilter(gray: gray, bright: bright, sat: sat), child: child);

/// 웹 faceTo(): 초상화(512×512)를 칸보다 1.24배 크게, 위쪽에 맞춰 그림
class FaceImg extends StatelessWidget {
  const FaceImg(this.id, {super.key, this.mood = 'idle'});
  final String id, mood;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return ClipRect(
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              left: -w * .12,
              top: -h * .02,
              width: w * 1.24,
              height: h * 1.24,
              child: kdImg('assets/game/portraits/portrait_${id}_$mood.png', fit: BoxFit.fill),
            ),
          ]),
        );
      });
}

/// 웹 numFlash(): 숫자가 오르면 초록·크게, 내리면 빨강·작게 반짝이고, 아래에서 「+N」이 떠올라 사라짐.
/// [big] 이면 작은 변화(10% 미만·50 미만)는 무시 (골드처럼 계속 조금씩 오르는 값)
class NumFlash extends StatefulWidget {
  const NumFlash(this.value, {super.key, required this.style, this.big = false, this.prefix = '', this.format});
  final num value;
  final TextStyle style;
  final bool big;
  final String prefix;
  final String Function(num)? format;

  @override
  State<NumFlash> createState() => _NumFlashState();
}

class _NumFlashState extends State<NumFlash> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  /// 숫자가 올라가는 효과 (U-2 ⑩, 웹 numRoll 0.4초) · 큰 보상 반짝임 (웹 .nfsp 0.9초)
  late final AnimationController _roll = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  num _from = 0;
  final List<(String, bool, AnimationController)> _floats = [];
  bool _up = true;

  String _f(num v) => (widget.format ?? _fmt)(v);
  static String _fmt(num v) => fmt(v);

  @override
  void didUpdateWidget(NumFlash old) {
    super.didUpdateWidget(old);
    final o = old.value, v = widget.value;
    if (v == o || !v.isFinite || !o.isFinite) return;
    final d = v - o;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduce && d > 0 && d >= (o * .02 > 1 ? o * .02 : 1)) {
      _from = _roll.isAnimating ? _shown(old.value) : o;
      _roll.forward(from: 0);
    } else {
      _roll.stop();
      _roll.value = 1;
    }
    if (!reduce && d > 0 && o > 0 && d >= o * .5) _spark.forward(from: 0);
    if (widget.big && d.abs() < (o.abs() * .1 > 50 ? o.abs() * .1 : 50)) return;
    if (!widget.big && d.abs() < 1) return;
    _up = d > 0;
    _pulse.forward(from: 0);
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    final f = ('${d > 0 ? '+' : '-'}${_f(d.abs())}', d > 0, c);
    setState(() => _floats.add(f));
    c.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _floats.remove(f));
      c.dispose();
    });
  }

  /// 지금 보여 줄 값 (올라가는 중이면 사이 값)
  num _shown(num target) {
    if (!_roll.isAnimating) return target;
    final e = Curves.easeOutCubic.transform(_roll.value);
    return _from + (target - _from) * e;
  }

  @override
  void dispose() {
    _roll.dispose();
    _spark.dispose();
    _pulse.dispose();
    for (final f in _floats) {
      f.$3.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style.color ?? Colors.white;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
      AnimatedBuilder(
        animation: Listenable.merge([_pulse, _roll, _spark]),
        builder: (_, __) {
          // 웹 @keyframes nfu/nfd: 30% 지점에서 가장 크게(작게)·색 바뀜
          final t = _pulse.value, k = !_pulse.isAnimating ? 0.0 : (t < .3 ? t / .3 : (1 - t) / .7);
          final hi = _up ? const Color(0xFF9BFFA8) : const Color(0xFFFF8A7A);
          return Transform.scale(
            scale: 1 + (_up ? .18 : -.08) * k,
            child: Text('${widget.prefix}${_f(_shown(widget.value))}',
                maxLines: 1,
                style: widget.style.copyWith(
                  color: Color.lerp(base, hi, k),
                  shadows: _spark.isAnimating
                      ? [Shadow(color: const Color(0xFFFFE27A).withValues(alpha: math.sin(_spark.value * math.pi)), blurRadius: 14)]
                      : null,
                )),
          );
        },
      ),
      for (final (txt, up, c) in _floats)
        Positioned(
          top: (widget.style.fontSize ?? 14) * 1.2,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) {
                final t = Curves.easeOut.transform(c.value);
                return Transform.translate(
                  offset: Offset(0, -26 * t),
                  child: Opacity(
                    opacity: 1 - t,
                    child: Text(txt,
                        style: TextStyle(
                          fontFamily: 'PlexKR',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: up ? const Color(0xFF9BFFA8) : const Color(0xFFFF8A7A),
                          shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2)],
                        )),
                  ),
                );
              },
            ),
          ),
        ),
    ]);
  }
}
