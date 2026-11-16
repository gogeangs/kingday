/// 유저 행동 기록 (docs/PLAN_MONETIZATION_REMOVAL.md 6번) — 웹 index.html 의 lgDay·lgAd·lgOut·lgFlush 와 같은 규칙.
///
/// 하루 한 줄: 날짜 · 최고 영지 · 지금 영지 · 은퇴 횟수 · 광고 자리별 시청 수 · 얻은 이삭 · 쓴 곳별 이삭.
/// 이 기기 저장소 「kd-log」에 최근 14일만 모아 두고, 접속할 때·앱으로 돌아올 때·10분마다 서버 kd_log_day 로 올림(같은 날은 덮어씀).
/// 계정 id 로만 묶이고(서버가 auth.uid() 로 정함) 개인을 알아볼 정보는 보내지 않는다. 서버가 없거나 실패하면 조용히 다음에.
/// 서버: supabase/stage15_play_log.sql (2026-11-16 실행)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../core/actions.dart';
import '../core/js.dart';
import 'controller.dart';

class PlayLog {
  PlayLog(this.g);
  final GameController g;
  static const key = 'kd-log';

  Map<String, dynamic>? _all;
  bool _busy = false;
  Timer? _timer;

  Map<String, dynamic> _load() {
    if (_all != null) return _all!;
    try {
      final t = g.store.prefs.getString(key);
      final d = t == null ? null : jsonDecode(t);
      _all = d is Map ? d.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      _all = <String, dynamic>{};
    }
    return _all!;
  }

  void _save() {
    try {
      g.store.prefs.setString(key, jsonEncode(_load()));
    } catch (_) {}
  }

  int get _gem => g.state.gem.floor();

  /// 오늘 줄 (날이 바뀌었으면 어제 줄을 지금 이삭으로 마감)
  Map<String, dynamic> _day() {
    final all = _load(), t = g.calc.today();
    if (all[t] is! Map) {
      for (final r in all.values) {
        if (r is Map && truthy(r['open'])) _close(r);
      }
      all[t] = <String, dynamic>{'d': t, 'g0': _gem, 'ad': <String, dynamic>{}, 'out': <String, dynamic>{}, 'open': 1};
      final ks = all.keys.toList()..sort();
      while (ks.length > 14) {
        all.remove(ks.removeAt(0));
      }
    }
    return (all[t] as Map).cast<String, dynamic>();
  }

  void _close(Map r) {
    final out = (asMap(r['out']) ?? const {}).values.fold<num>(0, (a, b) => a + (b is num ? b : 0));
    r['gin'] = math.max(0, _gem - orNum(r['g0'], 0) + out).floor();
    r['best'] = g.state.best;
    r['stage'] = g.state.stage;
    r['ret'] = orNum(g.state.raw['retires'], 0);
    r['open'] = 0;
  }

  /// 접속할 때: 오늘 줄을 만들고, 이삭 쓴 곳 기록을 잇고, 조금 뒤·10분마다 올림
  void boot() {
    GameActions.onGemOut = out;
    _day();
    _save();
    Timer(const Duration(seconds: 8), flush);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (!g.backgrounded) flush();
    });
  }

  /// 광고 자리별 시청 (웹 lgAd)
  void ad(String k) {
    final r = _day(), m = (r['ad'] as Map);
    m[k] = orNum(m[k], 0) + 1;
    _save();
  }

  /// 이삭 쓴 곳 (웹 lgOut)
  void out(String why, num n) {
    if (!(n > 0)) return;
    final r = _day(), m = (r['out'] as Map);
    m[why] = orNum(m[why], 0) + n;
    _save();
  }

  /// 서버로 올리기 (웹 lgFlush)
  Future<void> flush() async {
    if (_busy || !g.online.on) return;
    final all = _load(), cur = _day();
    _close(cur);
    cur['open'] = 1;
    final rows = [
      for (final r in all.values)
        if (r is Map && (!truthy(r['sent']) || truthy(r['open'])))
          {'d': r['d'], 'best': r['best'] ?? 1, 'stage': r['stage'] ?? 1, 'ret': r['ret'] ?? 0, 'ad': r['ad'] ?? {}, 'gin': r['gin'] ?? 0, 'out': r['out'] ?? {}},
    ];
    if (rows.isEmpty) return;
    _busy = true;
    try {
      await g.online.ensure();
      await g.online.rpc('kd_log_day', {'p_rows': rows});
      for (final r in all.values) {
        if (r is Map && !truthy(r['open'])) r['sent'] = 1;
      }
      _save();
    } catch (_) {
    } finally {
      _busy = false;
    }
  }
}
