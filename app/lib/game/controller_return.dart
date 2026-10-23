// 출석·방치 보상 (다시 들어왔을 때)
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameReturnX on GameController {
  void attAuto() {
    final t = calc.today();
    if (_attShown == t || !attEligible(this) || acts.attStatusAt(t) != 'ok') return;
    _attShown = t;
    openAttend(this, queued: true);
  }

  /// 꺼 둔 동안 쌓인 골드를 바로 더하고, 창으로 알려 줌 (1분 미만이면 없음)
  void offline() {
    final r = calc.offlineReward();
    if (r.gold <= 0) return;
    state.gold = state.gold + r.gold;
    // 다시 돌아왔을 때 두 번 받지 않게
    state.last = DateTime.now().millisecondsSinceEpoch;
    queue((ctx) => _offlineSheet(ctx, r));
  }

  Future<void> _offlineSheet(BuildContext ctx, ({num sec, num cap, num gold}) r) => showKdSheet<void>(ctx, closable: false, builder: (c) {
        final g = r.gold, hr = (r.sec / 3600).floor(), mn = (r.sec % 3600 / 60).floor(), capH = (r.cap / 3600).round();
        final full = r.sec >= r.cap, adN = calc.adLeft('offline');
        void twice() {
          state.gold = state.gold + g;
          toast('세금 2배! 골드 +${fmt(g)}');
        }

        return KdSheetBody(
          illust: 'offline',
          eyebrow: '돌아온 카엘',
          title: '영지에서 세금이 걷혔어요',
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF29334F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC94A), width: 2),
              ),
              child: Column(children: [
                Text('${hr > 0 ? '$hr시간 ' : ''}$mn분 동안', style: KdText.body(12, color: const Color(0xFF97A2C3)).copyWith(letterSpacing: .7)),
                Text('+${fmt(g)}', style: KdText.display(28, color: const Color(0xFFFFC94A))),
                Text('백성들이 보낸 골드${truthy(state.bld['farm']) ? ' · 밭 작물도 자랐어요' : ''}',
                    textAlign: TextAlign.center, style: KdText.body(12, color: const Color(0xFF97A2C3))),
                const SizedBox(height: 4),
                Text('${full ? '⏳ 가득 참! ' : ''}최대 $capH시간 · 여관 레벨마다 +1시간${calc.tl('inn') != 0 ? ' · 넉넉한 여관 +${calc.tl('inn')}시간' : ''}',
                    textAlign: TextAlign.center, style: KdText.body(12, color: const Color(0xFFFFC94A))),
              ]),
            ),
            // 2배 받기는 작은 줄 두 개, 기본은 「받기」 하나 (웹 .dblrow, UX 점검 5)
            Row(children: [
              if (adN > 0) ...[
                Expanded(
                  child: _DblBtn(
                    text: '▶ 광고 2배',
                    sub: '· $adN회',
                    // 창을 닫고 「닫힌 다음」 광고를 띄움 (바로 부르면 창이 아직 열린 것으로 보여 광고가 안 뜸)
                    onTap: () => chainSheet(c, () => watchAd('offline', twice)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _DblBtn(
                  icon: gemIcon,
                  text: '이삭 $gemOffline로 2배',
                  onTap: () {
                    if (!acts.spendGem(gemOffline)) {
                      _flush();
                      return;
                    }
                    twice();
                    Navigator.of(c).pop();
                  },
                ),
              ),
            ]),
          ],
          acts: KdActs(buttons: [
            KdAct('받기', primary: true, onTap: () => Navigator.of(c).pop()),
          ]),
        );
      });
}
