class TeamStanding {
  final int rank;
  final String team;
  final int games;
  final int wins;
  final int losses;
  final int ties;
  final double pct;
  final double gb;
  final String last10;
  final String streak;
  final int homeW;
  final int homeT;
  final int homeL;
  final int awayW;
  final int awayT;
  final int awayL;
  final int season;

  const TeamStanding({
    required this.rank,
    required this.team,
    required this.games,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.pct,
    required this.gb,
    required this.last10,
    required this.streak,
    required this.homeW,
    required this.homeT,
    required this.homeL,
    required this.awayW,
    required this.awayT,
    required this.awayL,
    required this.season,
  });

  factory TeamStanding.fromMap(Map<String, dynamic> m) => TeamStanding(
        rank: m['rank'] as int? ?? 0,
        team: m['team'] as String? ?? '',
        games: m['games'] as int? ?? 0,
        wins: m['wins'] as int? ?? 0,
        losses: m['losses'] as int? ?? 0,
        ties: m['ties'] as int? ?? 0,
        pct: (m['pct'] as num?)?.toDouble() ?? 0.0,
        gb: (m['gb'] as num?)?.toDouble() ?? 0.0,
        last10: m['last10'] as String? ?? '',
        streak: m['streak'] as String? ?? '',
        homeW: m['home_w'] as int? ?? 0,
        homeT: m['home_t'] as int? ?? 0,
        homeL: m['home_l'] as int? ?? 0,
        awayW: m['away_w'] as int? ?? 0,
        awayT: m['away_t'] as int? ?? 0,
        awayL: m['away_l'] as int? ?? 0,
        season: m['season'] as int? ?? 0,
      );

  String get homeRecord => '$homeW-$homeT-$homeL';
  String get awayRecord => '$awayW-$awayT-$awayL';
  String get wltRecord => '$wins-$losses-$ties';
}

class MatchupRecord {
  final int w;
  final int l;
  final int t;

  const MatchupRecord({required this.w, required this.l, required this.t});

  factory MatchupRecord.fromMap(Map<String, dynamic> m) => MatchupRecord(
        w: m['w'] as int? ?? 0,
        l: m['l'] as int? ?? 0,
        t: m['t'] as int? ?? 0,
      );

  int get total => w + l + t;
  double get winPct => total > 0 ? w / total : 0.0;
  String get record => '$w-$l-$t';
}

class HeadToHead {
  final String team;
  final Map<String, MatchupRecord?> matchups;
  final int totalW;
  final int totalL;
  final int totalT;
  final int season;

  const HeadToHead({
    required this.team,
    required this.matchups,
    required this.totalW,
    required this.totalL,
    required this.totalT,
    required this.season,
  });

  factory HeadToHead.fromMap(Map<String, dynamic> m) {
    final matchupsRaw = m['matchups'] as Map<String, dynamic>? ?? {};
    final matchups = <String, MatchupRecord?>{};
    for (final entry in matchupsRaw.entries) {
      if (entry.value == null) {
        matchups[entry.key] = null;
      } else {
        matchups[entry.key] =
            MatchupRecord.fromMap(entry.value as Map<String, dynamic>);
      }
    }
    return HeadToHead(
      team: m['team'] as String? ?? '',
      matchups: matchups,
      totalW: m['total_w'] as int? ?? 0,
      totalL: m['total_l'] as int? ?? 0,
      totalT: m['total_t'] as int? ?? 0,
      season: m['season'] as int? ?? 0,
    );
  }

  String get totalRecord => '$totalW-$totalL-$totalT';
}
