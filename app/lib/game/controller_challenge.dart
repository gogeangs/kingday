// 도전: 시련의 탑 · 요일 던전 (docs/content/CHALLENGE.md)
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameChallengeX on GameController {
  /// 영지 20 탈환 때 한 번: 해금 대사 (웹 chCheck)
  void chCheck() {
    if (calc.chOpen || !calc.chCan()) return;
    state.raw['chOpen'] = 1;
    save();
    void mpDot() {
      // 「나중에」: 지도 탭에 빨간 점 (웹 dotSeen2.mp 지움, 3회차 리뷰 13)
      asMap(state.raw['dotSeen2'])?.remove('mp');
      refresh();
    }

    // 다른 새 소식과 같은 때 생기면 「새 소식」 한 장으로 (웹 chCheck nwAdd)
    _nwAdd(
      (
        face: 'assets/game/portraits/portrait_luminar_proud.png',
        eb: '새로운 도전',
        t: '시련의 탑 · 요일 던전',
        p: const [
          'q:시련의 탑이다. 300년 전 에르단의 왕들은 왕관을 쓰기 전에 이 탑을 올랐지.',
          'm:브론|탑 말고 내 폐광도 좀 봐 줘. 요일마다 광석이 쏟아진다고.',
          'sys:지도 탭의 「⚔ 도전」에서 시련의 탑과 요일 던전에 들어갈 수 있어요.',
        ],
        btn: '도전 보러 가기',
        titleWidget: null,
        go: () => openChallenge(this),
      ),
      later: mpDot,
      one: () => scene('새로운 도전', '시련의 탑', const [
      'sys:들판 끝에 오래된 석탑이 서 있다. 꼭대기가 구름에 가려 보이지 않는다.',
      'q:시련의 탑이다. 300년 전 에르단의 왕들은 왕관을 쓰기 전에 이 탑을 올랐지.',
      'k:꼭대기가 어디야?',
      'q:없다. 오를수록 높아진다.',
      'k@flustered:…그럼 은퇴는 언제 해?',
      'm:브론|탑 말고 내 폐광도 좀 봐 줘. 요일마다 광석이 쏟아진다고.',
      'sys:지도 탭의 「⚔ 도전」에서 시련의 탑과 요일 던전에 들어갈 수 있어요.',
      ], '나중에 (지도에서 보기)', altLabel: '도전 보러 가기', onAlt: () => openChallenge(this), onGo: mpDot),
    );
  }

  /// 지도 탭·도전 버튼 노란 점
  bool get chDot => calc.chDot();

  void _chShow() {
    if (tab != null) setTab(null);
    frame.value++;
    refresh();
  }

  void towerStart(int f) {
    sim.towerStart(f);
    _chShow();
  }

  /// 던전 입장: 처음이면 소개 대사 → 입장권 1장 쓰고 3분 전투 (웹 dunEnter)
  void dunEnter(String k) {
    if (!calc.dunOpenK().contains(k)) return toast('오늘은 열리지 않는 던전이에요');
    if (calc.dunLeft() <= 0) return toast('오늘 입장권을 다 썼어요');
    void go() {
      if (calc.dunLeft() <= 0) return;
      final d = calc.dunDay();
      d['used'] = orNum(d['used'], 0) + 1;
      sim.dunStart(k);
      save();
      _chShow();
    }

    final seen = asMap(calc.dunS['seen'])!;
    if (!truthy(seen[k])) {
      seen[k] = 1;
      final dd = dunDef(k);
      scene('요일 던전', dd.n, [dd.intro, 'sys:3분 동안 몰려오는 마물을 잡아요. ${dunStars.join(' / ')}마리를 잡으면 ★1 / ★2 / ★3.'], '입장하기', onGo: go);
    } else {
      go();
    }
  }

  /// 소탕: 입장권 1장으로 ★3 보상 바로 받기
  void dunSweep(String k) {
    if (!calc.sweepOk(k)) return;
    if (calc.dunLeft() <= 0) return toast('오늘 입장권을 다 썼어요');
    final d = calc.dunDay();
    d['used'] = orNum(d['used'], 0) + 1;
    final r = calc.dunReward(k, calc.dunL(), 1, false);
    calc.rwGive(r);
    save();
    sound('coin');
    toast('${dunDef(k).n} 소탕 ★3! ${rewardText(r)}');
    refresh();
  }

  void claimSupply() {
    final r = calc.claimSupply();
    if (r == null) return;
    save();
    sound('coin');
    toast('탑 보급 도착! 골드 +${fmt(r.$1)} · 광석 +${r.$2}');
    refresh();
  }

  /// 광고 보고 입장권 +1 (하루 1번) → 도전 창 다시
  Future<void> dunAd() async {
    await watchAd('dun', () {
      calc.dunDay()['ad'] = 1;
      toast('던전 입장권 +1');
    });
    openChallenge(this);
  }

  /// 위쪽 「나가기」: 탑은 그 층 실패로 바로 나감, 던전은 그때까지 잡은 수로 정산
  void chExitTap() {
    final h = sim.ch;
    if (h == null) return;
    if (h.mode == 'dun' && h.st == 'fight') {
      sim.dunEnd();
      _drainEvents();
    } else {
      sim.chExit();
      toast('영지 탈환전으로 돌아왔어요');
    }
    frame.value++;
    refresh();
  }

  void chNextTap() {
    final h = sim.ch;
    if (h != null && h.mode == 'tower' && h.st == 'win') towerStart(h.f + 1);
  }

  Future<void> _towerWinSheet(BuildContext ctx, int f, bool first, Reward r, List<String> unlocked) async {
    final h = sim.ch;
    if (h == null || h.mode != 'tower' || h.f != f || h.st != 'win') return;
    final nx = towerInfo(f + 1);
    await showKdSheet<void>(ctx, closable: false, builder: (c) => KdSheetBody(
          eyebrow: '시련의 탑',
          title: '$f층 돌파!',
          children: [
            if (first) rewardChips(r) else const KdNote('이미 받은 층이에요', center: true),
            if (unlocked.isNotEmpty) Text('🎉 ${unlocked.join(' · ')} 획득! 프로필에서 쓸 수 있어요', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.gold)),
            if (f == 50) ...const [Para('q@proud:반은 왔다. …아니, 끝이 없으니 반은 아니군.'), Para('k:그 말은 위로야, 협박이야?')],
            KdNote('다음: ${nx.name}${nx.gate ? ' · 수문장' : nx.rule >= 0 ? ' · 시련: ${towerRules[nx.rule].n}' : ''}', center: true),
          ],
          acts: KdActs(buttons: [
            KdAct('나가기', onTap: () {
              Navigator.of(c).pop();
              sim.chExit();
              toast('영지 탈환전으로 돌아왔어요');
            }),
            KdAct('다음 층 ▶', primary: true, onTap: () {
              Navigator.of(c).pop();
              towerStart(f + 1);
            }),
          ]),
        ));
  }

  Future<void> _towerLoseSheet(BuildContext ctx, int f) async {
    final h = sim.ch;
    if (h == null || h.mode != 'tower' || h.f != f) return;
    await showKdSheet<void>(ctx, closable: false, builder: (c) => KdSheetBody(
          eyebrow: '시련의 탑',
          title: '$f층 실패',
          children: const [KdNote('원정대를 키워서 다시 와요\n도전은 몇 번이든 할 수 있고, 잃는 건 없어요', center: true)],
          acts: KdActs(buttons: [
            KdAct('나가기', onTap: () {
              Navigator.of(c).pop();
              sim.chExit();
            }),
            KdAct('다시 도전', primary: true, onTap: () {
              Navigator.of(c).pop();
              towerStart(f);
            }),
          ]),
        ));
  }

  Future<void> _dunEndSheet(BuildContext ctx, DunEndEvent e) => showKdSheet<void>(ctx, closable: false, builder: (c) => KdSheetBody(
        eyebrow: '${dunDef(e.k).n} · 단계 ${e.l}',
        title: e.star > 0 ? '${'★' * e.star}${'☆' * (3 - e.star)} · ${e.kills}마리 처치' : '한 마리도 못 잡았어요',
        children: [
          if (e.star > 0 && e.r != null) rewardChips(e.r!) else const KdNote('입장권은 돌려드릴게요', center: true),
          if (e.star > 0 && e.gob && e.k == 'vault') Text('황금 고블린 보너스 +20%', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.gold)),
          if (e.newStar3) const KdNote('이 단계는 이제 「소탕」으로 바로 받을 수 있어요', center: true),
        ],
        acts: KdActs(buttons: [
          KdAct('도전 창', onTap: () => chainSheet(c, () => openChallenge(this))),
          KdAct('확인', primary: true, onTap: () => Navigator.of(c).pop()),
        ]),
      ));

  /// 웹 intro(): 새 게임 프롤로그 → 첫 지역 소개
  void _intro() {
    scene('왕이 되는 그날까지 · 프롤로그', '밭에 박힌 쇠막대', const [
      '마계의 문이 열려 왕국이 무너진 날, 농부 카엘은 밭에 박힌 녹슨 쇠막대를 뽑아 마물을 막아 냈다.',
      'q@moved:…드디어 나를 뽑는 자가 나타났군. 300년 기다렸다, 주인. 이제 왕이 되러 가자.',
      'k@surprised:누구세요? 그리고 전 농부인데요.',
      'sys:빼앗긴 영지를 되찾고, 동료를 모아 마을을 다시 세우세요.',
    ], '일단 마을부터 지키자', illust: 'prologue');
    _chapter();
    _rpFlush();
  }
}
