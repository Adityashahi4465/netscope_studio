import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String initial;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const CustomTextField({
    required this.label,
    required this.initial,
    required this.enabled,
    required this.onChanged,
    this.error,
    super.key,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, errorText: error),
  );
}
