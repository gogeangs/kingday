/// 게임 진행 담당 — 저장 데이터·공식·전투·탭·알림·창 대기열을 한곳에서 관리.
///
/// 웹의 전역 S·curTab·toast()·queue()/pump()·renderAll() 자리.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../battle/battle_game.dart';
import '../battle/sim.dart';
import '../core/actions.dart';
import '../core/attendance.dart';
import '../core/calc.dart';
import '../core/challenge.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../core/retire.dart';
import '../core/save_store.dart';
import '../core/server.dart';
import '../core/state.dart';
import '../core/village.dart';
import '../core/worldmap.dart';
import '../screens/attend_sheet.dart';
import '../screens/challenge_sheet.dart';
import '../screens/retire_sheet.dart';
import '../screens/social_sheets.dart';
import '../ui/game_widgets.dart';
import '../ui/report_sheet.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ads.dart';
import 'feel.dart';
import 'online.dart';
import 'store.dart';

part 'controller_ads.dart';
part 'controller_capital.dart';
part 'controller_challenge.dart';
part 'controller_dots.dart';
part 'controller_map.dart';
part 'controller_retire.dart';
part 'controller_return.dart';
part 'controller_story.dart';
part 'controller_village.dart';

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
  /// 마을·지도는 지도 그림·아래 창이 좁아져 반 열림에서 뺌 (UX 점검 11: 해 보고 되돌림)
  bool get half => this == eq || this == pt || this == up || this == sh;

  /// 탭 줄에 보이는 이름
  String get label => this == pt ? '원정대' : title;
}

class GameController extends ChangeNotifier {
  GameController({required this.store, required this.state, Server? server}) {
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
    // 원정 일지 점수·성장 패키지 (docs/content/SHOP.md)
    sim
      ..onPass = ((k) => act((a) => a.passAdd(k)))
      ..onKill = (() => act((a) => a.passKill()))
      ..onGrow = (() => act((a) => a.growCheck()));
    // 웹 start(): 처음이면 프롤로그 (방치 보상은 7단계)
    final isNew = !truthy(state.raw['started']);
    state.raw['started'] = true;
    state.raw['v'] = 3;
    _builtToast(calc.produce());
    if (isNew) {
      _intro();
    } else {
      offline();
      attAuto();
      // 은퇴 횟수 보상: 업데이트 전에 넘긴 단계는 첫 접속 때 바로 지급 (웹 start → retRwCheck)
      final rw = calc.retRwCheck();
      if (rw != null) queue((_) async => toast(retRwText(rw)));
      act((a) => a.chiefCheck());
    }
    acts.passS();
    act((a) => a.growCheck());
    if (!isNew) queue((_) async => act((a) => a.passWarn()));
    calc.pfCheck();
    // 웹 start() 끝의 events(): 옛 기록·다른 곳에서 가져온 기록이면 밀린 이야기·칭호를 바로 보여 줌
    sim.runStoryEvents();
    // 웹 loop(): 5초마다 저장
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => save());
    // 8단계: 계정·랭킹·우편·클라우드 (서버가 없으면 꺼짐)
    online = Online(this, server)..start();
    // 인앱결제 (스토어 상품을 등록하기 전에는 꺼져 있음 → 시험용 바로 지급)
    iap = IapStore(this);
    if (Feel.live) iap.init();
  }

  /// 스토어 결제
  late final IapStore iap;

  /// 계정·랭킹·우편함·클라우드 저장
  late final Online online;

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
    if (t == GameTab.vl) state.raw['workDot'] = calc.today();
    tab = t;
    if (t == GameTab.mp) mapOpen();
    notifyListeners();
    refresh();
  }

  // ── 대륙 지도 (docs/content/WORLDMAP.md) ──
  /// 확대한 지역 (-1 = 전체 지도)
  int mapZoomR = -1;

  /// 카메라: 지도 좌표 가운데 + 배율 (지금 값 → 목표 값으로 부드럽게)
  double camX = mapW / 2, camY = mapH / 2, camZ = 1, camTx = mapW / 2, camTy = mapH / 2, camTz = 1;

  /// 걷힘·되찾음 연출 (지도 x, y, 시작 ms, 길이 ms, 종류 fog·reg·cap)
  final List<({double x, double y, int t0, int d, String k})> mapAnims = [];
  int _mapCapSeen = -1;

  void togglePgFull() {
    state.raw['pgFull'] = !pgFull;
    save();
    notifyListeners();
  }

  // ── 저장 ──
  /// 기록을 바꿔 끼우는 중이면 저장하지 않음 (웹 noSave)
  bool noSave = false;

  /// 앱이 뒤로 가 있는 동안은 마지막 접속 시각을 올리지 않음 (방치 보상 계산이 맞게)
  bool backgrounded = false;

  Future<void> save() async {
    if (noSave || backgrounded) return;
    await store.save(state, DateTime.now().millisecondsSinceEpoch);
  }

  /// 앱이 뒤로 갈 때: 지금 저장하고 멈춤
  void onPause() {
    if (backgrounded) return;
    save();
    // 웹 cloudBeacon(): 벗어날 때 클라우드에도 한 번
    online.cloudPut(false);
    backgrounded = true;
  }

  /// 시간이 다 돼 끝난 공사 알림 (웹 checkBuild → finishBuild: 첫 번째만 알림)
  void _builtToast(List<String> done) {
    if (done.isEmpty) return;
    vNewDone.addAll(done);
    final k = done.first, b = buildingDef(k);
    final after = state.bldLv(k) - done.skip(1).where((x) => x == k).length;
    toast('${b.n}${after - 1 > 0 ? ' 확장' : ' 재건'} 완료! ${calc.bldEff(k, after)}');
    refresh();
  }

  /// 앱으로 돌아올 때: 꺼 둔 동안의 방치 보상
  void onResume() {
    if (!backgrounded) return;
    backgrounded = false;
    _builtToast(calc.produce());
    offline();
    attAuto();
    // 원정 일지: 시즌이 바뀌었으면 넘기고, 마감 3일 전이면 알림 (하루 한 번)
    act((a) {
      a.passS();
      a.passWarn();
    });
    refresh();
    // 웹 'online' 이벤트처럼: 돌아오면 계정·우편 다시 확인
    if (online.on) online.ensure();
  }

  /// 기록을 통째로 바꿔 끼움 (저장 코드 불러오기·초기화). main.dart 의 앱 뿌리가 새 진행 담당을 만든다
  void Function(GameState next)? onRestart;

  /// 저장 코드 불러오기 (웹 setImp: 저장 후 다시 시작)
  Future<void> loadFromCode(Map<String, dynamic> d) async {
    noSave = true;
    await store.putRaw(d);
    onRestart?.call(store.load(DateTime.now().millisecondsSinceEpoch));
  }

  /// 게임 초기화 (웹 setYes)
  Future<void> resetAll() async {
    noSave = true;
    await store.clear();
    onRestart?.call(store.load(DateTime.now().millisecondsSinceEpoch));
  }

  // ── 출석체크 (웹: 그날 처음 들어오면 방치 보상 다음에 출석 창) ──
  String _attShown = '';

  // ── 방치 보상 (웹 offline()) ──

  @override
  void dispose() {
    _saveTimer?.cancel();
    _toastTimer?.cancel();
    save();
    online.dispose();
    iap.dispose();
    game.pauseEngine();
    super.dispose();
  }

  // ── 알림·진동 ──
  // ── 내 사진 (웹 PHOTO_KEY): 저장(state)·클라우드·저장 코드에 넣지 않고 이 기기에만 ──
  static const photoKey = 'kd-photo';
  String? _photoSrc;
  Uint8List? _photoBytes;

  /// 이 기기에 둔 내 사진 (없으면 null)
  Uint8List? get photoBytes {
    final d = store.prefs.getString(photoKey);
    if (d == null || d.isEmpty) return null;
    if (d != _photoSrc) {
      _photoSrc = d;
      try {
        _photoBytes = base64Decode(d.substring(d.indexOf(',') + 1));
      } catch (_) {
        _photoBytes = null;
      }
    }
    return _photoBytes;
  }

  /// 지금 내 사진을 얼굴로 쓰는 중인지
  bool get photoOn => truthy(state.raw['facePhoto']) && photoBytes != null;

  /// 휴대폰 사진첩에서 한 장 골라 작게(384px) 줄여 이 기기에 저장
  Future<bool> pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 384, maxHeight: 384, imageQuality: 85);
      if (x == null) return false;
      final b = await x.readAsBytes();
      await store.prefs.setString(photoKey, 'data:image/jpeg;base64,${base64Encode(b)}');
      state.raw['facePhoto'] = true;
      save();
      refresh();
      toast('내 사진으로 바꿨어요 · 이 기기에서만 보여요');
      return true;
    } catch (_) {
      toast('사진을 열 수 없어요');
      return false;
    }
  }

  void clearPhoto() {
    store.prefs.remove(photoKey);
    state.raw['facePhoto'] = false;
    save();
    refresh();
    toast('사진을 지웠어요');
  }

  /// 알림: 여러 개면 하나씩 차례로 (웹 toast · toastQ)
  final List<String> _toastQ = [];
  int _toastAt = 0;

  /// 원정대 초상화 줄 (알림을 그 바로 위에 띄움)
  final partyRowKey = GlobalKey();

  /// 열린 탭 창·아래 탭 줄 (탭이 열려 있으면 알림을 그 바로 위에, UX 점검 2)
  final pageKey = GlobalKey(), tabsKey = GlobalKey();

  /// 이야기 창(scene·탈환 보고서)이 떠 있는 동안 알림은 모아 두었다가 닫으면 보여 줌 (웹 sceneOn·toastHold, 3회차 리뷰 14)
  bool sceneOn = false;
  final List<String> _toastHold = [];

  void _sceneDone() {
    sceneOn = false;
    if (_toastHold.isEmpty) return;
    final h = List.of(_toastHold);
    _toastHold.clear();
    Timer(const Duration(milliseconds: 200), () => h.forEach(toast));
  }

  /// 쌓인 알림을 모두 지움 — 카드 결과 창처럼 창 안에 같은 내용이 있을 때
  /// (2026-10-25 제보: 「또 뽑기」 때 앞 뽑기 알림이 이삭 수를 가림)
  void toastClear() {
    _toastHold.clear();
    _toastQ.clear();
    _toastTimer?.cancel();
    toastMsg.value = null;
  }

  void toast(String m) {
    if (sceneOn && modalOpen) {
      if (!_toastHold.contains(m)) _toastHold.add(m);
      if (_toastHold.length > 3) _toastHold.removeAt(0);
      return;
    }
    if (toastMsg.value != null) {
      if (m == toastMsg.value || _toastQ.contains(m)) return;
      _toastQ.add(m);
      if (_toastQ.length > 3) _toastQ.removeAt(0);
      _toastTimer?.cancel();
      final wait = math.max(250, 1300 - (DateTime.now().millisecondsSinceEpoch - _toastAt));
      _toastTimer = Timer(Duration(milliseconds: wait), () => _toastShow(_toastQ.removeAt(0)));
      return;
    }
    _toastShow(m);
  }

  void _toastShow(String m) {
    toastMsg.value = m;
    _toastAt = DateTime.now().millisecondsSinceEpoch;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: _toastQ.isNotEmpty ? 1500 : 2000), () {
      if (_toastQ.isNotEmpty) {
        _toastShow(_toastQ.removeAt(0));
      } else {
        toastMsg.value = null;
      }
    });
  }

  /// 웹 haptic(): 설정에서 진동을 끄면(S.vib===false) 울리지 않음
  void haptic([List<int> p = const [12]]) {
    if (state.raw['vib'] == false) return;
    Feel.vibrate(p);
  }

  /// 효과음 (설정에서 끄면 조용, S.snd === false)
  void sound(String k) {
    Feel.soundOn = state.raw['snd'] != false;
    Feel.sound(k);
  }

  // ── 창 대기열 (웹 sceneQ / queue / pump) ──
  /// 제목 화면이 떠 있는 동안은 창을 띄우지 않음
  bool titleOpen = true;
  bool modalOpen = false;

  /// 시련의 탑 자동 오르기: 이번에 연달아 오른 층·보상 (웹 CH.run)
  TowerRun? towerRun;

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
      final n = _next;
      _next = null;
      if (n != null) {
        Future.microtask(n);
        return;
      }
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
      final n = _next;
      _next = null;
      if (n != null) {
        Future.microtask(n);
      } else {
        pump();
      }
    }
  }

  /// 지금 창을 닫고, 닫힌 다음 바로 다른 창을 엶 (웹은 같은 창의 내용을 바꿔 끼우던 자리)
  void chainSheet(BuildContext sheetCtx, FutureOr<void> Function() next) {
    _next = next;
    Navigator.of(sheetCtx).pop();
  }

  FutureOr<void> Function()? _next;

  /// 웹 scene(eyebrow,title,paras,btn,alt,illust): 이야기 창. 대기열에 넣는다.
  void scene(String eyebrow, String title, List<String> paras, String btn,
      {String? altLabel, VoidCallback? onGo, VoidCallback? onAlt, String? illust, String? illustFace, Widget? titleWidget, bool closable = false}) {
    queue((ctx) async {
      sceneOn = true;
      try {
        await showKdSheet<void>(ctx, closable: closable, builder: (c) {
          return KdSheetBody(
            illust: illust,
            illustFace: illustFace,
            eyebrow: eyebrow,
            title: titleWidget == null ? title : null,
            titleWidget: titleWidget,
            children: [for (final p in paras) Para(p)],
            acts: KdActs(buttons: [
              if (altLabel != null)
                KdAct(altLabel, onTap: () {
                  Navigator.of(c).pop();
                  onAlt?.call();
                }),
              KdAct(btn, primary: true, onTap: () {
                Navigator.of(c).pop();
                onGo?.call();
              }),
            ]),
          );
        });
      } finally {
        _sceneDone();
      }
    });
  }

  // ── 매 프레임 ──
  num _uiT = 0, _autoT = 0;
  void _onFrame(double dt) {
    // Flame 이 화면을 다시 짜는 도중(build)에 update(0) 을 부를 때가 있음 → 그때는 화면 갱신을 그 프레임 뒤로 미룸
    if (dt <= 0) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _frameNow(dt));
      return;
    }
    _frameNow(dt);
  }

  void _frameNow(double dt) {
    _drainEvents();
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
      _builtToast(calc.produce());
      calc.pkCheck();
      _vlTick();
      calc.pfCheck();
      chCheck();
      _nwFlush();
      // 하루가 바뀌면 원정 일지 시즌·마감 알림 확인 (웹 attHud 의 날짜 바뀜)
      final t = calc.today();
      if (_passDayK != t) {
        if (_passDayK.isNotEmpty) {
          act((a) {
            a.passS();
            a.passWarn();
          });
        }
        _passDayK = t;
      }
      refresh();
    }
  }

  String _passDayK = '';

  /// 전투가 쌓아 둔 일(알림·창)을 처리 — 매 프레임, 그리고 눌러서 전투 상태를 바꾼 직후
  void _drainEvents() {
    final es = List<BattleEvent>.of(sim.events);
    sim.events.clear();
    for (final e in es) {
      _handle(e);
    }
    _rpFlush();
  }

  // ── 새 소식 (UX 점검 4, 웹 nwAdd/nwFlush): 새로 열린 것 안내가 한꺼번에 생기면 한 장으로 ──
  final _nwBuf = <({ReportItem r, VoidCallback? later, VoidCallback one})>[];

  // ── 탈환 보고서 (docs/content/FIRST_DAY.md 3-2, 웹 rpAdd/rpFlush) ──
  final _rpBuf = <ReportItem>[];

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
          if (msg.contains('황금 이삭 +')) {
            sound('gem');
          } else if (msg.contains('골드 +') || msg.contains('판매 +')) {
            sound('coin');
          }
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
          } else if (lv == 31) {
            scene('새 등급', '태초의 물건', [
              'm:피트|형씨, 큰일 났어. 마계 상인한테서 「태초」라는 물건을 들여왔는데… 나도 처음 봐.',
              'k@surprised:그걸 팔아도 돼요?',
              'm:피트|팔면 안 되는 물건일수록 잘 팔리지!',
              'sys:이제 성유물 상자에서 신화보다 높은 「태초」 등급이 나와요. 상자 레벨이 오를수록 조금씩 잘 나와요.',
            ], '…조심해서 열게요');
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
          sound('box');
          queue((ctx) => showItemSheet(ctx, it, cur));
        case ActOpen10():
          sound('box');
          queue((ctx) => showOpen10Sheet(ctx, r));
        case ActBuildTutorial(:final k, :final lv):
          final b = buildingDef(k);
          scene('황금 이삭 사용법', '공사는 시간이 걸려요', [
            'sys:${b.n} ${lv > 0 ? '확장' : '재건'} 공사가 시작됐어요. 다 지어지려면 ${fmtT(calc.bldTime(b, lv))} 걸려요. 비싼 건물일수록 공사가 오래 걸려요.',
            'k@flustered:벽돌 쌓는 건 자신 있는데… 기다리는 건 좀 지루하네요.',
            'q@proud:주인, 이걸 받아라. 성검이 축복한 황금 이삭이다. 이삭을 내면 마을 사람들이 힘을 내서 공사를 바로 끝낸다.',
            'sys:황금 이삭 $tutGem개를 선물로 받았어요. 공사 중인 건물의 파란 "바로 완료" 버튼을 누르면 이삭으로 공사를 끝낼 수 있어요. 공사 중에도 다른 건물을 $buildQueueMax개까지 예약해 두면 차례로 지어져요.',
          ], '이삭으로 바로 완료', altLabel: '그냥 기다릴래요', onGo: () => act((a) => a.finishByGem()));
        case ActCardReveal(:final got, :final title, :final gold, :final again):
          sound('gem');
          queue((ctx) => showCardReveal(ctx, this, got, title, gold: gold, again: again));
        case ActPackGot(:final gem, :final first, :final ucard):
          // 결제 직후: 알림은 「구입 완료」 창 뒤에서 사라져 버려서 창으로 (2026-10-26)
          sound('gem');
          haptic(const [20, 30, 40]);
          scene('결제 완료', '황금 이삭 +${fmt(gem)}', [
            'sys:황금 이삭 ${fmt(gem)}개를 받았어요.${first ? ' 첫 구매라서 2배로 드렸어요.' : ''}${ucard > 0 ? ' 유니크 카드 $ucard장도 함께 받았어요.' : ''}',
            'm:피트|고마워, 형씨! 이삭은 상단 바에서 바로 확인해 봐.',
          ], '확인');
        case ActLaterToast(:final msg, :final ms):
          Timer(Duration(milliseconds: ms), () => toast(msg));
        case ActStarter(:final it, :final cur):
          scene('첫 거래 특가', '피트의 진품 보증', [
            'm:피트|형씨, 첫 거래 기념이야. 이번 건 진짜 진품이라고. 진짜로.',
            'k@surprised:…이번엔 정말 빛이 나네요.',
            'sys:전설 등급 성유물 1개와 황금 이삭 ${starterPack['gem']}개를 받았어요.',
          ], '성유물 확인하기', onGo: () => queue((ctx) async {
                acts.pending = it;
                await showItemSheet(ctx, it, cur);
              }));
        case ActGemPlotAsk(:final n, :final cost):
          scene('황금 밭', '새 밭 일구기', [
            'm:마르타|황금 이삭을 땅에 뿌리면 굳은 땅도 금세 부드러워지지. 한 칸 더 일궈 볼 텐가?',
            'sys:황금 이삭 $cost개로 밭을 1칸 늘려요 (${n + 1} / ${gemPlotCost.length}). 은퇴해도 사라지지 않아요.',
          ], '이삭 $cost개로 일구기', altLabel: '다음에', onGo: () => act((a) => a.buyGemPlot(n, cost)));
        case ActRecruitScene(:final id):
          final rc = recruits[id]!;
          scene('동료 합류', rc.title, rc.lines, rc.ok, illust: 'join', illustFace: id);
        case ActChiefScene(:final src):
          scene(
              '유니크 동료',
              '은퇴하면 더 바빠진다',
              [
                '새벽 종소리가 마을에 길게 울려 퍼졌다. 초록 모자를 쓴 할아버지가 성검을 지팡이처럼 짚고 걸어왔다.',
                'k@surprised:저게… 나야?',
                'm:카엘 촌장@laugh|껄껄! 은퇴하면 더 바빠진다, 이 녀석아.',
                'q@moved:…주인, 결국 은퇴는 하는군. 쉬지는 못하는 모양이지만.',
                if (src == 'retire') 'sys:은퇴 ${GameCalc.chiefRet}번을 채워 카엘 촌장이 찾아왔어요.',
                'sys:유니크 동료 · 카엘 자리에서 카엘 대신 출전해요. 장비·칭호는 카엘 것을 그대로 써요.',
                'sys:마을 스킬 「새벽 종소리」 마을 건물 생산 +${pctTxt(GameCalc.chPct(1))}% (출전 안 해도 적용)',
              ],
              '카엘 자리에 출전',
              altLabel: '나중에',
              onGo: () => act((a) => a.setKaelSeat(GameCalc.chiefId)));
      }
    }
  }

  // ── 마을 ──
  /// 마을에서 고른 건물 (웹 vlSel)
  String vlSel = 'farm';

  /// 건물 창(아래 반 창)이 열려 있는지 · 크게 보기 · 건물마다 마지막에 본 탭 (웹 vbOpen·vbFull·vbTabM)
  bool vbOpen = false, vbFull = false;
  final Map<String, String> vbTabM = {};

  /// 방금 공사가 끝난 건물 (할 일 줄 「🏗 공사 완료」, 고르면 꺼짐)
  final Set<String> vNewDone = {};

  /// 이번 실행 동안 펼친 안내문 (웹 helpOpen)
  final Map<String, bool> helpOpen = {};

  /// 길 위 사람을 눌렀을 때 한마디 (id, 대사, 지도 x·y, 끝나는 시각)
  ({String id, String line, double x, double y, int end})? vTalk;

  /// 밭 지정 모드 (웹 plotEdit)
  bool plotEdit = false;

  static const _vFn = {'farm': 'farm', 'forge': 'forge', 'market': 'order', 'chapel': 'bless', 'diner': 'kitchen'};

  /// 화면 쪽에서 채워 넣는 것 (일꾼 관리 창 열기 · 강화 가능 판단)
  VoidCallback? onWorkSheet;
  bool Function()? onForgeCan;

  /// 0.4초마다: 주문 채우기 · 편성으로 빠진 일꾼 · 건물 열림 이야기 · 일꾼 처음 열림 (웹 vlTick)
  // ── 첫 은퇴 권하기 (docs/content/FIRST_WALL.md C안, 웹 retHint/retGo) ──
  static const retHintLines = [
    'q@proud:주인, 여기까지 오느라 고생했다. 그런데 마족이 점점 단단해지는 게 느껴지지 않나?',
    'k@smile:…혹시 그 말은, 이제 은퇴해도 된다는 뜻?',
    'q:잠깐 쉬었다 오라는 뜻이다. 은퇴하면 「은퇴의 추억」이 쌓여 다음엔 훨씬 강해진다. …다시 끌려 나오겠지만.',
    'k@flustered:끌려 나오는 건 확정이구나.',
    'sys:은퇴하면 영지·장비·단련은 처음으로 돌아가고, 마을·동료·상자 레벨은 그대로 남아요. 은퇴의 추억 1개마다 모든 능력치·골드 +5%. 첫 은퇴 뒤에는 상자에서 신화보다 높은 「태초」도 나와요.',
  ];

  /// 단련 탭 「카엘의 은퇴 계획」 상자
  final retireKey = GlobalKey();

  // ── 광고 보상 (AdMob 보상형 광고 · 시험용 ID. 광고가 없으면 3초 가짜 광고로 대신) ──
  /// watchAd(k, give): 오늘 남은 횟수가 있으면 광고를 보고 보상
  Future<void> watchAd(String k, void Function() give) async {
    if (calc.adLeft(k) <= 0) {
      toast('오늘은 다 봤어요. 내일 다시 받을 수 있어요');
      return;
    }
    final ctx = navKey.currentContext;
    if (ctx == null || modalOpen) return;
    modalOpen = true;
    notifyListeners();
    bool? watched;
    try {
      watched = await Ads.show();
      // 보여 줄 광고가 없으면 (인터넷 없음·시험 환경) 웹처럼 3초 가짜 광고
      if (watched == null && ctx.mounted) {
        await showGeneralDialog<void>(
          context: ctx,
          barrierDismissible: false,
          barrierColor: const Color(0xE0000000),
          pageBuilder: (c, _, __) => _AdCountdown(onDone: () => Navigator.of(c).pop()),
        );
        watched = true;
      }
    } finally {
      modalOpen = false;
      notifyListeners();
    }
    if (watched != true) {
      toast('광고를 끝까지 보면 받을 수 있어요');
      pump();
      return;
    }
    final ad = asMap(calc.daily()['ad'])!;
    ad[k] = orNum(ad[k], 0) + 1;
    give();
    save();
    refresh();
    pump();
  }

  // ── 도전: 시련의 탑 · 요일 던전 (docs/content/CHALLENGE.md) ──

  // ── 다음 할 일 안내 (웹 GUIDE.go) ──
  /// 상자 버튼 깜빡이기 (첫 안내)
  int hintBoxAt = 0;

  /// 단련 탭 추천 줄 반짝임 (웹 upGo .flash)
  int upHintAt = 0;
  String? upHintK;

  // ── 은퇴 (웹 renderRetire 버튼 → scene → retireConfirm → retire) · 은퇴 일기 (docs/content/RETIRE.md) ──

  // ── 왕도 아스테리온 · 1부 엔딩 (docs/content/CAPITAL.md) ──

  static const _endingScenes = <(String, String, String?, List<String>, String)>[
    ('1부 엔딩 · 1', '왕좌 앞에서', 'ending1', ['m:발타사르@laugh|왕관은 무겁지. 지키고 싶은 것이 많을수록.', 'm:발타사르@laugh|이 왕관은 내가 가져간다. 진짜 왕이 될 자격이 있다면, 마계까지 찾아오너라.', 'sys:발타사르가 왕관을 들고 검은 문 너머로 사라졌다.'], '…'),
    ('1부 엔딩 · 2', '텅 빈 왕좌', null, ['k:…이겼다. 이제 은퇴?', 'q:아직이다. 왕관이 없는 왕은 왕이 아니다.', 'k@smile:나 왕 안 한다니까.'], '다음'),
    ('1부 엔딩 · 3', '왕궁 뜰', 'ending2', ['sys:되찾은 왕궁 뒤뜰. 카엘이 괭이로 땅을 고르고 있다.', 'q:주인, 거기는 왕궁 정원이다.', 'k@smile:좋은 흙이야. 여기다 밀 심으면 잘 자라겠어.', 'sys:1부 「잃어버린 왕국」 끝. 2부 「흩어진 동맹」에서 계속됩니다.'], '1부 완결'),
  ];

  // ── 빨간 점 (웹 ptAct / dotSeen) ──

}

/// 칭호 그림 (웹 RANKIMG)
const rankImg = ['rank_farmer', 'rank_guard', 'rank_knight', 'rank_lord', 'rank_count', 'rank_duke', 'rank_king', 'rank_king'];

/// 테스트 광고 화면: 3, 2, 1 뒤 보상 (웹 #adOv)
class _AdCountdown extends StatefulWidget {
  const _AdCountdown({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_AdCountdown> createState() => _AdCountdownState();
}

class _AdCountdownState extends State<_AdCountdown> {
  int n = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (n <= 1) {
        _t?.cancel();
        widget.onDone();
        return;
      }
      setState(() => n--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('광고 자리 · 테스트 모드', style: KdText.body(12, color: const Color(0xFF97A2C3))),
            const SizedBox(height: 6),
            Text('$n', style: KdText.display(56, color: const Color(0xFFFFC94A))),
            const SizedBox(height: 6),
            Text('초 뒤 보상을 받아요', style: KdText.body(14, color: Colors.white)),
          ]),
        ),
      );
}

/// 방치 보상 창의 작은 「2배」 버튼 (웹 .dblrow button)
class _DblBtn extends StatelessWidget {
  const _DblBtn({required this.text, this.sub, this.icon, required this.onTap});
  final String text;
  final String? sub, icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KdColors.panel2, borderRadius: BorderRadius.circular(10), border: Border.all(color: KdColors.line)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[kdImg(icon!, w: 14, h: 14), const SizedBox(width: 3)],
              Text(text, style: KdText.body(12.5, color: const Color(0xFFFFE08A), weight: FontWeight.w700)),
              if (sub != null) ...[const SizedBox(width: 4), Text(sub!, style: KdText.body(11, color: KdColors.muted))],
            ]),
          ),
        ),
      );
}
