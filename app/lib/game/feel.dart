/// 손맛 — 효과음과 진동.
///
/// - 효과음: app/assets/audio/sfx_*.wav (tools/make_sfx.py 로 직접 합성). 설정에서 끌 수 있음(S.snd === false).
/// - 진동: 웹 navigator.vibrate(패턴)과 같은 패턴. 안드로이드는 패턴 그대로, 아이폰은 기본 진동(패턴 미지원).
/// 시험(flutter test)에는 소리·진동 장치가 없으므로 main.dart 에서 [Feel.live] 를 켤 때만 동작한다.
library;

import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class Feel {
  /// 실제 폰에서만 true (main.dart)
  static bool live = false;

  /// 설정의 효과음 켜기/끄기 (저장: S.snd)
  static bool soundOn = true;

  static final Map<String, AudioPlayer> _players = {};
  static final Map<String, int> _last = {};

  /// 같은 소리가 너무 촘촘히 겹치지 않게 (밀리초)
  static const _gap = {'tap': 40, 'coin': 90, 'box': 90, 'up': 70};

  /// 효과음 (k: tap · coin · box · equip · up · clear · fanfare · boss · skill · goblin · gem)
  static Future<void> sound(String k, {double volume = 1}) async {
    if (!live || !soundOn) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[k] ?? 0) < (_gap[k] ?? 120)) return;
    _last[k] = now;
    try {
      final p = _players[k] ??= AudioPlayer(playerId: 'sfx_$k');
      await p.stop();
      await p.play(AssetSource('audio/sfx_$k.wav'), volume: volume, mode: PlayerMode.lowLatency);
    } catch (_) {/* 소리가 안 나도 게임은 계속 */}
  }

  static bool? _hasVib;

  /// 진동 (웹 haptic 패턴: [진동, 쉼, 진동 …] 밀리초)
  static Future<void> vibrate(List<int> pattern) async {
    if (!live || pattern.isEmpty) return;
    try {
      if (Platform.isAndroid) {
        _hasVib ??= await Vibration.hasVibrator();
        if (_hasVib != true) return;
        if (pattern.length == 1) {
          await Vibration.vibrate(duration: pattern[0]);
        } else {
          await Vibration.vibrate(pattern: [0, ...pattern]);
        }
      } else {
        // 아이폰: 길이에 따라 세기만 다르게
        final total = pattern.fold<int>(0, (a, b) => a + b);
        if (total >= 40) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
      }
    } catch (_) {}
  }
}
