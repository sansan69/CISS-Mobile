import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  List<ClientModel> _clients = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clients =
          await ref.read(mobileRepositoryProvider).fetchAdminClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: tokens.canvas,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateBlock(
                    icon: Icons.cloud_off_rounded,
                    title: 'Error',
                    message: _error!,
                    action: FilledButton.tonal(
                      onPressed: _fetchClients,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchClients,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader('CLIENTS', tokens),
                      const SizedBox(height: 8),
                      ..._clients.map(
                        (client) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: tokens.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials(client.name, fallback: ''),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink,
                                        ),
                                      ),
                                      if (client.stateCode != null)
                                        Text(
                                          client.stateCode!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: tokens.inkMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  client.portalEnabled
                                      ? Icons.language_rounded
                                      : Icons.language_outlined,
                                  size: 18,
                                  color: client.portalEnabled
                                      ? tokens.success
                                      : tokens.inkMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_clients.isEmpty)
                        const StateBlock(
                          icon: Icons.business_rounded,
                          title: 'No clients',
                          message: 'Client organizations will appear here.',
                        ),
                      const SizedBox(height: 20),
                      _sectionHeader('QUICK LINKS', tokens),
                      const SizedBox(height: 8),
                      GlassCard(
                        child: Column(
                          children: [
                            _LinkTile(
                              icon: Icons.open_in_browser_rounded,
                              title: 'Open Web Settings',
                              subtitle: 'Full settings panel in browser',
                              color: tokens.primary,
                              onTap: () async {
                                final rawBase = ref
                                    .read(mobileRepositoryProvider)
                                    .apiClient
                                    .dio
                                    .options
                                    .baseUrl;
                                final base = rawBase.endsWith('/')
                                    ? rawBase.substring(
                                        0, rawBase.length - 1)
                                    : rawBase;
                                await launchUrl(
                                  Uri.parse('$base/settings'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

Widget _sectionHeader(String text, CissThemeTokens tokens) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: tokens.inkMuted,
      letterSpacing: 2,
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
      onTap: onTap,
    );
  }
}
