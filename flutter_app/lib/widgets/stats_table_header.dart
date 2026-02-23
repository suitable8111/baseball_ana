import 'package:flutter/material.dart';

class StatsTableHeader extends StatelessWidget {
  final List<(String, String, double)> columns; // (label, key, width)
  final String sortColumn;
  final bool sortAscending;
  final void Function(String) onSort;
  final double scale;

  const StatsTableHeader({
    super.key,
    required this.columns,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: columns.map((col) {
          final (label, key, width) = col;
          final isActive = sortColumn == key;
          final isNonSortable = key == 'rank';

          return GestureDetector(
            onTap: isNonSortable ? null : () => onSort(key),
            child: SizedBox(
              width: width * scale,
              height: 36,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11 * scale.clamp(1.0, 1.3),
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 2),
                      Icon(
                        sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
