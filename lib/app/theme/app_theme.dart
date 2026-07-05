import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

ThemeData buildCissTheme(Brightness brightness) {
  final tokens =
      brightness == Brightness.dark
          ? CissThemeTokens.dark()
          : CissThemeTokens.light();

  final isDark = brightness == Brightness.dark;

  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B4F82),
    brightness: brightness,
    primary: tokens.primary,
    secondary: tokens.accent,
    surface: tokens.surface,
    onSurface: tokens.ink,
  ).copyWith(
    primaryContainer: tokens.primarySoft,
    onPrimaryContainer: tokens.primaryStrong,
    secondaryContainer: tokens.warningSoft,
    onSecondaryContainer: tokens.warning,
    surfaceContainerHighest: tokens.surfaceStrong,
    outline: tokens.border,
    outlineVariant: tokens.border,
    error: tokens.danger,
    onError: Colors.white,
    errorContainer: tokens.dangerSoft,
    onErrorContainer: tokens.danger,
  );

  final baseTextTheme = const TextTheme().apply(
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );

  final headerStyle = TextStyle(fontWeight: FontWeight.w700, color: tokens.ink);

  // Transparent status bar + nav bar for edge-to-edge
  final systemOverlayStyle =
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          )
          : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.canvas,
    extensions: <ThemeExtension<dynamic>>[tokens],

    // AppBar — M3 small top app bar (64dp)
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.canvas,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: headerStyle.copyWith(fontSize: 20),
      surfaceTintColor: tokens.primary,
      systemOverlayStyle: systemOverlayStyle,
      iconTheme: IconThemeData(color: tokens.ink, size: 24),
      actionsIconTheme: IconThemeData(color: tokens.ink, size: 24),
    ),

    // Card — M3 filled card (elevation via surface tint)
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 1,
      surfaceTintColor: tokens.primary,
      shadowColor: tokens.ink.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: tokens.border),
      ),
      margin: EdgeInsets.zero,
    ),

    // Typography — proper M3 type scale wiring
    textTheme: baseTextTheme.copyWith(
      headlineMedium: headerStyle.copyWith(fontSize: 28, letterSpacing: 0),
      headlineSmall: headerStyle.copyWith(fontSize: 24),
      titleLarge: headerStyle.copyWith(fontSize: 22),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: tokens.ink,
        height: 1.5,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: tokens.inkMuted,
        height: 1.4,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: tokens.inkMuted,
        height: 1.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),

    // Input — M3 filled style: depth via background, not border
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfaceStrong,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: tokens.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: tokens.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: tokens.danger, width: 2),
      ),
      labelStyle: TextStyle(color: tokens.inkMuted),
      hintStyle: TextStyle(color: tokens.inkMuted.withValues(alpha: 0.7)),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) return tokens.primary;
        return tokens.inkMuted;
      }),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return TextStyle(color: tokens.primary, fontWeight: FontWeight.w500);
        }
        return TextStyle(color: tokens.inkMuted);
      }),
    ),

    // FilledButton — M3 primary action (replaces ElevatedButton for CTAs)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primaryStrong,
        foregroundColor: Colors.white,
        disabledBackgroundColor: tokens.border,
        disabledForegroundColor: tokens.inkMuted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: headerStyle.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),

    // ElevatedButton — kept for backward compatibility, M3 tonal elevated style
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? tokens.surfaceStrong : tokens.primaryStrong,
        foregroundColor: isDark ? tokens.primary : Colors.white,
        surfaceTintColor: tokens.primary,
        disabledBackgroundColor: tokens.border,
        disabledForegroundColor: tokens.inkMuted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: headerStyle.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),

    // OutlinedButton — secondary/destructive actions
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.primaryStrong,
        side: BorderSide(color: tokens.borderStrong),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.primaryStrong,
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // NavigationBar — M3 bottom nav (replaces custom BrandedNavigationBar)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: tokens.primarySoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: tokens.primaryStrong, size: 22);
        }
        return IconThemeData(color: tokens.inkMuted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tokens.primaryStrong,
            letterSpacing: 0,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: tokens.inkMuted,
          letterSpacing: 0,
        );
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 72,
    ),

    // ListTile — used on More/settings screens
    listTileTheme: ListTileThemeData(
      iconColor: tokens.primaryStrong,
      textColor: tokens.ink,
      subtitleTextStyle: TextStyle(color: tokens.inkMuted, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      tileColor: tokens.surface,
      minLeadingWidth: 24,
    ),

    // SnackBar — floating M3 style
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? tokens.surfaceStrong : tokens.ink,
      contentTextStyle: TextStyle(
        color: isDark ? tokens.ink : tokens.canvas,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      elevation: 6,
      showCloseIcon: true,
      closeIconColor:
          isDark ? tokens.inkMuted : tokens.canvas.withValues(alpha: 0.7),
    ),

    // Dialog — M3 rounded dialog
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: tokens.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: headerStyle.copyWith(fontSize: 20, color: tokens.ink),
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
        color: tokens.inkMuted,
        height: 1.5,
      ),
    ),

    // BottomSheet — M3 modal bottom sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: tokens.surface,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      dragHandleColor: tokens.border,
      showDragHandle: true,
    ),

    // Switch — M3 adaptive toggle
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return tokens.inkMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return tokens.primary;
        return tokens.surfaceStrong;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return tokens.border;
      }),
    ),

    // Chip — status/filter chips
    chipTheme: ChipThemeData(
      backgroundColor: tokens.surfaceMuted,
      selectedColor: tokens.primarySoft,
      disabledColor: tokens.surfaceMuted,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: tokens.ink,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide(color: tokens.border),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: tokens.border,
      thickness: 1,
      space: 0,
    ),

    // Progress indicators
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.primary,
      linearTrackColor: tokens.primarySoft,
      circularTrackColor: tokens.primarySoft,
      refreshBackgroundColor: tokens.surface,
    ),

    // IconButton — standard M3 touch target
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: tokens.ink,
        highlightColor: tokens.primarySoft,
      ),
    ),
  );
}
