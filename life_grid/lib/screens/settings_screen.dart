import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_version.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'parameters_screen.dart';
import 'tutorial_screen.dart';

const _lockOptions = <int, String>{
  0: 'Never',
  1: '1 minute',
  5: '5 minutes',
  15: '15 minutes',
  30: '30 minutes',
};

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogOut;
  SettingsScreen({super.key, required this.onLogOut});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _updateService = UpdateService();
  bool _checkingUpdate = false;
  final _notifications = NotificationService();
  TimeOfDay _time = TimeOfDay(hour: 20, minute: 0);
  bool _enabled = true;
  final _forecastController = TextEditingController();
  int _lockAfter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (hour, minute, enabled) = await _storage.loadNotifyTime();
    final forecastDays = await _storage.loadForecastDays();
    final lockAfter = await _storage.loadLockAfterMinutes();
    setState(() {
      _time = TimeOfDay(hour: hour, minute: minute);
      _enabled = enabled;
      _forecastController.text = forecastDays.toString();
      _lockAfter = lockAfter;
    });
  }

  Future<void> _setLockAfter(int minutes) async {
    setState(() => _lockAfter = minutes);
    await _storage.saveLockAfterMinutes(minutes);
  }

  Future<void> _saveForecastDays(String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 3) return; // need at least 3 points
    await _storage.saveForecastDays(parsed);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foreseeing window set to $parsed days.')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
      await _apply();
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _apply();
  }

  Future<void> _apply() async {
    await _storage.saveNotifyTime(_time.hour, _time.minute, _enabled);
    if (_enabled) {
      await _notifications.requestPermissions();
      await _notifications.scheduleDaily(_time.hour, _time.minute);
    } else {
      await _notifications.cancelDaily();
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    final result = await _updateService.check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (result.checkFailed) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text('Could not check', style: TextStyle(color: AppColors.text, fontSize: 15)),
          content: Text(
            'Could not reach the update server. Check your internet connection and try again.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    if (!result.updateAvailable) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text('You\'re up to date', style: TextStyle(color: AppColors.text, fontSize: 15)),
          content: Text(
            'Version ${result.currentVersion} is the latest.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Update available', style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: Text(
          'Version ${result.latestVersion} is out — you have ${result.currentVersion}.\n\n'
          'On the web, just reload the page to get it automatically. On Android, '
          'copy the link below and open it in your browser to download the latest APK.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _updateService.releasesUrl));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Copy Download Link', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: AppColors.textDim)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: Text(
                'Daily reminder',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                'Notify me every day to log my entry',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              value: _enabled,
              activeColor: AppColors.accent,
              onChanged: _toggleEnabled,
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                'Reminder time',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                _time.format(context),
                style: TextStyle(fontSize: 16, color: AppColors.accent),
              ),
              trailing:
                  Icon(Icons.schedule, color: AppColors.textDim, size: 18),
              onTap: _enabled ? _pickTime : null,
              enabled: _enabled,
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foreseeing window',
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'How many past days to base today\'s forecast on',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _forecastController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text, fontSize: 13),
                    decoration: InputDecoration(
                      suffixText: 'days',
                      suffixStyle: TextStyle(color: AppColors.textDim),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: _saveForecastDays,
                    onEditingComplete: () =>
                        _saveForecastDays(_forecastController.text),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Card(
            child: ListTile(
              title: Text(
                'Logged in as ${StorageService.currentUser?.name ?? ''}',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                'Log out of this account',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              trailing: Icon(Icons.logout, color: AppColors.danger, size: 18),
              onTap: widget.onLogOut,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'APPEARANCE',
            style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1),
          ),
          SizedBox(height: 8),
          Card(
            child: ValueListenableBuilder<bool>(
              valueListenable: themeController,
              builder: (context, isDark, _) {
                return SwitchListTile(
                  title: Text(
                    'Dark theme',
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                  subtitle: Text(
                    isDark ? 'Currently dark' : 'Currently light',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                  value: isDark,
                  activeColor: AppColors.accent,
                  onChanged: (v) => themeController.setDark(v),
                );
              },
            ),
          ),
          SizedBox(height: 24),
          Text(
            'SECURITY',
            style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1),
          ),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lock After',
                    style: TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Require your passcode again after this long in the background',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _lockOptions.entries.map((e) {
                      final selected = _lockAfter == e.key;
                      return GestureDetector(
                        onTap: () => _setLockAfter(e.key),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accentSoft : AppColors.bg,
                            border: Border.all(
                              color: selected ? AppColors.accent : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? AppColors.accent : AppColors.textDim,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'CATEGORIES',
            style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                'Parameters',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                'Simple/Precise mode, categories, items, and your own custom ones',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ParametersScreen()),
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'HELP',
            style: TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 1),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                'How Life Grid Works',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                'A quick tutorial for what everything does and why',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              trailing: Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TutorialScreen()),
              ),
            ),
          ),
          SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(
                'Check for Updates',
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
              subtitle: Text(
                'Currently running version $kAppVersion',
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
              trailing: _checkingUpdate
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh, color: AppColors.textDim, size: 18),
              onTap: _checkingUpdate ? null : _checkForUpdates,
            ),
          ),
          SizedBox(height: 32),
          Text(
            '|   Developed By   |   Modjtaba M. Mansouri   |   All Rights Reserved   |   Version 2.7.4   |   2026   |',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textDim),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}
