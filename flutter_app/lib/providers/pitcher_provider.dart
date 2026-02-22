import 'package:flutter/material.dart';
import '../models/player_pitcher.dart';
import '../services/data_service.dart';
import 'filter_provider.dart';

class PitcherProvider extends ChangeNotifier {
  final DataService _dataService;

  List<PlayerPitcher> _pitchers = [];
  List<PlayerPitcher> _filtered = [];
  Map<PlayerPitcher, int> _rankMap = {};
  bool _isLoading = false;
  String? _error;
  String _sortColumn = 'era';
  bool _sortAscending = true;

  int _currentSeason = 0;
  String _currentTeam = '';

  PitcherProvider({DataService? dataService})
      : _dataService = dataService ?? const DataService();

  List<PlayerPitcher> get pitchers => _filtered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  /// 전체 정렬 기준 원본 순위 반환 (필터 여부와 무관)
  int rankOf(PlayerPitcher p) => _rankMap[p] ?? 0;

  void updateFilter(FilterProvider filter) {
    final seasonChanged = _currentSeason != filter.season;
    _currentSeason = filter.season;
    _currentTeam = filter.team;

    if (seasonChanged) {
      loadData(filter.season);
    } else {
      _applyFilter(filter.team);
    }
  }

  Future<void> loadData(int season) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pitchers = await _dataService.getPlayerPitchers(season);
    } catch (e) {
      _error = e.toString();
      _pitchers = [];
    } finally {
      _isLoading = false;
      _applyFilter(_currentTeam);
    }
  }

  void _applyFilter(String team) {
    _filtered = _pitchers.where((p) {
      return team == '전체' || team.isEmpty || p.team == team;
    }).toList();
    _sortData();
    notifyListeners();
  }

  void sort(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = ['era', 'whip', 'fip', 'bb9', 'hr9'].contains(column);
    }
    _sortData();
    notifyListeners();
  }

  void _sortData() {
    // 전체 리스트 정렬 → 원본 순위 결정
    _pitchers.sort((a, b) {
      final cmp = _getValue(a, _sortColumn).compareTo(_getValue(b, _sortColumn));
      return _sortAscending ? cmp : -cmp;
    });
    // 전체 순위 맵 기록
    _rankMap = {for (int i = 0; i < _pitchers.length; i++) _pitchers[i]: i + 1};
    // 필터된 리스트도 같은 순서로 정렬
    _filtered.sort((a, b) => _rankMap[a]!.compareTo(_rankMap[b]!));
  }

  Comparable _getValue(PlayerPitcher p, String col) {
    switch (col) {
      case 'name':   return p.name;
      case 'team':   return p.team;
      case 'games':  return p.games;
      case 'wins':   return p.wins;
      case 'losses': return p.losses;
      case 'saves':  return p.saves;
      case 'ip':     return p.ip;
      case 'so':     return p.so;
      case 'era':    return p.era;
      case 'whip':   return p.whip;
      case 'k9':     return p.k9;
      case 'bb9':    return p.bb9;
      case 'fip':    return p.fip;
      default:       return p.era;
    }
  }
}
