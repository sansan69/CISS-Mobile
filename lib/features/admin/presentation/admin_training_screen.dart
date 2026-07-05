import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';
import '../../../shared/widgets/status_chip.dart';

class AdminTrainingScreen extends ConsumerStatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  ConsumerState<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends ConsumerState<AdminTrainingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TrainingModuleModel> _modules = const [];
  List<QuestionBankModel> _banks = const [];
  List<Map<String, dynamic>> _assignments = const [];
  List<TrainingModuleModel> _allModules = const [];
  bool _loadingModules = true;
  bool _loadingBanks = true;
  bool _loadingAssignments = true;
  String? _errorModules;
  String? _errorBanks;
  String? _errorAssignments;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchModules(),
      _fetchBanks(),
      _fetchAssignments(),
    ]);
  }

  Future<void> _fetchModules() async {
    try {
      final modules = await ref
          .read(mobileRepositoryProvider)
          .fetchTrainingModules();
      if (!mounted) return;
      setState(() {
        _modules = modules;
        _allModules = modules;
        _loadingModules = false;
        _errorModules = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorModules = e.toString().replaceFirst('Exception: ', '');
        _loadingModules = false;
      });
    }
  }

  Future<void> _fetchBanks() async {
    try {
      final banks = await ref
          .read(mobileRepositoryProvider)
          .fetchQuestionBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _loadingBanks = false;
        _errorBanks = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorBanks = e.toString().replaceFirst('Exception: ', '');
        _loadingBanks = false;
      });
    }
  }

  Future<void> _fetchAssignments() async {
    try {
      final assignments = await ref
          .read(mobileRepositoryProvider)
          .fetchAdminTrainingAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _loadingAssignments = false;
        _errorAssignments = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAssignments = e.toString().replaceFirst('Exception: ', '');
        _loadingAssignments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Training'),
        backgroundColor: tokens.canvas,
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.primary,
          unselectedLabelColor: tokens.inkMuted,
          indicatorColor: tokens.primary,
          tabs: const [
            Tab(text: 'Modules'),
            Tab(text: 'Assignments'),
            Tab(text: 'Question Banks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModulesTab(tokens),
          _buildAssignmentsTab(tokens),
          _buildBanksTab(tokens),
        ],
      ),
    );
  }

  Widget _buildModulesTab(CissThemeTokens tokens) {
    if (_loadingModules) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorModules != null) {
      return Center(
        child: StateBlock(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load modules',
          message: _errorModules!,
          action: FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_modules.isEmpty) {
      return const Center(
        child: StateBlock(
          icon: Icons.school_rounded,
          title: 'No modules',
          message: 'Training modules will appear here.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _modules.length,
        itemBuilder: (context, index) {
          final m = _modules[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: m.isActive ? 'Active' : 'Inactive',
                        tone: m.isActive ? StatusChipTone.success : StatusChipTone.neutral,
                      ),
                    ],
                  ),
                  if (m.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      m.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: tokens.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(icon: Icons.category_rounded, label: m.categoryLabel),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.timer_rounded,
                        label: '${m.durationMinutes} min',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.quiz_rounded,
                        label: 'Pass: ${m.passingScore}%',
                      ),
                    ],
                  ),
                  if (m.contentType != null) ...[
                    const SizedBox(height: 6),
                    _InfoChip(
                      icon: Icons.attach_file_rounded,
                      label: m.contentType!.toUpperCase(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentsTab(CissThemeTokens tokens) {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAssignments != null) {
      return Center(
        child: StateBlock(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load assignments',
          message: _errorAssignments!,
          action: FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_assignments.isEmpty) {
      return const Center(
        child: StateBlock(
          icon: Icons.assignment_rounded,
          title: 'No assignments',
          message: 'Training assignments will appear here.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final a = _assignments[index];
          final employeeName = a['employeeName']?.toString() ?? '-';
          final moduleName = a['moduleName']?.toString() ?? '-';
          final status = a['status']?.toString() ?? 'assigned';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          moduleName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      StatusChip(
                        label: status,
                        tone: status == 'completed'
                            ? StatusChipTone.success
                            : StatusChipTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoChip(icon: Icons.person_rounded, label: employeeName),
                  if (a['district']?.toString().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    _InfoChip(
                      icon: Icons.place_rounded,
                      label: a['district'].toString(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBanksTab(CissThemeTokens tokens) {
    if (_loadingBanks) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorBanks != null) {
      return Center(
        child: StateBlock(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load question banks',
          message: _errorBanks!,
          action: FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_banks.isEmpty) {
      return const Center(
        child: StateBlock(
          icon: Icons.question_answer_rounded,
          title: 'No question banks',
          message: 'Question banks will appear here.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _banks.length,
        itemBuilder: (context, index) {
          final b = _banks[index];
          final moduleTitle = _allModules
              .where((m) => m.id == b.moduleId)
              .map((m) => m.title)
              .firstOrNull ?? b.moduleId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    moduleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.quiz_rounded,
                        label: '${b.questionCount} questions',
                      ),
                      const SizedBox(width: 12),
                      _InfoChip(
                        icon: Icons.shuffle_rounded,
                        label: '${b.questionsPerAttempt}/attempt',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tokens.inkMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: tokens.inkMuted),
        ),
      ],
    );
  }
}
