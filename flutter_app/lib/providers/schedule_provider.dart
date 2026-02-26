import 'package:flutter/material.dart';
import '../models/game_schedule.dart';
import '../services/naver_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final NaverService _service = const NaverService();

  DateTime _date = DateTime.now();
  List<KboGame> _games = [];
  KboGame? _selectedGame;
  GamePreview? _preview;
  bool _loadingGames = false;
  bool _loadingPreview = false;
  String? _error;
  // playerCode → { 'avg', 'obp', 'slg', 'ops' }
  Map<String, Map<String, double>> _playerStats = {};

  DateTime get date => _date;
  List<KboGame> get games => _games;
  KboGame? get selectedGame => _selectedGame;
  GamePreview? get preview => _preview;
  bool get loadingGames => _loadingGames;
  bool get loadingPreview => _loadingPreview;
  String? get error => _error;
  Map<String, Map<String, double>> get playerStats => _playerStats;

  Future<void> loadDate(DateTime date) async {
    _date = date;
    _games = [];
    _selectedGame = null;
    _preview = null;
    _playerStats = {};
    _loadingGames = true;
    _error = null;
    notifyListeners();

    try {
      _games = await _service.fetchSchedule(date);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingGames = false;
      notifyListeners();
    }
  }

  Future<void> selectGame(KboGame game) async {
    if (_selectedGame?.gameId == game.gameId) return;
    _selectedGame = game;
    _preview = null;
    _playerStats = {};
    _loadingPreview = true;
    notifyListeners();

    try {
      _preview = await _service.fetchPreview(game.gameId);

      // 라인업 타자 시즌 스탯 병렬 로드 (playerCode → AVG/OBP/SLG/OPS)
      if (_preview != null) {
        final season = _date.year;
        final batters = [
          ..._preview!.homeLineup,
          ..._preview!.awayLineup,
        ].where((p) => p.batorder > 0 && p.playerCode.isNotEmpty).toList();

        final results = await Future.wait(
          batters.map((p) => _service
              .fetchPlayerStats(p.playerCode, season)
              .then((s) => MapEntry(p.playerCode, s))),
        );

        for (final entry in results) {
          if (entry.value != null) _playerStats[entry.key] = entry.value!;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingPreview = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedGame = null;
    _preview = null;
    notifyListeners();
  }

  void prevDay() => loadDate(_date.subtract(const Duration(days: 1)));
  void nextDay() => loadDate(_date.add(const Duration(days: 1)));
}
