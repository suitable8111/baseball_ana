import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/simulation_models.dart';

/// 몬테카를로 야구 경기 시뮬레이션 서비스
///
/// - Log-5 공식으로 타자/투수/리그평균을 결합해 타석별 확률 계산
/// - compute() 를 통해 별도 isolate 에서 실행 (UI 블로킹 없음)
class SimulationService {
  const SimulationService();

  /// 시뮬레이션 실행 (isolate 백그라운드)
  Future<SimulationResult> run({
    required List<BatterProfile> homeLineup,
    required List<BatterProfile> awayLineup,
    required PitcherProfile homePitcher,
    required PitcherProfile awayPitcher,
    required LeagueAvg league,
    int iterations = 10000,
  }) async {
    final args = <String, dynamic>{
      'homeLineup': homeLineup.map((b) => <String, dynamic>{'name': b.name, 'team': b.team, ...b.toMap()}).toList(),
      'awayLineup': awayLineup.map((b) => <String, dynamic>{'name': b.name, 'team': b.team, ...b.toMap()}).toList(),
      'homePitcher': <String, dynamic>{'name': homePitcher.name, 'team': homePitcher.team, ...homePitcher.toMap()},
      'awayPitcher': <String, dynamic>{'name': awayPitcher.name, 'team': awayPitcher.team, ...awayPitcher.toMap()},
      'league': league.toMap(),
      'iterations': iterations,
    };
    final raw = await compute<Map<String, dynamic>, Map<String, dynamic>>(
      _runSimulationIsolate, args);
    return parseSimulationResult(raw);
  }
}

// ── isolate 진입점 (top-level 필수) ──────────────────────────────────────────

Map<String, dynamic> _runSimulationIsolate(Map<String, dynamic> args) {
  final rand = Random();
  final iterations = args['iterations'] as int;

  final homeLineup = (args['homeLineup'] as List)
      .map((e) => _IsolateBatter.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  final awayLineup = (args['awayLineup'] as List)
      .map((e) => _IsolateBatter.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
  final homePitcher =
      _IsolatePitcher.fromMap(Map<String, dynamic>.from(args['homePitcher'] as Map));
  final awayPitcher =
      _IsolatePitcher.fromMap(Map<String, dynamic>.from(args['awayPitcher'] as Map));
  final league =
      _IsolateLeague.fromMap(Map<String, double>.from(args['league'] as Map));

  int homeWins = 0, awayWins = 0, ties = 0;
  double homeTotal = 0, awayTotal = 0;
  final homeDist = <int, int>{};
  final awayDist = <int, int>{};

  for (int i = 0; i < iterations; i++) {
    final r = _simulateGame(homeLineup, awayLineup, homePitcher, awayPitcher, league, rand);
    final hs = r[0], as_ = r[1];
    homeTotal += hs;
    awayTotal += as_;
    homeDist[hs] = (homeDist[hs] ?? 0) + 1;
    awayDist[as_] = (awayDist[as_] ?? 0) + 1;
    if (hs > as_) {
      homeWins++;
    } else if (as_ > hs) {
      awayWins++;
    } else {
      ties++;
    }
  }

  return {
    'homeTeam': homePitcher.team,
    'awayTeam': awayPitcher.team,
    'homePitcher': homePitcher.name,
    'awayPitcher': awayPitcher.name,
    'iterations': iterations,
    'homeWins': homeWins,
    'awayWins': awayWins,
    'ties': ties,
    'homeAvgScore': homeTotal / iterations,
    'awayAvgScore': awayTotal / iterations,
    'homeScoreDist': {for (final e in homeDist.entries) e.key: e.value / iterations},
    'awayScoreDist': {for (final e in awayDist.entries) e.key: e.value / iterations},
  };
}

/// isolate 내부에서 사용하는 경량 데이터 클래스들

class _IsolateBatter {
  final String name;
  final String team;
  final double hr, triple, dbl, single, bb, so;

  const _IsolateBatter(
      {required this.name,
      required this.team,
      required this.hr,
      required this.triple,
      required this.dbl,
      required this.single,
      required this.bb,
      required this.so});

  factory _IsolateBatter.fromMap(Map<String, dynamic> m) => _IsolateBatter(
        name: m['name'] as String? ?? '',
        team: m['team'] as String? ?? '',
        hr: (m['hr'] as num? ?? 0).toDouble(),
        triple: (m['triple'] as num? ?? 0).toDouble(),
        dbl: (m['dbl'] as num? ?? 0).toDouble(),
        single: (m['single'] as num? ?? 0).toDouble(),
        bb: (m['bb'] as num? ?? 0).toDouble(),
        so: (m['so'] as num? ?? 0).toDouble(),
      );
}

class _IsolatePitcher {
  final String name;
  final String team;
  final double hr, triple, dbl, single, bb, so;

  const _IsolatePitcher(
      {required this.name,
      required this.team,
      required this.hr,
      required this.triple,
      required this.dbl,
      required this.single,
      required this.bb,
      required this.so});

  factory _IsolatePitcher.fromMap(Map<String, dynamic> m) => _IsolatePitcher(
        name: m['name'] as String? ?? '',
        team: m['team'] as String? ?? '',
        hr: (m['hr'] as num? ?? 0).toDouble(),
        triple: (m['triple'] as num? ?? 0).toDouble(),
        dbl: (m['dbl'] as num? ?? 0).toDouble(),
        single: (m['single'] as num? ?? 0).toDouble(),
        bb: (m['bb'] as num? ?? 0).toDouble(),
        so: (m['so'] as num? ?? 0).toDouble(),
      );
}

class _IsolateLeague {
  final double hr, triple, dbl, single, bb, so;

  const _IsolateLeague(
      {required this.hr,
      required this.triple,
      required this.dbl,
      required this.single,
      required this.bb,
      required this.so});

  factory _IsolateLeague.fromMap(Map<String, double> m) => _IsolateLeague(
        hr: m['hr'] ?? 0.027,
        triple: m['triple'] ?? 0.004,
        dbl: m['dbl'] ?? 0.045,
        single: m['single'] ?? 0.172,
        bb: m['bb'] ?? 0.113,
        so: m['so'] ?? 0.168,
      );
}

// ── Log-5 공식 ──────────────────────────────────────────────────────────────

double _log5(double b, double p, double lg) {
  if (lg <= 0 || lg >= 1) return b;
  final num = (b * p) / lg;
  final den = num + ((1 - b) * (1 - p)) / (1 - lg);
  return den > 0 ? num / den : 0.0;
}

// ── 타석 결과 확률 계산 ─────────────────────────────────────────────────────────

List<double> _matchupProbs(
    _IsolateBatter b, _IsolatePitcher p, _IsolateLeague lg) {
  final hr     = _log5(b.hr,     p.hr,     lg.hr);
  final triple = _log5(b.triple, p.triple, lg.triple);
  final dbl    = _log5(b.dbl,    p.dbl,    lg.dbl);
  final single = _log5(b.single, p.single, lg.single);
  final bb     = _log5(b.bb,     p.bb,     lg.bb);
  final so     = _log5(b.so,     p.so,     lg.so);

  final totalEvent = hr + triple + dbl + single + bb + so;
  final out = (1.0 - totalEvent).clamp(0.0, 1.0);
  final total = totalEvent + out;
  if (total <= 0) return [0, 0, 0, 0, 0, 0, 1];
  // 순서: [hr, triple, dbl, single, bb, so, out]
  return [hr / total, triple / total, dbl / total, single / total, bb / total, so / total, out / total];
}

/// 난수로 타석 결과 인덱스 샘플링 (0=hr,1=triple,2=dbl,3=single,4=bb,5=so,6=out)
int _sampleEvent(List<double> probs, Random rand) {
  final r = rand.nextDouble();
  double cum = 0.0;
  for (int i = 0; i < probs.length; i++) {
    cum += probs[i];
    if (r <= cum) return i;
  }
  return 6; // out
}

// ── 주자 진루 처리 ──────────────────────────────────────────────────────────────

/// bases = [r1, r2, r3], 반환: (새 bases, 득점)
(List<bool>, int) _advanceRunners(List<bool> bases, int event, Random rand) {
  bool r1 = bases[0], r2 = bases[1], r3 = bases[2];
  int runs = 0;

  switch (event) {
    case 0: // HR
      runs = (r1 ? 1 : 0) + (r2 ? 1 : 0) + (r3 ? 1 : 0) + 1;
      return ([false, false, false], runs);

    case 1: // triple
      runs = (r1 ? 1 : 0) + (r2 ? 1 : 0) + (r3 ? 1 : 0);
      return ([false, false, true], runs);

    case 2: // double
      runs += (r3 ? 1 : 0) + (r2 ? 1 : 0);
      bool newR3 = false;
      if (r1) {
        if (rand.nextDouble() < 0.4) {
          newR3 = true;
        } else {
          runs++;
        }
      }
      return ([false, true, newR3], runs);

    case 3: // single
      runs += (r3 ? 1 : 0);
      bool newR3 = false;
      if (r2) {
        if (rand.nextDouble() < 0.4) {
          newR3 = true;
        } else {
          runs++;
        }
      }
      bool newR2 = r1;
      return ([true, newR2, newR3], runs);

    case 4: // bb / hbp
      if (r1 && r2 && r3) return ([true, true, true], 1);
      bool newR3b = r3 || (r1 && r2);
      bool newR2b = r2 || r1;
      return ([true, newR2b, newR3b], 0);

    default: // so, out
      return (bases, 0);
  }
}

// ── 이닝 시뮬레이션 ──────────────────────────────────────────────────────────────

(int, int) _simulateHalfInning(
  List<_IsolateBatter> lineup,
  _IsolatePitcher pitcher,
  _IsolateLeague league,
  int startBatter,
  Random rand,
) {
  int outs = 0, runs = 0;
  List<bool> bases = [false, false, false];
  int idx = startBatter;
  final n = lineup.length;

  while (outs < 3) {
    final batter = lineup[idx % n];
    final probs = _matchupProbs(batter, pitcher, league);
    final event = _sampleEvent(probs, rand);
    if (event >= 5) {
      outs++; // so(5) or out(6)
    } else {
      final result = _advanceRunners(bases, event, rand);
      bases = result.$1;
      runs += result.$2;
    }
    idx++;
  }
  return (runs, idx % n);
}

// ── 경기 시뮬레이션 ──────────────────────────────────────────────────────────────

List<int> _simulateGame(
  List<_IsolateBatter> homeLineup,
  List<_IsolateBatter> awayLineup,
  _IsolatePitcher homePitcher,
  _IsolatePitcher awayPitcher,
  _IsolateLeague league,
  Random rand,
) {
  int homeScore = 0, awayScore = 0;
  int homeBat = 0, awayBat = 0;

  for (int inning = 0; inning < 9; inning++) {
    // 원정 공격 (vs 홈 투수)
    final awayResult = _simulateHalfInning(awayLineup, homePitcher, league, awayBat, rand);
    awayScore += awayResult.$1;
    awayBat = awayResult.$2;
    // 홈 공격 (vs 원정 투수)
    final homeResult = _simulateHalfInning(homeLineup, awayPitcher, league, homeBat, rand);
    homeScore += homeResult.$1;
    homeBat = homeResult.$2;
  }
  return [homeScore, awayScore];
}

// ── SimulationResult 변환 헬퍼 ──────────────────────────────────────────────────

SimulationResult parseSimulationResult(Map<String, dynamic> raw) {
  final homeScoreDist = (raw['homeScoreDist'] as Map).map(
      (k, v) => MapEntry(k is int ? k : int.parse(k.toString()), (v as num).toDouble()));
  final awayScoreDist = (raw['awayScoreDist'] as Map).map(
      (k, v) => MapEntry(k is int ? k : int.parse(k.toString()), (v as num).toDouble()));
  return SimulationResult(
    homeTeam: raw['homeTeam'] as String,
    awayTeam: raw['awayTeam'] as String,
    homePitcher: raw['homePitcher'] as String,
    awayPitcher: raw['awayPitcher'] as String,
    iterations: raw['iterations'] as int,
    homeWins: raw['homeWins'] as int,
    awayWins: raw['awayWins'] as int,
    ties: raw['ties'] as int,
    homeAvgScore: (raw['homeAvgScore'] as num).toDouble(),
    awayAvgScore: (raw['awayAvgScore'] as num).toDouble(),
    homeScoreDist: homeScoreDist,
    awayScoreDist: awayScoreDist,
  );
}
