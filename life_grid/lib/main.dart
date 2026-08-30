import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/entry_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lock_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'widgets/hal_status_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  themeController.load();
  runApp(LifeGridApp());
}

class LifeGridApp extends StatelessWidget {
  LifeGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeController,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Life Grid',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(isDark),
          home: SessionGate(),
        );
      },
    );
  }
}

/// Restores a previous login session (works offline via cache), then
/// hosts the app. Also owns the "Lock After" behavior: watches app
/// lifecycle and re-locks after the configured period in background.
class SessionGate extends StatefulWidget {
  SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> with WidgetsBindingObserver {
  final _auth = AuthService();
  final _storage = StorageService();
  bool _checking = true;
  AppUser? _user;
  bool _locked = false;
  DateTime? _pausedAt;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _syncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_user != null) _storage.syncPending();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
    }
  }

  Future<void> _checkLockOnResume() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (_user == null || pausedAt == null) return;
    final minutes = await _storage.loadLockAfterMinutes();
    if (minutes <= 0) return; // "Never"
    final elapsed = DateTime.now().difference(pausedAt);
    if (elapsed.inMinutes >= minutes) {
      setState(() => _locked = true);
    }
    // Also opportunistically try syncing whatever piled up while away.
    _storage.syncPending();
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
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return LoginScreen(
        onLoggedIn: (user) => setState(() => _user = user),
      );
    }
    if (_locked) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
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
  RootShell({super.key, required this.onLogOut});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapNotifications();
    StorageService().syncPending();
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
      TimelineScreen(),
      JournalScreen(),
      StatsScreen(),
      SettingsScreen(onLogOut: widget.onLogOut),
    ];
    return Scaffold(
      body: Stack(
        children: [
          pages[_index],
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: HalStatusIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar_outlined, size: 20),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_timeline_outlined, size: 20),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined, size: 20),
            label: 'Journal',
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
