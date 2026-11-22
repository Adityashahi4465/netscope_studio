import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/app_sidebar.dart';
import '../common/custom_app_bar.dart';
import '../common/custom_snackbar.dart';
import '../features/comparison/view/comparison_view.dart';
import '../features/dashboard/controller/benchmark_controller.dart';
import '../features/dashboard/view/dashboard_view.dart';
import '../theme/app_dimensions.dart';
import 'route_utils.dart';

class AppRouter {
  static Route<void> generate(RouteSettings settings) {
    final route = LabRoute.values.firstWhere(
      (r) => r.path == settings.name,
      orElse: () => LabRoute.dashboard,
    );
    return MaterialPageRoute(settings: settings, builder: (_) => _Shell(route));
  }
}

class _Shell extends ConsumerWidget {
  final LabRoute route;
  const _Shell(this.route);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(benchmarkControllerProvider, (before, next) {
      final message = next.notice ?? next.error;
      if (message != null &&
          message != (before?.notice ?? before?.error) &&
          ModalRoute.of(context)?.isCurrent == true) {
        CustomSnackbar.show(context, message);
      }
    });
    final page = switch (route) {
      LabRoute.dashboard => const DashboardView(),
      LabRoute.comparison => const ComparisonView(),
      _ => Center(child: Text('${route.title} is planned for a later phase.')),
    };
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
                    Expanded(child: page),
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
