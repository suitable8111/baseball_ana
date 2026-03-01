import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_schedule.dart' hide HeadToHead;
import '../models/player_pitcher.dart';
import '../models/simulation_models.dart';
import '../models/team_rank.dart';
import '../services/naver_service.dart';
import '../services/simulation_service.dart';
import 'prediction_provider.dart';

class AccuracyProvider extends ChangeNotifier {
  final NaverService _naver;
  final SimulationService _sim;
  PredictionProvider? _pred;

  int _year;
  int _month;
  List<GameAccuracyRecord> _records = [];
  bool _loading = false;
  bool _cancelled = false;
  int _processed = 0;
  int _total = 0;
  String? _error;

  // 보조 데이터 (시즌별 1회 로드)
  List<TeamStanding> _standings = [];
  List<HeadToHead> _h2h = [];
  Map<String, int> _teamRS = {}; // 팀별 득점 (runs scored)
  Map<String, int> _teamRA = {}; // 팀별 실점 (earned runs allowed)

  AccuracyProvider({
    required NaverService naver,
    required SimulationService sim,
  })  : _naver = naver,
        _sim = sim,
        _year = DateTime.now().year,
        _month = DateTime.now().month;

  // ── Getters ──────────────────────────────────────────────────────────────────
  int get year => _year;
  int get month => _month;
  List<GameAccuracyRecord> get records => List.unmodifiable(_records);
  bool get loading => _loading;
  int get processed => _processed;
  int get total => _total;
  String? get error => _error;

  /// 실제 결과가 있는 경기 중 예측 적중률
  double get accuracy {
    final withResult = _records.where((r) => r.actualWinner != null).toList();
    if (withResult.isEmpty) return 0;
    final correct = withResult.where((r) => r.isCorrect).length;
    return correct / withResult.length;
  }

  int get correctCount =>
      _records.where((r) => r.actualWinner != null && r.isCorrect).length;
  int get evaluatedCount =>
      _records.where((r) => r.actualWinner != null).length;

  // ── ProxyProvider 연결 ────────────────────────────────────────────────────────
  void setPredictionProvider(PredictionProvider p) {
    _pred = p;
  }

  // ── 월 이동 ──────────────────────────────────────────────────────────────────
  void prevMonth() {
    if (_loading) return;
    if (_month == 1) {
      _year--;
      _month = 12;
    } else {
      _month--;
    }
    _reset();
  }

  void nextMonth() {
    if (_loading) return;
    if (_month == 12) {
      _year++;
      _month = 1;
    } else {
      _month++;
    }
    _reset();
  }

  void _reset() {
    _records = [];
    _processed = 0;
    _total = 0;
    _error = null;
    notifyListeners();
  }

  // ── 월별 배치 시뮬레이션 ──────────────────────────────────────────────────────
  Future<void> loadMonth() async {
    if (_loading) return;
    if (_pred == null || !_pred!.dataLoaded) {
      _error = '선수 데이터가 로드되지 않았습니다. 잠시 후 다시 시도하세요.';
      notifyListeners();
      return;
    }

    _records = [];
    _processed = 0;
    _total = 0;
    _loading = true;
    _cancelled = false;
    _error = null;
    notifyListeners();

    try {
      // 팀 순위·상대 전적 데이터 로드 (Log-5 계산에 사용)
      await _loadSupplementalData();

      // Naver API의 단일 요청 결과 수 한계를 피하기 위해
      // 월을 7일 단위 청크로 나눠 여러 번 요청한 뒤 합산
      final firstDay = DateTime(_year, _month, 1);
      final lastDay = DateTime(_year, _month + 1, 0); // 해당 월 마지막 날

      final allGames = <KboGame>[];
      var chunkStart = firstDay;
      while (!chunkStart.isAfter(lastDay)) {
        if (_cancelled) break;
        final chunkEnd = chunkStart.add(const Duration(days: 6));
        final actualEnd = chunkEnd.isAfter(lastDay) ? lastDay : chunkEnd;
        final chunk = await _naver.fetchSchedule(chunkStart, toDate: actualEnd);
        allGames.addAll(chunk);
        chunkStart = chunkStart.add(const Duration(days: 7));
      }

      // 중복 제거 (gameId 기준)
      final seen = <String>{};
      final resultGames = allGames
          .where((g) => g.isResult && seen.add(g.gameId))
          .toList();
      _total = resultGames.length;
      notifyListeners();

      for (int i = 0; i < resultGames.length; i += 5) {
        if (_cancelled) break;
        final batch = resultGames.skip(i).take(5).toList();
        final results = await Future.wait(batch.map(_processGame));
        _records.addAll(results.whereType<GameAccuracyRecord>());
        _processed = (i + batch.length).clamp(0, _total);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void cancel() {
    _cancelled = true;
  }

  // ── 보조 데이터 로드 ──────────────────────────────────────────────────────────
  Future<void> _loadSupplementalData() async {
    try {
      final json =
          await rootBundle.loadString('assets/data/team_standings_$_year.json');
      final list = jsonDecode(json) as List;
      _standings =
          list.map((e) => TeamStanding.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _standings = [];
    }
    try {
      final json = await rootBundle
          .loadString('assets/data/team_head_to_head_$_year.json');
      final list = jsonDecode(json) as List;
      _h2h =
          list.map((e) => HeadToHead.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _h2h = [];
    }
    // 팀 득점(RS) / 실점(RA) 로드 → 피타고라스 기대 승률 계산용
    _teamRS = {};
    _teamRA = {};
    try {
      final json = await rootBundle
          .loadString('assets/data/team_hitter_$_year.json');
      for (final e in (jsonDecode(json) as List).cast<Map<String, dynamic>>()) {
        final team = e['team'] as String? ?? '';
        if (team.isNotEmpty) _teamRS[team] = e['runs'] as int? ?? 0;
      }
    } catch (_) {}
    try {
      final json = await rootBundle
          .loadString('assets/data/team_pitcher_$_year.json');
      for (final e in (jsonDecode(json) as List).cast<Map<String, dynamic>>()) {
        final team = e['team'] as String? ?? '';
        if (team.isNotEmpty) _teamRA[team] = e['er'] as int? ?? 0;
      }
    } catch (_) {}
  }

  /// 피타고라스 기대 승률: RS² / (RS² + RA²)
  /// 실제 W/L%보다 운의 영향을 덜 받아 팀 실력을 더 정확히 측정
  double _pythagoreanPct(String code) {
    final rs = (_teamRS[code] ?? 0).toDouble();
    final ra = (_teamRA[code] ?? 0).toDouble();
    if (rs <= 0 || ra <= 0) return 0.5;
    final rs2 = rs * rs;
    final ra2 = ra * ra;
    return rs2 / (rs2 + ra2);
  }

  /// 최근 10경기 승률: "6승1무3패" 파싱 → 무승부 제외 후 승률
  double _last10Pct(String code) {
    TeamStanding? s;
    for (final st in _standings) {
      if (st.team == code) { s = st; break; }
    }
    if (s == null) return 0.5;
    final text = s.last10;
    final w = int.tryParse(RegExp(r'(\d+)승').firstMatch(text)?.group(1) ?? '') ?? 0;
    final l = int.tryParse(RegExp(r'(\d+)패').firstMatch(text)?.group(1) ?? '') ?? 0;
    final total = w + l;
    return total > 0 ? w / total : 0.5;
  }

  /// Log-5 확률: (피타고라스 70% + 최근폼 30%) 혼합 품질 × 홈/원정 편향
  /// → Log-5 공식으로 홈팀 예상 승률 산출
  double _log5Prob(String homeCode, String awayCode) {
    TeamStanding? home, away;
    for (final s in _standings) {
      if (s.team == homeCode) home = s;
      if (s.team == awayCode) away = s;
    }

    // 팀 실력 추정: 피타고라스(운 제거) 70% + 최근 10경기 폼 30%
    final homeQuality =
        0.70 * _pythagoreanPct(homeCode) + 0.30 * _last10Pct(homeCode);
    final awayQuality =
        0.70 * _pythagoreanPct(awayCode) + 0.30 * _last10Pct(awayCode);

    // 홈/원정 편향 배수: 시즌 전체 승률 대비 홈(원정)에서 얼마나 강한가
    double splitBias(TeamStanding? s, bool isHome) {
      if (s == null) return isHome ? 1.08 : 0.92;
      final total = s.wins + s.losses;
      if (total == 0) return isHome ? 1.08 : 0.92;
      final overallPct = s.wins / total;
      final splitGames = isHome
          ? s.homeW + s.homeL
          : s.awayW + s.awayL;
      final splitWins = isHome ? s.homeW : s.awayW;
      if (splitGames == 0) return isHome ? 1.08 : 0.92;
      return (splitWins / splitGames) / overallPct.clamp(0.01, 0.99);
    }

    final pA = (homeQuality * splitBias(home, true)).clamp(0.1, 0.9);
    final pB = (awayQuality * splitBias(away, false)).clamp(0.1, 0.9);

    final num = pA * (1 - pB);
    final den = num + pB * (1 - pA);
    return den > 0 ? num / den : 0.54;
  }

  /// 상대 전적 조정: 홈팀의 원정팀 대상 H2H 승률 기반 → ±5% 이내
  double _h2hAdj(String homeCode, String awayCode) {
    HeadToHead? homeH2H;
    for (final h in _h2h) {
      if (h.team == homeCode) {
        homeH2H = h;
        break;
      }
    }
    if (homeH2H == null) return 0.0;
    final record = homeH2H.matchups[awayCode];
    if (record == null || record.total < 5) return 0.0; // 전적 5경기 미만 무시
    return (record.winPct - 0.5).clamp(-0.05, 0.05);
  }

  // ── 개별 경기 처리 ────────────────────────────────────────────────────────────
  Future<GameAccuracyRecord?> _processGame(KboGame game) async {
    if (_pred == null || !_pred!.dataLoaded) return null;
    try {
      final batterRecord = await _naver.fetchBattersRecord(game.gameId);
      final homeLineupNames = batterRecord['home'] ?? [];
      final awayLineupNames = batterRecord['away'] ?? [];

      final rawHitters = _pred!.rawHitters;
      final allPitchers = _pred!.allPitchers;
      final league = LeagueAvg.fromHitters(rawHitters);

      // "LG 트윈스" → "LG",  "삼성 라이온즈" → "삼성" 등
      // Naver API 전체 팀명 → JSON 데이터의 팀 코드(첫 단어)로 변환
      String teamCode(String fullName) => fullName.split(' ').first;
      final homeCode = teamCode(game.homeTeamName);
      final awayCode = teamCode(game.awayTeamName);

      List<BatterProfile> buildLineup(List<String> names, String code) {
        final profiles = <BatterProfile>[];
        for (final name in names) {
          Map<String, dynamic>? hit;
          // 팀+이름 우선 매칭
          for (final h in rawHitters) {
            if (h['name'] == name && h['team'] == code) {
              hit = h;
              break;
            }
          }
          // 이름만 매칭 (이적선수 등 대응)
          if (hit == null) {
            for (final h in rawHitters) {
              if (h['name'] == name) {
                hit = h;
                break;
              }
            }
          }
          if (hit != null) profiles.add(BatterProfile.fromPlayerMap(hit));
        }
        if (profiles.isEmpty) {
          final teamH = rawHitters.where((h) => h['team'] == code).toList()
            ..sort((a, b) =>
                ((b['ops'] as num? ?? 0).compareTo(a['ops'] as num? ?? 0)));
          return teamH.take(9).map(BatterProfile.fromPlayerMap).toList();
        }
        while (profiles.length < 9) {
          profiles.addAll(List<BatterProfile>.from(profiles));
        }
        return profiles.take(9).toList();
      }

      PlayerPitcher? findPitcher(String? name, String code) {
        if (name != null && name.isNotEmpty) {
          for (final p in allPitchers) {
            if (p.name == name && p.team == code) return p;
          }
          for (final p in allPitchers) {
            if (p.name == name) return p;
          }
        }
        final list = allPitchers.where((p) => p.team == code).toList()
          ..sort((a, b) => b.ip.compareTo(a.ip));
        return list.isNotEmpty ? list.first : null;
      }

      Map<String, dynamic> pitcherToMap(PlayerPitcher p) => {
            'name': p.name,
            'team': p.team,
            'ip': p.ip,
            'hits': p.hits,
            'hr': p.hr,
            'bb': p.bb,
            'hbp': p.hbp,
            'so': p.so,
            'tbf': 0,
          };

      final hp = findPitcher(game.homeStarterName, homeCode);
      final ap = findPitcher(game.awayStarterName, awayCode);
      if (hp == null || ap == null) return null;

      final homeLineup = buildLineup(homeLineupNames, homeCode);
      final awayLineup = buildLineup(awayLineupNames, awayCode);
      if (homeLineup.isEmpty || awayLineup.isEmpty) return null;

      final result = await _sim.run(
        homeLineup: homeLineup,
        awayLineup: awayLineup,
        homePitcher: PitcherProfile.fromPlayerMap(pitcherToMap(hp), league),
        awayPitcher: PitcherProfile.fromPlayerMap(pitcherToMap(ap), league),
        league: league,
      );

      // ── 시뮬레이션 결과 보정 ─────────────────────────────────────────────────
      // 1) Log-5: 홈팀 홈전적 × 원정팀 원정전적 → 홈 어드밴티지 자연 반영
      final log5Base = _log5Prob(homeCode, awayCode);

      // 2) FIP 기반 조정: ERA보다 수비 독립적으로 선발 투수 품질 반영
      //    (1 FIP 차이 ≈ 4% 승률 차이, ±3 범위 내 적용)
      const lgAvgFip = 4.20; // KBO 2025 리그 평균 FIP 추정값
      final homeFip = hp.fip > 0 ? hp.fip : lgAvgFip;
      final awayFip = ap.fip > 0 ? ap.fip : lgAvgFip;
      final fipDiff = (awayFip - homeFip).clamp(-3.0, 3.0);
      final fipAdj = fipDiff * 0.04;

      // 3) 상대 전적 조정 (±5% 이내)
      final h2hAdj = _h2hAdj(homeCode, awayCode);

      // 4) 시뮬레이션 신호: 0.5 기준 편차의 20% 가중 (라인업 품질 반영)
      final simSignal = (result.homeWinProb - 0.5) * 0.20;

      // 5) 최종 확률: Log-5(기반) + FIP조정 + H2H조정 + 시뮬신호
      final adjHomeProb =
          (log5Base + fipAdj + h2hAdj + simSignal).clamp(0.1, 0.9);
      final adjAwayProb = 1.0 - adjHomeProb;

      final predictedWinner = adjHomeProb >= 0.5 ? 'home' : 'away';
      final actualWinner = game.winner;
      final isCorrect =
          actualWinner != null && actualWinner == predictedWinner;

      return GameAccuracyRecord(
        gameId: game.gameId,
        gameDate: game.gameDate,
        homeTeam: game.homeTeamName,
        awayTeam: game.awayTeamName,
        homeStarter: game.homeStarterName,
        awayStarter: game.awayStarterName,
        homeWinProb: adjHomeProb,
        awayWinProb: adjAwayProb,
        predictedWinner: predictedWinner,
        actualWinner: actualWinner,
        isCorrect: isCorrect,
      );
    } catch (_) {
      return null;
    }
  }

}
