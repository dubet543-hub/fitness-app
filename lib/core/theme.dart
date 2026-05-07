import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kBg            = Color(0xFF080B10);
const Color kSurface       = Color(0xFF0F1318);
const Color kCard          = Color(0xFF141923);
const Color kCardAlt       = Color(0xFF1A2130);
const Color kAccent        = Color(0xFFFF6B35);
const Color kAccentSoft    = Color(0xFFFF8C5A);
const Color kBorder        = Color(0xFF1F2937);
const Color kBorderBright  = Color(0xFF2D3748);
const Color kTextPrimary   = Color(0xFFF1F5F9);
const Color kTextSecondary = Color(0xFF64748B);
const Color kTextMuted     = Color(0xFF3D4F63);

ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  fontFamily: 'SF Pro Display',
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    secondary: kAccent,
    surface: kSurface,
    onPrimary: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: kTextPrimary),
    titleTextStyle: TextStyle(
      color: kTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kCard,
    labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kAccent, width: 1.5),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccent,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kCardAlt,
    contentTextStyle: const TextStyle(color: kTextPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  useMaterial3: false,
);
