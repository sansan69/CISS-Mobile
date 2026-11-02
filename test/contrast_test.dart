import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/app/theme/app_tokens.dart';

/// WCAG 2.1 relative-luminance contrast ratio for two opaque colours.
double _contrast(Color foreground, Color background) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  double luminance(Color color) {
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  final first = luminance(foreground);
  final second = luminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('light theme text contrast (WCAG AA, small text)', () {
    final tokens = CissThemeTokens.light();

    test('status colours on their soft backgrounds reach 4.5:1', () {
      expect(_contrast(tokens.warning, tokens.warningSoft), greaterThanOrEqualTo(4.5));
      expect(_contrast(tokens.success, tokens.successSoft), greaterThanOrEqualTo(4.5));
      expect(_contrast(tokens.danger, tokens.dangerSoft), greaterThanOrEqualTo(4.5));
    });

    test('accent text/icons on surface reach 4.5:1', () {
      expect(
        _contrast(tokens.accent, tokens.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('primary and muted text remain readable', () {
      expect(_contrast(tokens.primary, tokens.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(tokens.ink, tokens.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(tokens.inkMuted, tokens.surface), greaterThanOrEqualTo(4.5));
    });
  });
}
