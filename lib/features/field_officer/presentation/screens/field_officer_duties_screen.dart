import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/haptics.dart';
import 'field_officer_attendance_screen.dart';
import 'field_officer_work_orders_screen.dart';

final StateProvider<int> fieldOfficerDutiesSubTabProvider = StateProvider<int>(
  (ref) => 0,
);

class FieldOfficerDutiesScreen extends ConsumerStatefulWidget {
  const FieldOfficerDutiesScreen({super.key, this.initialSubTab = 0});

  final int initialSubTab;

  @override
  ConsumerState<FieldOfficerDutiesScreen> createState() =>
      _FieldOfficerDutiesScreenState();
}

class _FieldOfficerDutiesScreenState
    extends ConsumerState<FieldOfficerDutiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(fieldOfficerDutiesSubTabProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initial.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(fieldOfficerDutiesSubTabProvider.notifier).state =
            _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final currentSubTab = ref.watch(fieldOfficerDutiesSubTabProvider);

    if (_tabController.index != currentSubTab &&
        currentSubTab >= 0 &&
        currentSubTab < 2) {
      _tabController.animateTo(currentSubTab);
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(largeText ? 64 : 48),
        child: Container(
          color: tokens.surface,
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              isScrollable: largeText,
              tabAlignment: largeText ? TabAlignment.start : TabAlignment.fill,
              indicatorColor: tokens.primary,
              indicatorWeight: 3,
              labelColor: tokens.primary,
              unselectedLabelColor: tokens.inkMuted,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              onTap: (_) => Haptics.selection(),
              tabs:
                  largeText
                      ? const [
                        Tab(text: 'Work Orders'),
                        Tab(text: 'Attendance'),
                      ]
                      : const [
                        Tab(
                          icon: Icon(
                            Icons.assignment_turned_in_rounded,
                            size: 18,
                          ),
                          text: 'Work Orders',
                        ),
                        Tab(
                          icon: Icon(Icons.fact_check_rounded, size: 18),
                          text: 'Attendance',
                        ),
                      ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FieldOfficerWorkOrdersScreen(),
          FieldOfficerGuardAttendanceScreen(),
        ],
      ),
    );
  }
}
