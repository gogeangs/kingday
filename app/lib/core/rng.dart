import 'dart:math' as math;

/// 게임에서 쓰는 난수. 웹의 Math.random() 자리.
///
/// 실제 게임은 [SystemRandom], 테스트는 [Mulberry32] 를 써서
/// 웹(Node)과 같은 난수 순서로 결과를 비교한다.
abstract class KdRandom {
  /// 0 이상 1 미만의 수
  double next();
}

class SystemRandom implements KdRandom {
  SystemRandom([math.Random? r]) : _r = r ?? math.Random();
  final math.Random _r;
  @override
  double next() => _r.nextDouble();
}

/// tools/parity/load_web.js 의 mulberry32 와 비트 단위로 같은 생성기.
class Mulberry32 implements KdRandom {
  Mulberry32(int seed) : _a = seed & _m;
  static const _m = 0xFFFFFFFF;
  int _a;

  /// JS Math.imul 의 아래 32비트 (부호 없는 값으로)
  static int _imul(int a, int b) {
    final al = a & 0xFFFF, ah = (a >> 16) & 0xFFFF;
    final bl = b & 0xFFFF, bh = (b >> 16) & 0xFFFF;
    return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & _m;
  }

  @override
  double next() {
    _a = (_a + 0x6D2B79F5) & _m;
    var t = _a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _m)) & _m;
    return ((t ^ (t >> 14)) & _m) / 4294967296;
  }
}
