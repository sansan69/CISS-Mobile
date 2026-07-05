import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/models/training_models.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/state_block.dart';

class AdminEvaluationsScreen extends ConsumerStatefulWidget {
  const AdminEvaluationsScreen({super.key});

  @override
  ConsumerState<AdminEvaluationsScreen> createState() =>
      _AdminEvaluationsScreenState();
}

class _AdminEvaluationsScreenState extends ConsumerState<AdminEvaluationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EvaluationModel> _evaluations = const [];
  List<LeaderboardEntryModel> _leaderboard = const [];
  bool _loadingEvals = true;
  bool _loadingLeaderboard = true;
  String? _errorEvals;
  String? _errorLeaderboard;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchEvaluations(), _fetchLeaderboard()]);
  }

  Future<void> _fetchEvaluations() async {
    try {
      final evals = await ref
          .read(mobileRepositoryProvider)
          .fetchAdminEvaluations();
      if (!mounted) return;
      setState(() {
        _evaluations = evals;
        _loadingEvals = false;
        _errorEvals = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorEvals = e.toString().replaceFirst('Exception: ', '');
        _loadingEvals = false;
      });
    }
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final scores = await ref
          .read(mobileRepositoryProvider)
          .fetchLeaderboard();
      if (!mounted) return;
      setState(() {
        _leaderboard = scores;
        _loadingLeaderboard = false;
        _errorLeaderboard = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorLeaderboard = e.toString().replaceFirst('Exception: ', '');
        _loadingLeaderboard = false;
      });
    }
  }

  Future<void> _showCreateEvaluation(CissThemeTokens tokens) async {
    final repo = ref.read(mobileRepositoryProvider);
    List<EmployeeModel> guards = [];
    String? selectedGuardId;
    double punctuality = 5;
    double uniform = 5;
    double behavior = 5;
    double skill = 5;
    double clientFeedback = 5;
    final commentsCtrl = TextEditingController();
    bool loadingGuards = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (loadingGuards) {
              ref.read(mobileRepositoryProvider).fetchAdminEmployees().then((g) {
                setDialogState(() {
                  guards = g;
                  loadingGuards = false;
                });
              }).catchError((_) {
                setDialogState(() => loadingGuards = false);
              });
            }

            return AlertDialog(
              title: const Text('Create Evaluation'),
              content: SingleChildScrollView(
                child: loadingGuards
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedGuardId,
                            decoration: const InputDecoration(
                              labelText: 'Guard',
                              border: OutlineInputBorder(),
                            ),
                            items: guards.map((g) {
                              return DropdownMenuItem(
                                value: g.id.isNotEmpty ? g.id : g.employeeId,
                                child: Text(g.name),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedGuardId = v),
                          ),
                          const SizedBox(height: 16),
                          _sliderRow('Punctuality', punctuality, tokens,
                              (v) => setDialogState(() => punctuality = v)),
                          _sliderRow('Uniform', uniform, tokens,
                              (v) => setDialogState(() => uniform = v)),
                          _sliderRow('Behavior', behavior, tokens,
                              (v) => setDialogState(() => behavior = v)),
                          _sliderRow('Skill', skill, tokens,
                              (v) => setDialogState(() => skill = v)),
                          _sliderRow('Client Feedback', clientFeedback, tokens,
                              (v) => setDialogState(() => clientFeedback = v)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: commentsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Comments',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedGuardId == null) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedGuardId != null) {
      try {
        await repo.createEvaluation({
          'employeeId': selectedGuardId,
          'criteria': {
            'punctuality': punctuality,
            'uniformCompliance': uniform,
            'behaviorProfessionalism': behavior,
            'skillCompetency': skill,
            'clientFeedback': clientFeedback,
          },
          'comments': commentsCtrl.text.trim(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation created')),
        );
        await _fetchAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: tokens.danger,
          ),
        );
      }
    }
    commentsCtrl.dispose();
  }

  Widget _sliderRow(String label, double value, CissThemeTokens tokens,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.inkMuted),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 10,
              label: value.toStringAsFixed(0),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Evaluations'),
        backgroundColor: tokens.canvas,
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.primary,
          unselectedLabelColor: tokens.inkMuted,
          indicatorColor: tokens.primary,
          tabs: const [
            Tab(text: 'Evaluations'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEvaluation(tokens),
        child: const Icon(Icons.add_rounded),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEvaluationsTab(tokens),
          _buildLeaderboardTab(tokens),
        ],
      ),
    );
  }

  Widget _buildEvaluationsTab(CissThemeTokens tokens) {
    if (_loadingEvals) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorEvals != null) {
      return Center(
        child: StateBlock(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load evaluations',
          message: _errorEvals!,
          action: FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_evaluations.isEmpty) {
      return const Center(
        child: StateBlock(
          icon: Icons.assessment_rounded,
          title: 'No evaluations',
          message: 'Performance evaluations will appear here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _evaluations.length,
        itemBuilder: (context, index) {
          final e = _evaluations[index];
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
                          e.employeeName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      _ScoreBadge(score: e.totalScore, max: 50, tokens: tokens),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.period,
                    style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  _CriteriaBar(
                    label: 'Punctuality',
                    value: e.punctualityScore,
                    max: 10,
                    tokens: tokens,
                  ),
                  _CriteriaBar(
                    label: 'Uniform',
                    value: e.uniformScore,
                    max: 10,
                    tokens: tokens,
                  ),
                  _CriteriaBar(
                    label: 'Behavior',
                    value: e.behaviorScore,
                    max: 10,
                    tokens: tokens,
                  ),
                  _CriteriaBar(
                    label: 'Skills',
                    value: e.skillScore,
                    max: 10,
                    tokens: tokens,
                  ),
                  _CriteriaBar(
                    label: 'Client Feedback',
                    value: e.clientFeedbackScore,
                    max: 10,
                    tokens: tokens,
                  ),
                  if (e.comments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      e.comments,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: tokens.inkMuted,
                      ),
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

  Widget _buildLeaderboardTab(CissThemeTokens tokens) {
    if (_loadingLeaderboard) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorLeaderboard != null) {
      return Center(
        child: StateBlock(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load leaderboard',
          message: _errorLeaderboard!,
          action: FilledButton.tonal(
            onPressed: _fetchAll,
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (_leaderboard.isEmpty) {
      return const Center(
        child: StateBlock(
          icon: Icons.leaderboard_rounded,
          title: 'No leaderboard data',
          message: 'Scores will appear once evaluations are recorded.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          final entry = _leaderboard[index];
          final isTop = entry.rank <= 3;
          final rankColor = entry.rank == 1
              ? const Color(0xFFFFD700)
              : entry.rank == 2
                  ? const Color(0xFFC0C0C0)
                  : entry.rank == 3
                      ? const Color(0xFFCD7F32)
                      : tokens.inkMuted;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              accentColor: isTop ? rankColor : null,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTop
                          ? rankColor.withValues(alpha: 0.15)
                          : tokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isTop ? rankColor : tokens.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.employeeName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                        Text(
                          '${entry.currentMonthScore.toStringAsFixed(1)} pts',
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.badges.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: entry.badges
                          .map(
                            (b) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.emoji_events_rounded,
                                size: 20,
                                color: rankColor,
                              ),
                            ),
                          )
                          .toList(),
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.max,
    required this.tokens,
  });

  final double score;
  final int max;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final pct = (score / max * 100).clamp(0, 100).round();
    final color = pct >= 80
        ? tokens.success
        : pct >= 60
            ? tokens.warning
            : tokens.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CriteriaBar extends StatelessWidget {
  const _CriteriaBar({
    required this.label,
    required this.value,
    required this.max,
    required this.tokens,
  });

  final String label;
  final double value;
  final int max;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / max).clamp(0.0, 1.0);
    final color = fraction >= 0.8
        ? tokens.success
        : fraction >= 0.5
            ? tokens.warning
            : tokens.danger;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: tokens.inkMuted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: tokens.surfaceMuted,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
