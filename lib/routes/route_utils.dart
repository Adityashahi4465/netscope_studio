import 'package:flutter/material.dart';

enum LabRoute {
  dashboard('/', 'Benchmark cockpit', Icons.speed),
  comparison('/comparison', 'TCP vs UDP', Icons.bar_chart),
  latency('/latency', 'Latency analysis', Icons.show_chart, available: false),
  packetLoss(
    '/packet-loss',
    'Packet loss',
    Icons.scatter_plot_outlined,
    available: false,
  ),
  history('/history', 'Experiment history', Icons.history, available: false),
  visualizer(
    '/visualizer',
    'Protocol visualizer',
    Icons.account_tree_outlined,
    available: false,
  );

  final String path;
  final String title;
  final IconData icon;
  final bool available;
  const LabRoute(this.path, this.title, this.icon, {this.available = true});
}

class RouteUtils {
  static void go(BuildContext context, LabRoute route) {
    if (ModalRoute.of(context)?.settings.name == route.path) return;
    Navigator.of(context).pushReplacementNamed(route.path);
  }

  static Future<void> dialog(BuildContext context, Widget content) =>
      showDialog<void>(context: context, builder: (_) => content);

  static void close(BuildContext context) => Navigator.of(context).pop();
}
