import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'modern_card.dart';

/// A card-based table widget for dashboard data displays.
///
/// Renders a header row followed by data rows, styled with the CISS
/// Material 3 design tokens. Supports optional per-column alignment
/// and highlight colors.
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.headerColor,
    this.emptyMessage = 'No data available',
    this.padding = const EdgeInsets.all(16),
  });

  final List<DataTableColumn> columns;
  final List<DataTableRow> rows;
  final Color? headerColor;
  final String emptyMessage;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = CissThemeTokens.of(context);

    return ModernCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (columns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: columns.map((col) {
                  return Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label.toUpperCase(),
                      textAlign: col.alignment,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: headerColor ?? tokens.inkMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (columns.isNotEmpty)
            Container(height: 1, color: tokens.border),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
            )
          else
            ...rows.map((row) {
              final isLast = rows.indexOf(row) == rows.length - 1;
              return Padding(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: isLast ? 0 : 8,
                ),
                child: Row(
                  children: row.cells.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cell = entry.value;
                    final col = i < columns.length ? columns[i] : null;
                    return Expanded(
                      flex: col?.flex ?? 1,
                      child: Text(
                        cell.text,
                        textAlign: col?.alignment ?? TextAlign.start,
                        maxLines: cell.maxLines ?? 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: cell.isBold
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: cell.color ?? tokens.ink,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// A column definition for [DataTableCard].
class DataTableColumn {
  const DataTableColumn({
    required this.label,
    this.flex = 1,
    this.alignment = TextAlign.start,
  });

  final String label;
  final int flex;
  final TextAlign alignment;
}

/// A row in [DataTableCard].
class DataTableRow {
  const DataTableRow({
    required this.cells,
  });

  final List<DataTableCell> cells;
}

/// A single cell value in [DataTableRow].
class DataTableCell {
  const DataTableCell({
    required this.text,
    this.color,
    this.isBold = false,
    this.maxLines,
  });

  final String text;
  final Color? color;
  final bool isBold;
  final int? maxLines;
}
