import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';

class ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  const ChartContainer({
    required this.title,
    required this.child,
    this.icon,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: AppColors.border),
      borderRadius: AppDimensions.borderRadiusLg,
    ),
    child: Padding(
      padding: AppDimensions.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primaryLight),
                const SizedBox(width: AppDimensions.sm),
              ],
              Expanded(child: Text(title, style: AppTextStyle.h3)),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          child,
        ],
      ),
    ),
  );
}
