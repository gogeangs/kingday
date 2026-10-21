/// 그리기(Painter)용 그림 저장소 — 처음 부를 때 불러 두고, 다 불러오면 다음 그림부터 보임
library;

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class ImageStore {
  static final Map<String, ui.Image> _m = {};
  static final Set<String> _loading = {};

  /// 불러온 그림. 아직이면 null 을 돌려주고 불러오기 시작
  static ui.Image? get(String asset) {
    final im = _m[asset];
    if (im != null) return im;
    if (_loading.add(asset)) {
      rootBundle
          .load(asset)
          .then((d) => ui.instantiateImageCodec(d.buffer.asUint8List()))
          .then((c) => c.getNextFrame())
          .then((f) => _m[asset] = f.image)
          .catchError((Object _) => _blank);
    }
    return null;
  }

  static final ui.Image _blank = (() {
    final r = ui.PictureRecorder();
    ui.Canvas(r);
    return r.endRecording().toImageSync(1, 1);
  })();
}

/// 그림 전체를 dst 에 그림
void drawImg(ui.Canvas c, ui.Image im, ui.Rect dst, {double alpha = 1, ui.ColorFilter? filter}) {
  final p = ui.Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..color = ui.Color.fromRGBO(0, 0, 0, alpha < 0 ? 0.0 : alpha > 1 ? 1.0 : alpha);
  if (filter != null) p.colorFilter = filter;
  c.drawImageRect(im, ui.Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst, p);
}
