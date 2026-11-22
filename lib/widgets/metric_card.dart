import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final Color color;
  const MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: AppDimensions.cardPadding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppDimensions.borderRadiusMd,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyle.label),
        const SizedBox(height: AppDimensions.sm),
        Text(value, style: AppTextStyle.metricValue.copyWith(color: color)),
        const SizedBox(height: AppDimensions.xs),
        Text(detail, style: AppTextStyle.bodySmall),
      ],
    ),
  );
}
