/// 문의하기 (웹 inqSheet · inqMineSheet) — 종류·내용·사진 1장을 서버에 보내고, 답은 우편함으로 받음.
/// 서버: supabase/stage8_inquiry.sql · 대표님 관리 페이지: admin.html
library;

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_info.dart';
import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'settings_sheet.dart';

/// 문의 종류 (웹 INQK): id · 이름 · 내용 칸 안내 글
const inqKinds = [
  ('pay', '결제', '언제, 어떤 상품을 샀는지 적어 주세요. 예) 오늘 오후 3시쯤 황금 이삭 330개를 샀는데 들어오지 않았어요'),
  ('bug', '버그', '어디서 무엇을 했을 때 어떤 일이 생겼는지 적어 주세요. 화면 사진을 붙이면 더 빨리 찾을 수 있어요'),
  ('account', '계정', '어떤 계정(구글·애플·게스트)으로 하던 중이었는지, 무엇이 안 되는지 적어 주세요'),
  ('etc', '기타', '하고 싶은 말을 자유롭게 적어 주세요'),
];

String inqKindName(Object? k) => inqKinds.firstWhere((x) => x.$1 == k, orElse: () => inqKinds.last).$2;

const inqStatus = {'new': '답변 기다리는 중', 'answered': '답변 완료', 'closed': '처리 완료'};

const inqErr = {
  'short': '내용을 5자 이상 적어 주세요',
  'long': '내용은 1000자까지 쓸 수 있어요',
  'limit': '문의는 하루 3번까지 보낼 수 있어요. 내일 다시 보내 주세요',
  'auth': '연결에 실패했어요. 잠시 후 다시 해 주세요',
  'bad': '보내지 못했어요. 잠시 후 다시 해 주세요',
  'net': '인터넷 연결이 필요해요',
};

/// 창을 닫았다 열어도 쓰던 글·사진이 남도록 (웹 inqDraft)
class _Draft {
  String kind = 'bug';
  String body = '';
  Uint8List? photo;
}

final _draft = _Draft();

String _date(Object? t) {
  final d = DateTime.tryParse('$t')?.toLocal();
  if (d == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.month}월 ${d.day}일 ${p(d.hour)}:${p(d.minute)}';
}

String get _platform => Platform.isIOS
    ? 'ios'
    : Platform.isAndroid
        ? 'android'
        : Platform.operatingSystem;

void openInquiry(GameController g) => g.openSheet<void>((c) => _Inquiry(g, c));

void openInquiryMine(GameController g) => g.openSheet<void>((c) => _Mine(g, c));

class _Inquiry extends StatefulWidget {
  const _Inquiry(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_Inquiry> createState() => _InquiryState();
}

class _InquiryState extends State<_Inquiry> {
  late final _body = TextEditingController(text: _draft.body);
  bool _busy = false;

  /// 보낸 뒤: null 이면 아직 · false 사진까지 · true 사진은 못 올림
  bool? _sentPhotoFail;

  GameController get g => widget.g;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 82);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (b.length > 3 * 1024 * 1024) return g.toast('사진이 너무 커요');
      setState(() => _draft.photo = b);
    } catch (_) {
      g.toast('사진을 열 수 없어요');
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    final body = _body.text.trim();
    if (body.length < 5) return g.toast(inqErr['short']!);
    if (!g.online.on) return g.toast('지금은 문의를 보낼 수 없어요');
    setState(() => _busy = true);
    final (r, photoFail) = await g.online.inqSend(
      kind: _draft.kind,
      body: body,
      photo: _draft.photo,
      ver: appVersion,
      device: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      platform: _platform,
    );
    if (!mounted) return;
    if (r != 'ok') {
      setState(() => _busy = false);
      return g.toast(inqErr[r] ?? inqErr['bad']!);
    }
    _draft
      ..kind = 'bug'
      ..body = ''
      ..photo = null;
    g.haptic(const [20]);
    setState(() {
      _busy = false;
      _sentPhotoFail = photoFail;
    });
  }

  Widget _kinds() => Row(children: [
        for (final (k, n, _) in inqKinds) ...[
          if (k != 'pay') const SizedBox(width: 6),
          Expanded(
            child: Pressable(
              onTap: () => setState(() => _draft.kind = k),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _draft.kind == k ? KdColors.gold : KdColors.panel2,
                  border: Border.all(color: _draft.kind == k ? KdColors.gold : KdColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(n, style: KdText.body(14, color: _draft.kind == k ? const Color(0xFF1A1206) : KdColors.muted, weight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ]);

  @override
  Widget build(BuildContext context) {
    if (_sentPhotoFail != null) {
      return KdSheetBody(
        eyebrow: '카엘의 수첩',
        title: '문의를 보냈어요 ✉️',
        children: [
          const KdNote('답이 오면 우편함에 도착해요. 「내 문의」에서 진행 상황을 볼 수 있어요.', center: true),
          if (_sentPhotoFail!)
            Text('사진은 올리지 못해 내용만 보냈어요.', textAlign: TextAlign.center, style: KdText.body(12.5, color: const Color(0xFFFFB3BD))),
        ],
        acts: KdActs(buttons: [
          KdAct('내 문의 보기', onTap: () => g.chainSheet(widget.sheet, () => openInquiryMine(g))),
          KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop()),
        ]),
      );
    }
    final hint = inqKinds.firstWhere((x) => x.$1 == _draft.kind).$3;
    final photo = _draft.photo;
    return KdSheetBody(
      eyebrow: '카엘의 수첩',
      title: '문의하기',
      children: [
        const KdNote('불편한 점을 알려 주세요. 답은 우편함으로 보내 드려요(보통 1~3일).'),
        const KdSec('종류'),
        _kinds(),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _body,
          builder: (_, v, __) => KdSec('내용', small: '${v.text.length}/1000'),
        ),
        TextField(
          controller: _body,
          minLines: 5,
          maxLines: 8,
          maxLength: 1000,
          onChanged: (t) => _draft.body = t,
          style: KdText.body(14),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF0B0F1A),
            hintText: hint,
            hintMaxLines: 4,
            hintStyle: KdText.body(13, color: KdColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
          ),
        ),
        const KdSec('사진', small: '선택 · 1장'),
        if (photo != null)
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(photo, width: 72, height: 72, fit: BoxFit.cover)),
            const SizedBox(width: 10),
            KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '사진 빼기', onTap: () => setState(() => _draft.photo = null)),
          ])
        else
          Row(children: [KdBuy(kind: BuyKind.ghost, minWidth: 0, text: '📷 사진 붙이기', onTap: _pick)]),
        const KdNote('함께 보내는 정보: 닉네임 · 계정 번호 · 게임 버전 · 기기 정보. 보내면 이 정보와 내용·사진을 문의 답변에만 쓰는 데 동의하는 것으로 봐요 (개인정보처리방침: gogeangs.github.io/kingday/privacy.html).'),
      ],
      acts: KdActs(buttons: [
        KdAct('돌아가기', onTap: _busy ? null : () => g.chainSheet(widget.sheet, () => openSettings(g))),
        KdAct(_busy ? '보내는 중…' : '보내기', primary: true, onTap: _busy ? null : _send),
      ]),
    );
  }
}

class _Mine extends StatefulWidget {
  const _Mine(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_Mine> createState() => _MineState();
}

class _MineState extends State<_Mine> {
  bool _loading = true;
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    widget.g.online.inqMine().then((l) {
      if (mounted) {
        setState(() {
          _list = l;
          _loading = false;
        });
      }
    });
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: const Color(0x4D000000), borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: KdText.body(12, color: c)),
      );

  Widget _item(Map<String, dynamic> q) {
    final st = '${q['status']}';
    final ans = q['answer'] is String && (q['answer'] as String).isNotEmpty ? q['answer'] as String : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40FFC94A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _pill(inqKindName(q['kind']), KdColors.fg),
          const SizedBox(width: 6),
          _pill(inqStatus[st] ?? st, st == 'new' ? KdColors.gold : st == 'answered' ? const Color(0xFF8FE3A2) : KdColors.muted),
          const Spacer(),
          Text(_date(q['created_at']), style: KdText.body(12, color: KdColors.muted)),
        ]),
        const SizedBox(height: 5),
        SelectableText('${q['body'] ?? ''}', style: KdText.body(13.5)),
        if (q['has_photo'] == true) Text('📷 사진 1장', style: KdText.body(12, color: KdColors.muted)),
        if (ans != null) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x148FE3A2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x4D8FE3A2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('답변 · ${_date(q['answered_at'])}', style: KdText.body(12, color: const Color(0xFF8FE3A2), weight: FontWeight.w600)),
              SelectableText(ans, style: KdText.body(13.5)),
            ]),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, l = _list;
    return KdSheetBody(
      eyebrow: '카엘의 수첩',
      title: '내 문의',
      children: [
        if (_loading)
          const KdNote('문의를 불러오는 중…', center: true)
        else if (l == null)
          const KdNote('인터넷에 연결되면 문의를 볼 수 있어요.', center: true)
        else if (l.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: KdNote('아직 보낸 문의가 없어요.', center: true))
        else ...[
          const KdNote('답변은 우편함으로도 보내 드려요.', center: true),
          for (final q in l) _item(q),
        ],
      ],
      acts: KdActs(buttons: [
        KdAct('새 문의', onTap: () => g.chainSheet(widget.sheet, () => openInquiry(g))),
        KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop()),
      ]),
    );
  }
}
