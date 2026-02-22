import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_pitcher.dart';
import '../models/simulation_models.dart';
import '../services/simulation_service.dart';

class PredictionProvider extends ChangeNotifier {
  static const _service = SimulationService();

  // ── 데이터 캐시 ──────────────────────────────────────────────────────────────
  int _season = 2025;
  List<PlayerPitcher> _allPitchers = [];
  List<Map<String, dynamic>> _rawHitters = [];
  bool _dataLoaded = false;

  // ── 선택 상태 ────────────────────────────────────────────────────────────────
  String _homeTeam = 'LG';
  String _awayTeam = '삼성';
  PlayerPitcher? _homePitcher;
  PlayerPitcher? _awayPitcher;

  // ── 결과 상태 ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _error;
  SimulationResult? _result;

  // ── Getters ──────────────────────────────────────────────────────────────────
  int get season => _season;
  String get homeTeam => _homeTeam;
  String get awayTeam => _awayTeam;
  PlayerPitcher? get homePitcher => _homePitcher;
  PlayerPitcher? get awayPitcher => _awayPitcher;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SimulationResult? get result => _result;

  List<PlayerPitcher> pitchersFor(String team) =>
      _allPitchers.where((p) => p.team == team).toList()
        ..sort((a, b) => b.ip.compareTo(a.ip));

  // ── 데이터 로드 ──────────────────────────────────────────────────────────────

  Future<void> loadSeason(int season) async {
    if (_season == season && _dataLoaded) return;
    _season = season;
    _dataLoaded = false;
    _result = null;
    _error = null;
    notifyListeners();

    try {
      final hRaw = await rootBundle.loadString('assets/data/player_hitter_$season.json');
      final pRaw = await rootBundle.loadString('assets/data/player_pitcher_$season.json');
      final hList = (jsonDecode(hRaw) as List).cast<Map<String, dynamic>>();
      final pList = (jsonDecode(pRaw) as List).cast<Map<String, dynamic>>();
      _rawHitters = hList;
      _allPitchers = pList.map(PlayerPitcher.fromMap).toList();
      _dataLoaded = true;

      // 현재 선택 팀에 맞게 투수 초기화
      _resetPitchers();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  void setHomeTeam(String team) {
    if (_homeTeam == team) return;
    _homeTeam = team;
    _homePitcher = null;
    _result = null;
    _resetHomePitcher();
    notifyListeners();
  }

  void setAwayTeam(String team) {
    if (_awayTeam == team) return;
    _awayTeam = team;
    _awayPitcher = null;
    _result = null;
    _resetAwayPitcher();
    notifyListeners();
  }

  void setHomePitcher(PlayerPitcher p) {
    _homePitcher = p;
    _result = null;
    notifyListeners();
  }

  void setAwayPitcher(PlayerPitcher p) {
    _awayPitcher = p;
    _result = null;
    notifyListeners();
  }

  void _resetPitchers() {
    _resetHomePitcher();
    _resetAwayPitcher();
  }

  void _resetHomePitcher() {
    final list = pitchersFor(_homeTeam);
    _homePitcher = list.isNotEmpty ? list.first : null;
  }

  void _resetAwayPitcher() {
    final list = pitchersFor(_awayTeam);
    _awayPitcher = list.isNotEmpty ? list.first : null;
  }

  // ── 시뮬레이션 실행 ──────────────────────────────────────────────────────────

  Future<void> runSimulation({int iterations = 10000}) async {
    if (!_dataLoaded) return;
    if (_homePitcher == null || _awayPitcher == null) return;

    _isLoading = true;
    _error = null;
    _result = null;
    notifyListeners();

    try {
      final league = LeagueAvg.fromHitters(_rawHitters);

      // 라인업: OPS 내림차순 상위 최대 9명 (9명 미만이면 반복 사용)
      final homeHitters = _rawHitters.where((h) => h['team'] == _homeTeam).toList()
        ..sort((a, b) => ((b['ops'] as num? ?? 0).compareTo(a['ops'] as num? ?? 0)));
      final awayHitters = _rawHitters.where((h) => h['team'] == _awayTeam).toList()
        ..sort((a, b) => ((b['ops'] as num? ?? 0).compareTo(a['ops'] as num? ?? 0)));

      List<BatterProfile> buildLineup(List<Map<String, dynamic>> hitters) {
        final profiles = hitters.take(9).map(BatterProfile.fromPlayerMap).toList();
        if (profiles.isEmpty) return [];
        while (profiles.length < 9) {
          profiles.addAll(profiles.toList());
        }
        return profiles.take(9).toList();
      }

      final homeLineup = buildLineup(homeHitters);
      final awayLineup = buildLineup(awayHitters);

      if (homeLineup.isEmpty || awayLineup.isEmpty) {
        throw Exception('라인업 구성 실패: 타자 데이터 부족');
      }

      // PlayerPitcher → PitcherProfile 변환
      final hpMap = _pitcherToRawMap(_homePitcher!);
      final apMap = _pitcherToRawMap(_awayPitcher!);
      final hp = PitcherProfile.fromPlayerMap(hpMap, league);
      final ap = PitcherProfile.fromPlayerMap(apMap, league);

      _result = await _service.run(
        homeLineup: homeLineup,
        awayLineup: awayLineup,
        homePitcher: hp,
        awayPitcher: ap,
        league: league,
        iterations: iterations,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _pitcherToRawMap(PlayerPitcher p) => {
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
}
