import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/player_hitter.dart';
import '../models/player_pitcher.dart';
import '../models/team_stats.dart';
import '../models/team_rank.dart';

/// 데이터 소스 전략
enum DataSource {
  /// assets/data/ 폴더의 JSON 파일 (개발/테스트용, Firebase 없이 바로 실행)
  assets,

  /// Firebase Firestore (운영용, 크롤러 → Firestore 업로드 후 사용)
  firebase,
}

/// 데이터 서비스 - assets / Firebase 두 소스를 통일된 인터페이스로 제공
///
/// 사용법:
///   final service = DataService(source: DataSource.assets);  // 개발
///   final service = DataService(source: DataSource.firebase); // 운영
class DataService {
  final DataSource source;

  const DataService({this.source = DataSource.assets});

  // ─────────────────────────────────────────────
  // 선수 타자
  // ─────────────────────────────────────────────

  Future<List<PlayerHitter>> getPlayerHitters(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadHittersFromAssets(season);
      case DataSource.firebase:
        return _loadHittersFromFirebase(season);
    }
  }

  Future<List<PlayerHitter>> _loadHittersFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/player_hitter_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list.map((e) => PlayerHitter.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('assets/data/player_hitter_$season.json 파일 없음. '
          '크롤러 dry-run 후 assets/data/에 복사하세요.\n$e');
    }
  }

  Future<List<PlayerHitter>> _loadHittersFromFirebase(int season) async {
    // TODO: Firebase 세팅 후 구현
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('seasons')
    //     .doc('$season')
    //     .collection('player_hitter')
    //     .get();
    // return snapshot.docs.map((d) => PlayerHitter.fromMap(d.data())).toList();
    throw UnimplementedError('Firebase 세팅 후 구현 예정');
  }

  // ─────────────────────────────────────────────
  // 선수 투수
  // ─────────────────────────────────────────────

  Future<List<PlayerPitcher>> getPlayerPitchers(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadPitchersFromAssets(season);
      case DataSource.firebase:
        return _loadPitchersFromFirebase(season);
    }
  }

  Future<List<PlayerPitcher>> _loadPitchersFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/player_pitcher_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list.map((e) => PlayerPitcher.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('assets/data/player_pitcher_$season.json 파일 없음.\n$e');
    }
  }

  Future<List<PlayerPitcher>> _loadPitchersFromFirebase(int season) async {
    // TODO: Firebase 세팅 후 구현
    throw UnimplementedError('Firebase 세팅 후 구현 예정');
  }

  // ─────────────────────────────────────────────
  // 팀 타자
  // ─────────────────────────────────────────────

  Future<List<TeamHitter>> getTeamHitters(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadTeamHittersFromAssets(season);
      case DataSource.firebase:
        return _loadTeamHittersFromFirebase(season);
    }
  }

  Future<List<TeamHitter>> _loadTeamHittersFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/team_hitter_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list.map((e) => TeamHitter.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('assets/data/team_hitter_$season.json 파일 없음.\n$e');
    }
  }

  Future<List<TeamHitter>> _loadTeamHittersFromFirebase(int season) async {
    throw UnimplementedError('Firebase 세팅 후 구현 예정');
  }

  // ─────────────────────────────────────────────
  // 팀 투수
  // ─────────────────────────────────────────────

  Future<List<TeamPitcher>> getTeamPitchers(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadTeamPitchersFromAssets(season);
      case DataSource.firebase:
        return _loadTeamPitchersFromFirebase(season);
    }
  }

  Future<List<TeamPitcher>> _loadTeamPitchersFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/team_pitcher_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list.map((e) => TeamPitcher.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('assets/data/team_pitcher_$season.json 파일 없음.\n$e');
    }
  }

  Future<List<TeamPitcher>> _loadTeamPitchersFromFirebase(int season) async {
    throw UnimplementedError('Firebase 세팅 후 구현 예정');
  }

  // ─────────────────────────────────────────────
  // 팀 순위
  // ─────────────────────────────────────────────

  Future<List<TeamStanding>> getTeamStandings(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadStandingsFromAssets(season);
      case DataSource.firebase:
        throw UnimplementedError('Firebase 세팅 후 구현 예정');
    }
  }

  Future<List<TeamStanding>> _loadStandingsFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/team_standings_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list
          .map((e) => TeamStanding.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('assets/data/team_standings_$season.json 파일 없음.\n$e');
    }
  }

  // ─────────────────────────────────────────────
  // 상대 전적
  // ─────────────────────────────────────────────

  Future<List<HeadToHead>> getHeadToHead(int season) async {
    switch (source) {
      case DataSource.assets:
        return _loadHeadToHeadFromAssets(season);
      case DataSource.firebase:
        throw UnimplementedError('Firebase 세팅 후 구현 예정');
    }
  }

  Future<List<HeadToHead>> _loadHeadToHeadFromAssets(int season) async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/team_head_to_head_$season.json',
      );
      final list = jsonDecode(json) as List;
      return list
          .map((e) => HeadToHead.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(
          'assets/data/team_head_to_head_$season.json 파일 없음.\n$e');
    }
  }
}
