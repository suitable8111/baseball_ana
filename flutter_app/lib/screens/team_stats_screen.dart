import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/team_provider.dart';
import '../models/team_stats.dart';

class TeamStatsScreen extends StatefulWidget {
  const TeamStatsScreen({super.key});

  @override
  State<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends State<TeamStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeamProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '팀 타자'),
            Tab(text: '팀 투수'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TeamHitterTable(teams: provider.teamHitters),
              _TeamPitcherTable(teams: provider.teamPitchers),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 팀 타자 ──────────────────────────────────────────────────────────────────────

class _TeamHitterTable extends StatelessWidget {
  final List<TeamHitter> teams;
  const _TeamHitterTable({required this.teams});

  // (label, width)
  static const _cols = [
    ('팀', 64.0),
    ('G', 44.0),
    ('AVG', 56.0),
    ('OBP', 56.0),
    ('SLG', 56.0),
    ('OPS', 60.0),
    ('HR', 44.0),
    ('RBI', 44.0),
    ('R', 44.0),
    ('SB', 44.0),
  ];
  static const double _totalWidth = 64 + 44 + 56 + 56 + 56 + 60 + 44 + 44 + 44 + 44;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const Center(child: Text('데이터 없음'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _totalWidth).clamp(1.0, 2.0);
        final fs = 13.0 * scale.clamp(1.0, 1.3);

        return Column(
          children: [
            // 헤더
            _buildHeader(context, scale, fs),
            // 데이터
            Expanded(
              child: ListView.builder(
                itemCount: teams.length,
                itemBuilder: (ctx, i) => _buildRow(ctx, teams[i], i, scale, fs),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double scale, double fs) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: _cols.map((c) {
          final (label, w) = c;
          return SizedBox(
            width: w * scale,
            height: 38,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontSize: fs - 1,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, TeamHitter t, int i, double scale, double fs) {
    final bg = i % 2 == 0
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Theme.of(context).colorScheme.surface;

    return Container(
      color: bg,
      child: Row(
        children: [
          _c(t.team, 64 * scale, fs, bold: true),
          _c('${t.games}', 44 * scale, fs),
          _c(t.avg.toStringAsFixed(3), 56 * scale, fs),
          _c(t.obp.toStringAsFixed(3), 56 * scale, fs),
          _c(t.slg.toStringAsFixed(3), 56 * scale, fs),
          _c(t.ops.toStringAsFixed(3), 60 * scale, fs, bold: true, color: const Color(0xFF1B3A6B)),
          _c('${t.hr}', 44 * scale, fs),
          _c('${t.rbi}', 44 * scale, fs),
          _c('${t.runs}', 44 * scale, fs),
          _c('${t.sb}', 44 * scale, fs),
        ],
      ),
    );
  }

  Widget _c(String text, double w, double fs, {bool bold = false, Color? color}) {
    return SizedBox(
      width: w,
      height: 38,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── 팀 투수 ──────────────────────────────────────────────────────────────────────

class _TeamPitcherTable extends StatelessWidget {
  final List<TeamPitcher> teams;
  const _TeamPitcherTable({required this.teams});

  static const _cols = [
    ('팀', 64.0),
    ('G', 44.0),
    ('W', 44.0),
    ('L', 44.0),
    ('ERA', 60.0),
    ('WHIP', 60.0),
    ('K', 48.0),
    ('BB', 48.0),
    ('HR', 48.0),
    ('IP', 60.0),
  ];
  static const double _totalWidth = 64 + 44 + 44 + 44 + 60 + 60 + 48 + 48 + 48 + 60;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const Center(child: Text('데이터 없음'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _totalWidth).clamp(1.0, 2.0);
        final fs = 13.0 * scale.clamp(1.0, 1.3);

        return Column(
          children: [
            _buildHeader(context, scale, fs),
            Expanded(
              child: ListView.builder(
                itemCount: teams.length,
                itemBuilder: (ctx, i) => _buildRow(ctx, teams[i], i, scale, fs),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, double scale, double fs) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: _cols.map((c) {
          final (label, w) = c;
          return SizedBox(
            width: w * scale,
            height: 38,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontSize: fs - 1,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, TeamPitcher t, int i, double scale, double fs) {
    final bg = i % 2 == 0
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Theme.of(context).colorScheme.surface;

    return Container(
      color: bg,
      child: Row(
        children: [
          _c(t.team, 64 * scale, fs, bold: true),
          _c('${t.games}', 44 * scale, fs),
          _c('${t.wins}', 44 * scale, fs),
          _c('${t.losses}', 44 * scale, fs),
          _c(t.era.toStringAsFixed(2), 60 * scale, fs, bold: true, color: const Color(0xFF1B3A6B)),
          _c(t.whip.toStringAsFixed(2), 60 * scale, fs),
          _c('${t.so}', 48 * scale, fs),
          _c('${t.bb}', 48 * scale, fs),
          _c('${t.hr}', 48 * scale, fs),
          _c(t.ip.toStringAsFixed(1), 60 * scale, fs),
        ],
      ),
    );
  }

  Widget _c(String text, double w, double fs, {bool bold = false, Color? color}) {
    return SizedBox(
      width: w,
      height: 38,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
