import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hitter_provider.dart';
import '../models/player_hitter.dart';
import '../widgets/stats_table_header.dart';

class PlayerHitterScreen extends StatelessWidget {
  const PlayerHitterScreen({super.key});

  static const _columns = [
    ('순위', 'rank', 40.0),
    ('선수명', 'name', 80.0),
    ('팀', 'team', 48.0),
    ('G', 'games', 44.0),
    ('PA', 'pa', 44.0),
    ('AB', 'ab', 44.0),
    ('H', 'hits', 44.0),
    ('HR', 'hr', 44.0),
    ('RBI', 'rbi', 44.0),
    ('SB', 'sb', 44.0),
    ('AVG', 'avg', 56.0),
    ('OBP', 'obp', 56.0),
    ('SLG', 'slg', 56.0),
    ('OPS', 'ops', 60.0),
    ('BABIP', 'babip', 60.0),
    ('ISO', 'iso', 56.0),
  ];

  static const double _totalWidth =
      40 + 80 + 48 + 44 + 44 + 44 + 44 + 44 + 44 + 44 + 56 + 56 + 56 + 60 + 60 + 56;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HitterProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(child: Text('오류: ${provider.error}'));
    }

    final hitters = provider.hitters;

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
              child: hitters.isEmpty
                  ? const Center(child: Text('데이터가 없습니다'))
                  : ListView.builder(
                      itemCount: hitters.length,
                      itemBuilder: (context, i) {
                        final h = hitters[i];
                        return _HitterRow(
                          rank: provider.rankOf(h),
                          hitter: h,
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

class _HitterRow extends StatelessWidget {
  final int rank;
  final PlayerHitter hitter;
  final double scale;

  const _HitterRow({required this.rank, required this.hitter, required this.scale});

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
          _cell(hitter.name, 80, bold: true, fs: fs),
          _teamCell(hitter.team, fs: fs),
          _cell('${hitter.games}', 44, fs: fs),
          _cell('${hitter.pa}', 44, fs: fs),
          _cell('${hitter.ab}', 44, fs: fs),
          _cell('${hitter.hits}', 44, fs: fs),
          _cell('${hitter.hr}', 44, fs: fs),
          _cell('${hitter.rbi}', 44, fs: fs),
          _cell('${hitter.sb}', 44, fs: fs),
          _statCell(hitter.avg.toStringAsFixed(3), fs: fs),
          _statCell(hitter.obp.toStringAsFixed(3), fs: fs),
          _statCell(hitter.slg.toStringAsFixed(3), fs: fs),
          _statCell(hitter.ops.toStringAsFixed(3), highlight: true, width: 60, fs: fs),
          _statCell(hitter.babip.toStringAsFixed(3), width: 60, fs: fs),
          _statCell(hitter.iso.toStringAsFixed(3), fs: fs),
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

  Widget _teamCell(String team, {required double fs}) {
    return SizedBox(
      width: 48 * scale,
      height: 36,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _teamColor(team).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            team,
            style: TextStyle(
              fontSize: fs - 1,
              fontWeight: FontWeight.bold,
              color: _teamColor(team),
            ),
          ),
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

  Color _teamColor(String team) {
    const colors = {
      'KIA': Color(0xFFCC0000),
      'LG': Color(0xFFC30452),
      '삼성': Color(0xFF074CA1),
      '두산': Color(0xFF131230),
      'KT': Color(0xFF000000),
      'SSG': Color(0xFFCE0E2D),
      '롯데': Color(0xFF002B5B),
      '한화': Color(0xFFFF6600),
      'NC': Color(0xFF315288),
      '키움': Color(0xFF820024),
    };
    return colors[team] ?? Colors.grey;
  }
}
