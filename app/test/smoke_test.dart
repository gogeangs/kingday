import 'package:flutter_test/flutter_test.dart';
import 'package:kingday/stage0/preview_game.dart';

void main() {
  test('시험 화면 게임 객체를 만들 수 있다', () {
    final g = PreviewGame();
    expect(g.bgX, 0);
    g.togglePause();
    expect(g.paused, isTrue);
  });
}
