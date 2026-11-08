// 2부 「흩어진 동맹」 (docs/content/PART2.md) — 웹 p2Check·p2IntroScene·p2Title·p2LoreScene·p2Chapter·
// p2FreeScene·allySheet·ending2Scene·part2Sheet 를 옮김. 장수 처치의 저장 변화(웹 p2Win)는 battle/sim.dart _p2Win.
part of 'controller.dart';

extension GameP2X on GameController {
  static String _bossFace(RegionDef r) => 'assets/game/map/${r.p2}_boss.png';

  Widget _p2Head(String img, String t) => Column(children: [
        kdImg(img, w: 120, h: 120),
        Text(t, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Hahmlet', fontSize: 22, fontWeight: FontWeight.w700)),
      ]);

  /// 그림(illust_<k>.jpg)이 들어 있으면 그 이름, 없으면 null (웹 scene 의 그림 칸)
  Future<String?> _illOk(String? k) async {
    if (k == null) return null;
    try {
      await rootBundle.load('assets/game/illust/illust_$k.jpg');
      return k;
    } catch (_) {
      return null;
    }
  }

  /// 2부 시작 장면: 1부 마왕을 쓰러뜨리고 61 이상에 있는데 아직 못 봤으면 1번 (1부 완결 창을 닫을 때 · 예전 세이브는 게임을 열 때)
  void p2Check() {
    final s = state;
    if (!p2On || truthy(s.raw['p2Intro']) || s.stage <= maxLand || !(asNum(s.raw['capClears']) > 0 || truthy(s.raw['ending1']))) return;
    s.raw['p2Intro'] = 1;
    save();
    _p2Intro();
  }

  Future<void> _p2Intro() async {
    final il = await _illOk('part2');
    scene('2부 시작', '바다 건너 온 편지', const [
      'sys:왕도를 되찾은 지 사흘째. 왕궁 뒤뜰 밭에 첫 싹이 올라왔다.',
      'k@smile:이제 진짜 은퇴만 남았…',
      'sys:그때, 갈매기 한 마리가 카엘의 밀짚모자 위에 편지를 떨어뜨렸다.',
      'q:엘프 왕국의 문장이다. 바다 건너에서 온 구조 요청이로군.',
      'm:하랄|바다라면 내가 길잡이지! 어험, 크라켄 정도는 내가—',
      'q:주인, 발타사르는 마계에 있다. 혼자서는 그 문을 넘을 수 없다. 대륙의 힘을 모아야 한다.',
      'k@flustered:…은퇴하려면 동맹부터 만들어야 한다는 거지?',
    ], '바다를 건넌다', illust: il, onGo: _p2Title);
  }

  /// 큰 제목 창 「흩어진 동맹」 → 지금 2부 나라에 있으면 그 나라 이야기
  void _p2Title() {
    queueFirst((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, builder: (c) => KdSheetBody(
              children: [
                const SizedBox(height: 18),
                Text('왕이 되는 그날까지', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted, weight: FontWeight.w700)),
                Text('2부', textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.gold, weight: FontWeight.w700)),
                Text('「흩어진 동맹」', textAlign: TextAlign.center, style: KdText.display(28, color: const Color(0xFFFFE08A))),
                const SizedBox(height: 8),
                Text('엘프 왕국 · 사막 제국 · 북방 부족\n마왕군에게 점령당한 세 나라를 해방해 동맹을 모으세요.',
                    textAlign: TextAlign.center, style: KdText.body(13, color: KdColors.muted, height: 1.6)),
                const SizedBox(height: 18),
              ],
              acts: KdActs(buttons: [
                KdAct('출발', primary: true, onTap: () {
                  Navigator.of(c).pop();
                  final st = state.stage;
                  if (st > maxLand && st <= land) _p2Lore(st, first: true);
                }),
              ]),
            ));
      } finally {
        _sceneDone();
      }
    });
  }

  /// 나라 이야기 창 (웹 p2LoreScene)
  void _p2Lore(int st, {bool first = false}) {
    final r = GameCalc.region(st);
    scene('바다 건너 · 마왕군 점령지', r.n, [...r.lore, 'sys:이 나라를 점령한 장수 · ${r.boss} · 쓰러뜨리면 나라가 해방되고 동맹이 돼요'], '진격한다',
        titleWidget: _p2Head(_bossFace(r), r.n), first: first);
  }

  /// 2부 나라에 들어갈 때 (영지 61·71·81): 지역 이야기 창. 2부 시작 장면 전이면 시작 장면이 끝난 뒤(_p2Lore) 보여 줌
  void _p2Chapter(int st) {
    final r = GameCalc.region(st);
    if (!truthy(state.raw['p2Intro'])) return;
    if (_quietStory) {
      toast('${r.n} 진입 · ${r.boss.split(' ').last}까지 10곳');
      return;
    }
    final face = _bossFace(r);
    _rpAdd((
      face: face,
      eb: '바다 건너 · 마왕군 점령지',
      t: r.n,
      p: [...r.lore, 'sys:이 나라를 점령한 장수 · ${r.boss} · 쓰러뜨리면 나라가 해방되고 동맹이 돼요'],
      btn: '진격한다',
      titleWidget: _p2Head(face, r.n),
      go: null,
    ));
  }

  /// 나라 장수 처치 뒤 화면 (웹 p2Win 의 화면 쪽): 처음이면 해방 장면 → 「동맹이 되었어요」, 다시면 추억 알림
  void _p2Won(AllyDef a, bool first, int bonus) {
    if (first) {
      save();
      _p2Free(a);
    } else if (bonus > 0) {
      Timer(const Duration(milliseconds: 2600), () => toast('${a.n} 재해방 보너스! 은퇴의 추억 +$bonus'));
    }
  }

  void _p2Free(AllyDef a) {
    final f = asMap(wP2free[a.k])!;
    scene('${a.n} 해방', f['t'] as String, (f['p'] as List).cast<String>(), '손을 잡는다',
        titleWidget: _p2Head('assets/game/portraits/portrait_${a.face}_idle.png', f['t'] as String), onGo: () => _allySheet(a));
  }

  /// 「동맹이 되었어요」 창 (웹 allySheet)
  void _allySheet(AllyDef a) {
    Widget row(Widget ic, String x, String y) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 28, height: 28, child: ic),
            const SizedBox(width: 8),
            Expanded(child: Text(x, style: KdText.body(13, color: KdColors.muted))),
            Text(y, textAlign: TextAlign.right, style: KdText.body(13, color: KdColors.gold, weight: FontWeight.w700)),
          ]),
        );
    queueFirst((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, builder: (c) => KdSheetBody(
              eyebrow: '${a.n} 해방',
              title: '동맹이 되었어요',
              children: [
                Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: FaceImg(a.face, mood: 'laugh'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.king, style: KdText.display(16)),
                      Text(a.t, style: KdText.body(12, color: KdColors.muted)),
                    ]),
                  ),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x73FFC94A))),
                  child: Column(children: [
                    row(const Center(child: Text('🤝', style: TextStyle(fontSize: 18))), '동맹 보너스', a.b.replaceFirst(' +', '\n+')),
                    row(kdImg(gemIcon), '황금 이삭', '+$p2Gem'),
                  ]),
                ),
                Para('sys:동맹 보너스는 영구예요. 은퇴해도 그대로 남아요. 은퇴하고 다시 이 나라를 해방하면 회차마다 한 번 은퇴의 추억 +$p2Mem을 더 받아요.'),
              ],
              acts: KdActs(buttons: [
                KdAct('함께 간다', primary: true, onTap: () {
                  Navigator.of(c).pop();
                  // 마지막 나라(북방)를 처음 해방하면 이어서 2부 엔딩
                  if (a.boss == p2Last && !truthy(state.raw['ending2'])) {
                    _ending2(0);
                  } else if (state.stage > land && land < p2Last) {
                    Timer(const Duration(milliseconds: 400), () => toast('바다 안개가 짙어요. 곧 열려요'));
                  }
                }),
              ]),
            ));
      } finally {
        _sceneDone();
      }
    });
  }

  /// 2부 엔딩 장면 → 「2부 완결」 창 (웹 ending2Scene)
  Future<void> _ending2(int i) async {
    if (i >= wEnding2.length) return _part2Sheet();
    final e = asMap(wEnding2[i])!;
    final il = await _illOk(e['il'] as String?);
    scene(e['eb'] as String, e['t'] as String, (e['p'] as List).cast<String>(), e['btn'] as String,
        illust: il, first: true, onGo: () => _ending2(i + 1));
  }

  void _part2Sheet() {
    state.raw['ending2'] = 1;
    calc.pfCheck();
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
    queueFirst((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, closable: false, builder: (c) => KdSheetBody(
              eyebrow: '왕이 되는 그날까지 · 2부 「흩어진 동맹」',
              title: '2부 완결',
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x73FFC94A))),
                  child: Column(children: [
                    row(kdImg(gemIcon), '황금 이삭', '+$p2Gem'),
                    row(const Center(child: Text('⚔', style: TextStyle(fontSize: 18))), '맹주 보너스', '원정대 공격 +10%'),
                    row(kdImg('assets/game/profile/frame_alliance.png'), '프로필 테두리', '연합의 깃발'),
                    row(kdImg('assets/game/profile/badge_part2.png'), '배지', '2부 완결'),
                    row(kdImg('assets/game/ui/${rankImg[ranks.length - 1]}.png'), '칭호', '연합군 맹주 (+4%)'),
                  ]),
                ),
                Para('sys:이제 「연합군 진영」에서 보스 없이 사냥이 이어져요. 동맹 보너스는 은퇴해도 남고, 은퇴하고 다시 나라를 해방하면 회차마다 나라마다 한 번 은퇴의 추억 +$p2Mem을 더 받아요.'),
                Text('3부 「마계 원정」 — 일곱 마왕이 기다려요. 준비 중이에요.', textAlign: TextAlign.center, style: KdText.body(12, color: KdColors.muted)),
              ],
              acts: KdActs(buttons: [
                KdAct('은퇴 계획', onTap: () {
                  Navigator.of(c).pop();
                  retGo();
                }),
                KdAct('계속하기', primary: true, onTap: () => Navigator.of(c).pop()),
              ]),
            ));
      } finally {
        _sceneDone();
      }
    });
  }

  /// 게임을 열 때 (웹 start): 61 「왕궁 뜰」에 있던 예전 세이브 → 2부 시작 장면 · 웹 1차 저장 71 바다 안개 → 사막 이야기
  void _p2Boot() {
    p2Check();
    final m = GameState.p2Mig;
    if (m != 0 && truthy(state.raw['p2Intro']) && state.stage == m) _p2Lore(m);
    GameState.p2Mig = 0;
  }
}
