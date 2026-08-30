import 'auth_service.dart';

/// Parses a birthday stored as "DD/MM/YYYY" and returns the person's
/// current age in whole years, or null if it can't be parsed.
int? calculateAge(String birthday) {
  final parts = birthday.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;

  final now = DateTime.now();
  var age = now.year - year;
  final hasHadBirthdayThisYear =
      now.month > month || (now.month == month && now.day >= day);
  if (!hasHadBirthdayThisYear) age -= 1;
  return age;
}

/// True only when the user's stored birthday clearly indicates 18+.
/// Unparseable/missing birthdays are treated as NOT adult — adult-only
/// content stays hidden unless age is clearly established, rather than
/// assuming access is fine when we can't tell.
bool isAdult(AppUser? user) {
  final birthday = user?.birthday;
  if (birthday == null || birthday.isEmpty) return false;
  final age = calculateAge(birthday);
  if (age == null) return false;
  return age >= 18;
}
