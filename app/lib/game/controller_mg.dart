// 미니게임 「선물 배달」·랭킹 결과·외형 화면 쪽 (docs/content/EVENT_SNOW.md 3-9~3-11) — 웹 evMgStart·mgEnd·evMgResult·skinSheet 를 옮김.
// 판 계산은 core/minigame.dart (MgGame), 저장·규칙은 core/event.dart.
part of 'controller.dart';

extension GameMgX on GameController {
  /// 선물 배달 시작 (웹 evMgStart). practice = 연습판(보상·기록 없음)
  Future<void> evMgStart(String id, bool practice) async {}

  /// 외형 고르기 창 (웹 skinSheet · 장비 탭 카엘 칸 「외형」)
  void openSkinSheet() {}
}
