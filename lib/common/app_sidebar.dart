import 'package:flutter/material.dart';

import '../routes/route_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_style.dart';

class AppSidebar extends StatelessWidget {
  final LabRoute current;
  final bool compact;
  const AppSidebar(this.current, {this.compact = false, super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: compact
        ? AppDimensions.sidebarCollapsedWidth
        : AppDimensions.sidebarWidth,
    color: AppColors.sidebar,
    child: ListView(
      padding: const EdgeInsets.all(AppDimensions.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
          child: compact
              ? const Icon(Icons.hub_outlined, color: AppColors.primaryLight)
              : Row(
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Text('Network lab', style: AppTextStyle.h2),
                  ],
                ),
        ),
        const Divider(),
        const SizedBox(height: AppDimensions.lg),
        for (final route in LabRoute.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.xs),
            child: Tooltip(
              message: route.title,
              child: Material(
                color: route == current
                    ? AppColors.primarySoft
                    : AppColors.sidebar,
                borderRadius: AppDimensions.borderRadiusSm,
                child: InkWell(
                  borderRadius: AppDimensions.borderRadiusSm,
                  onTap: () => RouteUtils.go(context, route),
                  child: SizedBox(
                    height: AppDimensions.sidebarItemHeight,
                    child: Row(
                      mainAxisAlignment: compact
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        if (!compact) const SizedBox(width: AppDimensions.md),
                        Icon(
                          route.icon,
                          color: route == current
                              ? AppColors.primaryLight
                              : AppColors.textSecondary,
                        ),
                        if (!compact) ...[
                          const SizedBox(width: AppDimensions.md),
                          Flexible(
                            child: Text(
                              route.title,
                              style: route == current
                                  ? AppTextStyle.navItemActive
                                  : AppTextStyle.navItem,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
