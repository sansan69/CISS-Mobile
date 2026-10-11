import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../core/sync/providers.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/metric_card.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/surface_card.dart';
import '../../../../../shared/widgets/time_counter_chip.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
import '../../../../../core/fcm/notification_service.dart';
import '../../../shared/notification_inbox_screen.dart';
import '../../guard_tab_provider.dart';
import 'guard_incidents_screen.dart';
import 'guard_patrol_screen.dart';
import 'guard_payslips_screen.dart';
import 'guard_leave_screen.dart';
import 'guard_training_leaderboard_screen.dart';

final FutureProvider<GuardDashboardSnapshot> guardDashboardProvider =
    FutureProvider<GuardDashboardSnapshot>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchGuardDashboard();
    });

class GuardDashboardScreen extends ConsumerWidget {
  const GuardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(guardDashboardProvider);

    return snapshot.when(
      loading:
          () => const Scaffold(
            body: Column(
              children: <Widget>[
                BrandBanner(title: 'Guard', subtitle: 'Preparing dashboard'),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
      error:
          (Object error, _) => Scaffold(
            body: Column(
              children: <Widget>[
                const BrandBanner(title: 'Guard', subtitle: 'Dashboard'),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: StateBlock(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load dashboard',
                        message: error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        action: FilledButton.tonal(
                          onPressed:
                              () => ref.invalidate(guardDashboardProvider),
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      data: (GuardDashboardSnapshot data) => _DashboardBody(data: data),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final GuardDashboardSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final displayName =
        data.employeeName.isNotEmpty ? data.employeeName : data.employeeId;
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final hasShift = data.nextShiftSiteName != null;
    final isOnDuty =
        data.nextShiftLabel != null &&
        data.nextShiftLabel!.toLowerCase().contains('duty');

    final initials =
        displayName.isNotEmpty
            ? displayName
                .split(' ')
                .where((p) => p.isNotEmpty)
                .map((p) => p[0])
                .take(2)
                .join()
                .toUpperCase()
            : data.employeeId.isNotEmpty
            ? data.employeeId.substring(0, 2).toUpperCase()
            : 'GU';

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(guardDashboardProvider),
          child: ListView(
            padding: EdgeInsets.only(
              bottom:
                  AppSpacing.xxl + MediaQuery.of(context).padding.bottom + 140,
            ),
            children: <Widget>[
              ModernHero(
                eyebrow: greeting,
                title: displayName,
                subtitle:
                    hasShift
                        ? '${data.nextShiftSiteName} • ${data.nextShiftLabel ?? 'Shift'}'
                        : '${data.clientName.isEmpty ? 'CISS Workforce' : data.clientName} • ${data.district.isEmpty ? 'No district' : data.district}',
                avatarText: initials,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SyncStatusBadge(
                      onTap: () => ref.read(syncServiceProvider).processQueue(),
                    ),
                    const _NotificationButton(),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Attendance this month — 3-column grid, no horizontal scroll
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: MetricCard(
                        label: 'Present',
                        value: '${data.presentDays}',
                        color: tokens.success,
                        backgroundColor: tokens.successSoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricCard(
                        label: 'Absent',
                        value: '${data.absentDays}',
                        color: tokens.danger,
                        backgroundColor: tokens.dangerSoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: MetricCard(
                        label: 'Working',
                        value: '${data.workingDays}',
                        color: tokens.primary,
                        backgroundColor: tokens.primarySoft,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  'This month',
                  style: AppTypography.micro(
                    context,
                  ).copyWith(color: tokens.inkMuted),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 2026 Bento Grid: Current Post & Tactile QR Clock In/Out Tile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Current Post Bento Card
                    Expanded(
                      flex: 5,
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: hasShift
                            ? () => ref.read(guardTabIndexProvider.notifier).state = 1
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnDuty ? tokens.glowEmerald : tokens.glowAmber,
                                    boxShadow: AppShadows.glow(
                                      isOnDuty ? tokens.glowEmerald : tokens.glowAmber,
                                      blur: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isOnDuty ? 'CURRENT POST' : 'NEXT ASSIGNMENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: tokens.inkMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hasShift ? data.nextShiftSiteName! : 'Attendance Post',
                              style: AppTypography.cardTitle(context).copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasShift && data.nextShiftDate != null
                                  ? '${data.nextShiftDate} • ${data.nextShiftLabel ?? 'Shift'}'
                                  : 'No shift assigned',
                              style: AppTypography.micro(context).copyWith(
                                color: tokens.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Tactile QR Clock In/Out Tile
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          boxShadow: AppShadows.glow(
                            isOnDuty ? tokens.glowCyan : tokens.glowEmerald,
                            opacity: 0.22,
                            blur: 16,
                          ),
                        ),
                        child: Material(
                          color: tokens.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: BorderSide(
                              color: isOnDuty ? tokens.glowCyan : tokens.glowEmerald,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            onTap: () {
                              ref.read(guardTabIndexProvider.notifier).state = 1;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: isOnDuty ? tokens.glowCyan : tokens.glowEmerald,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isOnDuty ? 'SCAN QR / CLOCK OUT' : 'SCAN QR / CLOCK IN',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: isOnDuty ? tokens.glowCyan : tokens.glowEmerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Night Patrol Checkpoints Bento Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuardPatrolScreen(),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.route_rounded,
                          color: tokens.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Night Patrol Checkpoints',
                              style: AppTypography.cardTitle(context),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Next perimeter check due soon',
                              style: AppTypography.micro(context).copyWith(
                                color: tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TimeCounterChip(
                        targetTime: DateTime.now().add(const Duration(minutes: 14)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Eval Score + Payslip Card
              if (data.latestEvalScore != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: ModernCard(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.stars_rounded,
                            color: tokens.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Latest Evaluation',
                                style: AppTypography.cardTitle(context),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.latestEvalPeriod ?? 'Current period',
                                style: AppTypography.micro(
                                  context,
                                ).copyWith(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.warningSoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${data.latestEvalScore!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (data.leaveBalance != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: ModernCard(
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.event_available_rounded,
                            color: tokens.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Leave Balance',
                                style: AppTypography.cardTitle(context),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${data.leaveBalance!.balance} remaining · ${data.leaveBalance!.entitled} entitled · ${data.leaveBalance!.taken} taken',
                                style: AppTypography.micro(
                                  context,
                                ).copyWith(color: tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: tokens.inkMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GuardLeaveScreen(),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Quick Actions
              // Quick Actions — 2026 Bento Action Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Quick Actions', style: AppTypography.title(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            radius: AppRadius.pill,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardLeaveScreen(),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: tokens.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LEAVE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            radius: AppRadius.pill,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardIncidentsScreen(),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: tokens.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'INCIDENTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            radius: AppRadius.pill,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardTrainingLeaderboardScreen(),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  color: tokens.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'TRAINING',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SurfaceCard(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            radius: AppRadius.pill,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GuardPayslipsScreen(),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  color: tokens.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PAYSLIPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: tokens.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Training Leaderboard ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: ModernCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GuardTrainingLeaderboardScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          color: tokens.accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Training Leaderboard',
                              style: AppTypography.cardTitle(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'See how you rank against guards in your district',
                              style: AppTypography.micro(
                                context,
                              ).copyWith(color: tokens.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: tokens.inkMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Recent Activity
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Recent Activity',
                          style: AppTypography.title(context),
                        ),
                        TextButton(
                          onPressed:
                              () =>
                                  ref
                                      .read(guardTabIndexProvider.notifier)
                                      .state = 1,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.recentAttendance.isEmpty)
                      ModernCard(
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.history_toggle_off_rounded,
                              color: tokens.inkMuted,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Your check-in and check-out activity will appear here.',
                                style: AppTypography.body(
                                  context,
                                ).copyWith(color: tokens.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...data.recentAttendance.take(5).map((item) {
                        final isIn = item.status == 'In';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ModernCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            onTap:
                                () =>
                                    ref
                                        .read(guardTabIndexProvider.notifier)
                                        .state = 1,
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  isIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  color: isIn ? tokens.success : tokens.warning,
                                  size: 22,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        item.siteName,
                                        style: AppTypography.bodyStrong(
                                          context,
                                        ),
                                      ),
                                      Text(
                                        '${item.dateLabel} • ${item.time}',
                                        style: AppTypography.micro(
                                          context,
                                        ).copyWith(color: tokens.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isIn
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  color: tokens.inkMuted,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(guardTabIndexProvider.notifier).state = 1,
        backgroundColor: isOnDuty ? tokens.primary : tokens.success,
        foregroundColor: tokens.surface,
        icon: Icon(isOnDuty ? Icons.logout_rounded : Icons.login_rounded),
        label: Text(isOnDuty ? 'Check Out' : 'Check In'),
      ),
    );
  }
}

class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final unreadAsync = ref.watch(NotificationService.unreadCountProvider);

    return unreadAsync.when(
      data:
          (int count) =>
              count > 0
                  ? Stack(
                    children: <Widget>[
                      IconButton(
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationInboxScreen(),
                              ),
                            ),
                        icon: Icon(
                          Icons.notifications_rounded,
                          color: tokens.surface,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: tokens.danger,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.primaryStrong,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : IconButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationInboxScreen(),
                          ),
                        ),
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: tokens.surface,
                      size: 22,
                    ),
                  ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
