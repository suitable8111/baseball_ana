class TeamHitter {
  final String team;
  final int games;
  final int pa;
  final int ab;
  final int runs;
  final int hits;
  final int doubles;
  final int triples;
  final int hr;
  final int rbi;
  final int sb;
  final int bb;
  final int so;
  final double avg;
  final double obp;
  final double slg;
  final double ops;
  final int season;

  const TeamHitter({
    required this.team,
    required this.games,
    required this.pa,
    required this.ab,
    required this.runs,
    required this.hits,
    required this.doubles,
    required this.triples,
    required this.hr,
    required this.rbi,
    required this.sb,
    required this.bb,
    required this.so,
    required this.avg,
    required this.obp,
    required this.slg,
    required this.ops,
    required this.season,
  });

  factory TeamHitter.fromMap(Map<String, dynamic> map) {
    return TeamHitter(
      team: map['team'] ?? '',
      games: map['games'] ?? 0,
      pa: map['pa'] ?? 0,
      ab: map['ab'] ?? 0,
      runs: map['runs'] ?? 0,
      hits: map['hits'] ?? 0,
      doubles: map['doubles'] ?? 0,
      triples: map['triples'] ?? 0,
      hr: map['hr'] ?? 0,
      rbi: map['rbi'] ?? 0,
      sb: map['sb'] ?? 0,
      bb: map['bb'] ?? 0,
      so: map['so'] ?? 0,
      avg: (map['avg'] ?? 0).toDouble(),
      obp: (map['obp'] ?? 0).toDouble(),
      slg: (map['slg'] ?? 0).toDouble(),
      ops: (map['ops'] ?? 0).toDouble(),
      season: map['season'] ?? 2024,
    );
  }
}

class TeamPitcher {
  final String team;
  final int games;
  final int wins;
  final int losses;
  final int saves;
  final double ip;
  final int hits;
  final int hr;
  final int bb;
  final int so;
  final int er;
  final double era;
  final double whip;
  final int season;

  const TeamPitcher({
    required this.team,
    required this.games,
    required this.wins,
    required this.losses,
    required this.saves,
    required this.ip,
    required this.hits,
    required this.hr,
    required this.bb,
    required this.so,
    required this.er,
    required this.era,
    required this.whip,
    required this.season,
  });

  factory TeamPitcher.fromMap(Map<String, dynamic> map) {
    return TeamPitcher(
      team: map['team'] ?? '',
      games: map['games'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      saves: map['saves'] ?? 0,
      ip: (map['ip'] ?? 0).toDouble(),
      hits: map['hits'] ?? 0,
      hr: map['hr'] ?? 0,
      bb: map['bb'] ?? 0,
      so: map['so'] ?? 0,
      er: map['er'] ?? 0,
      era: (map['era'] ?? 0).toDouble(),
      whip: (map['whip'] ?? 0).toDouble(),
      season: map['season'] ?? 2024,
    );
  }
}
