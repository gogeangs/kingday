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
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class Login {
  /// Google Cloud「kingday web」OAuth 클라이언트 ID (…apps.googleusercontent.com).
  /// 안드로이드는 이 ID 로 ID 토큰을 받아야 Supabase 가 받아 줌. (docs/RELEASE_NATIVE.md)
  static const googleWebClientId = '';

  /// Google Cloud 의 iOS OAuth 클라이언트 ID (아이폰용)
  static const googleIosClientId = '';

  /// 구글 로그인을 쓸 수 있는지 (클라이언트 ID 를 넣은 뒤)
  static bool get googleReady => googleWebClientId.isNotEmpty && (!Platform.isIOS || googleIosClientId.isNotEmpty);

  /// 애플 로그인 (아이폰만, App Store 규정: 다른 소셜 로그인이 있으면 애플 로그인도 있어야 함)
  static bool get appleReady => Platform.isIOS && googleReady;

  /// 구글 로그인 → (provider, idToken, nonce). 취소하면 null
  static Future<(String, String, String?)?> google() async {
    final gs = GoogleSignIn(
      scopes: const ['email'],
      serverClientId: googleWebClientId,
      clientId: Platform.isIOS ? googleIosClientId : null,
    );
    await gs.signOut();
    final acc = await gs.signIn();
    if (acc == null) return null;
    final auth = await acc.authentication;
    final id = auth.idToken;
    if (id == null) throw StateError('google id token 없음');
    return ('google', id, null);
  }

  /// 애플 로그인 → (provider, idToken, rawNonce). 취소하면 null
  static Future<(String, String, String?)?> apple() async {
    final raw = _nonce();
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
      final id = c.identityToken;
      if (id == null) throw StateError('apple id token 없음');
      return ('apple', id, raw);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  static String _nonce() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
  }
}
