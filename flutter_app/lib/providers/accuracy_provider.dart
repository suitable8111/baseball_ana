import 'package:flutter/material.dart';
import '../models/game_schedule.dart';
import '../models/player_pitcher.dart';
import '../models/simulation_models.dart';
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
      // 1) 홈팀 이점: KBO 홈팀 실제 승률 ≈ 54%
      const homeAdv = 0.04;

      // 2) ERA 기반 보정: 시뮬레이션이 시즌 평균 스탯이라 팀 간 차이를 충분히
      //    반영하지 못함 → 투수 ERA 차이를 직접 승률 신호로 추가 반영
      //    (1 ERA 차이 ≈ 5% 승률 차이, ±3 범위 내에서 적용)
      const lgAvgEra = 4.30; // KBO 2025 리그 평균 ERA
      final homeEra = hp.era > 0 ? hp.era : lgAvgEra;
      final awayEra = ap.era > 0 ? ap.era : lgAvgEra;
      final eraDiff = (awayEra - homeEra).clamp(-3.0, 3.0); // 원정ERA - 홈ERA
      final eraAdj = eraDiff * 0.05;

      final adjHomeProb =
          (result.homeWinProb + homeAdv + eraAdj).clamp(0.1, 0.9);
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
