import 'package:flutter/material.dart';
import '../models/player_hitter.dart';
import '../services/data_service.dart';
import 'filter_provider.dart';

class HitterProvider extends ChangeNotifier {
  final DataService _dataService;

  List<PlayerHitter> _hitters = [];
  List<PlayerHitter> _filtered = [];
  Map<PlayerHitter, int> _rankMap = {};
  bool _isLoading = false;
  String? _error;
  String _sortColumn = 'ops';
  bool _sortAscending = false;

  int _currentSeason = 0;
  String _currentTeam = '';

  HitterProvider({DataService? dataService})
      : _dataService = dataService ?? const DataService();

  List<PlayerHitter> get hitters => _filtered;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  /// 전체 정렬 기준 원본 순위 반환 (필터 여부와 무관)
  int rankOf(PlayerHitter h) => _rankMap[h] ?? 0;

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
      _hitters = await _dataService.getPlayerHitters(season);
    } catch (e) {
      _error = e.toString();
      _hitters = [];
    } finally {
      _isLoading = false;
      _applyFilter(_currentTeam);
    }
  }

  void _applyFilter(String team) {
    _filtered = _hitters.where((h) {
      return team == '전체' || team.isEmpty || h.team == team;
    }).toList();
    _sortData();
    notifyListeners();
  }

  void sort(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = false;
    }
    _sortData();
    notifyListeners();
  }

  void _sortData() {
    // 전체 리스트 정렬 → 원본 순위 결정
    _hitters.sort((a, b) {
      final cmp = _getValue(a, _sortColumn).compareTo(_getValue(b, _sortColumn));
      return _sortAscending ? cmp : -cmp;
    });
    // 전체 순위 맵 기록
    _rankMap = {for (int i = 0; i < _hitters.length; i++) _hitters[i]: i + 1};
    // 필터된 리스트도 같은 순서로 정렬
    _filtered.sort((a, b) => _rankMap[a]!.compareTo(_rankMap[b]!));
  }

  Comparable _getValue(PlayerHitter h, String col) {
    switch (col) {
      case 'name':   return h.name;
      case 'team':   return h.team;
      case 'games':  return h.games;
      case 'pa':     return h.pa;
      case 'ab':     return h.ab;
      case 'hits':   return h.hits;
      case 'hr':     return h.hr;
      case 'rbi':    return h.rbi;
      case 'sb':     return h.sb;
      case 'avg':    return h.avg;
      case 'obp':    return h.obp;
      case 'slg':    return h.slg;
      case 'ops':    return h.ops;
      case 'babip':  return h.babip;
      case 'iso':    return h.iso;
      default:       return h.ops;
    }
  }
}
