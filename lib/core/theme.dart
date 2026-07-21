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

// ── Semantic status colours ───────────────────────────────────────────────────
// Every screen used to hardcode these (Colors.redAccent, Color(0xFFEF4444), …),
// which is why light mode looked wrong: the dark-tuned neons have far too little
// contrast against a near-white background. The light variants below are
// darker//more saturated so they stay legible on kBg.

/// Bad / at-risk / over-threshold.
Color kDanger  = _darkDanger;
/// Caution / monitor / moderate.
Color kWarn    = _darkWarn;
/// Informational series (heart rate, exertion, secondary metrics).
Color kInfo    = _darkInfo;
/// Good / optimal / on-target.
Color kSuccess = _darkSuccess;
/// Skill / secondary-load series.
Color kViolet  = _darkViolet;
/// Running / intensity series.
Color kOrange  = _darkOrange;
/// Posture / technique series.
Color kSky     = _darkSky;
/// Chart gridlines and axis labels.
Color kGrid    = _darkGrid;
/// Foreground for text/icons sitting on top of [kAccent].
Color kOnAccent = Colors.black;

/// Foreground for controls painted over the live camera preview (record ring,
/// status pills, capture labels). Deliberately NOT theme-dependent: these sit on
/// video, not on [kBg], so following the light palette would turn them near-black
/// over a bright viewfinder. Always light.
const Color kOnCamera     = Colors.white;
const Color kOnCameraSoft = Colors.white70;
/// Scrim behind camera-overlay pills, so light text stays legible on any frame.
const Color kCameraScrim  = Colors.black54;

/// True when the light palette is active. Useful for brightness-dependent bits
/// (status bar style, etc.).
bool kIsLight = false;

// ── Typography ────────────────────────────────────────────────────────────────
/// Display font for headlines/titles/large stats (Conthrax-style techno face).
const String kHeadlineFont = 'ChakraPetch';
/// Default font across the entire app.
const String kBodyFont = 'ChakraPetch';

/// The "bold slanted" headline treatment: bold weight + italic slant.
/// Apply on top of a base style, e.g. `TextStyle(fontSize: 24).merge(kHeadline)`.
const TextStyle kHeadline = TextStyle(
  fontFamily: kHeadlineFont,
  fontWeight: FontWeight.w700,
  fontStyle: FontStyle.italic,
);

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
const Color _darkDanger        = Color(0xFFEF4444);
const Color _darkWarn          = Color(0xFFF59E0B);
const Color _darkInfo          = Color(0xFF4AADFF);
const Color _darkSuccess       = Color(0xFF00CF74);
const Color _darkViolet        = Color(0xFF9D8AFF);
const Color _darkOrange        = Color(0xFFFF6B35);
const Color _darkSky           = Color(0xFF38BDF8);
const Color _darkGrid          = Color(0xFF5C6280);

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
// Darker, more saturated than their dark-mode counterparts so they clear ~4.5:1
// against the near-white kBg. The dark neons sit near 1.5:1 there.
const Color _lightDanger        = Color(0xFFC62828);
const Color _lightWarn          = Color(0xFFB45309);
const Color _lightInfo          = Color(0xFF1D6FC0);
const Color _lightSuccess       = Color(0xFF00804A);
const Color _lightViolet        = Color(0xFF6247C7);
const Color _lightOrange        = Color(0xFFC2410C);
const Color _lightSky           = Color(0xFF0B6E9E);
const Color _lightGrid          = Color(0xFFB6BCCA);

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
  kDanger         = light ? _lightDanger         : _darkDanger;
  kWarn           = light ? _lightWarn           : _darkWarn;
  kInfo           = light ? _lightInfo           : _darkInfo;
  kSuccess        = light ? _lightSuccess        : _darkSuccess;
  kViolet         = light ? _lightViolet         : _darkViolet;
  kOrange         = light ? _lightOrange         : _darkOrange;
  kSky            = light ? _lightSky            : _darkSky;
  kGrid           = light ? _lightGrid           : _darkGrid;
  // On the dark accent black reads best; the light accent is dark enough that
  // white is the legible foreground.
  kOnAccent       = light ? Colors.white         : Colors.black;
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
  fontFamily: kBodyFont,
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
      fontFamily: kHeadlineFont,
      fontStyle: FontStyle.italic,
      color: kTextPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
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
  // Chakra Petch is the default throughout the app. Display styles additionally
  // receive the bold italic headline treatment.
  textTheme: _themedTextTheme(),
  useMaterial3: false,
);

/// Base text theme for the active brightness, used to derive [buildAppTheme]'s
/// mixed body/headline typography.
///
/// A function, not a `final` — a top-level final is initialised once on first
/// access and would pin the text colours to whichever brightness happened to be
/// active at app start, so text stayed dark-theme coloured after switching.
TextTheme _baseTextTheme() =>
    (kIsLight ? ThemeData.light() : ThemeData.dark()).textTheme;

/// Chakra Petch throughout, with the bold-italic headline treatment applied to
/// display/headline/title styles.
TextTheme _themedTextTheme() {
  final base = _baseTextTheme();
  return base.copyWith(
    displayLarge:   base.displayLarge?.merge(kHeadline),
    displayMedium:  base.displayMedium?.merge(kHeadline),
    displaySmall:   base.displaySmall?.merge(kHeadline),
    headlineLarge:  base.headlineLarge?.merge(kHeadline),
    headlineMedium: base.headlineMedium?.merge(kHeadline),
    headlineSmall:  base.headlineSmall?.merge(kHeadline),
    titleLarge:     base.titleLarge?.merge(kHeadline),
  );
}
