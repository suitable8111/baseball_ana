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

class _TeamHitterTable extends StatelessWidget {
  final List<TeamHitter> teams;

  const _TeamHitterTable({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const Center(child: Text('데이터 없음'));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer,
        ),
        columns: const [
          DataColumn(label: Text('팀', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('G'), numeric: true),
          DataColumn(label: Text('AVG'), numeric: true),
          DataColumn(label: Text('OBP'), numeric: true),
          DataColumn(label: Text('SLG'), numeric: true),
          DataColumn(label: Text('OPS'), numeric: true),
          DataColumn(label: Text('HR'), numeric: true),
          DataColumn(label: Text('RBI'), numeric: true),
          DataColumn(label: Text('R'), numeric: true),
          DataColumn(label: Text('SB'), numeric: true),
        ],
        rows: teams.map((t) => DataRow(cells: [
          DataCell(Text(t.team, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${t.games}')),
          DataCell(Text(t.avg.toStringAsFixed(3))),
          DataCell(Text(t.obp.toStringAsFixed(3))),
          DataCell(Text(t.slg.toStringAsFixed(3))),
          DataCell(Text(t.ops.toStringAsFixed(3),
              style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${t.hr}')),
          DataCell(Text('${t.rbi}')),
          DataCell(Text('${t.runs}')),
          DataCell(Text('${t.sb}')),
        ])).toList(),
      ),
    );
  }
}

class _TeamPitcherTable extends StatelessWidget {
  final List<TeamPitcher> teams;

  const _TeamPitcherTable({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const Center(child: Text('데이터 없음'));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer,
        ),
        columns: const [
          DataColumn(label: Text('팀', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('G'), numeric: true),
          DataColumn(label: Text('W'), numeric: true),
          DataColumn(label: Text('L'), numeric: true),
          DataColumn(label: Text('ERA'), numeric: true),
          DataColumn(label: Text('WHIP'), numeric: true),
          DataColumn(label: Text('K'), numeric: true),
          DataColumn(label: Text('BB'), numeric: true),
          DataColumn(label: Text('HR'), numeric: true),
          DataColumn(label: Text('IP'), numeric: true),
        ],
        rows: teams.map((t) => DataRow(cells: [
          DataCell(Text(t.team, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text('${t.games}')),
          DataCell(Text('${t.wins}')),
          DataCell(Text('${t.losses}')),
          DataCell(Text(t.era.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(t.whip.toStringAsFixed(2))),
          DataCell(Text('${t.so}')),
          DataCell(Text('${t.bb}')),
          DataCell(Text('${t.hr}')),
          DataCell(Text(t.ip.toStringAsFixed(1))),
        ])).toList(),
      ),
    );
  }
}
