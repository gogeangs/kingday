/// 도전 창 — 웹 chSheet(): 시련의 탑 카드 + 요일 던전 카드 (docs/content/CHALLENGE.md 4장)
library;

import 'package:flutter/material.dart';

import '../core/challenge.dart';
import '../core/fmt.dart';
import '../game/controller.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 도전 창 열기 (지도 탭 「⚔ 도전」)
Future<void> openChallenge(GameController g) async {
  final c = g.calc;
  if (!c.chCan() && !c.chOpen) {
    g.toast('영지 $chOpenLand을 되찾으면 열려요');
    return;
  }
  c.pkCheck();
  await g.openSheet((ctx) => ValueListenableBuilder<int>(valueListenable: g.ui, builder: (_, __, ___) => _ChSheet(g, ctx)));
}

class _ChSheet extends StatelessWidget {
  const _ChSheet(this.g, this.sheet);
  final GameController g;
  final BuildContext sheet;

  Widget _card(List<Widget> kids) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xE61E263C), Color(0xE6141A2A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: const Color(0x59FFC94A)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < kids.length; i++) ...[if (i > 0) const SizedBox(height: 6), kids[i]],
        ]),
      );

  Widget _head(String ic, String t, String k, String v) => Row(children: [
        Text(ic, style: const TextStyle(fontSize: 20, height: 1.1)),
        const SizedBox(width: 6),
        Text(t, style: KdText.display(16, color: const Color(0xFFFFE7A6))),
        const Spacer(),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$k '),
          TextSpan(text: v, style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700)),
        ]), style: KdText.body(12.5, color: const Color(0xFFCFD8EA))),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = g.calc, top = c.towerTop(), nx = towerInfo(top + 1), dl = c.dunLeft(), d = c.dunDay(), open = c.dunOpenK(), l = c.dunL();
    final adOk = !(d['ad'] == 1 || d['ad'] == true) && c.adLeft('dun') > 0;
    final tag = nx.gate ? ' · 수문장' : nx.rule >= 0 ? ' · 시련: ${towerRules[nx.rule].n}' : '';
    return KdSheetBody(
      titleWidget: SizedBox(
        height: 74,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: kdImg('assets/game/ui/hd_challenge.png')),
          Text('도전', style: KdText.display(20, color: const Color(0xFFFFE7A6)).copyWith(shadows: const [Shadow(blurRadius: 3, offset: Offset(0, 2))])),
        ]),
      ),
      children: [
        _memory(c.chPm(), c.pkPow()),
        _card([
          _head('🗼', '시련의 탑', '최고', '$top층'),
          Text.rich(TextSpan(children: [
            const TextSpan(text: '다음 '),
            TextSpan(text: nx.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: tag, style: TextStyle(color: nx.gate ? const Color(0xFFD6B4FF) : const Color(0xFFFFB36B), fontWeight: FontWeight.w700)),
          ]), style: KdText.body(13, height: 1.45)),
          Text('제한 ${nx.lim}초 · 처음 돌파하면 골드·광석${(top + 1) % 10 == 0 ? '·황금 이삭 $towerGem' : ''} · 실패해도 잃는 것 없음',
              style: KdText.body(11.5, color: KdColors.muted, height: 1.4)),
          Row(children: [
            Expanded(child: KdBuy(text: '도전하기', minWidth: 0, onTap: () => g.chainSheet(sheet, () => g.towerStart(top + 1)))),
            const SizedBox(width: 6),
            Expanded(
                child: KdBuy(
                    text: c.supplyCan() ? '🎁 탑 보급 받기' : '보급 받음 · 내일 다시',
                    minWidth: 0,
                    onTap: c.supplyCan() ? g.claimSupply : null)),
          ]),
          Text('탑 보급: 방치 보상 ${c.supplyMin()}분 어치 골드 + 광석 ${c.supplyOre()} (하루 1번, 최고 층이 높을수록 많이)',
              style: KdText.body(11.5, color: KdColors.muted, height: 1.4)),
        ]),
        _card([
          _head('📅', '요일 던전', '입장권', '$dl/${dunTk + (d['ad'] == 1 || d['ad'] == true ? 1 : 0)}'),
          for (final k in open) _dunRow(k, l, dl),
          Text('3분 동안 ${dunStars.join(' / ')}마리 → ★1 / ★2 / ★3. 별이 없으면 입장권을 돌려줘요. ★3 단계는 소탕 가능${c.weekday() == 0 ? ' · 일요일은 셋 다 열려요' : ''}',
              style: KdText.body(11.5, color: KdColors.muted, height: 1.4)),
          if (adOk) KdBuy(text: '▶ 광고 보고 입장권 +1', kind: BuyKind.ad, minWidth: 0, onTap: () => g.chainSheet(sheet, g.dunAd)),
        ]),
      ],
      acts: KdActs(buttons: [KdAct('닫기', primary: true, onTap: () => Navigator.of(sheet).pop())]),
    );
  }

  /// 추억 속 원정대 안내 (웹 .chpk)
  Widget _memory(num pm, num pk) {
    final on = pm >= pkShow;
    return Container(
      key: const ValueKey('chPk'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: on ? const Color(0x12FFC94A) : const Color(0x0AFFFFFF),
        border: Border.all(color: on ? const Color(0x73FFC94A) : const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: '🕯 '),
          const TextSpan(text: '추억 속 원정대', style: TextStyle(fontWeight: FontWeight.w700)),
          if (on) TextSpan(text: ' ×${pmText(pm)}', style: const TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700, fontSize: 15)),
        ]), textAlign: TextAlign.center, style: KdText.body(13)),
        Text('탑·던전에서는 지금 원정대와 역대 가장 강했던 원정대(전투력 ${fmt(pk)}) 중 센 쪽으로 싸워요. 은퇴해도 그대로예요',
            textAlign: TextAlign.center, style: KdText.body(11.5, color: KdColors.muted, height: 1.45)),
      ]),
    );
  }

  Widget _dunRow(String k, int l, int dl) {
    final c = g.calc, d = dunDef(k), st = c.dunStar(k, l);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(color: const Color(0x38000000), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 던전 카드 그림 (없으면 빠짐)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(aspectRatio: 3, child: Image.asset('assets/game/ui/dun_$k.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ),
        ),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${d.ic} ${d.n}', style: KdText.body(14, weight: FontWeight.w700)),
              Text('단계 $l · 최고 ${st > 0 ? '★' * st : '—'} · 보상 ${d.rw}', style: KdText.body(11.5, color: KdColors.muted)),
            ]),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            KdBuy(text: '입장', minWidth: 58, small: true, onTap: dl > 0 ? () => g.chainSheet(sheet, () => g.dunEnter(k)) : null),
            if (c.sweepOk(k)) ...[
              const SizedBox(width: 5),
              KdBuy(text: '소탕', minWidth: 58, small: true, kind: BuyKind.ghost, onTap: dl > 0 ? () => g.dunSweep(k) : null),
            ],
          ]),
        ]),
      ]),
    );
  }
}

/// 보상 칩 줄 (웹 rwHtml)
Widget rewardChips(Reward r) => Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
      for (final e in rewardNames.entries)
        if ((r[e.key] ?? 0) > 0)
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(10), border: Border.all(color: KdColors.line)),
            child: Column(children: [
              kdImg(e.value.$2, w: 32, h: 32),
              Text('+${fmt(r[e.key]!)}', style: KdText.figure(14, color: KdColors.gold)),
              Text(e.value.$1, style: KdText.body(11, color: KdColors.muted)),
            ]),
          ),
    ]);
