/// 피트의 상점 — 웹 #p-sh renderShop
/// 오늘의 할 일 · 피트의 무료 선물(광고) · 골드 바꾸기 · 동료 카드 · 특별 상품(첫 거래·정기 배송) · 황금 이삭 꾸러미
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/actions.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../game/controller.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String won(num n) => '₩${n.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

class ShopPage extends StatefulWidget {
  const ShopPage(this.g, {super.key});
  final GameController g;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  // 다 받은 묶음을 눌러 펼쳐 보기 (웹 misOpen · adOpen)
  bool _misOpen = false, _adOpen = false;
  final _jump = {for (final k in ['today', 'gold', 'card', 'pack']) k: GlobalKey()};

  GameController get g => widget.g;
  GameActions get a => g.acts;

  Widget _tag(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: KdColors.bad, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: KdText.body(10, color: Colors.white, weight: FontWeight.w600, height: 1.3)),
      );

  /// 웹 .mis
  Widget _row({required String title, Widget? sub, required Widget btn}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: KdText.body(13, weight: FontWeight.w600)),
              if (sub != null) ...[const SizedBox(height: 4), sub],
            ]),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 72), child: btn),
        ]),
      );

  /// 웹 .misdone: 다 받은 묶음 (누르면 펼침)
  Widget _done(String b, String sm, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x147BE08F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x597BE08F)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b, style: KdText.body(15, color: KdColors.good, weight: FontWeight.w600)),
            Text(sm, style: KdText.body(12, color: KdColors.muted)),
          ]),
        ),
      );

  /// 웹 .pack (3칸 격자 한 칸)
  Widget _pack({required Widget img, required String big, String? small, required Widget price, String? tag, required VoidCallback onTap, bool compact = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: EdgeInsets.fromLTRB(4, compact ? 6 : 8, 4, compact ? 8 : 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2A2A3E), KdColors.panel], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              border: Border.all(color: KdColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              SizedBox(height: compact ? 52 : 72, child: Center(child: img)),
              FittedBox(fit: BoxFit.scaleDown, child: Text(big, style: KdText.figure(15, color: const Color(0xFFFFE08A)))),
              SizedBox(
                height: 16,
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(small ?? '', style: KdText.body(compact ? 11.5 : 12, color: KdColors.good))),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(color: KdColors.gold, borderRadius: BorderRadius.circular(9)),
                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: price)),
              ),
            ]),
          ),
          if (tag != null) Positioned(top: -7, right: 6, child: _tag(tag)),
        ]),
      );

  Widget _grid(List<Widget> items, {double gap = 8}) => LayoutBuilder(builder: (_, c) {
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(spacing: gap, runSpacing: gap + 4, children: [for (final it in items) SizedBox(width: w, child: it)]);
      });

  Widget _gemPrice(num n) => Row(mainAxisSize: MainAxisSize.min, children: [
        kdImg(gemIcon, w: 16, h: 16),
        const SizedBox(width: 2),
        Text(fmt(n), style: KdText.figure(13, color: KdColors.goldInk)),
      ]);

  /// 웹 .shoprow
  Widget _shopRow({required String img, required String title, required Widget info, required Widget btn, bool hot = false, String? tag}) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2A2A3E), KdColors.panel], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              border: Border.all(color: hot ? KdColors.gold : KdColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              kdImg(img, w: 72, h: 72),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: KdText.display(15)),
                  DefaultTextStyle.merge(style: KdText.body(12, color: KdColors.muted, height: 1.5), child: info),
                ]),
              ),
              const SizedBox(width: 8),
              btn,
            ]),
          ),
          if (tag != null) Positioned(top: -8, left: 10, child: _tag(tag)),
        ],
      );

  Widget _anchor(String k) => SizedBox(key: _jump[k], height: 0, width: double.infinity);

  void _go(String k) {
    final ctx = _jump[k]!.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: .02);
  }

  @override
  Widget build(BuildContext context) {
    final s = g.state, c = g.calc, d = c.daily();
    final claim = asMap(d['claim']) ?? const <String, dynamic>{};
    final sub = a.sub, subOn = c.subOn(), gotToday = sub['last'] == c.today();
    final cardOk = GameCalc.cardIds().any(c.cardOpen);
    final adKeys = a.adKeys();

    Widget misRow(MissionDef m) {
      final v = math.min(orNum(d[m.k], 0), m.goal), done = truthy(claim[m.k]), can = a.misCan(m);
      return _row(
        title: m.n,
        sub: XpBar((v / m.goal).toDouble()),
        btn: KdBuy(
          minWidth: 72,
          text: done ? '받음' : can ? '+${fmt(m.r)} 받기' : '${fmt(v)} / ${fmt(m.goal)}',
          onTap: can ? () => g.act((x) => x.claimMission(m.k)) : null,
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (GameActions.testPay)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E2400),
            border: Border.all(color: KdColors.gold),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('시험판: 실제 결제 없이 누르면 바로 지급돼요. 스토어 결제를 붙이기 전까지만 이렇게 동작해요.',
              style: KdText.body(12, color: const Color(0xFFFFE08A), height: 1.5)),
        ),
      const SizedBox(height: 12),
      // 바로 가기 (웹 .shjump)
      Row(children: [
        for (final (k, n) in const [('today', '오늘'), ('gold', '골드'), ('card', '카드'), ('pack', '상품')]) ...[
          if (k != 'today') const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _go(k),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: KdColors.panel2, border: Border.all(color: KdColors.line), borderRadius: BorderRadius.circular(10)),
                child: Text(n, style: KdText.body(13, weight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      const Para('m:피트|어서 와, 형씨! 오늘도 진품만 들여놨어. …대부분.'),
      _anchor('today'),
      const SizedBox(height: 12),
      // ── 오늘의 할 일 ──
      if (truthy(claim['all']) && !_misOpen)
        _done('✓ 오늘의 할 일 완료', '내일 자정에 새 할 일이 열려요 · 눌러서 보기', () => setState(() => _misOpen = true))
      else ...[
        const KdSec('오늘의 할 일', small: '매일 자정에 새로 시작'),
        for (final m in missions) ...[misRow(m), const SizedBox(height: 8)],
        _row(
          title: '오늘의 할 일 모두 끝내기',
          btn: KdBuy(
            minWidth: 72,
            text: truthy(claim['all']) ? '받음' : '+$missionAllReward${a.misCan(null) ? ' 받기' : ''}',
            onTap: a.misCan(null) ? () => g.act((x) => x.claimMission('all')) : null,
          ),
        ),
      ],
      const SizedBox(height: 12),
      // ── 피트의 무료 선물 (광고) ──
      if (!adKeys.any((k) => c.adLeft(k) > 0) && !_adOpen)
        _done('✓ 피트의 무료 선물 모두 받음', '내일 자정에 다시 받을 수 있어요 · 눌러서 보기', () => setState(() => _adOpen = true))
      else ...[
        const KdSec('피트의 무료 선물', small: '광고를 보면 받아요 · 매일 자정 초기화'),
        for (final k in adKeys) ...[
          _row(
            title: ads[k]!.t,
            sub: Text('오늘 ${c.adLeft(k)} / ${ads[k]!.n}회 남음', style: KdText.body(11, color: KdColors.muted)),
            btn: KdBuy(
              kind: BuyKind.ad,
              minWidth: 72,
              text: '▶ 받기',
              onTap: c.adLeft(k) > 0
                  ? () => g.watchAd(k, () => g.act((x) {
                        if (k == 'box') {
                          x.adBoxGive();
                        } else if (k == 'gem') {
                          x.adGemGive();
                        } else {
                          x.adCardGive();
                        }
                      }))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
      _anchor('gold'),
      const SizedBox(height: 4),
      // ── 골드 바꾸기 ──
      const KdSec('골드 바꾸기', small: '지금 영지 기준 · 영지가 오를수록 더 많이'),
      _grid([
        for (var i = 0; i < goldExchanges.length; i++)
          _pack(
            img: kdImg('assets/game/ui/gold_pack${i + 1}.png', w: 72, h: 72),
            big: fmt(c.goldX(goldExchanges[i])),
            small: goldExchanges[i].n,
            price: _gemPrice(goldExchanges[i].gem),
            tag: i > 0 ? '${fmt(goldExchanges[i].h)}시간치' : null,
            onTap: () => g.act((x) => x.buyGoldX(goldExchanges[i].k)),
          ),
      ]),
      // ── 동료 카드 ──
      _anchor('card'),
      if (cardOk) ...[
        const SizedBox(height: 12),
        const KdSec('동료 카드', small: '3장은 무작위 · 30장은 한 동료로 영웅 이상'),
        _grid([
          for (var i = 0; i < cardPacks.length; i++)
            Builder(builder: (_) {
              final n = asNum(cardPacks[i]['n']).toInt();
              return _pack(
                img: Stack(clipBehavior: Clip.none, children: [
                  kdImg('assets/game/ui/card_pack${n >= 30 ? 30 : 3}.png', w: 64, h: 64),
                  Positioned(
                    right: -6,
                    bottom: 2,
                    child: Text('×$n', style: KdText.figure(14, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 3)])),
                  ),
                ]),
                big: '카드 $n장',
                small: n >= 30 ? '한 동료 30장 · 영웅 이상' : '무작위 3장',
                price: _gemPrice(asNum(cardPacks[i]['gem'])),
                tag: i > 0 ? '10% 이득' : null,
                onTap: () => g.act((x) => x.buyCardPack(i)),
              );
            }),
        ]),
      ],
      _anchor('pack'),
      const SizedBox(height: 12),
      // ── 특별 상품 ──
      const KdSec('특별 상품'),
      if (!truthy(a.buys['starter'])) ...[
        const SizedBox(height: 6),
        _shopRow(
          img: 'assets/game/relic/relic_weapon_3.png',
          title: starterPack['n'] as String,
          tag: '한 번만',
          hot: true,
          info: Text.rich(TextSpan(children: [
            const TextSpan(text: '전설 등급 성유물 1개 확정\n+ '),
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: kdImg(gemIcon, w: 16, h: 16)),
            TextSpan(text: '${starterPack['gem']}'),
          ])),
          btn: KdBuy(minWidth: 0, text: won(asNum(starterPack['won'])), onTap: () => g.act((x) => x.buyStarter())),
        ),
        const SizedBox(height: 10),
      ] else
        const SizedBox(height: 6),
      _shopRow(
        img: 'assets/game/gem/gem_pack_5.png',
        title: subscription['n'] as String,
        hot: subOn,
        info: subOn
            ? Text('남은 기간 ${a.subLeft()}일 · ${gotToday ? '오늘 배송 받음' : '오늘 배송이 도착했어요'}')
            : Text.rich(TextSpan(children: [
                const TextSpan(text: '구매 즉시 '),
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: kdImg(gemIcon, w: 16, h: 16)),
                TextSpan(text: '${subscription['now']} + 30일간 매일 '),
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: kdImg(gemIcon, w: 16, h: 16)),
                TextSpan(text: '${subscription['day']}\n방치 보상 +50%'),
              ])),
        btn: subOn
            ? KdBuy(minWidth: 0, text: gotToday ? '받음' : '+${subscription['day']} 받기', onTap: gotToday ? null : () => g.act((x) => x.claimSub()))
            : KdBuy(minWidth: 0, text: won(asNum(subscription['won'])), onTap: () => g.act((x) => x.buySub())),
      ),
      const SizedBox(height: 12),
      const KdSec('황금 이삭', small: '상품마다 첫 구매는 2배'),
      _grid(gap: 6, [
        for (var i = 0; i < gemPacks.length; i++)
          Builder(builder: (_) {
            final p = gemPacks[i], first = !truthy(a.buys[p.k]);
            return _pack(
              compact: true,
              img: kdImg('assets/game/gem/gem_pack_${i + 1}.png', w: 52, h: 52),
              big: fmt(p.gem),
              small: first ? '+${fmt(p.gem)} 보너스' : null,
              price: Text(won(p.won), style: KdText.figure(13, color: KdColors.goldInk)),
              onTap: () => g.act((x) => x.buyPack(p.k)),
            );
          }),
      ]),
      const SizedBox(height: 12),
      KdNote('황금 이삭 ${fmt(s.gem)}개 · 골드 바꾸기, 성유물 상자 10연속(장비 탭), 작물 바로 키우기·건물 바로 짓기(마을 탭), 방치 보상 2배 받기에 써요.'),
    ]);
  }
}
