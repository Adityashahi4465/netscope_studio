import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  const StatusIndicator(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: const SizedBox.square(dimension: AppDimensions.statusDotSize),
      ),
      const SizedBox(width: AppDimensions.sm),
      Text(label, style: AppTextStyle.chartLegend),
    ],
  );
}
