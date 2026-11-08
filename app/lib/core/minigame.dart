/// 미니게임 「선물 배달」 (docs/content/EVENT_SNOW.md 3-9) — 웹 index.html 의 MGC·mgRng·mgNew·mgHouse·mgFill·mgStep 을 그대로 옮긴 것.
///
/// 고정 시간 단위(1/60초)로만 움직여서, 화면이 몇 번 그려지든 같은 판 번호(seed)·같은 누름이면 같은 점수.
/// 웹과 같은 점수인지는 test/minigame_parity_test.dart 가 tools/parity/make_mg_fixtures.js 의 정답과 비교한다.
library;

import 'dart:math' as math;

import 'js.dart';
import 'rng.dart';
import 'web_data.g.dart';

/// 웹 MGC (값은 web_data.g.dart 의 wMgc)
class Mgc {
  static final num W = asNum(wMgc['W']), H = asNum(wMgc['H']), T = asNum(wMgc['T']), dt = asNum(wMgc['dt']);
  static final num sledX = asNum(wMgc['sledX']), sledY = asNum(wMgc['sledY']), dropY = asNum(wMgc['dropY']), ground = asNum(wMgc['ground']);
  static final num hw = asNum(wMgc['hw']), hsc0 = asNum((wMgc['hsc'] as List)[0]), hsc1 = asNum((wMgc['hsc'] as List)[1]);
  static final num gap0 = asNum((wMgc['gap'] as List)[0]), gap1 = asNum((wMgc['gap'] as List)[1]);
  static final num v0 = asNum(wMgc['v0']), vA = asNum(wMgc['vA']), G = asNum(wMgc['G']), cd = asNum(wMgc['cd']);
  static final num hit = asNum(wMgc['hit']), perf = asNum(wMgc['perf']), pt = asNum(wMgc['pt']), gold = asNum(wMgc['gold']), perfP = asNum(wMgc['perfP']);
  static final num step = asNum(wMgc['step']), mulMax = asNum(wMgc['mulMax']), goldP = asNum(wMgc['goldP']), smokeP = asNum(wMgc['smokeP']);
  static final Map<String, List<num>> C = {for (final e in (wMgc['C'] as Map).entries) e.key as String: (e.value as List).cast<num>()};
  static final int maxScore = asNum(wMgc['maxScore']).toInt();
}

/// 연속 배수 (5번마다 +1배, 최대 5배) (웹 mgMul)
int mgMul(int c) => math.min(Mgc.mulMax.toInt(), 1 + ((c - 1) / Mgc.step).floor());

/// 집이 지나가는 빠르기 (웹 mgV)
num mgV(num t) => Mgc.v0 + Mgc.vA * math.min(t, Mgc.T);

class MgHouse {
  MgHouse(this.ty, this.wx, this.w, this.h, this.cx, this.cy);
  final String ty;
  final num wx, w, h, cx, cy;
  bool done = false;
}

class MgGift {
  MgGift(this.x, this.y, this.k);
  final num x;
  num y, vy = 0, r = 0;
  final int k;
  bool dead = false;
}

/// 화면 효과 (쏙·퍽·콜록)
class MgFx {
  MgFx(this.k, this.x, this.y, this.t, this.gx, {this.p = 0, this.pf = false, this.m = 1, this.gold = false});
  final String k;
  final num x, y, t, gx;
  final num p;
  final bool pf, gold;
  final int m;
}

/// 한 판 (웹 mgNew 의 g)
class MgGame {
  MgGame(int seed)
      : seed = seed & 0xFFFFFFFF,
        _rnd = Mulberry32(seed & 0xFFFFFFFF) {
    _fill();
  }
  final int seed;
  final Mulberry32 _rnd;
  int n = 0;
  num t = 0, x = 0, cdT = 0, nx = 330;
  List<MgHouse> hs = [];
  List<MgGift> gifts = [];
  int score = 0, combo = 0, maxC = 0, hits = 0, perfN = 0, drops = 0, miss = 0;
  bool tapQ = false, over = false;
  String last = '';
  final List<MgFx> ev = [];

  void _house() {
    final a = _rnd.next(), b = _rnd.next(), c = _rnd.next(), d = _rnd.next(), e = _rnd.next();
    var ty = a < Mgc.goldP ? 'gold' : b < Mgc.smokeP ? 'smoke' : 'h${1 + (c * 3).floor()}';
    if (ty == 'smoke' && last == 'smoke') ty = 'h${1 + (c * 3).floor()}'; // 연기 굴뚝은 두 번 연달아 안 나옴
    final w = Mgc.hw * (Mgc.hsc0 + d * (Mgc.hsc1 - Mgc.hsc0)), h = (w * 429) / 320, cc = Mgc.C[ty]!;
    hs.add(MgHouse(ty, nx, w, h, nx - w / 2 + (w * cc[0]) / 320, Mgc.ground - h + (h * cc[1]) / 429));
    last = ty;
    nx += Mgc.gap0 + e * (Mgc.gap1 - Mgc.gap0);
  }

  void _fill() {
    while (nx - x < Mgc.W + 220) {
      _house();
    }
    if (hs.isNotEmpty && hs.first.wx - x < -160) hs = hs.where((h) => h.wx - x >= -160).toList();
  }

  /// 누르기 (다음 단위 처음에 반영, 웹 mgTap)
  void tap() => tapQ = true;

  /// 한 단위 진행 (웹 mgStep)
  void step() {
    if (over) return;
    final dt = Mgc.dt;
    if (tapQ) {
      tapQ = false;
      if (t < Mgc.T && cdT <= 0) {
        gifts.add(MgGift(Mgc.sledX + 4, Mgc.dropY, drops % 3));
        drops++;
        cdT = Mgc.cd;
      }
    }
    n++;
    t = n * dt;
    cdT = math.max(0, cdT - dt);
    final dx = mgV(t) * dt;
    x += dx;
    _fill();
    for (final q in gifts) {
      final y0 = q.y;
      q.vy += Mgc.G * dt;
      q.y += q.vy * dt;
      q.r += dt * 4;
      for (final h in hs) {
        if (h.done || !(y0 < h.cy && q.y >= h.cy)) continue;
        final f = (h.cy - y0) / (q.y - y0), sx = h.cx - x + dx * (1 - f), d = (q.x - sx).abs();
        if (d > Mgc.hit) continue;
        q.dead = true;
        h.done = true;
        if (h.ty == 'smoke') {
          combo = 0;
          ev.add(MgFx('smoke', sx, h.cy, t, x));
        } else {
          combo++;
          maxC = math.max(maxC, combo);
          hits++;
          final m = mgMul(combo), pf = d <= Mgc.perf, p = (h.ty == 'gold' ? Mgc.gold : Mgc.pt) * m + (pf ? Mgc.perfP : 0);
          if (pf) perfN++;
          score += p.toInt();
          ev.add(MgFx('in', sx, h.cy, t, x, p: p, pf: pf, m: m, gold: h.ty == 'gold'));
        }
        break;
      }
      if (q.dead) continue;
      // 지붕이나 땅에 떨어지면 점수 없음 · 연속 끊김
      final roof = hs.any((h) => (q.x - (h.wx - x)).abs() < h.w * .42 && q.y >= Mgc.ground - h.h * .62);
      if (roof || q.y >= Mgc.ground - 6) {
        q.dead = true;
        combo = 0;
        miss++;
        ev.add(MgFx('miss', q.x, q.y, t, x));
      }
    }
    gifts = gifts.where((q) => !q.dead).toList();
    if (ev.length > 40) ev.removeRange(0, ev.length - 40);
    if (t >= Mgc.T && (gifts.isEmpty || t >= Mgc.T + 1.5)) over = true;
  }

  /// 이 판으로 받는 이벤트 재화 (점수 ÷ 10, 최대 100, 웹 mgEnd)
  int get reward => math.min(100, (score / 10).floor());
}
