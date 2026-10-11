import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/models/training_models.dart';
import '../../../../../core/network/providers.dart';
import '../../../../../shared/utils/initials.dart';
import '../../../../../shared/widgets/modern_card.dart';
import '../../../../../shared/widgets/screen_scaffold.dart';
import '../../../../../shared/widgets/state_block.dart';
import '../widgets/guard_portal_widgets.dart';

final FutureProvider<GuardTrainingLeaderboard> guardTrainingLeaderboardProvider =
    FutureProvider<GuardTrainingLeaderboard>((Ref ref) {
      return ref.read(mobileRepositoryProvider).fetchTrainingLeaderboard();
    });

class GuardTrainingLeaderboardScreen extends ConsumerWidget {
  const GuardTrainingLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(guardTrainingLeaderboardProvider);

    return leaderboardAsync.when(
      loading:
          () =>
              const GuardLoadingScaffold(label: 'Loading training leaderboard...'),
      error:
          (Object error, StackTrace stackTrace) => GuardErrorScaffold(
            title: 'Could not load leaderboard',
            error: error,
            onRetry: () => ref.invalidate(guardTrainingLeaderboardProvider),
          ),
      data: (leaderboard) => _LeaderboardBody(leaderboard: leaderboard),
    );
  }
}

class _LeaderboardBody extends ConsumerWidget {
  const _LeaderboardBody({required this.leaderboard});

  final GuardTrainingLeaderboard leaderboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = CissThemeTokens.of(context);
    final entries = leaderboard.entries;
    final myEntry = leaderboard.myEntry;

    final String scopeLabel = leaderboard.district.isNotEmpty
        ? leaderboard.district
        : (myEntry?.district.isNotEmpty == true ? myEntry!.district : 'Your district');
    final String monthLabel = leaderboard.currentMonth.isEmpty
        ? 'This month'
        : leaderboard.currentMonth;

    return ScreenScaffold(
      title: 'Training Leaderboard',
      subtitle: '$scopeLabel • $monthLabel',
      onRefresh: () async => ref.invalidate(guardTrainingLeaderboardProvider),
      actions: <Widget>[
        IconButton(
          onPressed: () => ref.invalidate(guardTrainingLeaderboardProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: <Widget>[
        GuardHeroPanel(
          eyebrow: 'Training',
          title: 'Leaderboard',
          subtitle:
              entries.isEmpty
                  ? 'Complete a training quiz to appear on the leaderboard.'
                  : '${entries.length} guards ranked by latest quiz score.',
          icon: Icons.emoji_events_rounded,
          accentColor: tokens.accent,
        ),

        // ── Your ranking ─────────────────────────────────────────────
        if (leaderboard.myRank != null && myEntry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _MyRankCard(rank: leaderboard.myRank!, entry: myEntry),
        ],

        const SizedBox(height: AppSpacing.lg),

        // ── Empty state ──────────────────────────────────────────────
        if (entries.isEmpty)
          const StateBlock(
            icon: Icons.leaderboard_outlined,
            title: 'No rankings yet',
            message:
                'When guards in your area complete training quizzes, their '
                'scores will appear here.',
          ),

        // ── Podium (top 3) ───────────────────────────────────────────
        if (entries.isNotEmpty) ...<Widget>[
          const _SectionHeader(title: 'Top performers'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (entries.length >= 2) ...[
                Expanded(child: _PodiumCard(entry: entries[1], accent: tokens.accent)),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: _PodiumCard(entry: entries[0], accent: tokens.warning, isFirst: true)),
              if (entries.length >= 3) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _PodiumCard(entry: entries[2], accent: tokens.accent)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Full rankings (4+) ───────────────────────────────────────
        if (entries.length > 3) ...<Widget>[
          const _SectionHeader(title: 'All rankings'),
          const SizedBox(height: AppSpacing.sm),
          ...entries.skip(3).map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RankingRow(entry: entry),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.rank, required this.entry});

  final int rank;
  final GuardTrainingLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      borderColor: tokens.primary.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          Container(
            height: 52,
            width: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'You are ranked #$rank',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Latest training score: ${entry.trainingScore}/100 • '
                  '${entry.totalTrainingsCompleted} completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.accent,
    this.isFirst = false,
  });

  final GuardTrainingLeaderboardEntry entry;
  final Color accent;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return ModernCard(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        isFirst ? AppSpacing.lg : AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      borderColor: isFirst ? accent.withValues(alpha: 0.5) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isFirst ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
            color: accent,
            size: isFirst ? 30 : 24,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Avatar(entry: entry, size: isFirst ? 40 : 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            entry.employeeName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.clientName.isNotEmpty)
            Text(
              entry.clientName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${entry.trainingScore}',
            style: TextStyle(
              color: isFirst ? accent : tokens.primary,
              fontSize: isFirst ? 22 : 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${entry.totalTrainingsCompleted} done',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry});

  final GuardTrainingLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    final scoreColor =
        entry.trainingScore >= 80
            ? tokens.success
            : entry.trainingScore >= 60
            ? tokens.warning
            : tokens.danger;

    return ModernCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Avatar(entry: entry),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.clientName.isNotEmpty)
                  Text(
                    entry.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${entry.trainingScore}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${entry.totalTrainingsCompleted} done',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, this.size = 36});

  final GuardTrainingLeaderboardEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(entry.employeeName, fallback: 'G'),
        style: TextStyle(
          color: tokens.primaryStrong,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: tokens.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
