/// 카엘의 수첩 (웹 settingsSheet) — 계정·진동·효과음·문의·처음부터 다시 하기
/// (2026-10-27 대표님: 앱은 「저장 코드 옮기기」 빼고 계정 연결로만 · 아래 「닫기」 없이 ✕ 로)
library;

import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'inquiry_sheet.dart';
import 'social_sheets.dart';

/// 웹 .hdban: 금테 머리 그림 위에 글자
class HdBanner extends StatelessWidget {
  const HdBanner(this.img, this.text, {super.key, this.size = 20, this.padTop = .01, this.padBottom = 0});
  final String img, text;

  /// 글자 크기 (웹 --hs), 글자 위 여백 비율 (웹 --hp), 글자 아래 여백 비율 (웹 --hpb — 판이 위쪽에 있는 그림)
  final double size, padTop, padBottom;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: AspectRatio(
            aspectRatio: 720 / 225,
            child: Stack(fit: StackFit.expand, children: [
              kdImg('assets/game/ui/$img.png', fit: BoxFit.contain),
              Padding(
                padding: EdgeInsets.only(top: 330 * padTop, bottom: 330 * padBottom),
                child: Center(
                  child: Text(text,
                    style: KdText.display(size, color: const Color(0xFFFFE7A6))
                        .copyWith(letterSpacing: .8, shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 3)])),
                ),
              ),
            ]),
          ),
        ),
      );
}

void openSettings(GameController g) => g.openSheet<void>((c) => _Settings(g, c));

class _Settings extends StatefulWidget {
  const _Settings(this.g, this.sheetCtx);
  final GameController g;
  final BuildContext sheetCtx;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool _reset = false;

  GameController get g => widget.g;

  /// 켬/끔 한 줄: 왼쪽 이름·설명, 오른쪽 스위치 + 「켜짐」/「꺼짐」 (대표님 제보 10-27 — 「진동 켜기」가 상태인지 할 일인지 헷갈림)
  Widget _toggle(String k, String name, String sub, bool on, ValueChanged<bool> set) => GestureDetector(
        key: ValueKey('set-$k'),
        behavior: HitTestBehavior.opaque,
        onTap: () => set(!on),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: KdText.body(14, weight: FontWeight.w700)),
                Text(sub, style: KdText.body(11.5, color: KdColors.muted)),
              ]),
            ),
            Text(on ? '켜짐' : '꺼짐', style: KdText.body(12.5, weight: FontWeight.w700, color: on ? const Color(0xFF9BE3A8) : KdColors.muted)),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF2F8F55) : const Color(0xFF3A4256),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vibOff = g.state.raw['vib'] == false;
    return KdSheetBody(
      titleWidget: const HdBanner('hd_settings', '카엘의 수첩'),
      children: [
        const KdSec('계정', small: '클라우드 저장'),
        AccountBox(g),
        const KdSec('소리·진동'),
        _toggle('vib', '진동', '보상·보스 처치 때 (아이폰은 짧은 진동)', !vibOff, (on) {
          g.state.raw['vib'] = on;
          g.save();
          if (on) g.haptic(const [30]);
          setState(() {});
        }),
        _toggle('snd', '효과음', '버튼·보상·전투 소리', g.state.raw['snd'] != false, (on) {
          g.state.raw['snd'] = on;
          g.save();
          if (on) g.sound('gem');
          setState(() {});
        }),
        const KdSec('문의', small: '결제·버그·계정 · 답은 우편함으로'),
        Row(children: [
          Expanded(child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '문의하기', onTap: () => g.chainSheet(widget.sheetCtx, () => openInquiry(g)))),
          const SizedBox(width: 8),
          Expanded(child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '내 문의', onTap: () => g.chainSheet(widget.sheetCtx, () => openInquiryMine(g)))),
        ]),
        const KdSec('처음부터 다시 하기'),
        if (_reset) ...[
          Text('정말 지울까요? 영지, 장비, 동료, 마을, 황금 이삭, 구매 기록이 모두 사라지고 되돌릴 수 없어요.',
              style: KdText.body(12.5, color: const Color(0xFFFFB3BD))),
          Row(children: [
            Expanded(child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '취소', onTap: () => setState(() => _reset = false))),
            const SizedBox(width: 8),
            Expanded(
              child: KdBuy(
                kind: BuyKind.danger,
                minWidth: 0,
                text: '모두 지우기',
                onTap: () {
                  Navigator.of(widget.sheetCtx).pop();
                  g.resetAll();
                },
              ),
            ),
          ]),
        ] else
          Row(children: [Expanded(child: KdBuy(kind: BuyKind.danger, minWidth: 0, text: '게임 초기화', onTap: () => setState(() => _reset = true)))]),
      ],
    );
  }
}
