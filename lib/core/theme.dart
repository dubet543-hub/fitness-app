import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Runtime palette ───────────────────────────────────────────────────────────
// These tokens are MUTABLE so the whole app can switch between light and dark.
// Screens read them directly; [applyBrightness] swaps the values and a full
// rebuild (driven by [appThemeMode]) repaints everything.

Color kBg            = _darkBg;
Color kSurface       = _darkSurface;
Color kCard          = _darkCard;
Color kCardAlt       = _darkCardAlt;
Color kAccent        = _darkAccent;
Color kAccentSoft    = _darkAccentSoft;
Color kBorder        = _darkBorder;
Color kBorderBright  = _darkBorderBright;
Color kTextPrimary   = _darkTextPrimary;
Color kTextSecondary = _darkTextSecondary;
Color kTextMuted     = _darkTextMuted;
Color kExertion        = _darkExertion;
Color kSleep         = _darkSleep;

/// True when the light palette is active. Useful for brightness-dependent bits
/// (status bar style, etc.).
bool kIsLight = false;

// ── Dark palette ──────────────────────────────────────────────────────────────
const Color _darkBg            = Color(0xFF191C22);
const Color _darkSurface       = Color(0xFF13151C);
const Color _darkCard          = Color(0xFF22252D);
const Color _darkCardAlt       = Color(0xFF1C1F27);
const Color _darkAccent        = Color(0xFF00CF74);
const Color _darkAccentSoft    = Color(0xFF00E88A);
const Color _darkBorder        = Color(0xFF2A2E3D);
const Color _darkBorderBright  = Color(0xFF363B52);
const Color _darkTextPrimary   = Color(0xFFFFFFFF);
const Color _darkTextSecondary = Color(0xFF878CA8);
const Color _darkTextMuted     = Color(0xFF424866);
const Color _darkExertion        = Color(0xFF4AADFF);
const Color _darkSleep         = Color(0xFF9D8AFF);

// ── Light palette ─────────────────────────────────────────────────────────────
const Color _lightBg            = Color(0xFFF4F5F8);
const Color _lightSurface       = Color(0xFFFFFFFF);
const Color _lightCard          = Color(0xFFFFFFFF);
const Color _lightCardAlt       = Color(0xFFEFF1F5);
const Color _lightAccent        = Color(0xFF00A357);
const Color _lightAccentSoft    = Color(0xFF00B86B);
const Color _lightBorder        = Color(0xFFE3E6EC);
const Color _lightBorderBright  = Color(0xFFCAD0DA);
const Color _lightTextPrimary   = Color(0xFF15171C);
const Color _lightTextSecondary = Color(0xFF5B6173);
const Color _lightTextMuted     = Color(0xFF9CA2B2);
const Color _lightExertion        = Color(0xFF2F8FE0);
const Color _lightSleep         = Color(0xFF7A63E0);

/// Swap the live palette to match [b]. Call before building the app theme.
void applyBrightness(Brightness b) {
  final light = b == Brightness.light;
  kIsLight        = light;
  kBg             = light ? _lightBg            : _darkBg;
  kSurface        = light ? _lightSurface       : _darkSurface;
  kCard           = light ? _lightCard          : _darkCard;
  kCardAlt        = light ? _lightCardAlt        : _darkCardAlt;
  kAccent         = light ? _lightAccent         : _darkAccent;
  kAccentSoft     = light ? _lightAccentSoft     : _darkAccentSoft;
  kBorder         = light ? _lightBorder         : _darkBorder;
  kBorderBright   = light ? _lightBorderBright   : _darkBorderBright;
  kTextPrimary    = light ? _lightTextPrimary    : _darkTextPrimary;
  kTextSecondary  = light ? _lightTextSecondary  : _darkTextSecondary;
  kTextMuted      = light ? _lightTextMuted      : _darkTextMuted;
  kExertion         = light ? _lightExertion         : _darkExertion;
  kSleep          = light ? _lightSleep          : _darkSleep;
}

// ── Theme-mode controller (persisted) ─────────────────────────────────────────

/// The user's chosen theme mode. The app rebuilds when this changes.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

const String _kThemeModePref = 'app_theme_mode';

/// Load the saved theme mode (call once before runApp).
Future<void> loadAppThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  appThemeMode.value = _decodeMode(prefs.getString(_kThemeModePref));
}

/// Persist and apply a new theme mode.
Future<void> setAppThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kThemeModePref, _encodeMode(mode));
}

ThemeMode _decodeMode(String? s) => s == 'light'
    ? ThemeMode.light
    : s == 'system'
        ? ThemeMode.system
        : ThemeMode.dark;

String _encodeMode(ThemeMode m) => m == ThemeMode.light
    ? 'light'
    : m == ThemeMode.system
        ? 'system'
        : 'dark';

/// Resolve [mode] to a concrete brightness, using the platform for `system`.
Brightness effectiveBrightness(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }
}

// ── Theme builder ─────────────────────────────────────────────────────────────
// Reads the live palette, so call [applyBrightness] for the desired brightness
// before invoking this.

ThemeData buildAppTheme() => ThemeData(
  brightness: kIsLight ? Brightness.light : Brightness.dark,
  scaffoldBackgroundColor: kBg,
  fontFamily: 'SF Pro Display',
  colorScheme: ColorScheme(
    brightness: kIsLight ? Brightness.light : Brightness.dark,
    primary: kAccent,
    onPrimary: Colors.black,
    secondary: kAccent,
    onSecondary: Colors.black,
    surface: kSurface,
    onSurface: kTextPrimary,
    error: const Color(0xFFEF4444),
    onError: Colors.white,
  ),
  appBarTheme: AppBarTheme(
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
    systemOverlayStyle: kIsLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kCard,
    labelStyle: TextStyle(color: kTextSecondary, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kAccent, width: 1.5),
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
    contentTextStyle: TextStyle(color: kTextPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  dividerTheme: DividerThemeData(color: kBorder, thickness: 1),
  useMaterial3: false,
);
