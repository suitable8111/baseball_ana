import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pitcher_provider.dart';
import '../models/player_pitcher.dart';
import '../widgets/stats_table_header.dart';

class PlayerPitcherScreen extends StatelessWidget {
  const PlayerPitcherScreen({super.key});

  static const _columns = [
    ('순위', 'rank', 40.0),
    ('선수명', 'name', 80.0),
    ('팀', 'team', 48.0),
    ('G', 'games', 40.0),
    ('W', 'wins', 40.0),
    ('L', 'losses', 40.0),
    ('S', 'saves', 40.0),
    ('IP', 'ip', 52.0),
    ('K', 'so', 44.0),
    ('BB', 'bb', 44.0),
    ('ERA', 'era', 56.0),
    ('WHIP', 'whip', 56.0),
    ('K/9', 'k9', 52.0),
    ('BB/9', 'bb9', 52.0),
    ('FIP', 'fip', 56.0),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PitcherProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(child: Text('오류: ${provider.error}'));
    }

    final pitchers = provider.pitchers;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: StatsTableHeader(
            columns: _columns,
            sortColumn: provider.sortColumn,
            sortAscending: provider.sortAscending,
            onSort: provider.sort,
          ),
        ),
        Expanded(
          child: pitchers.isEmpty
              ? const Center(child: Text('데이터가 없습니다'))
              : ListView.builder(
                  itemCount: pitchers.length,
                  itemBuilder: (context, i) {
                    return _PitcherRow(rank: i + 1, pitcher: pitchers[i]);
                  },
                ),
        ),
      ],
    );
  }
}

class _PitcherRow extends StatelessWidget {
  final int rank;
  final PlayerPitcher pitcher;

  const _PitcherRow({required this.rank, required this.pitcher});

  @override
  Widget build(BuildContext context) {
    final isEven = rank % 2 == 0;
    final bg = isEven
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Theme.of(context).colorScheme.surface;

    return Container(
      color: bg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _cell('$rank', 40, bold: true),
            _cell(pitcher.name, 80, bold: true),
            _cell(pitcher.team, 48),
            _cell('${pitcher.games}', 40),
            _cell('${pitcher.wins}', 40),
            _cell('${pitcher.losses}', 40),
            _cell('${pitcher.saves}', 40),
            _cell(pitcher.ip.toStringAsFixed(1), 52),
            _cell('${pitcher.so}', 44),
            _cell('${pitcher.bb}', 44),
            _statCell(pitcher.era.toStringAsFixed(2), highlight: true),
            _statCell(pitcher.whip.toStringAsFixed(2)),
            _statCell(pitcher.k9.toStringAsFixed(1)),
            _statCell(pitcher.bb9.toStringAsFixed(1)),
            _statCell(pitcher.fip.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      height: 36,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _statCell(String text, {bool highlight = false}) {
    return SizedBox(
      width: 56,
      height: 36,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? const Color(0xFF1B3A6B) : null,
          ),
        ),
      ),
    );
  }
}
