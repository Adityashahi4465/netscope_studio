import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../controller/latency_controller.dart';

class LatencyCharts extends StatelessWidget {
  final LatencyReport report;
  const LatencyCharts(this.report, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.lg,
    children: [
      ChartContainer(
        title: 'Measured per-probe RTT (ms)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.md,
          children: [
            Text(
              'Successful sample index within repetition ${report.runs.indexOf(report.runIndex) + 1}. '
              'Timed-out probes are excluded; their original positions were not recorded.',
              style: AppTextStyle.bodySmall,
            ),
            LayoutBuilder(
              builder: (_, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: max(box.maxWidth, AppDimensions.histogramMinWidth),
                  height: AppDimensions.chartHeightSm,
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: max(2, report.samples.length).toDouble(),
                      minY: 0,
                      maxY: max(1.0, report.metrics.maxRttMs * 1.15),
                      titlesData: _titles(),
                      borderData: FlBorderData(show: false),
                      gridData: _grid(),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.chartTooltip,
                          getTooltipItems: (spots) => spots
                              .map(
                                (spot) => LineTooltipItem(
                                  'Sample ${spot.x.toInt()}\n${spot.y.toStringAsFixed(3)} ms',
                                  AppTextStyle.chartLegend,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < report.samples.length; i++)
                              FlSpot(i + 1.0, report.samples[i]),
                          ],
                          color: AppColors.forProtocol(report.protocol.name),
                          isCurved: false,
                          barWidth: AppDimensions.borderWidthFocused,
                          dotData: FlDotData(show: report.samples.length <= 40),
                        ),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ChartContainer(
        title: 'RTT histogram · samples per interval (ms)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.md,
          children: [
            Text(
              'Equal-width intervals; the final interval includes its upper bound.',
              style: AppTextStyle.bodySmall,
            ),
            LayoutBuilder(
              builder: (_, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: max(box.maxWidth, AppDimensions.histogramMinWidth),
                  height: AppDimensions.chartHeightSm,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY:
                          max(
                            1,
                            report.histogram.fold(0, (n, b) => max(n, b.count)),
                          ).toDouble() *
                          1.2,
                      gridData: _grid(),
                      borderData: FlBorderData(show: false),
                      titlesData: _titles(histogram: true),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.chartTooltip,
                          fitInsideHorizontally: true,
                          getTooltipItem: (group, _, rod, _) {
                            final bin = report.histogram[group.x];
                            return BarTooltipItem(
                              '${bin.lower.toStringAsFixed(3)}–${bin.upper.toStringAsFixed(3)} ms\n${bin.count} samples',
                              AppTextStyle.chartLegend,
                            );
                          },
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < report.histogram.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: report.histogram[i].count.toDouble(),
                                color: AppColors.forProtocol(
                                  report.protocol.name,
                                ),
                                width: AppDimensions.lg,
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  FlGridData _grid() => FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.chartGrid),
  );

  FlTitlesData _titles({bool histogram = false}) => FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: AppDimensions.xxxl,
        getTitlesWidget: (value, _) =>
            Text(value.toStringAsPrecision(2), style: AppTextStyle.chartAxis),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: AppDimensions.xxl,
        interval: histogram
            ? 1
            : max(1, (report.samples.length / 8).ceil()).toDouble(),
        getTitlesWidget: (value, _) {
          final index = value.toInt();
          if (value != index.toDouble()) return const SizedBox.shrink();
          final label =
              histogram && index >= 0 && index < report.histogram.length
              ? report.histogram[index].lower.toStringAsPrecision(3)
              : histogram
              ? ''
              : '$index';
          return Text(label, style: AppTextStyle.chartAxis);
        },
      ),
    ),
  );
}
