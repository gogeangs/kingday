/// 카엘의 수첩 (웹 settingsSheet) — 계정·저장 코드 옮기기·진동·처음부터 다시 하기
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/save_code.dart';
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
  final _code = TextEditingController();
  bool _reset = false;

  GameController get g => widget.g;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    await g.save();
    final c = exportSaveCode(g.state);
    _code.text = c;
    _code.selection = TextSelection(baseOffset: 0, extentOffset: c.length);
    try {
      await Clipboard.setData(ClipboardData(text: c));
      g.toast('저장 코드를 복사했어요');
    } catch (_) {
      g.toast('코드를 길게 눌러 복사하세요');
    }
  }

  Future<void> _import() async {
    final d = importSaveCode(_code.text);
    if (d == null) return g.toast('저장 코드가 올바르지 않아요');
    Navigator.of(widget.sheetCtx).pop();
    await g.loadFromCode(d);
  }

  @override
  Widget build(BuildContext context) {
    final vibOff = g.state.raw['vib'] == false;
    return KdSheetBody(
      titleWidget: const HdBanner('hd_settings', '카엘의 수첩'),
      children: [
        const KdSec('계정', small: '클라우드 저장'),
        AccountBox(g),
        const KdSec('저장 데이터 옮기기', small: '코드로 직접'),
        const KdNote('저장은 이 휴대폰에만 돼요. 아래 코드를 복사해 두면 다른 곳(웹 포함)에서 불러올 수 있어요.'),
        TextField(
          controller: _code,
          minLines: 3,
          maxLines: 3,
          autocorrect: false,
          enableSuggestions: false,
          style: KdText.figure(11, weight: FontWeight.w400),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF141A2C),
            hintText: '여기에 저장 코드를 붙여 넣고 불러오기를 누르세요',
            hintStyle: KdText.body(12, color: KdColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
          ),
        ),
        Row(children: [
          Expanded(child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '코드 만들기·복사', onTap: _export)),
          const SizedBox(width: 8),
          Expanded(child: KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '불러오기', onTap: _import)),
        ]),
        const KdSec('진동', small: '보상·보스 처치 때 (아이폰은 짧은 진동)'),
        Row(children: [
          Expanded(
            child: KdBuy(
              kind: BuyKind.ghost,
              minWidth: 0,
              text: vibOff ? '진동 켜기' : '진동 끄기',
              onTap: () {
                g.state.raw['vib'] = vibOff;
                g.save();
                if (vibOff) g.haptic(const [30]);
                g.toast(vibOff ? '진동을 켰어요' : '진동을 껐어요');
                setState(() {});
              },
            ),
          ),
        ]),
        const KdSec('효과음', small: '버튼·보상·전투 소리'),
        Row(children: [
          Expanded(
            child: KdBuy(
              kind: BuyKind.ghost,
              minWidth: 0,
              text: g.state.raw['snd'] == false ? '효과음 켜기' : '효과음 끄기',
              onTap: () {
                final on = g.state.raw['snd'] == false;
                g.state.raw['snd'] = on;
                g.save();
                if (on) g.sound('gem');
                g.toast(on ? '효과음을 켰어요' : '효과음을 껐어요');
                setState(() {});
              },
            ),
          ),
        ]),
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
      acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheetCtx).pop())]),
    );
  }
}
