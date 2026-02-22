// 몬테카를로 시뮬레이션 데이터 모델

class BatterProfile {
  final String name;
  final String team;
  final double hr;      // per PA
  final double triple;
  final double dbl;
  final double single;
  final double bb;      // bb + hbp per PA
  final double so;

  const BatterProfile({
    required this.name,
    required this.team,
    required this.hr,
    required this.triple,
    required this.dbl,
    required this.single,
    required this.bb,
    required this.so,
  });

  double get out =>
      (1.0 - hr - triple - dbl - single - bb - so).clamp(0.0, 1.0);

  Map<String, double> toMap() => {
        'hr': hr,
        'triple': triple,
        'dbl': dbl,
        'single': single,
        'bb': bb,
        'so': so,
      };

  factory BatterProfile.fromPlayerMap(Map<String, dynamic> h) {
    final pa = (h['pa'] as num).toDouble();
    if (pa <= 0) {
      return BatterProfile(
          name: h['name'] ?? '', team: h['team'] ?? '',
          hr: 0, triple: 0, dbl: 0, single: 0, bb: 0, so: 0);
    }
    final hits = (h['hits'] as num? ?? 0).toDouble();
    final d = (h['doubles'] as num? ?? 0).toDouble();
    final t = (h['triples'] as num? ?? 0).toDouble();
    final hr = (h['hr'] as num? ?? 0).toDouble();
    final sng = (hits - d - t - hr).clamp(0.0, double.infinity);
    final bb = ((h['bb'] as num? ?? 0) + (h['hbp'] as num? ?? 0)).toDouble();
    final so = (h['so'] as num? ?? 0).toDouble();
    return BatterProfile(
      name: h['name'] ?? '',
      team: h['team'] ?? '',
      hr: hr / pa,
      triple: t / pa,
      dbl: d / pa,
      single: sng / pa,
      bb: bb / pa,
      so: so / pa,
    );
  }
}

class PitcherProfile {
  final String name;
  final String team;
  final double hr;
  final double triple;
  final double dbl;
  final double single;
  final double bb;
  final double so;

  const PitcherProfile({
    required this.name,
    required this.team,
    required this.hr,
    required this.triple,
    required this.dbl,
    required this.single,
    required this.bb,
    required this.so,
  });

  Map<String, double> toMap() => {
        'hr': hr,
        'triple': triple,
        'dbl': dbl,
        'single': single,
        'bb': bb,
        'so': so,
      };

  /// [league] 리그 평균, 투수 JSON 데이터로부터 프로파일 생성
  factory PitcherProfile.fromPlayerMap(
      Map<String, dynamic> p, LeagueAvg league) {
    final ip = (p['ip'] as num? ?? 0).toDouble();
    final hits = (p['hits'] as num? ?? 0).toDouble();
    final hr = (p['hr'] as num? ?? 0).toDouble();
    final bb =
        ((p['bb'] as num? ?? 0) + (p['hbp'] as num? ?? 0)).toDouble();
    final so = (p['so'] as num? ?? 0).toDouble();

    // TBF 추정 (tbf 필드 0인 경우)
    double tbf = (p['tbf'] as num? ?? 0).toDouble();
    if (tbf <= 0) tbf = (3 * ip + hits + bb).clamp(1.0, double.infinity);

    final hrRate = hr / tbf;
    final bbRate = bb / tbf;
    final soRate = so / tbf;

    // 비홈런 안타를 리그 비율로 분배
    final nonHrHits = (hits - hr).clamp(0.0, double.infinity);
    final hitRate = nonHrHits / tbf;
    final lgHit = league.single + league.dbl + league.triple;
    double sngRate, dblRate, triRate;
    if (lgHit > 0) {
      sngRate = hitRate * (league.single / lgHit);
      dblRate = hitRate * (league.dbl / lgHit);
      triRate = hitRate * (league.triple / lgHit);
    } else {
      sngRate = hitRate * 0.78;
      dblRate = hitRate * 0.20;
      triRate = hitRate * 0.02;
    }

    return PitcherProfile(
      name: p['name'] ?? '',
      team: p['team'] ?? '',
      hr: hrRate,
      triple: triRate,
      dbl: dblRate,
      single: sngRate,
      bb: bbRate,
      so: soRate,
    );
  }
}

class LeagueAvg {
  final double hr;
  final double triple;
  final double dbl;
  final double single;
  final double bb;
  final double so;

  const LeagueAvg({
    required this.hr,
    required this.triple,
    required this.dbl,
    required this.single,
    required this.bb,
    required this.so,
  });

  static LeagueAvg fromHitters(List<Map<String, dynamic>> hitters) {
    final totalPa =
        hitters.fold<double>(0, (s, h) => s + (h['pa'] as num? ?? 0));
    if (totalPa <= 0) {
      return const LeagueAvg(
          hr: 0.027, triple: 0.004, dbl: 0.045, single: 0.172, bb: 0.113, so: 0.168);
    }
    double hr = 0, triple = 0, dbl = 0, single = 0, bb = 0, so = 0;
    for (final h in hitters) {
      final hits = (h['hits'] as num? ?? 0).toDouble();
      final d = (h['doubles'] as num? ?? 0).toDouble();
      final t = (h['triples'] as num? ?? 0).toDouble();
      final h2 = (h['hr'] as num? ?? 0).toDouble();
      hr += h2;
      triple += t;
      dbl += d;
      single += (hits - d - t - h2).clamp(0.0, double.infinity);
      bb += ((h['bb'] as num? ?? 0) + (h['hbp'] as num? ?? 0)).toDouble();
      so += (h['so'] as num? ?? 0).toDouble();
    }
    return LeagueAvg(
      hr: hr / totalPa,
      triple: triple / totalPa,
      dbl: dbl / totalPa,
      single: single / totalPa,
      bb: bb / totalPa,
      so: so / totalPa,
    );
  }

  Map<String, double> toMap() => {
        'hr': hr,
        'triple': triple,
        'dbl': dbl,
        'single': single,
        'bb': bb,
        'so': so,
      };

  factory LeagueAvg.fromMap(Map<String, double> m) => LeagueAvg(
        hr: m['hr'] ?? 0.027,
        triple: m['triple'] ?? 0.004,
        dbl: m['dbl'] ?? 0.045,
        single: m['single'] ?? 0.172,
        bb: m['bb'] ?? 0.113,
        so: m['so'] ?? 0.168,
      );
}

class SimulationResult {
  final String homeTeam;
  final String awayTeam;
  final String homePitcher;
  final String awayPitcher;
  final int iterations;
  final int homeWins;
  final int awayWins;
  final int ties;
  final double homeAvgScore;
  final double awayAvgScore;
  final Map<int, double> homeScoreDist;
  final Map<int, double> awayScoreDist;

  const SimulationResult({
    required this.homeTeam,
    required this.awayTeam,
    required this.homePitcher,
    required this.awayPitcher,
    required this.iterations,
    required this.homeWins,
    required this.awayWins,
    required this.ties,
    required this.homeAvgScore,
    required this.awayAvgScore,
    required this.homeScoreDist,
    required this.awayScoreDist,
  });

  double get homeWinProb => iterations > 0 ? homeWins / iterations : 0;
  double get awayWinProb => iterations > 0 ? awayWins / iterations : 0;
  double get tieProb => iterations > 0 ? ties / iterations : 0;
}
