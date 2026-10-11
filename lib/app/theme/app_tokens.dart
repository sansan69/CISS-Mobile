import 'package:flutter/material.dart';

class CissThemeTokens extends ThemeExtension<CissThemeTokens> {
  const CissThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
    required this.surfaceAlt,
    required this.surfaceGlass,
    required this.chartGrid,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.accent,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    this.glowEmerald = const Color(0xFF10B981),
    this.glowAmber = const Color(0xFFF59E0B),
    this.glowCyan = const Color(0xFF06B6D4),
    this.goldChampagne = const Color(0xFFD4AF37),
    this.specularBorder = const Color(0x26014C85),
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceStrong;
  final Color surfaceAlt;
  final Color surfaceGlass;
  final Color chartGrid;
  final Color border;
  final Color borderStrong;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color accent;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color glowEmerald;
  final Color glowAmber;
  final Color glowCyan;
  final Color goldChampagne;
  final Color specularBorder;

  factory CissThemeTokens.light() {
    return const CissThemeTokens(
      canvas: Color(0xFFF0F4F8),
      surface: Color(0xFFFFFFFF),
      surfaceMuted: Color(0xFFF5F8FA),
      surfaceStrong: Color(0xFFE1E8ED),
      surfaceAlt: Color(0xFFF8FAFC),
      surfaceGlass: Color(0xD9FFFFFF),
      chartGrid: Color(0xFFE1E8ED),
      border: Color(0xFFD3DFE9),
      borderStrong: Color(0xFFA2B6C7),
      ink: Color(0xFF0F1F31),
      inkMuted: Color(0xFF536A80),
      primary: Color(0xFF014C85),
      primaryStrong: Color(0xFF013A6B),
      primarySoft: Color(0xFFE3EDF7),
      accent: Color(0xFFBD9C55),
      success: Color(0xFF1B825E),
      successSoft: Color(0xFFE3F5EE),
      warning: Color(0xFFB86618),
      warningSoft: Color(0xFFFAF0E3),
      danger: Color(0xFFB52B44),
      dangerSoft: Color(0xFFFCE8EB),
      glowEmerald: Color(0xFF10B981),
      glowAmber: Color(0xFFF59E0B),
      glowCyan: Color(0xFF06B6D4),
      goldChampagne: Color(0xFFD4AF37),
      specularBorder: Color(0x1F014C85),
    );
  }

  factory CissThemeTokens.dark() {
    return const CissThemeTokens(
      canvas: Color(0xFF070B11),
      surface: Color(0xFF0F1622),
      surfaceMuted: Color(0xFF141D2D),
      surfaceStrong: Color(0xFF1A263B),
      surfaceAlt: Color(0xFF141D2D),
      surfaceGlass: Color(0xCC0F1622),
      chartGrid: Color(0xFF1E2E44),
      border: Color(0xFF1E2E44),
      borderStrong: Color(0xFF334B68),
      ink: Color(0xFFEBF1F5),
      inkMuted: Color(0xFF9CB1C9),
      primary: Color(0xFF5C9DD6),
      primaryStrong: Color(0xFF8AC1EB),
      primarySoft: Color(0xFF14243A),
      accent: Color(0xFFD8B96C),
      success: Color(0xFF46C289),
      successSoft: Color(0xFF0E2E20),
      warning: Color(0xFFE89A38),
      warningSoft: Color(0xFF3D270F),
      danger: Color(0xFFE8586E),
      dangerSoft: Color(0xFF3E131A),
      glowEmerald: Color(0xFF10B981),
      glowAmber: Color(0xFFF59E0B),
      glowCyan: Color(0xFF06B6D4),
      goldChampagne: Color(0xFFD8B96C),
      specularBorder: Color(0x33FFFFFF),
    );
  }

  static CissThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<CissThemeTokens>() ??
        CissThemeTokens.light();
  }

  @override
  CissThemeTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceStrong,
    Color? surfaceAlt,
    Color? surfaceGlass,
    Color? chartGrid,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? inkMuted,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? accent,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? glowEmerald,
    Color? glowAmber,
    Color? glowCyan,
    Color? goldChampagne,
    Color? specularBorder,
  }) {
    return CissThemeTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      chartGrid: chartGrid ?? this.chartGrid,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      glowEmerald: glowEmerald ?? this.glowEmerald,
      glowAmber: glowAmber ?? this.glowAmber,
      glowCyan: glowCyan ?? this.glowCyan,
      goldChampagne: goldChampagne ?? this.goldChampagne,
      specularBorder: specularBorder ?? this.specularBorder,
    );
  }

  @override
  CissThemeTokens lerp(ThemeExtension<CissThemeTokens>? other, double t) {
    if (other is! CissThemeTokens) return this;
    return CissThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      glowEmerald: Color.lerp(glowEmerald, other.glowEmerald, t)!,
      glowAmber: Color.lerp(glowAmber, other.glowAmber, t)!,
      glowCyan: Color.lerp(glowCyan, other.glowCyan, t)!,
      goldChampagne: Color.lerp(goldChampagne, other.goldChampagne, t)!,
      specularBorder: Color.lerp(specularBorder, other.specularBorder, t)!,
    );
  }
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double card = 22;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0D060E18), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x05060E18), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x06060E18), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.28, double blur = 18}) => [
    BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, spreadRadius: 1),
  ];
}

/// Pre-defined typography scale for consistent dashboard text.
/// Sizes are tuned for mobile readability and brand coherence.
abstract final class AppTypography {
  /// Hero greeting — 28px, tight leading, strong weight
  static TextStyle display(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall!
      .copyWith(fontWeight: FontWeight.w800, height: 1.15, letterSpacing: 0);

  /// Section titles — 18px, bold
  static TextStyle title(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(fontWeight: FontWeight.w700, height: 1.25, letterSpacing: 0);

  /// Card headings — 16px, semibold
  static TextStyle cardTitle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600, height: 1.3);

  /// Body emphasis — 15px, medium weight
  static TextStyle bodyStrong(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600, height: 1.4);

  /// Standard body — 14px, regular
  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.5);

  /// Small labels — 13px, bold, muted
  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.2,
        height: 1.3,
      );

  /// Metric values — 32px, extra bold
  static TextStyle metric(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 32,
        height: 1.0,
        letterSpacing: 0,
      );

  /// Micro text — 12px, medium. Minimum size for functional secondary text.
  static TextStyle micro(BuildContext context) => Theme.of(context)
      .textTheme
      .labelSmall!
      .copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3);
}
