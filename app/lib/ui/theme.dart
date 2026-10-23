/// 색·글꼴 — 웹 index.html :root 변수와 같은 값.
library;

import 'package:flutter/material.dart';

class KdColors {
  static const bg = Color(0xFF141A29); // --bg
  static const deep = Color(0xFF0A0D16); // body 배경
  static const panel = Color(0xFF1F2740); // --panel
  static const panel2 = Color(0xFF29334F); // --panel2
  static const line = Color(0xFF37436A); // --line
  static const fg = Color(0xFFEEF1F8); // --fg
  static const muted = Color(0xFFA9B3D1); // --muted (아이폰 가독성: 조금 밝게)
  static const gold = Color(0xFFFFC94A); // --gold
  static const goldInk = Color(0xFF3A2A00); // --gold-ink
  static const bad = Color(0xFFFF6B7D); // --bad
  static const good = Color(0xFF7BE08F); // --good
  static const brass = Color(0xFF6B5420); // 탭·창 금테
  static const pageTop = Color(0xFF18203A); // .page 머리
}

/// 글꼴 이름 (pubspec.yaml fonts)
class KdFonts {
  /// 제목·이름·버튼 (웹 --f-display, Hahmlet)
  static const display = 'Hahmlet';

  /// 본문 (웹 --f-body, IBM Plex Sans KR)
  static const body = 'PlexKR';
}

/// 자주 쓰는 글자 모양
class KdText {
  static TextStyle display(double size, {Color color = KdColors.fg, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: KdFonts.display, fontSize: size, fontWeight: weight, color: color, height: 1.25);

  static TextStyle body(double size, {Color color = KdColors.fg, FontWeight weight = FontWeight.w400, double height = 1.4}) =>
      TextStyle(fontFamily: KdFonts.body, fontSize: size, fontWeight: weight, color: color, height: height);

  /// 회색 보조 글자 최소 크기 (웹과 같게: 11.5~12 → 12.5, 그보다 작으면 +1)
  static double mutedSize(double size) => size >= 12.5 ? size : size >= 11.5 ? 12.5 : size + 1;

  /// 숫자가 흔들리지 않게 (웹 font-variant-numeric:tabular-nums)
  static TextStyle figure(double size, {Color color = KdColors.fg, FontWeight weight = FontWeight.w700}) =>
      body(size, color: color, weight: weight).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

ThemeData kdTheme() => ThemeData(
      brightness: Brightness.dark,
      fontFamily: KdFonts.body,
      scaffoldBackgroundColor: KdColors.deep,
      colorScheme: ColorScheme.fromSeed(seedColor: KdColors.gold, brightness: Brightness.dark, surface: KdColors.panel),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
