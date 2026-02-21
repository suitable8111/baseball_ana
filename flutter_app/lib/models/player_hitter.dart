class PlayerHitter {
  final String name;
  final String team;
  final int games;
  final int pa;       // 타석
  final int ab;       // 타수
  final int runs;     // 득점
  final int hits;     // 안타
  final int doubles;  // 2루타
  final int triples;  // 3루타
  final int hr;       // 홈런
  final int rbi;      // 타점
  final int sb;       // 도루
  final int cs;       // 도루실패
  final int bb;       // 볼넷
  final int hbp;      // 사구
  final int so;       // 삼진
  final int dp;       // 병살
  final double avg;   // 타율
  final double obp;   // 출루율
  final double slg;   // 장타율
  final double ops;   // OPS
  final int season;

  const PlayerHitter({
    required this.name,
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
    required this.cs,
    required this.bb,
    required this.hbp,
    required this.so,
    required this.dp,
    required this.avg,
    required this.obp,
    required this.slg,
    required this.ops,
    required this.season,
  });

  // 고급 지표 (계산)
  double get babip {
    final denom = ab - so - hr + (pa - ab - bb - hbp);
    if (denom <= 0) return 0;
    return (hits - hr) / denom;
  }

  double get iso => slg - avg;

  double get bbPct => pa > 0 ? bb / pa : 0;

  double get kPct => pa > 0 ? so / pa : 0;

  int get singles => hits - doubles - triples - hr;

  factory PlayerHitter.fromMap(Map<String, dynamic> map) {
    return PlayerHitter(
      name: map['name'] ?? '',
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
      cs: map['cs'] ?? 0,
      bb: map['bb'] ?? 0,
      hbp: map['hbp'] ?? 0,
      so: map['so'] ?? 0,
      dp: map['dp'] ?? 0,
      avg: (map['avg'] ?? 0).toDouble(),
      obp: (map['obp'] ?? 0).toDouble(),
      slg: (map['slg'] ?? 0).toDouble(),
      ops: (map['ops'] ?? 0).toDouble(),
      season: map['season'] ?? 2024,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'team': team,
      'games': games,
      'pa': pa,
      'ab': ab,
      'runs': runs,
      'hits': hits,
      'doubles': doubles,
      'triples': triples,
      'hr': hr,
      'rbi': rbi,
      'sb': sb,
      'cs': cs,
      'bb': bb,
      'hbp': hbp,
      'so': so,
      'dp': dp,
      'avg': avg,
      'obp': obp,
      'slg': slg,
      'ops': ops,
      'season': season,
    };
  }
}
