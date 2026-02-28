import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accuracy_provider.dart';
import '../models/game_schedule.dart';

class AccuracyScreen extends StatelessWidget {
  const AccuracyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예측 정확도'),
        centerTitle: true,
      ),
      body: const _AccuracyBody(),
    );
  }
}

class _AccuracyBody extends StatelessWidget {
  const _AccuracyBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AccuracyProvider>();

    return Column(
      children: [
        _MonthBar(prov: prov),
        if (prov.loading) _ProgressSection(prov: prov),
        if (!prov.loading && prov.records.isNotEmpty)
          _SummaryCard(prov: prov),
        if (prov.error != null) _ErrorSection(error: prov.error!),
        if (prov.records.isNotEmpty)
          Expanded(child: _GameList(records: prov.records)),
      ],
    );
  }
}

// ─── 월 선택 바 ───────────────────────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  final AccuracyProvider prov;
  const _MonthBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    final label = '${prov.year}년 ${prov.month}월';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: prov.loading ? null : prov.prevMonth,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: prov.loading ? null : prov.nextMonth,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          prov.loading
              ? OutlinedButton.icon(
                  onPressed: prov.cancel,
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('취소'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                )
              : FilledButton.icon(
                  onPressed: () =>
                      context.read<AccuracyProvider>().loadMonth(),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('분석 시작'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── 진행률 섹션 ───────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final AccuracyProvider prov;
  const _ProgressSection({required this.prov});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = prov.total > 0 ? prov.processed / prov.total : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 6),
          Text(
            '분석 중… ${prov.processed} / ${prov.total} 경기',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }
}

// ─── 에러 섹션 ────────────────────────────────────────────────────────────────

class _ErrorSection extends StatelessWidget {
  final String error;
  const _ErrorSection({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 요약 카드 ────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final AccuracyProvider prov;
  const _SummaryCard({required this.prov});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (prov.accuracy * 100).round();
    final label = '${prov.year}년 ${prov.month}월 예측 정확도';

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.outline)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${prov.correctCount} / ${prov.evaluatedCount} 경기 적중',
                    style: TextStyle(fontSize: 14, color: cs.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: prov.accuracy,
                minHeight: 12,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 날짜별 그룹 게임 리스트 ──────────────────────────────────────────────────

class _GameList extends StatelessWidget {
  final List<GameAccuracyRecord> records;
  const _GameList({required this.records});

  @override
  Widget build(BuildContext context) {
    // 날짜별 그룹화 (YYYYMMDD 정렬)
    final Map<String, List<GameAccuracyRecord>> grouped = {};
    for (final r in records) {
      (grouped[r.gameDate] ??= []).add(r);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: dates.length,
      itemBuilder: (context, i) {
        final date = dates[i];
        final dayRecords = grouped[date]!;
        return _DateGroup(date: date, records: dayRecords);
      },
    );
  }
}

class _DateGroup extends StatelessWidget {
  final String date; // YYYYMMDD
  final List<GameAccuracyRecord> records;
  const _DateGroup({required this.date, required this.records});

  String _formatDate(String d) {
    if (d.length != 8) return d;
    final month = d.substring(4, 6);
    final day = d.substring(6, 8);
    try {
      final dt = DateTime(
          int.parse(d.substring(0, 4)),
          int.parse(month),
          int.parse(day));
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return '$month.$day (${weekdays[dt.weekday - 1]})';
    } catch (_) {
      return '$month.$day';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 날짜 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(
                _formatDate(date),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.outline),
              ),
              const Expanded(child: Divider(indent: 8)),
            ],
          ),
        ),
        for (final record in records) _GameRow(record: record),
      ],
    );
  }
}

// ─── 개별 경기 행 ────────────────────────────────────────────────────────────

class _GameRow extends StatelessWidget {
  final GameAccuracyRecord record;
  const _GameRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final awayPct = (record.awayWinProb * 100).round();
    final homePct = (record.homeWinProb * 100).round();
    final isCorrect = record.isCorrect;
    final hasResult = record.actualWinner != null;

    // 바 색상 결정
    Color awayColor;
    Color homeColor;

    if (!hasResult) {
      awayColor = Colors.redAccent;
      homeColor = const Color(0xFF1B3A6B);
    } else if (isCorrect) {
      awayColor = record.actualWinner == 'away'
          ? Colors.redAccent
          : cs.outlineVariant;
      homeColor = record.actualWinner == 'home'
          ? const Color(0xFF1B3A6B)
          : cs.outlineVariant;
    } else {
      // 오답: 실제 승자=파랑, 잘못 예측한 쪽=빨강
      awayColor = record.actualWinner == 'away'
          ? Colors.blue
          : (record.predictedWinner == 'away' ? Colors.red : cs.outlineVariant);
      homeColor = record.actualWinner == 'home'
          ? Colors.blue
          : (record.predictedWinner == 'home' ? Colors.red : cs.outlineVariant);
    }

    // 배지
    Widget badge;
    if (!hasResult) {
      badge = const SizedBox.shrink();
    } else if (isCorrect) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '✓',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green),
        ),
      );
    } else {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '✗',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 원정팀
          SizedBox(
            width: 44,
            child: Text(
              record.awayTeam,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: record.actualWinner == 'away' ? cs.primary : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // 확률 바
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 22,
                child: Row(
                  children: [
                    Expanded(
                      flex: awayPct,
                      child: Container(
                        color: awayColor,
                        alignment: Alignment.center,
                        child: Text(
                          '$awayPct%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: homePct,
                      child: Container(
                        color: homeColor,
                        alignment: Alignment.center,
                        child: Text(
                          '$homePct%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 홈팀
          SizedBox(
            width: 44,
            child: Text(
              record.homeTeam,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: record.actualWinner == 'home' ? cs.primary : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 배지
          SizedBox(width: 28, child: badge),
        ],
      ),
    );
  }
}
