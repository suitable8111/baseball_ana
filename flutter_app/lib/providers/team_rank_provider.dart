import 'package:flutter/foundation.dart';
import '../models/team_rank.dart';
import '../services/data_service.dart';

class TeamRankProvider extends ChangeNotifier {
  final DataService _dataService;

  List<TeamStanding> _standings = [];
  List<HeadToHead> _headToHead = [];
  bool _isLoading = false;
  String? _error;

  TeamRankProvider({required DataService dataService})
      : _dataService = dataService;

  List<TeamStanding> get standings => _standings;
  List<HeadToHead> get headToHead => _headToHead;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData(int season) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _standings = await _dataService.getTeamStandings(season);
      _headToHead = await _dataService.getHeadToHead(season);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
