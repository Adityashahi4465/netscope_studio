import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import 'metric_card.dart';

class MetricGrid extends StatelessWidget {
  final List<MetricCard> cards;
  const MetricGrid(this.cards, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final columns = (box.maxWidth / AppDimensions.metricCardMinWidth)
          .floor()
          .clamp(1, 4);
      final width = (box.maxWidth - (columns - 1) * AppDimensions.md) / columns;
      return Wrap(
        spacing: AppDimensions.md,
        runSpacing: AppDimensions.md,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );
}
