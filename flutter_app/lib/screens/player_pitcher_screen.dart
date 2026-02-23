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

  static const double _totalWidth =
      40 + 80 + 48 + 40 + 40 + 40 + 40 + 52 + 44 + 44 + 56 + 56 + 52 + 52 + 56;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _totalWidth).clamp(1.0, 2.0);

        return Column(
          children: [
            StatsTableHeader(
              columns: _columns,
              sortColumn: provider.sortColumn,
              sortAscending: provider.sortAscending,
              onSort: provider.sort,
              scale: scale,
            ),
            Expanded(
              child: pitchers.isEmpty
                  ? const Center(child: Text('데이터가 없습니다'))
                  : ListView.builder(
                      itemCount: pitchers.length,
                      itemBuilder: (context, i) {
                        return _PitcherRow(
                          rank: provider.rankOf(pitchers[i]),
                          pitcher: pitchers[i],
                          scale: scale,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PitcherRow extends StatelessWidget {
  final int rank;
  final PlayerPitcher pitcher;
  final double scale;

  const _PitcherRow({required this.rank, required this.pitcher, required this.scale});

  @override
  Widget build(BuildContext context) {
    final isEven = rank % 2 == 0;
    final bg = isEven
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Theme.of(context).colorScheme.surface;
    final fs = (12 * scale.clamp(1.0, 1.3));

    return Container(
      color: bg,
      child: Row(
        children: [
          _cell('$rank', 40, bold: true, fs: fs),
          _cell(pitcher.name, 80, bold: true, fs: fs),
          _cell(pitcher.team, 48, fs: fs),
          _cell('${pitcher.games}', 40, fs: fs),
          _cell('${pitcher.wins}', 40, fs: fs),
          _cell('${pitcher.losses}', 40, fs: fs),
          _cell('${pitcher.saves}', 40, fs: fs),
          _cell(pitcher.ip.toStringAsFixed(1), 52, fs: fs),
          _cell('${pitcher.so}', 44, fs: fs),
          _cell('${pitcher.bb}', 44, fs: fs),
          _statCell(pitcher.era.toStringAsFixed(2), highlight: true, fs: fs),
          _statCell(pitcher.whip.toStringAsFixed(2), fs: fs),
          _statCell(pitcher.k9.toStringAsFixed(1), width: 52, fs: fs),
          _statCell(pitcher.bb9.toStringAsFixed(1), width: 52, fs: fs),
          _statCell(pitcher.fip.toStringAsFixed(2), fs: fs),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {bool bold = false, required double fs}) {
    return SizedBox(
      width: width * scale,
      height: 36,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _statCell(String text, {bool highlight = false, double width = 56, required double fs}) {
    return SizedBox(
      width: width * scale,
      height: 36,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? const Color(0xFF1B3A6B) : null,
          ),
        ),
      ),
    );
  }
}
