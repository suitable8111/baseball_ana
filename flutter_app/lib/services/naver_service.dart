import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game_schedule.dart';

class NaverService {
  // 네이티브(iOS/Android): false  → Naver API 직접 호출
  // Flutter Web 개발:      true   → 로컬 프록시 (python proxy_server.py)
  static const bool _useProxy = bool.fromEnvironment('USE_PROXY');
  static const _base = _useProxy
      ? 'http://localhost:8765'
      : 'https://api-gw.sports.naver.com';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Referer': 'https://m.sports.naver.com/',
    'Origin': 'https://m.sports.naver.com',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
  };

  const NaverService();

  Future<List<KboGame>> fetchSchedule(DateTime fromDate, {DateTime? toDate}) async {
    final fromStr = _fmt(fromDate);
    final toStr = toDate != null ? _fmt(toDate) : fromStr;
    final uri =
        Uri.parse('$_base/schedule/games').replace(queryParameters: {
      'fields': 'all',
      'fromDate': fromStr,
      'toDate': toStr,
      'size': '200',
    });

    final client = http.Client();
    try {
      final res = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('일정 불러오기 실패 (HTTP ${res.statusCode})\n${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final games = (data['result']?['games'] as List<dynamic>?) ?? [];

      return games
          .cast<Map<String, dynamic>>()
          .where((g) =>
              g['upperCategoryId'] == 'kbaseball' &&
              (g['gameId'] as String?)?.isNotEmpty == true &&
              (g['homeTeamName'] as String?)?.isNotEmpty == true &&
              (g['awayTeamName'] as String?)?.isNotEmpty == true)
          .map(KboGame.fromJson)
          .toList();
    } finally {
      client.close();
    }
  }

  Future<GamePreview> fetchPreview(String gameId) async {
    final uri = Uri.parse('$_base/schedule/games/$gameId/preview');
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('라인업 불러오기 실패 (HTTP ${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final preview =
        data['result']?['previewData'] as Map<String, dynamic>? ?? {};
    return GamePreview.fromJson(preview);
  }

  /// 선수 코드로 시즌 타격 스탯 가져오기 (AVG / OBP / SLG / OPS)
  /// 반환: { 'avg': 0.275, 'obp': 0.316, 'slg': 0.47, 'ops': 0.786 } 또는 null
  Future<Map<String, double>?> fetchPlayerStats(
      String playerCode, int season) async {
    if (playerCode.isEmpty) return null;
    final uri = Uri.parse(
        '$_base/statistics/categories/kbo/seasons/$season/players/$playerCode');
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final s = data['result']?['hitterStats'] as Map<String, dynamic>?;
      if (s == null) return null;
      final avg = (s['hitterHra'] as num?)?.toDouble() ?? 0.0;
      final ops = (s['hitterOps'] as num?)?.toDouble() ?? 0.0;
      if (avg <= 0 && ops <= 0) return null;
      return {
        'avg': avg,
        'obp': (s['hitterObp'] as num?)?.toDouble() ?? 0.0,
        'slg': (s['hitterSlg'] as num?)?.toDouble() ?? 0.0,
        'ops': ops,
      };
    } catch (_) {
      return null;
    }
  }

  /// 완료된 경기 박스스코어에서 선수별 시즌 타율 가져오기
  /// 반환: { "선수명": 0.288, ... }  ← `hra` 필드 (AVG)
  Future<Map<String, double>> fetchRecord(String gameId) async {
    final uri = Uri.parse('$_base/schedule/games/$gameId/record');
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {};

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final batters = data['result']?['recordData']?['battersBoxscore']
          as Map<String, dynamic>?;
      if (batters == null) return {};

      final result = <String, double>{};
      for (final side in ['away', 'home']) {
        final list = batters[side] as List<dynamic>? ?? [];
        for (final b in list.cast<Map<String, dynamic>>()) {
          final name = b['name']?.toString() ?? '';
          final raw = b['hra'];
          final avg = raw is num
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? '') ?? 0.0;
          if (name.isNotEmpty && avg > 0) {
            result[name] = avg;
          }
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// 완료된 경기 박스스코어에서 홈/원정 실제 타자 이름 리스트 반환 (타순 순서)
  ///
  /// - batorder 필드 우선 사용: 타순별 첫 출전자(선발)만 수집 → 대타 중복 제거
  /// - batorder 없으면 hra(AVG) > 0 타자만 (KBO DH 규정상 투수 불타석)
  /// 반환: { 'home': ['이름1', ...], 'away': ['이름1', ...] }  최대 9명
  Future<Map<String, List<String>>> fetchBattersRecord(String gameId) async {
    final uri = Uri.parse('$_base/schedule/games/$gameId/record');
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return {'home': [], 'away': []};

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final batters = data['result']?['recordData']?['battersBoxscore']
          as Map<String, dynamic>?;
      if (batters == null) return {'home': [], 'away': []};

      List<String> extractNames(String side) {
        final list = batters[side] as List<dynamic>? ?? [];
        final slotSeen = <int>{}; // 타순(1-9)별 첫 출전자만 취하기 위한 중복 체크
        final names = <String>[];

        for (final raw in list.cast<Map<String, dynamic>>()) {
          final name = raw['name']?.toString() ?? '';
          if (name.isEmpty) continue;

          // batorder 필드가 있으면 타순 기반으로 선별
          final batorderRaw = raw['batorder'] ?? raw['batOrder'];
          if (batorderRaw != null) {
            final order = int.tryParse(batorderRaw.toString()) ?? 0;
            if (order < 1 || order > 9) continue; // 투수(0) 또는 범위 밖 제외
            if (!slotSeen.add(order)) continue;    // 타순 중복(대타) 제거
            names.add(name);
            continue;
          }

          // batorder 없는 경우: hra > 0 타자만 (DH 규정상 투수는 타석 없음)
          final hraRaw = raw['hra'];
          final avg = hraRaw is num
              ? hraRaw.toDouble()
              : double.tryParse(hraRaw?.toString() ?? '') ?? 0.0;
          if (avg > 0 && names.length < 9) names.add(name);
        }
        return names.take(9).toList();
      }

      return {
        'home': extractNames('home'),
        'away': extractNames('away'),
      };
    } catch (_) {
      return {'home': [], 'away': []};
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
