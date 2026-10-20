/// 게임 진행 담당 — 저장 데이터·공식·전투·탭·알림·창 대기열을 한곳에서 관리.
///
/// 웹의 전역 S·curTab·toast()·queue()/pump()·renderAll() 자리.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../battle/battle_game.dart';
import '../battle/sim.dart';
import '../core/actions.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/save_store.dart';
import '../core/state.dart';
import '../ui/game_widgets.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// 화면 어디서나 ref.watch(gameProvider) 로 꺼내 씀 (main.dart 에서 실제 값으로 바꿔 끼움)
final gameProvider = Provider<GameController>((ref) => throw UnimplementedError('ProviderScope 에서 넣어 주세요'));

/// 하단 탭 (웹 data-t)
enum GameTab {
  eq('장비', 'tab_equipment'),
  pt('원정대', 'tab_party'),
  up('단련', 'tab_training'),
  vl('마을', 'tab_village'),
  mp('지도', 'tab_map'),
  sh('피트의 상점', null);

  const GameTab(this.title, this.icon);
  final String title;
  final String? icon;

  /// 반쯤 열리는 창 (웹 HALF)
  bool get half => this == eq || this == pt || this == up || this == sh;

  /// 탭 줄에 보이는 이름
  String get label => this == pt ? '원정대' : title;
}

class GameController extends ChangeNotifier {
  GameController({required this.store, required this.state}) {
    calc = GameCalc(state);
    sim = BattleSim(calc);
    game = BattleGame(sim, insets: const BattleInsets(top: 84, bottom: 118))..onTick = _onFrame;
    acts = GameActions(calc)
      ..bossFight = (() => sim.mons.any((m) => m.boss && m.hp > 0 && m.dead == 0))
      ..onSwap = _swap
      ..onHpAdd = (id, h) {
        final p = sim.party[id];
        if (p != null) p.hp += h;
      };
    if (!truthy(state.raw['started'])) state.raw['started'] = true;
    state.raw['v'] = 3;
    calc.produce();
    // 웹 loop(): 5초마다 저장
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => save());
  }

  final SaveStore store;
  final GameState state;
  late final GameCalc calc;
  late final BattleSim sim;
  late final BattleGame game;
  late final GameActions acts;

  /// 방금 바뀐 장비 칸 → 시각 (반짝임)
  final Map<String, int> flashAt = {};

  /// 매 프레임 (전투 위 표시: 보스 막대·초상화)
  final frame = ValueNotifier<int>(0);

  /// 0.4초마다·눌렀을 때 (상단 바·창 내용, 웹 renderAll 주기)
  final ui = ValueNotifier<int>(0);

  /// 알림 한 줄 (웹 toast)
  final toastMsg = ValueNotifier<String?>(null);
  Timer? _toastTimer, _saveTimer;

  /// 창을 띄울 곳 (MaterialApp.navigatorKey)
  final navKey = GlobalKey<NavigatorState>();

  // ── 탭 (웹 curTab / setTab) ──
  GameTab? tab;
  bool get pgFull => state.raw['pgFull'] == true;

  void setTab(GameTab? t) {
    if (t == tab) t = null;
    if (t == GameTab.pt) dotSeen();
    tab = t;
    notifyListeners();
    refresh();
  }

  void togglePgFull() {
    state.raw['pgFull'] = !pgFull;
    save();
    notifyListeners();
  }

  /// 알림이 화면 위쪽에 붙는지 (웹 toast.hi: 창이 열렸거나 전체 화면 탭일 때)
  bool get toastHigh => modalOpen || (tab != null && (!tab!.half || pgFull));

  void refresh() => ui.value++;

  // ── 저장 ──
  Future<void> save() => store.save(state, DateTime.now().millisecondsSinceEpoch);

  @override
  void dispose() {
    _saveTimer?.cancel();
    _toastTimer?.cancel();
    save();
    super.dispose();
  }

  // ── 알림·진동 ──
  void toast(String m) {
    toastMsg.value = m;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () => toastMsg.value = null);
  }

  /// 웹 haptic(): 설정에서 진동을 끄면(S.vib===false) 울리지 않음
  void haptic([List<int> p = const [12]]) {
    if (state.raw['vib'] == false) return;
    final total = p.fold<int>(0, (a, b) => a + b);
    if (total >= 60) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  // ── 창 대기열 (웹 sceneQ / queue / pump) ──
  /// 제목 화면이 떠 있는 동안은 창을 띄우지 않음
  bool titleOpen = true;
  bool modalOpen = false;

  /// 제목 화면의 「게임 시작」 (웹 startBtn)
  void startFromTitle() {
    titleOpen = false;
    haptic();
    notifyListeners();
    pump();
  }
  final List<Future<void> Function(BuildContext)> _q = [];

  void queue(Future<void> Function(BuildContext ctx) fn) {
    _q.add(fn);
    pump();
  }

  void pump() {
    final ctx = navKey.currentContext;
    if (titleOpen || modalOpen || _q.isEmpty || ctx == null) return;
    final fn = _q.removeAt(0);
    modalOpen = true;
    notifyListeners();
    fn(ctx).whenComplete(() {
      modalOpen = false;
      notifyListeners();
      refresh();
      // 다음 창은 한 박자 쉬고
      Future.delayed(const Duration(milliseconds: 120), pump);
    });
  }

  /// 사용자가 직접 여는 창 (대기열을 거치지 않지만, 열린 동안 다른 창은 기다림)
  Future<T?> openSheet<T>(Widget Function(BuildContext ctx) builder, {bool closable = true}) async {
    final ctx = navKey.currentContext;
    if (ctx == null || modalOpen) return null;
    modalOpen = true;
    notifyListeners();
    try {
      return await showKdSheet<T>(ctx, builder: builder, closable: closable);
    } finally {
      modalOpen = false;
      notifyListeners();
      refresh();
      pump();
    }
  }

  /// 웹 scene(eyebrow,title,paras,btn,alt,illust): 이야기 창. 대기열에 넣는다.
  void scene(String eyebrow, String title, List<String> paras, String btn,
      {String? altLabel, VoidCallback? onGo, String? illust, String? illustFace, Widget? titleWidget, bool closable = false}) {
    queue((ctx) => showKdSheet<void>(ctx, closable: closable, builder: (c) {
          return KdSheetBody(
            illust: illust,
            illustFace: illustFace,
            eyebrow: eyebrow,
            title: titleWidget == null ? title : null,
            titleWidget: titleWidget,
            children: [for (final p in paras) Para(p)],
            acts: KdActs(buttons: [
              if (altLabel != null) KdAct(altLabel, onTap: () => Navigator.of(c).pop()),
              KdAct(btn, primary: true, onTap: () {
                Navigator.of(c).pop();
                onGo?.call();
              }),
            ]),
          );
        }));
  }

  // ── 매 프레임 ──
  num _uiT = 0, _autoT = 0;
  void _onFrame(double dt) {
    for (final e in sim.events) {
      _handle(e);
    }
    sim.events.clear();
    frame.value++;
    // 웹 loop(): 자동 열기 0.9초마다 (창이 없을 때)
    _autoT += dt;
    if (truthy(state.raw['autoOpen']) && _autoT > .9 && !modalOpen) {
      _autoT = 0;
      act((a) => a.openBox(true));
    }
    // 웹 loop(): 0.4초마다 생산·화면 새로 그리기
    _uiT += dt;
    if (_uiT > .4) {
      _uiT = 0;
      calc.produce();
      refresh();
    }
  }

  // ── 누르면 일어나는 일 (core/actions.dart) ──
  /// 조작을 하고, 그 결과(알림·창)를 처리한 뒤 화면을 새로 그림
  T act<T>(T Function(GameActions a) f) {
    final r = f(acts);
    _flush();
    refresh();
    return r;
  }

  bool _peteAuto = false;

  void _flush() {
    final out = List.of(acts.out);
    acts.out.clear();
    for (final r in out) {
      switch (r) {
        case ActToast(:final msg):
          toast(msg);
        case ActHaptic(:final pattern):
          haptic(pattern);
        case ActFlashSlot(:final slot):
          flashAt[slot] = DateTime.now().millisecondsSinceEpoch;
        case ActBoxLevelScene(:final lv):
          if (lv == 5) {
            scene('성유물 상자 Lv.5', '단골 대접', [
              'm:피트|단골 대접이야. 이번 물건은 진짜 진품이라고. …이번엔 진짜.',
              'k@flustered:지난번엔 가짜였어요?',
              'm:피트|자, 자! 영웅 등급이 더 잘 나오게 해 놨어!',
            ], '…믿어 볼게요');
          } else {
            scene('성유물 상자 Lv.10', '왕국 최고의 상인', [
              'm:피트|형씨 덕분에 내가 왕국 최고의 상인이 됐어. 이제 내 상자엔 신화 등급도 들어 있다고!',
              'q@proud:…저 상인, 처음부터 주인의 재능을 알아본 거로군.',
              'm:피트|아니, 난 돈 냄새를 맡았지.',
            ], '그럴 줄 알았어요');
          }
        case ActPeteIntro():
          scene('수상한 행상인', '행상인 피트', [
            '마을 어귀에 낯선 마차가 서 있었다. 짐칸 가득 녹슨 상자가 실려 있었다.',
            'm:피트|어이, 거기 성검 든 형씨! 성유물 상자 하나 어때? 마왕군이 흘리고 간 진품이야. …아마도.',
            'k@surprised:아마도요?',
            'q@angry:주인, 저자 눈빛이 수상하다.',
            'm:피트|수상하긴! 열어 보면 알아. 환불은 안 되지만.',
            'sys:상자를 열면 카엘의 장비가 나와요. 많이 열수록 피트가 더 좋은 물건을 들여와요.',
          ], '한번 열어 본다', onGo: () => act((a) => a.openBox(_peteAuto)));
        case ActShowItem(:final it, :final cur):
          queue((ctx) => showItemSheet(ctx, it, cur));
        case ActOpen10():
          queue((ctx) => showOpen10Sheet(ctx, r));
        case ActRecruitScene(:final id):
          final rc = recruits[id]!;
          scene('동료 합류', rc.title, rc.lines, rc.ok, illust: 'join', illustFace: id);
      }
    }
  }

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
  Future<void> showItemSheet(BuildContext ctx, Relic it, Relic? cur) => showKdSheet<void>(ctx, closable: false, builder: (c) {
        final d = (GameCalc.score(it) - GameCalc.score(cur)) * calc.enMul(it.slot);
        final mood = it.g < 1 ? 'angry' : it.g >= 4 ? 'moved' : 'proud';
        return KdSheetBody(
          title: '성유물을 얻었어요',
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: RelicCard(it, '새 장비', calc, vs: cur, compare: true)),
              const SizedBox(width: 8),
              Expanded(child: RelicCard(cur, '착용 중', calc)),
            ]),
            Text('전투력 ${d >= 0 ? '▲' : '▼'} ${fmt(d.abs())}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Hahmlet', fontSize: 17, fontWeight: FontWeight.w700, color: d > 0 ? const Color(0xFF7BE08F) : d < 0 ? const Color(0xFFFF6B7D) : null)),
            Para('q@$mood:${lumQuotes[it.g]}'),
          ],
          acts: KdActs(buttons: [
            KdAct('판매 +${fmt(it.price)}', onTap: () {
              Navigator.of(c).pop();
              act((a) => a.sell(it));
            }),
            KdAct('장착', primary: true, onTap: () {
              Navigator.of(c).pop();
              act((a) => a.equip(it));
            }),
          ]),
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
      case HapticEvent(:final pattern):
        haptic(pattern);
      case GoblinLootEvent(:final relic, :final gold, :final gem, :final cardId):
        // 장비 비교 창은 4단계. 지금은 웹 「자동 열기」처럼 더 좋으면 끼우고 아니면 판다.
        final cur = calc.equipped(relic.slot);
        String what;
        if (GameCalc.score(relic) > GameCalc.score(cur)) {
          if (cur != null) state.gold = state.gold + cur.price;
          state.eq[relic.slot] = relic.toJson();
          what = '${itemGrades[relic.g].n} ${slotDef(relic.slot).n} 장착';
        } else {
          state.gold = state.gold + relic.price;
          what = '${itemGrades[relic.g].n} ${slotDef(relic.slot).n} 판매';
        }
        toast('황금 고블린 처치! 골드 +${fmt(gold)} · 이삭 +${fmt(gem)} · $what${cardId != null ? ' · ${comps[cardId]!.n} 카드 +3' : ''}');
      case StoryEvent(:final id):
        final ev = storyEvents.firstWhere((x) => x.id == id);
        scene(ev.eyebrow, ev.title, ev.lines, ev.button);
      case RankUpEvent(:final rankIdx, :final gem):
        final r = ranks[rankIdx];
        scene('칭호 상승', '${r.n} 카엘', [
          '되찾은 영지가 ${r.at}곳에 이르자, 사람들이 카엘을 ${r.n}(이)라고 부르기 시작했다.',
          'k@flustered:${r.k ?? ''}',
          'q@proud:하하! 한 걸음 더 왕좌에 가까워졌다!',
          'sys:모든 원정대 능력치 +4%${gem > 0 ? ' · 황금 이삭 +${fmt(gem)}' : ''}',
        ], '…알겠어요',
            titleWidget: Column(children: [
              kdImg('assets/game/ui/${rankImg[rankIdx]}.png', w: 96, h: 96),
              Text('${r.n} 카엘', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Hahmlet', fontSize: 22, fontWeight: FontWeight.w700)),
            ]));
      case GemEvent(:final n, :final why):
        toast('황금 이삭 +${fmt(n)} · $why');
      case SkillTutorialEvent():
        // 웹: 안내를 보는 동안 자동 스킬을 잠시 끔
        final was = state.raw['autoSkill'];
        state.raw['autoSkill'] = false;
        scene('특수 스킬', '동료들의 힘이 모였다', [
          'q@proud:주인, 원정대의 힘이 가득 찼다! 빛나는 초상화를 눌러 봐라.',
          'sys:초상화 둘레의 금색 고리가 다 차면 특수 스킬을 쓸 수 있어요. 오른쪽 아래 AUTO를 켜 두면 알아서 써요. 초상화를 길게 누르면 스킬 설명이 나와요.',
        ], '알겠어', onGo: () => state.raw['autoSkill'] = was);
      case StageClearedEvent(:final chapter):
        if (chapter) _chapter();
        save();
      case FightResetEvent():
        break;
    }
  }

  /// 웹 chapter(): 새 지역에 들어설 때 군단 소개
  void _chapter() {
    final st = state.stage, r = GameCalc.region(st), i = GameCalc.regionIndex(st);
    scene('제${i + 1}군단 · 점령지', r.n, [...r.lore, 'sys:이 땅의 지배자 · ${r.boss}'], '진격한다',
        titleWidget: Column(children: [
          kdImg('assets/game/portraits/portrait_${bossIds[i]}_idle.png', w: 120, h: 120),
          Text(r.n, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Hahmlet', fontSize: 22, fontWeight: FontWeight.w700)),
        ]));
  }

  // ── 빨간 점 (웹 ptAct / dotSeen) ──
  String ptAct() {
    final parts = <String>[for (final id in calc.cardReady()) 'c$id${calc.recStar(id)}'];
    for (final j in jobSlots) {
      if (j == 'kael' || !calc.betterBench(j)) continue;
      final ms = calc.jobMembers(j);
      var best = ms.first;
      for (final x in ms.skip(1)) {
        if (calc.cPow(x) > calc.cPow(best)) best = x;
      }
      parts.add('b$j$best');
    }
    return parts.join(',');
  }

  void dotSeen() => state.raw['dotSeen'] = ptAct();

  /// 원정대 탭 점: 지금 누르면 바로 이득이고, 아직 확인하지 않았을 때
  bool get ptDot {
    final a = ptAct();
    if (tab == GameTab.pt) {
      if (a != state.raw['dotSeen']) state.raw['dotSeen'] = a;
      return false;
    }
    return a.isNotEmpty && a != state.raw['dotSeen'];
  }

  /// 마을 탭 점: 수확할 작물이 있을 때
  bool get vlDot => truthy(state.bld['farm']) && state.plots.any((p) => calc.plotState(p).st == 'ready');

  /// 이삭 점: 받을 수 있는 할 일 보상이나 정기 배송이 있을 때 (웹 gemDot)
  bool get gemDot {
    final d = calc.daily();
    final claim = asMap(d['claim']) ?? const <String, dynamic>{};
    bool can(MissionDef m) => orNum(d[m.k], 0) >= m.goal && !truthy(claim[m.k]);
    final all = missions.every((m) => truthy(claim[m.k])) && !truthy(claim['all']);
    final sub = asMap(state.raw['sub']);
    return missions.any(can) || all || (calc.subOn() && sub?['last'] != calc.today());
  }
}

/// 칭호 그림 (웹 RANKIMG)
const rankImg = ['rank_farmer', 'rank_guard', 'rank_knight', 'rank_lord', 'rank_count', 'rank_duke', 'rank_king'];
