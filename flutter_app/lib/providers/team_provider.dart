import 'package:flutter/material.dart';
import '../models/team_stats.dart';
import '../services/data_service.dart';
import 'filter_provider.dart';

class TeamProvider extends ChangeNotifier {
  final DataService _dataService;

  List<TeamHitter> _teamHitters = [];
  List<TeamPitcher> _teamPitchers = [];
  bool _isLoading = false;
  String? _error;

  TeamProvider({DataService? dataService})
      : _dataService = dataService ?? const DataService();

  List<TeamHitter> get teamHitters => _teamHitters;
  List<TeamPitcher> get teamPitchers => _teamPitchers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateFilter(FilterProvider filter) {
    loadData(filter.season);
  }

  Future<void> loadData(int season) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _dataService.getTeamHitters(season),
        _dataService.getTeamPitchers(season),
      ]);
      _teamHitters = results[0] as List<TeamHitter>;
      _teamPitchers = results[1] as List<TeamPitcher>;
    } catch (e) {
      _error = e.toString();
      _teamHitters = [];
      _teamPitchers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
