/// 전투 그림·몬스터 표 (웹 「이미지 에셋」 구역). 값은 web_data.g.dart 에서 자동으로 옮겨 온 것.
library;

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
