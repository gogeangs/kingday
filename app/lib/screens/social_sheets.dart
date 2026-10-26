/// 온라인·꾸미기 창 — 프로필(테두리·배지), 닉네임, 랭킹 3탭, 우편함, 시즌 결과, 카드 공개, 고블린 희귀 전리품, 계정 상자.
/// 웹 profileSheet · nickSheet · rankSheet · mailSheet · resultPop · cardReveal · gobRare · acctBox 자리.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/challenge.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../core/server.dart' show ServerError;
import '../game/controller.dart';
import '../game/login.dart';
import '../game/online.dart';
import '../ui/fx.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attend_sheet.dart';
import 'settings_sheet.dart';

// ════════════════════ 공통 ════════════════════

/// 얼굴 + 프로필 테두리 (웹 .face/.pfbig/.rkf). 큰 테두리(tall)는 위로 솟음
class FramedFace extends StatelessWidget {
  const FramedFace({super.key, required this.frame, required this.size, this.dim = false, this.portrait = false, this.face = true, this.faceId = 'kael', this.photo});
  final String frame;

  /// 얼굴 주인 (카엘·동료 id), [photo] 가 있으면 내 사진
  final String faceId;
  final Uint8List? photo;
  final double size;
  final bool dim;

  /// false 면 얼굴 없이 바탕만 (웹 프로필 테두리 고르기 칸 .pfc .pv i)
  final bool face;

  /// 랭킹처럼 초상화를 그대로 잘라 보여 줄 때 (웹 .rkf .pt)
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final tall = isTallFrame(frame);
    final inset = size * (portrait ? .12 : .11);
    final img = kdImg(frameAsset(frame), fit: BoxFit.fill);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: ClipRRect(
            borderRadius: BorderRadius.circular((size - inset * 2) * .16),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3B5A8A), Color(0xFF1A2440)])),
              child: !face
                  ? null
                  : photo != null
                      ? Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true)
                      : portrait
                          ? kdImg('assets/game/portraits/portrait_${faceId}_idle.png', fit: BoxFit.cover, align: const Alignment(0, -.8))
                          : FaceImg(faceId),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: tall ? -size * .15625 : 0,
          height: tall ? size * 1.15625 : size,
          child: dim ? filtered(img, gray: 1, bright: .65) : img,
        ),
      ]),
    );
  }
}

Widget _badgeImg(String k, double s) => kdImg(badgeAsset(k), w: s, h: s);

TextStyle _muted([double size = 13]) => KdText.body(size, color: KdColors.muted);

/// 화면 위 빨간 숫자 점 (웹 .mdot)
class CountDot extends StatelessWidget {
  const CountDot(this.n, {super.key});
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 17),
        height: 17,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: KdColors.bad, borderRadius: BorderRadius.circular(9)),
        child: Text(n > 9 ? '9+' : '$n', style: KdText.body(10, color: Colors.white, weight: FontWeight.w600, height: 1)),
      );
}

// ════════════════════ 전투 화면 오른쪽 위: 우편함·랭킹 버튼 (웹 #mailBtn · #rankBtn) ════════════════════
class SocialFabs extends StatelessWidget {
  const SocialFabs(this.g, {super.key});
  final GameController g;

  /// 아이콘 아래 이름 (웹 .mailbtn[data-l] · UI 점검 10-27 7번). D-day 표시가 있으면 이름은 숨김
  Widget _btn(String icon, VoidCallback onTap, Widget? mark, [String? label]) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xC70A0E1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x8CFFC94A)),
            ),
            child: kdImg('assets/game/ui/$icon.png', w: 34, h: 34),
          ),
          if (mark != null) mark,
        ]),
        SizedBox(
          height: 15,
          child: label == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(label,
                      style: KdText.body(11, color: const Color(0xFFF3E6C4), weight: FontWeight.w700, height: 1)
                          .copyWith(shadows: const [Shadow(blurRadius: 2, color: Colors.black), Shadow(blurRadius: 3, color: Colors.black)])),
                ),
        ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final o = g.online;
    // 상점 버튼 (U-2 ③): 늘 보임 · 할 일·무료 선물이 남았고 아직 안 봤으면 점
    final shop = _btn('icon_shop', () => g.setTab(GameTab.sh),
        g.dotOn(GameTab.sh) ? Positioned(top: -3, right: -3, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: KdColors.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white)))) : null, '상점');
    // 출석부 (웹 #attBtn): 상점 바로 밑, 1-3 이후 · 오늘 안 받았으면 노란 점
    final att = attEligible(g)
        ? _btn(
            'ic_attend',
            () => openAttend(g),
            attDot(g)
                ? Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD23A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0xFFFFD23A), blurRadius: 6)],
                      ),
                    ),
                  )
                : null,
            '출석')
        : null;
    // 원정 일지 시즌이 끝나 넘어온 보상 (이 기기 저장 · 인터넷 없어도 받음)
    final lm = g.acts.passMails().length;
    if (!o.on) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (lm > 0) ...[_btn('icon_mail', () => openMail(g), Positioned(top: -5, right: -5, child: CountDot(lm)), '우편'), const SizedBox(height: 4)],
        shop,
        if (att != null) ...[const SizedBox(height: 4), att],
      ]);
    }
    return ValueListenableBuilder<int>(
      valueListenable: o.ver,
      builder: (_, __, ___) {
        final left = (seasonEndAt(DateTime.now().millisecondsSinceEpoch) - DateTime.now().millisecondsSinceEpoch) / 864e5;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _btn('icon_mail', () => openMail(g), o.mails.length + lm == 0 ? null : Positioned(top: -5, right: -5, child: CountDot(o.mails.length + lm)), '우편'),
          const SizedBox(height: 4),
          _btn(
            'icon_rank',
            () => openRanking(g),
            left > 3
                ? null
                : Positioned(
                    bottom: -7,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(color: const Color(0xFFFF5A6E), borderRadius: BorderRadius.circular(7)),
                        child: Text(left < 1 ? 'D-DAY' : 'D-${left.ceil()}', style: KdText.body(9.5, color: Colors.white, weight: FontWeight.w600, height: 1.45)),
                      ),
                    ),
                  ),
            left > 3 ? '랭킹' : null,
          ),
          const SizedBox(height: 4),
          shop,
          if (att != null) ...[const SizedBox(height: 4), att],
        ]);
      },
    );
  }
}

// ════════════════════ 프로필 (웹 profileSheet) ════════════════════
void openProfile(GameController g) {
  final s = g.state;
  s.raw['pfSeen'] = 1;
  final nw = Map<String, dynamic>.from(asMap(s.raw['pfNew']) ?? const {});
  s.raw['pfNew'] = <String, dynamic>{};
  g.calc.pfCheck();
  g.save();
  g.refresh();
  g.openSheet<void>((c) => _Profile(g, c, nw));
}

class _Profile extends StatefulWidget {
  const _Profile(this.g, this.sheet, this.nw);
  final GameController g;
  final BuildContext sheet;
  final Map<String, dynamic> nw;

  @override
  State<_Profile> createState() => _ProfileState();
}

/// 웹 profileSheet: 칸을 눌러 고르기만(금테) → 「저장」으로 한 번에 적용. 맨 위 미리보기는 고른 대로.
/// 저장하지 않고 나가려 하면(✕·바깥·뒤로·설정·랭킹·닉네임) 「저장할까요?」 한 번 묻기
class _ProfileState extends State<_Profile> {
  GameController get g => widget.g;

  // 고르는 중인 값 (웹 pfDraft)
  late String _pf;
  String? _badge;
  late String _face;
  late bool _photo;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _pf = g.calc.curFrame();
    _badge = g.calc.curBadge();
    _face = g.calc.pubFace();
    _photo = g.photoOn;
  }

  bool get _dirty {
    final c = g.calc;
    return _pf != c.curFrame() || _badge != c.curBadge() || _face != c.pubFace() || _photo != g.photoOn;
  }

  void _save() {
    final c = g.calc, s = g.state;
    s.raw['pf'] = _pf;
    s.raw['badge'] = _badge;
    s.raw['face'] = _face == 'kael' ? null : _face;
    s.raw['facePhoto'] = _photo;
    g.online.faceSync();
    c.pfCheck();
    g.save();
    g.refresh();
    g.toast('프로필을 저장했어요');
  }

  /// 저장 안 한 채로 나가려 할 때. then: 나간 뒤 할 일
  Future<void> _leave(VoidCallback then) async {
    if (!_dirty) {
      _leaving = true;
      then();
      return;
    }
    final save = await showKdSheet<bool>(
      context,
      closable: false,
      builder: (c) => KdSheetBody(
        eyebrow: '프로필',
        title: '바꾼 꾸미기를 저장할까요?',
        children: [Text('저장하지 않으면 고른 얼굴·테두리·배지가 원래대로 돌아가요.', textAlign: TextAlign.center, style: _muted(13))],
        acts: KdActs(buttons: [
          KdAct('저장 안 함', onTap: () => Navigator.of(c).pop(false)),
          KdAct('저장', primary: true, onTap: () => Navigator.of(c).pop(true)),
        ]),
      ),
    );
    if (save == null || !mounted) return;
    if (save) _save();
    _leaving = true;
    then();
  }

  void _pick(Deco d, bool frame) {
    final c = g.calc;
    final has = frame ? c.pfHas(d.k) : c.bdHas(d.k);
    if (!has) {
      g.toast(passFrameNo(d.k) != null ? '${d.d} 보상이에요' : d.rk ? '${d.d}로 우편함에 도착해요' : d.rare ? '황금 고블린을 잡으면 아주 드물게 얻어요' : '${d.d} 달성 시 얻어요');
      return;
    }
    setState(() {
      if (frame) {
        _pf = d.k;
      } else {
        _badge = _badge == d.k ? null : d.k;
      }
    });
  }

  /// 사진 올리기는 고르는 즉시 이 기기에 저장되고 바로 씀
  Future<void> _newPhoto() async {
    if (await g.pickPhoto() && mounted) setState(() => _photo = true);
  }

  void _delPhoto() {
    g.clearPhoto();
    if (mounted) setState(() => _photo = false);
  }

  void _pickFace(String id) {
    if (id == 'photo') {
      if (g.photoBytes == null) {
        _newPhoto();
        return;
      }
      setState(() => _photo = true);
    } else {
      setState(() {
        _face = id;
        _photo = false;
      });
    }
  }

  /// 웹 .fcgrid: 내 사진 + 카엘 + 합류한 동료
  Widget _faceGrid() => LayoutBuilder(builder: (_, box) {
        final w = (box.maxWidth - 3 * 8) / 4, pv = math.min(52.0, w - 6);
        final c = g.calc, ph = _photo, pub = _face, bytes = g.photoBytes;
        final ids = ['kael', for (final id in comps.keys) if (id != 'kael' && c.owned(id)) id];
        Widget cell(String key, String name, Widget face, bool on, String sub) => GestureDetector(
              onTap: () => _pickFace(key),
              child: Container(
                width: w,
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 7),
                decoration: BoxDecoration(
                  color: KdColors.panel2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? KdColors.gold : Colors.transparent, width: 2),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: pv,
                    height: pv,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? KdColors.gold : const Color(0xFF3A4568), width: 2),
                      gradient: const RadialGradient(center: Alignment(0, -.3), colors: [Color(0xFF3B5A8A), Color(0xFF1A2440)]),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: face),
                  ),
                  const SizedBox(height: 3),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KdText.body(12, weight: FontWeight.w600, height: 1.2)),
                  Text(sub, style: KdText.body(11.5, color: on ? KdColors.gold : KdColors.muted, height: 1.2)),
                ]),
              ),
            );
        return Wrap(spacing: 8, runSpacing: 8, children: [
          cell('photo', '내 사진', bytes != null ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true) : const Center(child: Text('📷', style: TextStyle(fontSize: 24))), ph,
              bytes != null ? ' ' : '올리기'),
          for (final id in ids) cell(id, id == 'kael' ? '카엘' : comps[id]!.n, FaceImg(id), !ph && pub == id, ' '),
        ]);
      });

  Widget _grid(List<Deco> list, bool frame) => LayoutBuilder(builder: (_, box) {
        final w = (box.maxWidth - 3 * 8) / 4, pv = math.min(56.0, w - 6);
        final c = g.calc, cur = _pf;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in list)
            Builder(builder: (_) {
              final has = frame ? c.pfHas(d.k) : c.bdHas(d.k);
              final on = frame ? d.k == cur : _badge == d.k;
              final isNew = truthy(widget.nw['${frame ? 'f' : 'b'}_${d.k}']);
              return GestureDetector(
                onTap: () => _pick(d, frame),
                child: Opacity(
                  opacity: has ? 1 : .55,
                  child: Container(
                    width: w,
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 7),
                    decoration: BoxDecoration(
                      color: KdColors.panel2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: on ? KdColors.gold : Colors.transparent, width: 2),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: pv,
                        height: pv,
                        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                          if (frame)
                            FramedFace(frame: d.k, size: pv, dim: !has, face: false)
                          else
                            Positioned.fill(child: has ? _badgeImg(d.k, pv) : filtered(_badgeImg(d.k, pv), gray: 1, bright: .6)),
                          if (!has) uiImg('icon_lock', size: 26),
                          if (d.rk)
                            Positioned(
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFFFD96A), Color(0xFFD39A1C)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text('랭킹', style: KdText.body(9.5, color: const Color(0xFF2A1A00), weight: FontWeight.w600, height: 1.45)),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 3),
                      Text(d.n, textAlign: TextAlign.center, style: KdText.body(12, weight: FontWeight.w600, height: 1.2)),
                      if (isNew)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: KdColors.bad, borderRadius: BorderRadius.circular(6)),
                          child: Text('NEW', style: KdText.body(9, color: Colors.white, weight: FontWeight.w600, height: 1.4)),
                        ),
                      Text(
                        has ? ' ' : '🔒 ${d.d}',
                        textAlign: TextAlign.center,
                        style: KdText.body(11.5, color: on ? KdColors.gold : KdColors.muted, height: 1.2),
                      ),
                    ]),
                  ),
                ),
              );
            }),
        ]);
      });

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc, o = g.online, cur = _pf, bd = _badge, dirty = _dirty;
    return PopScope(
      canPop: !dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(() => Navigator.of(widget.sheet).pop());
      },
      child: KdSheetBody(
      titleWidget: const HdBanner('hd_profile', '프로필'),
      children: [
        Row(children: [
          FramedFace(frame: cur, size: 104, faceId: _face, photo: _photo ? g.photoBytes : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 이름 줄 옆 ⚙ 설정 · 🏆 랭킹 (대표님 제보 10-27: 설정이 창 맨 아래라 찾기 어려움)
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('카엘', style: KdText.display(20)),
                  if (bd != null) ...[const SizedBox(width: 4), _badgeImg(bd, 22)],
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  KdBuy(key: const ValueKey('pfSet'), kind: BuyKind.ghost, small: true, minWidth: 0, text: '⚙ 설정', onTap: () => _leave(() => g.chainSheet(widget.sheet, () => openSettings(g)))),
                  const SizedBox(width: 4),
                  KdBuy(key: const ValueKey('pfRank'), kind: BuyKind.ghost, small: true, minWidth: 0, text: '🏆 랭킹', onTap: () => _leave(() => g.chainSheet(widget.sheet, () => openRanking(g)))),
                ]),
              ]),
              const SizedBox(height: 3),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                Text.rich(TextSpan(children: [
                  const TextSpan(text: '닉네임 '),
                  TextSpan(text: o.nick ?? '준비 중', style: const TextStyle(color: Color(0xFFFFE7A6), fontWeight: FontWeight.w600)),
                ]), style: _muted()),
                if (o.nickTemp)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(color: const Color(0x33FFC94A), borderRadius: BorderRadius.circular(6)),
                    child: Text('임시', style: KdText.body(10, color: KdColors.gold)),
                  ),
                if (o.on)
                  KdBuy(
                    small: true,
                    minWidth: 0,
                    text: o.nickTemp || o.nick == null ? '정하기' : '바꾸기',
                    onTap: () => _leave(() => g.chainSheet(widget.sheet, () async {
                          if (o.nick == null) await o.ensure();
                          openNick(g, after: () => openProfile(g));
                        })),
                  ),
              ]),
              const SizedBox(height: 3),
              Text('${ranks[c.rankIdx()].n} · 전투력 ${fmt(c.power())}', style: _muted()),
              const SizedBox(height: 3),
              Text('최고 영지 ${math.min(s.best, maxLand)} · 은퇴 ${fmt(s.retires)}번 · 은퇴의 추억 ${fmt(s.memory)}개', style: _muted()),
              if (c.chOpen) ...[const SizedBox(height: 3), Text('시련의 탑 최고 ${c.towerTop()}층', style: _muted())],
            ]),
          ),
        ]),
        Text.rich(
            TextSpan(children: dirty
                ? const [TextSpan(text: '고른 대로 위에 미리 보여요. '), TextSpan(text: '저장', style: TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: '을 눌러야 바뀌어요.')]
                : const [TextSpan(text: '칸을 눌러 고른 뒤 '), TextSpan(text: '저장', style: TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: '을 누르세요.')]),
            style: _muted(12.5)),
        KdSec('얼굴', small: '합류한 동료 · 내 사진'),
        _faceGrid(),
        if (g.photoBytes != null)
          Text.rich(
            TextSpan(style: _muted(12), children: [
              const TextSpan(text: '내 사진은 이 기기에서만 보여요. 다른 영주에게는 '),
              TextSpan(text: _face == 'kael' ? '카엘' : comps[_face]!.n, style: KdText.body(12, weight: FontWeight.w600)),
              const TextSpan(text: ' 얼굴이 보여요.  '),
              TextSpan(text: '다른 사진', style: KdText.body(12, color: KdColors.gold).copyWith(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = _newPhoto),
              const TextSpan(text: ' · '),
              TextSpan(text: '사진 지우기', style: KdText.body(12, color: KdColors.gold).copyWith(decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = _delPhoto),
            ]),
          ),
        KdSec('테두리', small: '${c.pfList().where((f) => c.pfHas(f.k)).length} / ${c.pfList().length}'),
        _grid(c.pfList(), true),
        KdSec('대표 배지', small: '${badges.where((b) => c.bdHas(b.k)).length + c.attBadges().length} / ${badges.length + c.attBadges().length} · 한 번 더 누르면 떼기'),
        _grid([...c.attBadges(), ...badges], false),
      ],
      acts: KdActs(buttons: [
        if (dirty)
          KdAct('저장', primary: true, onTap: () {
            _save();
            _leaving = true;
            Navigator.of(widget.sheet).pop();
          })
        else
          KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop()),
      ]),
      ),
    );
  }
}

// ════════════════════ 닉네임 (웹 nickSheet) ════════════════════
void openNick(GameController g, {VoidCallback? after}) => g.openSheet<void>((c) => _Nick(g, c, after));

class _Nick extends StatefulWidget {
  const _Nick(this.g, this.sheet, this.after);
  final GameController g;
  final BuildContext sheet;
  final VoidCallback? after;

  @override
  State<_Nick> createState() => _NickState();
}

class _NickState extends State<_Nick> {
  late final TextEditingController _t;
  String _err = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.g.online;
    _t = TextEditingController(text: o.nickTemp ? '' : (o.nick ?? ''));
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    setState(() {
      _busy = true;
      _err = '확인하는 중…';
    });
    final e = await widget.g.online.setNick(_t.text.trim());
    if (!mounted) return;
    if (e == null) {
      widget.g.chainSheet(widget.sheet, widget.after ?? () => openRanking(widget.g));
    } else {
      setState(() {
        _busy = false;
        _err = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.g.online;
    return KdSheetBody(
      eyebrow: '프로필',
      title: '닉네임 ${o.nickTemp || o.nick == null ? '정하기' : '바꾸기'}',
      children: [
        Text('${o.nickTemp ? '지금은 임시 닉네임이에요. 원하는 이름으로 바꿔 보세요.\n' : ''}랭킹과 우편에 쓰이는 이름이에요. 2~10글자, 시즌마다 한 번 바꿀 수 있어요.',
            textAlign: TextAlign.center, style: _muted()),
        TextField(
          controller: _t,
          maxLength: 10,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          style: KdText.display(18),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF141A2C),
            hintText: '예: 은퇴하고픈농부',
            hintStyle: KdText.body(14, color: KdColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: KdColors.line)),
          ),
          onSubmitted: (_) => _busy ? null : _ok(),
        ),
        Text(_err, textAlign: TextAlign.center, style: KdText.body(12.5, color: const Color(0xFFFFB3BD))),
      ],
      acts: KdActs(buttons: [
        KdAct('취소', onTap: () => Navigator.of(widget.sheet).pop()),
        KdAct('정하기', primary: true, onTap: _busy ? null : _ok),
      ]),
    );
  }
}

// ════════════════════ 랭킹 3탭 (웹 rankSheet) ════════════════════
const _towerRew = [('1위', '이삭 100'), ('2~10위', '이삭 50'), ('상위 30%', '이삭 20')];
const _gobRew = [('1위', '이삭 100 · 고블린 사냥꾼 배지'), ('2~10위', '이삭 50'), ('상위 30%', '이삭 20')];
const _rkRew = [('1위', '이삭 500 · 시즌 왕관 테두리 · 전용 배지'), ('2~10위', '이삭 300 · 전용 배지'), ('상위 10%', '이삭 150 · 동료 카드 30장'), ('상위 50%', '이삭 50'), ('참여', '이삭 20')];

/// 마지막으로 본 탭 (웹 rkTab)
String _rkTab = 'season';

Future<void> openRanking(GameController g, [String? tab]) async {
  final o = g.online;
  if (tab != null) _rkTab = tab;
  if (!o.on) {
    g.scene('랭킹', '준비 중이에요', ['랭킹 서버를 연결하고 있어요. 곧 다른 영주들과 겨룰 수 있어요!', 'q@proud:흥, 주인이 1등인 건 정해진 일이다.'], '기대할게요', closable: true);
    return;
  }
  // 닉네임은 프로필에서만 정함 (처음엔 임시 닉네임으로 랭킹에 올라감)
  g.openSheet<void>((c) => _Rank(g, c));
}

class _Rank extends StatefulWidget {
  const _Rank(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_Rank> createState() => _RankState();
}

class _RankState extends State<_Rank> {
  GameController get g => widget.g;
  List<Map<String, dynamic>>? _rows;
  String? _err;
  bool _rewOpen = false;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final my = ++_req, o = g.online;
    setState(() {
      _rows = null;
      _err = null;
      _rewOpen = false;
    });
    if (o.nick == null) await o.ensure();
    if (!mounted || my != _req) return;
    if (o.nick == null) {
      setState(() => _err = '서버에 연결하지 못했어요. 인터넷 연결을 확인하거나 조금 뒤에 다시 열어 주세요');
      return;
    }
    try {
      final rows = await o.ranking(_rkTab);
      if (!mounted || my != _req) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted || my != _req) return;
      // 서버가 답했지만 실패(ServerError)면 서버 쉬는 중, 답이 없으면(연결 안 됨·시간 초과) 인터넷 문제 (웹 sbDownMsg · UI 점검 10-27 12번)
      setState(() => _err = e is ServerError ? '랭킹 서버가 잠시 쉬고 있어요. 조금 뒤에 다시 열어 주세요' : '인터넷 연결을 확인해 주세요. 연결되면 랭킹을 볼 수 있어요');
    }
  }

  String _score(Map<String, dynamic> x) => switch (_rkTab) {
        'goblin' => '${fmt(asNum(x['kills']))}마리',
        'tower' => '${fmt(asNum(x['top']))}층',
        _ => stgName(asNum(x['stage'])),
      };

  /// 랭킹 얼굴: 나는 내가 고른 얼굴(사진은 내 화면에서만), 다른 영주는 서버가 준 동료 id
  Widget _face(Map<String, dynamic> x, double size) {
    final me = x['me'] == true, f = x['face'];
    return FramedFace(
      frame: x['frame'] is String && frameOf(x['frame']) != null ? x['frame'] : 'wood',
      size: size,
      portrait: true,
      faceId: me ? g.calc.pubFace() : (f is String && comps.containsKey(f) ? f : 'kael'),
      photo: me && g.photoOn ? g.photoBytes : null,
    );
  }

  Widget _nick(Map<String, dynamic> x, double size, {TextAlign align = TextAlign.left}) {
    final b = x['badge'];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (b is String && (badgeOf(b) != null || isAttBadge(b))) ...[_badgeImg(b, 16), const SizedBox(width: 2)],
      Flexible(child: Text('${x['nick'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: align, style: KdText.body(size, weight: FontWeight.w600))),
    ]);
  }

  Widget _line(Map<String, dynamic> x) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: x['me'] == true ? const Color(0x1F7BE08F) : KdColors.panel2,
          borderRadius: BorderRadius.circular(10),
          border: x['me'] == true ? Border.all(color: const Color(0x807BE08F)) : null,
        ),
        child: Row(children: [
          SizedBox(width: 26, child: Text('${x['rank']}', textAlign: TextAlign.center, style: KdText.figure(14, color: KdColors.muted))),
          const SizedBox(width: 6),
          _face(x, 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _nick(x, 14),
              Text('${x['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted(12)),
            ]),
          ),
          const SizedBox(width: 6),
          _rkTab == 'goblin'
              ? iconNum('assets/game/ui/icon_goblin.png', _score(x).replaceAll('마리', ''), size: 16, style: KdText.figure(14, color: KdColors.gold))
              : _rkTab == 'tower'
                  ? iconNum('assets/game/ui/icon_challenge.png', _score(x), size: 16, style: KdText.figure(14, color: KdColors.gold))
                  : Text(_score(x), style: KdText.figure(14, color: KdColors.gold)),
        ]),
      );

  Widget _tabs() => Row(children: [
        for (final (k, n) in const [('season', '시즌'), ('hall', '명예의 전당'), ('goblin', '고블린'), ('tower', '탑')])
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_rkTab == k) return;
                _rkTab = k;
                _load();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _rkTab == k ? KdColors.gold : KdColors.panel2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _rkTab == k ? KdColors.gold : KdColors.line),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(n, style: KdText.body(13, color: _rkTab == k ? const Color(0xFF1A1206) : KdColors.fg, weight: FontWeight.w600)),
                ),
              ),
            ),
          ),
      ]);

  String _left(num endMs) {
    final left = math.max(0, (endMs - DateTime.now().millisecondsSinceEpoch) / 1000);
    return left > 86400 ? '${(left / 86400).ceil()}일' : '${math.max(1, (left / 3600).ceil())}시간';
  }

  Widget _info(List<Map<String, dynamic>> rows) {
    final tot = rows.isEmpty ? 0 : asNum(rows[0]['total']);
    List<(String, String)>? rew;
    final List<InlineSpan> head;
    if (_rkTab == 'season') {
      if (rows.isEmpty) return const SizedBox.shrink();
      final end = DateTime.tryParse('${rows[0]['season_end']}')?.millisecondsSinceEpoch ?? seasonEndAt(DateTime.now().millisecondsSinceEpoch);
      head = [
        TextSpan(text: '${rows[0]['season']}시즌', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w600)),
        TextSpan(text: ' · ${_left(end)} 남음 · ${fmt(tot)}명 참여'),
      ];
      rew = _rkRew;
    } else if (_rkTab == 'hall') {
      head = [TextSpan(text: '지금까지 도달한 최고 기록이에요 · ${fmt(tot)}명')];
    } else if (_rkTab == 'tower') {
      final w = rows.isNotEmpty ? asNum(rows[0]['week']).toInt() : g.sim.curWeek();
      final end = (rows.isNotEmpty ? DateTime.tryParse('${rows[0]['week_end']}')?.millisecondsSinceEpoch : null) ?? seasonZero + w * 604800000;
      head = [
        const TextSpan(text: '시련의 탑 · 역대 최고 층', style: TextStyle(color: KdColors.gold, fontWeight: FontWeight.w600)),
        TextSpan(text: ' · ${fmt(tot)}명\n$w주차 정산까지 ${_left(end)} · 이번 주에 게임한 영주끼리 순위대로 보상\n내 최고 ${fmt(g.online.towerTop)}층'),
      ];
      rew = _towerRew;
    } else {
      final w = rows.isNotEmpty ? asNum(rows[0]['week']).toInt() : g.sim.curWeek();
      final end = (rows.isNotEmpty ? DateTime.tryParse('${rows[0]['week_end']}')?.millisecondsSinceEpoch : null) ?? seasonZero + w * 604800000;
      head = [
        TextSpan(text: '$w주차 황금 고블린', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w600)),
        TextSpan(text: ' · ${_left(end)} 남음 · ${fmt(tot)}명 참여\n이번 주 내 기록 ${fmt(asNum(g.sim.gobWeek()['n']))}마리'),
      ];
      rew = _gobRew;
    }
    return Column(children: [
      Text.rich(TextSpan(children: head), textAlign: TextAlign.center, style: _muted()),
      if (rew != null) ...[
        GestureDetector(
          onTap: () => setState(() => _rewOpen = !_rewOpen),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${_rewOpen ? '▾' : '▸'} ${_rkTab == 'season' ? '시즌' : '주간'} 보상 보기', style: KdText.body(13, color: KdColors.gold)),
          ),
        ),
        if (_rewOpen) for (final (a, b) in rew) KdKv(a, b),
      ],
    ]);
  }

  Widget _podium(List<Map<String, dynamic>> top) {
    Widget pod(int i) {
      if (i >= top.length) return const Expanded(child: SizedBox());
      final x = top[i], me = x['me'] == true;
      return Expanded(
        flex: i == 0 ? 115 : 100,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: EdgeInsets.fromLTRB(4, i == 0 ? 14 : 8, 4, 8),
            decoration: BoxDecoration(
              color: const Color(0xD1171E36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: me ? KdColors.good : i == 0 ? KdColors.gold : Colors.transparent, width: me ? 2 : 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _face(x, i == 0 ? 64 : 52),
              const SizedBox(height: 2),
              _nick(x, 13),
              Text(_score(x), style: KdText.figure(13, color: KdColors.gold)),
            ]),
          ),
          Positioned(top: -12, child: Text(['🥇', '🥈', '🥉'][i], style: const TextStyle(fontSize: 20))),
        ]),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x59FFC94A)),
          borderRadius: BorderRadius.circular(14),
          image: DecorationImage(
            image: AssetImage('assets/game/illust/${_rkTab == 'goblin' ? 'rank_bg_goblin' : 'rank_bg'}.jpg'),
            fit: BoxFit.cover,
            alignment: const Alignment(0, .56),
            colorFilter: const ColorFilter.mode(Color(0x660D1220), BlendMode.srcATop),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 26, 8, 40),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [pod(1), pod(0), pod(2)]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final me = rows?.where((x) => x['me'] == true).firstOrNull;
    final tot = rows == null || rows.isEmpty ? 0 : asNum(rows[0]['total']);
    final top = rows?.where((x) => asNum(x['rank']) <= 100).toList() ?? const [];
    return KdSheetBody(
      titleWidget: switch (_rkTab) {
        'goblin' => const HdBanner('hd_goblin', '고블린 랭킹', size: 18, padTop: .048),
        'tower' => const HdBanner('hd_challenge', '탑 랭킹'),
        _ => const HdBanner('hd_rank', '랭킹'),
      },
      children: [
        _tabs(),
        if (_err != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_err!, textAlign: TextAlign.center, style: _muted()))
        else if (rows == null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text('불러오는 중…', textAlign: TextAlign.center, style: _muted()))
        else ...[
          _info(rows),
          if (rows.isEmpty)
            Text(
                switch (_rkTab) {
                  'goblin' => '이번 주에 황금 고블린을 잡은 영주가 아직 없어요. 1-3 영지부터 나타나요!',
                  'tower' => '아직 탑 기록이 없어요. 영지 20을 되찾으면 지도의 「도전」에서 시련의 탑이 열려요!',
                  _ => '아직 기록이 없어요. 첫 1위가 되어 보세요!',
                },
                textAlign: TextAlign.center, style: _muted())
          else ...[
            _podium(top.take(3).toList()),
            for (final x in top.skip(3)) _line(x),
          ],
          if (me != null) ...[
            _line(me),
            Text('상위 ${math.max(1, (asNum(me['rank']) / math.max(1, tot) * 100).ceil())}%', textAlign: TextAlign.right, style: KdText.body(12, color: KdColors.good)),
          ],
        ],
      ],
      acts: KdActs(buttons: [
        KdAct('닫기', primary: true, onTap: () => Navigator.of(widget.sheet).pop()),
      ]),
    );
  }
}

// ════════════════════ 우편함 (웹 mailSheet) ════════════════════
void openMail(GameController g) {
  if (!g.online.on && g.acts.passMails().isEmpty) {
    g.openSheet<void>((c) => KdSheetBody(
          titleWidget: const HdBanner('hd_mail', '우편함', size: 16),
          children: [Text('우편함을 준비하고 있어요.', textAlign: TextAlign.center, style: _muted())],
          acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(c).pop())]),
        ));
    return;
  }
  g.openSheet<void>((c) => _Mail(g, c));
}

class _Mail extends StatefulWidget {
  const _Mail(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  @override
  State<_Mail> createState() => _MailState();
}

class _MailState extends State<_Mail> {
  bool _loading = true;
  bool _offline = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = widget.g.online;
    if (!o.on) {
      setState(() {
        _loading = false;
        _offline = true;
      });
      return;
    }
    if (o.nick == null) {
      await o.ensure();
    } else {
      await o.mailFetch();
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = o.nick == null;
    });
  }

  static String _day(Object? t) {
    final ms = DateTime.tryParse('$t')?.millisecondsSinceEpoch;
    if (ms == null) return '';
    final d = (ms - DateTime.now().millisecondsSinceEpoch) / 864e5;
    return d >= 1 ? '${d.floor()}일 남음' : '${math.max(1, (d * 24).ceil())}시간 남음';
  }

  Widget _chip(String img, String t) => Container(
        padding: const EdgeInsets.fromLTRB(2, 2, 6, 2),
        decoration: BoxDecoration(color: const Color(0x4D000000), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          kdImg(img, w: 20, h: 20),
          const SizedBox(width: 3),
          Flexible(child: Text(t, style: KdText.body(12, weight: FontWeight.w600))),
        ]),
      );

  /// 원정 일지 우편 보상 칩
  List<Widget> _passChips(Map<String, dynamic> r) => [
        if (asNum(r['idle']) > 0) _chip('assets/game/ui/ui_gold.png', '골드 ${fmt(asNum(r['idle']))}시간'),
        if (asNum(r['ore']) > 0) _chip('assets/game/ui/item_ore.png', '광석 ${fmt(asNum(r['ore']))}'),
        if (asNum(r['seed']) > 0) _chip('assets/game/ui/seed_wheat.png', '씨앗 ×${fmt(asNum(r['seed']))}'),
        if (asNum(r['gem']) > 0) _chip(gemIcon, fmt(asNum(r['gem']))),
        if (asNum(r['card']) > 0) _chip('assets/game/ui/card_pack3.png', '동료 카드 ${fmt(asNum(r['card']))}장'),
        if (asNum(r['box10']) > 0) _chip('assets/game/ui/item_box10ticket.png', '상자 10연속 ${fmt(asNum(r['box10']))}'),
        if (r['frame'] is List)
          for (final f in r['frame'] as List) _chip(frameAsset('$f'), '${frameName('$f')} 테두리'),
      ];

  List<Widget> _chips(Map<String, dynamic> r) => [
        if (asNum(r['gem']) > 0) _chip(gemIcon, fmt(asNum(r['gem']))),
        if (asNum(r['cards']) > 0) _chip('assets/game/ui/card_pack30.png', '동료 카드 ${fmt(asNum(r['cards']))}장'),
        if (asNum(r['ucard']) > 0) _chip('assets/game/ui/card_unique.png', '유니크 카드 ${fmt(asNum(r['ucard']))}장'),
        if (r['frame'] is String) _chip(frameAsset(r['frame'] as String), '${frameName(r['frame'])} 테두리'),
        if (r['badge'] is String) _chip(badgeAsset(r['badge'] as String), '${badgeName(r['badge'])} 배지'),
      ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g, o = g.online;
    return ValueListenableBuilder<int>(
      valueListenable: o.ver,
      builder: (_, __, ___) {
        final ms = o.mails, lm = g.acts.passMails(), tot = ms.length + lm.length;
        return KdSheetBody(
          titleWidget: const HdBanner('hd_mail', '우편함', size: 16),
          children: [
            // 원정 일지 시즌 끝 보상 (이 기기 저장)
            for (final m in lm)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x40FFC94A)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('📖 ${m['title'] ?? ''}', style: KdText.body(14, weight: FontWeight.w600)),
                      Text('시즌이 끝나 받지 않은 보상을 모아 보냈어요.', style: _muted(12)),
                      const SizedBox(height: 3),
                      Wrap(spacing: 4, runSpacing: 4, children: _passChips(asMap(m['r']) ?? const {})),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  KdBuy(kind: BuyKind.claim, minWidth: 0, text: '받기', onTap: () => g.act((x) => x.passMailClaim('${m['id']}'))),
                ]),
              ),
            if (_offline && lm.isNotEmpty)
              const SizedBox.shrink()
            else if (_loading && ms.isEmpty)
              Text('우편을 확인하는 중…', textAlign: TextAlign.center, style: _muted())
            else if (_offline)
              Text('인터넷에 연결되면 우편을 받을 수 있어요.', textAlign: TextAlign.center, style: _muted())
            else ...[
              Text('받은 우편은 30일 동안 보관돼요.', textAlign: TextAlign.center, style: _muted()),
              if (ms.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('도착한 우편이 없어요.', textAlign: TextAlign.center, style: _muted()))
              else
                for (final m in ms)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x40FFC94A)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['kind'] == 'reply' ? '💬 ' : ''}${m['title'] ?? ''}', style: KdText.body(14, weight: FontWeight.w600)),
                          if (m['body'] is String && (m['body'] as String).isNotEmpty) Text(m['body'], style: _muted(12)),
                          const SizedBox(height: 3),
                          Wrap(spacing: 4, runSpacing: 4, children: _chips(asMap(m['reward'])?.cast<String, dynamic>() ?? const {})),
                          const SizedBox(height: 3),
                          Text(_day(m['expires_at']), style: KdText.body(12, color: KdColors.gold)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      KdBuy(
                        kind: BuyKind.claim,
                        minWidth: 0,
                        // 보상 없는 문의 답변은 「확인」 (웹과 같음)
                        text: m['kind'] == 'reply' && (asMap(m['reward'])?.isEmpty ?? true) ? '확인' : '받기',
                        onTap: _busy.contains(asNum(m['id']).toInt())
                            ? null
                            : () {
                                final id = asNum(m['id']).toInt();
                                setState(() => _busy.add(id));
                                o.mailClaim(id).whenComplete(() {
                                  if (mounted) setState(() => _busy.remove(id));
                                });
                              },
                      ),
                    ]),
                  ),
            ],
          ],
          acts: KdActs(buttons: [
            if (tot > 1)
              KdAct('모두 받기', primary: true, claim: true, onTap: () {
                if (lm.isNotEmpty) g.act((x) => x.passMailClaim(null));
                if (ms.isNotEmpty) o.mailClaim(null);
              }),
            KdAct('닫기', primary: tot <= 1, onTap: () => Navigator.of(widget.sheet).pop()),
          ]),
        );
      },
    );
  }
}

// ════════════════════ 시즌·주간 결과 (웹 resultPop) ════════════════════
Future<void> showResultSheet(BuildContext ctx, GameController g, {required int no, required int rank, required bool big, required String body}) =>
    showKdSheet<void>(ctx, builder: (c) => KdSheetBody(
          eyebrow: big ? '시즌 결과' : '황금 고블린 주간 결과',
          title: '$no${big ? '시즌' : '주차'} $rank위!',
          children: [
            Text(rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '🏅', textAlign: TextAlign.center, style: const TextStyle(fontSize: 64, height: 1.1)),
            Text('${body.isNotEmpty ? '$body\n' : ''}보상이 우편함에 도착했어요.', textAlign: TextAlign.center, style: _muted()),
          ],
          acts: KdActs(buttons: [
            KdAct('닫기', onTap: () => Navigator.of(c).pop()),
            KdAct('우편함 열기', primary: true, onTap: () => g.chainSheet(c, () => openMail(g))),
          ]),
        ));

// ════════════════════ 카드 공개 (웹 cardReveal, C-1) ════════════════════
/// 줄 높이는 내용에 맞춤 · 카드가 하나씩 뒤집힘(영웅·전설은 뒤집기 전부터 빛이 샘) · 「모두 뒤집기」
/// · 맨 위 요약 + 합류·★ 올리기 가능한 동료를 맨 위로(금테) · 줄마다 「합류하기」「★ 올리기」
Future<void> showCardReveal(BuildContext ctx, GameController g, List<(String, int)> list, String title, {num gold = 0, int? again}) {
  final m = <String, int>{};
  for (final (id, n) in list) {
    m[id] = (m[id] ?? 0) + n;
  }
  if (m.isEmpty) {
    if (gold > 0) g.toast('동료 카드 → 골드 +${fmt(gold)} (별을 다 채운 동료)');
    return Future.value();
  }
  g.toastClear();
  return showKdSheet<void>(ctx, builder: (sc) => _CardReveal(g, m, title, gold, again));
}

class _CardReveal extends StatefulWidget {
  const _CardReveal(this.g, this.m, this.title, this.gold, this.again);
  final GameController g;
  final Map<String, int> m;
  final String title;
  final num gold;

  /// 상점 카드 묶음 번호 → 「또 뽑기」 (가격 보이게, 확인 창 없음)
  final int? again;

  @override
  State<_CardReveal> createState() => _CardRevealState();
}

class _CardRevealState extends State<_CardReveal> with SingleTickerProviderStateMixin {
  late final List<String> _ids;

  /// 전체 시간 하나로 줄마다 0.35초씩 늦게 0.45초 동안 뒤집음 (타이머 없이)
  late final AnimationController _ac;
  int get _totalMs => 350 + _ids.length * 350 + 450;
  double _t(int i) => ((_ac.value * _totalMs - (350 + i * 350)) / 450).clamp(0.0, 1.0);

  bool _can(String id) {
    final c = widget.g.calc;
    final need = c.starNeed(id);
    return c.recStar(id) < c.starMax(id) && need != null && orNum(c.s.cardsW[id], 0) >= need;
  }

  @override
  void initState() {
    super.initState();
    _ids = stableSorted(widget.m.keys, (a, b) {
      final d = (_can(b) ? 1 : 0) - (_can(a) ? 1 : 0);
      return d != 0 ? d : GameCalc.gr(a).w.compareTo(GameCalc.gr(b).w);
    });
    _ac = AnimationController(vsync: this, duration: Duration(milliseconds: _totalMs));
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduce) {
      _ac.value = 1;
    } else {
      _ac.forward();
    }
    _ac.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _flipAll() => setState(() => _ac.value = 1);

  Widget _back(String id) {
    final gk = gradeOf[id];
    final glow = gk == 'legend'
        ? const Color(0xB3FFC23A)
        : gk == 'epic'
            ? const Color(0x99B07BFF)
            : null;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1B2246), Color(0xFF121833)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: glow == null ? null : [BoxShadow(color: glow, blurRadius: 14, spreadRadius: 1)],
        border: glow == null ? null : Border.all(color: glow, width: 2),
      ),
      child: kdImg('assets/game/ui/card_back.png', h: 70),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, c = g.calc, m = widget.m;
    final jn = _ids.where((id) => _can(id) && c.recStar(id) == 0).length, un = _ids.where((id) => _can(id) && c.recStar(id) > 0).length;
    final best = _ids.first;
    return KdSheetBody(
      eyebrow: widget.title,
      eyebrowColor: compColor(best),
      title: '카드를 받았어요!',
      children: [
        if (jn + un > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: const Color(0x1FFFC94A), border: Border.all(color: const Color(0x66FFC94A)), borderRadius: BorderRadius.circular(10)),
            child: Text.rich(
              TextSpan(children: [
                if (jn > 0) ...[const TextSpan(text: '합류 가능 '), TextSpan(text: '$jn명', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700))],
                if (jn > 0 && un > 0) const TextSpan(text: ' · '),
                if (un > 0) ...[const TextSpan(text: '★ 올리기 가능 '), TextSpan(text: '$un명', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700))],
              ]),
              textAlign: TextAlign.center,
              style: KdText.body(13),
            ),
          ),
        if (_ids.length > 1 && _ac.value < 1)
          Center(child: KdBuy(text: '모두 뒤집기', kind: BuyKind.ghost, small: true, minWidth: 0, onTap: _flipAll)),
        for (final (i, id) in _ids.indexed)
          AnimatedBuilder(
            animation: _ac,
            builder: (_, __) {
              final t = _t(i);
              final st = c.recStar(id), mx = st >= c.starMax(id), n = orNum(c.s.cardsW[id], 0).toInt(), need = c.starNeed(id) ?? 1, can = _can(id);
              final row = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KdColors.panel2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: can ? KdColors.gold : compColor(id), width: can ? 2 : 1),
                ),
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    CompFrame(id, w: 50, h: 60),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(color: compColor(id), borderRadius: BorderRadius.circular(8)),
                        child: Text('+${m[id]}', style: KdText.figure(12, color: const Color(0xFF1A1206))),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(comps[id]!.n, style: KdText.display(15)), GradeTag(id)]),
                      Text('${jobName[jobOf[id]]}${st > 0 ? ' · ${'★' * st}' : ' · 합류 전'}', style: _muted(12)),
                      if (mx)
                        Text('별을 모두 모았어요', style: _muted(12))
                      else ...[
                        const SizedBox(height: 3),
                        XpBar(math.min(1, n / need).toDouble()),
                        Text('$n / $need', style: _muted(12)),
                      ],
                    ]),
                  ),
                  if (can) ...[
                    const SizedBox(width: 6),
                    KdBuy(
                      text: st > 0 ? '★ 올리기' : '합류하기',
                      small: true,
                      glow: true,
                      minWidth: 0,
                      onTap: () {
                        final first = st == 0;
                        g.act((a) => a.recruitUp(id));
                        if (first) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ]),
              );
              // 앞 절반: 카드 뒷면이 접히고, 뒤 절반: 내용이 펼쳐짐 (웹 cbkout rotateY)
              if (t >= 1) return row;
              final front = t >= .6;
              final k = front ? ((t - .6) / .4) : 1 - t / .6;
              return Stack(children: [
                Opacity(opacity: front ? 1 : 0, child: row),
                if (!front) Positioned.fill(child: Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(k.clamp(0.0, 1.0), 1, 1), child: _back(id))),
              ]);
            },
          ),
        if (widget.gold > 0)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            uiImg('ui_gold', size: 20),
            const SizedBox(width: 6),
            Text.rich(TextSpan(children: [
              const TextSpan(text: '별을 다 채운 동료 카드 → 골드 '),
              TextSpan(text: '+${fmt(widget.gold)}', style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700)),
            ]), style: _muted(13)),
          ]),
      ],
      acts: KdActs(buttons: [
        if (widget.again == null) KdAct('닫기', onTap: () => Navigator.of(context).pop()),
        KdAct('원정대에서 보기', primary: widget.again == null, onTap: () {
          Navigator.of(context).pop();
          g.state.raw['ptTab'] = 'card';
          g.setTab(GameTab.pt);
        }),
        if (widget.again != null)
          KdAct('또 뽑기',
              primary: true,
              onTap: () {
                final i = widget.again!;
                g.toastClear();
                Navigator.of(context).pop();
                g.act((x) => x.buyCardPack(i));
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('또 뽑기', style: KdText.display(16, color: KdColors.goldInk)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  kdImg(gemIcon, w: 16, h: 16),
                  const SizedBox(width: 2),
                  Text(fmt(asNum(cardPacks[widget.again!]['gem'])), style: KdText.body(13, color: KdColors.goldInk, weight: FontWeight.w700)),
                ]),
              ])),
      ]),
    );
  }
}

// ════════════════════ 황금 고블린 아주 드문 전리품 (웹 gobRare 창) ════════════════════
Future<void> showGobRare(BuildContext ctx, GameController g, String t, String n) => showKdSheet<void>(ctx, closable: false, builder: (c) {
      final frame = t == 'frame';
      return KdSheetBody(
        eyebrow: '아주 드문 전리품!',
        eyebrowColor: const Color(0xFFFFD34A),
        title: '${frame ? '프로필 테두리' : '배지'} 「$n」',
        children: [
          Center(child: kdImg('assets/game/profile/${t}_goblin.png', w: 120, h: 120)),
          const Para('q@moved:황금 고블린이 이런 걸 숨기고 있었다니… 주인, 오늘은 운이 좋군.'),
          Text('프로필(얼굴 누르기)에서 ${frame ? '끼울' : '달'} 수 있어요', textAlign: TextAlign.center, style: _muted()),
        ],
        acts: KdActs(buttons: [
          KdAct('닫기', onTap: () => Navigator.of(c).pop()),
          KdAct('바로 ${frame ? '끼우기' : '달기'}', primary: true, onTap: () {
            g.state.raw[frame ? 'pf' : 'badge'] = 'goblin';
            g.calc.pfCheck();
            g.save();
            g.refresh();
            Navigator.of(c).pop();
          }),
        ]),
      );
    });

// ════════════════════ 설정 창의 계정 상자 (웹 acctBox) ════════════════════
class AccountBox extends StatefulWidget {
  const AccountBox(this.g, {super.key});
  final GameController g;

  @override
  State<AccountBox> createState() => _AccountBoxState();
}

class _AccountBoxState extends State<AccountBox> {
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.g.online.on) {
      widget.g.online.acctFetch().whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g, o = g.online;
    if (!o.on) return const KdNote('계정 기능을 준비하고 있어요.');
    if (_loading && o.acct == null) return const KdNote('계정을 확인하는 중…');
    final a = o.acct;
    if (a == null) return const KdNote('인터넷에 연결되면 계정을 확인할 수 있어요.');
    if (a.anon && Login.googleReady) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '지금은 '),
            const TextSpan(text: '게스트 계정', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.fg)),
            const TextSpan(text: '이에요. 휴대폰을 바꾸거나 앱을 지우면 기록이 사라질 수 있어요. 계정을 연결하면 '),
            const TextSpan(text: '황금 이삭 50', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.gold)),
            const TextSpan(text: '을 드려요. 웹에서 쓰던 구글 계정으로 연결하면 웹 기록도 불러올 수 있어요.'),
          ]),
          style: _muted(),
        ),
        const SizedBox(height: 6),
        KdBuy(minWidth: 0, text: '구글 계정 연결', onTap: () => o.loginWith('google')),
        if (Login.appleReady) ...[
          const SizedBox(height: 6),
          KdBuy(kind: BuyKind.ghost, minWidth: 0, text: 'Apple로 계속하기', onTap: () => o.loginWith('apple')),
        ],
      ]);
    }
    if (a.anon) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '지금은 '),
            const TextSpan(text: '게스트 계정', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.fg)),
            TextSpan(text: '이에요${o.nick != null ? ' (닉네임 「${o.nick}」)' : ''}. 휴대폰을 바꾸거나 앱을 지우면 기록이 사라질 수 있어요. '),
            const TextSpan(text: '구글·애플 계정 연결', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.fg)),
            const TextSpan(text: '은 다음 업데이트에서 열려요(연결 선물 '),
            const TextSpan(text: '황금 이삭 50', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.gold)),
            const TextSpan(text: '). 그전까지는 아래 저장 코드로 기록을 옮겨 두세요.'),
          ]),
          style: _muted(),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: '✅ '),
          const TextSpan(text: '계정 연결됨', style: TextStyle(fontWeight: FontWeight.w600, color: KdColors.fg)),
          if (a.email.isNotEmpty) TextSpan(text: ' · ${a.email}'),
          TextSpan(text: '\n클라우드 저장: ${agoText(g.state.raw['cloudAt'])} (3분마다 자동 저장)'),
        ]),
        style: _muted(),
      ),
      const SizedBox(height: 6),
      KdBuy(
        kind: BuyKind.ghost,
        minWidth: 0,
        text: '지금 클라우드에 저장',
        onTap: _saving
            ? null
            : () async {
                setState(() => _saving = true);
                await g.save();
                final ok = await o.cloudPut(true);
                g.toast(ok ? '클라우드에 저장했어요' : '저장하지 못했어요. 인터넷 연결을 확인해 주세요');
                if (mounted) setState(() => _saving = false);
              },
      ),
    ]);
  }
}


// ════════════════════ 어느 기록으로 할까요? (웹 cloudPick) ════════════════════
Future<void> showCloudPick(BuildContext ctx, GameController g, Map<String, dynamic> cl) => showKdSheet<void>(ctx, closable: false, builder: (c) {
      final s = g.state, data = (cl['data'] as Map).cast<String, dynamic>();
      Widget card(String t, num stage, num power, num gem, String when) => Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: KdColors.line)),
              child: Column(children: [
                Text(t, style: KdText.body(12, color: KdColors.gold, weight: FontWeight.w600)),
                Text(stgName(stage), style: KdText.display(20)),
                Text('전투력 ${fmt(power)} · 황금 이삭 ${fmt(gem)}', textAlign: TextAlign.center, style: _muted(12)),
                Text(when, style: _muted(12)),
              ]),
            ),
          );
      return KdSheetBody(
        eyebrow: '계정',
        title: '어느 기록으로 할까요?',
        children: [
          Text('이 계정에 저장된 기록이 있어요. 하나를 고르면 다른 쪽은 덮어써져요.', textAlign: TextAlign.center, style: _muted()),
          Row(children: [
            card('클라우드 기록', asNum(cl['stage']), asNum(cl['power']), asNum(cl['gem']), '${agoText(cl['updated_at'])} 저장'),
            const SizedBox(width: 8),
            card('이 기기 기록', math.min(s.stage, maxLand + 1), g.calc.power(), s.gem, '지금'),
          ]),
        ],
        acts: KdActs(buttons: [
          KdAct('이 기기 기록 유지', onTap: () async {
            Navigator.of(c).pop();
            await g.online.ensure();
            await g.online.cloudPut(true);
            g.toast('이 기기 기록을 클라우드에 저장했어요');
          }),
          KdAct('클라우드 기록 불러오기', primary: true, onTap: () {
            Navigator.of(c).pop();
            g.loadFromCode(data);
          }),
        ]),
      );
    });
