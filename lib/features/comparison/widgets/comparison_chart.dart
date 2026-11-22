import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../../../widgets/status_indicator.dart';
import '../controller/comparison_report.dart';

class ComparisonChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<ChartPoint> points;
  final List<String> footnotes;
  const ComparisonChart({
    required this.title,
    required this.unit,
    required this.points,
    this.footnotes = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final point in points) ...[?point.tcp, ?point.udp],
    ];
    final maxValue = values.fold(0.0, max);
    final ceiling = unit == '%'
        ? 100.0
        : maxValue == 0
        ? 1.0
        : maxValue * 1.15;
    return ChartContainer(
      title: '$title ($unit)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.md,
        children: [
          const Wrap(
            spacing: AppDimensions.lg,
            children: [
              StatusIndicator('TCP', AppColors.tcp),
              StatusIndicator('UDP', AppColors.udp),
            ],
          ),
          if (values.isEmpty)
            Text(
              'Insufficient successful RTT samples for this measurement.',
              style: AppTextStyle.body,
            )
          else
            LayoutBuilder(
              builder: (_, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: max(
                    box.maxWidth,
                    points.length * AppDimensions.topBarHeight +
                        AppDimensions.xxxl,
                  ),
                  height: AppDimensions.chartHeightSm,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: ceiling,
                      barGroups: [
                        for (var i = 0; i < points.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              if (points[i].tcp case final value?)
                                _rod(value, AppColors.tcp),
                              if (points[i].udp case final value?)
                                _rod(value, AppColors.udp),
                            ],
                          ),
                      ],
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.chartTooltip,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                            '${points[group.x].label} · ${rod.color == AppColors.tcp ? 'TCP' : 'UDP'}\n${rod.toY.toStringAsPrecision(4)} $unit',
                            AppTextStyle.chartLegend,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: ceiling / 4,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.chartGrid),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: AppDimensions.xxxl,
                            interval: ceiling / 4,
                            getTitlesWidget: (value, _) => Text(
                              value == 0 ? '0' : value.toStringAsPrecision(2),
                              style: AppTextStyle.chartAxis,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: AppDimensions.xl,
                            getTitlesWidget: (x, _) => Text(
                              points[x.toInt()].label,
                              style: AppTextStyle.chartAxis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
          for (final note in footnotes)
            Text(note, style: AppTextStyle.bodySmall),
        ],
      ),
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: AppDimensions.md,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppDimensions.xs),
    ),
  );
}
