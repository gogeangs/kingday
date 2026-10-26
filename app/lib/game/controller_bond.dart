// 원정대의 정 (docs/content/BOND.md): 관계 이야기 띄우기 · 원정대 일기
// (웹 bondCheck·bondPlay·bondDiary — 상태 변경은 core/bond.dart 의 BondAct)
part of 'controller.dart';

extension GameBondX on GameController {
  /// 새로 열린 관계 이야기: 토스트 → 다른 창이 없을 때 장면 (웹 bondCheck)
  void bondOpenFx(int k) {
    if (!bondQ.add(k)) return;
    final b = bonds.firstWhere((x) => x.k == k);
    toast('원정대 일기: 「${b.t}」가 열렸어요');
    queue((ctx) async => act((a) => a.bondPlay(k)));
  }

  /// 장면 보기 (웹 bondPlay 의 scene)
  void bondSceneFx(int k, bool first) {
    bondQ.remove(k);
    final b = bonds.firstWhere((x) => x.k == k);
    scene('원정대 일기', b.t, b.lines, first ? '황금 이삭 20 받기' : '닫기');
  }
}
