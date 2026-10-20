/// 전투 화면 — Flame 캔버스 + 그 위의 Flutter 표시(영지 표시줄, 보스 막대, 원정대 초상화, 자동·배속 버튼).
///
/// 웹 index.html 의 .stagewrap 안 구성(ovtop · bossbar · ovbottom)을 옮긴 것.
/// 상단 바·하단 탭·메뉴 창은 3단계에서 붙인다.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../battle/battle_game.dart';
import '../battle/sim.dart';
import '../core/calc.dart';
import '../core/data.dart';
import '../core/fmt.dart';
import '../core/js.dart';
import '../core/save_store.dart';
import '../core/state.dart';

class KdColors {
  static const bg = Color(0xFF141A29); // --bg
  static const panel = Color(0xFF1F2740); // --panel
  static const panel2 = Color(0xFF29334F); // --panel2
  static const line = Color(0xFF37436A); // --line
  static const gold = Color(0xFFFFC94A); // --gold
  static const fg = Color(0xFFEEF1F8); // --fg
  static const muted = Color(0xFF97A2C3); // --muted
  static const good = Color(0xFF7BE08F); // --good
  static const bad = Color(0xFFFF6B7D); // --bad
}

/// 0~1 로 자르기
double _c01(num v) => v < 0 ? 0 : v > 1 ? 1 : v.toDouble();

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.store, required this.state});
  final SaveStore store;
  final GameState state;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with WidgetsBindingObserver {
  late final GameCalc calc = GameCalc(widget.state);
  late final BattleSim sim = BattleSim(calc);
  late final BattleGame game = BattleGame(sim, insets: const BattleInsets(top: 84, bottom: 118))..onTick = _onTick;
  final _tick = ValueNotifier<int>(0);
  Timer? _saveTimer;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.state;
    if (!truthy(s.raw['started'])) s.raw['started'] = true;
    s.raw['v'] = 3;
    calc.produce();
    // 웹 loop(): 5초마다 저장
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _toastTimer?.cancel();
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    // 웹 visibilitychange: 화면을 벗어나면 바로 저장
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive) _save();
  }

  void _save() => widget.store.save(widget.state, DateTime.now().millisecondsSinceEpoch);

  num _uiT = 0;
  void _onTick() {
    for (final e in sim.events) {
      _handle(e);
    }
    sim.events.clear();
    // 웹 loop(): 0.4초마다 생산(낚시터·양봉장·광산·공사)
    _uiT += 1 / 60;
    if (_uiT > .4) {
      _uiT = 0;
      calc.produce();
    }
    _tick.value++;
  }

  void toast(String m) {
    setState(() => _toast = m);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _haptic(List<int> p) {
    if (widget.state.raw['vib'] == false) return;
    p.length > 1 ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }

  void _handle(BattleEvent e) {
    switch (e) {
      case ToastEvent(:final msg):
        toast(msg);
      case HapticEvent(:final pattern):
        _haptic(pattern);
      case GoblinLootEvent(:final relic, :final gold, :final gem, :final cardId):
        // 장비 비교 창은 4단계. 지금은 웹 「자동으로 열기」처럼 더 좋으면 끼우고 아니면 판다.
        final cur = calc.equipped(relic.slot);
        String what;
        if (GameCalc.score(relic) > GameCalc.score(cur)) {
          if (cur != null) widget.state.gold = widget.state.gold + cur.price;
          widget.state.eq[relic.slot] = relic.toJson();
          what = '${itemGrades[relic.g].n} ${slotDef(relic.slot).n} 장착';
        } else {
          widget.state.gold = widget.state.gold + relic.price;
          what = '${itemGrades[relic.g].n} ${slotDef(relic.slot).n} 판매';
        }
        toast('황금 고블린 처치! 골드 +${fmt(gold)} · 이삭 +${fmt(gem)} · $what${cardId != null ? ' · ${comps[cardId]!.n} 카드 +3' : ''}');
      case StoryEvent(:final id):
        final ev = storyEvents.firstWhere((x) => x.id == id);
        toast('${ev.eyebrow} · ${ev.title}');
      case RankUpEvent(:final rankIdx, :final gem):
        toast('칭호 상승! ${ranks[rankIdx].n} 카엘 · 원정대 +4%${gem > 0 ? ' · 황금 이삭 +${fmt(gem)}' : ''}');
      case GemEvent(:final n, :final why):
        toast('황금 이삭 +${fmt(n)} · $why');
      case SkillTutorialEvent():
        toast('원정대의 힘이 가득 찼어요! 빛나는 초상화를 눌러 특수 스킬을 쓰세요');
      case StageClearedEvent():
        _save();
      case FightResetEvent():
        break;
    }
  }

  void _tapMember(String id) {
    final p = sim.party[id];
    if (sim.skFull(id) && sim.engaged) {
      sim.castSkill(id);
      HapticFeedback.lightImpact();
      return;
    }
    if (p != null && p.down) {
      toast('${comps[id]!.n}은(는) 쓰러져 있어요');
    } else if (!sim.engaged && sim.skFull(id)) {
      toast('싸우는 중에만 쓸 수 있어요');
    } else {
      toast('${skills[id]!.n} · 게이지 ${((p?.sg ?? 0) / skills[id]!.need * 100).floor()}%');
    }
  }

  void _skillInfo(String id) {
    final p = sim.party[id];
    final g = math.min(100, (p?.sg ?? 0) / skills[id]!.need * 100);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KdColors.panel,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/game/skills/skill_$id.png', width: 56, height: 56, errorBuilder: (_, __, ___) => const SizedBox(width: 56)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(skills[id]!.n, style: const TextStyle(color: KdColors.gold, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${comps[id]!.n} · ${skills[id]!.d}', style: const TextStyle(color: KdColors.fg, height: 1.45)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: g / 100, minHeight: 6, color: KdColors.gold, backgroundColor: Colors.black38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      backgroundColor: KdColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<int>(valueListenable: _tick, builder: (_, __, ___) => _hud(s)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: GameWidget(game: game)),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    child: ValueListenableBuilder<int>(valueListenable: _tick, builder: (_, __, ___) => _top(s)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: ValueListenableBuilder<int>(valueListenable: _tick, builder: (_, __, ___) => _bottom(s)),
                  ),
                  if (_toast != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 132,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xEE0D1220),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF6B5420)),
                            ),
                            child: Text(_toast!, textAlign: TextAlign.center, style: const TextStyle(color: KdColors.fg, fontSize: 13, height: 1.35)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 정보 (3단계에서 웹 .hud 그대로 꾸밈) ──
  Widget _hud(GameState s) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1A2135), Color(0xFF0D1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(bottom: BorderSide(color: Color(0xFF6B5420), width: 2)),
      ),
      child: Row(
        children: [
          Text('카엘', style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(ranks[calc.rankIdx()].n, style: const TextStyle(color: KdColors.gold, fontSize: 12)),
          const SizedBox(width: 10),
          Text('전투력 ${fmt(calc.power())}', style: const TextStyle(color: KdColors.muted, fontSize: 12)),
          const Spacer(),
          _pill('assets/game/gem/ui_gem.png', fmt(s.gem)),
          const SizedBox(width: 6),
          _pill('assets/game/ui/ui_gold.png', fmt(s.gold)),
        ],
      ),
    );
  }

  Widget _pill(String icon, String v) => Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(icon, width: 20, height: 20, errorBuilder: (_, __, ___) => const SizedBox(width: 4)),
          const SizedBox(width: 4),
          Text(v, style: const TextStyle(color: KdColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );

  // ── 영지 표시줄 + 보스 막대 (웹 .ovtop) ──
  Widget _top(GameState s) {
    final st = s.stage, r = GameCalc.region(st), boss = sim.boss;
    final label = st > maxLand ? '왕도 진격로' : '${(st - 1) ~/ 10 + 1}-${(st - 1) % 10 + 1} ${r.n}';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0D1220),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6B5420)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: KdColors.fg, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(GameCalc.terrName(st), style: const TextStyle(color: KdColors.muted, fontSize: 11)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 10; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: i < s.wave ? KdColors.gold : Colors.white24, shape: BoxShape.circle),
                  ),
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: boss != null ? KdColors.bad : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
            ],
          ),
        ),
        if (boss != null) ...[const SizedBox(height: 6), _bossBar(s, boss)],
      ],
    );
  }

  Widget _bossBar(GameState s, Mon b) {
    final lord = GameCalc.isLord(s.stage), lim = sim.bossLimit, left = math.max(0, sim.bossT);
    final hurry = left <= 10;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      decoration: BoxDecoration(
        color: const Color(0xDD1A0610),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lord ? const Color(0xFFB06EFF) : const Color(0xFFFF4A5E), width: 1.5),
      ),
      child: Row(
        children: [
          if (lord)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/game/portraits/portrait_${bossIds[GameCalc.regionIndex(s.stage)]}_idle.png',
                    width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: lord ? const Color(0xFF7A3FD0) : const Color(0xFFB0283A), borderRadius: BorderRadius.circular(4)),
                    child: Text(lord ? '군단장' : '성주', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(GameCalc.bossName(s.stage),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: KdColors.fg, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Text('${left.ceil()}초', style: TextStyle(color: hurry ? KdColors.bad : KdColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Stack(alignment: Alignment.center, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _c01(math.max(0, b.hp) / b.max),
                      minHeight: 12,
                      color: const Color(0xFFE0334A),
                      backgroundColor: Colors.black54,
                    ),
                  ),
                  Text('${fmt(math.max(0, b.hp))} / ${fmt(b.max)}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _c01(left / lim),
                    minHeight: 3,
                    color: hurry ? KdColors.bad : KdColors.gold,
                    backgroundColor: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 원정대 초상화 + 자동·배속 (웹 .ovbottom) ──
  Widget _bottom(GameState s) {
    final ids = calc.members();
    final manual = s.raw['autoSkill'] == false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: i < ids.length ? _memberCard(ids[i], manual) : _emptyCard(),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 6),
          _qbtn('assets/game/ui/btn_auto.png', manual ? '자동 끔' : '자동 켬', on: !manual, onTap: () {
            setState(() => s.raw['autoSkill'] = manual);
            toast(manual ? '스킬 자동 사용 켜짐' : '스킬 자동 사용 꺼짐 · 빛나는 초상화를 눌러 쓰세요');
          }),
          const SizedBox(width: 4),
          _qbtn('assets/game/ui/btn_x${game.speed}.png', 'x${game.speed}', on: game.speed == 2, onTap: () {
            setState(() => s.raw['speed'] = game.speed == 2 ? 1 : 2);
          }),
        ],
      ),
    );
  }

  Widget _emptyCard() => AspectRatio(
        aspectRatio: 56 / 76,
        child: Container(
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
        ),
      );

  Widget _memberCard(String id, bool manual) {
    final p = sim.party[id];
    final hp = p == null ? 1.0 : _c01(p.hp / calc.stats(id).hp);
    final g = p == null ? 0.0 : _c01(p.sg / skills[id]!.need);
    final ready = sim.skFull(id), down = p?.down ?? false;
    return GestureDetector(
      onTap: () => _tapMember(id),
      onLongPress: () => _skillInfo(id),
      child: AspectRatio(
        aspectRatio: 56 / 76,
        child: Opacity(
          opacity: down ? .45 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1220),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ready ? KdColors.gold : const Color(0xFF6B5420), width: ready ? 2 : 1),
              boxShadow: ready ? [BoxShadow(color: KdColors.gold.withValues(alpha: .6), blurRadius: 8)] : null,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                        child: Image.asset('assets/game/portraits/portrait_${id}_idle.png',
                            fit: BoxFit.cover, alignment: const Alignment(0, -.6), errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                      // 스킬 게이지 (웹 .ring)
                      Positioned(
                        left: 3,
                        right: 3,
                        bottom: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(value: g, minHeight: 4, color: KdColors.gold, backgroundColor: Colors.black54),
                        ),
                      ),
                      if (ready && manual)
                        const Center(
                          child: Text('탭!', style: TextStyle(color: KdColors.gold, fontWeight: FontWeight.w800, fontSize: 14, shadows: [Shadow(blurRadius: 4)])),
                        ),
                    ],
                  ),
                ),
                Container(
                  height: 5,
                  margin: const EdgeInsets.fromLTRB(3, 2, 3, 3),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)),
                  child: FractionallySizedBox(
                    widthFactor: hp,
                    child: Container(decoration: BoxDecoration(color: down ? Colors.grey : KdColors.good, borderRadius: BorderRadius.circular(2))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qbtn(String img, String label, {required bool on, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: on ? const Color(0xCC3A2E10) : const Color(0xCC0D1220),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? KdColors.gold : const Color(0xFF6B5420)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(img, width: 28, height: 28, errorBuilder: (_, __, ___) => const SizedBox(height: 28)),
            Text(label, style: TextStyle(color: on ? KdColors.gold : KdColors.muted, fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
