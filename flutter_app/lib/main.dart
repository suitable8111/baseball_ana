import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/hitter_provider.dart';
import 'providers/pitcher_provider.dart';
import 'providers/team_provider.dart';
import 'providers/team_rank_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/prediction_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/accuracy_provider.dart';
import 'services/data_service.dart';
import 'services/naver_service.dart';
import 'services/simulation_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';

// ★ 데이터 소스 전환 포인트
// 개발/테스트: DataSource.assets  → 크롤러 JSON을 assets/data/에 넣고 바로 실행
// 운영:       DataSource.firebase → Firebase 세팅 후 전환
const _dataSource = DataSource.assets;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  await themeProvider.loadSettings();

  runApp(BaseballAnaApp(themeProvider: themeProvider));
}

class BaseballAnaApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const BaseballAnaApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FilterProvider()),
        ChangeNotifierProxyProvider<FilterProvider, HitterProvider>(
          create: (_) => HitterProvider(
            dataService: const DataService(source: _dataSource),
          ),
          update: (_, filter, hitter) {
            hitter!.updateFilter(filter);
            return hitter;
          },
        ),
        ChangeNotifierProxyProvider<FilterProvider, PitcherProvider>(
          create: (_) => PitcherProvider(
            dataService: const DataService(source: _dataSource),
          ),
          update: (_, filter, pitcher) {
            pitcher!.updateFilter(filter);
            return pitcher;
          },
        ),
        ChangeNotifierProxyProvider<FilterProvider, TeamProvider>(
          create: (_) => TeamProvider(
            dataService: const DataService(source: _dataSource),
          ),
          update: (_, filter, team) {
            team!.updateFilter(filter);
            return team;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => TeamRankProvider(
            dataService: const DataService(source: _dataSource),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PredictionProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(),
        ),
        ChangeNotifierProxyProvider<PredictionProvider, AccuracyProvider>(
          create: (_) => AccuracyProvider(
            naver: const NaverService(),
            sim: const SimulationService(),
          ),
          update: (_, pred, acc) {
            acc!.setPredictionProvider(pred);
            return acc;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'KBO 야구 분석',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B3A6B),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B3A6B),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user != null) {
      return const HomeScreen();
    }
    return const AuthScreen();
  }
}
