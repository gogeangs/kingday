// 정기 이벤트 「눈꽃제」 화면 쪽 (docs/content/EVENT_SNOW.md) — 웹 evSheet·evBossEnd·evScenes·evXmasCheck·evGiftSheet·
// evWarnCheck·evFetch·evBoot 를 옮김. 규칙·저장은 core/event.dart (EventCalc·EventAct).
part of 'controller.dart';

extension GameEventX on GameController {
  /// 눈사람 대장 끝 (웹 evBossWin·evBossLose → evBossEnd): 보상을 넣고, 이기면 1.3초 뒤 결과 창
  void _evBossEnd(EvBossEndEvent e) {
    final (sf, rows) = acts.evBossResult(e.ev, e.won, e.stg, e.santa);
    save();
    void end() {
      sim.chExit();
      refresh();
    }

    if (e.won) {
      Timer(const Duration(milliseconds: 1300), end);
    } else {
      end();
    }
    // 결과 창은 화면 작업에서 (sf·rows 를 보여 줌)
    if (sf <= 0 && rows.isEmpty) return;
  }
}
