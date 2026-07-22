import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Fixed dark palette.
// The app intentionally uses this palette regardless of the platform setting.

const Color kBg = Color(0xFF191C22);
const Color kSurface = Color(0xFF13151C);
const Color kCard = Color(0xFF22252D);
const Color kCardAlt = Color(0xFF1C1F27);
const Color kAccent = Color(0xFF00CF74);
const Color kAccentSoft = Color(0xFF00E88A);
const Color kBorder = Color(0xFF2A2E3D);
const Color kBorderBright = Color(0xFF363B52);
const Color kTextPrimary = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFF878CA8);
const Color kTextMuted = Color(0xFF424866);
const Color kExertion = Color(0xFF4AADFF);
const Color kSleep = Color(0xFF9D8AFF);

// ── Semantic status colours ───────────────────────────────────────────────────
/// Bad / at-risk / over-threshold.
const Color kDanger = Color(0xFFEF4444);

/// Caution / monitor / moderate.
const Color kWarn = Color(0xFFF59E0B);

/// Informational series (heart rate, exertion, secondary metrics).
const Color kInfo = Color(0xFF4AADFF);

/// Good / optimal / on-target.
const Color kSuccess = Color(0xFF00CF74);

/// Skill / secondary-load series.
const Color kViolet = Color(0xFF9D8AFF);

/// Running / intensity series.
const Color kOrange = Color(0xFFFF6B35);

/// Posture / technique series.
const Color kSky = Color(0xFF38BDF8);

/// Chart gridlines and axis labels.
const Color kGrid = Color(0xFF5C6280);

/// Foreground for text/icons sitting on top of [kAccent].
const Color kOnAccent = Colors.black;

/// Foreground for controls painted over the live camera preview (record ring,
/// status pills, capture labels). Deliberately NOT theme-dependent: these sit on
/// video, not on [kBg], so they stay light over the viewfinder.
const Color kOnCamera = Colors.white;
const Color kOnCameraSoft = Colors.white70;

/// Scrim behind camera-overlay pills, so light text stays legible on any frame.
const Color kCameraScrim = Colors.black54;

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

// ── Theme builder ─────────────────────────────────────────────────────────────
ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  fontFamily: kBodyFont,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
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
    systemOverlayStyle: SystemUiOverlayStyle.light,
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
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
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

/// Chakra Petch throughout, with the bold-italic headline treatment applied to
/// display/headline/title styles.
TextTheme _themedTextTheme() {
  final base = ThemeData.dark().textTheme;
  return base.copyWith(
    displayLarge: base.displayLarge?.merge(kHeadline),
    displayMedium: base.displayMedium?.merge(kHeadline),
    displaySmall: base.displaySmall?.merge(kHeadline),
    headlineLarge: base.headlineLarge?.merge(kHeadline),
    headlineMedium: base.headlineMedium?.merge(kHeadline),
    headlineSmall: base.headlineSmall?.merge(kHeadline),
    titleLarge: base.titleLarge?.merge(kHeadline),
  );
}
