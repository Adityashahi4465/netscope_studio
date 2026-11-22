import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_style.dart';
import '../../../widgets/chart_container.dart';
import '../controller/visualizer_controller.dart';

class ProtocolTimeline extends StatelessWidget {
  final VisualizerState state;
  const ProtocolTimeline(this.state, {super.key});
  @override
  Widget build(BuildContext context) => ChartContainer(
    title: state.replay
        ? 'Recorded UDP request status · illustrative motion'
        : 'Protocol illustration · not measured data',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.md,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Client', style: AppTextStyle.label),
            Text('Server', style: AppTextStyle.label),
          ],
        ),
        Semantics(
          label: state.activeStep?.explanation ?? 'No timeline steps',
          child: SizedBox(
            height: AppDimensions.timelineHeight,
            child: CustomPaint(
              painter: _TimelinePainter(
                state.activeStep,
                state.fraction,
                state.replay
                    ? AppColors.udp
                    : AppColors.forProtocol(state.protocol.name),
              ),
            ),
          ),
        ),
        if (state.activeStep case final step?) ...[
          Text(step.label, style: AppTextStyle.h3),
          Text(step.explanation, style: AppTextStyle.body),
          if (step.sentAtUs case final timestamp?)
            Text(
              'Recorded send time: ${(timestamp / 1000).toStringAsFixed(3)} ms from run start. '
              'Animation timing is illustrative.',
              style: AppTextStyle.bodySmall,
            ),
        ],
      ],
    ),
  );
}

class _TimelinePainter extends CustomPainter {
  final VisualStep? step;
  final double progress;
  final Color color;
  const _TimelinePainter(this.step, this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width < AppDimensions.narrowChartWidth
        ? AppDimensions.xl
        : AppDimensions.timelineEndpointInset;
    final left = Offset(inset, size.height / 2);
    final right = Offset(size.width - inset, size.height / 2);
    final lane = Paint()
      ..color = AppColors.border
      ..strokeWidth = AppDimensions.timelineStrokeWidth;
    canvas.drawLine(
      Offset(left.dx, AppDimensions.sm),
      Offset(left.dx, size.height - AppDimensions.sm),
      lane,
    );
    canvas.drawLine(
      Offset(right.dx, AppDimensions.sm),
      Offset(right.dx, size.height - AppDimensions.sm),
      lane,
    );
    canvas.drawCircle(
      left,
      AppDimensions.iconMd,
      Paint()..color = AppColors.surfaceElevated,
    );
    canvas.drawCircle(
      right,
      AppDimensions.iconMd,
      Paint()..color = AppColors.surfaceElevated,
    );
    if (step == null) return;
    final source = step!.fromClient ? left : right;
    final destination = step!.fromClient ? right : left;
    canvas.drawLine(source, destination, lane);
    final unknown = step!.outcome == VisualOutcome.unknown;
    final end = unknown ? Offset.lerp(source, destination, 0.5)! : destination;
    final point = Offset.lerp(source, end, progress)!;
    final ink = Paint()
      ..color = unknown ? AppColors.textDisabled : color
      ..strokeWidth = AppDimensions.timelineStrokeWidth;
    canvas.drawLine(source, point, ink);
    canvas.drawCircle(point, AppDimensions.timelineDotRadius, ink);
    if (progress > 0.8 && step!.outcome != VisualOutcome.delivered) {
      final label = TextPainter(
        text: TextSpan(
          text: unknown ? '?' : '×',
          style: AppTextStyle.metricValue.copyWith(
            color: unknown ? AppColors.textDisabled : AppColors.warning,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          end.dx - label.width / 2,
          end.dy - label.height - AppDimensions.md,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.step != step || old.progress != progress || old.color != color;
}
