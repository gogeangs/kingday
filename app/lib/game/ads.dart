/// 보상형 광고 (AdMob).
///
/// AdMob 계정 biz@project30s.co.kr (2026-10-27 가입) 의 「보상형 광고」 단위를 쓴다.
/// 앱 ID 는 AndroidManifest·Info.plist 에 있다 (docs/RELEASE_NATIVE.md). 광고 ID 는 공개돼도 되는 값.
/// 아이폰은 첫 광고를 보기 직전에 한 번 「추적 허용」 창(ATT)을 띄운다.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class Ads {
  /// 구글 공식 시험용 보상형 광고 단위
  static const testAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const testIos = 'ca-app-pub-3940256099942544/1712485313';

  /// 실제 광고 단위 (AdMob 「왕이 되는 그날까지」 · 보상형 광고)
  static const realAndroid = 'ca-app-pub-8720405407394137/5228095656';
  static const realIos = 'ca-app-pub-8720405407394137/7880637162';

  /// 실제 폰에서만 true (main.dart)
  static bool live = false;

  static String get _unit {
    if (Platform.isIOS) return realIos.isNotEmpty ? realIos : testIos;
    return realAndroid.isNotEmpty ? realAndroid : testAndroid;
  }

  static RewardedAd? _ad;
  static bool _loading = false;
  static int _fails = 0;

  static Future<void> init() async {
    if (!live) return;
    try {
      await MobileAds.instance.initialize();
      preload();
    } catch (_) {
      live = false;
    }
  }

  /// 다음 광고를 미리 불러 둠 (실패하면 조금 뒤 다시)
  static void preload() {
    if (!live || _ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _fails = 0;
        },
        onAdFailedToLoad: (e) {
          _loading = false;
          _fails++;
          Timer(Duration(seconds: (_fails * 15).clamp(15, 120)), preload);
        },
      ),
    );
  }

  /// 아이폰: 아직 묻지 않았으면 「추적 허용」 창을 한 번 띄움 (답과 상관없이 광고는 나옴)
  static bool _asked = false;
  static Future<void> _askTracking() async {
    if (_asked || !Platform.isIOS) return;
    _asked = true;
    try {
      if (await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {}
  }

  /// 광고 보여 주기. true = 끝까지 봄(보상), false = 중간에 닫음, null = 보여 줄 광고가 없음
  static Future<bool?> show() async {
    if (!live) return null;
    await _askTracking();
    final ad = _ad;
    if (ad == null) {
      preload();
      return null;
    }
    _ad = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preload();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        preload();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (_) {
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }
}
