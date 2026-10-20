import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// 0단계 시험용 Flame 화면: 노을 지역(dusk) 배경 4겹 위를 카엘이 걷는다.
///
/// 배경 배치는 index.html 의 drawBg()/tileLayer() 를 단순화한 것이다.
/// 정확한 이식(지역별 배치·안개·흔들림)은 2단계에서 한다.
class PreviewGame extends FlameGame {
  /// 웹의 bgX 와 같은 역할: 화면이 흘러간 거리(px)
  double bgX = 0;

  void togglePause() => paused = !paused;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF141A29);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/game/';
    final sky = await images.load('bg/dusk_sky.png');
    final far = await images.load('bg/dusk_far.png');
    final mid = await images.load('bg/dusk_mid.png');
    final ground = await images.load('bg/dusk_ground.png');

    // 웹 drawBg 의 BG_FULL 분기와 같은 순서·속도(.04 .12 .3 .9)
    addAll([
      ScrollLayer(sky, bottom: .62, height: .62, speed: .04),
      ScrollLayer(far, bottom: .58, height: .20, speed: .12),
      ScrollLayer(mid, bottom: .72, height: .27, speed: .30),
      ScrollLayer(ground, bottom: 1.0, height: .42, speed: .90),
    ]);

    final walk = await images.load('characters/kael_walk.png');
    final frames = walk.width ~/ walk.height; // 가로 프레임 시트: 프레임 = 폭 ÷ 높이
    final kael = SpriteAnimationComponent(
      animation: SpriteAnimation.fromFrameData(
        walk,
        SpriteAnimationData.sequenced(
          amount: frames,
          stepTime: .1,
          textureSize: Vector2.all(walk.height.toDouble()),
        ),
      ),
      anchor: Anchor.bottomCenter,
    );
    add(_Placed(kael, x: .3, y: .9, h: .42));
  }

  @override
  void update(double dt) {
    super.update(dt);
    bgX += 60 * dt;
  }
}

/// 좌우로 반복되며 흐르는 배경 한 겹 (웹 tileLayer 와 같은 방식).
/// bottom·height 는 화면 높이에 대한 비율.
class ScrollLayer extends Component with HasGameReference<PreviewGame> {
  ScrollLayer(this.image,
      {required this.bottom, required this.height, required this.speed});

  final ui.Image image;
  final double bottom, height, speed;
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  @override
  void render(ui.Canvas canvas) {
    final sw = game.size.x, sh = game.size.y;
    final h = sh * height, w = image.width * h / image.height;
    final src = ui.Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final off = ((game.bgX * speed) % w + w) % w;
    for (var x = -off; x < sw; x += w) {
      canvas.drawImageRect(
          image, src, ui.Rect.fromLTWH(x, sh * bottom - h, w + 1, h), _paint);
    }
  }
}

/// 화면 크기가 바뀌어도 비율 위치를 유지하도록 자식 크기·위치를 맞춰 준다.
class _Placed extends Component with HasGameReference<PreviewGame> {
  _Placed(this.child, {required this.x, required this.y, required this.h});

  final PositionComponent child;
  final double x, y, h;

  @override
  Future<void> onLoad() async => add(child);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    child
      ..size = Vector2.all(size.y * h)
      ..position = Vector2(size.x * x, size.y * y);
  }
}
