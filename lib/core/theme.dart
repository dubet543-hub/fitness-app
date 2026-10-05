import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Fixed dark palette — minimal and neutral.
// The app intentionally uses this palette regardless of the platform setting.
// One accent (brand green) for the primary action, the active tab and key
// progress; everything else is greyscale so the data carries the colour.

const Color kBg = Color(0xFF0B0B0D);
const Color kSurface = Color(0xFF111114);
const Color kCard = Color(0xFF17171B);
const Color kCardAlt = Color(0xFF141418);
const Color kAccent = Color(0xFF00CF74);
const Color kAccentSoft = Color(0xFF00E88A);
const Color kBorder = Color(0xFF232328);
const Color kBorderBright = Color(0xFF2E2E35);
const Color kTextPrimary = Color(0xFFF5F5F7);
const Color kTextSecondary = Color(0xFF9A9AA3);
const Color kTextMuted = Color(0xFF66666F);
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
const Color kGrid = Color(0xFF55555E);

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
// The platform's own UI face — SF Pro on iOS, Roboto on Android — so the app
// reads as native on both. Null means "use the platform default".

/// Display font for headlines/titles/large stats.
const String? kHeadlineFont = null;

/// Default font across the entire app.
const String? kBodyFont = null;

/// Headline treatment: semibold, upright, slightly tightened.
/// Apply on top of a base style, e.g. `TextStyle(fontSize: 24).merge(kHeadline)`.
const TextStyle kHeadline = TextStyle(
  fontWeight: FontWeight.w700,
  letterSpacing: -0.4,
);

// ── Spacing & shape ───────────────────────────────────────────────────────────
const double kRadius = 16;      // cards, sheets
const double kRadiusSm = 12;    // inputs, tiles, buttons
const double kGutter = 20;      // screen side padding

// ── Theme builder ─────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: kAccent,
    onPrimary: Colors.black,
    secondary: kAccent,
    onSecondary: Colors.black,
    surface: kSurface,
    onSurface: kTextPrimary,
    error: kDanger,
    onError: Colors.white,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0);

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    canvasColor: kBg,
    fontFamily: kBodyFont,
    colorScheme: scheme,
    useMaterial3: false,
    splashFactory: InkRipple.splashFactory,
    splashColor: kTextPrimary.withValues(alpha: 0.06),
    highlightColor: kTextPrimary.withValues(alpha: 0.04),
    dividerColor: kBorder,
    // Native transitions: iOS slide with edge-swipe back; Android predictive back.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: kTextPrimary, size: 22),
      actionsIconTheme: IconThemeData(color: kTextPrimary, size: 22),
      titleTextStyle: TextStyle(
        fontFamily: kHeadlineFont,
        color: kTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
      labelStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: kTextMuted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: const BorderSide(color: kTextSecondary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: const BorderSide(color: kDanger),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.black,
        disabledBackgroundColor: kCard,
        disabledForegroundColor: kTextMuted,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(64, 52),
        shape: shape,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextPrimary,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: kBorderBright),
        shape: shape,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kTextPrimary,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: kTextPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kTextPrimary,
      contentTextStyle: const TextStyle(color: kBg, fontSize: 14, fontWeight: FontWeight.w500),
      actionTextColor: kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      modalBackgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kBorder),
      ),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3),
      contentTextStyle: const TextStyle(fontSize: 15, color: kTextSecondary, height: 1.45),
    ),
    cardTheme: CardThemeData(
      color: kCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: kBorder),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: kTextSecondary,
      textColor: kTextPrimary,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kTextPrimary,
      unselectedLabelColor: kTextMuted,
      indicatorColor: kTextPrimary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: kBorder,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : kTextSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : kBorderBright),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: const BorderSide(color: kTextMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? kAccent : kTextMuted),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: kAccent,
      inactiveTrackColor: kBorderBright,
      thumbColor: Colors.white,
      overlayColor: kAccent.withValues(alpha: 0.12),
      trackHeight: 4,
      valueIndicatorColor: kTextPrimary,
      valueIndicatorTextStyle: const TextStyle(color: kBg, fontWeight: FontWeight.w600),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccent,
      linearTrackColor: kBorder,
      circularTrackColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kCard,
      selectedColor: kTextPrimary,
      disabledColor: kCard,
      labelStyle: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: kBg, fontSize: 14, fontWeight: FontWeight.w600),
      side: const BorderSide(color: kBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      checkmarkColor: kBg,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm), side: const BorderSide(color: kBorder)),
      textStyle: const TextStyle(color: kTextPrimary, fontSize: 15),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: kTextPrimary, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: kBg, fontSize: 12, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, thickness: 0.6, space: 0.6),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: kSurface,
      headerForegroundColor: kTextPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: kAccent,
      scaffoldBackgroundColor: kBg,
      barBackgroundColor: kSurface,
    ),
    textTheme: _themedTextTheme(),
  );
}

/// Platform text styles with headlines tightened and upright.
TextTheme _themedTextTheme() {
  final base = ThemeData.dark().textTheme.apply(bodyColor: kTextPrimary, displayColor: kTextPrimary);
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

/// Light haptic for selection changes (tabs, segmented controls, chips).
void hapticSelect() => HapticFeedback.selectionClick();

/// Slightly firmer haptic for confirming a primary action.
void hapticConfirm() => HapticFeedback.lightImpact();
