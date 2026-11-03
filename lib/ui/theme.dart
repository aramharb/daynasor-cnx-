import 'package:flutter/material.dart';

import '../game/ctx.dart' show kUiFont;

/// The two visual themes: plain monochrome (offline) and colorful (online).
class Pal {
  const Pal({
    required this.classic,
    required this.panel,
    required this.text,
    required this.muted,
    required this.accent,
    required this.radius,
    required this.border,
    required this.buttonBg,
    required this.buttonBorder,
    required this.scrim,
    this.family,
    this.familyFallback,
  });

  final bool classic;
  final Color panel, text, muted, accent, border, buttonBg, buttonBorder, scrim;
  final double radius;
  final String? family;
  final List<String>? familyFallback;

  static const Pal colorful = Pal(
    classic: false,
    panel: Color(0xD1140C2D),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFC9C2E8),
    accent: Color(0xFFFFD54F),
    radius: 18,
    border: Color(0x1FFFFFFF),
    buttonBg: Color(0x1FFFFFFF),
    buttonBorder: Color(0x2EFFFFFF),
    scrim: Color(0x590A051E),
    family: kUiFont,
  );

  static const Pal mono = Pal(
    classic: true,
    panel: Color(0xF0F7F7F7),
    text: Color(0xFF535353),
    muted: Color(0xFF7A7A7A),
    accent: Color(0xFF535353),
    radius: 2,
    border: Color(0xFF535353),
    buttonBg: Color(0x00000000),
    buttonBorder: Color(0xFF535353),
    scrim: Color(0x59F7F7F7),
    family: 'monospace',
    familyFallback: ['Courier', 'Courier New'],
  );

  static Pal of(bool colorful) => colorful ? Pal.colorful : Pal.mono;

  TextStyle style({double size = 14, FontWeight weight = FontWeight.w700, Color? color, double? height, double? letterSpacing}) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        fontFamily: family,
        fontFamilyFallback: familyFallback,
        height: height,
        letterSpacing: letterSpacing,
        decoration: TextDecoration.none,
      );

  static const List<Color> rainbow = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFE040FB),
  ];
}
