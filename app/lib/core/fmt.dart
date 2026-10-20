/// 숫자·시간 표시 — 웹 fmt() / fmtT() / mmss() 와 같은 글자를 만든다.
library;

/// 단위: K M B T, 그다음 aa ab … zz
final List<String> _units = [
  '', 'K', 'M', 'B', 'T',
  for (var i = 0; i < 26 * 26; i++) String.fromCharCode(97 + i ~/ 26) + String.fromCharCode(97 + i % 26),
];

/// 1만 미만은 1,234 처럼, 그 이상은 12.3K · 1.23M · 4.56aa 처럼.
String fmt(num n) {
  if (!n.isFinite) return '∞';
  // floorToDouble: 아주 큰 수(1e80 등)도 정수 범위를 넘지 않게 실수로 내림
  num v = n.floorToDouble();
  if (v < 1e4) return _group(v.toInt());
  var i = 0;
  while (v >= 1000 && i < _units.length - 1) {
    v /= 1000;
    i++;
  }
  final s = v < 10 ? v.toStringAsFixed(2) : v < 100 ? v.toStringAsFixed(1) : v.floorToDouble().toInt().toString();
  return s + _units[i];
}

/// 웹 toLocaleString('ko-KR') — 세 자리마다 쉼표
String _group(int n) {
  final neg = n < 0;
  final d = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(',');
    b.write(d[i]);
  }
  return (neg ? '-' : '') + b.toString();
}

/// 남은 시간: 「2시간 5분」 「3분 20초」 「45초」
String fmtT(num sec) {
  final t = sec.ceil() < 0 ? 0 : sec.ceil();
  final h = t ~/ 3600, m = t % 3600 ~/ 60, x = t % 60;
  if (h > 0) return '$h시간 ${m > 0 ? '$m분' : ''}';
  if (m > 0) return '$m분${x > 0 && m < 10 ? ' $x초' : ''}';
  return '$x초';
}

/// 0:00 형식
String mmss(num sec) {
  final t = sec.ceil() < 0 ? 0 : sec.ceil();
  final m = t ~/ 60, s = t % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
