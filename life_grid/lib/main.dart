import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/entry_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
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
      home: const SessionGate(),
    );
  }
}

/// Restores a previous login session (if any) before deciding whether to
/// show the login screen or the app itself.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _auth = AuthService();
  bool _checking = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await _auth.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = user;
      StorageService.currentUser = user;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      return LoginScreen(
        onLoggedIn: (user) => setState(() => _user = user),
      );
    }
    return RootShell(
      onLogOut: () async {
        await _auth.logOut();
        StorageService.currentUser = null;
        setState(() => _user = null);
      },
    );
  }
}

class RootShell extends StatefulWidget {
  final VoidCallback onLogOut;
  const RootShell({super.key, required this.onLogOut});

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
      SettingsScreen(onLogOut: widget.onLogOut),
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
