import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A simple +/- number stepper for counter items (e.g. "how many times
/// today"), used instead of the 5-stage rating dots.
class CounterSelector extends StatelessWidget {
  final String label;
  final int value; // defaults to 0 when unset
  final ValueChanged<int> onChanged;

  const CounterSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textDim, letterSpacing: 0.03),
            ),
          ),
          SizedBox(width: 8),
          _stepButton(Icons.remove, onTap: value > 0 ? () => onChanged(value - 1) : null),
          SizedBox(width: 10),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          _stepButton(Icons.add, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, {VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: enabled ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Icon(icon, size: 16, color: enabled ? AppColors.accent : AppColors.textDim),
      ),
    );
  }
}
