import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Shows a dismissible "Happy Birthday" banner for the whole day the
/// user's birthday falls on, based on the DD/MM/YYYY they entered at
/// signup. Dismissing hides it for the rest of that day; it comes back
/// next year.
class BirthdayBanner extends StatefulWidget {
  const BirthdayBanner({super.key});

  @override
  State<BirthdayBanner> createState() => _BirthdayBannerState();
}

class _BirthdayBannerState extends State<BirthdayBanner> {
  bool _visible = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final birthday = StorageService.currentUser?.birthday ?? '';
    final parts = birthday.split('/');
    if (parts.length != 3) {
      setState(() => _checked = true);
      return;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (day == null || month == null) {
      setState(() => _checked = true);
      return;
    }
    final now = DateTime.now();
    final isBirthday = now.day == day && now.month == month;
    if (!isBirthday) {
      setState(() => _checked = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final dismissedKey =
        'life_grid_birthday_dismissed_${StorageService.currentUser?.slug}_${now.year}-${now.month}-${now.day}';
    final dismissed = prefs.getBool(dismissedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _visible = !dismissed;
      _checked = true;
    });
  }

  Future<void> _dismiss() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final dismissedKey =
        'life_grid_birthday_dismissed_${StorageService.currentUser?.slug}_${now.year}-${now.month}-${now.day}';
    await prefs.setBool(dismissedKey, true);
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_visible) return SizedBox.shrink();
    final name = StorageService.currentUser?.name ?? '';
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Text('🎉🎂🥳', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Happy Birthday, $name!',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppColors.textDim),
            onPressed: _dismiss,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
