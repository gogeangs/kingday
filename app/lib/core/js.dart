/// 웹(JavaScript) 코드의 동작을 그대로 흉내 내는 작은 도구들.
///
/// 저장 데이터는 웹과 같은 JSON 이라 값의 종류가 섞여 있다(숫자·없음·false).
/// 웹 공식의 `S.lv[id]||1` 같은 "값이 없거나 0이면 기본값" 규칙을 그대로 옮기려고 쓴다.
library;

/// JS 의 참/거짓 판정 (null·false·0·NaN·'' 는 거짓)
bool truthy(Object? v) {
  if (v == null || v == false) return false;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS `v || d` (숫자용)
num orNum(Object? v, num d) => truthy(v) && v is num ? v : d;

/// 숫자로 읽기 (숫자가 아니면 d)
num asNum(Object? v, [num d = 0]) => v is num ? v : d;

/// JS 객체(Map)로 읽기. 없으면 null
Map<String, dynamic>? asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

/// JS Math.round (양수는 Dart round 와 같고, 음수의 .5 는 +∞ 쪽으로)
num jsRound(num x) {
  if (x is int) return x;
  if (!x.isFinite) return x;
  final f = x.floorToDouble();
  final r = (x - f >= 0.5) ? f + 1 : f;
  return _toIntIfSafe(r);
}

num jsFloor(num x) => x is int || !x.isFinite ? x : _toIntIfSafe(x.floorToDouble());
num jsCeil(num x) => x is int || !x.isFinite ? x : _toIntIfSafe(x.ceilToDouble());

/// 2^53 안쪽이면 정수로(저장 JSON 이 웹과 같은 모양이 되게), 넘으면 실수 그대로
num _toIntIfSafe(double d) => d.abs() <= 9007199254740991 ? d.toInt() : d;

/// 안정 정렬 (JS Array.sort 는 안정 정렬이고, Dart List.sort 는 보장하지 않음)
List<T> stableSorted<T>(Iterable<T> src, int Function(T a, T b) cmp) {
  final list = src.toList();
  for (var i = 1; i < list.length; i++) {
    final x = list[i];
    var j = i - 1;
    while (j >= 0 && cmp(list[j], x) > 0) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = x;
  }
  return list;
}

/// JSON 깊은 복사 (Map·List 만 새로 만들고 값은 그대로)
dynamic deepCopy(dynamic v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key as String: deepCopy(e.value)};
  if (v is List) return [for (final x in v) deepCopy(x)];
  return v;
}

/// 웹 숫자를 글자로 바꿀 때와 같게: 정수면 소수점 없이 (5 → "5", 7.5 → "7.5")
String pctTxt(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
