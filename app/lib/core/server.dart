/// 서버(Supabase) 연결 — 웹과 똑같이 SDK 없이 REST 로 직접 부른다.
///
/// - 게스트(익명) 계정: /auth/v1/signup → access/refresh 토큰을 기기에 저장 (웹 localStorage 'kd-sb')
/// - 게임 함수: /rest/v1/rpc/{함수}  (kd_ensure_profile · kd_submit · kd_ranking · kd_mail_list …)
/// - 여기에 들어가는 키는 공개용(publishable) 키뿐. 비밀 키·DB 비밀번호는 절대 넣지 않는다.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const sbUrl = 'https://xqrdqigdwfyoaalqalfc.supabase.co';
const sbKey = 'sb_publishable_b0VfItWh30lKMyHaOSehXQ_lWqe_xTM';

/// 웹 localStorage 키와 같은 이름 (앱 저장소 안에서만 쓰임)
const sbAuthKey = 'kd-sb';

class SbAuth {
  SbAuth({required this.access, this.refresh, required this.expiresAt, this.uid});
  final String access;
  final String? refresh;

  /// 초 단위 (웹 expires_at)
  final int expiresAt;
  final String? uid;

  Map<String, dynamic> toJson() => {'access_token': access, 'refresh_token': refresh, 'expires_at': expiresAt, 'uid': uid};

  static SbAuth? fromJson(Object? j) {
    if (j is! Map || j['access_token'] is! String) return null;
    return SbAuth(
      access: j['access_token'],
      refresh: j['refresh_token'] as String?,
      expiresAt: (j['expires_at'] as num?)?.toInt() ?? 0,
      uid: j['uid'] as String?,
    );
  }
}

class ServerError implements Exception {
  ServerError(this.what);
  final String what;
  @override
  String toString() => 'ServerError($what)';
}

class Server {
  Server(this._prefs, {http.Client? client, int Function()? now})
      : _http = client ?? http.Client(),
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    try {
      final t = _prefs.getString(sbAuthKey);
      if (t != null) auth = SbAuth.fromJson(jsonDecode(t));
    } catch (_) {}
  }

  final SharedPreferences _prefs;
  final http.Client _http;
  final int Function() _now;
  SbAuth? auth;

  static const _timeout = Duration(seconds: 15);
  Map<String, String> get _h => {'apikey': sbKey, 'Content-Type': 'application/json'};

  Future<void> _store() => _prefs.setString(sbAuthKey, jsonEncode(auth?.toJson()));

  /// 받은 토큰 저장 (구글 로그인 뒤 등 바깥에서 받은 토큰도 여기로)
  Future<SbAuth> setSession(Map<String, dynamic> j) async {
    final user = j['user'];
    auth = SbAuth(
      access: j['access_token'] as String,
      refresh: j['refresh_token'] as String?,
      expiresAt: (j['expires_at'] as num?)?.toInt() ?? (_now() ~/ 1000 + ((j['expires_in'] as num?)?.toInt() ?? 3600)),
      uid: user is Map ? user['id'] as String? : null,
    );
    await _store();
    return auth!;
  }

  /// 웹 sbLogin(): 토큰이 1분 넘게 남았으면 그대로, 아니면 새로 고침, 그것도 안 되면 새 게스트 계정
  Future<SbAuth> login() async {
    final a = auth;
    if (a != null && a.expiresAt * 1000 > _now() + 60000) return a;
    http.Response? res;
    if (a?.refresh != null) {
      try {
        res = await _http
            .post(Uri.parse('$sbUrl/auth/v1/token?grant_type=refresh_token'), headers: _h, body: jsonEncode({'refresh_token': a!.refresh}))
            .timeout(_timeout);
      } catch (_) {}
    }
    if (res == null || res.statusCode >= 300) {
      res = await _http.post(Uri.parse('$sbUrl/auth/v1/signup'), headers: _h, body: jsonEncode({})).timeout(_timeout);
    }
    if (res.statusCode >= 300) throw ServerError('auth ${res.statusCode}');
    return setSession(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// 웹 sbRpc(fn,args)
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? args]) async {
    final a = await login();
    final res = await _http
        .post(Uri.parse('$sbUrl/rest/v1/rpc/$fn'),
            headers: {..._h, 'Authorization': 'Bearer ${a.access}'}, body: jsonEncode(args ?? const {}))
        .timeout(_timeout);
    if (res.statusCode >= 300) throw ServerError('$fn ${res.statusCode}');
    if (res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// 웹 acctFetch(): 지금 계정 정보 (게스트인지, 연결된 이메일)
  Future<({bool anon, String email})?> user() async {
    final a = await login();
    final res = await _http.get(Uri.parse('$sbUrl/auth/v1/user'), headers: {'apikey': sbKey, 'Authorization': 'Bearer ${a.access}'}).timeout(_timeout);
    if (res.statusCode >= 300) return null;
    final u = jsonDecode(utf8.decode(res.bodyBytes));
    if (u is! Map) return null;
    var email = u['email'] is String ? u['email'] as String : '';
    if (email.isEmpty && u['identities'] is List) {
      for (final i in u['identities'] as List) {
        final d = i is Map ? i['identity_data'] : null;
        if (d is Map && d['email'] is String && (d['email'] as String).isNotEmpty) {
          email = d['email'];
          break;
        }
      }
    }
    return (anon: u['is_anonymous'] == true, email: email);
  }

  void close() => _http.close();
}
