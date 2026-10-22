/// 게임 데이터 표 (웹 index.html 「데이터」 구역과 같은 내용).
///
/// 값 자체는 [web_data.g.dart] 에 웹에서 자동으로 옮겨 온 것을 쓰고,
/// 여기서는 앱 코드가 쓰기 편하게 이름 붙인 형태로 감싼다.
library;

import 'web_data.g.dart';

export 'web_data.g.dart' show wSaveKey;

num _n(Object? v) => v as num;
List<String> _ss(Object? v) => (v as List).cast<String>();
Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();

/// '#rrggbb' → 0xFFrrggbb
int hexColor(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);

// ── 장비 ──
class SlotDef {
  SlotDef._(Map<String, dynamic> m)
      : k = m['k'], n = m['n'], a = _n(m['a']), h = _n(m['h']);
  final String k, n;
  final num a, h;
}

class ItemGrade {
  ItemGrade._(Map<String, dynamic> m) : n = m['n'], color = m['c'], m = _n(m['m']);
  final String n, color;
  final num m;
}

final slots = [for (final x in wSlots) SlotDef._(_m(x))];
final itemGrades = [for (final x in wGrades) ItemGrade._(_m(x))];
final List<num> baseOdds = wBaseOdds.cast<num>();
SlotDef slotDef(String k) => slots.firstWhere((s) => s.k == k);

// ── 지역·영지 ──
class RegionDef {
  RegionDef._(Map<String, dynamic> m)
      : n = m['n'],
        sky = _ss(m['sky']),
        hill = m['hill'],
        hill2 = m['hill2'],
        ground = m['ground'],
        kind = m['kind'],
        col = m['col'],
        mn = m['mn'],
        boss = m['boss'],
        terr = _ss(m['terr']),
        lore = _ss(m['lore']);
  final String n, hill, hill2, ground, kind, col, mn, boss;
  final List<String> sky, terr, lore;
}

final regions = [for (final x in wRegions) RegionDef._(_m(x))];
const int maxLand = wMaxland;
final List<String> bossIds = wBossid.cast<String>();

// ── 동료 ──
class CompStat {
  CompStat._(Map<String, dynamic> m) : atk = _n(m['atk']), hp = _n(m['hp']), aps = m['aps'] == null ? null : _n(m['aps']);
  final num atk, hp;
  final num? aps;
}

class CompDef {
  CompDef._(this.id, Map<String, dynamic> m)
      : n = m['n'],
        role = m['role'],
        desc = m['desc'],
        join = m['join'],
        base = m['base'] == null ? null : CompStat._(_m(m['base'])),
        per = m['per'] == null ? null : CompStat._(_m(m['per']));
  final String id, n, role, desc;
  final String? join;

  /// 카엘은 null (카엘 능력치는 단련·장비로 계산)
  final CompStat? base, per;
}

final Map<String, CompDef> comps = {for (final e in wComp.entries) e.key: CompDef._(e.key, _m(e.value))};

/// 동료 → 직업 (miner·fisher·keeper·cook)
final Map<String, String> jobOf = wJob.cast<String, String>();
final Map<String, String> jobName = wJobn.cast<String, String>();

/// 편성 자리 순서 (가운데가 카엘)
final List<String> jobSlots = wJslot.cast<String>();

/// 직업 → 이야기 동료
final Map<String, String> storyOf = wStory.cast<String, String>();
final List<String> partyOrder = wOrder.cast<String>();
final Map<String, num> spriteHeight = wHeight.cast<String, num>();

class RecruitDef {
  RecruitDef._(this.id, Map<String, dynamic> m)
      : job = m['job'], title = m['title'], lines = _ss(m['lines']), ok = m['ok'];
  final String id, job, title, ok;
  final List<String> lines;
}

/// 모집 동료 (웹과 같은 순서)
final Map<String, RecruitDef> recruits = {
  for (final e in wRecruits.entries) e.key: RecruitDef._(e.key, _m(e.value))
};

final List<num> starNeedLegacy = wStarNeed.cast<num>();
final List<num> starMulTable = wStarMul.cast<num>();

/// 동료 → 등급 키 (common·rare·epic·legend)
final Map<String, String> gradeOf = wGrade.cast<String, String>();

class CompGrade {
  CompGrade._(this.key, Map<String, dynamic> m)
      : n = m['n'],
        color = m['c'],
        max = _n(m['max']).toInt(),
        mul = _n(m['mul']),
        w = _n(m['w']),
        need = (m['need'] as List).cast<num>(),
        frame = m['fr'];
  final String key, n, color, frame;
  final int max;
  final num mul, w;
  final List<num> need;
}

final Map<String, CompGrade> compGrades = {for (final e in wGr.entries) e.key: CompGrade._(e.key, _m(e.value))};

/// 전설 동료 마을 스킬 이름
final Map<String, String> villageSkillName = {for (final e in wVpas.entries) e.key: _m(e.value)['n'] as String};

class SkillDef {
  SkillDef._(this.id, Map<String, dynamic> m)
      : n = m['n'], d = m['d'], line = m['line'], need = _n(m['need']), face = m['face'];
  final String id, n, d, line, face;
  final num need;
}

final Map<String, SkillDef> skills = {for (final e in wSkills.entries) e.key: SkillDef._(e.key, _m(e.value))};

// ── 밸런스 손잡이 ──
class Balance {
  static final num hpG = _n(wBal['hpG']), atkG = _n(wBal['atkG']), goldG = _n(wBal['goldG']), boxG = _n(wBal['boxG']);
  static final num bossHp = _n(wBal['bossHp']), lordHp = _n(wBal['lordHp']);
  static final num bossAtk = _n(wBal['bossAtk']), lordAtk = _n(wBal['lordAtk']);
  /// 마왕 발타사르: 체력 ×demHp, 공격 1단계 ×demAtk → 2단계 ×demAtk2, 봉인의 파동 = 공격 ×seal
  static final num demHp = _n(wBal['demHp']), demAtk = _n(wBal['demAtk']), demAtk2 = _n(wBal['demAtk2']), seal = _n(wBal['seal']);
}

const num compGrow = wCompGrow;
const num bless = wBless;
const int enMax = wEnMax;
const int cwMax = wCwMax;
final Map<String, String> compWeapon = wCw.cast<String, String>();

// ── 단련 ──
class UpgradeDef {
  UpgradeDef._(Map<String, dynamic> m) : k = m['k'], n = m['n'], max = _n(m['max']).toInt();
  final String k, n;
  final int max;
}

final upgrades = [for (final x in wUpg) UpgradeDef._(_m(x))];

// ── 밭·생산·요리 ──
class CropDef {
  CropDef._(Map<String, dynamic> m)
      : k = m['k'], n = m['n'], t = _n(m['t']), color = m['c'], sell = _n(m['sell']), drop = _n(m['drop']);
  final String k, n, color;
  final num t, sell, drop;
}

class GoodDef {
  GoodDef._(Map<String, dynamic> m) : k = m['k'], n = m['n'], color = m['c'], sell = _n(m['sell']), b = m['b'];
  final String k, n, color, b;
  final num sell;
}

class RecipeDef {
  RecipeDef._(Map<String, dynamic> m)
      : k = m['k'], n = m['n'], need = _m(m['need']).cast<String, num>(), buff = m['buff'], desc = m['desc'];
  final String k, n, buff, desc;
  final Map<String, num> need;
}

final crops = [for (final x in wCrops) CropDef._(_m(x))];
final goods = [for (final x in wGoods) GoodDef._(_m(x))];
final recipes = [for (final x in wRecipes) RecipeDef._(_m(x))];
final Map<String, String> buffName = wBuffn.cast<String, String>();
final Map<String, String> itemName = {for (final c in crops) c.k: c.n, for (final g in goods) g.k: g.n};

/// 판매가 기준 (작물·생산품)
num baseSell(String k) {
  for (final c in crops) {
    if (c.k == k) return c.sell;
  }
  return goods.firstWhere((g) => g.k == k).sell;
}

// ── 마을 건물 ──
class BuildingDef {
  BuildingDef._(Map<String, dynamic> m)
      : k = m['k'], n = m['n'], who = m['who'], max = _n(m['max']).toInt(), base = _n(m['base']), lock = m['lock'];
  final String k, n, who, lock;
  final int max;
  final num base;
}

final buildings = [for (final x in wBld) BuildingDef._(_m(x))];
BuildingDef buildingDef(String k) => buildings.firstWhere((b) => b.k == k);
const int buildQueueMax = wBqMax;
const int tutGem = wTutGem;
final List<num> gemPlotCost = wGemPlots.cast<num>();

// ── 칭호·이야기 ──
class RankDef {
  RankDef._(Map<String, dynamic> m) : at = _n(m['at']).toInt(), n = m['n'], k = m['k'];
  final int at;
  final String n;
  final String? k;
}

final ranks = [for (final x in wRanks) RankDef._(_m(x))];

class StoryEventDef {
  StoryEventDef._(Map<String, dynamic> m)
      : at = _n(m['at']).toInt(), id = m['id'], eyebrow = m['eb'], title = m['t'], lines = _ss(m['p']), button = m['btn'];
  final int at;
  final String id, eyebrow, title, button;
  final List<String> lines;
}

final storyEvents = [for (final x in wEvents) StoryEventDef._(_m(x))];

/// 전투 중 한마디 ['k'|'q', 대사]
final List<List<String>> quips = [for (final q in wQuips) _ss(q)];
final List<String> lumQuotes = wLumq.cast<String>();

// ── 오늘의 할 일·광고·상점 ──
class MissionDef {
  MissionDef._(Map<String, dynamic> m) : k = m['k'], n = m['n'], goal = _n(m['goal']), r = _n(m['r']);
  final String k, n;
  final num goal, r;
}

final missions = [for (final x in wMissions) MissionDef._(_m(x))];
const int missionAllReward = wMisAll, rankGem = wRankGem, lordGem = wLordGem;

/// 왕도 보상 (웹 GHOST_GEM · DEMON_GEM · CAP_MEM)
const int ghostGem = 30, demonGem = 300, capMem = 3;

class AdDef {
  AdDef._(this.k, Map<String, dynamic> m) : n = _n(m['n']).toInt(), t = m['t'];
  final String k, t;

  /// 하루 횟수
  final int n;
}

final Map<String, AdDef> ads = {for (final e in wAds.entries) e.key: AdDef._(e.key, _m(e.value))};

class GemPack {
  GemPack._(Map<String, dynamic> m) : k = m['k'], gem = _n(m['gem']), won = _n(m['won']);
  final String k;
  final num gem, won;
}

final gemPacks = [for (final x in wPacks) GemPack._(_m(x))];

class GoldExchange {
  GoldExchange._(Map<String, dynamic> m) : k = m['k'], n = m['n'], gem = _n(m['gem']), h = _n(m['h']);
  final String k, n;
  final num gem, h;
}

final goldExchanges = [for (final x in wGoldx) GoldExchange._(_m(x))];
final Map<String, dynamic> subscription = _m(wSub);
final Map<String, dynamic> starterPack = _m(wStarter);
final List<Map<String, dynamic>> cardPacks = [for (final x in wCardpk) _m(x)];
const int gem10 = wGem10, gemPlot = wGemPlot, gemOffline = wGemOffline;
