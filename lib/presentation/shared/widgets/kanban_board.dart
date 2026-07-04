import 'package:flutter/material.dart';

class KanbanColumnDef<S> {
  final S status;
  final String label;
  final IconData icon;
  final Color color;
  const KanbanColumnDef({required this.status, required this.label, required this.icon, required this.color});
}

/// A horizontally-scrolling Kanban board. Generic over item type [T] and
/// status type [S] so it can drive both the cross-project "My Tasks" view
/// and a single project's task list without duplicating drag/drop logic.
///
/// Uses Flutter's built-in LongPressDraggable/DragTarget rather than a
/// third-party package -- long-press (not plain drag) is used so a normal
/// vertical scroll gesture inside a column isn't mistaken for a drag.
class KanbanBoard<T extends Object, S> extends StatelessWidget {
  final List<KanbanColumnDef<S>> columns;
  final List<T> items;
  final S Function(T item) statusOf;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final void Function(T item, S newStatus) onStatusChanged;
  final double columnWidth;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.items,
    required this.statusOf,
    required this.cardBuilder,
    required this.onStatusChanged,
    this.columnWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: [
        for (final column in columns)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _KanbanColumn<T, S>(
              column: column,
              items: items.where((i) => statusOf(i) == column.status).toList(),
              cardBuilder: cardBuilder,
              width: columnWidth,
              onAccept: (item) => onStatusChanged(item, column.status),
            ),
          ),
      ],
    );
  }
}

class _KanbanColumn<T extends Object, S> extends StatelessWidget {
  final KanbanColumnDef<S> column;
  final List<T> items;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final double width;
  final void Function(T item) onAccept;

  const _KanbanColumn({
    required this.column,
    required this.items,
    required this.cardBuilder,
    required this.width,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<T>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: isHovering
                ? column.color.withOpacity(0.08)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: isHovering ? Border.all(color: column.color, width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Icon(column.icon, size: 15, color: column.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        column.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: column.color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: column.color.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
                      child: Text('${items.length}', style: TextStyle(color: column.color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Drop here',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: column.color.withOpacity(0.6)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LongPressDraggable<T>(
                              data: item,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(width: width - 16, child: Opacity(opacity: 0.9, child: cardBuilder(context, item))),
                              ),
                              childWhenDragging: Opacity(opacity: 0.3, child: cardBuilder(context, item)),
                              child: cardBuilder(context, item),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
