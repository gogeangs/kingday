/// 보상형 광고 (AdMob).
///
/// 지금은 구글이 공개한 **시험용 광고 ID** 로 동작한다(진짜 돈이 오가지 않는 시험 광고).
/// 출시 전에 대표님이 AdMob 에서 만든 광고 단위 ID 를 [realAndroid]·[realIos] 에 넣고,
/// AndroidManifest·Info.plist 의 앱 ID 도 바꾼다 (docs/RELEASE_NATIVE.md 참고). 광고 ID 는 공개돼도 되는 값.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

class Ads {
  /// 구글 공식 시험용 보상형 광고 단위
  static const testAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const testIos = 'ca-app-pub-3940256099942544/1712485313';

  /// 실제 광고 단위 (AdMob 에서 만든 뒤 채움. 비어 있으면 시험용 사용)
  static const realAndroid = '';
  static const realIos = '';

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

  /// 광고 보여 주기. true = 끝까지 봄(보상), false = 중간에 닫음, null = 보여 줄 광고가 없음
  static Future<bool?> show() async {
    if (!live) return null;
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
