import 'package:flutter/material.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) title;
  final ValueChanged<T>? onChanged;
  const CustomDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.title,
    this.onChanged,
    super.key,
  });
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        items: [
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(title(item), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged!(v);
              },
      ),
    ),
  );
}
