import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/mobile_dashboard_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/brand_banner.dart';
import '../../../../../shared/widgets/glass_card.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../../../../../shared/widgets/sync_status_badge.dart';
...
            error: (_, _) => const SizedBox.shrink(),

final StateProvider<String?> attendanceSelectedDateProvider =
    StateProvider<String?>((Ref ref) => null);

final FutureProvider<List<FieldOfficerAttendanceEntry>>
    fieldOfficerGuardAttendanceProvider =
    FutureProvider<List<FieldOfficerAttendanceEntry>>((Ref ref) {
  final date = ref.watch(attendanceSelectedDateProvider) ??
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  return ref
      .read(mobileRepositoryProvider)
      .fetchFieldOfficerGuardAttendance(date: date);
});

class FieldOfficerGuardAttendanceScreen extends ConsumerStatefulWidget {
  const FieldOfficerGuardAttendanceScreen({super.key});

  @override
  ConsumerState<FieldOfficerGuardAttendanceScreen> createState() =>
      _FieldOfficerGuardAttendanceScreenState();
}

class _FieldOfficerGuardAttendanceScreenState
    extends ConsumerState<FieldOfficerGuardAttendanceScreen> {
  DateTime? _selectedDate;
  String? _selectedSiteId;
  static final DateFormat _displayFmt = DateFormat('dd/MM/yyyy');
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  void _refresh() {
    ref
      ..invalidate(fieldOfficerDashboardProvider)
      ..invalidate(fieldOfficerGuardAttendanceProvider);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      ref.read(attendanceSelectedDateProvider.notifier).state =
          _apiFmt.format(picked);
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    ref.read(attendanceSelectedDateProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(fieldOfficerDashboardProvider);
    final entriesAsync = ref.watch(fieldOfficerGuardAttendanceProvider);
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          BrandBanner(
            title: 'Attendance',
            subtitle: _selectedDate != null
                ? _displayFmt.format(_selectedDate!)
                : 'Live Duty Feed',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SyncStatusBadge(),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _selectedDate != null
                          ? _displayFmt.format(_selectedDate!)
                          : 'Select Date',
                      style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_selectedDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearDate,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: tokens.surface,
                    ),
                  ),
                ],
              ],
            ),
          ),

          dashboardAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (dashboard) {
              final sites = dashboard.attendanceSites;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sites.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text(
                        'SITE SUMMARIES',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sites.length,
                        itemBuilder: (_, i) => _SiteFilterChip(
                          site: sites[i],
                          isSelected: _selectedSiteId == sites[i].siteId,
                          onTap: () => setState(() {
                            _selectedSiteId = _selectedSiteId == sites[i].siteId
                                ? null
                                : sites[i].siteId;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'INDIVIDUAL RECORDS',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),

                  entriesAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: StateBlock(
                        icon: Icons.error_outline_rounded,
                        title: 'Sync issue',
                        message: err.toString(),
                      ),
                    ),
                    data: (entries) {
                      final filtered = _selectedSiteId == null
                          ? entries
                          : entries
                              .where((e) =>
                                  e.siteName.trim().toLowerCase() ==
                                  sites
                                      .firstWhere((s) => s.siteId == _selectedSiteId)
                                      .siteName
                                      .trim()
                                      .toLowerCase())
                              .toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: StateBlock(
                            icon: Icons.person_off_outlined,
                            title: 'No records found',
                            message: 'No guard attendance recorded for this filter.',
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: filtered.map((e) => _LiveGuardRow(e)).toList(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SiteFilterChip extends StatelessWidget {
  const _SiteFilterChip({
    required this.site,
    required this.isSelected,
    required this.onTap,
  });

  final FieldOfficerAttendanceSite site;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final accent = isSelected ? tokens.primary : tokens.border;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? tokens.primarySoft : tokens.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: tokens.primary.withValues(alpha: 0.1), blurRadius: 10)] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                site.siteName,
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? tokens.primaryStrong : tokens.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.people_alt_outlined, size: 12, color: tokens.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${site.onDutyNow}/${site.checkedInToday}',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? tokens.primaryStrong : tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveGuardRow extends StatelessWidget {
  const _LiveGuardRow(this.entry);
  final FieldOfficerAttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final bool isPresent = entry.status == 'Present' || entry.status == 'In';
    final glow = isPresent ? tokens.success : tokens.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        accentColor: glow,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: glow.withValues(alpha: 0.1),
                  backgroundImage: (entry.photoUrl != null && entry.photoUrl!.isNotEmpty)
                      ? NetworkImage(entry.photoUrl!)
                      : null,
                  child: (entry.photoUrl == null || entry.photoUrl!.isEmpty)
                      ? Text(
                          entry.guardName.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: glow,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: glow,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.guardName,
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  Text(
                    '${entry.siteName} · ${entry.dutyPointName}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.checkIn ?? '--:--',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.primary,
                  ),
                ),
                Text(
                  entry.status.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: glow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
