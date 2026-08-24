import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/entry_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'widgets/hal_status_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeGridApp());
}

class LifeGridApp extends StatelessWidget {
  const LifeGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Grid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapNotifications();
  }

  Future<void> _bootstrapNotifications() async {
    final storage = StorageService();
    final notifications = NotificationService();
    final (hour, minute, enabled) = await storage.loadNotifyTime();
    if (enabled) {
      await notifications.requestPermissions();
      await notifications.scheduleDaily(hour, minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EntryScreen(date: DateTime.now()),
      const TimelineScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          pages[_index],
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: const HalStatusIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar_outlined, size: 20),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_timeline_outlined, size: 20),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart, size: 20),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 20),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
