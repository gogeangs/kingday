// 왕도 아스테리온 · 1부 엔딩 (docs/content/CAPITAL.md)
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameCapitalX on GameController {
  /// 웹 capChapter()·capStory(): 처음 왕도 입장은 「왕도로 가는 길」 + 지역 소개, 다시 들어오면 알림 한 줄, 56·57 이야기
  void _capStory(String kind) {
    switch (kind) {
      case 'roadAgain':
        toast('왕도 아스테리온 진입 · 알현실까지 10곳');
      case 'road':
        final r = regions.last;
        scene('다섯 군단을 몰아내다', '왕도로 가는 길', const [
          'sys:다섯 군단이 모두 물러났다. 안개 너머로 왕도 아스테리온의 성벽이 보인다.',
          'q@moved:…300년 만이다. 저 성문 안에 주인의 왕좌가 있다.',
          'k:왕좌 말고 은퇴 서류는 없을까?',
          'q:왕이 되면 은퇴 서류는 주인이 직접 쓰면 된다.',
          'k@smile:…그 말, 이상하게 설득력 있네.',
        ], '성문으로 간다');
        scene('마지막 지역 · 왕도', r.n, [...r.lore, 'sys:이 땅의 지배자 · ${r.boss} · 홀수 영지는 군단장의 잔영, 짝수 영지는 마왕 근위대장'], '진격한다');
      case 'cap56':
        scene('왕립 도서관', '불탄 책장 사이', const ['sys:불탄 책장 사이에서 낡은 초상화를 발견했다. 성검을 든 젊은 왕.', 'q@moved:…이 얼굴은.', 'k:아는 사람이야?', 'q:……아니다. 가자.'], '계속 간다');
      case 'cap57':
        scene('왕비의 정원', '잔영이 흩어지다', const ['q@moved:알도르. 이번엔 편히 잠들어라.', 'k:…루미나르, 괜찮아?', 'q:괜찮다. 칼은 울지 않는다.'], '…가자');
    }
  }

  /// 엔딩 장면 → 「1부 완결」 창. 일러스트(illust_ending1·illust_ending2)는 들어오기 전엔 건너뜀
  Future<void> _ending(int i) async {
    if (i >= GameController._endingScenes.length) return _part1Sheet();
    final (eb, t, il, p, btn) = GameController._endingScenes[i];
    String? ill;
    if (il != null) {
      try {
        await rootBundle.load('assets/game/illust/illust_$il.jpg');
        ill = il;
      } catch (_) {}
    }
    scene(eb, t, p, btn, illust: ill, onGo: () => _ending(i + 1));
  }

  void _part1Sheet() {
    state.raw['ending1'] = 1;
    save();
    Widget row(Widget ic, String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 28, height: 28, child: ic),
            const SizedBox(width: 8),
            Expanded(child: Text(a, style: KdText.body(13, color: KdColors.muted))),
            Text(b, style: KdText.body(13, color: KdColors.gold, weight: FontWeight.w700)),
          ]),
        );
    queue((ctx) => showKdSheet<void>(ctx, closable: false, builder: (c) => KdSheetBody(
          eyebrow: '왕이 되는 그날까지 · 1부 「잃어버린 왕국」',
          title: '1부 완결',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x73FFC94A))),
              child: Column(children: [
                row(kdImg(gemIcon), '황금 이삭', '+$demonGem'),
                row(kdImg('assets/game/profile/frame_capital.png'), '프로필 테두리', '왕도의 별'),
                row(kdImg('assets/game/profile/badge_part1.png'), '배지', '1부 완결'),
                row(kdImg('assets/game/ui/${rankImg.last}.png'), '칭호', '왕도 탈환자 (+4%)'),
              ]),
            ),
            const Para('sys:이제 「왕궁 뜰」에서 보스 없이 사냥이 이어져요. 은퇴하고 다시 왕도를 되찾으면 회차마다 한 번 은퇴의 추억 +$capMem을 더 받아요.'),
            Text('2부 「흩어진 동맹」 — 엘프 왕국, 사막 제국, 북방 부족. 준비 중이에요.', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
          ],
          acts: KdActs(buttons: [
            KdAct('은퇴 계획 보기', onTap: () {
              Navigator.of(c).pop();
              setTab(GameTab.up);
            }),
            KdAct('계속 사냥하기', primary: true, onTap: () => Navigator.of(c).pop()),
          ]),
        )));
  }

  /// 웹 chapter(): 새 지역에 들어설 때 군단 소개
  void _chapter() {
    final st = state.stage, r = GameCalc.region(st), i = GameCalc.regionIndex(st);
    if (GameCalc.isCap(st)) {
      final k = truthy(state.done['capRoad']) ? 'roadAgain' : 'road';
      state.done['capRoad'] = true;
      return _capStory(k);
    }
    if (_quietStory) {
      toast('제${i + 1}군단 점령지 · ${r.n} 진입');
      return;
    }
    _rpAdd((
      face: 'assets/game/portraits/portrait_${bossIds[i]}_idle.png',
      eb: '제${i + 1}군단 · 점령지',
      t: r.n,
      p: [...r.lore, 'sys:이 땅의 지배자 · ${r.boss}'],
      btn: '진격한다',
      titleWidget: Column(children: [
        kdImg('assets/game/portraits/portrait_${bossIds[i]}_idle.png', w: 120, h: 120),
        Text(r.n, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Hahmlet', fontSize: 22, fontWeight: FontWeight.w700)),
      ]),
      go: null,
    ));
  }
}
