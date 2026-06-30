import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/haptics.dart';
import '../../../core/region/region_service.dart';
import '../../../shared/widgets/auth/login_background.dart';

class RegionSelectorScreen extends ConsumerStatefulWidget {
  const RegionSelectorScreen({super.key});

  @override
  ConsumerState<RegionSelectorScreen> createState() => _RegionSelectorScreenState();
}

class _RegionSelectorScreenState extends ConsumerState<RegionSelectorScreen> {
  String? _selectedCode;
  bool _loading = false;
  String? _error;

  Future<void> _selectRegion(RegionInfo region) async {
    Haptics.medium();
    setState(() {
      _selectedCode = region.code;
      _loading = true;
      _error = null;
    });

    try {
      // Fetch full config and initialize Firebase
      await ref.read(regionServiceProvider).initRegionalFirebase(region);
      await ref.read(regionServiceProvider).saveRegionPreference(region.code);

      if (!mounted) return;
      Haptics.heavy();
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to initialize region: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final regionsAsync = ref.watch(availableRegionsProvider);

    return Scaffold(
      body: SecurityGridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tokens.primary, tokens.primaryStrong],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select Your State',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the state where your duty is based.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: tokens.inkMuted),
                ),
                const SizedBox(height: 32),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: TextStyle(color: tokens.danger, fontSize: 13)),
                    ),
                  ),

                // Region list
                Expanded(
                  child: regionsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 48, color: tokens.inkMuted),
                          const SizedBox(height: 12),
                          Text('Could not load regions', style: TextStyle(color: tokens.inkMuted)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref.invalidate(availableRegionsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (regions) {
                      if (regions.isEmpty) {
                        return Center(
                          child: Text('No regions available', style: TextStyle(color: tokens.inkMuted)),
                        );
                      }
                      return ListView.separated(
                        itemCount: regions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final region = regions[index];
                          final isSelected = _selectedCode == region.code;
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.primary
                                    : tokens.border.withValues(alpha: 0.3),
                              ),
                              color: isSelected
                                  ? tokens.primarySoft
                                  : tokens.surface,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _loading ? null : () => _selectRegion(region),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: tokens.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            region.code,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: tokens.primary,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              region.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              region.apiUrl.replaceAll('https://', ''),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: tokens.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_loading && isSelected)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: tokens.inkMuted,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const Spacer(flex: 1),

                Text(
                  'You can change your state later in Settings.',
                  style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
