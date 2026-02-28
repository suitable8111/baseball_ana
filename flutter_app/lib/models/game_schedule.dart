// ── 안전 파싱 헬퍼 ────────────────────────────────────────────────────────────
// Naver API는 숫자 필드를 String으로 내려주는 경우가 있음
int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int? _ni(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final parsed = int.tryParse(v.toString());
  return parsed;
}

// ─────────────────────────────────────────────────────────────────────────────

class LineupPlayer {
  final String playerName;
  final int batorder; // 0 = pitcher entry (no batting order)
  final String positionName;
  final String backnum;
  final String hitType;
  final String playerCode;

  const LineupPlayer({
    required this.playerName,
    required this.batorder,
    required this.positionName,
    required this.backnum,
    required this.hitType,
    required this.playerCode,
  });

  factory LineupPlayer.fromJson(Map<String, dynamic> j) => LineupPlayer(
        playerName: j['playerName']?.toString() ?? '',
        batorder: _i(j['batorder']),
        positionName: j['positionName']?.toString() ?? '',
        backnum: j['backnum']?.toString() ?? '',
        hitType: j['hitType']?.toString() ?? '',
        playerCode: j['playerCode']?.toString() ?? '',
      );
}

class StarterInfo {
  final String name;
  final double era;
  final int wins;
  final int losses;
  final double ip;
  final double whip;

  const StarterInfo({
    required this.name,
    required this.era,
    required this.wins,
    required this.losses,
    required this.ip,
    required this.whip,
  });

  factory StarterInfo.fromJson(Map<String, dynamic> j) {
    final info = j['playerInfo'] as Map<String, dynamic>? ?? {};
    final stats = j['currentSeasonStats'] as Map<String, dynamic>? ?? {};
    return StarterInfo(
      name: info['name']?.toString() ?? '',
      era: _d(stats['era']),
      wins: _i(stats['w']),
      losses: _i(stats['l']),
      ip: _d(stats['ip']),
      whip: _d(stats['whip']),
    );
  }
}

class TeamStandings {
  final int rank;
  final int wins;
  final int losses;
  final int draws;
  final double wra;

  const TeamStandings({
    required this.rank,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.wra,
  });

  factory TeamStandings.fromJson(Map<String, dynamic> j) => TeamStandings(
        rank: _i(j['rank']),
        wins: _i(j['w']),
        losses: _i(j['l']),
        draws: _i(j['d']),
        wra: _d(j['wra']),
      );
}

class HeadToHead {
  final int homeWins;
  final int homeLosses;
  final int homeDraws;
  final int awayWins;
  final int awayLosses;
  final int awayDraws;

  const HeadToHead({
    required this.homeWins,
    required this.homeLosses,
    required this.homeDraws,
    required this.awayWins,
    required this.awayLosses,
    required this.awayDraws,
  });

  factory HeadToHead.fromJson(Map<String, dynamic> j) => HeadToHead(
        homeWins: _i(j['hw']),
        homeLosses: _i(j['hl']),
        homeDraws: _i(j['hd']),
        awayWins: _i(j['aw']),
        awayLosses: _i(j['al']),
        awayDraws: _i(j['ad']),
      );
}

class GamePreview {
  final List<LineupPlayer> homeLineup;
  final List<LineupPlayer> awayLineup;
  final StarterInfo? homeStarter;
  final StarterInfo? awayStarter;
  final TeamStandings? homeStandings;
  final TeamStandings? awayStandings;
  final HeadToHead? headToHead;

  const GamePreview({
    required this.homeLineup,
    required this.awayLineup,
    this.homeStarter,
    this.awayStarter,
    this.homeStandings,
    this.awayStandings,
    this.headToHead,
  });

  factory GamePreview.fromJson(Map<String, dynamic> j) {
    List<LineupPlayer> parseLineup(String side) {
      final raw =
          j['${side}TeamLineUp']?['fullLineUp'] as List<dynamic>? ?? [];
      return raw
          .cast<Map<String, dynamic>>()
          .map(LineupPlayer.fromJson)
          .toList();
    }

    return GamePreview(
      homeLineup: parseLineup('home'),
      awayLineup: parseLineup('away'),
      homeStarter: j['homeStarter'] != null
          ? StarterInfo.fromJson(j['homeStarter'] as Map<String, dynamic>)
          : null,
      awayStarter: j['awayStarter'] != null
          ? StarterInfo.fromJson(j['awayStarter'] as Map<String, dynamic>)
          : null,
      homeStandings: j['homeStandings'] != null
          ? TeamStandings.fromJson(j['homeStandings'] as Map<String, dynamic>)
          : null,
      awayStandings: j['awayStandings'] != null
          ? TeamStandings.fromJson(j['awayStandings'] as Map<String, dynamic>)
          : null,
      headToHead: j['seasonVsResult'] != null
          ? HeadToHead.fromJson(j['seasonVsResult'] as Map<String, dynamic>)
          : null,
    );
  }
}

class KboGame {
  final String gameId;
  final String gameDate; // YYYYMMDD
  final String gameDateTime; // ISO-like string from API
  final String stadium;
  final String statusCode; // SCHEDULED, LIVE, RESULT, CANCELED
  final String homeTeamCode;
  final String homeTeamName;
  final String awayTeamCode;
  final String awayTeamName;
  final int? homeTeamScore;
  final int? awayTeamScore;
  final String? homeStarterName;
  final String? awayStarterName;
  final List<int> homeScoreByInning;
  final List<int> awayScoreByInning;
  final List<int> homeRheb; // [R, H, E, B]
  final List<int> awayRheb;
  final String? winner; // 'home' | 'away' | null

  const KboGame({
    required this.gameId,
    required this.gameDate,
    required this.gameDateTime,
    required this.stadium,
    required this.statusCode,
    required this.homeTeamCode,
    required this.homeTeamName,
    required this.awayTeamCode,
    required this.awayTeamName,
    this.homeTeamScore,
    this.awayTeamScore,
    this.homeStarterName,
    this.awayStarterName,
    required this.homeScoreByInning,
    required this.awayScoreByInning,
    required this.homeRheb,
    required this.awayRheb,
    this.winner,
  });

  factory KboGame.fromJson(Map<String, dynamic> j) {
    List<int> toInts(dynamic raw) {
      if (raw == null) return [];
      return (raw as List<dynamic>).map((e) => _i(e)).toList();
    }

    return KboGame(
      gameId: j['gameId']?.toString() ?? '',
      gameDate: j['gameDate']?.toString() ?? '',
      gameDateTime: j['gameDateTime']?.toString() ?? '',
      stadium: j['stadium']?.toString() ?? '',
      statusCode: j['statusCode']?.toString() ?? 'SCHEDULED',
      homeTeamCode: j['homeTeamCode']?.toString() ?? '',
      homeTeamName: j['homeTeamName']?.toString() ?? '',
      awayTeamCode: j['awayTeamCode']?.toString() ?? '',
      awayTeamName: j['awayTeamName']?.toString() ?? '',
      homeTeamScore: _ni(j['homeTeamScore']),
      awayTeamScore: _ni(j['awayTeamScore']),
      homeStarterName: j['homeStarterName']?.toString(),
      awayStarterName: j['awayStarterName']?.toString(),
      homeScoreByInning: toInts(j['homeTeamScoreByInning']),
      awayScoreByInning: toInts(j['awayTeamScoreByInning']),
      homeRheb: toInts(j['homeTeamRheb']),
      awayRheb: toInts(j['awayTeamRheb']),
      winner: (() {
        final w = j['winner']?.toString().toLowerCase();
        return (w == 'home' || w == 'away') ? w : null;
      })(),
    );
  }

  bool get isResult => statusCode == 'RESULT';
  bool get isLive => statusCode == 'LIVE';
  bool get isScheduled => statusCode == 'SCHEDULED';

  /// e.g. "18:30" from gameDateTime
  String get timeLabel {
    try {
      final dt = DateTime.parse(gameDateTime);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

// ── 예측 정확도 기록 ────────────────────────────────────────────────────────────

class GameAccuracyRecord {
  final String gameId;
  final String gameDate;        // YYYYMMDD
  final String homeTeam;
  final String awayTeam;
  final String? homeStarter;
  final String? awayStarter;
  final double homeWinProb;
  final double awayWinProb;
  final String predictedWinner; // 'home' | 'away'
  final String? actualWinner;   // 'home' | 'away' | null(무승부)
  final bool isCorrect;         // actualWinner != null && actualWinner == predictedWinner

  const GameAccuracyRecord({
    required this.gameId,
    required this.gameDate,
    required this.homeTeam,
    required this.awayTeam,
    this.homeStarter,
    this.awayStarter,
    required this.homeWinProb,
    required this.awayWinProb,
    required this.predictedWinner,
    this.actualWinner,
    required this.isCorrect,
  });
}
