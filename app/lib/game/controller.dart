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

  void mapGo(double x, double y, double z) {
    camTx = x;
    camTy = y;
    camTz = z;
  }

  void mapFocusCur([double z = 1.25]) {
    final p = mapPts[calc.mapCur() - 1];
    mapGo(p.$1, p.$2, z);
  }

  /// 지도 탭을 열 때: 처음 대사 · 걷힘 연출(처음 1번씩) (웹 mapOpen)
  void mapOpen() {
    final s = state, c = calc, now = DateTime.now().millisecondsSinceEpoch;
    mapZoomR = -1;
    mapFocusCur();
    camX = camTx;
    camY = camTy;
    camZ = camTz;
    if (c.mapIntroDue) {
      s.raw['mapIntro'] = 1;
      scene('대륙 지도', '안개 걷힌 에르단', const [
        'q:주인, 이게 에르단 대륙이다. 안개 낀 곳은 아직 마족의 땅이지.',
        'k:우리 마을이 저렇게 작았어?',
        'q:되찾을 때마다 안개가 걷힐 거다. 끝에는 왕도가 있다.',
        'k@smile:…끝까지 가면 은퇴할 수 있겠지?',
      ], '지도를 본다');
    }
    final fs = c.fogSeen;
    if (fs < s.best) {
      for (var st = math.max(2, fs + 1); st <= math.min(maxLand, s.best + 1); st++) {
        mapAnims.add((x: mapPts[st - 1].$1, y: mapPts[st - 1].$2, t0: now + 80 * (st - fs), d: 800, k: 'fog'));
      }
      s.raw['fogSeen'] = s.best;
    }
    var delay = 0;
    for (var r = 0; r < 6; r++) {
      if (!c.mapRegCleared(r) || truthy(c.regSeen['$r'])) continue;
      c.regSeen['$r'] = 1;
      final ct = mapCtr[r], d0 = delay;
      mapAnims.add((x: ct.$1, y: ct.$2, t0: now + d0, d: 2000, k: 'reg'));
      Future.delayed(Duration(milliseconds: d0), () {
        if (tab != GameTab.mp) return;
        mapGo(ct.$1, ct.$2, 1.35);
        Future.delayed(const Duration(milliseconds: 1700), () {
          if (tab == GameTab.mp && mapZoomR < 0) mapFocusCur();
        });
      });
      final m = regFogLines[r];
      if (m != null) {
        Future.delayed(Duration(milliseconds: d0 + 400), () {
          toast(m.$1);
          Future.delayed(const Duration(milliseconds: 1900), () => toast('루미나르: ${m.$2.replaceFirst(RegExp(r'^q(@\w+)?:'), '')}'));
        });
      }
      delay += 2200;
    }
    final cap = c.landCount();
    if (_mapCapSeen >= 0 && cap > _mapCapSeen) {
      for (var st = _mapCapSeen + 1; st <= cap; st++) {
        mapAnims.add((x: mapPts[st - 1].$1, y: mapPts[st - 1].$2, t0: now, d: 600, k: 'cap'));
      }
    }
    _mapCapSeen = cap;
    save();
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
  void attAuto() {
    final t = calc.today();
    if (_attShown == t || !attEligible(this) || acts.attStatusAt(t) != 'ok') return;
    _attShown = t;
    openAttend(this, queued: true);
  }

  // ── 방치 보상 (웹 offline()) ──
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
            if (adN > 0)
              KdBuy(
                kind: BuyKind.ad,
                minWidth: 0,
                text: '▶ 광고 보고 2배 · 오늘 $adN회',
                // 창을 닫고 「닫힌 다음」 광고를 띄움 (바로 부르면 창이 아직 열린 것으로 보여 광고가 안 뜸)
                onTap: () => chainSheet(c, () => watchAd('offline', twice)),
              ),
          ],
          acts: KdActs(buttons: [
            KdAct(
              '2배 받기',
              onTap: () {
                if (!acts.spendGem(gemOffline)) {
                  _flush();
                  return;
                }
                twice();
                Navigator.of(c).pop();
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('2배 받기 · ', style: KdText.display(15, color: const Color(0xFFFFE08A))),
                  iconNum(gemIcon, '$gemOffline', size: 16, style: KdText.figure(15, color: const Color(0xFFFFE08A))),
                ]),
              ),
            ),
            KdAct('받기', primary: true, onTap: () => Navigator.of(c).pop()),
          ]),
        );
      });

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

  void toast(String m) {
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
    queue((ctx) => showKdSheet<void>(ctx, closable: closable, builder: (c) {
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
        }));
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
      refresh();
    }
  }

  /// 전투가 쌓아 둔 일(알림·창)을 처리 — 매 프레임, 그리고 눌러서 전투 상태를 바꾼 직후
  void _drainEvents() {
    final es = List<BattleEvent>.of(sim.events);
    sim.events.clear();
    for (final e in es) {
      _handle(e);
    }
    _rpFlush();
  }

  // ── 탈환 보고서 (docs/content/FIRST_DAY.md 3-2, 웹 rpAdd/rpFlush) ──
  final _rpBuf = <ReportItem>[];
  void _rpAdd(ReportItem it) => _rpBuf.add(it);

  /// 모인 이야기 창이 1개면 그 창 그대로, 2개 이상이면 「탈환 보고서」 한 장
  void _rpFlush() {
    if (_rpBuf.isEmpty) return;
    final b = List<ReportItem>.of(_rpBuf);
    _rpBuf.clear();
    if (b.length == 1) {
      final it = b.first;
      scene(it.eb, it.t, it.p, it.btn, titleWidget: it.titleWidget);
      return;
    }
    queue((ctx) => showKdSheet<void>(ctx, builder: (c) => ReportSheet(items: b, onDone: () => Navigator.of(c).pop())));
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
          } else if (lv == 11) {
            scene('성유물 상자 Lv.11', '태초의 물건', [
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
        case ActCardReveal(:final got, :final title, :final gold):
          sound('gem');
          queue((ctx) => showCardReveal(ctx, this, got, title, gold: gold));
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
  Map<String, dynamic> get helpSeen => asMap(state.raw['helpSeen']) ?? (state.raw['helpSeen'] = <String, dynamic>{});

  /// 길 위 사람을 눌렀을 때 한마디 (id, 대사, 지도 x·y, 끝나는 시각)
  ({String id, String line, double x, double y, int end})? vTalk;

  /// 밭 지정 모드 (웹 plotEdit)
  bool plotEdit = false;

  static const _vFn = {'farm': 'farm', 'forge': 'forge', 'market': 'order', 'chapel': 'bless', 'diner': 'kitchen'};

  /// 건물 창 탭 (웹 vbTabs): 기능 탭 → 정보 → 일꾼
  List<String> vbTabs(String k) {
    final l = state.bldLv(k), fn = _vFn[k];
    return [
      if (fn != null && (k == 'diner' ? truthy(state.bld['farm']) : l > 0)) fn,
      'info',
      if (l > 0 && calc.wkOpen()) 'work',
    ];
  }

  String vbTab(String k) {
    final t = vbTabs(k), m = vbTabM[k];
    return m != null && t.contains(m) ? m : t.first;
  }

  /// 건물 고르기: 마을 탭으로 가서 아래 건물 창을 연다 (웹 vlSelect)
  void vlSelect(String k, {String? tab}) {
    vlSel = k;
    vbOpen = true;
    if (tab != null) vbTabM[k] = tab;
    vNewDone.remove(k);
    if (this.tab != GameTab.vl) setTab(GameTab.vl);
    refresh();
  }

  void vbClose() {
    vbOpen = false;
    refresh();
  }

  void vbTabSet(String k, String t) {
    vbTabM[k] = t;
    refresh();
  }

  /// 마을 할 일 (웹 vTodos): (키, 글자, 누르면)
  List<(String, String, VoidCallback)> vTodos() {
    final s = state, c = calc, t = <(String, String, VoidCallback)>[];
    final ready = truthy(s.bld['farm']) ? s.plots.where((p) => c.plotState(p).st == 'ready').length : 0;
    if (c.vlRw()) t.add(('lv', '🎁 마을 Lv 보상', vlClaimUi));
    if (ready > 0) t.add(('farm', '🌾 수확 $ready', () => vlSelect('farm', tab: 'farm')));
    if (c.ordReady() > 0) t.add(('market', '📋 납품 ${c.ordReady()}', () => vlSelect('market', tab: 'order')));
    if (c.blessLeft() > 0) t.add(('chapel', '✨ 축복 받기', () => vlSelect('chapel', tab: 'bless')));
    for (final b in vNewDone) {
      t.add((b, '🏗 공사 완료 · ${buildingDef(b).n}', () => vlSelect(b, tab: 'info')));
    }
    if (c.wkOpen() && c.idleIds().isNotEmpty) {
      final h = buildings.fold<int>(0, (a, b) => a + math.max(0, c.wkSlots(b.k) - c.wkIds(b.k).length));
      if (h > 0) t.add(('work', '🔨 일꾼 빈칸 $h', () => onWorkSheet?.call()));
    }
    if (truthy(s.bld['forge']) && (onForgeCan?.call() ?? false)) t.add(('forge', '⚒ 강화 가능', () => vlSelect('forge', tab: 'forge')));
    return t;
  }

  /// 화면 쪽에서 채워 넣는 것 (일꾼 관리 창 열기 · 강화 가능 판단)
  VoidCallback? onWorkSheet;
  bool Function()? onForgeCan;

  /// 마을 레벨 보상 받기 → 보상 창 · 처음 보는 동료 마을 에피소드
  void vlClaimUi() {
    final got = act((a) => a.vlClaim());
    for (final (l, ep) in got) {
      final g = vlvGem[l];
      scene('마을 Lv.$l', '마을이 살아나요', [
        'sys:마을 Lv.$l! 방치 골드 +${2 * l}%',
        'sys:황금 이삭 +$g${l == 5 ? ' · 배지 「마을의 영웅」' : l == 10 ? ' · 테두리 「에르단 마을」' : ''}',
      ], '좋아요');
      if (ep) {
        final e = villageEpisodes[l]!;
        scene('동료 마을 이야기', e.$1, e.$2, '마을로');
      }
    }
    if (got.isNotEmpty) {
      calc.pfCheck();
      save();
    }
  }

  /// 0.4초마다: 주문 채우기 · 편성으로 빠진 일꾼 · 건물 열림 이야기 · 일꾼 처음 열림 (웹 vlTick)
  void _vlTick() {
    calc.ordTick(acts.rng);
    final back = calc.wkClean();
    if (back.isNotEmpty && tab != GameTab.pt) {
      for (final id in back) {
        toast('${comps[id]!.n}이(가) 원정대로 돌아갔어요');
      }
    }
    final done = state.done;
    for (final k in const ['forge', 'market', 'ranch', 'chapel']) {
      if (truthy(done['vo_$k']) || !calc.bldOpen(k)) continue;
      done['vo_$k'] = 1;
      final b = buildingDef(k), mv = k == 'forge' && state.bldLv('forge') > 0;
      scene(
        mv ? '마을 · 이사' : '마을 · 새 빈터',
        mv ? '브론의 대장간 이사' : b.n,
        mv
            ? forgeMoveLines
            : [
                ...villageOpenLines[k]!,
                'sys:마을에 ${b.n} 빈터가 열렸어요. ${k == 'forge' ? '재건하면 성유물·동료 무기를 강화할 수 있어요.' : '마을 탭에서 재건해요.'}',
              ],
        '마을에서 보기',
        altLabel: '나중에',
        onGo: () => vlSelect(k),
      );
    }
    if (!truthy(state.raw['workIntro']) && calc.restIds().isNotEmpty && state.bldLv('inn') > 0) {
      state.raw['workIntro'] = 1;
      scene('마을 일꾼', '쉬는 동료에게 일을', const [
        'm:마르타|원정 안 나가는 동료들, 마을에서 놀고먹기만 할 거냐? 일 좀 시켜.',
        'k:다들 쉬고 싶을 텐데…',
        'q:주인이 쉬고 싶은 거겠지.',
        'k@flustered:…들켰네.',
        'sys:출전하지 않는 동료를 건물 일꾼으로 넣으면 건물 효과가 올라요. 직업이 맞으면 2배!',
      ], '추천 일꾼 넣기', altLabel: '나중에', onGo: () => act((a) => a.wkAuto(false)));
    }
  }

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
        _rpAdd((face: reportFace(ev.lines), eb: ev.eyebrow, t: ev.title, p: ev.lines, btn: ev.button, titleWidget: null));
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
          'q@proud:주인, 원정대의 힘이 가득 찼다! 빛나는 초상화를 눌러 봐라.',
          'sys:초상화 둘레의 금색 고리가 다 차면 특수 스킬을 쓸 수 있어요. 오른쪽 아래 AUTO를 켜 두면 알아서 써요. 초상화를 길게 누르면 스킬 설명이 나와요.',
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
        Timer(const Duration(milliseconds: 1100), () => queue((ctx) => _towerWinSheet(ctx, f, first, r, unlocked)));
      case TowerLoseEvent(:final f):
        queue((ctx) => _towerLoseSheet(ctx, f));
      case final DunEndEvent de:
        save();
        queue((ctx) => _dunEndSheet(ctx, de));
      case FightResetEvent():
        break;
    }
  }

  // ── 도전: 시련의 탑 · 요일 던전 (docs/content/CHALLENGE.md) ──
  /// 영지 20 탈환 때 한 번: 해금 대사 (웹 chCheck)
  void chCheck() {
    if (calc.chOpen || !calc.chCan()) return;
    state.raw['chOpen'] = 1;
    save();
    scene('새로운 도전', '시련의 탑', const [
      'sys:들판 끝에 오래된 석탑이 서 있다. 꼭대기가 구름에 가려 보이지 않는다.',
      'q:시련의 탑이다. 300년 전 에르단의 왕들은 왕관을 쓰기 전에 이 탑을 올랐지.',
      'k:꼭대기가 어디야?',
      'q:없다. 오를수록 높아진다.',
      'k@flustered:…그럼 은퇴는 언제 해?',
      'm:브론|탑 말고 내 폐광도 좀 봐 줘. 요일마다 광석이 쏟아진다고.',
      'sys:지도 탭의 「⚔ 도전」에서 시련의 탑과 요일 던전에 들어갈 수 있어요.',
    ], '도전 보러 가기', altLabel: '나중에', onGo: () => openChallenge(this), onAlt: () {
      // 「나중에」: 지도 탭에 빨간 점 (웹 dotSeen2.mp 지움)
      asMap(state.raw['dotSeen2'])?.remove('mp');
      refresh();
    });
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

  // ── 다음 할 일 안내 (웹 GUIDE.go) ──
  /// 상자 버튼 깜빡이기 (첫 안내)
  int hintBoxAt = 0;

  /// 단련 탭 추천 줄 반짝임 (웹 upGo .flash)
  int upHintAt = 0;
  String? upHintK;

  /// 웹 upGo(): 단련 탭을 열고 추천 줄을 반짝임
  void upGo() {
    upHintK = calc.upBest();
    upHintAt = DateTime.now().millisecondsSinceEpoch;
    setTab(GameTab.up);
  }

  /// 할 일을 누르면 그곳으로 (웹 guideNow().go). k: 'g0'~'g8' · 'up:..' · 'b:..'
  void guideGo(String k) {
    if (k.startsWith('up:')) return upGo();
    if (k.startsWith('b:')) return vlSelect(k.substring(2));
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

  // ── 은퇴 (웹 renderRetire 버튼 → scene → retireConfirm → retire) · 은퇴 일기 (docs/content/RETIRE.md) ──
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
    refresh();
  }

  /// 단련 탭 노란 점: 찍을 수 있는 특성이 있음 (웹 trCanAny)
  bool get upDot => calc.trCanAny();

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

  // ── 왕도 아스테리온 · 1부 엔딩 (docs/content/CAPITAL.md) ──
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

  static const _endingScenes = <(String, String, String?, List<String>, String)>[
    ('1부 엔딩 · 1', '왕좌 앞에서', 'ending1', ['m:발타사르@laugh|왕관은 무겁지. 지키고 싶은 것이 많을수록.', 'm:발타사르@laugh|이 왕관은 내가 가져간다. 진짜 왕이 될 자격이 있다면, 마계까지 찾아오너라.', 'sys:발타사르가 왕관을 들고 검은 문 너머로 사라졌다.'], '…'),
    ('1부 엔딩 · 2', '텅 빈 왕좌', null, ['k:…이겼다. 이제 은퇴?', 'q:아직이다. 왕관이 없는 왕은 왕이 아니다.', 'k@smile:나 왕 안 한다니까.'], '다음'),
    ('1부 엔딩 · 3', '왕궁 뜰', 'ending2', ['sys:되찾은 왕궁 뒤뜰. 카엘이 괭이로 땅을 고르고 있다.', 'q:주인, 거기는 왕궁 정원이다.', 'k@smile:좋은 흙이야. 여기다 밀 심으면 잘 자라겠어.', 'sys:1부 「잃어버린 왕국」 끝. 2부 「흩어진 동맹」에서 계속됩니다.'], '1부 완결'),
  ];

  /// 엔딩 장면 → 「1부 완결」 창. 일러스트(illust_ending1·illust_ending2)는 들어오기 전엔 건너뜀
  Future<void> _ending(int i) async {
    if (i >= _endingScenes.length) return _part1Sheet();
    final (eb, t, il, p, btn) = _endingScenes[i];
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
    ));
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

  /// 마을 탭 점 (웹 vDot): 수확 · 납품 · 축복 · 공사 완료 · 마을 레벨 보상 · 강화 가능 · 일꾼 빈칸(하루 한 번)
  bool get vlDot {
    final s = state, c = calc;
    if (truthy(s.bld['farm']) && s.plots.any((p) => c.plotState(p).st == 'ready')) return true;
    if (c.ordReady() > 0 || c.blessLeft() > 0 || vNewDone.isNotEmpty || c.vlRw()) return true;
    if (truthy(s.bld['forge']) && (onForgeCan?.call() ?? false)) return true;
    return s.raw['workDot'] != c.today() && c.wkOpen() && c.idleIds().isNotEmpty && buildings.any((b) => c.wkSlots(b.k) > c.wkIds(b.k).length);
  }

  /// 마을에서 바로 받을 수 있는 것 수 (웹 vReadyN): 다 자란 밭 + 납품할 주문 + 다 된 공사 + 마을 레벨 보상
  int vReadyN() {
    final s = state, c = calc;
    final ready = truthy(s.bld['farm']) ? s.plots.where((p) => c.plotState(p).st == 'ready').length : 0;
    return ready + c.ordReady() + vNewDone.length + (c.vlRw() ? 1 : 0);
  }

  /// 탭 점 서명 (웹 dotSig, U-2 ②): 「지금 누르면 바로 이득」인 이유들. 탭을 열면 본 것으로 기록
  String dotSig(GameTab t) {
    final c = calc;
    switch (t) {
      case GameTab.up:
        return c.trCanAny() ? 'm${c.memPts()}' : '';
      case GameTab.vl:
        if (!vlDot) return '';
        final s = state;
        final w = s.raw['workDot'] != c.today() && c.wkOpen() && c.idleIds().isNotEmpty;
        return [
          vReadyN(),
          c.ordReady(),
          c.blessLeft() > 0 ? 'b${c.today()}' : '',
          (vNewDone.toList()..sort()).join('.'),
          c.vlRw() ? 'r${c.vLv()}' : '',
          truthy(s.bld['forge']) && (onForgeCan?.call() ?? false) ? 'f' : '',
          w ? 'w' : '',
        ].join('|');
      case GameTab.mp:
        return c.chDot() ? 'c${c.supplyCan() ? 1 : 0}.${c.dunLeft()}.${c.today()}' : '';
      case GameTab.sh:
        final d = c.daily();
        final claim = asMap(d['claim']) ?? const <String, dynamic>{};
        final n = missions.where((m) => orNum(d[m.k], 0) >= m.goal && !truthy(claim[m.k])).length +
            (missions.every((m) => truthy(claim[m.k])) && !truthy(claim['all']) ? 1 : 0) +
            (c.subOn() && asMap(state.raw['sub'])?['last'] != c.today() ? 1 : 0);
        final a = acts.adKeys().any((k) => c.adLeft(k) > 0);
        return n > 0 || a ? 's$n${a ? 'a' : ''}${c.today()}' : '';
      default:
        return '';
    }
  }

  bool dotOn(GameTab t) {
    final sig = dotSig(t);
    if (sig.isEmpty) return false;
    final seen = asMap(state.raw['dotSeen2']) ?? (state.raw['dotSeen2'] = <String, dynamic>{});
    if (tab == t) {
      seen[t.name] = sig;
      return false;
    }
    return sig != seen[t.name];
  }

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
