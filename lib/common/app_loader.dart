import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

class AppLoader extends StatelessWidget {
  final String message;
  const AppLoader(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppDimensions.md),
        Text(message),
      ],
    ),
  );
}
