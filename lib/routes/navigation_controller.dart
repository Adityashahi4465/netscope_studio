import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LabRoute {
  dashboard('/', 'Benchmark cockpit', Icons.speed),
  comparison('/comparison', 'TCP vs UDP', Icons.bar_chart),
  latency('/latency', 'Latency analysis', Icons.show_chart),
  packetLoss('/packet-loss', 'Packet loss', Icons.scatter_plot_outlined),
  history('/history', 'Experiment history', Icons.history),
  visualizer('/visualizer', 'Protocol visualizer', Icons.account_tree_outlined);

  final String path;
  final String title;
  final IconData icon;
  const LabRoute(this.path, this.title, this.icon);
}

class NavigationController extends StateNotifier<LabRoute> {
  NavigationController() : super(LabRoute.dashboard);
  void select(LabRoute route) => state = route;
}

final navigationControllerProvider =
    StateNotifierProvider<NavigationController, LabRoute>(
      (ref) => NavigationController(),
    );
