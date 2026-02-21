import 'package:flutter/material.dart';
import '../models/player_hitter.dart';
import '../services/data_service.dart';
import 'filter_provider.dart';

class HitterProvider extends ChangeNotifier {
  final DataService _dataService;

  List<PlayerHitter> _hitters = [];
  List<PlayerHitter> _filtered = [];
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
    _filtered.sort((a, b) {
      final cmp = _getValue(a, _sortColumn).compareTo(_getValue(b, _sortColumn));
      return _sortAscending ? cmp : -cmp;
    });
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
