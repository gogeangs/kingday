/// 정기 이벤트 창 (docs/content/EVENT_SNOW.md 4장) — 웹 evSheet·evAttHtml·evBossHtml·evShopHtml·evMgHtml·evBtnTap(잠김)·
/// evBossEnd(결과 창)·evGiftSheet(산타 피트 선물)·evTreeHit(트리 선물) 의 화면 부분.
/// 규칙·저장은 core/event.dart (EventCalc·EventAct), 흐름(대기열·광고·도전 시작)은 game/controller_event.dart.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/attendance.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/event.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'social_sheets.dart' show openRanking;

/// 'assets/ui/x.png' (웹 경로) → 'assets/game/ui/x.png' (앱 그림)
String _ga(String p) => p.startsWith('assets/game/') ? p : p.replaceFirst('assets/', 'assets/game/');

/// 남은 날 (웹 Math.max(0, Math.floor(ms / 864e5)))
int _days(num ms) {
  final v = ms / 864e5;
  return v.isFinite ? math.max(0, v.floor()) : 0;
}

String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

/// 이벤트마다 마지막으로 본 탭 (웹 evTab)
final Map<String, String> _evTab = {};

/// 이벤트 창 열기 (웹 evSheet(id, tab)): 기간 중·상점만 열린 동안
Future<void> openEventSheet(GameController g, [String? id, String? tab]) async {
  final e = id != null ? evts[id] : g.calc.evCur();
  if (e == null) return;
  if (!const ['on', 'shop'].contains(g.calc.evPhase(e))) {
    g.toast('${e.n}이(가) 끝났어요');
    return;
  }
  if (tab != null) _evTab[e.id] = tab;
  await g.openSheet<void>((c) => ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => EventSheet(g, c, id: e.id)));
}

/// 이야기 창 다음에 바로 이벤트 창 (웹 sceneQ.unshift(() => evSheet(id, tab)))
void queueEventSheet(GameController g, [String? id, String? tab]) {
  final e = id != null ? evts[id] : g.calc.evCur();
  if (e == null || !const ['on', 'shop'].contains(g.calc.evPhase(e))) return;
  if (tab != null) _evTab[e.id] = tab;
  g.queueFirst((ctx) => showKdSheet<void>(ctx, builder: (c) => ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => EventSheet(g, c, id: e.id))));
}

/// 영지 10 전: 「영지 10부터 함께해요」 (웹 evBtnTap 잠김)
Future<void> openEventLock(GameController g, EventDef e) {
  final d = g.calc.evDates(e);
  return g.openSheet<void>((c) => KdSheetBody(
        titleWidget: EvBanner(e),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '정기 이벤트 「${e.n}」이(가) 열렸어요!\n'),
                TextSpan(text: '영지 $evOpenLand', style: const TextStyle(fontWeight: FontWeight.w700, color: KdColors.fg)),
                TextSpan(text: '에 닿으면 함께할 수 있어요 · ${kstDate(d.start)} ~ ${kstDate(d.end - 1)}'),
              ]),
              textAlign: TextAlign.center,
              style: KdText.body(12, color: KdColors.muted, height: 1.6),
            ),
          ),
        ],
        acts: KdActs(buttons: [KdAct('영지 $evOpenLand부터 함께해요', primary: true, onTap: () => Navigator.of(c).pop())]),
      ));
}

/// 이벤트 배너 (웹 .hdban.evban — 글자는 눈빛 흰색)
class EvBanner extends StatelessWidget {
  const EvBanner(this.e, {super.key, this.text});
  final EventDef e;
  final String? text;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: AspectRatio(
            aspectRatio: 720 / 225,
            child: Stack(fit: StackFit.expand, children: [
              kdImg(_ga(e.art['hd'] ?? 'assets/ui/hd_snow.png')),
              Padding(
                padding: const EdgeInsets.only(top: 3.3),
                child: Center(
                  child: Text(text ?? e.n,
                      style: KdText.display(20, color: const Color(0xFFF2FBFF)).copyWith(letterSpacing: .8, shadows: const [
                        Shadow(color: Color(0xCC0A1E46), offset: Offset(0, 2), blurRadius: 3),
                        Shadow(color: Color(0x9978B4FF), blurRadius: 8),
                      ])),
                ),
              ),
            ]),
          ),
        ),
      );
}

// ════════════════════ 보상 그림·글 (웹 evRwTxt · evRwIc · attIc) ════════════════════
/// 보상 미리보기 글 (웹 evRwTxt)
String evRwTxt(EventDef e, Map<String, dynamic> r) {
  switch (r['k']) {
    case 'sf':
      return '${e.curN} ${_n(asNum(r['n']))}';
    case 'gold':
      return '골드 ${_n(asNum(r['h']))}시간';
    case 'gem':
      return '이삭 ${_n(asNum(r['n']))}';
    case 'ore':
      return '광석 ${_n(asNum(r['n']))}';
    case 'tbox':
      return '상자 ${_n(asNum(r['n']))}개';
    case 'card':
      return '동료 카드 ${_n(asNum(r['n']))}';
    case 'lcard':
      return '전설 만능 ${_n(asNum(r['n']))}';
    case 'evcard':
      return '${comps[r['id']]?.n ?? r['id']} 카드 ${_n(asNum(r['n']))}';
    case 'frame':
      return '테두리 「${decoName(pframes, r['id'] as String)}」';
    case 'badge':
      return '배지 「${decoName(badges, r['id'] as String)}」';
  }
  return '';
}

/// 받은 줄·보상 칸의 그림 (웹 attIc · 상자권 그림 · 전설 꼬리표)
Widget evKindIcon(String kind, double size) {
  final p = switch (kind) {
    'gold' => 'assets/game/ui/ui_gold.png',
    'gem' => 'assets/game/gem/ui_gem.png',
    'ore' => 'assets/game/ui/item_ore.png',
    'seed' => 'assets/game/ui/seed_wheat.png',
    'tbox' => 'assets/game/ui/item_boxticket.png',
    'tbox10' => 'assets/game/ui/item_box10ticket.png',
    'card' || 'ecard' || 'lcard' => 'assets/game/ui/card_back.png',
    _ => 'assets/game/profile/badge_att.png',
  };
  final im = kdImg(p, w: size, h: size);
  if (kind != 'lcard') return im;
  // 전설 만능 카드: 카드 뒷면 + 「전설」 꼬리표 (웹 .lcic)
  return SizedBox(
    width: size,
    height: size,
    child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      im,
      Positioned(
        bottom: -2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: const Color(0xFFFFC23A), borderRadius: BorderRadius.circular(5)),
          child: Text('전설', style: KdText.body(math.min(9.0, size * .34), color: const Color(0xFF2A1A00), weight: FontWeight.w700, height: 1.2)),
        ),
      ),
    ]),
  );
}

/// 보상 하나의 그림 (웹 evRwIc)
Widget evRwIcon(EventDef e, Map<String, dynamic> r, double size) {
  final k = r['k'] as String;
  if (k == 'sf') return kdImg(e.curImg, w: size, h: size);
  if (k == 'evcard') {
    return ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: kdImg('assets/game/portraits/portrait_${r['id']}_idle.png', w: size, h: size, fit: BoxFit.cover));
  }
  if (k == 'frame') return kdImg(frameAsset(r['id'] as String), w: size, h: size);
  if (k == 'badge') return kdImg(badgeAsset(r['id'] as String), w: size, h: size);
  return evKindIcon(k, size);
}

/// 받은 보상 줄 (웹 .attrws .attrw)
class EvRowsView extends StatelessWidget {
  const EvRowsView(this.rows, {super.key});
  final List<EvRow> rows;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(children: [
            rows[i].img != null
                ? (rows[i].kind == 'evcard'
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: kdImg(rows[i].img!, w: 24, h: 24, fit: BoxFit.cover))
                    : kdImg(rows[i].img!, w: 24, h: 24))
                : evKindIcon(rows[i].kind, 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(rows[i].text, style: KdText.body(13, weight: FontWeight.w700)),
                if (rows[i].sub.isNotEmpty) Text(rows[i].sub, style: KdText.body(12, color: KdColors.muted)),
              ]),
            ),
          ]),
        ],
      ]);
}

/// 방금 받은 것 상자 (웹 .evjust)
Widget _justBox(String? title, List<EvRow> rows) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1AFFD34A),
        border: Border.all(color: const Color(0x73FFD34A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (title != null) ...[
          Text(title, textAlign: TextAlign.center, style: KdText.body(13.5, color: const Color(0xFFFFD34A), weight: FontWeight.w700)),
          const SizedBox(height: 6),
        ],
        EvRowsView(rows),
      ]),
    );

Widget _small(List<InlineSpan> spans, {double size = 12}) =>
    Text.rich(TextSpan(children: spans), style: KdText.body(size, color: KdColors.muted, height: 1.4));

const _bGold = TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700);

// ════════════════════ 이벤트 창 (웹 evSheet) ════════════════════
class EventSheet extends StatefulWidget {
  const EventSheet(this.g, this.sheet, {super.key, required this.id});
  final GameController g;
  final BuildContext sheet;
  final String id;

  @override
  State<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<EventSheet> {
  GameController get g => widget.g;
  late String id = widget.id;

  /// 방금 받은 것 (출석·상점, 웹 just)
  ({String? title, List<EvRow> rows})? _just;
  bool _rwOpen = false;

  void _tab(String k) => setState(() {
        _evTab[id] = k;
        _just = null;
      });

  void _attClaim() {
    final r = g.act((a) => a.evAttClaim(id));
    if (r.err != null) {
      if (r.err!.isNotEmpty) g.toast(r.err!);
      return;
    }
    g.haptic(const [30, 40, 70]);
    g.sound('gem');
    g.save();
    setState(() => _just = (title: '${r.i + 1}번째 출석!', rows: r.rows));
  }

  void _buy(String k) {
    final r = g.act((a) => a.evBuy(id, k));
    if (r.err != null) {
      if (r.err!.isNotEmpty) g.toast(r.err!);
      return;
    }
    g.haptic(const [25]);
    g.sound('coin');
    g.save();
    setState(() => _just = (title: null, rows: r.rows));
  }

  @override
  Widget build(BuildContext context) {
    final c = g.calc, e = evts[id];
    if (e == null) return const SizedBox.shrink();
    final ph = c.evPhase(e), x = c.evToday(c.evS(id)), xm = c.evXmas(e), d = c.evDates(e), back = c.evBack(x);
    final tabs = <(String, String)>[
      if (e.att.isNotEmpty) ('att', '출석'),
      if (e.boss != null) ('boss', e.boss!.n),
      if (e.shop.isNotEmpty) ('shop', e.shopN),
      if (e.mg != null && (xm || c.evMgShow(e))) ('mg', '선물 배달'),
    ];
    if (tabs.isEmpty) return const SizedBox.shrink();
    var cur = _evTab[id] ?? (ph == 'shop' ? 'shop' : c.evAttCan(e) ? 'att' : xm ? 'mg' : 'boss');
    if (!tabs.any((t) => t.$1 == cur)) cur = tabs.first.$1;
    _evTab[id] = cur;
    final left = _days((ph == 'on' ? d.end : d.shop) - c.evNow);
    final others = c.evList().where((o) => o.id != id).toList();
    final shut = ph == 'shop' && (cur == 'att' || cur == 'boss');
    final sf = asNum(x['sf']), day = x['day'] as Map;
    bool tabDot(String k) =>
        (k == 'att' && c.evAttCan(e)) || (k == 'boss' && ph == 'on' && e.boss != null && c.evTriesLeft(e) > 0 && !back) || (k == 'mg' && c.evMgLeft(e) > 0 && !back);

    final body = shut
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: '이벤트 기간이 끝났어요. '),
                TextSpan(text: e.shopN, style: const TextStyle(fontWeight: FontWeight.w700, color: KdColors.fg)),
                TextSpan(text: '은(는) ${kstDate(d.shop - 1)}까지 열려 있어요'),
              ]),
              textAlign: TextAlign.center,
              style: KdText.body(12, color: KdColors.muted, height: 1.6),
            ),
          )
        : switch (cur) {
            'att' => _att(e, x, back),
            'boss' => _boss(e, x, back),
            'shop' => _shop(e, x),
            _ => _mg(e, x, back),
          };

    return KdSheetBody(
      titleWidget: EvBanner(e),
      children: [
        if (xm)
          Container(
            key: const ValueKey('evXm'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7A1424), Color(0xFFA52234), Color(0xFF1F6B3A)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('🎄 크리스마스 주간 · ${kstDate(d.xe - 1)}까지', textAlign: TextAlign.center, style: KdText.body(13, color: const Color(0xFFFFF3D6), weight: FontWeight.w700)),
              Text('산타 피트 선물 · 산타 눈사람 2배 · 마을 트리 · 선물 배달',
                  textAlign: TextAlign.center, style: KdText.body(11.5, color: const Color(0xE6FFF3D6), height: 1.3)),
            ]),
          ),
        // 이벤트 두 개가 겹치면 바꾸기 (웹 .evsw)
        if (others.isNotEmpty)
          Row(children: [
            for (final o in [e, ...others]) ...[
              if (o != e) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    id = o.id;
                    _just = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.id == id ? const Color(0xFFBFE6FF) : KdColors.panel2,
                      border: Border.all(color: o.id == id ? const Color(0xFFBFE6FF) : KdColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${o.n}${c.evPhase(o) == 'shop' ? ' · 상점' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(12.5, color: o.id == id ? const Color(0xFF0E2238) : KdColors.muted)),
                  ),
                ),
              ),
            ],
          ]),
        // 내 재화 · 오늘 전투 재화 · 남은 날 (웹 .evtop)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF23345C), Color(0xFF1B2847)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: Border.all(color: const Color(0xFF3B5385)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              kdImg(e.curImg, w: 28, h: 28),
              const SizedBox(width: 5),
              Text(fmt(sf), style: KdText.display(19, color: const Color(0xFFE9F7FF))),
              const SizedBox(width: 4),
              Text(e.curN, style: KdText.body(12.5, color: KdColors.muted)),
            ]),
            if (ph == 'on' && e.bat != null)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '오늘 전투 ${e.curN} '),
                  TextSpan(text: '${asNum(day['bat']).toInt()}/${_n(asNum(e.bat!['cap']))}', style: const TextStyle(color: Color(0xFFE9F7FF), fontWeight: FontWeight.w700)),
                ]),
                style: KdText.body(12.5, color: KdColors.muted),
              ),
            Text('${ph == 'shop' ? '상점 ' : ''}${left > 0 ? 'D-$left' : 'D-DAY'}', style: KdText.body(12.5, color: const Color(0xFFFFD34A), weight: FontWeight.w800)),
          ]),
        ),
        if (ph == 'shop' && sf > 0)
          Text('${e.curN}은(는) ${kstDate(d.shop - 1)}이 지나면 사라져요', textAlign: TextAlign.center, style: KdText.body(12, color: const Color(0xFFFFB3BD), height: 1.5)),
        // 탭 (웹 .subtabs.evtabs)
        Row(children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                key: ValueKey('evt-${tabs[i].$1}'),
                onTap: () => _tab(tabs[i].$1),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    height: 36,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: tabs[i].$1 == cur ? KdColors.gold : KdColors.panel2,
                      border: Border.all(color: tabs[i].$1 == cur ? KdColors.gold : KdColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tabs[i].$2,
                          maxLines: 1, style: KdText.body(13, weight: FontWeight.w700, color: tabs[i].$1 == cur ? KdColors.goldInk : KdColors.muted).copyWith(letterSpacing: -.26)),
                    ),
                  ),
                  if (tabDot(tabs[i].$1)) const Positioned(top: -3, right: -3, child: KdRedDot()),
                ]),
              ),
            ),
          ],
        ]),
        if (_just != null) _justBox(_just!.title, _just!.rows),
        body,
      ],
      acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop())]),
    );
  }

  // ── 출석 14칸 (웹 evAttHtml) ──
  Widget _att(EventDef e, Map<String, dynamic> x, bool back) {
    final c = g.calc, can = c.evAttCan(e), cnt = asNum((x['att'] as Map)['cnt']).toInt(), d = c.evDates(e), n = e.att.length;
    Widget cell(int i) {
      final r = e.att[i], got = i < cnt, big = r.any((q) => q['k'] == 'evcard' || q['k'] == 'card'), nxt = i == cnt && can;
      final ic = r[r.length > 1 && r[1]['k'] != 'gold' ? 1 : 0];
      return Opacity(
        opacity: got ? .55 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(1, 14, 1, 4),
          decoration: BoxDecoration(
            color: big ? null : KdColors.panel2,
            gradient: big ? const LinearGradient(colors: [Color(0xFF3A2C5C), Color(0xFF29334F)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            border: Border.all(color: nxt ? const Color(0xFFFFD34A) : big ? const Color(0xFFB07BFF) : KdColors.line, width: nxt ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              evRwIcon(e, ic, 26),
              const SizedBox(height: 2),
              // 낱말 단위로 줄 바꿈 (웹 word-break: keep-all)
              for (final q in r)
                for (final w in evRwTxt(e, q).split(' '))
                  FittedBox(fit: BoxFit.scaleDown, child: Text(w, maxLines: 1, style: KdText.body(9.5, height: 1.15))),
            ]),
            Positioned(top: -13, left: 3, child: Text('${i + 1}', style: KdText.body(10, color: KdColors.muted, height: 1))),
            if (got)
              Positioned.fill(
                child: Center(
                  child: Text('✔', style: TextStyle(fontSize: 22, color: KdColors.good, height: 1, shadows: const [Shadow(blurRadius: 2, offset: Offset(0, 1))])),
                ),
              ),
          ]),
        ),
      );
    }

    Widget line(int from) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = from; i < from + 7; i++) ...[
              if (i > from) const SizedBox(width: 4),
              Expanded(child: i < n ? cell(i) : const SizedBox()),
            ],
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < n; r += 7) ...[if (r > 0) const SizedBox(height: 4), line(r)],
      const SizedBox(height: 8),
      _small([
        TextSpan(text: '${e.n} 기간(${kstDate(d.start)}~${kstDate(d.end - 1)}) 중 하루 1칸 · $n칸을 채우면 끝 · '),
        TextSpan(text: '$n칸째 ${comps[e.comp]?.n ?? ''} 카드 10장', style: const TextStyle(fontWeight: FontWeight.w700, color: KdColors.fg)),
      ]),
      const SizedBox(height: 8),
      KdBuy(
        key: const ValueKey('evAtt'),
        kind: BuyKind.claim,
        minWidth: 0,
        text: back
            ? '휴대폰 시간을 확인해 주세요'
            : cnt >= n
                ? '$n칸 모두 받았어요'
                : can
                    ? '${cnt + 1}번째 출석 받기'
                    : '오늘은 받았어요 · 내일 또 만나요',
        onTap: can ? _attClaim : null,
      ),
    ]);
  }

  // ── 눈사람 대장 (웹 evBossHtml) ──
  Widget _boss(EventDef e, Map<String, dynamic> x, bool back) {
    final c = g.calc, b = e.boss!, left = c.evTriesLeft(e), xm = c.evXmas(e), bs = x['boss'] as Map, st = asNum(bs['st']).toInt();
    final mile = asMap(bs['mile']) ?? const <String, dynamic>{}, ad = truthy(bs['ad']);
    int? nxtM;
    for (var s = st; s < st + 10; s++) {
      if (b.mile(s) != null && !truthy(mile['$s'])) {
        nxtM = s;
        break;
      }
    }
    final spr = (xm ? b.sprX : b.spr)['id'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A3C63), Color(0xFF1F2B48)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0xFF3B5385)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          // 걷기 시트 첫 칸의 몸통 부분 (웹 .evbossimg: 640×160 으로 줄여 -38,-72)
          SizedBox(
            width: 84,
            height: 84,
            child: ClipRect(
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                Positioned(left: -38, top: -72, width: 640, height: 160, child: kdImg('assets/game/monsters/${spr}_walk.png', fit: BoxFit.fill)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${xm ? '🎅 산타 ' : ''}${b.n} · $st단계', style: KdText.body(14, color: const Color(0xFFE9F7FF), weight: FontWeight.w700)),
              _small([
                const TextSpan(text: '오늘 남은 도전 '),
                TextSpan(text: '$left/${c.evTries(e, x)}', style: _bGold),
                const TextSpan(text: ' · 최고 '),
                TextSpan(text: '${asNum(bs['best']).toInt()}단계', style: _bGold),
              ]),
              _small([
                TextSpan(text: '이기면 ${e.curN} '),
                TextSpan(text: _n(b.win(st) * (xm ? b.santaX : 1)), style: _bGold),
                TextSpan(text: '${xm ? ' (산타 2배)' : ''} · 져도 ${b.lose}'),
              ]),
              if (nxtM != null) _small([TextSpan(text: '$nxtM단계 첫 돌파: ${b.mile(nxtM)!.map((r) => evRwTxt(e, r)).join(' · ')}')]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      KdNote('${_n(b.lim)}초 안에 쓰러뜨리면 다음 단계로 · 기술 「${b.sk.n}」: ${_n(b.sk.every)}초마다 앞줄 동료에게 큰 피해 + ${_n(b.sk.slow)}초 느려짐 (경고가 뜨면 막기·보호막 스킬!) · 배경 하른 설원'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: KdBuy(
            key: const ValueKey('evBoss'),
            minWidth: 0,
            text: back
                ? '휴대폰 시간을 확인해 주세요'
                : left > 0
                    ? '도전하기'
                    : '오늘 도전 끝 · 내일 다시',
            onTap: left > 0 && !back ? () => g.chainSheet(widget.sheet, () => g.evBossGo(id)) : null,
          ),
        ),
        if (!ad && !back) ...[
          const SizedBox(width: 6),
          KdBuy(kind: BuyKind.ad, minWidth: 0, text: '▶ 광고 보고 +1', onTap: () => g.chainSheet(widget.sheet, () => g.evAdWatch(id, 'boss'))),
        ],
      ]),
    ]);
  }

  // ── 상점 (웹 evShopHtml) ──
  Widget _shop(EventDef e, Map<String, dynamic> x) {
    final c = g.calc, sf = asNum(x['sf']);
    var all = 0;
    for (final it in e.shop) {
      all += it.p * it.lim;
    }
    Widget row(EvShopItem it) {
      final left = c.evShopLeft(e, it), own = c.evShopOwned(it);
      Map<String, dynamic>? sob;
      for (final r in it.r) {
        if (r['k'] == 'evcard') sob = r;
      }
      final sid = sob?['id'] as String?;
      final lc = it.r.any((r) => r['k'] == 'lcard') && !g.acts.lcardCan();
      final mx = sid != null && c.recStar(sid) >= c.starMax(sid);
      final ok = left > 0 && !own && !lc && !mx && sf >= it.p;
      final nm = sid != null ? '${comps[sid]?.n ?? sid} 카드 ${_n(asNum(sob!['n']))}장' : it.r.map((r) => evRwTxt(e, r)).join(' · ');
      final jl = sid != null ? c.evJoinLeft(sid) : 0;
      final sub = <InlineSpan>[
        if (sid != null && jl > 0) ...[
          const TextSpan(text: '합류까지 '),
          TextSpan(text: '$jl장', style: _bGold),
          TextSpan(text: ' · ${GameCalc.gr(sid).n} 광부 · 일반 카드 뽑기에 안 나와요 · '),
        ] else if (sid != null)
          TextSpan(text: mx ? '별을 모두 모았어요 · ' : '합류했어요 · ★ 올리기 카드 · ')
        else if (own)
          const TextSpan(text: '이미 가지고 있어요 · ')
        else if (lc)
          const TextSpan(text: '전설 동료 카드가 나오기 시작하면 살 수 있어요 · '),
        TextSpan(text: '남은 ${math.max(0, left)}/${it.lim}'),
      ];
      return Opacity(
        opacity: left <= 0 || own ? .55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: it.hot ? null : KdColors.panel2,
            gradient: it.hot ? const LinearGradient(colors: [Color(0xFF3D3320), Color(0xFF29334F)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            border: Border.all(color: it.hot ? const Color(0xFFFFD34A) : KdColors.line, width: it.hot ? 1.5 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            evRwIcon(e, it.r.first, 34),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(nm, style: KdText.body(13.5, weight: FontWeight.w700)),
                _small(sub, size: 11.5),
              ]),
            ),
            const SizedBox(width: 6),
            KdBuy(
              key: ValueKey('evbuy-${it.k}'),
              kind: ok ? BuyKind.gold : BuyKind.ghost,
              small: true,
              minWidth: 70,
              costIcon: e.curImg,
              cost: it.p,
              onTap: left > 0 && !own ? () => _buy(it.k) : null,
            ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < e.shop.length; i++) ...[if (i > 0) const SizedBox(height: 6), row(e.shop[i])],
      const SizedBox(height: 6),
      KdNote('전부 사면 ${fmt(all)} · 매일 오면 ${comps[e.comp]?.n ?? ''}·테두리·배지는 확실히 받을 수 있어요. 다음 겨울에도 같은 상점이 다시 열려요'),
    ]);
  }

  // ── 선물 배달 (웹 evMgHtml) ──
  Widget _mg(EventDef e, Map<String, dynamic> x, bool back) {
    final c = g.calc, m = mgEvs[e.mg];
    if (m == null) return const SizedBox.shrink();
    final on = c.evMgOn(e), left = c.evMgLeft(e), gm = x['mg'] as Map, ad = truthy(gm['ad']);
    final settle = evT(m.settle) ?? 0, settled = c.evNow >= settle;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1C2650), Color(0xFF131A38)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0xFF3B5385)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          kdImg('assets/game/mini/sled.png', w: 96, h: 64, fit: BoxFit.cover, align: Alignment.topLeft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('🎁 선물 배달', style: KdText.body(14, weight: FontWeight.w700)),
              _small(on
                  ? [
                      const TextSpan(text: '오늘 남은 판 '),
                      TextSpan(text: '$left/${m.daily + (ad ? m.ad : 0)}', style: _bGold),
                      const TextSpan(text: ' · 연습판은 무제한'),
                    ]
                  : [TextSpan(text: settled ? '랭킹 정산이 끝났어요 · 보상은 우편함으로' : '크리스마스 주간에 열려요')]),
              _small([const TextSpan(text: '내 최고 '), TextSpan(text: '${fmt(asNum(gm['best']))}점', style: _bGold)]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      _small([
        const TextSpan(text: '30초 동안 화면을 눌러 굴뚝에 선물을 넣어요. 굴뚝 10점 × 연속 배수(5번마다 +1배, 최대 5배) · 한가운데 +5 · '),
        const TextSpan(text: '황금 굴뚝', style: _bGold),
        TextSpan(text: ' 30점 · 연기 나는 굴뚝은 연속이 끊겨요. 판마다 ${e.curN} 점수÷10 (최대 100)'),
      ]),
      if (on) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 3,
            child: KdBuy(
              key: const ValueKey('evMgGo'),
              minWidth: 0,
              text: back
                  ? '휴대폰 시간을 확인해 주세요'
                  : left > 0
                      ? '시작'
                      : '오늘 판 끝',
              onTap: left > 0 && !back ? () => g.chainSheet(widget.sheet, () => g.evMgStart(id, false)) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '연습', onTap: () => g.chainSheet(widget.sheet, () => g.evMgStart(id, true)))),
          if (!ad && !back) ...[
            const SizedBox(width: 6),
            Expanded(flex: 3, child: KdBuy(kind: BuyKind.ad, minWidth: 0, text: '▶ 광고 +1판', onTap: () => g.chainSheet(widget.sheet, () => g.evAdWatch(id, 'mg')))),
          ],
        ]),
      ],
      const SizedBox(height: 8),
      KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '🏆 선물 배달 랭킹', onTap: () => g.chainSheet(widget.sheet, () => openRanking(g, 'mg'))),
      const SizedBox(height: 6),
      // 랭킹 보상 (웹 <details class="evrw">)
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _rwOpen = !_rwOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${_rwOpen ? '▾' : '▸'} 랭킹 보상 (${kstDate(settle - 1)} 하루 끝에 정산 → 우편)', style: KdText.body(12.5)),
        ),
      ),
      if (_rwOpen) ...[
        for (final (a, b) in m.rew) Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: KdKv(a, b)),
        const KdNote('크리스마스 주간 동안 보상 판 한 판 최고 점수로 순위를 정해요 (같은 점수면 먼저 낸 사람)'),
      ],
    ]);
  }
}

// ════════════════════ 결과·선물 창 (controller_event 가 띄움) ════════════════════
/// 눈사람 대장 결과 (웹 evBossEnd)
Widget evBossResultBody(GameController g, BuildContext c, {required String id, required bool won, required int stg, required bool santa, required int sf, required List<EvRow> rows}) {
  final e = evts[id]!, b = e.boss!, left = g.calc.evTriesLeft(e), best = asNum((g.calc.evS(id)['boss'] as Map)['best']).toInt();
  return KdSheetBody(
    eyebrow: '${e.n} · ${santa ? '산타 ' : ''}${b.n}',
    title: won ? '$stg단계 돌파!' : '$stg단계 실패',
    children: [
      Text('「${won ? b.sayWin : b.sayLose}」', textAlign: TextAlign.center, style: KdText.body(15, color: const Color(0xFFCFE8FF), weight: FontWeight.w600)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        kdImg(e.curImg, w: 36, h: 36),
        const SizedBox(width: 6),
        Text('+$sf', style: KdText.display(26, color: const Color(0xFFE9F7FF))),
        const SizedBox(width: 6),
        Flexible(child: Text('${e.curN}${won && santa ? ' (산타 2배)' : won ? '' : ' (져도 받아요)'}', style: KdText.body(12, color: KdColors.muted))),
      ]),
      if (rows.isNotEmpty) ...[
        Text('$stg단계 첫 돌파 보상', textAlign: TextAlign.center, style: KdText.body(12, color: const Color(0xFFFFD34A), height: 1.6)),
        EvRowsView(rows),
      ],
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${won ? '다음 ${stg + 1}단계' : '원정대를 키워서 다시 와요'} · 오늘 남은 도전 '),
          TextSpan(text: '$left', style: const TextStyle(fontWeight: FontWeight.w700, color: KdColors.fg)),
          TextSpan(text: '번 · 최고 $best단계'),
        ]),
        textAlign: TextAlign.center,
        style: KdText.body(12, color: KdColors.muted, height: 1.6),
      ),
    ],
    acts: KdActs(buttons: [
      KdAct('이벤트 창', onTap: () => g.chainSheet(c, () => openEventSheet(g, id, 'boss'))),
      KdAct(left > 0 ? '다시 도전' : '확인', primary: true, onTap: () {
        if (left > 0) {
          g.chainSheet(c, () => g.evBossGo(id));
        } else {
          Navigator.of(c).pop();
        }
      }),
    ]),
  );
}

/// 산타 피트의 선물 (웹 evGiftSheet)
Widget evGiftBody(GameController g, BuildContext c, EventDef e, bool big, List<EvRow> rows) => KdSheetBody(
      children: [
        Row(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A20),
              border: Border.all(color: const Color(0xFFD93A4A), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: kdImg('assets/game/portraits/portrait_pete_santa_${big ? 'laugh' : 'idle'}.png', fit: BoxFit.cover)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('크리스마스 주간 · ${kstDate(g.calc.evNow)}', style: KdText.body(12, color: KdColors.gold).copyWith(letterSpacing: 2.4)),
              Text(big ? '산타 피트의 큰 선물!' : '산타 피트의 선물', style: KdText.display(20)),
            ]),
          ),
        ]),
        if (big) for (final p in e.line('big')) Para(p),
        EvRowsView(rows),
        KdNote('${big ? '메리 크리스마스!' : '크리스마스(25일)에는 큰 선물이 있어요'} · 5일 중 3일 접속하면 배지 「메리 크리스마스」', center: true),
      ],
      acts: KdActs(buttons: [KdAct('받기', primary: true, claim: true, onTap: () => Navigator.of(c).pop())]),
    );

/// 마을 광장 트리 선물 (웹 evTreeHit)
Widget evTreeBody(BuildContext c, List<EvRow> rows) => KdSheetBody(
      eyebrow: '마을 광장',
      title: '🎄 트리 아래 선물',
      children: [
        EvRowsView(rows),
        const KdNote('크리스마스 주간에는 하루 1번 선물이 생겨요', center: true),
      ],
      acts: KdActs(buttons: [KdAct('받기', primary: true, claim: true, onTap: () => Navigator.of(c).pop())]),
    );
