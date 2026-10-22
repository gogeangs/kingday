/// 전투 화면 (Flame) — 웹 draw()/drawBg()/drawMember()/drawMon()/drawFxs()/drawProj() 등을 옮긴 것.
///
/// 계산은 [BattleSim] 이 하고, 여기서는 그 상태를 그리기만 한다.
/// 웹에는 그림이 안 들어온 동안 쓰던 "코드 그림"이 있지만, 앱은 그림이 모두 들어 있으므로 그림만 쓴다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/data.dart';
import 'battle_data.dart';
import 'sim.dart';

/// 화면 위·아래를 가리는 UI(상단 표시줄, 원정대 줄)의 높이. 말풍선·컷인이 그 아래·위로 피한다.
class BattleInsets {
  const BattleInsets({this.top = 84, this.bottom = 118});
  final double top, bottom;
}

class BattleGame extends FlameGame {
  BattleGame(this.sim, {this.insets = const BattleInsets()});

  final BattleSim sim;
  final BattleInsets insets;

  /// 2배속 (웹 S.speed===2)
  int get speed => sim.s.raw['speed'] == 2 ? 2 : 1;

  /// 매 프레임 끝에 부름 (화면 위 Flutter 위젯 새로 그리기용)
  void Function(double dt)? onTick;

  final Map<String, ui.Image> _img = {};
  ui.Image? img(String path) => _img[path];

  /// 배경 레이어 정보: 가로 전체가 불투명해지는 높이 비율(웹 opaqueTop), 바닥 기본색(웹 baseColor)
  final Map<String, double> _opaqueTop = {};
  final Map<String, ui.Color> _baseColor = {};

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF141A29);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/game/';
    final paths = <String>{
      for (final id in charSheets.keys) for (final a in ['idle', 'walk', 'attack', 'hit']) 'characters/${id}_$a.png',
      for (final k in fxFrames.keys) 'fx/fx_$k.png',
      'ui/banner_capture.png', 'ui/boss_mark_lord.png', 'ui/boss_mark_commander.png',
      'ui/boss_aura_lord.png', 'ui/boss_aura_commander.png',
      for (final id in skills.keys) 'portraits/portrait_${id}_${skills[id]!.face}.png',
    };
    await Future.wait(paths.map((p) async {
      try {
        _img[p] = await images.load(p);
      } catch (_) {/* 없는 그림은 건너뜀 */}
    }));
    // 효과 그림이 실제로 있는 것만 전투에서 씀 (웹 fxOk)
    sim.fxLoaded
      ..clear()
      ..addAll(fxFrames.keys.where((k) => _img.containsKey('fx/fx_$k.png')));
    await _ensureRegion(GameCalc.regionIndex(sim.s.stage));
  }

  final Set<int> _loadingRegions = {};

  /// 지금 지역과 다음 지역의 배경·마물 그림을 미리 받는다 (웹 loadBgs/loadMonReg)
  Future<void> _ensureRegion(int ri) async {
    for (final r in [ri, ri + 1]) {
      if (r >= regions.length || !_loadingRegions.add(r)) continue;
      final paths = <String>[];
      final bg = bgImage[r];
      if (bg != null) {
        for (final l in ['sky', 'far', 'mid', 'ground']) {
          paths.add('bg/${bg}_$l.png');
        }
      }
      // 왕도(5): 전용 그림이 오기 전에는 물들일 원본(군단장 5명·골렘·박쥐)도 받음
      final capSrc = r == regions.length - 1 ? [for (var j = 0; j < 5; j++) ...[monSheets[j], monSheets[j]?.boss], ...balthasarSheets] : const <MonSheet?>[];
      for (final m in [monSheets[r], monSheets[r]?.boss, monAlt[r], ...capSrc]) {
        if (m == null) continue;
        for (final a in ['walk', 'attack', 'hit']) {
          paths.add('monsters/${m.id}_$a.png');
        }
      }
      if (r == 0) {
        for (final a in ['walk', 'attack', 'hit']) {
          paths.add('monsters/${goblinSheet.id}_$a.png');
        }
      }
      // 아직 안 들어온 그림(왕도 배경·몬스터 등)은 부르지 않음 — 앱에 들어 있는 그림 목록으로 확인
      final have = await _assetList();
      await Future.wait(paths.where((p) => have == null || have.contains('assets/game/$p')).map((p) async {
        try {
          final im = await images.load(p);
          _img[p] = im;
          if (p.startsWith('bg/')) await _measureBg(p, im);
        } catch (_) {}
      }));
    }
    // 고블린은 어느 지역에서든 나오므로 늘 받아 둔다
    if (!_img.containsKey('monsters/${goblinSheet.id}_walk.png')) {
      for (final a in ['walk', 'attack', 'hit']) {
        try {
          _img['monsters/${goblinSheet.id}_$a.png'] = await images.load('monsters/${goblinSheet.id}_$a.png');
        } catch (_) {}
      }
    }
  }

  Set<String>? _assets;
  Future<Set<String>?> _assetList() async {
    if (_assets != null) return _assets;
    try {
      final m = await AssetManifest.loadFromAssetBundle(rootBundle);
      return _assets = m.listAssets().toSet();
    } catch (_) {
      return null;
    }
  }

  Future<void> _measureBg(String p, ui.Image im) async {
    // opaqueTop: 64px 폭으로 줄여서 알파가 꽉 찬 첫 줄을 찾는다
    const w = 64;
    final h = math.max(16, (64 * im.height / im.width).round());
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(im, ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.medium);
    final small = await rec.endRecording().toImage(w, h);
    final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    var top = .5;
    if (data != null) {
      for (var y = 0; y < h; y++) {
        var n = 0;
        for (var i = 0; i < w; i++) {
          if (data.getUint8((y * w + i) * 4 + 3) > 230) n++;
        }
        if (n >= w - 1) {
          top = y / h;
          break;
        }
      }
    }
    _opaqueTop[p] = top;
    if (p.endsWith('_ground.png')) {
      final rec2 = ui.PictureRecorder();
      ui.Canvas(rec2).drawImageRect(im, ui.Rect.fromLTWH(0, im.height * .75, im.width.toDouble(), im.height * .25),
          const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint()..filterQuality = ui.FilterQuality.medium);
      final px = await rec2.endRecording().toImage(1, 1);
      final d = await px.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (d != null) _baseColor[p] = ui.Color.fromARGB(255, d.getUint8(0), d.getUint8(1), d.getUint8(2));
    }
  }

  int _lastRegion = -1;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    sim
      ..w = size.x
      ..ht = size.y;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final d = math.min(.1, dt) * speed;
    sim.step(d);
    final ri = GameCalc.regionIndex(sim.s.stage);
    if (ri != _lastRegion) {
      _lastRegion = ri;
      _ensureRegion(ri);
    }
    onTick?.call(math.min(.1, dt));
  }

  // ════════════════════════ 그리기 ════════════════════════
  late ui.Canvas _c;
  double get _w => size.x;
  double get _ht => size.y;
  double get _t => sim.time.toDouble();

  final _paint = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..isAntiAlias = true;

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (_w == 0) return;
    _c = canvas;
    canvas.save();
    canvas.translate(sim.shakeX.toDouble(), sim.shakeY.toDouble());
    final r = GameCalc.region(sim.s.stage), ri = GameCalc.regionIndex(sim.s.stage), l = sim.layout();
    _drawBg(ri, r, l);
    final ents = <(double, void Function())>[
      for (final id in l.ids)
        (l.py[id]!.toDouble(), () => _drawMember(id, l.pos[id]!.toDouble(), l.py[id]!.toDouble(), (l.s * l.dsc[id]!).toDouble(), sim.party[id], !sim.engaged)),
      for (final m in sim.mons)
        () {
          final y = sim.depthAt(l, m.lane).toDouble();
          return (y, () => _drawMon(ri, y, (l.s * (.9 + .14 * m.lane)).toDouble(), m));
        }(),
    ];
    // 웹 Array.sort 는 안정 정렬 → 같은 깊이면 원래 순서
    final idx = List.generate(ents.length, (i) => i)..sort((a, b) => ents[a].$1 != ents[b].$1 ? ents[a].$1.compareTo(ents[b].$1) : a - b);
    for (final i in idx) {
      ents[i].$2();
    }
    for (final p in sim.proj) {
      _drawProj(p, l.s.toDouble());
    }
    _drawFxs();
    for (final f in sim.floats) {
      _text(f.txt, f.x.toDouble(), f.y.toDouble(), (f.size * math.max(.9, l.s)).toDouble(), ui.Color(f.col),
          alpha0: 1 - f.t / .9, serif: true, stroke: const ui.Color(0xA6000000), strokeW: 3.5);
    }
    _drawSkillFx(l);
    _drawQuip(l);
    canvas.restore();
    _drawWarn(l);
    _drawBanner(l);
    _drawDemon(l);
  }

  /// 봉인의 파동 예고 원 · 마왕 대사 띠 (웹 drawDemon)
  void _drawDemon(BattleLayout l) {
    final sw = sim.seal;
    if (sw != null && l.ids.isNotEmpty) {
      final k = _cl(1 - math.max(0, sw.t) / BattleSim.sealWarn);
      final back = l.ids.map((i) => l.pos[i]!).reduce(math.min).toDouble();
      final cx = (back + l.front) / 2, cy = (l.top + l.bot) / 2 + 10 * l.s;
      final rx = math.max(80.0, (l.front - back) * .75 + 50 * l.s).toDouble(), ry = rx * .32;
      final r = ui.Rect.fromCenter(center: ui.Offset(cx.toDouble(), cy.toDouble()), width: rx * 2, height: ry * 2);
      _c.drawOval(r, ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ui.Color.fromRGBO(255, 211, 74, .25 + .55 * k));
      _c.drawOval(ui.Rect.fromCenter(center: r.center, width: rx * 2 * k, height: ry * 2 * k), ui.Paint()..color = ui.Color.fromRGBO(255, 211, 74, .08 + .22 * k));
      _text('봉인의 파동!', cx, cy - ry - 8, 13, const ui.Color(0xFFFFE08A), stroke: const ui.Color(0xB3000000), strokeW: 3);
    }
    final tk = sim.talk;
    if (tk != null) {
      final (w, t) = tk.lines[tk.i];
      final q = w == 'q', a = _cl(math.min((2.6 - tk.t) * 5, tk.t * 4)), cy = _ht * .24;
      final g = ui.Gradient.linear(ui.Offset.zero, ui.Offset(_w, 0),
          [const ui.Color(0x000A0614), const ui.Color(0xE00A0614), const ui.Color(0xE00A0614), const ui.Color(0x000A0614)], [0, .12, .88, 1]);
      _c.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, a));
      _c.drawRect(ui.Rect.fromLTWH(0, cy - 28, _w, 56), ui.Paint()..shader = g);
      _c.drawRect(ui.Rect.fromLTWH(_w * .1, cy - 28, _w * .8, 2), ui.Paint()..color = q ? const ui.Color(0xFF5AB4FF) : const ui.Color(0xFFB98CFF));
      _text(q ? '성검 루미나르' : w, _w / 2, cy - 11, 11, q ? const ui.Color(0xFF8FD0FF) : const ui.Color(0xFFCFA8FF));
      _text(t, _w / 2, cy + 10, math.min(14, _w / 26), const ui.Color(0xFFF4EEFE), serif: true, maxW: _w - 24, weight: FontWeight.w600);
      _c.restore();
    }
  }

  // ── 기본 도형 ──
  /// 0~1 로 자르기
  static double _cl(num v) => v < 0 ? 0 : v > 1 ? 1 : v.toDouble();

  void _ell(num x, num y, num rx, num ry, ui.Color c) {
    _c.drawOval(
        ui.Rect.fromCenter(
            center: ui.Offset(x.toDouble(), y.toDouble()),
            width: math.max(.1, rx.toDouble()) * 2,
            height: math.max(.1, ry.toDouble()) * 2),
        ui.Paint()..color = c);
  }

  void _rr(num x, num y, num w, num h, num r, ui.Color c) {
    _c.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()), ui.Radius.circular(r.toDouble())),
        ui.Paint()..color = c);
  }

  void _bar(num x0, num y0, num w0, num p, ui.Color c) {
    final x = x0.toDouble(), y = y0.toDouble(), w = w0.toDouble();
    _c.drawRect(ui.Rect.fromLTWH(x - w / 2 - 1, y - 1, w + 2, 5), ui.Paint()..color = const ui.Color(0x73000000));
    _c.drawRect(ui.Rect.fromLTWH(x - w / 2, y, w * _cl(p), 3), ui.Paint()..color = c);
  }

  /// 글자 (웹 fillText + strokeText). align: 0 가운데, -1 왼쪽
  void _text(String s, num x0, num y0, num size0, ui.Color color,
      {num alpha0 = 1, bool serif = false, ui.Color? stroke, num strokeW = 0, int align = 0, num? maxW, FontWeight weight = FontWeight.w700}) {
    final x = x0.toDouble(), y = y0.toDouble(), size = size0.toDouble(), alpha = _cl(alpha0);
    if (alpha <= 0) return;
    final family = serif ? 'Hahmlet' : 'PlexKR';
    TextPainter tp(ui.Paint? fg, ui.Color? col) => TextPainter(
          text: TextSpan(
              text: s,
              style: TextStyle(
                  fontSize: size, fontWeight: weight, fontFamily: family, foreground: fg, color: fg == null ? col : null, height: 1)),
          textDirection: TextDirection.ltr,
        )..layout();
    final main = tp(null, color.withValues(alpha: color.a * alpha));
    var sx = 1.0;
    if (maxW != null && main.width > maxW) sx = maxW / main.width;
    final w = main.width * sx;
    final dx = align == 0 ? x - w / 2 : x;
    // 웹 기준선(alphabetic) ≈ 글자 아래쪽 → 높이의 80% 위로
    final dy = y - main.height * .8;
    _c.save();
    _c.translate(dx, dy);
    if (sx != 1) _c.scale(sx, 1);
    if (stroke != null && strokeW > 0) {
      tp(
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = strokeW.toDouble()
          ..strokeJoin = ui.StrokeJoin.round
          ..color = stroke.withValues(alpha: stroke.a * alpha),
        null,
      ).paint(_c, ui.Offset.zero);
    }
    main.paint(_c, ui.Offset.zero);
    _c.restore();
  }

  // ── 배경 (웹 drawBg) ──
  void _tileLayer(ui.Image im, num bottom0, num h0, num speed) {
    final bottom = bottom0.toDouble(), h = h0.toDouble();
    final w = im.width * h / im.height;
    final off = (((sim.bgX * speed) % w + w) % w).toDouble();
    final src = ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
    for (var x = -off; x < _w; x += w) {
      _c.drawImageRect(im, src, ui.Rect.fromLTWH(x, bottom - h, w + 1, h), _paint);
    }
  }

  void _drawBg(int ri, RegionDef r, BattleLayout l) {
    final bn = bgImage[ri];
    ui.Image? L(String layer) => bn == null ? null : _img['bg/${bn}_$layer.png'];
    final sky = L('sky'), far = L('far'), mid = L('mid'), ground = L('ground');
    final ht = _ht, w = _w;
    if (sky == null || far == null || mid == null || ground == null) {
      // 그림을 받는 중: 지역 하늘색으로
      final g = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, ht), [ui.Color(hexColor(r.sky[0])), ui.Color(hexColor(r.ground))]);
      _c.drawRect(ui.Rect.fromLTWH(0, 0, w, ht), ui.Paint()..shader = g);
      return;
    }
    final hz = (l.top - ht * .05).toDouble();
    final opG = _opaqueTop['bg/${bn}_ground.png'] ?? .5, opM = _opaqueTop['bg/${bn}_mid.png'] ?? .5;
    if (bgFull.contains(bn)) {
      _tileLayer(sky, hz + ht * .1, math.max(hz + ht * .1, w * sky.height / sky.width * 1.3), .04);
      final gH = ht - hz + ht * .06, gOp = ht - gH + gH * opG, mH = ht * .27, mB = math.max(hz + ht * .15, gOp + 6);
      final mOp = mB - mH + mH * opM, fH = ht * .2, fB = math.max(hz + ht * .05, mOp + 6);
      _tileLayer(far, fB, fH, .12);
      _tileLayer(mid, mB, mH, .3);
      _tileLayer(ground, ht, gH, .9);
      _vignette(.72, .35);
      return;
    }
    // 에르단 평원: 하늘·먼 산만 그림, 땅은 바닥색 + 풀·돌
    _tileLayer(sky, hz + ht * .08, math.max(hz + ht * .08, w * sky.height / sky.width * 1.6), .04);
    _tileLayer(far, hz + ht * .035, ht * .15, .12);
    final c = _baseColor['bg/${bn}_ground.png'] ?? const ui.Color(0xFF966E3C);
    final bandB = hz + ht * .24;
    int ch(double v, double k) => math.max(0, math.min(255, (v * 255 * k).round()));
    ui.Color mul(ui.Color x, double k) => ui.Color.fromARGB(255, ch(x.r, k), ch(x.g, k), ch(x.b, k));
    final fg = ui.Gradient.linear(ui.Offset(0, bandB), ui.Offset(0, ht), [c, mul(c, .55)]);
    _c.drawRect(ui.Rect.fromLTWH(0, hz + ht * .1, w, ht), ui.Paint()..shader = fg);
    double rnd(int i) {
      final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
      return x - x.floorToDouble();
    }

    for (var i = 0; i < 40; i++) {
      final d = rnd(i * 3 + 1), y = bandB - ht * .02 + (ht - bandB) * d, sp = .5 + d * .8, span = w + 60;
      final x = (((rnd(i * 3 + 2) * span - sim.bgX * sp) % span + span) % span - 30).toDouble(), z = .8 + d * 1.2, t = rnd(i * 3 + 5);
      if (t < .45) {
        final p = ui.Paint()
          ..color = mul(c, 1.25).withValues(alpha: .9)
          ..strokeWidth = 1.6 * z
          ..style = ui.PaintingStyle.stroke;
        final path = ui.Path();
        for (var k = -1; k <= 1; k++) {
          path
            ..moveTo(x + k * 3 * z, y)
            ..lineTo(x + k * 6 * z, y - 9 * z);
        }
        _c.drawPath(path, p);
      } else if (t < .8) {
        _ell(x, y, 7 * z, 3.5 * z, mul(c, .6).withValues(alpha: .8));
        _ell(x - 1 * z, y - 1.5 * z, 5.5 * z, 2.6 * z, mul(c, 1.15).withValues(alpha: .9));
      } else {
        _ell(x, y, 9 * z, 2.5 * z, mul(c, .7).withValues(alpha: .6));
      }
    }
    _tileLayer(mid, hz + ht * .085, ht * .16, .3);
    _tileLayer(ground, bandB, ht * .24, .9);
    final fd = ui.Gradient.linear(ui.Offset(0, bandB - ht * .07), ui.Offset(0, bandB + 2), [c.withValues(alpha: 0), c]);
    _c.drawRect(ui.Rect.fromLTWH(0, bandB - ht * .07, w, ht * .07 + 2), ui.Paint()..shader = fd);
    _vignette(.72, .4);
  }

  void _vignette(double from, double a) {
    final g = ui.Gradient.linear(ui.Offset(0, _ht * from), ui.Offset(0, _ht), [const ui.Color(0x00000000), ui.Color.fromRGBO(0, 0, 0, a)]);
    _c.drawRect(ui.Rect.fromLTWH(0, _ht * from, _w, _ht * (1 - from)), ui.Paint()..shader = g);
  }

  // ── 원정대 (웹 drawMember/spriteFrame/drawSprite) ──
  (String, int) _spriteFrame(String id, Member? p, bool walk) {
    final d = charSheets[id]!;
    if (p == null) return ('idle', 0);
    if (p.down) return ('hit', d.hit - 1);
    if (p.hit > 0) return ('hit', 0);
    if (p.swing > 0) return ('attack', math.max(0, math.min(d.attack - 1, ((1 - p.swing / .22) * d.attack).floor())));
    if (walk) return ('walk', (_t * 10).floor() % d.walk);
    return ('idle', (_t * 5).floor() % d.idle);
  }

  void _drawSprite(String id, double x, double y, double s, String anim, int idx, {double alpha = 1}) {
    final im = _img['characters/${id}_$anim.png'];
    if (im == null) return;
    final k = (66 * s / sprFig).toDouble(), n = charSheets[id]!.frames(anim), cw = im.width / n;
    final src = ui.Rect.fromLTWH(idx * cw, 0, cw, sprFrame.toDouble());
    final dst = ui.Rect.fromLTWH(x - cw / 2 * k, y - sprFoot * k, cw * k, sprFrame * k);
    _c.drawImageRect(im, src, dst, ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..color = ui.Color.fromRGBO(0, 0, 0, _cl(alpha)));
  }

  void _drawMember(String id, double x, double y, double s, Member? p, bool walk) {
    if (p == null) return;
    _ell(x, y, 16 * s, 4.5 * s, const ui.Color(0x47000000));
    final (a, i) = _spriteFrame(id, p, walk && !p.down);
    _drawSprite(id, x, y, s, a, i, alpha: p.down ? .35 : 1.0);
    final mx = sim.c.stats(id).hp;
    _bar(x, y - (heightOf(id) - 2) * s, 26 * s, p.hp / mx, p.down ? const ui.Color(0xFF666666) : const ui.Color(0xFF7BE08F));
    // 버치 「벌통 방패」 표시
    if (p.bsh > 0 && !p.down && sim.fxOk('skill_birch')) {
      _fxFrame('skill_birch', 3, x + 18 * s, y - 20 * s, 40 * s, alpha: math.min(1, p.bsh) * .85);
    }
  }

  // ── 마물 (웹 drawMon) ──
  bool _has(MonSheet? d) => d != null && _img['monsters/${d.id}_walk.png'] != null;

  /// 그릴 시트 + 물들이기 (웹 monSprite/tintSet). 왕도 그림이 오기 전엔 기존 그림을 색만 바꿔 씀
  ({MonSheet sheet, ui.ColorFilter? tint, double alpha, double scale, bool lordArt})? _monArt(int ri, Mon m) {
    if (m.gob) return (sheet: goblinSheet, tint: null, alpha: 1.0, scale: 1.0, lordArt: false);
    if (m.dem) {
      final own = balthasarSheets[m.ph2 ? 1 : 0];
      if (_has(own)) return (sheet: own, tint: null, alpha: 1.0, scale: 1.3, lordArt: true);
      final src = monSheets[3]?.boss; // 알도르
      if (!_has(src)) return null;
      return (
        sheet: src!,
        tint: m.ph2 ? const ui.ColorFilter.mode(ui.Color(0xFFC8B6FF), ui.BlendMode.color) : const ui.ColorFilter.mode(ui.Color(0xFF3A2F4C), ui.BlendMode.multiply),
        alpha: 1.0, scale: 1.3, lordArt: true,
      );
    }
    if (m.ghost != null) {
      final src = monSheets[m.ghost!]?.boss;
      if (!_has(src)) return null;
      return (sheet: src!, tint: const ui.ColorFilter.mode(ui.Color(0xFFA88CFF), ui.BlendMode.color), alpha: .72, scale: 1.0, lordArt: true);
    }
    final d = monSheets[ri];
    if (d == null) return null;
    MonSheet? pick = m.alt ? monAlt[ri] : (m.lord || m.guard) && d.boss != null ? d.boss : d;
    if (pick == null) return null;
    if (_has(pick)) return (sheet: pick, tint: null, alpha: 1.0, scale: 1.0, lordArt: m.lord && pick == d.boss);
    final t = capTint[pick.id];
    if (t == null || !_has(t.src)) return null;
    return (sheet: t.src, tint: ui.ColorFilter.mode(t.color, t.mode), alpha: 1.0, scale: 1.0, lordArt: false);
  }

  void _drawAura(double x, double y, double ss, bool cmd) {
    final pulse = .75 + .25 * math.sin(_t * 3), w = (cmd ? 46 : 38) * ss;
    final im = _img[cmd ? 'ui/boss_aura_commander.png' : 'ui/boss_aura_lord.png'];
    if (im == null) return;
    final iw = w * 2.3, ih = iw * .36;
    final dst = ui.Rect.fromLTWH(x - iw / 2, y - ih / 2, iw, ih), src = ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
    _c.drawImageRect(im, src, dst, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, .55 + .4 * pulse));
    _c.drawImageRect(im, src, dst, ui.Paint()
      ..blendMode = ui.BlendMode.plus
      ..color = ui.Color.fromRGBO(0, 0, 0, (.55 + .4 * pulse) * .35 * pulse));
  }

  void _drawMon(int ri, double y, double s, Mon m) {
    // 토비 「파도 가르기」로 밀쳐지면 잠깐 뒤로 밀렸다 돌아옴 (그림만, 웹 drawMon 의 m.kb)
    final kbx = m.kb > 0 ? math.sin(m.kb / .5 * math.pi) * 36 * s : 0.0;
    final k0 = m.boss ? (m.lord ? 1.8 : 1.5) : m.gob ? 1.3 : 1.0, x = m.x.toDouble() + kbx, ss = s * k0;
    final art = _monArt(ri, m);
    final fade = (m.dead > 0 ? (m.dead / .35).clamp(0, 1).toDouble() : 1.0) * (art?.alpha ?? 1.0);
    if (m.boss) _drawAura(x, y, ss, m.lord || m.ghost != null);
    _ell(x, y, 18 * ss, 5 * ss, ui.Color.fromRGBO(0, 0, 0, .25 * fade));
    final ph = x * .05;
    final md = art?.sheet;
    double top = y - 40 * ss, bot = y;
    if (md != null) {
      final sk = art!.lordArt ? ss * .8 * art.scale : ss;
      final ly = (md.lift != null ? y - md.lift! * sk * (1 + .08 * math.sin(_t * 5 + ph)) : y).toDouble();
      final kk = (md.h * sk / md.fig).toDouble(), moving = m.tx != null && m.x > m.tx! + 1;
      var a = 'walk';
      var i = (_t * 8 + ph).floor() % md.walk;
      if (m.hit > 0 || m.dead > 0) {
        a = 'hit';
        i = m.dead > 0 ? 1 : 0;
      } else if (m.sw > 0) {
        a = 'attack';
        i = math.max(0, math.min(md.attack - 1, ((1 - m.sw / .4) * md.attack).floor()));
      } else if (!moving) {
        i = (_t * 4 + ph).floor() % md.walk;
      }
      final im = _img['monsters/${md.id}_$a.png'];
      if (im != null) {
        final fr = sprFrame.toDouble(), src = ui.Rect.fromLTWH(i * fr, 0, fr, fr);
        final dst = ui.Rect.fromLTWH(x - fr / 2 * kk, ly - sprFoot * kk, fr * kk, fr * kk);
        _c.save();
        if (m.flee) {
          _c.translate(x, 0);
          _c.scale(-1, 1);
          _c.translate(-x, 0);
        }
        if ((m.boss || m.gob) && m.dead == 0) {
          final glow = m.gob || m.ph2 ? const ui.Color(0xF2FFD23C) : m.lord || m.ghost != null ? const ui.Color(0xE6B46EFF) : const ui.Color(0xD9FF3C50);
          final blur = (14 + 6 * math.sin(_t * 4)) * s;
          _c.drawImageRect(im, src, dst, ui.Paint()
            ..colorFilter = ui.ColorFilter.mode(glow, ui.BlendMode.srcIn)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2));
        }
        final pt = ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..color = ui.Color.fromRGBO(0, 0, 0, _cl(fade));
        if (art.tint != null) pt.colorFilter = art.tint;
        _c.drawImageRect(im, src, dst, pt);
        if (m.hit > 0) {
          _c.drawImageRect(im, src, dst, ui.Paint()
            ..blendMode = ui.BlendMode.plus
            ..color = ui.Color.fromRGBO(0, 0, 0, _cl(fade * .35)));
        }
        _c.restore();
      }
      top = (ly - md.fig * kk).toDouble();
      bot = ly;
    }
    // 베릴 「약점 감정」: 과녁 표시 · 카라 「불맛 한 숟갈」: 발밑 불길
    if (m.vul > 0 && m.dead == 0 && sim.fxOk('skill_beryl')) {
      _fxFrame('skill_beryl', 0, x, (top + bot) / 2, (m.boss ? 70 : 48) * s, alpha: _cl(m.vul) * .85);
    }
    if (m.brn > 0 && m.dead == 0 && sim.fxOk('skill_kara')) {
      _fxFrame('skill_kara', 2 + (_t * 6).floor() % 2, x, y - 10 * s, (m.boss ? 60 : 40) * s, alpha: _cl(m.brn) * .7);
    }
    if (m.bind > 0 && m.dead == 0) {
      final nr = (m.boss ? 34 : 24) * s, ny = (top + bot) / 2, a = _cl(m.bind) * .92;
      if (m.bindK != 'net') {
        // 기절(막례·고든·말봉): 머리 위 빙글빙글 별
        for (var k = 0; k < 3; k++) {
          final an = _t * 4 + k * 2.094;
          _text('★', x + math.cos(an) * nr * .7, top - 6 * s + math.sin(an) * nr * .22, (m.boss ? 16 : 12) * s,
              ui.Color.fromRGBO(255, 226, 122, a), stroke: ui.Color.fromRGBO(58, 38, 0, a), strokeW: 3 * s, weight: FontWeight.w900);
        }
      } else if (sim.fxOk('net')) {
        // 넬라 그물: 손그림 그물(fx_net 2번째 칸)을 덮어씌움
        _fxFrame('net', 1, x, ny + (bot - top) * .08, math.max(nr * 2.6, (bot - top) * 1.25) / 1.5, alpha: a);
      } else {
        final p = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4 * s
          ..color = ui.Color.fromRGBO(217, 230, 238, a);
        _c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, ny), width: nr * 2, height: nr * 2.3), p);
        final path = ui.Path();
        for (var i = -2; i <= 2; i++) {
          path
            ..moveTo(x + i * nr * .4, ny - nr * 1.1)
            ..lineTo(x + i * nr * .4, ny + nr * 1.1)
            ..moveTo(x - nr, ny + i * nr * .45)
            ..lineTo(x + nr, ny + i * nr * .45);
        }
        _c.drawPath(path, p);
      }
    }
    if (m.boss) {
      final mk = _img[m.lord ? 'ui/boss_mark_commander.png' : 'ui/boss_mark_lord.png'];
      if (mk != null) {
        final z = (m.lord ? 44 : 36) * s, bob = math.sin(_t * 3) * 3 * s;
        _c.drawImageRect(mk, ui.Rect.fromLTWH(0, 0, mk.width.toDouble(), mk.height.toDouble()),
            ui.Rect.fromLTWH(x - z / 2, top - z - 4 * s + bob, z, z), _paint);
      }
      m.barY = top - (mk != null ? (m.lord ? 46 : 38) * s : 10 * s);
    } else if (m.gob) {
      m.barY = top - 12 * s;
      _bar(x, m.barY!, 44 * s, m.hp / m.max, const ui.Color(0xFFFFD34A));
      if (m.dead == 0 && !m.flee) {
        final life = m.life ?? 0;
        _text('⏱${math.max(0, life).ceil()}', x + 25 * s + 14 * s, m.barY! + 6 * s, 12 * s,
            life < 4 ? const ui.Color(0xFFFF8A7A) : const ui.Color(0xFFFFE27A),
            stroke: const ui.Color(0xFF3A2600), strokeW: 3 * s, weight: FontWeight.w800);
      }
    } else {
      m.barY = top - 12 * s;
      _bar(x, m.barY!, 32 * s, m.hp / m.max, const ui.Color(0xFFFF6B7D));
    }
  }

  // ── 효과·투사체 (웹 drawFxs/fxFrame/drawProj) ──
  void _fxFrame(String k, int i, num x, num y, num size0, {num rot = 0, num alpha = 1}) {
    final im = _img['fx/fx_$k.png'];
    if (im == null) return;
    final size = size0.toDouble();
    final cw = im.width / fxFrames[k]!, h = im.height.toDouble(), w = size * cw / h;
    _c.save();
    _c.translate(x.toDouble(), y.toDouble());
    if (rot != 0) _c.rotate(rot.toDouble());
    _c.drawImageRect(im, ui.Rect.fromLTWH(i * cw, 0, cw, h), ui.Rect.fromLTWH(-w / 2, -size / 2, w, size),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..color = ui.Color.fromRGBO(0, 0, 0, _cl(alpha)));
    _c.restore();
  }

  void _drawFxs() {
    for (final f in sim.fxs) {
      final n = fxFrames[f.k]!, i = math.min(n - 1, (f.t / f.d * n).floor());
      final a = f.t > f.d * .7 ? math.max(0, 1 - (f.t - f.d * .7) / (f.d * .3)) : 1;
      _fxFrame(f.k, i, f.x, f.y + f.vy * f.t, f.size, alpha: a);
    }
  }

  void _drawProj(Proj p, double s) {
    final k = p.t / p.d, x = (p.x + (p.tx - p.x) * k).toDouble();
    final y = (p.y + (p.ty - p.y) * k - math.sin(k * math.pi) * (p.kind == 'harpoon' ? 4 : 14) * s).toDouble();
    switch (p.kind) {
      case 'harpoon' when sim.fxOk('harpoon'):
        _fxFrame('harpoon', 0, x, y, 30 * s * (p.big ?? 1).toDouble(), rot: math.atan2((p.ty - p.y).toDouble(), (p.tx - p.x).toDouble()));
      case 'bees' when sim.fxOk('bees'):
        _fxFrame('bees', (_t * 12).floor() % 4, x, y, 40 * s);
      case 'soup' when sim.fxOk('soup'):
        _fxFrame('soup', 0, x, y, 26 * s, rot: math.sin(k * math.pi * 2) * .4);
      case 'pollen':
        for (var i = 0; i < 6; i++) {
          _ell(x + math.sin(_t * 14 + i * 1.9) * 7 * s, y + math.cos(_t * 11 + i * 2.6) * 6 * s, 2.2 * s, 2.2 * s,
              i.isOdd ? const ui.Color(0xFFFFE36E) : const ui.Color(0xFFFF9EC7));
        }
      case 'net' when sim.fxOk('net'):
        // 넬라 기본 공격: 손그림 감긴 그물(fx_net 1번째 칸)
        _fxFrame('net', 0, x, y, (6 + k * 8) * s * 2.4, rot: math.sin(_t * 10) * .35);
      case 'net':
        final r = ((6 + k * 8) * s).toDouble();
        _c.save();
        _c.translate(x, y);
        _c.rotate(_t * 6);
        final pt = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..color = const ui.Color(0xFFD9E6EE);
        final path = ui.Path()..addOval(ui.Rect.fromCircle(center: ui.Offset.zero, radius: r));
        for (var i = -1; i <= 1; i++) {
          path
            ..moveTo(i * r * .5, -r * .9)
            ..lineTo(i * r * .5, r * .9)
            ..moveTo(-r * .9, i * r * .5)
            ..lineTo(r * .9, i * r * .5);
        }
        _c.drawPath(path, pt);
        _c.restore();
      default:
        _ell(x, y, 4.5 * s, 3 * s, const ui.Color(0xFFE8E2D8));
    }
  }

  // ── 스킬 효과·컷인 (웹 drawSkillFx) ──
  void _drawSkillFx(BattleLayout l) {
    final s = l.s.toDouble(), sk = sim.skx;
    if (sk.shield > 0 && sim.party.containsKey('bron') && sim.fxOk('skill_bron')) {
      final e = 5 - sk.shield;
      final i = e < .12 ? 0 : e < .28 ? 1 : sk.shield < .35 ? 3 : 2, hh = (e < .5 ? 120 : 100) * s;
      _fxFrame('skill_bron', i, (l.pos['bron'] ?? l.front) + 44 * s, (l.py['bron'] ?? l.bot) - hh * .42, hh,
          alpha: math.min(1, sk.shield * 3) * (e < .5 ? .95 : .7));
    }
    if (sk.feast > 0) {
      for (final id in l.ids) {
        final yy = l.py[id]! - ((_t * 40 + l.pos[id]!) % 40) * s;
        _text('▲', l.pos[id]! + 14 * s, yy - 30 * s, 12 * s, const ui.Color(0xFFFFD27A),
            alpha0: math.min(1, sk.feast) * .6, weight: FontWeight.w700);
      }
    }
    if (sim.flash > 0) {
      _c.drawRect(ui.Rect.fromLTWH(-20, -20, _w + 40, _ht + 40), ui.Paint()..color = ui.Color.fromRGBO(255, 246, 208, _cl(sim.flash * 2)));
    }
    final cut = sim.cut;
    if (cut != null) {
      final k = _cl(math.min((1.6 - cut.t) * 6, cut.t * 3));
      final y = math.max(_ht * .2, insets.top + 8);
      final sx = (-60 * (1 - math.min(1, (1.6 - cut.t) * 5))).toDouble();
      final g = ui.Gradient.linear(ui.Offset.zero, ui.Offset(_w, 0),
          [const ui.Color(0xE6FFC94A), const ui.Color(0x59FFC94A), const ui.Color(0x00FFC94A)], [0, .7, 1]);
      _c.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, k));
      _c.drawRect(ui.Rect.fromLTWH(0, y, _w, 66), ui.Paint()..shader = g);
      final im = _img['portraits/portrait_${cut.id}_${skills[cut.id]!.face}.png'];
      if (im != null) {
        const z = 92.0;
        _c.drawImageRect(im, ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), ui.Rect.fromLTWH(8 + sx, y + 66 - z, z, z), _paint);
      }
      _text('${comps[cut.id]!.n} 스킬', 100 + sx, y + 20, 11, const ui.Color(0xFF2A1A00), align: -1);
      _text(skills[cut.id]!.n, 100 + sx, y + 42, 21, const ui.Color(0xFFFFFFFF),
          align: -1, serif: true, stroke: const ui.Color(0xFF5A3A00), strokeW: 4);
      _text('“${skills[cut.id]!.line}”', 100 + sx, y + 59, 11, const ui.Color(0xFF3A2400), align: -1, weight: FontWeight.w600, maxW: _w - 110 - sx);
      _c.restore();
    }
  }

  // ── 말풍선 (웹 drawQuip) ──
  void _drawQuip(BattleLayout l) {
    final q = sim.quip;
    if (q == null) return;
    final id = comps.containsKey(q.who) && q.who != 'kael' && l.pos[q.who] != null ? q.who : 'kael';
    final x = l.pos[id]?.toDouble();
    if (x == null) return;
    final gy = (l.py[id] ?? l.top).toDouble(), s = l.s.toDouble(), z = math.max(.85, s);
    final lumi = q.who == 'q';
    final who = lumi ? '루미나르' : id == 'kael' ? '카엘' : comps[id]!.n;
    final tp = TextPainter(
      text: TextSpan(text: q.txt, style: TextStyle(fontFamily: 'PlexKR', fontSize: 11 * z, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = math.min(_w - 12, tp.width + 16), h = 30 * z;
    final bx = math.max(6.0, math.min(_w - w - 6, x - w * .35));
    var by = (gy - (heightOf(id) + 22) * s - h).toDouble();
    if (by < insets.top) by = insets.top;
    final a = _cl(q.t * 2);
    final bg = lumi ? ui.Color.fromRGBO(20, 32, 60, .92 * a) : ui.Color.fromRGBO(255, 255, 255, .92 * a);
    _rr(bx, by, w, h, 8, bg);
    _c.drawPath(
        ui.Path()
          ..moveTo(x - 4, by + h)
          ..lineTo(x + 4, by + h)
          ..lineTo(x, by + h + 6)
          ..close(),
        ui.Paint()..color = bg);
    _text(who, bx + 8, by + 11 * z, 9 * z, lumi ? const ui.Color(0xFF8FD0FF) : const ui.Color(0xFF4A7A3A), alpha0: a, align: -1);
    _text(q.txt, bx + 8, by + 24 * z, 11 * z, lumi ? const ui.Color(0xFFEEF6FF) : const ui.Color(0xFF22262E),
        alpha0: a, align: -1, weight: FontWeight.w600, maxW: w - 16);
  }

  // ── 보스 출현 경고·탈환 띠 ──
  void _drawWarn(BattleLayout l) {
    final wr = sim.warn;
    if (wr == null) return;
    final k = _cl(math.min((1.4 - wr.t) * 6, wr.t * 2.5));
    final cy = _ht * .3, col = wr.cmd ? const [150, 80, 255] : const [255, 40, 60];
    _c.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, k));
    final v = ui.Gradient.radial(ui.Offset(_w / 2, _ht / 2), math.max(_w, _ht) * .75,
        [ui.Color.fromRGBO(col[0], col[1], col[2], 0), ui.Color.fromRGBO(col[0], col[1], col[2], .55)],
        [math.min(_w, _ht) * .3 / (math.max(_w, _ht) * .75), 1]);
    _c.drawRect(ui.Rect.fromLTWH(0, 0, _w, _ht), ui.Paint()..shader = v);
    final g = ui.Gradient.linear(ui.Offset.zero, ui.Offset(_w, 0),
        [const ui.Color(0x00140408), const ui.Color(0xD9140408), const ui.Color(0xD9140408), const ui.Color(0x00140408)], [0, .2, .8, 1]);
    _c.drawRect(ui.Rect.fromLTWH(0, cy - 26, _w, 52), ui.Paint()..shader = g);
    final line = ui.Paint()..color = ui.Color.fromRGBO(col[0], col[1], col[2], .9);
    _c.drawRect(ui.Rect.fromLTWH(0, cy - 26, _w, 2), line);
    _c.drawRect(ui.Rect.fromLTWH(0, cy + 24, _w, 2), line);
    final sx = ((1 - math.min(1, (1.4 - wr.t) * 4)) * 40).toDouble();
    _text(wr.txt ?? (wr.cmd ? '⚠ 군단장 출현! ⚠' : '⚠ 성주 출현! ⚠'), _w / 2 + sx, cy + 8, (24 * math.min(1.2, l.s)).round(),
        wr.cmd ? const ui.Color(0xFFE2C4FF) : const ui.Color(0xFFFFD2D8),
        serif: true, stroke: const ui.Color(0xFF1A0006), strokeW: 4);
    _c.restore();
  }

  void _drawBanner(BattleLayout l) {
    final b = sim.banner;
    if (b == null) return;
    final k = _cl(math.min((2 - b.t) * 5, b.t * 2.5));
    final cy = _ht * .36, im = _img['ui/banner_capture.png'];
    _c.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, k));
    final bw = math.min(_w * .98, 460.0), bh = bw / 4;
    if (im != null) {
      final sc = (.85 + .15 * math.min(1, (2 - b.t) * 6)).toDouble();
      _c.save();
      _c.translate(_w / 2, cy);
      _c.scale(sc, sc);
      _c.drawImageRect(im, ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), ui.Rect.fromLTWH(-bw / 2, -bh * .55, bw, bh), _paint);
      _c.restore();
    }
    final bf = im != null ? bw * .052 : 26 * math.min(1.3, l.s).toDouble();
    final ty = im != null ? cy + bf * .1 : cy + 4;
    _text(b.txt, _w / 2, ty + bf * .35, bf, const ui.Color(0xFFFFE08A), serif: true, stroke: const ui.Color(0xFF3A1200), strokeW: 4, maxW: _w * .42);
    final sy = im != null ? cy + bh * .62 : cy + 21;
    _text(b.sub, _w / 2, sy, 12, const ui.Color(0xFFF4EAD0), stroke: const ui.Color(0xB3000000), strokeW: 3, weight: FontWeight.w600);
    _c.restore();
  }
}
