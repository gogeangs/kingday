/// 자동 전투 — 웹 index.html 「전투」「특수 스킬」 구역의 step()/spawn()/castSkill() 등을 그대로 옮긴 것.
///
/// 화면과 분리된 순수 계산이다. Flame 화면([BattleGame])은 매 프레임 [step] 을 부르고
/// 여기 있는 상태(원정대·마물·효과·글자)를 그리기만 한다.
///
/// **난수를 쓰는 순서까지 웹과 같다.** 그래서 같은 씨앗(seed)을 넣으면 웹과 똑같이 싸운다.
/// test/battle_parity_test.dart 가 웹 코드를 Node 로 돌린 결과와 프레임 단위로 비교한다.
library;

import 'dart:math' as math;

import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/profile_data.dart';
import '../core/rng.dart';
import '../core/state.dart';
import 'battle_data.dart';

/// 원정대 한 명의 전투 상태 (웹 P[id])
class Member {
  Member({required this.hp, required this.cd});
  num hp, cd;
  num swing = 0, hit = 0, sg = 0;
  bool down = false;

  /// 덕배 「보양 수라상」: 쓰러질 피해를 한 번 버팀 (웹 P[id].guts)
  bool guts = false;

  /// 버치 「벌통 방패」: 남은 시간·세기 (웹 P[id].bsh·bshK)
  num bsh = 0, bshK = 1;
}

/// 마물 한 마리 (웹 mons[] 원소)
class Mon {
  Mon({
    required this.x, required this.lane, required this.hp, required this.max, required this.atk,
    this.boss = false, this.lord = false, required this.cd, this.alt = false, this.gob = false,
    this.mv, this.cdm, this.life, this.dem = false, this.ghost, this.guard = false,
  });
  num x, lane, hp, max, atk, cd;
  bool boss, lord, alt, gob;
  /// 왕도: dem = 마왕 발타사르, ghost = 군단장 잔영(지역 번호 0~4), guard = 마왕 근위대장
  bool dem, guard;
  int? ghost;
  /// 마왕 2단계, 다음 봉인의 파동까지 남은 시간
  bool ph2 = false;
  num sealT = 0;
  num? mv, cdm, life;
  num hit = 0, dead = 0, sw = 0, slow = 0, bind = 0, psn = 0, psnD = 0, psnT = 0;
  /// 베릴 「약점 감정」 취약(받는 피해 ×vulM), 토비 밀쳐냄(그림만), 카라 화상(0.5초마다 brnD)
  num vul = 0, vulM = 1.3, kb = 0, brn = 0, brnD = 0, brnT = 0;
  /// 묶임 종류: 'net' 넬라 그물 · 'stun' 기절 (그림만 다름)
  String? bindK;
  bool flee = false, gone = false;
  num? tx, barY;
  num y = 0;
}

class FloatText {
  FloatText(this.x, this.y, this.txt, this.col, this.size);
  num x, y, t = 0;
  final String txt;
  final int col;
  final num size;
}

class Proj {
  Proj({required this.x, required this.y, required this.tx, required this.ty, required this.d, required this.kind, this.big});
  final num x, y, tx, ty, d;
  final String kind;
  final num? big;
  num t = 0;
}

class Fx {
  Fx(this.k, this.x, this.y, this.size, this.d, this.vy);
  final String k;
  final num x, y, size, d, vy;
  num t = 0;
}

/// 한마디 말풍선
/// 마왕 대사 띠: [(누가, 대사)…] 를 2.6초씩
class BossTalk {
  BossTalk(this.lines);
  final List<(String, String)> lines;
  int i = 0;
  num t = 2.6;
}

/// 봉인의 파동 예고 (남은 초)
class SealWarn {
  num t = 2;
}

class Quip {
  Quip(this.who, this.txt);
  final String who, txt;
  num t = 3.2;
}

/// 화면 가운데 띠 (영지 탈환! / 황금 고블린 출현!)
class StageBanner {
  StageBanner(this.txt, this.sub);
  final String txt, sub;
  num t = 2;
}

/// 보스 출현 경고
class Warn {
  Warn(this.cmd, [this.txt]);
  final bool cmd;
  /// 왕도 보스용 문구 (없으면 군단장/성주)
  final String? txt;
  num t = 1.4;
}

/// 스킬 컷인
class CutIn {
  CutIn(this.id);
  final String id;
  num t = 1.6;
}

/// 스킬 지속 효과 (웹 SKX)
class SkillTimers {
  num shield = 0, honey = 0, feast = 0, honeyTick = 0, bake = 0, mount = 0, mountK = 1, wall = 0;

  /// 덕배 불굴 남은 시간, 안단테 꿀벌 교향곡 (남은 시간·강화·다음 박자)
  num guts = 0, sym = 0, symK = 1, symTick = 0;
}

/// 전투가 화면·저장에 알려야 할 일. 화면이 매 프레임 꺼내서 처리한다.
sealed class BattleEvent {}

class ToastEvent extends BattleEvent {
  ToastEvent(this.msg);
  final String msg;
}

/// 효과음 (앱에만 있음: boss · skill · gob)
class SoundEvent extends BattleEvent {
  SoundEvent(this.k);
  final String k;
}

class HapticEvent extends BattleEvent {
  HapticEvent(this.pattern);
  final List<int> pattern;
}

/// 영지 탈환 (보스 처치). [chapter]: 새 지역에 들어섬
class StageClearedEvent extends BattleEvent {
  StageClearedEvent(this.clearedStage, this.lord, this.chapter);
  final int clearedStage;
  final bool lord, chapter;
}

/// 이야기 사건(동료 합류 등) — 장면 보여 주기는 6단계
class StoryEvent extends BattleEvent {
  StoryEvent(this.id);
  final String id;
}

class RankUpEvent extends BattleEvent {
  RankUpEvent(this.rankIdx, this.gem);
  final int rankIdx;
  final num gem;
}

class GemEvent extends BattleEvent {
  GemEvent(this.n, this.why);
  final num n;
  final String why;
}

/// 황금 고블린 처치 전리품 (성유물은 장착·판매를 고르게 해야 함 → 4단계 장비 창)
class GoblinLootEvent extends BattleEvent {
  GoblinLootEvent(this.gold, this.gem, this.relic, this.cardId, this.rare, {this.sold = false});
  final num gold, gem;
  /// 자동 판매로 바로 팔렸으면 true (창 없이 알림 한 줄)
  final bool sold;
  final Relic relic;
  final String? cardId;

  /// 아주 드문 전리품: ['badge'|'frame', 이름]
  final List<(String, String)> rare;
}

class SkillTutorialEvent extends BattleEvent {}

/// 왕도 이야기 (웹 capChapter·capStory): 'road' 처음 왕도 입장 · 'roadAgain' 다시 입장 · 'cap56' · 'cap57'
class CapStoryEvent extends BattleEvent {
  CapStoryEvent(this.kind);
  final String kind;
}

/// 마왕 발타사르 처치 (웹 bossDemonWin): [first] 첫 처치, [bonus] 재탈환 추억
class DemonWinEvent extends BattleEvent {
  DemonWinEvent(this.first, this.bonus);
  final bool first;
  final int bonus;
}

class FightResetEvent extends BattleEvent {
  FightResetEvent(this.msg);
  final String msg;
}

/// 화면 배치 (웹 layout())
class BattleLayout {
  BattleLayout(this.ids, this.pos, this.py, this.dsc, this.front, this.s, this.top, this.bot);
  final List<String> ids;
  final Map<String, num> pos, py, dsc;
  final num front, s, top, bot;
}

class BattleSim {
  BattleSim(this.c, {KdRandom? rng, num? gobT, Set<String>? fxLoaded})
      : rng = rng ?? SystemRandom(),
        fxLoaded = fxLoaded ?? fxFrames.keys.toSet() {
    this.gobT = gobT ?? 150 + this.rng.next() * 120;
    c.bakeProbe = () => skx.bake > 0;
  }

  final GameCalc c;
  final KdRandom rng;

  /// 그림을 불러온 효과 (웹 fxOk). 앱은 모두 있음.
  final Set<String> fxLoaded;

  /// 전투 화면 크기 (웹 W, Ht)
  num w = 390, ht = 330;

  // ── 웹 전역 변수들 ──
  late num gobT;
  Warn? warn;
  num shakeT = 0, shakeX = 0, shakeY = 0;
  StageBanner? banner;
  final Map<String, Member> party = {};
  List<Mon> mons = [];
  num spawnT = .5, bgX = 0, time = 0, bossT = 0, quipT = 6, flash = 0;
  List<FloatText> floats = [];
  List<Proj> proj = [];
  List<Fx> fxs = [];
  bool engaged = false;
  Quip? quip;
  CutIn? cut;
  final SkillTimers skx = SkillTimers();
  final List<BattleEvent> events = [];
  /// 마왕 2단계 전환 멈춤 · 대사 띠 · 봉인의 파동 예고
  num holdT = 0;
  BossTalk? talk;
  SealWarn? seal;
  static const balTalkStart = [('발타사르', '왔구나, 루미나르. 이번 주인은… 괭이를 든 농부인가.'), ('q', '괭이 아니다! …아, 아니, 주인 말고 내가 괭이가 아니라는 뜻이다.')];
  static const balTalkReveal = [('발타사르', '300년 전, 너를 처음 뽑은 손이 이 손이었다.'), ('q', '……발타사르. 나의 첫 번째 주인.')];
  static const sealEvery = 8, sealWarn = 2;

  GameState get s => c.s;

  bool fxOk(String k) => fxLoaded.contains(k);

  // ───────────── 배치 ─────────────
  BattleLayout layout() {
    final ids = c.members();
    final sc = math.min(w / 300, ht / 380), top = ht * .43, bot = math.max(top + 60, ht - 118);
    final pos = <String, num>{}, py = <String, num>{}, dsc = <String, num>{};
    final solo = ids.length == 1;
    for (final id in ids) {
      final f = solo ? const [.42, .55] : formation[id]!;
      pos[id] = w * f[0];
      py[id] = top + (bot - top) * f[1];
      dsc[id] = .9 + .14 * f[1];
    }
    final front = ids.map((id) => pos[id]!).reduce(math.max);
    return BattleLayout(ids, pos, py, dsc, front, sc, top, bot);
  }

  num depthAt(BattleLayout l, num lane) => l.top + (l.bot - l.top) * lane;

  void say(String who, String txt) => quip = Quip(who, txt);
  void toast(String m) => events.add(ToastEvent(m));
  void addFloat(num x, num y, String txt, int col, [num? size]) => floats.add(FloatText(x, y, txt, col, size ?? 15));
  void spawnFx(String k, num x, num y, num size, num d, [num? vy]) {
    if (fxOk(k)) fxs.add(Fx(k, x, y, size, d, vy ?? 0));
  }

  void syncParty() {
    for (final id in c.members()) {
      if (!party.containsKey(id)) party[id] = Member(hp: c.stats(id).hp, cd: rng.next() * .5);
    }
  }

  // ───────────── 특수 스킬 ─────────────
  bool skFull(String id) {
    final p = party[id];
    return p != null && !p.down && p.sg >= skills[id]!.need;
  }

  void chargeSkill(String id) {
    final p = party[id];
    if (p == null) return;
    p.sg = math.min(skills[id]!.need, p.sg + 1);
    if (p.sg >= skills[id]!.need && !truthy(s.done['tutSkill'])) {
      s.done['tutSkill'] = true;
      events.add(SkillTutorialEvent());
    }
  }

  /// castSkill(id): 초상화를 누르거나 AUTO 일 때
  bool castSkill(String id) {
    final p = party[id];
    if (!skFull(id) || !engaged) return false;
    final l = layout(), pos = l.pos, py = l.py, sc = l.s, t = c.stats(id);
    final alive = mons.where((m) => m.hp > 0 && m.dead == 0).toList();
    if (alive.isEmpty) return false;
    p!.sg = 0;
    p.swing = .4;
    cut = CutIn(id);
    events.add(SoundEvent('skill'));
    quip = null;
    num cx = 0, cy = 0;
    for (final m in alive) {
      cx = cx + m.x;
    }
    for (final m in alive) {
      cy = cy + m.y;
    }
    cx = cx / alive.length;
    cy = cy / alive.length;
    final feast = skx.feast > 0 ? 1.2 : 1;
    switch (id) {
      case 'kael':
        spawnFx('skill_kael', cx - 10 * sc, cy - 46 * sc, 170 * sc, .6);
        for (final m in alive) {
          hitMon(m, t.atk * 3 * feast, true, sc);
          if (!fxOk('skill_kael')) spawnFx('crit', m.x, m.y - 40 * sc, (m.boss ? 130 : 90) * sc, .5);
        }
        flash = .25;
      case 'bron':
        skx.shield = 5;
      case 'haral':
        for (final m in alive) {
          hitMon(m, t.atk * 3 * (m.boss ? 2 : 1) * feast, true, sc);
        }
        final tg = alive.last;
        if (fxOk('skill_haral')) {
          spawnFx('skill_haral', (pos['haral']! + tg.x) / 2 + 30 * sc, (py['haral']! + tg.y) / 2 - 40 * sc, 120 * sc, .55);
        } else {
          proj.add(Proj(x: pos['haral']! + 12 * sc, y: py['haral']! - 40 * sc, tx: tg.x + 40 * sc, ty: tg.y - 30 * sc, d: .35, kind: 'harpoon', big: 2.4));
        }
      case 'riel':
        skx.honey = 6;
        skx.honeyTick = 0;
        spawnFx('skill_riel', cx, cy - 40 * sc, 150 * sc, .9);
      case 'margo':
        _healAll(.3, 70 * sc, sc, pos, py);
        skx.feast = 8;
        _teamFx('skill_margo', sc, pos, py);
      case 'gordon':
        final k = c.skPow(id), tg = alive.first;
        hitMon(tg, t.atk * 2.5 * k * feast, true, sc);
        tg.bind = math.max(tg.bind, tg.boss ? 1 : 2);
        addFloat(tg.x, tg.y - 80 * sc, '기절!', 0xFFFFE27A, 13);
        skx.wall = 6;
        shakeT = .25;
        if (fxOk('skill_gordon')) {
          spawnFx('skill_gordon', pos[id]! + 30 * sc, py[id]! - 40 * sc, 150 * sc, .8);
        } else if (fxOk('skill_bron')) {
          spawnFx('skill_bron', pos[id]! + 30 * sc, py[id]! - 40 * sc, 120 * sc, .8);
        }
      case 'daisy':
        final k = c.skPow(id);
        for (final m in alive) {
          m.psn = 8;
          m.psnD = t.atk * .4 * k;
          m.psnT = 0;
        }
        if (fxOk('skill_daisy')) {
          spawnFx('skill_daisy', cx, cy - 40 * sc, 170 * sc, .9);
        } else {
          for (final m in alive) {
            spawnFx('bees', m.x, m.y - 30 * sc, 50 * sc, .6);
          }
        }
      case 'brida':
        final k = c.skPow(id);
        skx.mount = 6 * math.min(k, 1.3);
        skx.mountK = k;
        shakeT = .35;
        for (final j in c.members()) {
          spawnFx('heal', pos[j]!, py[j]! - 24 * sc, 60 * sc, .5);
        }
        if (fxOk('skill_brida')) {
          spawnFx('skill_brida', pos[id]! + 20 * sc, py[id]! - 40 * sc, 170 * sc, .9);
        } else if (fxOk('skill_bron')) {
          spawnFx('skill_bron', pos[id]! + 30 * sc, py[id]! - 40 * sc, 140 * sc, .9);
        }
      case 'malbong':
        // 맨손 잡기: 보스 먼저, 없으면 체력이 가장 많은 적
        final k = c.skPow(id);
        Mon? tg;
        for (final m in alive) {
          if (m.boss && m.hp > 0) {
            tg = m;
            break;
          }
        }
        if (tg == null) {
          for (final m in alive) {
            if (m.hp > 0 && (tg == null || m.hp > tg.hp)) tg = m;
          }
        }
        if (tg != null) {
          hitMon(tg, t.atk * 6 * k * feast, true, sc);
          tg.bind = math.max(tg.bind, tg.boss ? 1 : 1.5);
          addFloat(tg.x, tg.y - 80 * sc, '꽉!', 0xFFFFE27A, 14);
          shakeT = .25;
          if (fxOk('skill_malbong')) spawnFx('skill_malbong', tg.x, tg.y - 40 * sc, 150 * sc, .8);
        }
      case 'deokbae':
        // 보양 수라상: 원정대 모두 불굴
        final k = c.skPow(id);
        skx.guts = 6 * k;
        for (final j in c.members()) {
          final q = party[j];
          if (q == null) continue;
          if (!q.down) q.guts = true;
          spawnFx('heal', pos[j]!, py[j]! - 24 * sc, 60 * sc, .5);
        }
        if (fxOk('skill_deokbae')) _teamFx('skill_deokbae', sc, pos, py);
      case 'peppy':
        // 발파: 모든 적 큰 폭발
        final k = c.skPow(id);
        for (final m in alive) {
          hitMon(m, t.atk * 5 * k * feast, true, sc);
        }
        shakeT = .5;
        if (fxOk('skill_peppy')) spawnFx('skill_peppy', cx, cy - 30 * sc, 190 * sc, .8);
      case 'toby':
        // 파도 가르기: 앞쪽 적 3마리 피해 + 밀쳐내 공격을 늦춤
        final k = c.skPow(id);
        final idx = [for (var i = 0; i < alive.length; i++) i]..sort((a, b) {
            final d = alive[a].x.compareTo(alive[b].x);
            return d != 0 ? d : a.compareTo(b);
          });
        final fr = [for (final i in idx.take(3)) alive[i]];
        for (final m in fr) {
          hitMon(m, t.atk * 3 * k * feast, true, sc);
          m.cd = m.cd + (m.boss ? .6 : 1.2);
          m.kb = .5;
          addFloat(m.x, m.y - 80 * sc, '밀쳐냄!', 0xFF9BE3FF, 13);
        }
        shakeT = .2;
        if (fxOk('skill_toby')) spawnFx('skill_toby', (fr.isNotEmpty ? fr[0].x : cx) - 10 * sc, cy - 30 * sc, 170 * sc, .8);
      case 'kara':
        // 불맛 한 숟갈: 모든 적 피해 + 화상 5초
        final k = c.skPow(id);
        for (final m in alive) {
          hitMon(m, t.atk * 1.5 * k * feast, true, sc);
          m.brn = 5;
          m.brnD = t.atk * .35 * k;
          m.brnT = .5;
        }
        if (fxOk('skill_kara')) spawnFx('skill_kara', cx, cy - 30 * sc, 180 * sc, .9);
      case 'beryl':
        // 약점 감정: 모든 적 6초 취약(받는 피해 +30%, ★3 +39%)
        final k = c.skPow(id);
        for (final m in alive) {
          m.vul = 6;
          m.vulM = 1 + .3 * k;
          hitMon(m, t.atk * k * feast, false, sc);
          addFloat(m.x, m.y - 80 * sc, '약점!', 0xFFD6A8FF, 13);
        }
        if (fxOk('skill_beryl')) spawnFx('skill_beryl', cx, cy - 40 * sc, 160 * sc, .8);
      case 'mora':
        // 싱싱한 한 방: 맨 앞 적 하나에 4배 피해
        final k = c.skPow(id);
        final tg = alive.reduce((a, m) => m.x < a.x ? m : a);
        hitMon(tg, t.atk * 4 * k * feast, true, sc);
        addFloat(tg.x, tg.y - 80 * sc, '싱싱!', 0xFFFFE27A, 13);
        shakeT = .2;
        if (fxOk('skill_mora')) spawnFx('skill_mora', tg.x, tg.y - 40 * sc, 150 * sc, .7);
      case 'melo':
        // 끈적 꿀단지: 맨 앞 적 하나에 2.5배 피해 + 4초 느려짐
        final k = c.skPow(id);
        final tg = alive.reduce((a, m) => m.x < a.x ? m : a);
        hitMon(tg, t.atk * 2.5 * k * feast, true, sc);
        tg.slow = math.max(tg.slow, 4);
        addFloat(tg.x, tg.y - 80 * sc, '끈적!', 0xFFFFD36B, 13);
        if (fxOk('skill_melo')) spawnFx('skill_melo', tg.x, tg.y - 40 * sc, 150 * sc, .8);
      case 'pori':
        // 따끈한 수프 배달: 체력 비율이 가장 낮은 동료 하나 35% 회복 (쓰러졌으면 일으킴)
        final k = c.skPow(id);
        String? tj;
        num tr = 2;
        for (final j in c.members()) {
          final q = party[j];
          if (q == null) continue;
          final r = q.down ? 0 : q.hp / c.stats(j).hp;
          if (r < tr) {
            tr = r;
            tj = j;
          }
        }
        if (tj != null) {
          final q = party[tj]!;
          if (q.down) {
            q.down = false;
            q.hp = 0;
          }
          q.hp = math.min(c.stats(tj).hp, q.hp + c.stats(tj).hp * .35 * k);
          spawnFx('heal', pos[tj]!, py[tj]! - 24 * sc, 70 * sc, .6);
          addFloat(pos[tj]!, py[tj]! - 70 * sc, '따끈!', 0xFF9CF08A, 13);
          if (fxOk('skill_pori')) spawnFx('skill_pori', pos[tj]!, py[tj]! - 50 * sc, 150 * sc, .8);
        }
      case 'rollo':
        // 광차 굴리기: 모든 적을 꿰뚫어 2.5배 피해 (앞쪽부터)
        final k = c.skPow(id);
        final idx = [for (var i = 0; i < alive.length; i++) i]..sort((a, b) {
            final d = alive[a].x.compareTo(alive[b].x);
            return d != 0 ? d : a.compareTo(b);
          });
        for (final i in idx) {
          hitMon(alive[i], t.atk * 2.5 * k * feast, true, sc);
        }
        shakeT = .3;
        if (fxOk('skill_rollo')) spawnFx('skill_rollo', cx, cy - 30 * sc, 180 * sc, .8);
      case 'crab':
        // 집게 물기: 가장 강한 적(보스 먼저) 2배 피해 + 6초 느려짐
        final k = c.skPow(id);
        Mon? tg;
        for (final m in alive) {
          if (m.boss) {
            tg = m;
            break;
          }
        }
        if (tg == null) {
          for (final m in alive) {
            if (tg == null || m.hp > tg.hp) tg = m;
          }
        }
        final g = tg!;
        hitMon(g, t.atk * 2 * k * feast, true, sc);
        g.slow = math.max(g.slow, 6);
        addFloat(g.x, g.y - 80 * sc, '꽉!', 0xFFFF9A7A, 13);
        if (fxOk('skill_crab')) spawnFx('skill_crab', g.x, g.y - 40 * sc, 150 * sc, .8);
      case 'birch':
        // 벌통 방패: 체력 비율이 가장 낮은 동료 6초 동안 받는 피해 40% 감소
        final k = c.skPow(id);
        String? tj;
        num tr = 2;
        for (final j in c.members()) {
          final q = party[j];
          if (q == null || q.down) continue;
          final r = q.hp / c.stats(j).hp;
          if (r < tr) {
            tr = r;
            tj = j;
          }
        }
        if (tj != null) {
          party[tj]!.bsh = 6;
          party[tj]!.bshK = k;
          addFloat(pos[tj]!, py[tj]! - 70 * sc, '벌통 방패!', 0xFFFFD36B, 13);
          if (fxOk('skill_birch')) spawnFx('skill_birch', pos[tj]! + 16 * sc, py[tj]! - 40 * sc, 130 * sc, .8);
        }
      case 'gram':
        // 군감자 한 알: 쓰러지지 않은 동료 모두 15% 회복
        final k = c.skPow(id);
        for (final j in c.members()) {
          final q = party[j];
          if (q == null || q.down) continue;
          q.hp = math.min(c.stats(j).hp, q.hp + c.stats(j).hp * .15 * k);
          spawnFx('heal', pos[j]!, py[j]! - 24 * sc, 56 * sc, .6);
        }
        if (fxOk('skill_gram')) {
          final ids = c.members();
          num mx = 0, my = 0;
          for (final j in ids) {
            mx = mx + pos[j]!;
            my = my + py[j]!;
          }
          spawnFx('skill_gram', mx / ids.length, my / ids.length - 50 * sc, 150 * sc, .9);
        }
      case 'andante':
        skx.sym = 6;
        skx.symK = c.skPow(id);
        skx.symTick = 0;
        if (fxOk('skill_andante')) spawnFx('skill_andante', cx, cy - 40 * sc, 170 * sc, .9);
      case 'makrye':
        // 숨비소리: 말순이 촉수로 모든 적 피해 + 기절 (보스 1초)
        final k = c.skPow(id);
        for (final m in alive) {
          hitMon(m, t.atk * 3 * k * feast, true, sc);
          m.bind = math.max(m.bind, m.boss ? 1 : 2);
          m.bindK = 'stun';
          addFloat(m.x, m.y - 80 * sc, '기절!', 0xFFFFE27A, 13);
        }
        shakeT = .35;
        if (fxOk('skill_makrye')) {
          spawnFx('skill_makrye', cx, cy - 30 * sc, 190 * sc, .9);
        } else if (fxOk('skill_nella')) {
          spawnFx('skill_nella', cx, cy - 40 * sc, 170 * sc, .8);
        }
      case 'nella':
        final k = c.skPow(id);
        for (final m in alive) {
          hitMon(m, t.atk * 2 * k * feast, true, sc);
          m.bind = (m.boss ? 2 : 4) * k;
          m.bindK = 'net';
          addFloat(m.x, m.y - 80 * sc, '꽁꽁!', 0xFF9BE3FF, 13);
        }
        if (fxOk('skill_nella')) spawnFx('skill_nella', cx, cy - 40 * sc, 170 * sc, .8);
      case 'luka':
        final k = c.skPow(id);
        _healAll(.2 * k, 64 * sc, sc, pos, py);
        skx.bake = 8 * k;
        _teamFx('skill_luka', sc, pos, py);
    }
    return true;
  }

  void _healAll(num ratio, num fxSize, num sc, Map<String, num> pos, Map<String, num> py) {
    for (final j in c.members()) {
      final q = party[j];
      if (q == null) continue;
      if (q.down) {
        q.down = false;
        q.hp = 0;
      }
      final mx = c.stats(j).hp;
      q.hp = math.min(mx, q.hp + c.stats(j).hp * ratio);
      spawnFx('heal', pos[j]!, py[j]! - 24 * sc, fxSize, .6);
    }
  }

  void _teamFx(String k, num sc, Map<String, num> pos, Map<String, num> py) {
    final ids = c.members();
    num mx = 0, my = 0;
    for (final j in ids) {
      mx = mx + pos[j]!;
    }
    for (final j in ids) {
      my = my + py[j]!;
    }
    spawnFx(k, mx / ids.length, my / ids.length - 60 * sc, 190 * sc, .9);
  }

  void _stepSkills(num dt, BattleLayout l, List<Mon> alive) {
    skx.shield = math.max(0, skx.shield - dt);
    skx.feast = math.max(0, skx.feast - dt);
    skx.bake = math.max(0, skx.bake - dt);
    skx.mount = math.max(0, skx.mount - dt);
    skx.wall = math.max(0, skx.wall - dt);
    skx.guts = math.max(0, skx.guts - dt);
    if (skx.sym > 0) {
      // 안단테 「꿀벌 교향곡」: 0.5초마다 벌떼가 모든 적을 쏨
      skx.sym -= dt;
      skx.symTick -= dt;
      if (skx.symTick <= 0 && party.containsKey('andante')) {
        skx.symTick = .5;
        final a = c.stats('andante').atk * .6 * skx.symK;
        for (final m in alive) {
          if (m.hp > 0) hitMon(m, a, false, l.s);
        }
      }
    }
    if (skx.honey > 0) {
      skx.honey -= dt;
      skx.honeyTick -= dt;
      if (skx.honeyTick <= 0 && party.containsKey('riel')) {
        skx.honeyTick = .5;
        final a = c.stats('riel').atk * .5;
        for (final m in alive) {
          if (m.hp > 0) {
            hitMon(m, a, false, l.s);
            if (rng.next() < .5) spawnFx('bees', m.x, m.y - 36 * l.s, 46 * l.s, .45);
          }
        }
      }
    }
    if (engaged && s.raw['autoSkill'] != false) {
      for (final id in l.ids) {
        if (skFull(id)) {
          castSkill(id);
          break;
        }
      }
    }
  }

  // ───────────── 마물 ─────────────
  void hitMon(Mon m, num d, bool cr, num sc) {
    if (m.vul > 0) d *= m.vulM;
    m.hp -= d;
    m.hit = .12;
    final fx = m.x + (rng.next() - .5) * 10 * sc;
    spawnFx(cr ? 'crit' : 'hit', fx, m.y - (m.boss ? 50 : 28) * sc, (cr ? 60 : 42) * sc * (m.boss ? 1.3 : 1), cr ? .36 : .24);
    final ax = m.x + (rng.next() - .5) * 12 * sc;
    addFloat(ax, m.barY != null ? m.barY! - 8 * sc : m.y - (m.boss ? 95 : 60) * sc, fmt(d), cr ? 0xFFFFC94A : 0xFFFFFFFF, cr ? 21 : 14);
  }

  void spawn() {
    if (s.stage > maxLand && s.wave >= 10) s.wave = 0; // 61 왕궁 뜰: 보스 없이 계속
    final st = c.fightSt();
    if (s.wave >= 10) {
      final mx = GameCalc.monHp(st, true), dem = GameCalc.isDemon(st), gh = GameCalc.isGhost(st), gd = GameCalc.isGuard(st);
      final lord = GameCalc.isLord(st) && !dem, cm = lord || dem || gh;
      mons = [
        Mon(x: w + 70, lane: .55, hp: mx, max: mx, atk: GameCalc.monAtk(st, true), boss: true, lord: lord || dem, cd: .8,
            dem: dem, ghost: gh ? GameCalc.ghostIdx(st) : null, guard: gd)
      ];
      bossT = GameCalc.bossLim(st);
      warn = Warn(cm, dem ? '⚠ 마왕 출현! ⚠' : gh ? '⚠ 군단장의 잔영! ⚠' : gd ? '⚠ 근위대장 출현! ⚠' : null);
      events.add(SoundEvent('boss'));
      shakeT = cm ? .6 : .4;
      mons[0].mv = .55;
      if (dem) {
        talk = BossTalk(balTalkStart);
      } else {
        say('q', gh ? '쓰러뜨린 군단장의 잔영이다! 다시 한번 베어라, 주인!' : gd ? '마왕 근위대장이다! 왕도를 되찾자, 주인!' : lord ? '군단장이다! 이번엔 도망치지 마라, 주인!' : '성주다! 정신 차려라, 주인!');
      }
      return;
    }
    final left = 10 - s.wave;
    var n = 1;
    if (left > 1 && rng.next() < .55) n++;
    if (left > 2 && st >= 3 && rng.next() < .35) n++;
    final ri = GameCalc.regionIndex(st);
    final altSheet = monAlt[ri];
    final alt = altSheet != null && rng.next() < .4 ? altSheet : null;
    final tr = alt != null ? traits[alt.trait]! : null;
    if (tr != null && alt!.trait == 'swarm' && left > n) n++;
    final mx = GameCalc.monHp(st, false) * (n > 1 ? .75 : 1) * (tr?.hp ?? 1);
    const lanes = [.45, .82, .12, .65];
    mons = [
      for (var i = 0; i < n; i++)
        Mon(
          x: w + 60 + i * 40, lane: lanes[i], hp: mx, max: mx,
          atk: GameCalc.monAtk(st, false) * (n > 1 ? .8 : 1) * (tr?.atk ?? 1),
          cd: .8 + i * .35, alt: alt != null, mv: tr?.mv ?? 1, cdm: tr?.cd ?? 1,
        )
    ];
    if (st >= 3 && gobT <= 0) {
      gobT = 360 + rng.next() * 360;
      final gh = GameCalc.monHp(st, false) * 5;
      mons.insert(0, Mon(x: w + 30, lane: .3, hp: gh, max: gh, atk: 0, cd: 1e9, gob: true, mv: 1.4, life: 12));
      banner = StageBanner('황금 고블린 출현!', '12초 안에 잡으면 보물을 떨군다');
      events.add(SoundEvent('gob'));
      shakeT = .3;
    }
  }

  /// gobWeek(): 이번 주 황금 고블린 처치 수 (랭킹용)
  static const int week0 = 1792335600000; // Date.parse('2026-10-18T15:00:00Z')
  int curWeek() => ((c.now - week0) / 6048e5).floor() + 1;
  Map<String, dynamic> gobWeek() {
    final cw = curWeek();
    final g = asMap(s.raw['gobW']);
    if (g == null || g['w'] != cw) s.raw['gobW'] = <String, dynamic>{'w': cw, 'n': 0};
    return s.raw['gobW'] as Map<String, dynamic>;
  }

  /// 실제 저장하지 않는 미리보기 전투면 true (고블린 주간 기록을 올리지 않음)
  bool noSave = false;

  void _gobDrop(Mon m, num sc) {
    final g = jsFloor(GameCalc.reward(c.fightSt(), false) * 30 * (c.buff('gold') ? 1.5 : 1) * c.memMul());
    final gem = 5 + (rng.next() * 6).floor();
    s.gold = s.gold + g;
    c.stat('gob', 1);
    events.add(HapticEvent(const [30, 30, 30]));
    if (!noSave) {
      final gw = gobWeek();
      gw['n'] = asNum(gw['n']) + 1;
    }
    spawnFx('coin', m.x, m.y - 30 * sc, 70 * sc, .8, -70 * sc);
    addFloat(m.x, m.y - 40 * sc, '+${fmt(g)}', 0xFFFFC94A, 20);
    addFloat(m.x, m.y - 66 * sc, '황금 이삭 +$gem', 0xFFFFE27A, 14);
    final it = c.rollItem(rng, math.max(2, c.rollItem(rng).g));
    s.gem = s.gem + gem;
    final gc0 = c.gainCard(rng, 3, 'battle');
    final cg = gc0 == '' ? c.cardGoldLast : 0;
    final gc = (gc0 == null || gc0.isEmpty) ? null : gc0;
    final rare = <(String, String)>[];
    s.raw['bdUnl'] = asMap(s.raw['bdUnl']) ?? <String, dynamic>{};
    s.raw['pfUnl'] = asMap(s.raw['pfUnl']) ?? <String, dynamic>{};
    final bd = s.raw['bdUnl'] as Map<String, dynamic>, pf = s.raw['pfUnl'] as Map<String, dynamic>;
    if (!truthy(bd['goblin']) && rng.next() < gobRareBadge) {
      bd['goblin'] = 1;
      rare.add(('badge', '고블린 사냥꾼'));
    }
    if (!truthy(pf['goblin']) && rng.next() < gobRareFrame) {
      pf['goblin'] = 1;
      rare.add(('frame', '황금 고블린'));
    }
    // 자동 판매가 켜져 있고 착용 중인 것보다 좋지 않으면 바로 판매 (창 없이 알림 한 줄)
    final cur = c.equipped(it.slot);
    final sold = truthy(s.raw['autoSell']) && cur != null && GameCalc.score(it) <= GameCalc.score(cur);
    if (sold) s.gold = s.gold + it.price;
    events.add(GoblinLootEvent(g + cg, gem, it, gc, rare, sold: sold));
  }

  /// events(): 영지를 되찾을 때 이야기 사건·칭호 확인
  void runStoryEvents() {
    for (final e in storyEvents) {
      if (s.stage >= e.at && !truthy(s.done[e.id])) {
        s.done[e.id] = true;
        _eventAct(e.id);
        syncParty();
        events.add(StoryEvent(e.id));
      }
    }
    final ri = c.rankIdx();
    if (ri > asNum(s.raw['rankSeen'])) {
      s.raw['rankSeen'] = ri;
      final gg = ri > orNum(s.raw['gemRank'], 0);
      if (gg) {
        s.raw['gemRank'] = ri;
        s.gem = s.gem + rankGem;
      }
      events.add(RankUpEvent(ri, gg ? rankGem : 0));
    }
  }

  void _eventAct(String id) {
    switch (id) {
      case 'marta':
        s.bld['farm'] = math.max(1, s.bldLv('farm'));
        s.seeds['wheat'] = asNum(s.seeds['wheat']) + 5;
      case 'margo' || 'haral' || 'riel' || 'bron':
        s.joined[id] = true;
    }
  }

  void resetFight(String msg) {
    final dem = mons.any((m) => m.dem);
    skx.shield = skx.honey = skx.feast = skx.guts = skx.sym = 0;
    for (final id in c.members()) {
      party[id]!.hp = c.stats(id).hp;
      party[id]!.down = false;
    }
    mons = [];
    spawnT = 1;
    s.wave = 0;
    seal = null;
    talk = null;
    holdT = 0;
    // 마왕에게 지면 59(왕궁 회랑) 마지막 웨이브로
    if (dem) {
      s.stage = maxLand - 1;
      s.wave = 9;
    }
    events.add(FightResetEvent(msg));
    toast(msg);
  }

  // ───────────── 한 프레임 ─────────────
  /// step(dt): 웹 step() 과 같은 순서로 한 프레임 진행
  void step(num dt) {
    if (talk != null) {
      talk!.t -= dt;
      if (talk!.t <= 0) {
        talk!.i++;
        talk!.t = 2.6;
        if (talk!.i >= talk!.lines.length) talk = null;
      }
    }
    if (holdT > 0) {
      holdT -= dt; // 마왕 2단계 전환: 잠깐 멈춤
      return;
    }
    if (seal != null) seal!.t -= dt;
    time += dt;
    flash = math.max(0, flash - dt);
    if (cut != null) {
      cut!.t -= dt;
      if (cut!.t <= 0) cut = null;
    }
    if (warn != null) {
      warn!.t -= dt;
      if (warn!.t <= 0) warn = null;
    }
    if (shakeT > 0) {
      shakeT -= dt;
      final a = shakeT * 14;
      shakeX = (rng.next() - .5) * a;
      shakeY = (rng.next() - .5) * a;
    } else {
      shakeX = shakeY = 0;
    }
    final l = layout(), ids = l.ids, front = l.front, sc = l.s;
    syncParty();
    for (final m in mons) {
      m.y = depthAt(l, m.lane);
    }
    if (banner != null) {
      banner!.t -= dt;
      if (banner!.t <= 0) banner = null;
    }
    if (quip != null) {
      quip!.t -= dt;
      if (quip!.t <= 0) quip = null;
    } else {
      quipT -= dt;
      if (quipT <= 0) {
        quipT = 12 + rng.next() * 10;
        final q = quips[(rng.next() * quips.length).floor()];
        say(q[0], q[1]);
      }
    }
    for (final id in ids) {
      final p = party[id]!;
      p.swing = math.max(0, p.swing - dt);
      p.hit = math.max(0, p.hit - dt);
      if (p.bsh > 0) p.bsh -= dt;
    }
    gobT -= dt;
    for (final m in mons) {
      if (m.slow > 0) m.slow -= dt;
      if (m.bind > 0) m.bind -= dt;
      if (m.vul > 0) m.vul -= dt;
      if (m.kb > 0) m.kb -= dt;
      if (m.brn > 0 && m.hp > 0 && m.dead == 0) {
        m.brn -= dt;
        m.brnT -= dt;
        if (m.brnT <= 0) {
          m.brnT = .5;
          m.hp -= m.brnD;
          addFloat(m.x + (rng.next() - .5) * 14 * sc, m.y - 50 * sc, fmt(m.brnD), 0xFFFF9A4A, 12);
        }
      }
      if (m.psn > 0 && m.hp > 0 && m.dead == 0) {
        m.psn -= dt;
        m.psnT -= dt;
        if (m.psnT <= 0) {
          m.psnT = .5;
          m.hp -= m.psnD;
          addFloat(m.x + (rng.next() - .5) * 14 * sc, m.y - 50 * sc, fmt(m.psnD), 0xFFB7F07A, 12);
        }
      }
      if (m.flee) {
        m.x += dt * 300;
        if (m.x > w + 80) m.gone = true;
      }
      m.hit = math.max(0, m.hit - dt);
      m.sw = math.max(0, m.sw - dt);
      if (m.dead > 0) {
        m.dead -= dt;
        if (m.dead <= 0) m.gone = true;
      }
    }
    mons = mons.where((m) => !m.gone).toList();
    if (mons.isEmpty) {
      engaged = false;
      bgX += dt * 90;
      for (final id in ids) {
        final p = party[id]!, mx = c.stats(id).hp;
        if (p.down) {
          p.down = false;
          p.hp = mx * .3;
        }
        p.hp = math.min(mx, p.hp + mx * .04 * dt);
      }
      spawnT -= dt;
      if (spawnT <= 0) {
        spawn();
        spawnT = .6;
      }
    } else {
      final alive = mons.where((m) => m.hp > 0 && m.dead == 0 && !m.flee).toList();
      for (var i = 0; i < alive.length; i++) {
        final m = alive[i];
        m.tx = m.boss ? math.max(front + 60 * sc, w * .66) : math.max(front + 46 * sc, w * (.66 + .1 * (i % 2)) + i * 4);
        if (m.x > m.tx!) {
          m.x = math.max(m.tx!, m.x - dt * 170 * orNum(m.mv, 1));
        } else if (m.gob) {
          m.life = m.life! - dt;
          if (m.life! <= 0) {
            m.flee = true;
            toast('황금 고블린이 보물을 챙겨 도망쳤어요');
            say('q', '쳇, 놓쳤군… 다음엔 더 빨리 베어라.');
          }
        }
      }
      engaged = alive.isNotEmpty && alive[0].x <= alive[0].tx! + 1;
      if (!engaged && alive.isNotEmpty) bgX += dt * 90;
      for (final id in ids) {
        final p = party[id]!;
        if (!p.down) p.hp = math.min(c.stats(id).hp, p.hp + c.stats(id).hp * .01 * dt);
      }
      if (engaged) {
        _membersAttack(dt, l, alive);
        _stepSkills(dt, l, alive);
        _monstersAttack(dt, l, alive);
      }
      for (final m in mons) {
        if (m.hp <= 0 && m.dead == 0 && m.gob && !m.flee) {
          m.dead = .5;
          _gobDrop(m, sc);
          continue;
        }
        if (m.hp <= 0 && m.dead == 0 && !m.gob) {
          m.dead = .35;
          _kill(m, sc);
        }
      }
      if (ids.every((i) => party[i]!.down)) {
        return resetFight('성검의 가호로 모두 다시 일어섰어요. 더 강해져서 돌아가요');
      }
      if (mons.any((m) => m.boss && m.hp > 0 && m.dead == 0) && engaged) {
        _demStep(dt, l);
        bossT -= dt;
        if (bossT <= 0) return resetFight('마족이 버텼어요. 더 강해진 뒤 다시 도전해요');
      }
    }
    for (final f in floats) {
      f.t += dt;
      f.y -= dt * 40;
    }
    floats = floats.where((f) => f.t < .9).toList();
    for (final p in proj) {
      p.t += dt;
    }
    proj = proj.where((p) => p.t < p.d).toList();
    for (final f in fxs) {
      f.t += dt;
    }
    fxs = fxs.where((f) => f.t < f.d).toList();
  }

  void _membersAttack(num dt, BattleLayout l, List<Mon> alive) {
    final ids = l.ids, pos = l.pos, py = l.py, sc = l.s;
    for (final id in ids) {
      final p = party[id]!;
      if (p.down) continue;
      final t = c.stats(id);
      p.cd -= dt;
      if (p.cd > 0) continue;
      p.cd = 1 / t.aps;
      chargeSkill(id);
      Mon? tgt;
      for (final m in alive) {
        if (m.hp > 0) {
          tgt = m;
          break;
        }
      }
      final job = jobOf[id];
      if (job == 'cook') {
        String? low;
        num lr = .9;
        for (final j in ids) {
          final q = party[j]!;
          if (q.down) continue;
          final r = q.hp / c.stats(j).hp;
          if (r < lr) {
            lr = r;
            low = j;
          }
        }
        if (low != null) {
          final h = t.atk * 3.2;
          party[low]!.hp = math.min(c.stats(low).hp, party[low]!.hp + h);
          p.swing = .3;
          spawnFx('heal', pos[low]!, py[low]! - 24 * sc, 62 * sc, .55);
          addFloat(pos[low]!, py[low]! - (heightOf(low) + 8) * sc, '+${fmt(h)}', 0xFF7BE08F, 13);
          proj.add(Proj(x: pos[id]! + 10 * sc, y: py[id]! - 50 * sc, tx: pos[low]!, ty: py[low]! - 40 * sc, d: .3, kind: 'soup'));
          continue;
        }
      }
      if (tgt == null) continue;
      final cr = rng.next() < t.crit;
      final d = t.atk * (cr ? 2 : 1) * (.9 + rng.next() * .2) * (skx.feast > 0 ? 1.2 : 1);
      p.swing = .22;
      if (id == 'daisy') {
        for (final m in alive) {
          if (m.hp > 0) {
            hitMon(m, d * .55, cr, sc);
            if (!(m.psn > 3)) {
              m.psn = 3;
              m.psnD = t.atk * .15;
              m.psnT = 0;
            }
          }
        }
        proj.add(Proj(x: pos[id]! + 10 * sc, y: py[id]! - 46 * sc, tx: tgt.x, ty: tgt.y - 30 * sc, d: .35, kind: 'pollen'));
      } else if (id == 'riel') {
        for (final m in alive) {
          if (m.hp > 0) hitMon(m, d * .7, cr, sc);
        }
        proj.add(Proj(x: pos['riel']! + 10 * sc, y: py['riel']! - 46 * sc, tx: tgt.x, ty: tgt.y - 30 * sc, d: .35, kind: 'bees'));
      } else if (id == 'nella') {
        hitMon(tgt, d, cr, sc);
        tgt.slow = 2;
        proj.add(Proj(x: pos[id]! + 12 * sc, y: py[id]! - 40 * sc, tx: tgt.x, ty: tgt.y - 28 * sc, d: .3, kind: 'net'));
      } else if (id == 'andante') {
        for (final m in alive) {
          if (m.hp > 0) hitMon(m, d * .6, cr, sc);
        }
        proj.add(Proj(x: pos[id]! + 10 * sc, y: py[id]! - 46 * sc, tx: tgt.x, ty: tgt.y - 30 * sc, d: .35, kind: 'bees'));
      } else if (id == 'makrye') {
        hitMon(tgt, d, cr, sc);
        proj.add(Proj(x: pos[id]! + 12 * sc, y: py[id]! - 40 * sc, tx: tgt.x, ty: tgt.y - 28 * sc, d: .22, kind: 'harpoon'));
      } else if (id == 'haral') {
        hitMon(tgt, d, cr, sc);
        proj.add(Proj(x: pos['haral']! + 12 * sc, y: py['haral']! - 40 * sc, tx: tgt.x, ty: tgt.y - 28 * sc, d: .2, kind: 'harpoon'));
      } else if (job == 'cook') {
        hitMon(tgt, d, cr, sc);
        proj.add(Proj(x: pos[id]! + 10 * sc, y: py[id]! - 50 * sc, tx: tgt.x, ty: tgt.y - 30 * sc, d: .3, kind: 'soup'));
      } else {
        hitMon(tgt, d, cr, sc);
      }
    }
  }

  void _monstersAttack(num dt, BattleLayout l, List<Mon> alive) {
    final ids = l.ids, pos = l.pos, py = l.py, sc = l.s;
    for (final m in alive) {
      if (m.hp <= 0 || m.gob) continue;
      if (m.bind > 0) continue;
      m.cd -= dt * (skx.honey > 0 ? .5 : 1) * (m.slow > 0 ? .6 : 1);
      if (m.cd > 0) continue;
      m.cd = 1.2 * orNum(m.cdm, 1);
      m.sw = .4;
      String? tk;
      for (final i in ids) {
        if (jobOf[i] == 'miner') {
          tk = i;
          break;
        }
      }
      String? tid;
      if (tk != null && party[tk] != null && !party[tk]!.down) {
        tid = tk;
      } else {
        for (final i in ids) {
          if (!party[i]!.down) {
            tid = i;
            break;
          }
        }
      }
      if (tid == null) continue;
      final q = party[tid]!;
      final dm = m.atk * (skx.shield > 0 ? .5 : 1) * (skx.mount > 0 ? .3 : 1) * (q.bsh > 0 ? 1 - .4 * q.bshK : 1);
      if (skx.mount > 0 && party.containsKey('brida')) {
        final rf = m.atk * .7 * .5 * skx.mountK;
        hitMon(m, rf, false, sc);
      }
      if (tid == 'gordon' && (skx.wall > 0 || rng.next() < .25)) {
        hitMon(m, c.stats('gordon').atk * .6 * c.skPow('gordon'), false, sc);
        party['gordon']!.swing = .22;
      }
      q.hp -= dm;
      q.hit = .15;
      addFloat(pos[tid]!, py[tid]! - (heightOf(tid) + 8) * sc, '-${fmt(dm)}', 0xFFFF6B7D, 13);
      if (q.hp <= 0) {
        if (skx.guts > 0 && q.guts) {
          // 덕배 불굴: 체력 1로 한 번 버팀
          q.guts = false;
          q.hp = 1;
          addFloat(pos[tid]!, py[tid]! - (heightOf(tid) + 24) * sc, '불굴!', 0xFFFFD27A, 14);
        } else {
          q.hp = 0;
          q.down = true;
        }
      }
    }
  }

  void _kill(Mon m, num sc) {
    spawnFx('coin', m.x, m.y - 26 * sc, 34 * sc, .6, -60 * sc);
    final g = GameCalc.reward(s.stage, m.boss) * (c.buff('gold') ? 1.5 : 1) * c.memMul();
    s.gold = s.gold + g;
    final d = c.daily();
    d['kill'] = orNum(d['kill'], 0) + 1;
    addFloat(m.x, m.y - 30 * sc, '+${fmt(g)}', 0xFFFFC94A, 14);
    final nc = m.boss ? (GameCalc.isLord(c.fightSt()) ? 5 : 2) : (rng.next() < .003 ? 1 : 0);
    if (nc != 0) {
      final cid = c.gainCard(rng, nc, 'battle');
      if (cid != null && cid.isNotEmpty) {
        addFloat(m.x, m.y - 74 * sc, '${comps[cid]!.n} 카드 +$nc', 0xFFC9A4FF, 13);
      } else if (cid == '') {
        addFloat(m.x, m.y - 74 * sc, '+${fmt(c.cardGoldLast)}', 0xFFFFC94A, 13);
      }
    }
    if (truthy(s.bld['farm'])) {
      for (final cr in crops.reversed) {
        if (rng.next() < cr.drop * (m.boss ? 5 : 1)) {
          s.seeds[cr.k] = asNum(s.seeds[cr.k]) + 1;
          addFloat(m.x, m.y - 50 * sc, '${cr.n} 씨앗', 0xFF9BE38A, 12);
          break;
        }
      }
    }
    if (m.boss) {
      events.add(HapticEvent(const [40, 30, 60]));
      final cleared = s.stage, bn = GameCalc.bossName(cleared), lord = GameCalc.isLord(cleared), tn = GameCalc.terrName(cleared);
      final dem = GameCalc.isDemon(cleared), gh = GameCalc.isGhost(cleared);
      if (dem) {
        _demonWin();
      } else {
        final gl = s.raw['gemLord'] is Map ? s.raw['gemLord'] as Map : (s.raw['gemLord'] = <String, dynamic>{});
        if (lord && !truthy(gl['$cleared'])) {
          gl['$cleared'] = 1;
          s.gem = s.gem + lordGem;
          events.add(GemEvent(lordGem, '군단장 첫 처치'));
        }
        if (gh && !truthy(gl['$cleared'])) {
          gl['$cleared'] = 1;
          s.gem = s.gem + ghostGem;
          events.add(GemEvent(ghostGem, '잔영 첫 처치'));
        }
      }
      s.stage = math.min(maxLand + 1, cleared + 1);
      s.best = math.max(s.best, s.stage);
      s.wave = 0;
      seal = null;
      toast('$bn 처치');
      banner = StageBanner('$tn 탈환!', dem ? '마왕을 몰아냈다' : lord ? '군단장을 쓰러뜨렸다' : gh ? '잔영을 걷어냈다' : '영지를 되찾았다');
      say('k', dem ? '…끝났다. 진짜로.' : lord ? '됐다… 이제 진짜 은퇴해도 되지?' : '여기 흙, 다시 살아나겠네.');
      final chapter = s.stage <= maxLand && (s.stage - 1) % 10 == 0;
      // 왕도 이야기 표시 여부는 웹처럼 여기서 정함 (처음 한 번만 장면, 그 뒤는 알림)
      if (chapter && GameCalc.isCap(s.stage)) {
        events.add(CapStoryEvent(truthy(s.done['capRoad']) ? 'roadAgain' : 'road'));
        s.done['capRoad'] = true;
      }
      for (final (st0, k) in const [(56, 'cap56'), (57, 'cap57')]) {
        if (cleared == st0 && !truthy(s.done[k])) {
          s.done[k] = true;
          events.add(CapStoryEvent(k));
        }
      }
      events.add(StageClearedEvent(cleared, lord, chapter && !GameCalc.isCap(s.stage)));
      runStoryEvents();
    } else {
      s.wave = s.wave + 1;
    }
  }

  /// 마왕 발타사르: 50%에서 1.5초 멈춤 → 정체 공개 → 2단계(공격 ×demAtk2), 2단계는 8초마다 「봉인의 파동」 (웹 demStep)
  void _demStep(num dt, BattleLayout l) {
    Mon? bm;
    for (final m in mons) {
      if (m.dem && m.hp > 0 && m.dead == 0) bm = m;
    }
    if (bm == null) return;
    if (!bm.ph2 && bm.hp <= bm.max * .5) {
      bm.ph2 = true;
      bm.atk = bm.atk * Balance.demAtk2 / Balance.demAtk;
      bm.sealT = sealEvery;
      holdT = 1.5;
      shakeT = .5;
      flash = .25;
      talk = BossTalk(balTalkReveal);
      events.add(HapticEvent(const [60, 40, 60]));
      return;
    }
    if (!bm.ph2) return;
    bm.sealT -= dt;
    if (bm.sealT <= sealWarn && seal == null) seal = SealWarn();
    if (bm.sealT <= 0) {
      bm.sealT = sealEvery;
      seal = null;
      _sealHit(bm, l);
    }
  }

  /// 봉인의 파동: 원정대 전체에 공격 ×seal. 방어 스킬(브론 버팀목·버치 벌통 방패·덕배 불굴 등)로 버틸 수 있음
  void _sealHit(Mon bm, BattleLayout l) {
    flash = .35;
    shakeT = .6;
    events.add(HapticEvent(const [80]));
    for (final id in l.ids) {
      final q = party[id];
      if (q == null || q.down) continue;
      final dm = bm.atk * Balance.seal * (skx.shield > 0 ? .5 : 1) * (skx.mount > 0 ? .3 : 1) * (q.bsh > 0 ? 1 - .4 * q.bshK : 1);
      q.hp -= dm;
      q.hit = .2;
      addFloat(l.pos[id]!, l.py[id]! - (heightOf(id) + 8) * l.s, '-${fmt(dm)}', 0xFFFFD34A, 14);
      if (q.hp <= 0) {
        if (skx.guts > 0 && q.guts) {
          q.guts = false;
          q.hp = 1;
          addFloat(l.pos[id]!, l.py[id]! - (heightOf(id) + 24) * l.s, '불굴!', 0xFFFFD27A, 14);
        } else {
          q.hp = 0;
          q.down = true;
        }
      }
    }
    spawnFx('crit', w * .3, l.bot - 20 * l.s, 140 * l.s, .5);
  }

  /// 마왕 처치 (웹 bossDemonWin): 첫 처치 이삭 300·테두리·배지 / 은퇴 후 다시 처치하면 그 회차 1번 은퇴의 추억 +3
  void _demonWin() {
    final first = orNum(s.raw['capClears'], 0) <= 0;
    s.raw['capClears'] = orNum(s.raw['capClears'], 0) + 1;
    talk = null;
    seal = null;
    final gl = s.raw['gemLord'] is Map ? s.raw['gemLord'] as Map : (s.raw['gemLord'] = <String, dynamic>{});
    if (first && !truthy(gl['$maxLand'])) {
      gl['$maxLand'] = 1;
      s.gem = s.gem + demonGem;
      events.add(GemEvent(demonGem, '마왕 발타사르 첫 처치'));
    }
    var bonus = 0;
    if (!first && !truthy(s.raw['capBonus'])) {
      s.memory = s.memory + capMem;
      bonus = capMem;
    }
    s.raw['capBonus'] = 1;
    c.pfCheck();
    events.add(DemonWinEvent(first, bonus));
  }

  /// 보스 남은 시간 한도 (성주 30초, 군단장 40초, 마왕 60초)
  num get bossLimit => GameCalc.bossLim(c.fightSt());
  Mon? get boss {
    for (final m in mons) {
      if (m.boss) return m;
    }
    return null;
  }
}
