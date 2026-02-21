class PlayerPitcher {
  final String name;
  final String team;
  final int games;
  final int wins;
  final int losses;
  final int saves;
  final int holds;
  final double ip;      // 이닝
  final int hits;       // 피안타
  final int hr;         // 피홈런
  final int bb;         // 볼넷
  final int hbp;        // 사구
  final int so;         // 삼진
  final int runs;       // 실점
  final int er;         // 자책점
  final double era;     // 평균자책점
  final double whip;    // WHIP
  final int season;

  const PlayerPitcher({
    required this.name,
    required this.team,
    required this.games,
    required this.wins,
    required this.losses,
    required this.saves,
    required this.holds,
    required this.ip,
    required this.hits,
    required this.hr,
    required this.bb,
    required this.hbp,
    required this.so,
    required this.runs,
    required this.er,
    required this.era,
    required this.whip,
    required this.season,
  });

  // 고급 지표
  double get k9 => ip > 0 ? 9 * so / ip : 0;
  double get bb9 => ip > 0 ? 9 * bb / ip : 0;
  double get hr9 => ip > 0 ? 9 * hr / ip : 0;
  double get kbb => bb > 0 ? so / bb : 0;

  // FIP 상수는 시즌별로 다르나, KBO 평균값 4.0 사용
  double get fip {
    if (ip <= 0) return 0;
    const fipConst = 3.20;
    return (13 * hr + 3 * (bb + hbp) - 2 * so) / ip + fipConst;
  }

  factory PlayerPitcher.fromMap(Map<String, dynamic> map) {
    return PlayerPitcher(
      name: map['name'] ?? '',
      team: map['team'] ?? '',
      games: map['games'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      saves: map['saves'] ?? 0,
      holds: map['holds'] ?? 0,
      ip: (map['ip'] ?? 0).toDouble(),
      hits: map['hits'] ?? 0,
      hr: map['hr'] ?? 0,
      bb: map['bb'] ?? 0,
      hbp: map['hbp'] ?? 0,
      so: map['so'] ?? 0,
      runs: map['runs'] ?? 0,
      er: map['er'] ?? 0,
      era: (map['era'] ?? 0).toDouble(),
      whip: (map['whip'] ?? 0).toDouble(),
      season: map['season'] ?? 2024,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'team': team,
      'games': games,
      'wins': wins,
      'losses': losses,
      'saves': saves,
      'holds': holds,
      'ip': ip,
      'hits': hits,
      'hr': hr,
      'bb': bb,
      'hbp': hbp,
      'so': so,
      'runs': runs,
      'er': er,
      'era': era,
      'whip': whip,
      'season': season,
    };
  }
}
