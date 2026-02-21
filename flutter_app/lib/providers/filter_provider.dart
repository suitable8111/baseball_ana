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

  List<int> get availableSeasons {
    final current = DateTime.now().year;
    return List.generate(current - 1981, (i) => current - i);
  }
}
