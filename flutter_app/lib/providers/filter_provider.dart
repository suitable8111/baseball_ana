import 'package:flutter/material.dart';

const List<String> kboTeams = [
  '전체',
  'KIA',
  '삼성',
  'LG',
  '두산',
  'KT',
  'SSG',
  '롯데',
  '한화',
  'NC',
  '키움',
];

class FilterProvider extends ChangeNotifier {
  int _season = 2025;
  String _team = '전체';

  int get season => _season;
  String get team => _team;

  void setSeason(int season) {
    _season = season;
    notifyListeners();
  }

  void setTeam(String team) {
    _team = team;
    notifyListeners();
  }

  // koreabaseball.com 통계 제공 시작: 2002년
  static const int _firstSeason = 2002;

  List<int> get availableSeasons {
    final current = DateTime.now().year;
    return List.generate(current - _firstSeason + 1, (i) => current - i);
  }
}
