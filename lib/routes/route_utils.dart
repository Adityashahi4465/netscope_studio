import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modals/benchmark_result.dart';
import 'navigation_controller.dart';
export 'navigation_controller.dart' show LabRoute;

class RouteUtils {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void go(BuildContext context, LabRoute route, {Object? arguments}) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (container.read(navigationControllerProvider) == route &&
        arguments == null) {
      return;
    }
    container.read(navigationControllerProvider.notifier).select(route);
    (navigatorKey.currentState ?? Navigator.of(context)).pushReplacementNamed(
      route.path,
      arguments: arguments,
    );
  }

  static void compare(BuildContext context, Iterable<String> ids) => go(
    context,
    LabRoute.comparison,
    arguments: List<String>.unmodifiable(ids),
  );

  static void replay(BuildContext context, BenchmarkResult result) =>
      go(context, LabRoute.visualizer, arguments: result);

  static Future<void> dialog(BuildContext context, Widget content) =>
      showDialog<void>(
        context: navigatorKey.currentState?.overlay?.context ?? context,
        builder: (_) => content,
      );

  static void close(BuildContext context) =>
      (navigatorKey.currentState ?? Navigator.of(context)).pop();
}
