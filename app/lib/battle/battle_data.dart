/// 전투 그림·몬스터 표 (웹 「이미지 에셋」 구역). 값은 web_data.g.dart 에서 자동으로 옮겨 온 것.
library;

import 'dart:ui' as ui;

import '../core/web_data.g.dart';

Map<String, dynamic> _m(Object? v) => (v as Map).cast<String, dynamic>();
num _n(Object? v) => v as num;

/// 동료 스프라이트 시트 정보: 동작별 프레임 수, 화면 키(h)
class CharSheet {
  CharSheet._(Map<String, dynamic> m)
      : idle = _n(m['idle']).toInt(), walk = _n(m['walk']).toInt(), attack = _n(m['attack']).toInt(),
        hit = _n(m['hit']).toInt(), h = _n(m['h']);
  final int idle, walk, attack, hit;
  final num h;
  int frames(String anim) => switch (anim) { 'idle' => idle, 'walk' => walk, 'attack' => attack, _ => hit };
}

final Map<String, CharSheet> charSheets = {for (final e in wSprites.entries) e.key: CharSheet._(_m(e.value))};
final int sprFrame = _n(wSprConst['frame']).toInt(), sprFoot = _n(wSprConst['foot']).toInt();
final num sprFig = _n(wSprConst['fig']);

/// 몬스터 시트: assets/monsters/<id>_<walk|attack|hit>.png, 왼쪽을 봄
class MonSheet {
  MonSheet._(Map<String, dynamic> m)
      : id = m['id'], walk = _n(m['walk']).toInt(), attack = _n(m['attack']).toInt(), hit = _n(m['hit']).toInt(),
        fig = _n(m['fig']), h = _n(m['h']), lift = m['lift'] == null ? null : _n(m['lift']), trait = m['trait'],
        boss = m['boss'] == null ? null : MonSheet._(_m(m['boss']));
  final String id;
  final int walk, attack, hit;
  final num fig, h;
  final num? lift;
  final String? trait;
  final MonSheet? boss;
}

/// 지역 번호 → 기본 마물(+군단장 그림)
final Map<int, MonSheet> monSheets = {for (final e in wMonSprites.entries) int.parse(e.key): MonSheet._(_m(e.value))};

/// 지역 번호 → 두 번째 마물(특성 있음)
final Map<int, MonSheet> monAlt = {for (final e in wMonAlt.entries) int.parse(e.key): MonSheet._(_m(e.value))};
final MonSheet goblinSheet = MonSheet._(_m(wGob));

/// 마왕 발타사르 1·2단계 전용 그림 (assets/monsters/boss_baltasar{,2}_*.png). 없으면 알도르 그림을 물들여 씀
final List<MonSheet> baltasarSheets = [
  for (final id in ['boss_baltasar', 'boss_baltasar2']) MonSheet._({'id': id, 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 175, 'h': 78}),
];

/// 발타사르 시전 동작 프레임 수 (assets/monsters/boss_baltasar{,2}_cast.png, 봉인의 파동 예고 동안)
const int baltasarCast = 4;

/// 봉인의 파동 위치 (웹 sealGeo). 효과 그림 fx_boss_seal 은 512x384 칸, 바닥 y=372
({double cx, double cy, double rx, double ry}) sealGeo(List<String> ids, Map<String, num> pos, num front, num top, num bot, num s) {
  final back = ids.map((i) => pos[i]!).reduce((a, b) => a < b ? a : b).toDouble();
  final rx = ((front - back) * .75 + 50 * s).toDouble();
  final r = rx < 80 ? 80.0 : rx;
  return (cx: (back + front) / 2, cy: ((top + bot) / 2 + 10 * s).toDouble(), rx: r, ry: r * .32);
}

double sealFxY(double cy, double sz) => cy + sz / 2 - sz * 372 / 384;

/// 왕도 그림이 오기 전 대체: 기존 그림 + 색 (웹 MON_SPRITES[5].tint · MON_ALT[5].tint)
class CapTint {
  const CapTint(this.src, this.color, this.mode);
  final MonSheet src;
  final ui.Color color;
  final ui.BlendMode mode;
}

final Map<String, CapTint> capTint = {
  'guard_black': CapTint(monSheets[2]!, const ui.Color(0xFF4B3F6A), ui.BlendMode.multiply), // 흑철 근위병 ← 강철 골렘
  'boss_guardcap': CapTint(monSheets[2]!, const ui.Color(0xFF7A5A2E), ui.BlendMode.multiply), // 근위대장 ← 강철 골렘(검은 청동)
  'gargoyle_wall': CapTint(monSheets[1]!, const ui.Color(0xFF9C9AA8), ui.BlendMode.color), // 성벽 가고일 ← 그림자 박쥐(회색)
};

class Trait {
  Trait._(Map<String, dynamic> m) : hp = _n(m['hp']), atk = _n(m['atk']), mv = _n(m['mv']), cd = _n(m['cd']), n = m['n'];
  final num hp, atk, mv, cd;
  final String n;
}

final Map<String, Trait> traits = {for (final e in wTraits.entries) e.key: Trait._(_m(e.value))};

/// 효과 시트 프레임 수: assets/fx/fx_<이름>.png
final Map<String, int> fxFrames = {for (final e in wFxdef.entries) e.key: _n(e.value).toInt()};

/// 원정대 대형 [가로 위치, 깊이]
final Map<String, List<num>> formation = {for (final e in wForm.entries) e.key: (e.value as List).cast<num>()};

final num gobRareBadge = _n(wGobRare['badge']), gobRareFrame = _n(wGobRare['frame']);

/// 지역 번호 → 배경 그림 이름, 꽉 찬 배경 여부
final Map<int, String> bgImage = {for (final e in wBgImg.entries) int.parse(e.key): e.value};
final Set<String> bgFull = {for (final e in wBgFull.entries) if (e.value == true) e.key};
final List<String> decoKinds = wDeco.cast<String>();

/// 웹 코드 그림의 키(HEIGHT). 스프라이트가 있으면 시트의 h 를 씀
num heightOf(String id) => charSheets[id]?.h ?? 66;
