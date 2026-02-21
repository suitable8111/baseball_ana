import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/team_rank_provider.dart';
import '../models/team_rank.dart';

class TeamRankScreen extends StatelessWidget {
  const TeamRankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: '팀 순위'),
              Tab(text: '상대 전적'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: Consumer<TeamRankProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                return TabBarView(
                  children: [
                    _StandingsTab(standings: provider.standings),
                    _HeadToHeadTab(headToHead: provider.headToHead),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 팀 순위표 탭
// ─────────────────────────────────────────────

class _StandingsTab extends StatelessWidget {
  final List<TeamStanding> standings;

  const _StandingsTab({required this.standings});

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          ),
          columns: const [
            DataColumn(label: Text('순위', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('팀', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('경기', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('승', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('패', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('무', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('승률', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('게임차', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('최근10경기', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('연속', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('홈(승-무-패)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('방문(승-무-패)', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: standings.map((s) {
            final isPlayoff = s.rank <= 5;
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (isPlayoff) {
                  return Colors.blue.withValues(alpha: 0.05);
                }
                return null;
              }),
              cells: [
                DataCell(Text(
                  '${s.rank}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPlayoff
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                )),
                DataCell(Text(
                  s.team,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
                DataCell(Text('${s.games}')),
                DataCell(Text(
                  '${s.wins}',
                  style: const TextStyle(color: Colors.blue),
                )),
                DataCell(Text(
                  '${s.losses}',
                  style: const TextStyle(color: Colors.red),
                )),
                DataCell(Text('${s.ties}')),
                DataCell(Text(s.pct.toStringAsFixed(3))),
                DataCell(Text(s.gb == 0.0 ? '-' : s.gb.toStringAsFixed(1))),
                DataCell(Text(s.last10, style: const TextStyle(fontSize: 12))),
                DataCell(_StreakBadge(streak: s.streak)),
                DataCell(Text(s.homeRecord, style: const TextStyle(fontSize: 12))),
                DataCell(Text(s.awayRecord, style: const TextStyle(fontSize: 12))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final String streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final isWin = streak.contains('승');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWin
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        streak,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isWin ? Colors.blue.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 상대 전적 매트릭스 탭
// ─────────────────────────────────────────────

class _HeadToHeadTab extends StatelessWidget {
  final List<HeadToHead> headToHead;

  const _HeadToHeadTab({required this.headToHead});

  @override
  Widget build(BuildContext context) {
    if (headToHead.isEmpty) {
      return const Center(child: Text('데이터 없음'));
    }

    final teams = headToHead.map((h) => h.team).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
          defaultColumnWidth: const FixedColumnWidth(70),
          children: [
            // 헤더 행
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              children: [
                _tableCell('팀', bold: true),
                ...teams.map((t) => _tableCell(t, bold: true)),
                _tableCell('합계', bold: true),
              ],
            ),
            // 데이터 행
            ...headToHead.map((h) => TableRow(
                  children: [
                    _teamCell(h.team),
                    ...teams.map((opp) {
                      if (opp == h.team) return _selfCell();
                      return _matchupCell(h.matchups[opp]);
                    }),
                    _totalCell(h),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _teamCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _selfCell() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(8),
      child: const Text('■', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    );
  }

  Widget _matchupCell(MatchupRecord? record) {
    if (record == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
      );
    }
    Color? bg;
    if (record.w > record.l) {
      bg = Colors.blue.withValues(alpha: 0.12);
    } else if (record.w < record.l) {
      bg = Colors.red.withValues(alpha: 0.12);
    }
    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Text(
        record.record,
        style: const TextStyle(fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _totalCell(HeadToHead h) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        h.totalRecord,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
