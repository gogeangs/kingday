/// 출석체크 「피트의 출석부」 창 — 웹 attOpen()/attSheet() 자리.
/// 규칙은 core/attendance.dart (웹 attDo·attAdDo 와 같음), 기획은 docs/content/ATTENDANCE.md
library;

import 'package:flutter/material.dart';

import '../core/attendance.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_sheet.dart';

/// 1-3 에 닿은 뒤부터 출석부가 열림
bool attEligible(GameController g) => g.state.best >= 3;

/// 오늘 아직 출석 안 했으면 상단 바 달력 아이콘에 노란 점
bool attDot(GameController g) => attEligible(g) && g.acts.attStatusAt(g.calc.today()) == 'ok';

/// 상단 바 아이콘·자동으로 열 때: 처음 한 번은 피트 소개 장면
void openAttend(GameController g, {bool queued = false}) {
  final a = g.acts.attA();
  // 처음 한 번 피트 대사는 따로 창을 띄우지 않고 출석부 위에 (웹 attIntroNow, UX 점검 4)
  final intro = orNum(a['intro'], 0) == 0;
  if (intro) {
    a['intro'] = 1;
    g.save();
  }
  if (queued) {
    g.queue((ctx) => showKdSheet<void>(ctx, builder: (c) => AttendSheet(g, c, intro: intro)));
  } else {
    g.openSheet<void>((c) => AttendSheet(g, c, intro: intro));
  }
}

/// 마지막으로 본 탭 (S.att.tab, 웹과 같은 저장)
class AttendSheet extends StatefulWidget {
  const AttendSheet(this.g, this.sheet, {super.key, this.just, this.adRows, this.intro = false});
  final GameController g;
  final BuildContext sheet;

  /// 처음 연 날: 피트 소개 대사를 맨 위에
  final bool intro;

  /// 방금 받은 결과 (도장 애니메이션·대사), 광고로 한 번 더 받은 줄
  final AttResult? just;
  final List<AttRow>? adRows;

  @override
  State<AttendSheet> createState() => _AttendSheetState();
}

class _AttendSheetState extends State<AttendSheet> {
  GameController get g => widget.g;
  AttResult? just;
  List<AttRow>? adRows;

  @override
  void initState() {
    super.initState();
    just = widget.just;
    adRows = widget.adRows;
  }

  static Widget _icon(String k, double size) {
    final p = switch (k) {
      'gold' => 'assets/game/ui/ui_gold.png',
      'gem' => 'assets/game/gem/ui_gem.png',
      'ore' => 'assets/game/ui/item_ore.png',
      'seed' => 'assets/game/ui/seed_wheat.png',
      'tbox' => 'assets/game/ui/item_boxticket.png',
      'tbox10' => 'assets/game/ui/item_box10ticket.png',
      'card' || 'ecard' => 'assets/game/ui/card_back.png',
      _ => 'assets/game/profile/badge_att.png',
    };
    return kdImg(p, w: size, h: size);
  }

  Widget _stamp(double size, bool fresh) {
    final img = Transform.rotate(angle: -.21, child: Opacity(opacity: .85, child: kdImg('assets/game/ui/att_stamp.png', w: size, h: size)));
    if (!fresh) return img;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 2.4, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: (3.4 - v).clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: child)),
      child: img,
    );
  }

  Widget _cell({required String top, required Map r, required String label, bool big = false, bool now = false, bool got = false, bool fresh = false, double icon = 30, bool small = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: big ? const LinearGradient(colors: [Color(0xFF3A2C0C), Color(0xFF241A07)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
        color: big ? null : KdColors.panel2,
        border: Border.all(color: now ? const Color(0xFFFFD23A) : big ? KdColors.gold : KdColors.line, width: now || (big && small) ? 2 : 1),
        borderRadius: BorderRadius.circular(small ? 7 : 10),
        boxShadow: now ? const [BoxShadow(color: Color(0x99FFD23A), blurRadius: 10)] : null,
      ),
      child: Stack(alignment: Alignment.center, children: [
        Opacity(
          opacity: got ? .45 : 1,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: small ? 2 : 5, horizontal: 2),
            // 한달 판 칸은 작아서 내용이 넘치지 않게 줄여 맞춤
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Text(top, style: KdText.body(small ? 9 : 10, color: KdColors.muted, weight: FontWeight.w700)),
                _icon(r['k'] as String, icon),
                if (!small) Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(10.5, weight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        if (got) Positioned.fill(child: Center(child: _stamp(small ? icon * 1.3 : 46, fresh))),
      ]),
    );
  }

  Widget _row(AttRow r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          r.badge != null ? kdImg(attBadgeAsset(r.badge!), w: 24, h: 24) : _icon(r.kind, 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.text, style: KdText.body(13, weight: FontWeight.w700)),
              if (r.sub.isNotEmpty) Text(r.sub, style: KdText.body(11, color: KdColors.muted)),
            ]),
          ),
          if (r.again) Text('2배', style: KdText.body(11, color: KdColors.gold, weight: FontWeight.w800)),
        ]),
      );

  void _claim() {
    final r = g.act((a) => a.attDo(g.calc.today()));
    if (r == 'done') return g.toast('오늘은 이미 받았어요. 내일 자정에 또 만나요');
    if (r == 'back') return g.toast('날짜가 이상해요. 휴대폰 시간을 확인해 주세요.');
    final res = r as AttResult;
    g.haptic(const [30, 40, 70]);
    g.calc.pfCheck();
    g.save();
    g.refresh();
    g.toast('출석 완료! 7일 판 ${res.wd + 1}일째 · 이번 달 ${res.md}회째');
    setState(() {
      just = res;
      adRows = null;
    });
  }

  void _ad() {
    final t = g.calc.today();
    g.chainSheet(widget.sheet, () async {
      List<AttRow>? rows;
      await g.watchAd('att', () {
        rows = g.act((a) => a.attAdDo(t));
      });
      if (rows != null) {
        g.calc.pfCheck();
        g.save();
        g.toast('피트가 한 번 더 챙겨 줬어요');
      }
      g.openSheet<void>((c) => AttendSheet(g, c, adRows: rows));
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = g.acts.attA(), t = g.calc.today(), st = g.acts.attStatusAt(t), done = st == 'done';
    final tab = a['tab'] == 'm' ? 'm' : 'w', mc = g.acts.attMonthN(t), dim = attDim(t), mo = int.parse(t.split('-')[1]);
    final jw = just?.wd ?? -1, jm = just?.md ?? -1;
    Widget tabBtn(String k, String label) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              a['tab'] = k;
              g.save();
            }),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tab == k ? KdColors.gold : KdColors.panel2,
                border: Border.all(color: tab == k ? KdColors.gold : KdColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label, style: KdText.body(14, weight: FontWeight.w700, color: tab == k ? KdColors.goldInk : KdColors.muted)),
            ),
          ),
        );

    Widget board;
    if (tab == 'w') {
      final nx = orNum(a['w'], 0).toInt(), full = done && nx == 0;
      board = LayoutBuilder(builder: (_, cs) {
        final w = (cs.maxWidth - 18) / 4;
        Widget c(int i) {
          final rs = attWeek[i], got = full || i < nx, now = !done && i == nx;
          return SizedBox(
            width: i == 6 ? w * 2 + 6 : w,
            height: 86,
            child: _cell(top: '${i + 1}일', r: rs[0], label: rs.map(attShort).join(' + '), big: i == 6, now: now, got: got, fresh: i == jw, icon: i == 6 ? 40 : 30),
          );
        }

        return Wrap(spacing: 6, runSpacing: 6, children: [for (var i = 0; i < 7; i++) c(i)]);
      });
    } else {
      final nb = [7, 14, 21, 28].where((n) => n > mc).firstOrNull;
      board = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text('$mo월 · 이번 달 $mc회 출석', style: KdText.display(15))),
          Text.rich(
            nb != null
                ? TextSpan(children: [const TextSpan(text: '다음 큰 보상까지 '), TextSpan(text: '${nb - mc}회', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700))])
                : const TextSpan(text: '큰 보상을 모두 받았어요'),
            style: KdText.body(12, color: KdColors.muted),
          ),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (_, cs) {
          final w = (cs.maxWidth - 4 * 6) / 7;
          return Wrap(spacing: 4, runSpacing: 4, children: [
            for (var n = 1; n <= dim; n++)
              SizedBox(
                width: w,
                height: w,
                child: _cell(
                  top: '$n',
                  r: attMonth(n)[0],
                  label: '',
                  big: attBig.containsKey(n),
                  now: !done && n == mc + 1,
                  got: n <= mc,
                  fresh: n == jm,
                  icon: w * (attBig.containsKey(n) ? .5 : .42),
                  small: true,
                ),
              ),
          ]);
        }),
      ]);
    }

    final line = just == null
        ? null
        : just!.md == 28
            ? 'm:피트|이번 달 출석부를 다 채우셨네요! 이 배지는 아무나 못 받아요.'
            : just!.wd == 6
                ? 'm:피트|일주일 개근! 특별히 상자 10번 여는 표를 넣었어요.'
                : null;
    final rows = adRows ?? just?.rows ??
        (done
            ? [
                for (final r in (a['got'] as List).map((x) => asMap(x)!))
                  r['k'] == 'badge' ? AttRow('badge', '${attBadgeName(r['id'] as String)} 배지', '', false, r['id'] as String) : AttRow(r['k'] == 'ecard' ? 'card' : r['k'] as String, attName(r)),
              ]
            : null);
    final adOk = done && a['ad'] != t && g.calc.adLeft('att') > 0;

    return KdSheetBody(
      titleWidget: const HdBanner('hd_attend', '피트의 출석부'),
      children: [
        if (widget.intro) ...const [
          Para('m:피트|어서 와요, 영주님! 오늘부터 출석부를 만들었어요. 하루 한 번 얼굴만 보여 주시면 선물을 챙겨 드릴게요.'),
          Para('k@smile:얼굴만 보여 주면 된다고? 그건 은퇴하고도 할 수 있겠네.'),
        ],
        Row(children: [tabBtn('w', '7일'), const SizedBox(width: 6), tabBtn('m', '한달')]),
        board,
        KdNote(tab == 'w'
            ? '7칸을 다 채우면 1일부터 다시 시작해요. 빠진 날이 있어도 다음 칸으로 이어서 찍혀요.'
            : '큰 보상 · 7회 동료 카드 10장 · 14회 이삭 100 · 21회 영웅 이상 카드 10장 · 28회 이삭 100 + $mo월 출석 배지. 매달 1일에 새로 시작해요.'),
        if (st == 'back') const KdNote('날짜가 이상해요. 휴대폰 시간을 확인해 주세요.'),
        if (line != null) Para(line),
        if (rows != null && rows.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: const Color(0xFF10162A), border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(adRows != null ? '광고 보상 · 한 번 더' : '오늘 받은 선물', style: KdText.body(12, color: KdColors.muted, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final r in rows) _row(r),
            ]),
          ),
      ],
      // 받은 뒤에는 노란 버튼이 「닫기」, 광고는 보조 버튼 (웹 attSheet, UX 점검 6)
      acts: KdActs(buttons: done && st != 'back'
          ? [
              adOk ? KdAct('▶ 광고로 한 번 더', onTap: _ad) : const KdAct('내일 또 만나요'),
              KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop()),
            ]
          : [
              KdAct('닫기', onTap: () => Navigator.of(widget.sheet).pop()),
              st == 'back' ? const KdAct('날짜를 확인해 주세요', primary: true) : KdAct('출석하기', primary: true, onTap: _claim),
            ]),
    );
  }
}
