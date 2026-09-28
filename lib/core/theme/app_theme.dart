import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour tokens of the "lab report" style shared with NetSpeedDiag and
/// the browser extensions: ink on paper, rules instead of shadows.
@immutable
class LabPalette extends ThemeExtension<LabPalette> {
  final Color bg;
  final Color paper;
  final Color paper2;
  final Color rule;
  final Color ruleSoft;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color fill;
  final Color onFill;
  final Color ok;
  final Color warn;
  final Color crit;

  const LabPalette({
    required this.bg,
    required this.paper,
    required this.paper2,
    required this.rule,
    required this.ruleSoft,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.fill,
    required this.onFill,
    required this.ok,
    required this.warn,
    required this.crit,
  });

  static const dark = LabPalette(
    bg: Color(0xFF15121A),
    paper: Color(0xFF1C1823),
    paper2: Color(0xFF231E2B),
    rule: Color(0xFF3D3548),
    ruleSoft: Color(0xFF2D2736),
    ink: Color(0xFFEFE7DA),
    muted: Color(0xFFA59CAE),
    accent: Color(0xFFC4A8FF),
    fill: Color(0xFF4A2391),
    onFill: Color(0xFFF3ECDF),
    ok: Color(0xFF9CC794),
    warn: Color(0xFFE6B45E),
    crit: Color(0xFFF08A78),
  );

  static const light = LabPalette(
    bg: Color(0xFFF7F3EA),
    paper: Color(0xFFFBF8F1),
    paper2: Color(0xFFF0E9DC),
    rule: Color(0xFFCFC6B6),
    ruleSoft: Color(0xFFE2DACB),
    ink: Color(0xFF1C1917),
    muted: Color(0xFF736B64),
    accent: Color(0xFF5B21B6),
    fill: Color(0xFF3F1D7A),
    onFill: Color(0xFFF7F3EA),
    ok: Color(0xFF3F7A3A),
    warn: Color(0xFF9A5B06),
    crit: Color(0xFFB3261E),
  );

  static LabPalette of(BuildContext context) =>
      Theme.of(context).extension<LabPalette>()!;

  @override
  LabPalette copyWith() => this;

  @override
  LabPalette lerp(LabPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LabPalette(
      bg: mix(bg, other.bg),
      paper: mix(paper, other.paper),
      paper2: mix(paper2, other.paper2),
      rule: mix(rule, other.rule),
      ruleSoft: mix(ruleSoft, other.ruleSoft),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      fill: mix(fill, other.fill),
      onFill: mix(onFill, other.onFill),
      ok: mix(ok, other.ok),
      warn: mix(warn, other.warn),
      crit: mix(crit, other.crit),
    );
  }
}

/// Bundled families: Fraunces for headings, Plex Sans for text and Plex
/// Mono for numbers. Bundled so the first launch needs no network.
class AppFonts {
  static const serif = 'Fraunces';
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}

/// Text styles the Material text theme has no slot for
class LabText {
  /// Uppercase, letter-spaced label that opens a section
  static TextStyle sectionLabel(LabPalette p) => TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: p.muted,
      );

  /// Italic serif line under a heading, also used for status
  static TextStyle statusLine(LabPalette p) => TextStyle(
        fontFamily: AppFonts.serif,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.35,
        color: p.muted,
      );

  static TextStyle mono(LabPalette p, {double size = 14, Color? color}) =>
      TextStyle(
        fontFamily: AppFonts.mono,
        fontWeight: FontWeight.w500,
        fontSize: size,
        color: color ?? p.ink,
      );
}

/// App theme configuration
class AppTheme {
  static ThemeData get lightTheme => _build(LabPalette.light, Brightness.light);

  static ThemeData get darkTheme => _build(LabPalette.dark, Brightness.dark);

  static const _square = RoundedRectangleBorder();

  static ThemeData _build(LabPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Accent carries highlights (links, focus, progress); the deeper fill
    // is reserved for the one primary action and reaches widgets through
    // primaryContainer.
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: isDark ? p.bg : p.onFill,
      primaryContainer: p.fill,
      onPrimaryContainer: p.onFill,
      secondary: p.accent,
      onSecondary: isDark ? p.bg : p.onFill,
      secondaryContainer: p.paper2,
      onSecondaryContainer: p.ink,
      tertiary: p.ok,
      onTertiary: p.bg,
      error: p.crit,
      onError: isDark ? p.bg : p.onFill,
      errorContainer: p.paper2,
      onErrorContainer: p.crit,
      surface: p.paper,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      surfaceDim: p.bg,
      surfaceBright: p.paper2,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.paper,
      surfaceContainer: p.paper,
      surfaceContainerHigh: p.paper2,
      surfaceContainerHighest: p.paper2,
      outline: p.rule,
      outlineVariant: p.ruleSoft,
      shadow: Colors.transparent,
      scrim: Colors.black54,
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
      inversePrimary: p.fill,
      surfaceTint: Colors.transparent,
    );

    final base = (isDark ? ThemeData.dark() : ThemeData.light())
        .textTheme
        .apply(fontFamily: AppFonts.sans, bodyColor: p.ink, displayColor: p.ink);

    TextStyle? serif(TextStyle? s, double size) => s?.copyWith(
          fontFamily: AppFonts.serif,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.15,
          letterSpacing: 0,
        );

    final textTheme = base.copyWith(
      displayLarge: serif(base.displayLarge, 48),
      displayMedium: serif(base.displayMedium, 40),
      displaySmall: serif(base.displaySmall, 34),
      headlineLarge: serif(base.headlineLarge, 30),
      headlineMedium: serif(base.headlineMedium, 26),
      headlineSmall: serif(base.headlineSmall, 22),
      titleLarge: serif(base.titleLarge, 20),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: p.muted),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500),
    );

    final buttonText = textTheme.labelLarge?.copyWith(fontSize: 14);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

    // Filled primary: fill ink, fading when disabled as in the reference
    final filledStyle = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(_square),
      padding: const WidgetStatePropertyAll(buttonPadding),
      textStyle: WidgetStatePropertyAll(buttonText),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? p.fill.withValues(alpha: 0.4)
            : p.fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? p.onFill.withValues(alpha: 0.6)
            : p.onFill,
      ),
      overlayColor: WidgetStatePropertyAll(p.accent.withValues(alpha: 0.2)),
    );

    final systemOverlay = (isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [p],
      fontFamily: AppFonts.sans,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.ruleSoft,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        iconTheme: IconThemeData(color: p.ink),
        systemOverlayStyle: systemOverlay,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
        // The masthead rule
        shape: Border(bottom: BorderSide(color: p.ink, width: 2)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.rule)),
      ),
      dividerTheme: DividerThemeData(color: p.ruleSoft, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: p.ink),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          foregroundColor: p.ink,
          textStyle: buttonText,
          shape: _square,
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.pressed)
                  ? p.accent
                  : p.rule,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: buttonText,
          shape: _square,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: _square),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.fill,
        foregroundColor: p.onFill,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: _square,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: p.muted),
        labelStyle: TextStyle(color: p.muted),
        floatingLabelStyle: TextStyle(color: p.accent),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        errorStyle: TextStyle(color: p.crit),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.crit),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: p.crit, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        textColor: p.ink,
        shape: _square,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.muted,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.accent, width: 2),
        ),
        dividerColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.ruleSoft,
        linearMinHeight: 2,
        refreshBackgroundColor: p.paper,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.rule)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paper,
        modalBackgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: p.rule,
        dragHandleSize: const Size(36, 3),
        shape: Border(top: BorderSide(color: p.ink, width: 2)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.paper2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.ink),
        actionTextColor: p.accent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.rule)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.ink),
        textStyle: textTheme.bodySmall?.copyWith(color: p.bg),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: p.rule),
        shape: _square,
        labelStyle: LabText.mono(p, size: 12, color: p.muted),
      ),
    );
  }
}
