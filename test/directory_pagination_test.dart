import 'dart:async';
import 'package:ciss_mobile/core/network/mobile_repository.dart';
import 'package:ciss_mobile/core/network/providers.dart';
import 'package:ciss_mobile/core/models/guard_profile.dart';
import 'package:ciss_mobile/features/field_officer/presentation/screens/field_officer_guards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/guard_redesign_fixtures.dart';

void main() {
  testWidgets('scroll requests exactly one next page while it is in flight', (
    tester,
  ) async {
    final repo = PageRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mobileRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: FieldOfficerGuardsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.cursors, [null]);
    await tester.drag(find.byType(ListView), const Offset(0, -8000));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -8000));
    await tester.pump();
    expect(repo.cursors, [null, 'next']);
    repo.next.complete(GuardDirectoryPage([guard('g-21')], null));
    await tester.pumpAndSettle();
    expect(repo.cursors, [null, 'next']);
    expect(tester.takeException(), isNull);
  });
}

GuardProfileModel guard(String id) => GuardProfileModel(
  id: id,
  fullName: id,
  employeeId: id,
  clientName: 'Client',
  district: 'Kollam',
  phoneNumber: '',
  status: 'Active',
);

class PageRepo extends NoNetworkRepository {
  final cursors = <String?>[];
  final next = Completer<GuardDirectoryPage>();
  @override
  Future<GuardDirectoryPage> fetchFieldOfficerGuardsPage({
    String? district,
    bool includeInactive = false,
    int? limit,
    String? after,
  }) async {
    cursors.add(after);
    if (after != null) return next.future;
    return GuardDirectoryPage(List.generate(20, (i) => guard('g-$i')), 'next');
  }
}
