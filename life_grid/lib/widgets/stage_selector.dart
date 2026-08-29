import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A row of 5 tappable dots for Disaster..Wonderful, used for one category.
class StageSelector extends StatelessWidget {
  final String label;
  final int? value; // 1..5 or null (unset)
  final ValueChanged<int> onChanged;

  StageSelector({
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
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDim,
                letterSpacing: 0.03,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(5, (i) {
                final stage = i + 1;
                final selected = value == stage;
                final color = AppColors.stageColors[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(stage),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      height: 28,
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.18) : AppColors.bg,
                        border: Border.all(
                          color: selected ? color : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? color : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
