/// 은퇴 심화 「카엘의 은퇴 일기」: 추억 포인트 특성 · 지름길 · 은퇴 횟수 보상 (docs/content/RETIRE.md)
///
/// 웹 index.html 「은퇴 일기」 구역(MEMT·tl·retStart·retirePts·RET_RW)과 같은 규칙·같은 저장 필드
/// (S.trait, S.trReset, S.runStart, S.retRw, S.diaryIntro). 효과 배수(trAtk 등)는 calc.dart 의 GameCalc 안에 있다.
library;

import 'dart:math' as math;

import 'calc.dart';
import 'js.dart';

class MemBranch {
  const MemBranch(this.k, this.ic, this.n, this.d);
  final String k, ic, n, d;
}

const memBranches = [
  MemBranch('sword', '⚔', '검의 기억', '전투'),
  MemBranch('farm', '🌾', '밭의 기억', '마을'),
  MemBranch('travel', '🎒', '여행의 기억', '은퇴·편의'),
];

/// 줄 r을 열려면 그 갈래에 써야 하는 포인트
const memRow = [0, 0, 10, 30];

class MemTrait {
  const MemTrait(this.k, this.b, this.r, this.n, this.c, this.e);
  final String k, b, n;
  final int r;

  /// 단계별 비용
  final List<int> c;

  /// 단계 l의 효과 문구
  final String Function(int l) e;
  int get max => c.length;
}

final List<MemTrait> memTraits = [
  MemTrait('sharp', 'sword', 1, '날 선 괭이', const [1, 1, 2, 2, 3, 3, 4, 4], (l) => '원정대 공격 +${4 * l}%'),
  MemTrait('hat', 'sword', 1, '두꺼운 밀짚모자', const [1, 1, 2, 2, 3, 3, 4, 4], (l) => '원정대 체력 +${4 * l}%'),
  MemTrait('critd', 'sword', 2, '급소의 기억', const [2, 2, 3, 3, 4], (l) => '치명타 피해 +${10 * l}%'),
  MemTrait('stubborn', 'sword', 2, '끈질긴 농부', const [3, 4, 5], (l) => '보스 제한 시간 +${2 * l}초'),
  MemTrait('stretch', 'sword', 3, '아침 체조', const [4, 5, 6], (l) => '보스·도전 시작 때 스킬 게이지 ${10 * l}%'),
  MemTrait('climb', 'sword', 3, '탑 오르기', const [2, 3, 3, 4, 4], (l) => '탑·던전에서 주는 피해 +${10 * l}%'),
  MemTrait('soil', 'farm', 1, '비옥한 흙', const [1, 1, 2, 2, 3, 3], (l) => '작물 자라는 시간 −${5 * l}%'),
  MemTrait('hands', 'farm', 1, '부지런한 손', const [1, 1, 2, 2, 3, 3, 4, 4], (l) => '부두·양봉장·광산 생산 +${6 * l}%'),
  MemTrait('carpenter', 'farm', 2, '손 빠른 목수', const [1, 1, 2, 2, 3, 3], (l) => '건물 공사 시간 −${5 * l}%'),
  MemTrait('seedbag', 'farm', 2, '마르타의 씨앗 주머니', const [2, 3, 4], (l) => '은퇴 직후 씨앗 밀 ${10 * l} · 당근 ${5 * l} · 호박 ${2 * l}'),
  MemTrait('stew', 'farm', 3, '오래 끓인 국', const [2, 3, 3, 4, 4], (l) => '요리 버프 시간 +${10 * l}%'),
  MemTrait('bumper', 'farm', 3, '풍년의 기억', const [3, 4, 5, 6], (l) => '수확 2배 확률 +${5 * l}%'),
  MemTrait('purse', 'travel', 1, '비상금', const [1, 1, 2, 2, 3], (l) => '은퇴 직후 골드 = 시작 영지 성주 보상 ×${20 * l}'),
  MemTrait('shortcut', 'travel', 1, '지름길', const [2, 2, 2, 3, 3, 3, 4, 4, 5, 5], (l) => '은퇴 후 영지 ${1 + 5 * l}부터 시작'),
  MemTrait('inn', 'travel', 2, '넉넉한 여관', const [2, 3, 3, 4], (l) => '방치 보상 최대 시간 +$l시간'),
  MemTrait('knack', 'travel', 2, '단련의 요령', const [2, 2, 3, 3, 4], (l) => '단련 비용 −${4 * l}%'),
  MemTrait('memoir', 'travel', 3, '회고록', const [4, 6, 8], (l) => '은퇴할 때 받는 추억 +${10 * l}%'),
  MemTrait('goblin', 'travel', 3, '고블린 친구', const [3, 4, 5], (l) => '황금 고블린 등장 간격 −${10 * l}%'),
];

MemTrait? memT(String k) {
  for (final t in memTraits) {
    if (t.k == k) return t;
  }
  return null;
}

int trCostTo(MemTrait t, int l) => t.c.take(l).fold(0, (a, b) => a + b);

/// 전부 찍는 데 드는 포인트 (282)
final int memTotal = memTraits.fold(0, (a, t) => a + trCostTo(t, t.max));

/// 은퇴 횟수 보상: 은퇴하는 순간 1번 (배지·테두리는 profile_data 가 은퇴 횟수로 엶)
class RetReward {
  const RetReward(this.n, this.gem, [this.t]);
  final int n, gem;
  final String? t;
}

const retRewards = [
  RetReward(1, 50),
  RetReward(3, 50, '배지 「은퇴 전문가」'),
  RetReward(5, 100, '배지 「노련한 은퇴자」'),
  RetReward(10, 200, '테두리 「은퇴의 정원」'),
  RetReward(20, 300, '배지 「전설의 은퇴자」'),
];

/// 회차별 은퇴 장면 (기획서 5-2). 없는 회차는 기존 대사
const retOpen = '그러던 어느 날, 마계의 문이 다시 열렸다.';
const retRunLines = [
  'q@proud:일어나라, 주인. 은퇴는 끝났다.',
  'k@flustered:…왜 또 나야.',
  'm:티모|형! 은퇴했다더니 또 나왔네요! 역시 영웅은 쉬지 않아!',
];
const retDefault = ['평화로운 3년이었다. 카엘은 매일 밭을 갈았고, 호박은 해마다 커졌다.', retOpen, ...retRunLines];
const Map<int, List<String>> retScenes = {
  2: ['호박이 너무 커져서 수레에 실리지 않았다. 카엘은 그게 인생 최대의 고민이었다.', retOpen, ...retRunLines],
  3: ['카엘은 은퇴 기념으로 밭 옆에 작은 의자를 놓았다. 앉아 본 날은 사흘뿐이었다.', retOpen, ...retRunLines],
  5: ['마을 사람들이 「은퇴 축하」 현수막을 아예 접지 않고 창고에 넣어 두었다.', retOpen, ...retRunLines],
  10: [
    '루미나르는 이제 침대 옆에 기대어 카엘이 깨기를 기다린다.',
    'q:좋은 아침이다, 주인. 마계의 문이 열렸다.',
    'k@flustered:…인사보다 그 말이 먼저 나오는 거 너무하지 않아?',
    'm:티모|형! 은퇴했다더니 또 나왔네요! 역시 영웅은 쉬지 않아!',
  ],
  20: [
    '에르단에는 이제 이런 속담이 있다. 「카엘이 은퇴하면 곧 전쟁이 난다」.',
    'k:그 속담 만든 사람 찾으면 가만 안 둬.',
    retOpen,
    'q@proud:일어나라, 주인. 은퇴는 끝났다.',
    'm:티모|형! 은퇴했다더니 또 나왔네요! 역시 영웅은 쉬지 않아!',
  ],
};

/// 은퇴 일기 처음 열 때 (5-1)
const diaryIntroLines = [
  'sys:카엘의 서랍 깊은 곳에서 손때 묻은 일기장이 나왔다.',
  'k@smile:은퇴할 때마다 적어 둔 거야. 다음엔 더 빨리 은퇴하려고.',
  'q:…그 일기, 전부 싸운 이야기뿐이다만.',
  'k:그러니까 다음엔 더 잘 싸워서 더 빨리 끝내야지.',
  'sys:은퇴의 추억만큼 추억 포인트가 생겨요. 써도 추억 효과는 그대로예요',
];

extension RetireCalc on GameCalc {
  Map<String, dynamic> get traitS {
    final v = asMap(s.raw['trait']);
    if (v != null) return s.raw['trait'] = v;
    return s.raw['trait'] = <String, dynamic>{};
  }

  int trSpent([String? b]) => memTraits.where((t) => b == null || t.b == b).fold(0, (a, t) => a + trCostTo(t, tl(t.k)));
  int memPts() => math.max(0, s.memory.toInt() - trSpent());
  bool trOpen(MemTrait t) => trSpent(t.b) >= memRow[t.r];
  int? trNext(MemTrait t) => tl(t.k) < t.max ? t.c[tl(t.k)] : null;
  bool trCanAny() {
    final p = memPts();
    return p > 0 && memTraits.any((t) => trOpen(t) && trNext(t) != null && trNext(t)! <= p);
  }

  int trResetGem() => orNum(s.raw['trReset'], 0) != 0 ? 100 : 0;
  int get runStart => orNum(s.raw['runStart'], 1).toInt();

  /// 지름길: 은퇴 후 시작 영지. one = 「영지 1부터 시작」을 고름
  int retStart(bool one) => one ? 1 : math.max(1, math.min(1 + 5 * tl('shortcut'), (s.best / 2).floor()));

  /// 은퇴 전 추억(회고록 빼고): 지름길로 건너뛴 구간의 추억은 뺌 (RETIRE.md 10장)
  int retireBase() => math.max(0, ((s.stage - 10) / 5).floor() - (math.max(0, runStart - 10) / 5).floor());

  /// 이번 회차에 되찾은 영지
  int retRun() => s.stage - runStart;
  bool retCan() => s.stage >= 20 && retRun() >= 10;
  num retPurse(int st) {
    final l = tl('purse');
    return l != 0 ? jsFloor(GameCalc.reward(st, true) * 20 * l) : 0;
  }

  /// 은퇴 횟수 보상 확인: 넘긴 단계 중 안 받은 것을 지급. 받은 게 있으면 (이삭 합, 단계들)
  ({int g, List<RetReward> got})? retRwCheck() {
    final rw = asMap(s.raw['retRw']) ?? <String, dynamic>{};
    s.raw['retRw'] = rw;
    var g = 0;
    final got = <RetReward>[];
    for (final r in retRewards) {
      if (s.retires >= r.n && !truthy(rw['${r.n}'])) {
        rw['${r.n}'] = 1;
        g += r.gem;
        got.add(r);
      }
    }
    if (got.isEmpty) return null;
    s.gem = s.gem + g;
    return (g: g, got: got);
  }

  /// 특성 한 단계 찍기. 찍었으면 새 단계
  int? trBuy(String k) {
    final t = memT(k);
    if (t == null) return null;
    final nx = trNext(t);
    if (nx == null || !trOpen(t) || nx > memPts()) return null;
    traitS[k] = tl(k) + 1;
    return tl(k);
  }
}

String retRwText(({int g, List<RetReward> got}) x) {
  final ts = [for (final r in x.got) if (r.t != null) r.t!];
  return '은퇴 ${x.got.map((r) => r.n).join('·')}회 보상 · 황금 이삭 +${x.g}${ts.isNotEmpty ? ' · ${ts.join(' · ')}' : ''}';
}
