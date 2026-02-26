import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/filter_provider.dart' show FilterProvider, kboTeams;
import '../providers/hitter_provider.dart';
import '../providers/pitcher_provider.dart';
import '../providers/team_provider.dart';
import '../providers/team_rank_provider.dart';
import '../providers/prediction_provider.dart';
import 'player_hitter_screen.dart';
import 'player_pitcher_screen.dart';
import 'team_stats_screen.dart';
import 'team_rank_screen.dart';
import 'game_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PlayerHitterScreen(),
    PlayerPitcherScreen(),
    TeamStatsScreen(),
    TeamRankScreen(),
    GameScheduleScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final filter = context.read<FilterProvider>();
    context.read<HitterProvider>().loadData(filter.season);
    context.read<PitcherProvider>().loadData(filter.season);
    context.read<TeamProvider>().loadData(filter.season);
    context.read<TeamRankProvider>().loadData(filter.season);
    context.read<PredictionProvider>().loadSeason(filter.season);
  }

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterProvider>();
    final theme = context.read<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_baseball, size: 24),
            SizedBox(width: 8),
            Text('KBO 야구 분석', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // 시즌 필터
          DropdownButton<int>(
            value: filter.season,
            underline: const SizedBox(),
            items: filter.availableSeasons
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (y) {
              if (y != null) {
                filter.setSeason(y);
                _loadData();
              }
            },
          ),
          const SizedBox(width: 8),
          // 팀 필터
          DropdownButton<String>(
            value: filter.team,
            underline: const SizedBox(),
            items: kboTeams
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (t) {
              if (t != null) filter.setTeam(t);
            },
          ),
          const SizedBox(width: 8),
          // 테마 전환
          IconButton(
            icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: theme.toggleTheme,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person),
            label: '타자',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_baseball),
            label: '투수',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups),
            label: '팀',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard),
            label: '순위',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '일정',
          ),
        ],
      ),
    );
  }
}
