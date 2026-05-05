import 'package:flutter/material.dart';

class CissThemeTokens extends ThemeExtension<CissThemeTokens> {
  const CissThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceStrong,
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
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceStrong;
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

  factory CissThemeTokens.light() {
    return const CissThemeTokens(
      canvas: Color(0xFFF3F6F8),
      surface: Color(0xFFFFFFFF),
      surfaceMuted: Color(0xFFF8FAFC),
      surfaceStrong: Color(0xFFE7EEF4),
      border: Color(0xFFD9E3EA),
      borderStrong: Color(0xFFB8C9D6),
      ink: Color(0xFF102A43),
      inkMuted: Color(0xFF5B7186),
      primary: Color(0xFF0B4F82),
      primaryStrong: Color(0xFF083B61),
      primarySoft: Color(0xFFDCEBF6),
      accent: Color(0xFFE7B04B),
      success: Color(0xFF1F8F63),
      successSoft: Color(0xFFDDF4EA),
      warning: Color(0xFFC17A11),
      warningSoft: Color(0xFFF8E7C6),
      danger: Color(0xFFB5475C),
      dangerSoft: Color(0xFFF7DDE2),
    );
  }

  factory CissThemeTokens.dark() {
    return const CissThemeTokens(
      canvas: Color(0xFF0B1220),
      surface: Color(0xFF101B2D),
      surfaceMuted: Color(0xFF152235),
      surfaceStrong: Color(0xFF1A2A41),
      border: Color(0xFF26384F),
      borderStrong: Color(0xFF3A5573),
      ink: Color(0xFFF4F7FB),
      inkMuted: Color(0xFFB3C2D3),
      primary: Color(0xFF7CB8F0),
      primaryStrong: Color(0xFFB8D9FA),
      primarySoft: Color(0xFF17324F),
      accent: Color(0xFFF0C36E),
      success: Color(0xFF59C48A),
      successSoft: Color(0xFF123526),
      warning: Color(0xFFF0B85B),
      warningSoft: Color(0xFF3E2E12),
      danger: Color(0xFFF07D93),
      dangerSoft: Color(0xFF3C1D28),
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
  }) {
    return CissThemeTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
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
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x140C2A43),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
