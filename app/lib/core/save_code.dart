/// 저장 코드 — 웹 설정 「저장 데이터 옮기기」와 같은 형식.
///
/// 웹: btoa(unescape(encodeURIComponent(JSON.stringify(S)))) = 저장 JSON 을 UTF-8 로 바꿔 base64.
/// 그래서 웹에서 만든 코드를 앱에 붙여 넣어도, 앱에서 만든 코드를 웹에 붙여 넣어도 그대로 불러와진다.
library;

import 'dart:convert';

import 'state.dart';

String exportSaveCode(GameState s) => base64Encode(utf8.encode(jsonEncode(s.raw)));

/// 코드를 읽어 저장 JSON 으로. 올바르지 않으면 null (웹: d.gold 가 숫자인지 확인)
Map<String, dynamic>? importSaveCode(String code) {
  try {
    // 복사하다 들어간 줄바꿈·띄어쓰기는 지움
    var c = code.replaceAll(RegExp(r'\s'), '');
    final pad = c.length % 4;
    if (pad != 0) c = c.padRight(c.length + 4 - pad, '=');
    final d = jsonDecode(utf8.decode(base64Decode(c)));
    if (GameState.looksLikeSave(d)) return (d as Map).cast<String, dynamic>();
  } catch (_) {}
  return null;
}
