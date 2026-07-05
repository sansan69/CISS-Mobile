import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/modern_hero.dart';
import '../../../../../shared/widgets/state_block.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
  });

  final String id;
  final String prompt;
  final List<String> options;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: (json['id'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? (json['question'] as String?) ?? '',
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }
}

class QuizData {
  const QuizData({
    required this.assignment,
    required this.bank,
    required this.questions,
  });

  final Map<String, dynamic> assignment;
  final Map<String, dynamic> bank;
  final List<QuizQuestion> questions;

  factory QuizData.fromJson(Map<String, dynamic> json) {
    final assignment = json['assignment'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['assignment'] as Map)
        : <String, dynamic>{};
    final bank = json['bank'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['bank'] as Map)
        : <String, dynamic>{};
    final questions = (json['questions'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList();
    return QuizData(
      assignment: assignment,
      bank: bank,
      questions: questions,
    );
  }
}

class QuizResult {
  const QuizResult({
    required this.score,
    required this.passed,
    required this.passingScore,
  });

  final int score;
  final bool passed;
  final int passingScore;

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      passed: json['passed'] == true,
      passingScore: (json['passingScore'] as num?)?.toInt() ?? 80,
    );
  }
}

class GuardTrainingQuizScreen extends ConsumerStatefulWidget {
  const GuardTrainingQuizScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  ConsumerState<GuardTrainingQuizScreen> createState() =>
      _GuardTrainingQuizScreenState();
}

class _GuardTrainingQuizScreenState
    extends ConsumerState<GuardTrainingQuizScreen> {
  bool _loading = true;
  String? _error;
  QuizData? _quizData;
  QuizResult? _result;

  int _currentIndex = 0;
  final Map<int, int> _answers = {};
  DateTime? _startedAt;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _deadlineMs = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileRepositoryProvider)
          .fetchQuiz(widget.assignmentId);
      final quiz = QuizData.fromJson(data);
      final timeLimitMinutes =
          (quiz.bank['timeLimitMinutes'] as num?)?.toInt() ?? 0;
      _startedAt = DateTime.now().toUtc();
      setState(() {
        _quizData = quiz;
        _loading = false;
      });
      if (timeLimitMinutes > 0) {
        _startTimer(timeLimitMinutes);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startTimer(int minutes) {
    _deadlineMs =
        DateTime.now().millisecondsSinceEpoch + minutes * 60 * 1000;
    _remainingSeconds = minutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = ((_deadlineMs - now) / 1000).ceil();
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _submitQuiz();
      } else {
        setState(() => _remainingSeconds = remaining);
      }
    });
  }

  String get _timerDisplay {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  int get _answeredCount => _answers.length;

  void _selectOption(int questionIndex, int optionIndex) {
    setState(() => _answers[questionIndex] = optionIndex);
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _nextQuestion() {
    if (_quizData != null && _currentIndex < _quizData!.questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  Future<void> _submitQuiz() async {
    if (_submitting) return;
    if (_quizData == null) return;

    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      final answers = <Map<String, dynamic>>[];
      for (var i = 0; i < _quizData!.questions.length; i++) {
        final question = _quizData!.questions[i];
        final selectedOption = _answers[i];
        answers.add(<String, dynamic>{
          'questionId': question.id,
          'selectedIndex': selectedOption ?? -1,
        });
      }

      final response = await ref
          .read(mobileRepositoryProvider)
          .submitQuiz(
            assignmentId: widget.assignmentId,
            bankId: (_quizData!.bank['id'] as String?) ?? '',
            startedAt: _startedAt?.toIso8601String() ?? '',
            answers: answers,
          );

      final result = QuizResult.fromJson(response);
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  void _goBackToTraining() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: _loading
            ? _LoadingView(tokens: tokens)
            : _error != null && _result == null
                ? _ErrorView(
                    error: _error!,
                    tokens: tokens,
                    onRetry: _fetchQuiz,
                  )
                : _result != null
                    ? _ResultView(
                        result: _result!,
                        tokens: tokens,
                        onBack: _goBackToTraining,
                      )
                    : _QuizView(
                        quizData: _quizData!,
                        currentIndex: _currentIndex,
                        answers: _answers,
                        remainingSeconds: _remainingSeconds,
                        timerDisplay: _timerDisplay,
                        answeredCount: _answeredCount,
                        submitting: _submitting,
                        tokens: tokens,
                        onSelectOption: _selectOption,
                        onPrevious: _previousQuestion,
                        onNext: _nextQuestion,
                        onSubmit: _submitQuiz,
                      ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.tokens});

  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: tokens.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading quiz...',
            style: TextStyle(color: tokens.inkMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.tokens,
    required this.onRetry,
  });

  final String error;
  final CissThemeTokens tokens;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: StateBlock(
        icon: Icons.error_outline_rounded,
        title: 'Could not load quiz',
        message: error,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.primary,
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.tokens,
    required this.onBack,
  });

  final QuizResult result;
  final CissThemeTokens tokens;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final icon = result.passed
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    final iconColor = result.passed ? tokens.success : tokens.danger;
    final bgColor = result.passed ? tokens.successSoft : tokens.dangerSoft;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          ModernHero(
            eyebrow: 'Quiz complete',
            title: result.passed ? 'Congratulations!' : 'Keep trying',
            subtitle: result.passed
                ? 'You have passed the training quiz.'
                : 'You did not meet the passing score this time.',
            avatarChild: Icon(
              result.passed ? Icons.emoji_events_rounded : Icons.school_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ModernCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${result.score}%',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  result.passed ? 'Passed' : 'Did not pass',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: result.passed ? tokens.success : tokens.danger,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Passing ${result.passingScore}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Training'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.quizData,
    required this.currentIndex,
    required this.answers,
    required this.remainingSeconds,
    required this.timerDisplay,
    required this.answeredCount,
    required this.submitting,
    required this.tokens,
    required this.onSelectOption,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final QuizData quizData;
  final int currentIndex;
  final Map<int, int> answers;
  final int remainingSeconds;
  final String timerDisplay;
  final int answeredCount;
  final bool submitting;
  final CissThemeTokens tokens;
  final void Function(int questionIndex, int optionIndex) onSelectOption;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final questions = quizData.questions;
    final question = questions[currentIndex];
    final isLast = currentIndex == questions.length - 1;
    final selectedOption = answers[currentIndex];

    return Column(
      children: <Widget>[
        ModernHero(
          eyebrow: 'Training Quiz',
          title: (quizData.assignment['moduleName'] as String?) ?? 'Quiz',
          subtitle: '${questions.length} questions',
          trailing: remainingSeconds > 0
              ? _TimerPill(
                  display: timerDisplay,
                  tokens: tokens,
                )
              : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _QuestionProgress(
                  current: currentIndex + 1,
                  total: questions.length,
                  answeredCount: answeredCount,
                  tokens: tokens,
                ),
                const SizedBox(height: AppSpacing.md),
                ModernCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Question ${currentIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...List.generate(question.options.length, (optionIndex) {
                        final isSelected = selectedOption == optionIndex;
                        final letters = ['A', 'B', 'C', 'D'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _OptionButton(
                            letter: optionIndex < letters.length
                                ? letters[optionIndex]
                                : '${optionIndex + 1}',
                            text: question.options[optionIndex],
                            isSelected: isSelected,
                            tokens: tokens,
                            onTap: () => onSelectOption(
                              currentIndex,
                              optionIndex,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          isFirst: currentIndex == 0,
          isLast: isLast,
          answeredCount: answeredCount,
          totalCount: questions.length,
          submitting: submitting,
          tokens: tokens,
          onPrevious: onPrevious,
          onNext: onNext,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.display, required this.tokens});

  final String display;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tokens.warning,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({
    required this.current,
    required this.total,
    required this.answeredCount,
    required this.tokens,
  });

  final int current;
  final int total;
  final int answeredCount;
  final CissThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total > 0 ? current / total : 0,
              minHeight: 6,
              backgroundColor: tokens.border,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$answeredCount / $total answered',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tokens.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool isSelected;
  final CissThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? tokens.primarySoft : tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(
          color: isSelected ? tokens.primary : tokens.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? tokens.primary : tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : tokens.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? tokens.primary : tokens.ink,
                    height: 1.4,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: tokens.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isFirst,
    required this.isLast,
    required this.answeredCount,
    required this.totalCount,
    required this.submitting,
    required this.tokens,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
  });

  final bool isFirst;
  final bool isLast;
  final int answeredCount;
  final int totalCount;
  final bool submitting;
  final CissThemeTokens tokens;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            if (!isFirst)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.inkMuted,
                    side: BorderSide(color: tokens.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            if (!isFirst) const SizedBox(width: AppSpacing.sm),
            if (isLast)
              Expanded(
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(submitting ? 'Submitting...' : 'Submit Quiz'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.primary,
                    disabledBackgroundColor: tokens.primary.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
