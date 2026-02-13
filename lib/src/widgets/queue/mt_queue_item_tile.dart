import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';

/// Default queue item tile with artwork, title, artist, and drag handle.
///
/// Used by [MtQueueListView] to display queue items.
class MtQueueItemTile extends StatelessWidget {
  /// Creates an [MtQueueItemTile].
  const MtQueueItemTile({
    required this.item,
    required this.isCurrentItem,
    this.onTap,
    this.showDragHandle = false,
    this.reorderIndex,
    super.key,
  });

  /// The audio item to display.
  final MtAudioItem item;

  /// Whether this is the currently playing item.
  final bool isCurrentItem;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether to show a drag handle.
  final bool showDragHandle;

  /// Reorder index used by [ReorderableDragStartListener].
  ///
  /// Required when [showDragHandle] is true.
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: MtArtwork(
        artworkUri: item.artworkUri,
        size: 48,
      ),
      title: Text(
        item.title,
        style: isCurrentItem
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              )
            : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: item.artist != null
          ? Text(
              item.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: showDragHandle
          ? ReorderableDragStartListener(
              index: reorderIndex ?? 0,
              child: const Icon(Icons.drag_handle),
            )
          : null,
      onTap: onTap,
    );
  }
}
