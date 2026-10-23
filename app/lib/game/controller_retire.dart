// 할 일 길잡이 · 은퇴 · 은퇴 일기
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameRetireX on GameController {
  /// 웹 upGo(): 단련 탭을 열고 추천 줄을 반짝임
  void upGo() {
    upHintK = calc.upBest();
    upHintAt = DateTime.now().millisecondsSinceEpoch;
    if (tab != GameTab.up) setTab(GameTab.up);
  }

  /// 할 일을 누르면 그곳으로 (웹 guideNow().go). k: 'g0'~'g8' · 'up:..' · 'b:..'
  void guideGo(String k) {
    if (k.startsWith('up:')) return upGo();
    if (k.startsWith('b:')) return vlSelect(k.substring(2), tab: 'info');
    switch (int.tryParse(k.substring(1)) ?? -1) {
      case 0:
        hintBoxAt = DateTime.now().millisecondsSinceEpoch;
      case 1:
        upGo();
      case 8:
        setTab(GameTab.up);
      case 2:
        toast('원정대가 자동으로 싸워요. 막히면 장비와 단련을 올려요');
      case 3:
        vlSelect('inn');
      case 4:
        state.raw['ptTab'] = 'list';
        setTab(GameTab.pt);
      case 5 || 6:
        vlSelect('farm');
      case 7:
        setTab(GameTab.sh);
    }
  }

  void askRetire() {
    if (!calc.retCan()) return;
    scene('은퇴하기', '드디어 은퇴?', const ['k@smile:좋아, 이 정도면 충분해. 난 밭으로 돌아간다.', 'q@angry:주인! 아직 왕좌가…!'], '은퇴 준비하기',
        altLabel: '아직은 아니야', onGo: () => queue((ctx) => _retireConfirm(ctx)));
  }

  /// 웹 retireConfirm(one): 시작 영지(지름길)·받을 추억(회고록·보정)·비상금·씨앗 주머니·은퇴 횟수 보상 미리 보기
  Future<void> _retireConfirm(BuildContext ctx) {
    var one = false;
    return showKdSheet<void>(ctx, closable: false, builder: (c) => StatefulBuilder(builder: (c, setSt) {
          final s = state, eqN = s.eq.values.where(truthy).length, p = calc.retirePts();
          num up = 0;
          for (final v in s.up.values) {
            up = up + asNum(v);
          }
          final cl = [
            for (final e in s.lv.entries)
              if (calc.owned(e.key) && orNum(e.value, 0) > 1 && comps.containsKey(e.key)) '${comps[e.key]!.n} Lv.${e.value}'
          ];
          final sc = calc.tl('shortcut') > 0, st = calc.retStart(one), sb = calc.tl('seedbag'), purse = calc.retPurse(st);
          final half = sc && !one && 1 + 5 * calc.tl('shortcut') > (s.best / 2).floor();
          final rwN = s.retires.toInt() + 1, rwDone = asMap(s.raw['retRw']) ?? const <String, dynamic>{};
          RetReward? nextRw;
          for (final r in retRewards) {
            if (r.n == rwN && !truthy(rwDone['${r.n}'])) nextRw = r;
          }
          var nrank = 0; // 시작 영지 st 의 칭호 (웹 rankIdx({stage:st}))
          for (var j = 0; j < ranks.length; j++) {
            if ((st - 1 < maxLand ? st - 1 : maxLand) >= ranks[j].at) nrank = j;
          }
          Widget box(String head, Color col, List<Widget> body, {Color? border}) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF29334F),
                  borderRadius: BorderRadius.circular(12),
                  border: border != null ? Border.all(color: border) : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(head, style: KdText.body(13, color: col, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...body,
                ]),
              );
          Widget li(String a, String b) => Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x0FFFFFFF)))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a, style: KdText.body(13, color: const Color(0xFF97A2C3))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, textAlign: TextAlign.right, style: KdText.body(13, weight: FontWeight.w600))),
                ]),
              );
          Widget note(String t, [Color col = const Color(0xFF97A2C3)]) =>
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, style: KdText.body(12, color: col, height: 1.45)));
          final land = (s.stage < maxLand + 1 ? s.stage : maxLand + 1) - 1;
          const gold = TextStyle(color: Color(0xFFFFD34A), fontWeight: FontWeight.w700);
          return KdSheetBody(
            eyebrow: '은퇴 확인',
            eyebrowColor: const Color(0xFFFF8A7A),
            title: '정말 은퇴할까요?',
            children: [
              box('처음으로 돌아가요', const Color(0xFFFF8A7A), border: const Color(0x80FF8A7A), [
                li('되찾은 영지', '$land곳 → ${st - 1}곳 (${stgName(st)}부터)'),
                li('골드', '${fmt(s.gold)} → ${fmt(60 + purse)}'),
                li('착용한 성유물', '$eqN개 → 모두 사라짐'),
                li('단련 능력치', up > 0 ? '+${fmt(up)}단계 → 0' : '없음'),
                li('동료 레벨', cl.isNotEmpty ? '${cl.join(', ')} → Lv.1' : '모두 Lv.1'),
                li('칭호', '${ranks[calc.rankIdx()].n} → ${ranks[nrank].n}'),
                if (sc) ...[
                  const SizedBox(height: 6),
                  Text.rich(TextSpan(children: [
                    const TextSpan(text: '🎒 지름길: '),
                    TextSpan(text: '영지 $st', style: const TextStyle(color: Color(0xFF9FE0A6), fontWeight: FontWeight.w700)),
                    const TextSpan(text: '부터 시작'),
                    if (half) const TextSpan(text: ' (최고 영지의 절반까지)', style: TextStyle(fontSize: 11, color: Color(0xFF97A2C3))),
                  ]), style: KdText.body(13)),
                  GestureDetector(
                    key: const ValueKey('rtOne'),
                    onTap: () => setSt(() => one = !one),
                    child: Row(children: [
                      Checkbox(value: one, onChanged: (v) => setSt(() => one = v ?? false), visualDensity: VisualDensity.compact),
                      Text('영지 1부터 시작', style: KdText.body(13, color: const Color(0xFF97A2C3))),
                    ]),
                  ),
                ],
              ]),
              box('그대로 남아요', const Color(0xFF9BE3C0), [
                Text('마을 건물·밭·재료, 동료 합류와 모집 동료의 카드·별, 대장간 강화, 성유물 상자 레벨, 황금 이삭, 프로필 테두리·배지, 은퇴 일기 특성',
                    style: KdText.body(13, height: 1.5)),
              ]),
              box('얻는 것', const Color(0xFFFFD34A), border: const Color(0x80FFD23C), [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '은퇴의 추억 '),
                    TextSpan(text: '+$p개', style: gold),
                    if (calc.tl('memoir') > 0) TextSpan(text: ' (회고록 +${10 * calc.tl('memoir')}% 포함)', style: const TextStyle(fontSize: 11)),
                    const TextSpan(text: ' → 모든 능력치·골드 획득 '),
                    TextSpan(text: '+${fmt((s.memory + p) * 5)}%', style: gold),
                    TextSpan(text: ' (지금 +${fmt(s.memory * 5)}%), 영구 적용 · 추억 포인트 '),
                    TextSpan(text: '+$p', style: gold),
                  ]),
                  style: KdText.body(13, height: 1.5),
                ),
                if (truthy(s.raw['capBonus'])) note('👑 이번 회차 왕도 재탈환 보너스 +$capMem은 이미 받았어요'),
                if (calc.runStart > 10) note('지름길로 건너뛴 구간(영지 ${calc.runStart} 앞)의 추억은 빼고 쳐요'),
                if (sb > 0 || purse > 0)
                  note('은퇴 직후 받음: ${[
                    if (purse > 0) '비상금 골드 +${fmt(purse)}',
                    if (sb > 0) '씨앗 밀 ${10 * sb} · 은빛 당근 ${5 * sb} · 달빛 호박 ${2 * sb}',
                  ].join(' · ')}'),
                if (nextRw != null) note('🎉 은퇴 $rwN회 보상: 황금 이삭 +${nextRw.gem}${nextRw.t != null ? ' · ${nextRw.t}' : ''}', const Color(0xFFFFD34A)),
              ]),
            ],
            acts: KdActs(buttons: [
              KdAct('취소', onTap: () => Navigator.of(c).pop()),
              KdAct('은퇴 확정', danger: true, onTap: () {
                Navigator.of(c).pop();
                _retire(calc.retirePts(), one);
              }),
            ]),
          );
        }));
  }

  /// 웹 retire(p, one): 처음부터 다시 + 추억 + 지름길·비상금·씨앗 주머니 + 은퇴 횟수 보상 + 회차별 「몇 년 뒤」 장면 + 첫 지역 소개
  void _retire(int p, [bool one = false]) {
    if (sim.ch != null) sim.chExit();
    final st = calc.retStart(one), pg = calc.retPurse(st), sb = calc.tl('seedbag');
    calc.retire(p, one);
    sim.party.clear();
    sim.mons = [];
    sim.syncParty();
    final rw = calc.retRwCheck();
    calc.pfCheck();
    save();
    final n = state.retires.toInt(), sc = retScenes[n];
    final extra = [if (st > 1) '지름길로 영지 $st부터 다시 출발!', if (pg > 0) '비상금 골드 +${fmt(pg)}', if (sb > 0) '씨앗 주머니 받음'];
    final quiet = _quietStory && sc == null;
    if (quiet) {
      toast('은퇴의 추억 +$p · ${extra.isNotEmpty ? extra.first : '다시 출발!'}');
    } else {
      scene('몇 년 뒤', '…다시 끌려 나오다', sc ?? retDefault, '괭이 대신 검을 든다', illust: 'retire');
      if (extra.isNotEmpty) queue((_) async => toast(extra.join(' · ')));
    }
    act((a) => a.chiefCheck());
    if (rw != null) queue((_) async => toast(retRwText(rw)));
    if (!_quietStory) _chapter();
    _rpFlush();
    act((a) => a.primalIntro());
    refresh();
  }

  /// 은퇴 일기 열기: 처음이면 대사 먼저 (웹 diaryOpen)
  void openDiary() {
    if (!truthy(state.raw['diaryIntro'])) {
      state.raw['diaryIntro'] = 1;
      save();
      scene('은퇴 일기', '카엘의 은퇴 일기', diaryIntroLines, '일기 펼치기', onGo: () => _next = () => openDiarySheet(this));
      return;
    }
    openDiarySheet(this);
  }

  /// 특성 한 단계 찍기 (웹 trBuy)
  void trBuy(String k) {
    final l = calc.trBuy(k);
    if (l == null) return;
    toast('${memT(k)!.n} $l단계!');
    haptic(const [20]);
    save();
    refresh();
  }

  /// 특성 초기화: 첫 1번 무료, 그다음 황금 이삭 100 (웹 trResetAsk). 했으면 true
  bool trReset() {
    final gcost = calc.trResetGem();
    if (gcost > 0 && !acts.spendGem(gcost)) return false;
    final back = calc.trSpent();
    state.raw['trait'] = <String, dynamic>{};
    state.raw['trReset'] = orNum(state.raw['trReset'], 0) + 1;
    toast('추억 포인트 $back 돌려받음');
    save();
    refresh();
    return true;
  }

  /// 두 번째 은퇴부터는 다시 나오는 이야기 창(은퇴 직후·지역 이야기·칭호 상승)을 알림 한 줄로 (웹 quietStory)
  bool get _quietStory => orNum(state.raw['retires'], 0) >= 2;
}
