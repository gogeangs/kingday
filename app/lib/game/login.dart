/// 구글·애플 로그인 → Supabase 계정 (웹과 같은 계정 서버).
///
/// 폰의 구글/애플 로그인 창에서 받은 ID 토큰을 Supabase 에 보내 로그인한다 (/auth/v1/token?grant_type=id_token).
/// 클라이언트 ID 는 공개돼도 되는 값이지만, 대표님이 Google Cloud 에서 만들어야 생긴다.
/// 비어 있는 동안은 설정 창에 「다음 업데이트에서 열려요」로 보이고 로그인 버튼이 숨겨진다.
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class Login {
  /// Google Cloud「kingday web」OAuth 클라이언트 ID (…apps.googleusercontent.com).
  /// 안드로이드는 이 ID 로 ID 토큰을 받아야 Supabase 가 받아 줌. (docs/RELEASE_NATIVE.md)
  static const googleWebClientId = '784535946419-qrselu11h6qteqdugkpc9f7su3d0rfkl.apps.googleusercontent.com';

  /// Google Cloud 의 iOS OAuth 클라이언트 ID (아이폰용)
  static const googleIosClientId = '784535946419-6lcj1p50e5jptq7am9v7vpsrr6nv417b.apps.googleusercontent.com';

  /// 구글 로그인을 쓸 수 있는지 (클라이언트 ID 를 넣은 뒤)
  static bool get googleReady => googleWebClientId.isNotEmpty && (!Platform.isIOS || googleIosClientId.isNotEmpty);

  /// 애플 로그인 (아이폰만, App Store 규정: 다른 소셜 로그인이 있으면 애플 로그인도 있어야 함)
  static bool get appleReady => Platform.isIOS && googleReady;

  /// 구글 로그인 준비는 앱을 켠 뒤 한 번만 (google_sign_in 7: initialize 는 한 번만 불러야 함).
  /// 아이폰 구글 로그인은 ID 토큰에 nonce 를 늘 넣으므로, 우리가 만든 nonce 를 넘기고
  /// Supabase 에는 원래 값(raw)을 보낸다 (Supabase 「Skip nonce checks」는 켜지 않음 · 2026-11-02 애플 심사 2.1(a)).
  static String? _gRaw;
  static Future<void>? _gInit;

  /// 구글 로그인 → (provider, idToken, rawNonce). 취소하면 null
  static Future<(String, String, String?)?> google() async {
    final gs = GoogleSignIn.instance;
    _gInit ??= () {
      final raw = _gRaw = _nonce();
      return gs.initialize(
        clientId: Platform.isIOS ? googleIosClientId : null,
        serverClientId: googleWebClientId,
        nonce: _sha(raw),
      );
    }();
    await _gInit;
    try {
      await gs.signOut();
    } catch (_) {}
    try {
      final acc = await gs.authenticate(scopeHint: const ['email']);
      final id = acc.authentication.idToken;
      if (id == null) throw StateError('google id token 없음');
      return ('google', id, _gRaw);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// 애플 로그인은 앱 안 네이티브 코드(ios/Runner/AppleSignIn.swift)로 띄운다.
  /// 아이패드에서 로그인 창이 뜨지 않던 문제(2026-11-02 애플 심사 2.1(a)) — 창을 띄울 화면(window)을 직접 정해 줌.
  static const _appleCh = MethodChannel('kd/apple_sign_in');

  /// 애플 로그인 → (provider, idToken, rawNonce). 취소하면 null
  static Future<(String, String, String?)?> apple() async {
    final raw = _nonce();
    try {
      final id = await _appleCh.invokeMethod<String>('signIn', {'nonce': _sha(raw)});
      if (id == null || id.isEmpty) throw StateError('apple id token 없음');
      return ('apple', id, raw);
    } on PlatformException catch (e) {
      if (e.code == 'canceled') return null;
      rethrow;
    }
  }

  static String _sha(String raw) => sha256.convert(utf8.encode(raw)).toString();

  static String _nonce() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
  }
}
