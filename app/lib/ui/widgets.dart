/// 공통 화면 부품 — 웹 index.html CSS 의 .box .row .sec .note .kv .xp .buy .acts .sheet .talk 를 옮긴 것.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../game/feel.dart';
import 'theme.dart';

const _ui = 'assets/game/ui';

/// 그림이 없으면 빈칸 (웹 onerror="this.remove()")
Widget kdImg(String path, {double? w, double? h, BoxFit fit = BoxFit.contain, Alignment align = Alignment.center}) => Image.asset(
      path,
      width: w,
      height: h,
      fit: fit,
      alignment: align,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(width: w, height: h),
    );

Widget uiImg(String name, {double size = 24}) => kdImg('$_ui/$name.png', w: size, h: size);

/// .box — 판넬 상자
class KdBox extends StatelessWidget {
  const KdBox({super.key, required this.children, this.gap = 10, this.padding = const EdgeInsets.all(12)});
  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: KdColors.panel, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(children, gap)),
      );
}

/// .row — 한 줄 항목 (아이콘 · 정보 · 버튼)
class KdRow extends StatelessWidget {
  const KdRow({super.key, required this.children, this.locked = false, this.highlight});
  final List<Widget> children;
  final bool locked;
  final Color? highlight;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: locked ? .6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: KdColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: highlight != null ? Border.all(color: highlight!, width: 1.5) : null,
          ),
          child: Row(children: _gap(children, 10, horizontal: true)),
        ),
      );
}

/// .sec — 소제목 (오른쪽에 작은 설명)
class KdSec extends StatelessWidget {
  const KdSec(this.title, {super.key, this.small});
  final String title;
  final String? small;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: KdText.display(15))),
          if (small != null) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(small!, textAlign: TextAlign.right, style: KdText.body(12, color: KdColors.muted))),
          ],
        ],
      );
}

/// .note — 회색 설명글
class KdNote extends StatelessWidget {
  const KdNote(this.text, {super.key, this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: KdText.body(12, color: KdColors.muted, height: 1.6));
}

/// .kv — 왼쪽 이름, 오른쪽 값
class KdKv extends StatelessWidget {
  const KdKv(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(k, style: KdText.body(13, color: KdColors.muted))),
        Text(v, style: KdText.figure(13, weight: FontWeight.w600)),
      ]);
}

/// .xp — 진행 막대
class XpBar extends StatelessWidget {
  const XpBar(this.value, {super.key, this.height = 6, this.color = KdColors.gold, this.bg = KdColors.panel2});
  final double value, height;
  final Color color, bg;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: bg,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: value.isNaN ? 0 : value.clamp(0, 1).toDouble(), child: Container(color: color)),
        ),
      );
}

/// 버튼 색 규칙 (U-2 ⑦): gold = 골드·이삭 쓰기 · ghost = 다른 화면으로 이동 · claim(초록) = 받기
enum BuyKind { gold, ghost, gem, ad, danger, claim }

/// 누르면 살짝 작아지는 효과 (U-2 ⑩, 웹 .buy:active scale .95)
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(scale: _down ? .95 : 1, duration: const Duration(milliseconds: 80), child: widget.child),
      );
}

/// .buy — 사는/올리는 버튼. [label] 위 작은 글자, [cost] 아래 큰 글자(아이콘과 함께)
class KdBuy extends StatelessWidget {
  const KdBuy({
    super.key,
    this.label,
    this.cost,
    this.costIcon,
    this.text,
    this.onTap,
    this.kind = BuyKind.gold,
    this.minWidth = 84,
    this.glow = false,
    this.small = false,
    this.extra,
  });

  /// 위 작은 글자 (웹 .bl)
  final String? label;

  /// 아래 값 (웹 .bc). 숫자면 fmt 로 표시
  final num? cost;
  final String? costIcon;

  /// 글자만 있는 버튼
  final String? text;
  final VoidCallback? onTap;
  final BuyKind kind;
  final double minWidth;
  final bool glow, small;

  /// .bc 옆에 붙는 두 번째 값(광석 등)
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    final (Color? bg, Gradient? grad, Color fg, Border? border) = switch (kind) {
      _ when off && kind != BuyKind.ghost => (KdColors.panel2, null, KdColors.muted, null),
      BuyKind.gold => (KdColors.gold, null, KdColors.goldInk, null),
      BuyKind.ghost => (Colors.transparent, null, off ? KdColors.muted : KdColors.fg, Border.all(color: KdColors.line)),
      BuyKind.gem => (null, const LinearGradient(colors: [Color(0xFF2C4A8C), Color(0xFF1D3366)], begin: Alignment.topCenter, end: Alignment.bottomCenter), const Color(0xFFFFE08A), Border.all(color: const Color(0xFF5A7AC8))),
      BuyKind.ad || BuyKind.claim => (null, const LinearGradient(colors: [Color(0xFF2F7A4A), Color(0xFF1D5232)], begin: Alignment.topCenter, end: Alignment.bottomCenter), const Color(0xFFE8FFE8), Border.all(color: const Color(0xFF5AC07A))),
      BuyKind.danger => (const Color(0xFF5A1A24), null, const Color(0xFFFFD6DC), Border.all(color: KdColors.bad)),
    };
    final costColor = off && kind == BuyKind.gold ? const Color(0xFFFF8D9A) : fg;
    final content = <Widget>[
      if (label != null) Text(label!, style: KdText.body(small ? 10 : 11, color: fg.withValues(alpha: .8), weight: FontWeight.w600, height: 1.2)),
      if (cost != null || text != null)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (costIcon != null) ...[kdImg(costIcon!, w: 18, h: 18), const SizedBox(width: 3)],
            Text(text ?? fmt(cost!), style: KdText.figure(small ? 13 : 15, color: text != null ? fg : costColor)),
            if (extra != null) ...[const SizedBox(width: 6), extra!],
          ]),
        ),
    ];
    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              Feel.sound('tap');
              onTap!();
            },
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 5 : 9),
        decoration: BoxDecoration(
          color: bg,
          gradient: off ? null : grad,
          borderRadius: BorderRadius.circular(10),
          border: border,
          boxShadow: glow && !off ? const [BoxShadow(color: Color(0xCCFFD23C), blurRadius: 12)] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: content),
      ),
    );
  }
}

/// .acts — 창 아래 버튼 줄 (보조 버튼 + 주 버튼)
class KdActs extends StatelessWidget {
  const KdActs({super.key, required this.buttons});
  final List<KdAct> buttons;

  @override
  Widget build(BuildContext context) => Row(
        children: _gap([for (final b in buttons) Expanded(child: b)], 8, horizontal: true),
      );
}

class KdAct extends StatelessWidget {
  const KdAct(this.text, {super.key, this.onTap, this.primary = false, this.danger = false, this.claim = false, this.child});
  final String text;
  final VoidCallback? onTap;

  /// claim: 초록 「받기」 버튼 (U-2 ⑦)
  final bool primary, danger, claim;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final green = claim && onTap != null;
    final bg = danger || green
        ? null
        : primary
            ? KdColors.gold
            : KdColors.panel2;
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Pressable(
        onTap: onTap == null
            ? null
            : () {
                Feel.sound('tap');
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.all(11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            gradient: danger
                ? const LinearGradient(colors: [Color(0xFFFF7A6A), Color(0xFFC94A3A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                : green
                    ? const LinearGradient(colors: [Color(0xFF3FA863), Color(0xFF24713F)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                    : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: green ? const Color(0xFF5AC07A) : primary ? KdColors.gold : KdColors.line),
          ),
          child: child ??
              Text(text,
                  textAlign: TextAlign.center,
                  style: KdText.display(16, color: danger ? Colors.white : green ? const Color(0xFFEFFFF2) : primary ? KdColors.goldInk : KdColors.fg)),
        ),
      ),
    );
  }
}

// ════════════════════ 대사 (웹 para) ════════════════════

/// 'k:대사' 카엘, 'q@angry:대사' 루미나르, 'm:이름@표정|대사' 다른 인물, 'sys:설명', 그 밖은 지문
class Para extends StatelessWidget {
  const Para(this.p, {super.key});
  final String p;

  static const _npc = {
    '막례': 'makrye', '말봉': 'malbong', '덕배': 'deokbae', '페피': 'peppy', '안단테': 'andante', '토비': 'toby', '카라': 'kara', '베릴': 'beryl', '모라': 'mora', '멜로': 'melo', '포리': 'pori', '롤로': 'rollo', '크랩': 'crab', '버치': 'birch', '그램': 'gram', '고든': 'gordon', '데이지': 'daisy', '브리다': 'brida', '넬라': 'nella', '루카': 'luka', '브론': 'bron', '하랄': 'haral',
    '리엘': 'riel', '마고': 'margo', '마르타': 'marta', '피트': 'pete', '티모': 'timo', '모르바스': 'morbas', '세릴': 'seril',
    '그로마크': 'gromak', '알도르': 'aldor', '이그니스': 'ignis', '발타사르': 'baltasar',
  };

  /// guessMood(w,t): 표정이 없으면 대사로 짐작
  static String guessMood(String w, String t) {
    bool has(String re) => RegExp(re).hasMatch(t);
    if (w == 'k') {
      if (has(r'\?|누구|왜|설마')) return 'surprised';
      if (has(r'…|못 하|아니고|멀어|싫')) return 'flustered';
      if (has(r'좋|은퇴|흙|행복')) return 'smile';
      return 'idle';
    }
    if (has(r'!|당장|정신|마라|도망') && has(r'주인')) return has(r'당장|정신|도망') ? 'angry' : 'proud';
    if (has(r'300년|드디어|운명|보람')) return 'moved';
    return 'proud';
  }

  static const _lore = 14.5;

  Widget _talk(String face, Color border, Gradient bg, Widget line, {Alignment pos = const Alignment(0, -.6)}) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 2), gradient: bg),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: kdImg(face, fit: BoxFit.cover, align: pos)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x38000000), borderRadius: BorderRadius.circular(12)),
              child: line,
            ),
          ),
        ],
      );

  /// 이름은 대사 앞에 작게 붙임 (웹 .talk .who inline)
  Widget _line(String who, String t, Color c) => Text.rich(TextSpan(children: [
        TextSpan(text: '$who  ', style: KdText.body(11.5, color: c.withValues(alpha: .7))),
        TextSpan(text: t, style: KdText.display(14, color: c, weight: FontWeight.w500).copyWith(height: 1.5)),
      ]));

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^([kq])(?:@(\w+))?:').firstMatch(p);
    if (m != null) {
      final w = m.group(1)!, t = p.substring(m.end), mood = m.group(2) ?? guessMood(w, t);
      final lumi = w == 'q';
      return _talk(
        'assets/game/portraits/portrait_${lumi ? 'luminar' : 'kael'}_$mood.png',
        lumi ? const Color(0xFF5AB4FF) : const Color(0xFFC9952A),
        lumi
            ? const RadialGradient(colors: [Color(0xFF203A66), Color(0xFF0D1220)])
            : const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFF2C4A7A), KdColors.bg]),
        _line(lumi ? '성검 루미나르' : '카엘', t, lumi ? KdColors.gold : const Color(0xFFA8E6B0)),
        pos: lumi ? const Alignment(0, -.2) : const Alignment(0, -.6),
      );
    }
    if (p.startsWith('m:')) {
      final i = p.indexOf('|');
      var w = p.substring(2, i < 0 ? p.length : i);
      final t = i < 0 ? '' : p.substring(i + 1);
      var mood = 'idle';
      if (w.contains('@')) {
        final sp = w.split('@');
        w = sp[0];
        mood = sp[1];
      }
      final line = _line(w, t, const Color(0xFFFFD9A8));
      final id = _npc[w];
      if (id == null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0x38000000), borderRadius: BorderRadius.circular(12)),
          child: line,
        );
      }
      return _talk('assets/game/portraits/portrait_${id}_$mood.png', const Color(0xFFFFD9A8),
          const RadialGradient(center: Alignment(0, -.2), colors: [Color(0xFF2C4A7A), KdColors.bg]), line,
          pos: const Alignment(0, -.4));
    }
    if (p.startsWith('sys:')) {
      return Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: KdColors.line))),
        child: Text(p.substring(4), style: KdText.body(13, color: KdColors.muted, height: 1.5)),
      );
    }
    return Text(p, style: KdText.display(_lore, weight: FontWeight.w500).copyWith(height: 1.6));
  }
}

// ════════════════════ 창 (웹 .modal .sheet) ════════════════════

/// 금테 창 틀 (assets/ui/frame_popup.png 를 9칸으로 늘려 씀, 웹 border-image 70 / 22px)
class KdSheetFrame extends StatelessWidget {
  const KdSheetFrame({super.key, required this.child, this.onClose});
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.sizeOf(context).height * .9),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(decoration: BoxDecoration(color: KdColors.panel, borderRadius: BorderRadius.circular(4))),
            ),
          ),
          // 금테: 웹 border-image: frame_popup.png 70 fill / 22px (모서리 70px 를 22px 로 줄여 그림)
          const Positioned.fill(child: NineSlice('$_ui/frame_popup.png', slice: 70, border: 22)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
            child: SingleChildScrollView(child: child),
          ),
          if (onClose != null)
            Positioned(
              right: 14,
              top: 14,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 2))], shape: BoxShape.circle),
                  child: uiImg('btn_close', size: 34),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 창 안의 내용 순서: 그림 → 작은 머리글 → 제목 → 내용 → 버튼
class KdSheetBody extends StatelessWidget {
  const KdSheetBody({super.key, this.illust, this.illustFace, this.eyebrow, this.eyebrowColor, this.title, this.titleWidget, this.children = const [], this.acts});
  final String? illust, eyebrow, title;

  /// 그림 위 왼쪽 아래에 띄울 동료 초상화 (웹 .joinpf)
  final String? illustFace;
  final Color? eyebrowColor;
  final Widget? titleWidget;
  final List<Widget> children;
  final KdActs? acts;

  /// illust_<이름>.jpg 의 보이는 부분 (웹 .il-*)
  static const _illPos = {
    'prologue': Alignment(0, -.32), 'join': Alignment(0, .1), 'retire': Alignment(0, -.04), 'offline': Alignment(-.16, 0),
  };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _gap([
          if (illust != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              // 웹 .illust: 2:1 (합류 장면 12:5), 화면 높이의 30%(작은 화면 22%)를 넘지 않게
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * (MediaQuery.sizeOf(context).height <= 700 ? .22 : .30)),
                child: AspectRatio(
                aspectRatio: illust == 'join' ? 12 / 5 : 2,
                child: LayoutBuilder(
                  builder: (_, c) => Stack(fit: StackFit.expand, children: [
                    kdImg('assets/game/illust/illust_$illust.jpg', fit: BoxFit.cover, align: _illPos[illust] ?? const Alignment(0, -.1)),
                    if (illustFace != null)
                      Positioned(
                        left: c.maxWidth * .12,
                        bottom: c.maxHeight * .04,
                        width: c.maxWidth * .38,
                        height: c.maxWidth * .38,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Color(0x80FFE68C), blurRadius: 18)],
                          ),
                          child: kdImg('assets/game/portraits/portrait_${illustFace}_idle.png'),
                        ),
                      ),
                  ]),
                ),
              ),
              ),
            ),
          if (eyebrow != null)
            Text(eyebrow!, textAlign: TextAlign.center, style: KdText.body(12, color: eyebrowColor ?? KdColors.gold).copyWith(letterSpacing: 2.4)),
          if (titleWidget != null) titleWidget!,
          if (title != null) Text(title!, textAlign: TextAlign.center, style: KdText.display(20)),
          ...children,
          if (acts != null) acts!,
        ], MediaQuery.sizeOf(context).height <= 700 ? 7 : 9),
      );
}

/// 창 띄우기. [closable] 이면 오른쪽 위 ✕·바깥 누르기로 닫힘.
Future<T?> showKdSheet<T>(BuildContext context, {required Widget Function(BuildContext ctx) builder, bool closable = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: closable,
    barrierLabel: '닫기',
    barrierColor: const Color(0xBF060912),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            type: MaterialType.transparency,
            child: KdSheetFrame(onClose: closable ? () => Navigator.of(ctx).pop() : null, child: builder(ctx)),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)), child: child),
    ),
  );
}

List<Widget> _gap(List<Widget> ws, double g, {bool horizontal = false}) {
  final out = <Widget>[];
  for (var i = 0; i < ws.length; i++) {
    if (i > 0) out.add(horizontal ? SizedBox(width: g) : SizedBox(height: g));
    out.add(ws[i]);
  }
  return out;
}


/// 9칸 나눠 그리기 (웹 border-image): 그림의 가장자리 [slice]px 를 화면에서 [border]px 로 그리고 가운데는 늘림
class NineSlice extends StatefulWidget {
  const NineSlice(this.asset, {super.key, required this.slice, required this.border});
  final String asset;
  final double slice, border;

  @override
  State<NineSlice> createState() => _NineSliceState();
}

class _NineSliceState extends State<NineSlice> {
  ui.Image? _img;
  ImageStream? _stream;
  late final ImageStreamListener _l = ImageStreamListener((info, _) {
    if (mounted) setState(() => _img = info.image);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_l);
    _stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context))..addListener(_l);
  }

  @override
  void dispose() {
    _stream?.removeListener(_l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NinePainter(_img, widget.slice, widget.border));
}

class _NinePainter extends CustomPainter {
  _NinePainter(this.img, this.s, this.b);
  final ui.Image? img;
  final double s, b;

  @override
  void paint(Canvas canvas, Size size) {
    final im = img;
    if (im == null) return;
    final iw = im.width.toDouble(), ih = im.height.toDouble();
    final p = Paint()..filterQuality = FilterQuality.medium;
    final sx = [0.0, s, iw - s, iw], sy = [0.0, s, ih - s, ih];
    final dx = [0.0, b, size.width - b, size.width], dy = [0.0, b, size.height - b, size.height];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        canvas.drawImageRect(
          im,
          Rect.fromLTRB(sx[c], sy[r], sx[c + 1], sy[r + 1]),
          Rect.fromLTRB(dx[c], dy[r], dx[c + 1], dy[r + 1]),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NinePainter o) => o.img != img || o.s != s || o.b != b;
}

/// 빨간 점 (할 수 있는 일이 있을 때, 웹 .dot)
class KdRedDot extends StatelessWidget {
  const KdRedDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: KdColors.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
      );
}
