import 'package:ciss_mobile/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'registered route ${reduced ? 'fades only with reduced motion' : 'slides at an intermediate frame'}',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(routerProvider);
        addTearDown(router.dispose);
        final route = router.configuration.routes.whereType<GoRoute>().first;
        final state = GoRouterState(
          router.configuration,
          uri: Uri.parse('/'),
          matchedLocation: '/',
          fullPath: '/',
          pathParameters: const {},
          pageKey: const ValueKey('motion'),
        );
        late CustomTransitionPage<void> page;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Builder(
                builder: (context) {
                  page =
                      route.pageBuilder!(context, state)
                          as CustomTransitionPage<void>;
                  return page.transitionsBuilder(
                    context,
                    const AlwaysStoppedAnimation(0.2),
                    const AlwaysStoppedAnimation(0),
                    const SizedBox(width: 100, height: 100),
                  );
                },
              ),
            ),
          ),
        );
        final fade = tester.widget<FadeTransition>(
          find.byType(FadeTransition).last,
        );
        expect(fade.opacity.value, greaterThan(0));
        expect(fade.opacity.value, lessThan(1));
        final slide = find.byType(SlideTransition);
        if (reduced) {
          expect(slide, findsNothing);
        } else {
          final position = tester.widget<SlideTransition>(slide).position.value;
          expect(position.dx, greaterThan(0));
          expect(position.dx, lessThan(0.06));
          expect(position.dy, 0);
        }
        expect(page.transitionDuration, const Duration(milliseconds: 240));
        expect(
          page.reverseTransitionDuration,
          const Duration(milliseconds: 180),
        );
      },
    );
  }
}
