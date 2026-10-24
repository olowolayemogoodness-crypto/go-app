import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility preferences. Null means "follow the OS setting".
class AppPrefs extends ChangeNotifier {
  bool largeText = false;
  bool? _highContrast;
  bool dyslexiaFont = false;
  bool? _reduceMotion;

  bool highContrastFor(BuildContext c) => _highContrast ?? MediaQuery.of(c).highContrast;
  bool reduceMotionFor(BuildContext c) => _reduceMotion ?? MediaQuery.of(c).disableAnimations;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    largeText = p.getBool('largeText') ?? false;
    dyslexiaFont = p.getBool('dyslexiaFont') ?? false;
    _highContrast = p.getBool('highContrast');
    _reduceMotion = p.getBool('reduceMotion');
    notifyListeners();
  }

  Future<void> _save(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
  }

  void setLargeText(bool v) {
    largeText = v;
    _save('largeText', v);
    notifyListeners();
  }

  void setHighContrast(bool v) {
    _highContrast = v;
    _save('highContrast', v);
    notifyListeners();
  }

  void setDyslexia(bool v) {
    dyslexiaFont = v;
    _save('dyslexiaFont', v);
    notifyListeners();
  }

  void setReduceMotion(bool v) {
    _reduceMotion = v;
    _save('reduceMotion', v);
    notifyListeners();
  }
}

final AppPrefs prefs = AppPrefs();

/// Colour palette. `Pal.of(context)` returns the normal or the high-contrast set.
class Pal {
  final Color ground, card, ink, onSun, muted, primary, onPrimary, primaryShadow;
  final Color sun, sunSoft, orange, mint, mintInk, teal, lilac, lilacInk, peach, line, field;
  const Pal({
    required this.ground,
    required this.card,
    required this.ink,
    required this.onSun,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.primaryShadow,
    required this.sun,
    required this.sunSoft,
    required this.orange,
    required this.mint,
    required this.mintInk,
    required this.teal,
    required this.lilac,
    required this.lilacInk,
    required this.peach,
    required this.line,
    required this.field,
  });

  static const normal = Pal(
    ground: Color(0xFFFFF9F2),
    card: Colors.white,
    ink: Color(0xFF1B1B1F),
    onSun: Color(0xFF1B1B1F),
    muted: Color(0xFF6C6C75),
    primary: Color(0xFF1B1B1F),
    onPrimary: Colors.white,
    primaryShadow: Color(0xFF1B1B1F),
    sun: Color(0xFFFFE1A8),
    sunSoft: Color(0xFFFFF0DA),
    orange: Color(0xFFE08813),
    mint: Color(0xFFE3F4EC),
    mintInk: Color(0xFF0F5C47),
    teal: Color(0xFF1F9D7A),
    lilac: Color(0xFFEEEAFB),
    lilacInk: Color(0xFF2B2170),
    peach: Color(0xFFFFE6D2),
    line: Color(0xFFE9DFD2),
    field: Color(0xFFD9CCBC),
  );

  static const contrast = Pal(
    ground: Colors.black,
    card: Color(0xFF111111),
    ink: Colors.white,
    onSun: Colors.black,
    muted: Color(0xFFE6E6E6),
    primary: Color(0xFFFFEB3B),
    onPrimary: Colors.black,
    primaryShadow: Color(0xFF8A7F00),
    sun: Color(0xFFFFEB3B),
    sunSoft: Color(0xFFFFEB3B),
    orange: Color(0xFF00E5FF),
    mint: Color(0xFF003D33),
    mintInk: Colors.white,
    teal: Color(0xFF00BFA5),
    lilac: Color(0xFF1A1440),
    lilacInk: Colors.white,
    peach: Color(0xFF332200),
    line: Colors.white,
    field: Colors.white,
  );

  static Pal of(BuildContext c) => prefs.highContrastFor(c) ? contrast : normal;
}

ThemeData buildTheme(BuildContext context) {
  final p = Pal.of(context);
  final hc = prefs.highContrastFor(context);
  final reduce = prefs.reduceMotionFor(context);
  final dys = prefs.dyslexiaFont;

  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: hc ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    surface: p.ground,
    onSurface: p.ink,
    secondary: p.orange,
    primaryContainer: p.mint,
    onPrimaryContainer: p.mintInk,
    secondaryContainer: p.sun,
    onSecondaryContainer: p.onSun,
    outline: p.field,
  );

  final raw = Typography.material2021().black.apply(bodyColor: p.ink, displayColor: p.ink);
  final base = dys ? raw.apply(fontFamily: 'Verdana') : GoogleFonts.lexendTextTheme(raw);
  TextStyle? head(TextStyle? s) =>
      dys ? s : GoogleFonts.fredoka(textStyle: s, fontWeight: FontWeight.w700);

  final textTheme = base.copyWith(
    displayLarge: head(base.displayLarge),
    displayMedium: head(base.displayMedium),
    displaySmall: head(base.displaySmall),
    headlineLarge: head(base.headlineLarge),
    headlineMedium: head(base.headlineMedium),
    headlineSmall: head(base.headlineSmall),
    titleLarge: head(base.titleLarge),
  );

  final noTransition = PageTransitionsTheme(builders: {
    for (final t in TargetPlatform.values) t: const _NoTransition(),
  });

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: p.ground,
    textTheme: textTheme,
    pageTransitionsTheme: reduce ? noTransition : null,
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 24),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.field, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.field, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.ink, width: 2.5)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.primary,
      inactiveTrackColor: p.line,
      thumbColor: p.primary,
      trackHeight: 8,
      overlayColor: p.primary.withValues(alpha: 0.2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.ink),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.line),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.primary : p.card),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.ink),
        side: WidgetStatePropertyAll(BorderSide(color: p.ink, width: 2)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(88, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        side: BorderSide(color: p.primary, width: 2),
        minimumSize: const Size(88, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.primary, minimumSize: const Size(88, 48)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), side: BorderSide(color: p.ink, width: 2.5)),
    ),
    focusColor: p.primary.withValues(alpha: 0.3),
  );
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> animation, Animation<double> secondary, Widget child) =>
      child;
}
