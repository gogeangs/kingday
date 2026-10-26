// 광고 보상 · 장비 창 · 전투가 보낸 일 처리
// (game/controller.dart 의 GameController 에서 옮겨 옴 — 상태(필드)는 클래스에 그대로)
part of 'controller.dart';

extension GameAdsX on GameController {
  /// 상자 열기 (빠른 버튼·장비 탭)
  void openBox({bool auto = false}) {
    _peteAuto = auto;
    act((a) => a.openBox(auto));
  }

  /// 원정대 교체: 나간 동료의 체력 비율을 이어받고 스킬 게이지는 처음부터 (웹 setMember)
  void _swap(String cur, String id) {
    final p = sim.party[cur];
    if (p == null) return;
    final r = p.down ? 0 : p.hp / calc.stats(cur).hp;
    sim.party.remove(cur);
    sim.party[id] = Member(hp: calc.stats(id).hp * (r < 0 ? 0 : r), cd: .5)..down = r <= 0;
  }

  /// 장비 비교 창 (웹 showItem) — 고르기 전에는 닫히지 않음
  /// 약한 장비를 10번 팔면 한 번만 「약한 장비는 바로 팔까요?」 (웹 sellAsk, 3회차 리뷰 12 · done.sellN·sellAsk)
  void _sellAsk() {
    final d = state.done;
    if (truthy(state.raw['autoSell']) || truthy(d['sellAsk'])) return;
    d['sellN'] = orNum(d['sellN'], 0) + 1;
    if (orNum(d['sellN'], 0) < 10) return;
    d['sellAsk'] = 1;
    scene('피트의 제안', '약한 장비는 바로 팔까요?', const [
      'm:피트|형씨, 약한 물건 파느라 손목 나가겠어. 지금 것보다 약한 건 내가 알아서 사 갈까?',
      'sys:켜 두면 지금 장비보다 약하거나 같은 장비는 창 없이 바로 팔아요. 장비 탭 「약한 장비 바로 판매」에서 언제든 바꿀 수 있어요.',
    ], '바로 팔기 켜기', altLabel: '괜찮아요', onGo: () {
      state.raw['autoSell'] = true;
      toast('약한 장비 바로 판매 켜짐');
      save();
      refresh();
    });
  }

  Future<void> showItemSheet(BuildContext ctx, Relic it, Relic? cur,
          {({num gold, num gem, String? card, List<(String, String)> rare})? gob}) =>
      showKdSheet<void>(ctx, closable: false, builder: (c) {
        final d = (GameCalc.score(it) - GameCalc.score(cur)) * calc.enMul(it.slot);
        final mood = it.g < 1 ? 'angry' : it.g >= 4 ? 'moved' : 'proud';
        // 새 장비가 더 약하면 노란(주) 버튼은 「판매」, 루미나르도 팔라고 함 (웹 showItem weak · lumWeak)
        final weak = cur != null && d < 0;
        final quote = weak
            ? (it.g >= 3 ? 'q@proud:등급은 좋다만 지금 것보다 약하다. 팔아라.' : 'q@angry:흥, 지금 것보다 약하군. 팔아서 골드로 바꿔라.')
            : 'q@$mood:${lumQuotes[it.g]}';
        final sellBtn = KdAct('판매 +${fmt(it.price)}', primary: weak, onTap: () {
          Navigator.of(c).pop();
          sound('coin');
          act((a) => a.sell(it));
          if (weak) _sellAsk();
        });
        final eqBtn = KdAct('장착', primary: !weak, onTap: () {
          Navigator.of(c).pop();
          sound('equip');
          act((a) => a.equip(it));
        });
        Widget gl(Widget icon, String b, String sm, Color col) => Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(
                color: KdColors.panel2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: col.withValues(alpha: .6)),
              ),
              child: Column(children: [
                SizedBox(width: 34, height: 34, child: icon),
                FittedBox(fit: BoxFit.scaleDown, child: Text(b, style: KdText.figure(13, color: col))),
                FittedBox(fit: BoxFit.scaleDown, child: Text(sm, style: KdText.body(10.5, color: KdColors.muted))),
              ]),
            );
        return KdSheetBody(
          title: gob != null ? '황금 고블린 처치!' : '성유물을 얻었어요',
          children: [
            if (gob != null) ...[
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                gl(kdImg(goldIcon), '+${fmt(gob.gold)}', '골드', KdColors.gold),
                gl(kdImg(gemIcon), '+${fmt(gob.gem)}', '황금 이삭', const Color(0xFFFFE08A)),
                gl(RelicIcon(it, size: 34), itemGrades[it.g].n, slotDef(it.slot).n, gradeColor(it.g)),
                if (gob.card != null) gl(CompFrame(gob.card!, w: 28, h: 34), '+3', '${comps[gob.card]!.n} 카드', const Color(0xFFC9A4FF)),
                for (final (t, _) in gob.rare)
                  gl(kdImg('assets/game/profile/${t}_goblin.png'), t == 'frame' ? '테두리' : '배지', '아주 드묾!', const Color(0xFFFFD34A)),
              ]),
              const KdSec('받은 성유물'),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: RelicCard(it, '새 장비', calc, vs: cur, compare: true)),
              const SizedBox(width: 8),
              Expanded(child: RelicCard(cur, '착용 중', calc)),
            ]),
            Text('전투력 ${d >= 0 ? '▲' : '▼'} ${fmt(d.abs())}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Hahmlet', fontSize: 17, fontWeight: FontWeight.w700, color: d > 0 ? const Color(0xFF7BE08F) : d < 0 ? const Color(0xFFFF6B7D) : null)),
            Para(quote),
          ],
          acts: KdActs(buttons: weak ? [eqBtn, sellBtn] : [sellBtn, eqBtn]),
        );
      });

  /// 10연속 결과 창 (웹 open10)
  Future<void> showOpen10Sheet(BuildContext ctx, ActOpen10 r) => showKdSheet<void>(ctx, closable: false, builder: (c) {
        final cnt = <(int, int)>[
          for (var g = 0; g < itemGrades.length; g++)
            if (r.items.any((x) => x.g == g)) (g, r.items.where((x) => x.g == g).length)
        ];
        return KdSheetBody(
          eyebrow: '성유물 상자 10연속',
          title: '피트의 특별 배달',
          children: [
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 4, children: [
              for (final (g, n) in cnt) oddsChip(gradeColor(g), '${itemGrades[g].n} $n개', size: 13),
            ]),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              for (final it in r.items)
                SizedBox(
                  width: 56,
                  child: Column(children: [
                    RelicIcon(it, size: 56),
                    Text(r.equipped.contains(it) ? '장착' : ' ', style: KdText.body(10, color: gradeColor(it.g), weight: FontWeight.w600)),
                  ]),
                ),
            ]),
            Para(r.equipped.isNotEmpty ? 'q@proud:좋다! 더 강한 성유물 ${r.equipped.length}개를 바로 걸쳤다.' : 'q@angry:흥, 지금 것보다 나은 게 없군.'),
            Text('나머지를 팔아 골드 +${fmt(r.sold)}', style: const TextStyle(fontSize: 13, color: Color(0xFF97A2C3))),
          ],
          acts: KdActs(buttons: [KdAct('확인', primary: true, onTap: () => Navigator.of(c).pop())]),
        );
      });

  void _handle(BattleEvent e) {
    switch (e) {
      case ToastEvent(:final msg):
        toast(msg);
      case PillEvent(:final msg):
        pillMsg = msg;
        pillUntil = DateTime.now().millisecondsSinceEpoch + 2600;
      case HapticEvent(:final pattern):
        haptic(pattern);
      case SoundEvent(:final k):
        sound(k == 'gob' ? 'goblin' : k);
      case GoblinLootEvent(:final relic, :final gold, :final gem, :final cardId, :final rare, :final sold):
        sound('coin');
        if (!sim.noSave) {
          online.gobDirty = true;
          Timer(const Duration(milliseconds: 2600), online.gobRankToast);
        }
        if (sold) {
          // 자동 판매: 창 없이 알림 한 줄 (웹 gobDrop)
          toast('황금 고블린 처치! 골드 +${fmt(gold)} · 이삭 +$gem${cardId != null ? ' · ${comps[cardId]!.n} 카드 +3' : ''} · '
              '${itemGrades[relic.g].n} ${slotDef(relic.slot).n} 자동 판매 +${fmt(relic.price)}${rare.isNotEmpty ? ' · 희귀 전리품!' : ''}');
          for (final (t, n) in rare) {
            queue((ctx) => showGobRare(ctx, this, t, n));
          }
          return;
        }
        // 웹 gobDrop: 장비 비교 창 위에 전리품 줄을 붙여 보여 줌 (다른 장비를 고르는 중이면 건너뜀)
        queue((ctx) async {
          if (acts.pending != null) return;
          acts.pending = relic;
          await showItemSheet(ctx, relic, calc.equipped(relic.slot), gob: (gold: gold, gem: gem, card: cardId, rare: rare));
        });
        for (final (t, n) in rare) {
          queue((ctx) => showGobRare(ctx, this, t, n));
        }
      case StoryEvent(:final id):
        final ev = storyEvents.firstWhere((x) => x.id == id);
        // 마르타 「밭으로 간다」: 마을 밭을 열어 줌 (웹 EVENTS marta.go)
        _rpAdd((face: reportFace(ev.lines), eb: ev.eyebrow, t: ev.title, p: ev.lines, btn: ev.button, titleWidget: null, go: id == 'marta' ? () => vlSelect('farm') : null));
      case RankUpEvent(:final rankIdx, :final gem):
        sound('fanfare');
        final r = ranks[rankIdx];
        if (_quietStory) {
          toast('칭호 상승: ${r.n} · 능력치 +4%${gem > 0 ? ' · 황금 이삭 +${fmt(gem)}' : ''}');
          return;
        }
        _rpAdd((
          face: 'assets/game/ui/${rankImg[rankIdx]}.png',
          eb: '칭호 상승',
          t: '${r.n} 카엘',
          p: [
            '되찾은 영지가 ${r.at}곳에 이르자, 사람들이 카엘을 ${r.n}(이)라고 부르기 시작했다.',
            'k@flustered:${r.k ?? ''}',
            'q@proud:하하! 한 걸음 더 왕좌에 가까워졌다!',
            'sys:모든 원정대 능력치 +4%${gem > 0 ? ' · 황금 이삭 +${fmt(gem)}' : ''}',
          ],
          btn: '…알겠어요',
          titleWidget: Column(children: [
            kdImg('assets/game/ui/${rankImg[rankIdx]}.png', w: 96, h: 96),
            Text('${r.n} 카엘', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Hahmlet', fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
          go: null,
        ));
      case GemEvent(:final n, :final why):
        // 웹: 군단장 첫 처치 이삭은 2.3초 뒤 (「○○ 처치」 알림에 덮이지 않게) + 진동
        Timer(Duration(milliseconds: why.endsWith('첫 처치') ? 2300 : 0), () {
          haptic(const [18]);
          sound('gem');
          toast('황금 이삭 +${fmt(n)} · $why');
        });
      case SkillTutorialEvent():
        // 웹: 안내를 보는 동안 자동 스킬을 잠시 끔
        final was = state.raw['autoSkill'];
        state.raw['autoSkill'] = false;
        scene('특수 스킬', '동료들의 힘이 모였다', [
          'q@proud:주인, 원정대의 힘이 가득 찼다! 빛나는 초상화가 특수 스킬이다. 지금은 알아서 쓰고 있다.',
          'sys:초상화 둘레의 금색 고리가 다 차면 특수 스킬이 나가요. 오른쪽 아래 「자동」을 끄면 빛나는 초상화를 직접 눌러 쓸 수 있어요. 초상화를 길게 누르면 스킬 설명이 나와요.',
        ], '알겠어', onGo: () => state.raw['autoSkill'] = was);
      case StageClearedEvent(:final chapter):
        sound('clear');
        if (chapter) _chapter();
        save();
      case CapStoryEvent(:final kind):
        _capStory(kind);
      case DemonWinEvent(:final bonus):
        sound('fanfare');
        if (!truthy(state.raw['ending1'])) {
          _ending(0);
        } else if (bonus > 0) {
          Timer(const Duration(milliseconds: 2600), () => toast('왕도 재탈환 보너스! 은퇴의 추억 +$bonus'));
        }
      case TowerWinEvent(:final f, :final first, :final r, :final unlocked):
        sound('clear');
        save();
        _towerWon(f, first, r, unlocked);
      case TowerLoseEvent(:final f):
        queue((ctx) => _towerLoseSheet(ctx, f));
      case final DunEndEvent de:
        save();
        queue((ctx) => _dunEndSheet(ctx, de));
      case FightResetEvent():
        break;
    }
  }
}
