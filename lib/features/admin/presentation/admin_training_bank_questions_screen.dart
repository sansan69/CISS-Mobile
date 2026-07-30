import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/haptics.dart';
import '../../../core/network/providers.dart';
import '../../../shared/widgets/modern_card.dart';
import '../../../shared/widgets/modern_hero.dart';
import '../../../shared/widgets/state_block.dart';


class AdminTrainingBankQuestionsScreen extends ConsumerStatefulWidget {
  const AdminTrainingBankQuestionsScreen({
    super.key,
    required this.bank,
  });

  final QuestionBankModel bank;

  @override
  ConsumerState<AdminTrainingBankQuestionsScreen> createState() =>
      _AdminTrainingBankQuestionsScreenState();
}

class _AdminTrainingBankQuestionsScreenState
    extends ConsumerState<AdminTrainingBankQuestionsScreen> {
  List<Map<String, dynamic>> _questions = const [];
  bool _loading = true;
  String? _error;

  // Add/edit question state
  bool _showAddForm = false;
  final _qCtrl = TextEditingController();
  final _a0Ctrl = TextEditingController();
  final _a1Ctrl = TextEditingController();
  final _a2Ctrl = TextEditingController();
  final _a3Ctrl = TextEditingController();
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _a0Ctrl.dispose();
    _a1Ctrl.dispose();
    _a2Ctrl.dispose();
    _a3Ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .getJson('/api/admin/training/banks/${widget.bank.id}/questions');
      if (!mounted) return;
      final list =
          data['questions'] as List<dynamic>? ?? const <dynamic>[];
      setState(() {
        _questions =
            list.whereType<Map<String, dynamic>>().toList();
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

  Future<void> _addQuestion() async {
    if (_qCtrl.text.trim().isEmpty) return;
    Haptics.light();
    try {
      final payload = <String, dynamic>{
        'questionText': _qCtrl.text.trim(),
        'options': [
          _a0Ctrl.text.trim(),
          _a1Ctrl.text.trim(),
          _a2Ctrl.text.trim(),
          _a3Ctrl.text.trim(),
        ],
        'correctIndex': _correctIndex,
      };
      await ref
          .read(mobileRepositoryProvider)
          .postGeneric(
              '/api/admin/training/banks/${widget.bank.id}/questions',
              payload);
      setState(() {
        _showAddForm = false;
        _qCtrl.clear();
        _a0Ctrl.clear();
        _a1Ctrl.clear();
        _a2Ctrl.clear();
        _a3Ctrl.clear();
        _correctIndex = 0;
      });
      await _fetchQuestions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: StateBlock(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load questions',
                      message: _error!,
                      action: FilledButton.tonal(
                        onPressed: _fetchQuestions,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: <Widget>[
                      ModernHero(
                        eyebrow: 'Training',
                        title: widget.bank.title,
                        subtitle:
                            '${_questions.length} questions · ${widget.bank.questionsPerAttempt} per attempt',
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ModernCard(
                          child: Row(
                            children: <Widget>[
                              _stat(
                                  tokens, 'Total', '${_questions.length}',
                                  tokens.primary),
                              _stat(
                                  tokens,
                                  'Per Attempt',
                                  '${widget.bank.questionsPerAttempt}',
                                  tokens.accent),
                              _stat(
                                  tokens,
                                  'Time',
                                  widget.bank.timeLimitMinutes > 0
                                      ? '${widget.bank.timeLimitMinutes}min'
                                      : 'Unlimited',
                                  tokens.success),
                              _stat(
                                  tokens,
                                  'Attempts',
                                  widget.bank.maxAttempts > 0
                                      ? '${widget.bank.maxAttempts}'
                                      : '∞',
                                  tokens.warning),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: <Widget>[
                            Text(
                              'QUESTIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: tokens.inkMuted,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _showAddForm = !_showAddForm),
                              icon: Icon(
                                _showAddForm
                                    ? Icons.close_rounded
                                    : Icons.add_rounded,
                                size: 18,
                              ),
                              label: Text(
                                  _showAddForm ? 'Cancel' : 'Add Question'),
                            ),
                          ],
                        ),
                      ),
                      if (_showAddForm) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ModernCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                TextField(
                                  controller: _qCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Question',
                                    hintText: 'Enter the question text',
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 10),
                                for (int i = 0; i < 4; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: <Widget>[
                                        Radio<int>(
                                          value: i,
                                          groupValue: _correctIndex,
                                          onChanged: (v) => setState(
                                              () => _correctIndex = v ?? 0),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: [
                                              _a0Ctrl,
                                              _a1Ctrl,
                                              _a2Ctrl,
                                              _a3Ctrl
                                            ][i],
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Option ${i + 1}${i == _correctIndex ? ' (correct)' : ''}',
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _addQuestion,
                                    icon: const Icon(Icons.add_rounded,
                                        size: 18),
                                    label: const Text('ADD QUESTION'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_questions.isEmpty)
                        StateBlock(
                          icon: Icons.quiz_outlined,
                          title: 'No questions yet',
                          message:
                              'Add questions to this question bank using the form above.',
                        )
                      else
                        ..._questions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final q = entry.value;
                          final questionText =
                              q['questionText'] as String? ??
                              q['text'] as String? ??
                              'Question ${idx + 1}';
                          final options =
                              (q['options'] as List<dynamic>?)
                                      ?.whereType<String>()
                                      .toList() ??
                                  <String>[];
                          final correctIdx =
                              (q['correctIndex'] as num?)?.toInt() ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ModernCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: tokens.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: tokens.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          questionText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: tokens.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (options.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ...options.asMap().entries.map((opt) {
                                      final oi = opt.key;
                                      final text = opt.value;
                                      final isCorrect = oi == correctIdx;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: isCorrect
                                                    ? tokens.successSoft
                                                    : tokens.surfaceMuted,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isCorrect
                                                      ? Icons.check_rounded
                                                      : Icons.close_rounded,
                                                  size: 14,
                                                  color: isCorrect
                                                      ? tokens.success
                                                      : tokens.inkMuted,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              text,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isCorrect
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isCorrect
                                                    ? tokens.success
                                                    : tokens.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }

  Widget _stat(
      CissThemeTokens tokens, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tokens.inkMuted)),
        ],
      ),
    );
  }
}
