/// 그림 효과 — 웹 CSS filter(grayscale·brightness·saturate)와 얼굴 확대(faceTo)
library;

import 'package:flutter/material.dart';

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
