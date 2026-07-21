import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/theme.dart';

// The light palette exists so status colours stay legible on a near-white
// background. Pin that with real contrast maths rather than eyeballing hexes.

double _lum(Color c) {
  double ch(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * ch((c.r * 255).roundToDouble()) +
      0.7152 * ch((c.g * 255).roundToDouble()) +
      0.0722 * ch((c.b * 255).roundToDouble());
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => applyBrightness(Brightness.dark));

  test('light status colours are legible on the light background', () {
    applyBrightness(Brightness.light);
    final checks = <String, Color>{
      'danger': kDanger,
      'warn': kWarn,
      'info': kInfo,
      'success': kSuccess,
      'violet': kViolet,
      'orange': kOrange,
      'sky': kSky,
      'accent': kAccent,
      'textPrimary': kTextPrimary,
      'textSecondary': kTextSecondary,
    };
    checks.forEach((name, c) {
      // 3:1 is the WCAG floor for large text and graphical objects, which is
      // what these are used for (chart series, stat numerals, badges).
      expect(contrast(c, kBg), greaterThanOrEqualTo(3.0),
          reason: '$name has too little contrast on the light background');
    });
  });

  test('dark status colours are legible on the dark background', () {
    applyBrightness(Brightness.dark);
    final checks = <String, Color>{
      'danger': kDanger,
      'warn': kWarn,
      'info': kInfo,
      'success': kSuccess,
      'violet': kViolet,
      'orange': kOrange,
      'sky': kSky,
    };
    checks.forEach((name, c) {
      expect(contrast(c, kBg), greaterThanOrEqualTo(3.0),
          reason: '$name has too little contrast on the dark background');
    });
  });

  test('the two palettes are genuinely different', () {
    applyBrightness(Brightness.dark);
    final dark = [kDanger, kWarn, kInfo, kSuccess, kViolet, kOrange, kSky, kGrid];
    applyBrightness(Brightness.light);
    final light = [kDanger, kWarn, kInfo, kSuccess, kViolet, kOrange, kSky, kGrid];
    for (var i = 0; i < dark.length; i++) {
      expect(light[i], isNot(dark[i]), reason: 'token $i never changes');
    }
  });

  test('accent foreground flips so it stays readable on the accent', () {
    applyBrightness(Brightness.dark);
    expect(contrast(kOnAccent, kAccent), greaterThanOrEqualTo(3.0));
    applyBrightness(Brightness.light);
    expect(contrast(kOnAccent, kAccent), greaterThanOrEqualTo(3.0));
  });
}
