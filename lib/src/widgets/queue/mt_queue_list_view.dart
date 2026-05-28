import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';
import 'package:mt_audio/src/widgets/queue/mt_queue_item_tile.dart';

/// A reorderable, dismissible list view for the audio queue.
///
/// Displays the current queue with support for reordering (drag to reorder)
/// and removal (swipe to dismiss).
class MtQueueListView extends StatelessWidget {
  /// Creates an [MtQueueListView].
  const MtQueueListView({
    required this.player,
    this.itemBuilder,
    this.enableReorder = true,
    this.enableDismiss = true,
    this.emptyBuilder,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Custom builder for queue items.
  ///
  /// If null, uses [MtQueueItemTile].
  final Widget Function(
    BuildContext context,
    MtAudioItem item,
    int index,
    bool isCurrentItem,
  )?
  itemBuilder;

  /// Whether to enable reordering items.
  final bool enableReorder;

  /// Whether to enable dismissing (removing) items.
  final bool enableDismiss;

  /// Builder for empty state.
  final Widget Function(BuildContext context)? emptyBuilder;

  Widget _buildDismissible({
    required BuildContext context,
    required Widget child,
    required MtAudioItem item,
    required int index,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('${item.id}::${item.uri}::$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      onDismissed: (direction) {
        unawaited(player.removeFromQueue(index));
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: player.queueStateStream,
      builder: (context, snapshot) {
        final queueState = snapshot.data ?? player.currentQueueState;

        if (queueState.isEmpty) {
          return emptyBuilder?.call(context) ??
              const Center(
                child: Text('Queue is empty'),
              );
        }

        if (enableReorder) {
          return ReorderableListView.builder(
            itemCount: queueState.queue.length,
            onReorderItem: (oldIndex, newIndex) {
              unawaited(player.reorderQueue(oldIndex, newIndex));
            },
            itemBuilder: (context, index) {
              final item = queueState.queue[index];
              final isCurrentItem = index == queueState.queueIndex;

              final child =
                  itemBuilder?.call(
                    context,
                    item,
                    index,
                    isCurrentItem,
                  ) ??
                  MtQueueItemTile(
                    key: ValueKey('${item.id}::${item.uri}::$index'),
                    item: item,
                    isCurrentItem: isCurrentItem,
                    showDragHandle: true,
                    reorderIndex: index,
                    onTap: () => player.skipToIndex(index),
                  );

              final keyedChild = itemBuilder == null
                  ? child
                  : KeyedSubtree(
                      key: ValueKey('${item.id}::${item.uri}::$index'),
                      child: child,
                    );

              return enableDismiss
                  ? _buildDismissible(
                      context: context,
                      child: keyedChild,
                      item: item,
                      index: index,
                    )
                  : keyedChild;
            },
          );
        }

        return ListView.builder(
          itemCount: queueState.queue.length,
          itemBuilder: (context, index) {
            final item = queueState.queue[index];
            final isCurrentItem = index == queueState.queueIndex;

            final child =
                itemBuilder?.call(
                  context,
                  item,
                  index,
                  isCurrentItem,
                ) ??
                MtQueueItemTile(
                  item: item,
                  isCurrentItem: isCurrentItem,
                  onTap: () => player.skipToIndex(index),
                );

            return enableDismiss
                ? _buildDismissible(
                    context: context,
                    child: child,
                    item: item,
                    index: index,
                  )
                : child;
          },
        );
      },
    );
  }
}
