/// 게임 저장 데이터 — 웹의 `S` 객체와 **같은 JSON 구조**.
///
/// 웹에서 클라우드 저장한 기록을 앱에서 그대로 불러오고, 앱 기록을 웹에서도 열 수 있게
/// 내부는 JSON Map 하나로 들고 있다(모르는 필드도 지우지 않고 그대로 보존).
/// 자주 쓰는 필드만 이름 붙인 읽기·쓰기 손잡이를 둔다.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'js.dart';
import 'web_data.g.dart';

class GameState {
  GameState(this.raw);

  /// 웹 S 와 같은 JSON (그대로 저장·업로드)
  final Map<String, dynamic> raw;

  // ── 새 게임 · 불러오기 (index.html fresh() / hydrate()) ──

  /// index.html fresh() 와 같은 기본값
  static Map<String, dynamic> freshMap(int now) => {
        'gold': 0, 'stage': 1, 'wave': 0, 'boxLv': 1, 'boxXp': 0,
        'up': {'atk': 0, 'hp': 0, 'spd': 0, 'crit': 0},
        'eq': <String, dynamic>{}, 'autoSell': false, 'autoOpen': false, 'last': now, 'best': 1, 'started': false,
        'joined': <String, dynamic>{}, 'done': <String, dynamic>{},
        'lv': {'bron': 1, 'haral': 1, 'riel': 1, 'margo': 1},
        'bld': {'inn': 0, 'farm': 0, 'diner': 0, 'dock': 0, 'apiary': 0, 'mine': 0, 'forge': 0, 'market': 0, 'ranch': 0, 'chapel': 0},
        'plots': <dynamic>[], 'seeds': {'wheat': 0, 'carrot': 0, 'pumpkin': 0},
        'items': {'wheat': 0, 'carrot': 0, 'pumpkin': 0, 'fish': 0, 'honey': 0, 'ore': 0, 'egg': 0, 'milk': 0},
        'prod': <String, dynamic>{}, 'buffs': <String, dynamic>{}, 'rankSeen': 0, 'memory': 0, 'retires': 0,
        'buys': <String, dynamic>{}, 'sub': {'until': 0, 'last': ''}, 'ucard': 0, 'gem': 0, 'gemRank': 0,
        'gemLord': <String, dynamic>{},
        'daily': {'d': '', 'kill': 0, 'box': 0, 'harv': 0, 'claim': <String, dynamic>{}},
        // 출석체크 (docs/content/ATTENDANCE.md) — 웹과 같은 필드명
        'att': {'last': '', 'w': 0, 'ym': '', 'm': 0, 'ad': '', 'got': <dynamic>[], 'intro': 0, 'tab': 'w'},
        'tickets': {'box': 0, 'box10': 0},
        // 왕도·1부 엔딩 (docs/content/CAPITAL.md 7장)
        'capClears': 0, 'capBonus': 0, 'ending1': 0,
        // 도전: 시련의 탑·요일 던전 (docs/content/CHALLENGE.md 7장) — chOpen·tower·dun.star 는 은퇴해도 유지
        'chOpen': 0,
        'tower': {'top': 0, 'day': '', 'pk': 0},
        'dun': {'d': '', 'used': 0, 'ad': 0, 'star': {'mine': <String, dynamic>{}, 'field': <String, dynamic>{}, 'vault': <String, dynamic>{}}, 'seen': <String, dynamic>{}},
        // 대륙 지도 (docs/content/WORLDMAP.md 7장)
        'mapIntro': 0, 'fogSeen': 1, 'regSeen': <String, dynamic>{},
        // 은퇴 일기 (docs/content/RETIRE.md 7장) — trait·trReset·retRw 는 은퇴해도 유지, runStart 는 이번 회차 시작 영지
        'trait': <String, dynamic>{}, 'trReset': 0, 'runStart': 1, 'retRw': <String, dynamic>{}, 'diaryIntro': 0,
        // 마을 확장 (docs/content/VILLAGE.md 7장) — 은퇴해도 모두 유지
        'orders': <dynamic>[], 'ordDay': {'d': '', 'gem': 0, 'skip': <String, dynamic>{}},
        'bless': {'d': '', 'used': 0, 'ad': 0, 'k': '', 'until': 0, 'opts': <dynamic>[]},
        'vlv': 1, 'ep': <String, dynamic>{}, 'walkers': {'d': '', 'ids': <dynamic>[]}, 'keepOrder': 1,
        'work': <String, dynamic>{}, 'workIntro': 0, 'workDot': '',
        'v': 3,
      };

  /// index.html hydrate(d): 저장된 값을 기본값 위에 얹는다.
  /// [rankIdx] 는 옛 저장(v<3)의 칭호 기록을 맞출 때 쓴다(공식 쪽에서 넘겨줌).
  static GameState hydrate(Map<String, dynamic> d, int now, int Function(GameState) rankIdx) {
    final src = deepCopy(d) as Map<String, dynamic>;
    final f = freshMap(now);
    for (final k in src.keys) {
      final fv = f[k], dv = src[k];
      // 웹 okVal: 기본값이 숫자·객체·배열인 칸에 종류가 다른 값(null·NaN·무한대·글자 등)은 버리고 기본값
      if (f.containsKey(k) ? !_okVal(fv, dv) : _badNum(dv)) continue;
      if (fv is Map) {
        // Object.assign(f[k], d[k]) — 기본값 객체에 저장 값을 덮어씀(한 단계만), 칸마다 같은 규칙
        final merged = Map<String, dynamic>.from(fv);
        (dv as Map).forEach((sk, b) {
          final a = fv[sk];
          if ((a is num || a is Map || a is List) && !_okVal(a, b)) return;
          if (_badNum(b)) return;
          merged['$sk'] = b;
        });
        f[k] = merged;
      } else {
        f[k] = dv;
      }
    }
    final crops = asMap(src['crops']);
    if (crops != null) {
      final items = asMap(f['items'])!;
      for (final k in crops.keys) {
        final cv = crops[k];
        items[k] = orNum(items[k], 0) + (cv is num && cv.isFinite ? cv : 0);
      }
      f.remove('crops');
    }
    final g = GameState(f);
    if (asNum(src['v']) < 3) f['rankSeen'] = rankIdx(g);
    // 왕도 이전 저장: 예전 「왕도 진격로」(51 이상)에 있던 기록은 51(남쪽 성문)부터, 최고 기록도 51까지
    const cap1 = wMaxland - 9, last = wMaxland + 1;
    if (src['capClears'] == null) {
      if (asNum(f['stage']) > cap1) {
        f['stage'] = cap1;
        f['wave'] = 0;
      }
      if (asNum(f['best']) > cap1) f['best'] = cap1;
    }
    // 도전: 별 기록 3종·소개 대사 기록이 빠진 저장도 채움 (웹 hydrate)
    final dun = asMap(f['dun'])!;
    dun['star'] = <String, dynamic>{'mine': <String, dynamic>{}, 'field': <String, dynamic>{}, 'vault': <String, dynamic>{}, ...?asMap(dun['star'])};
    if (!truthy(dun['seen'])) dun['seen'] = <String, dynamic>{};
    // 마을 확장: 광산이 있던 세이브는 브론의 대장간을 Lv.1로 지어 줌(강화 기록 slotEn·cwEn은 그대로)
    final sb = asMap(src['bld']);
    if (!(sb != null && sb['forge'] != null) && f['bld'] is Map && asNum((f['bld'] as Map)['mine']) > 0) (f['bld'] as Map)['forge'] = 1;
    // 유니크 카드: 0 이상 정수 · 카엘 자리는 카엘 촌장만 저장 (웹 hydrate)
    f['ucard'] = math.max(0, asNum(f['ucard']).isFinite ? asNum(f['ucard']).floor() : 0);
    final pty = asMap(f['party']);
    if (pty != null && pty['kael'] != null && pty['kael'] != 'kael_chief') pty.remove('kael');
    final f0 = freshMap(now);
    for (final k in const ['ordDay', 'bless', 'walkers', 'work']) {
      if (f[k] is! Map) f[k] = f0[k];
    }
    if (f['orders'] is! List) f['orders'] = <dynamic>[];
    final wk = (f['work'] as Map);
    wk.removeWhere((k, v) => v is! List);
    final bl = f['bless'] as Map;
    if (bl['opts'] is! List) bl['opts'] = <dynamic>[];
    final od = f['ordDay'] as Map;
    if (!truthy(od['skip']) || od['skip'] is! Map) od['skip'] = <String, dynamic>{};
    final wl = f['walkers'] as Map;
    if (wl['ids'] is! List) wl['ids'] = <dynamic>[];
    // 대륙 지도: 기존 세이브는 지금 S.best까지 걷힘 연출을 본 것으로 (연출이 몰려 나오지 않게)
    final best = f['best'] is num ? f['best'] as num : 1;
    if (src['fogSeen'] == null) {
      f['fogSeen'] = math.max(1, best);
      if (f['regSeen'] is! Map) f['regSeen'] = <String, dynamic>{};
      for (var r = 0; r < 6; r++) {
        if (best > 10 * (r + 1)) (f['regSeen'] as Map)['$r'] = 1;
      }
    }
    if (f['regSeen'] is! Map) f['regSeen'] = <String, dynamic>{};
    if (asNum(f['stage']) > last) f['stage'] = last;
    return g;
  }

  static bool _okVal(Object? fv, Object? dv) {
    if (fv is num) return dv is num && dv.isFinite;
    if (fv is Map) return dv is Map;
    if (fv is List) return dv is List;
    return dv != null;
  }

  static bool _badNum(Object? v) => v is num && !v.isFinite;

  /// 웹 isSave(d): 저장처럼 보이는지 — 골드 칸이 있으면 (값이 깨져 null 이어도 다른 기록은 살림)
  static bool looksLikeSave(Object? d) => d is Map && d.containsKey('gold');

  /// 처음 시작하는 게임 (웹 start(): hydrate({gold:60}))
  static GameState newGame(int now, int Function(GameState) rankIdx) => hydrate({'gold': 60}, now, rankIdx);

  static GameState fromJson(String s, int now, int Function(GameState) rankIdx) =>
      hydrate(jsonDecode(s) as Map<String, dynamic>, now, rankIdx);

  String toJson() => jsonEncode(raw);

  // ── 이름 붙인 손잡이 ──
  Map<String, dynamic> _obj(String k) {
    final v = raw[k];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return raw[k] = v.cast<String, dynamic>();
    return raw[k] = <String, dynamic>{};
  }

  Map<String, dynamic>? _objOrNull(String k) => asMap(raw[k]);

  num get gold => asNum(raw['gold']);
  set gold(num v) => raw['gold'] = v;
  int get stage => asNum(raw['stage'], 1).toInt();
  set stage(int v) => raw['stage'] = v;
  int get wave => asNum(raw['wave']).toInt();
  set wave(int v) => raw['wave'] = v;
  int get best => asNum(raw['best'], 1).toInt();
  set best(int v) => raw['best'] = v;
  int get boxLv => asNum(raw['boxLv'], 1).toInt();
  set boxLv(int v) => raw['boxLv'] = v;
  int get boxXp => asNum(raw['boxXp']).toInt();
  set boxXp(int v) => raw['boxXp'] = v;
  num get memory => asNum(raw['memory']);
  set memory(num v) => raw['memory'] = v;
  num get retires => asNum(raw['retires']);
  set retires(num v) => raw['retires'] = v;
  num get gem => orNum(raw['gem'], 0);
  set gem(num v) => raw['gem'] = v;
  num get last => asNum(raw['last']);
  set last(num v) => raw['last'] = v;
  num get gemPlots => orNum(raw['gemPlots'], 0);
  String? get wish => raw['wish'] is String && (raw['wish'] as String).isNotEmpty ? raw['wish'] : null;
  set wish(String? v) => raw['wish'] = v;

  /// 단련 레벨 {atk,hp,spd,crit}
  Map<String, dynamic> get up => _obj('up');

  /// 장착 중인 성유물 {부위: {slot,g,lv,atk,hp,price}}
  Map<String, dynamic> get eq => _obj('eq');
  Map<String, dynamic> get joined => _obj('joined');
  Map<String, dynamic> get done => _obj('done');
  Map<String, dynamic> get lv => _obj('lv');
  Map<String, dynamic> get bld => _obj('bld');
  Map<String, dynamic> get seeds => _obj('seeds');
  Map<String, dynamic> get items => _obj('items');
  Map<String, dynamic> get prod => _obj('prod');
  Map<String, dynamic> get buffs => _obj('buffs');
  Map<String, dynamic> get buys => _obj('buys');
  Map<String, dynamic> get sub => _obj('sub');
  List<dynamic> get plots => raw['plots'] is List ? raw['plots'] as List : (raw['plots'] = <dynamic>[]);

  /// 없을 수도 있는 것들 (웹: S.rec&&S.rec[id] 처럼 확인)
  Map<String, dynamic>? get rec => _objOrNull('rec');
  Map<String, dynamic> get recW => _obj('rec');
  Map<String, dynamic>? get cards => _objOrNull('cards');
  Map<String, dynamic> get cardsW => _obj('cards');
  Map<String, dynamic>? get party => _objOrNull('party');
  Map<String, dynamic>? get slotEn => _objOrNull('slotEn');
  Map<String, dynamic>? get cwEn => _objOrNull('cwEn');

  num bldLv(String k) => asNum(bld[k]);
  num upLv(String k) => asNum(up[k]);
  bool isJoined(String id) => truthy(joined[id]);
}
