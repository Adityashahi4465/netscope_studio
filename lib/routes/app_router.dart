import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/app_sidebar.dart';
import '../common/custom_app_bar.dart';
import '../common/custom_snackbar.dart';
import '../features/comparison/view/comparison_view.dart';
import '../features/dashboard/controller/benchmark_controller.dart';
import '../features/dashboard/view/dashboard_view.dart';
import '../features/history/view/history_view.dart';
import '../features/latency_analysis/view/latency_analysis_view.dart';
import '../features/packet_loss/view/packet_loss_view.dart';
import '../features/protocol_visualizer/view/protocol_visualizer_view.dart';
import '../modals/benchmark_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'navigation_controller.dart';

class AppRouter {
  static Route<void> generate(RouteSettings settings) {
    final route = LabRoute.values.firstWhere(
      (r) => r.path == settings.name,
      orElse: () => LabRoute.dashboard,
    );
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: AppDimensions.animFast,
      reverseTransitionDuration: AppDimensions.animFast,
      pageBuilder: (_, _, _) => Material(
        color: AppColors.background,
        child: _page(route, settings.arguments),
      ),
      transitionsBuilder: (context, animation, _, child) =>
          MediaQuery.disableAnimationsOf(context)
          ? child
          : FadeTransition(opacity: animation, child: child),
    );
  }

  static Widget _page(LabRoute route, Object? arguments) => switch (route) {
    LabRoute.dashboard => const DashboardView(),
    LabRoute.comparison => ComparisonView(
      initialSelection: arguments is List<String> ? arguments : const [],
    ),
    LabRoute.latency => const LatencyAnalysisView(),
    LabRoute.packetLoss => const PacketLossView(),
    LabRoute.history => const HistoryView(),
    LabRoute.visualizer => ProtocolVisualizerView(
      initialResult: arguments is BenchmarkResult ? arguments : null,
    ),
  };
}

/// The shell lives outside the navigator so its elements stay mounted and
/// stationary while the main-content navigator animates its own routes.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({required this.child, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(navigationControllerProvider);
    ref.listen(benchmarkControllerProvider, (before, next) {
      final message = next.notice ?? next.error;
      if (message != null && message != (before?.notice ?? before?.error)) {
        CustomSnackbar.show(context, message);
      }
    });
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              AppSidebar(
                route,
                compact: box.maxWidth < AppDimensions.breakpointMedium,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CustomAppBar(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
