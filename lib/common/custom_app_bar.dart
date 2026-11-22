import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../features/dashboard/controller/benchmark_controller.dart';
import '../features/dashboard/controller/config_field.dart';
import '../features/dashboard/widgets/config_form.dart';
import '../routes/route_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';
import '../widgets/status_indicator.dart';

class CustomAppBar extends ConsumerWidget {
  const CustomAppBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchmarkControllerProvider);
    final tcp = state.status.isActive && state.progress.tcpOnline;
    final udp = state.status.isActive && state.progress.udpOnline;
    return Container(
      padding: AppDimensions.cardPadding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: AppDimensions.xl,
                children: [
                  Text(AppConstants.appName, style: AppTextStyle.h2),
                  StatusIndicator(
                    state.status.label,
                    state.status.isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  StatusIndicator(
                    'TCP ${tcp ? 'online' : 'offline'}',
                    tcp ? AppColors.tcp : AppColors.textDisabled,
                  ),
                  StatusIndicator(
                    'UDP ${udp ? 'online' : 'offline'}',
                    udp ? AppColors.udp : AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Run settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                unawaited(RouteUtils.dialog(context, const _Settings())),
          ),
        ],
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Dialog(
    child: SingleChildScrollView(
      padding: AppDimensions.cardPaddingLarge,
      child: SizedBox(
        width: AppDimensions.sidebarWidth * 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.lg,
          children: [
            Text('Run settings', style: AppTextStyle.h2),
            const Text('Loopback host  ·  127.0.0.1'),
            const ConfigFields([
              ConfigField.tcpPort,
              ConfigField.udpPort,
              ConfigField.timeout,
              ConfigField.seed,
            ]),
            if (ref.watch(benchmarkControllerProvider).validation
                case final problem?)
              Text(problem),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => RouteUtils.close(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
