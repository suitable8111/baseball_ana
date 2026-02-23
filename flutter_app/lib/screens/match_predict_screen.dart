import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/prediction_provider.dart';
import '../providers/filter_provider.dart';
import '../models/player_pitcher.dart';
import '../models/simulation_models.dart';

class MatchPredictScreen extends StatelessWidget {
  const MatchPredictScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PredictionProvider>();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectionCard(provider: provider),
          const SizedBox(height: 12),
          _RunButton(provider: provider),
          const SizedBox(height: 16),
          if (provider.isLoading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(child: Text('시뮬레이션 중... (10,000회)', style: TextStyle(color: Colors.grey))),
          ] else if (provider.error != null)
            _ErrorCard(message: provider.error!)
          else if (provider.result != null)
            _ResultPanel(result: provider.result!),
        ],
      ),
        ),
      ),
    );
  }
}

// ── 팀/투수 선택 카드 ────────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final PredictionProvider provider;
  const _SelectionCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final teams = kboTeams.where((t) => t != '전체').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 팀 선택 행
            Row(
              children: [
                Expanded(
                  child: _TeamDropdown(
                    label: '홈팀',
                    value: provider.homeTeam,
                    teams: teams,
                    onChanged: provider.setHomeTeam,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Expanded(
                  child: _TeamDropdown(
                    label: '원정팀',
                    value: provider.awayTeam,
                    teams: teams,
                    onChanged: provider.setAwayTeam,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 투수 선택 행
            Row(
              children: [
                Expanded(
                  child: _PitcherDropdown(
                    label: '홈 선발',
                    selected: provider.homePitcher,
                    pitchers: provider.pitchersFor(provider.homeTeam),
                    onChanged: provider.setHomePitcher,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _PitcherDropdown(
                    label: '원정 선발',
                    selected: provider.awayPitcher,
                    pitchers: provider.pitchersFor(provider.awayTeam),
                    onChanged: provider.setAwayPitcher,
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

class _TeamDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> teams;
  final ValueChanged<String> onChanged;

  const _TeamDropdown({
    required this.label,
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = teams.contains(value) ? value : teams.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        _DropdownField(
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            underline: const SizedBox(),
            items: teams
                .map((t) => DropdownMenuItem(
                    value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (t) { if (t != null) onChanged(t); },
          ),
        ),
      ],
    );
  }
}

class _PitcherDropdown extends StatelessWidget {
  final String label;
  final PlayerPitcher? selected;
  final List<PlayerPitcher> pitchers;
  final ValueChanged<PlayerPitcher> onChanged;

  const _PitcherDropdown({
    required this.label,
    required this.selected,
    required this.pitchers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = (selected != null && pitchers.any((p) => p.name == selected!.name))
        ? selected
        : (pitchers.isNotEmpty ? pitchers.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        _DropdownField(
          child: DropdownButton<PlayerPitcher>(
            value: current,
            isExpanded: true,
            underline: const SizedBox(),
            items: pitchers
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        '${p.name} (${p.era.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (p) { if (p != null) onChanged(p); },
          ),
        ),
      ],
    );
  }
}

// ── 드롭다운 테두리 래퍼 ──────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final Widget child;
  const _DropdownField({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

// ── 실행 버튼 ────────────────────────────────────────────────────────────────────

class _RunButton extends StatelessWidget {
  final PredictionProvider provider;
  const _RunButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: provider.isLoading ? null : () => provider.runSimulation(),
      icon: const Icon(Icons.play_arrow),
      label: const Text('승부 예측 시뮬레이션 실행 (10,000회)'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ── 오류 카드 ────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('오류: $message',
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      ),
    );
  }
}

// ── 결과 패널 ────────────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final SimulationResult result;
  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WinProbCard(result: result),
        const SizedBox(height: 12),
        _ScoreDistCard(result: result),
        const SizedBox(height: 8),
        Text(
          '시뮬레이션 ${result.iterations ~/ 1000}천 회 기준 | Log-5 알고리즘',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

// ── 승리 확률 카드 ──────────────────────────────────────────────────────────────

class _WinProbCard extends StatelessWidget {
  final SimulationResult result;
  const _WinProbCard({required this.result});

  static const Color _homeColor = Color(0xFF1B3A6B);
  static const Color _awayColor = Color(0xFFB71C1C);

  @override
  Widget build(BuildContext context) {
    final hw = result.homeWinProb;
    final aw = result.awayWinProb;
    final tw = result.tieProb;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 팀명 + 예상 점수
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamLabel(result.homeTeam, '홈', _homeColor),
                Column(
                  children: [
                    Text(
                      '${result.homeAvgScore.toStringAsFixed(1)} : ${result.awayAvgScore.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Text('예상 득점', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                _teamLabel(result.awayTeam, '원정', _awayColor),
              ],
            ),
            const SizedBox(height: 16),
            // 승리 확률 바
            _WinProbBar(homeProb: hw, awayProb: aw, tieProb: tw),
            const SizedBox(height: 8),
            // 확률 숫자
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _probLabel('${(hw * 100).toStringAsFixed(1)}%', '홈 승', _homeColor),
                _probLabel('${(tw * 100).toStringAsFixed(1)}%', '무', Colors.grey),
                _probLabel('${(aw * 100).toStringAsFixed(1)}%', '원정 승', _awayColor),
              ],
            ),
            const SizedBox(height: 12),
            // 선발 투수
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('선발: ${result.homePitcher}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('선발: ${result.awayPitcher}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamLabel(String team, String role, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(team,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _probLabel(String pct, String label, Color color) {
    return Column(
      children: [
        Text(pct, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _WinProbBar extends StatelessWidget {
  final double homeProb;
  final double awayProb;
  final double tieProb;

  const _WinProbBar({
    required this.homeProb,
    required this.awayProb,
    required this.tieProb,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            Expanded(
              flex: (homeProb * 1000).round(),
              child: Container(color: const Color(0xFF1B3A6B)),
            ),
            Expanded(
              flex: (tieProb * 1000).round(),
              child: Container(color: Colors.grey.shade400),
            ),
            Expanded(
              flex: (awayProb * 1000).round(),
              child: Container(color: const Color(0xFFB71C1C)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 득점 분포 카드 ──────────────────────────────────────────────────────────────

class _ScoreDistCard extends StatelessWidget {
  final SimulationResult result;
  const _ScoreDistCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('득점 분포', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              children: [
                _dot(const Color(0xFF1B3A6B)),
                const SizedBox(width: 4),
                Text(result.homeTeam, style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
                _dot(const Color(0xFFB71C1C)),
                const SizedBox(width: 4),
                Text(result.awayTeam, style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _ScoreBarChart(
                homeDist: result.homeScoreDist,
                awayDist: result.awayScoreDist,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
      width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _ScoreBarChart extends StatelessWidget {
  final Map<int, double> homeDist;
  final Map<int, double> awayDist;

  const _ScoreBarChart({required this.homeDist, required this.awayDist});

  @override
  Widget build(BuildContext context) {
    // 0~최대점수 범위
    final allKeys = {...homeDist.keys, ...awayDist.keys};
    if (allKeys.isEmpty) return const SizedBox.shrink();

    final maxScore = allKeys.reduce((a, b) => a > b ? a : b);
    final minScore = 0;

    final barGroups = <BarChartGroupData>[];
    for (int s = minScore; s <= maxScore; s++) {
      barGroups.add(BarChartGroupData(
        x: s,
        barRods: [
          BarChartRodData(
            toY: (homeDist[s] ?? 0) * 100,
            color: const Color(0xFF1B3A6B),
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          BarChartRodData(
            toY: (awayDist[s] ?? 0) * 100,
            color: const Color(0xFFB71C1C),
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
        barsSpace: 2,
      ));
    }

    final maxY = [...homeDist.values, ...awayDist.values].fold(0.0, (m, v) => v > m ? v : m) * 100;

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        maxY: (maxY * 1.2).clamp(5, 40),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawHorizontalLine: true,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) {
              final score = group.x;
              final label = rodIndex == 0 ? '홈' : '원정';
              return BarTooltipItem(
                '$score점 $label\n${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }
}
