import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/prediction_provider.dart';
import '../models/game_schedule.dart';
import '../models/simulation_models.dart';

class GameScheduleScreen extends StatefulWidget {
  const GameScheduleScreen({super.key});

  @override
  State<GameScheduleScreen> createState() => _GameScheduleScreenState();
}

class _GameScheduleScreenState extends State<GameScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<ScheduleProvider>();
      if (prov.games.isEmpty && !prov.loadingGames) {
        prov.loadDate(prov.date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (isWide) {
          return _WideLayout();
        } else {
          return _NarrowLayout();
        }
      },
    );
  }
}

// ─── Wide layout (≥700px): sidebar + detail panel ───────────────────────────

class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScheduleProvider>();

    return Column(
      children: [
        _DateBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left sidebar: game list
              SizedBox(
                width: 280,
                child: _GameList(
                  onTap: (game) => context.read<ScheduleProvider>().selectGame(game),
                ),
              ),
              const VerticalDivider(width: 1),
              // Right panel: lineup / placeholder
              Expanded(
                child: prov.selectedGame == null
                    ? const _EmptyPanel()
                    : _PreviewPanel(game: prov.selectedGame!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Narrow layout (<700px): list + bottom sheet ─────────────────────────────

class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DateBar(),
        Expanded(
          child: _GameList(
            onTap: (game) {
              context.read<ScheduleProvider>().selectGame(game);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<ScheduleProvider>(),
                  child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.92,
                    maxChildSize: 0.95,
                    builder: (_, ctrl) => _PreviewPanel(
                      game: game,
                      scrollController: ctrl,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Date bar ────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScheduleProvider>();
    final d = prov.date;
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    final label =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ($wd)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: prov.loadingGames ? null : prov.prevDay,
            visualDensity: VisualDensity.compact,
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: prov.date,
                firstDate: DateTime(2025, 1, 1),
                lastDate: DateTime(2026, 12, 31),
              );
              if (picked != null && context.mounted) {
                context.read<ScheduleProvider>().loadDate(picked);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: prov.loadingGames ? null : prov.nextDay,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Game list ───────────────────────────────────────────────────────────────

class _GameList extends StatelessWidget {
  final void Function(KboGame) onTap;
  const _GameList({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScheduleProvider>();

    if (prov.loadingGames) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.error != null && prov.games.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40),
            const SizedBox(height: 8),
            Text('불러오기 실패', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SelectableText(
                prov.error!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () =>
                  context.read<ScheduleProvider>().loadDate(prov.date),
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }
    if (prov.games.isEmpty) {
      return const Center(child: Text('경기 없음'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: prov.games.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final game = prov.games[i];
        final isSelected = prov.selectedGame?.gameId == game.gameId;
        return _GameCard(
          game: game,
          isSelected: isSelected,
          onTap: () => onTap(game),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  final KboGame game;
  final bool isSelected;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isSelected ? cs.primaryContainer : cs.surface;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score / time row
            Row(
              children: [
                Expanded(
                  child: Text(
                    game.awayTeamName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: game.winner == 'away' ? cs.primary : null,
                    ),
                  ),
                ),
                _ScoreOrTime(game: game),
                Expanded(
                  child: Text(
                    game.homeTeamName,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: game.winner == 'home' ? cs.primary : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Starters row
            Row(
              children: [
                Expanded(
                  child: Text(
                    game.awayStarterName ?? '-',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  game.stadium,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline),
                ),
                Expanded(
                  child: Text(
                    game.homeStarterName ?? '-',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (game.isResult && game.homeScoreByInning.isNotEmpty)
              _InningRow(game: game),
          ],
        ),
      ),
    );
  }
}

class _ScoreOrTime extends StatelessWidget {
  final KboGame game;
  const _ScoreOrTime({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (game.isResult || game.isLive) {
      final aw = game.awayTeamScore ?? 0;
      final hw = game.homeTeamScore ?? 0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$aw',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: game.winner == 'away' ? cs.primary : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                game.isLive ? '●' : ':',
                style: TextStyle(
                  color: game.isLive ? Colors.red : cs.outline,
                ),
              ),
            ),
            Text(
              '$hw',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: game.winner == 'home' ? cs.primary : null,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        game.timeLabel,
        style: TextStyle(fontSize: 14, color: cs.outline),
      ),
    );
  }
}

class _InningRow extends StatelessWidget {
  final KboGame game;
  const _InningRow({required this.game});

  @override
  Widget build(BuildContext context) {
    final innings = game.homeScoreByInning.length;
    if (innings == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < innings; i++)
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    Text(
                      '${i + 1}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                    Text(
                      '${game.awayScoreByInning.length > i ? game.awayScoreByInning[i] : '-'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '${game.homeScoreByInning[i]}',
                      style: const TextStyle(fontSize: 11),
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

// ─── Preview panel ────────────────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_baseball_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '경기를 선택하면\n라인업을 확인할 수 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final KboGame game;
  final ScrollController? scrollController;

  const _PreviewPanel({required this.game, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ScheduleProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Game header
        _GameHeader(game: game),
        const Divider(height: 1),
        // Content
        Expanded(
          child: prov.loadingPreview
              ? const Center(child: CircularProgressIndicator())
              : prov.preview == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(height: 8),
                          const Text('라인업 정보 없음'),
                          if (prov.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                prov.error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    )
                  : _PreviewContent(
                      game: game,
                      preview: prov.preview!,
                      scrollController: scrollController,
                    ),
        ),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  final KboGame game;
  const _GameHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              game.awayTeamName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Column(
            children: [
              if (game.isResult || game.isLive)
                Text(
                  '${game.awayTeamScore ?? 0}  :  ${game.homeTeamScore ?? 0}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                )
              else
                Text(
                  game.timeLabel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              Text(
                game.stadium,
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
              ),
            ],
          ),
          Expanded(
            child: Text(
              game.homeTeamName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  final KboGame game;
  final GamePreview preview;
  final ScrollController? scrollController;

  const _PreviewContent({
    required this.game,
    required this.preview,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        // Standings + H2H
        if (preview.homeStandings != null || preview.awayStandings != null)
          _StandingsRow(
            game: game,
            home: preview.homeStandings,
            away: preview.awayStandings,
            h2h: preview.headToHead,
          ),
        const SizedBox(height: 12),
        // Starters
        if (preview.homeStarter != null || preview.awayStarter != null)
          _StartersRow(
            game: game,
            homeStarter: preview.homeStarter,
            awayStarter: preview.awayStarter,
          ),
        const SizedBox(height: 12),
        // 승률 예측
        _LineupWinProbSection(game: game, preview: preview),
        const SizedBox(height: 12),
        // Lineups
        _LineupsTable(
          game: game,
          homeLineup: preview.homeLineup,
          awayLineup: preview.awayLineup,
        ),
      ],
    );
  }
}

// ─── Standings row ────────────────────────────────────────────────────────────

class _StandingsRow extends StatelessWidget {
  final KboGame game;
  final TeamStandings? home;
  final TeamStandings? away;
  final HeadToHead? h2h;

  const _StandingsRow({
    required this.game,
    this.home,
    this.away,
    this.h2h,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String standingLabel(TeamStandings? s, String teamName) {
      if (s == null) return teamName;
      return '${s.rank}위 (${s.wins}승 ${s.losses}패)';
    }

    String h2hLabel() {
      if (h2h == null) return '';
      return '시즌 상대전적: 원정 ${h2h!.awayWins}승 ${h2h!.awayLosses}패 / 홈 ${h2h!.homeWins}승 ${h2h!.homeLosses}패';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    standingLabel(away, game.awayTeamName),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '순위',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSecondaryContainer),
                  ),
                ),
                Expanded(
                  child: Text(
                    standingLabel(home, game.homeTeamName),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (h2h != null) ...[
              const SizedBox(height: 6),
              Text(
                h2hLabel(),
                style: TextStyle(fontSize: 12, color: cs.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Starters row ─────────────────────────────────────────────────────────────

class _StartersRow extends StatelessWidget {
  final KboGame game;
  final StarterInfo? homeStarter;
  final StarterInfo? awayStarter;

  const _StartersRow({
    required this.game,
    this.homeStarter,
    this.awayStarter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget starterCard(StarterInfo? s, String fallbackName) {
      final name = s?.name ?? fallbackName;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              if (s != null) ...[
                const SizedBox(height: 4),
                Text(
                  'ERA ${s.era.toStringAsFixed(2)}  WHIP ${s.whip.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                Text(
                  '${s.wins}승 ${s.losses}패  ${s.ip.toStringAsFixed(1)}이닝',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        starterCard(awayStarter, game.awayStarterName ?? '?'),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text('vs',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: cs.outline)),
        ),
        const SizedBox(width: 4),
        starterCard(homeStarter, game.homeStarterName ?? '?'),
      ],
    );
  }
}

// ─── Lineups table ─────────────────────────────────────────────────────────────

class _LineupsTable extends StatelessWidget {
  final KboGame game;
  final List<LineupPlayer> homeLineup;
  final List<LineupPlayer> awayLineup;

  const _LineupsTable({
    required this.game,
    required this.homeLineup,
    required this.awayLineup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Sort batters by batorder; put pitchers (batorder==0) at end
    List<LineupPlayer> sortLineup(List<LineupPlayer> lineup) {
      final batters = lineup.where((p) => p.batorder > 0).toList()
        ..sort((a, b) => a.batorder.compareTo(b.batorder));
      final others = lineup.where((p) => p.batorder == 0).toList();
      return [...batters, ...others];
    }

    final away = sortLineup(awayLineup);
    final home = sortLineup(homeLineup);
    final rows = [away.length, home.length].reduce((a, b) => a > b ? a : b);

    if (rows == 0) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '라인업 미발표',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline),
          ),
        ),
      );
    }

    Widget headerCell(String text) => Expanded(
          child: Container(
            color: cs.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );

    Widget playerCell(LineupPlayer? p, int idx) {
      final bg = idx % 2 == 0 ? cs.surfaceContainerLow : cs.surface;
      if (p == null) {
        return Expanded(child: Container(color: bg, height: 44));
      }
      // 타자 스탯 조회: 로컬 JSON 우선, 없으면 통계 API (playerCode 기반)
      String? statLine;
      if (p.batorder > 0) {
        final pred = context.read<PredictionProvider>();
        final sched = context.read<ScheduleProvider>();
        final localStats = pred.hitterStatsByName(p.playerName);
        if (localStats != null) {
          final avg = (localStats['avg'] as num?)?.toStringAsFixed(3);
          final ops = (localStats['ops'] as num?)?.toStringAsFixed(3);
          if (avg != null) statLine = 'AVG $avg  OPS ${ops ?? '-'}';
        } else {
          final online = sched.playerStats[p.playerCode];
          if (online != null) {
            final avg = online['avg'];
            final ops = online['ops'];
            if (avg != null && avg > 0) {
              final opsStr = (ops != null && ops > 0)
                  ? ops.toStringAsFixed(3)
                  : '-';
              statLine = 'AVG ${avg.toStringAsFixed(3)}  OPS $opsStr';
            }
          }
        }
      }

      return Expanded(
        child: Container(
          color: bg,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              if (p.batorder > 0)
                SizedBox(
                  width: 16,
                  child: Text(
                    '${p.batorder}',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.outline,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.playerName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statLine != null)
                      Text(
                        statLine,
                        style: TextStyle(fontSize: 10, color: cs.outline),
                      ),
                  ],
                ),
              ),
              Text(
                p.positionName,
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Row(
            children: [
              headerCell('원정  ${game.awayTeamName}'),
              const SizedBox(width: 1),
              headerCell('홈  ${game.homeTeamName}'),
            ],
          ),
          // Rows
          for (int i = 0; i < rows; i++)
            Row(
              children: [
                playerCell(i < away.length ? away[i] : null, i),
                Container(width: 1, height: 44, color: cs.outlineVariant),
                playerCell(i < home.length ? home[i] : null, i),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── 라인업 승률 예측 섹션 ──────────────────────────────────────────────────────

class _LineupWinProbSection extends StatelessWidget {
  final KboGame game;
  final GamePreview preview;

  const _LineupWinProbSection({required this.game, required this.preview});

  List<String> _battingNames(List<LineupPlayer> lineup) {
    final sorted = lineup.where((p) => p.batorder > 0).toList()
      ..sort((a, b) => a.batorder.compareTo(b.batorder));
    return sorted.map((p) => p.playerName).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pred = context.watch<PredictionProvider>();
    final cs = Theme.of(context).colorScheme;

    // 라인업이 없거나 PredictionProvider 데이터 미로드 상태
    final hasLineup =
        preview.homeLineup.any((p) => p.batorder > 0) ||
        preview.awayLineup.any((p) => p.batorder > 0);

    if (!hasLineup) return const SizedBox.shrink();

    // 예측 결과 표시
    if (pred.lineupLoading) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('승률 계산 중…', style: TextStyle(color: cs.outline)),
            ],
          ),
        ),
      );
    }

    if (pred.lineupResult != null &&
        pred.lineupResult!.homeTeam == game.homeTeamName) {
      return _WinProbCard(result: pred.lineupResult!, game: game);
    }

    // 예측 버튼
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.calculate_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '라인업 기반 승률 예측',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
            ),
            if (pred.lineupError != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: pred.lineupError!,
                  child: Icon(Icons.error_outline,
                      size: 16, color: cs.error),
                ),
              ),
            FilledButton.tonal(
              onPressed: () {
                final homeNames = _battingNames(preview.homeLineup);
                final awayNames = _battingNames(preview.awayLineup);
                context.read<PredictionProvider>().runLineupSimulation(
                      gameId: game.gameId,
                      homeTeam: game.homeTeamName,
                      awayTeam: game.awayTeamName,
                      homeLineupNames: homeNames,
                      awayLineupNames: awayNames,
                      homeStarterName: game.homeStarterName,
                      awayStarterName: game.awayStarterName,
                    );
              },
              child: const Text('예측'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinProbCard extends StatelessWidget {
  final SimulationResult result;
  final KboGame game;

  const _WinProbCard({required this.result, required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final awayPct = (result.awayWinProb * 100).round();
    final tiePct = (result.tieProb * 100).round();
    final homePct = (result.homeWinProb * 100).round();

    // 과거 경기 비교 로직
    final isResult = game.isResult;
    final actualWinner = game.winner; // 'home' | 'away' | null
    final predictedWinner =
        result.homeWinProb >= result.awayWinProb ? 'home' : 'away';
    final isCorrect =
        !isResult || actualWinner == null || actualWinner == predictedWinner;

    // 바 색상: 기본(예정) → 원정 빨강 / 홈 남색
    // 과거 정답: 실제 승자 강조(원래 색), 패자 회색
    // 과거 오답: 실제 승자 파랑/초록, 잘못 예측한 쪽 빨강
    Color awayColor;
    Color homeColor;
    Color tieColor = cs.outlineVariant;

    if (!isResult || actualWinner == null) {
      awayColor = Colors.redAccent;
      homeColor = const Color(0xFF1B3A6B);
    } else if (isCorrect) {
      awayColor = actualWinner == 'away' ? Colors.redAccent : cs.outlineVariant;
      homeColor =
          actualWinner == 'home' ? const Color(0xFF1B3A6B) : cs.outlineVariant;
    } else {
      // 오답: 실제 승자=파랑, 잘못 예측한 쪽=빨강
      awayColor = actualWinner == 'away'
          ? Colors.blue
          : (predictedWinner == 'away' ? Colors.red : cs.outlineVariant);
      homeColor = actualWinner == 'home'
          ? Colors.blue
          : (predictedWinner == 'home' ? Colors.red : cs.outlineVariant);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 팀명 + 뱃지
            Row(
              children: [
                Expanded(
                  child: Text(result.awayTeam,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start),
                ),
                if (isResult && actualWinner != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isCorrect ? '✓ 예측 적중' : '✗ 예측 실패',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                  )
                else
                  Text('승률 예측',
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                Expanded(
                  child: Text(result.homeTeam,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 확률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    if (awayPct > 0)
                      Expanded(
                        flex: awayPct,
                        child: Container(
                          color: awayColor,
                          alignment: Alignment.center,
                          child: Text('$awayPct%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (tiePct > 0)
                      Expanded(
                        flex: tiePct,
                        child: Container(
                          color: tieColor,
                          alignment: Alignment.center,
                          child: Text('$tiePct%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    if (homePct > 0)
                      Expanded(
                        flex: homePct,
                        child: Container(
                          color: homeColor,
                          alignment: Alignment.center,
                          child: Text('$homePct%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 평균 예측 점수 + 실제 스코어(과거)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '예측 ${result.awayAvgScore.toStringAsFixed(1)}점'
                    '${isResult && game.awayTeamScore != null ? '  실제 ${game.awayTeamScore}점' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${isResult && game.homeTeamScore != null ? '실제 ${game.homeTeamScore}점  ' : ''}예측 ${result.homeAvgScore.toStringAsFixed(1)}점',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, color: cs.outline),
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
