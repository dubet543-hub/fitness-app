import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kBg            = Color(0xFF191C22);
const Color kSurface       = Color(0xFF13151C);
const Color kCard          = Color(0xFF22252D);
const Color kCardAlt       = Color(0xFF1C1F27);
const Color kAccent        = Color(0xFF00CF74);
const Color kAccentSoft    = Color(0xFF00E88A);
const Color kBorder        = Color(0xFF2A2E3D);
const Color kBorderBright  = Color(0xFF363B52);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF878CA8);
const Color kTextMuted     = Color(0xFF424866);

// Metric accent colors
const Color kStrain        = Color(0xFF4AADFF);
const Color kSleep         = Color(0xFF9D8AFF);

ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  fontFamily: 'SF Pro Display',
  colorScheme: const ColorScheme.dark(
    primary: kAccent,
    secondary: kAccent,
    surface: kSurface,
    onPrimary: Colors.black,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBg,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: kTextPrimary),
    titleTextStyle: TextStyle(
      color: kTextPrimary,
      fontSize: 17,
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
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kAccent, width: 1.5),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccent,
      foregroundColor: Colors.black,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kCard,
    contentTextStyle: const TextStyle(color: kTextPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  dividerTheme: const DividerThemeData(color: kBorder, thickness: 1),
  useMaterial3: false,
);
