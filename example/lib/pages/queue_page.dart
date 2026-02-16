import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/providers/player_provider.dart';
import 'package:mt_audio_example/sample_data/sample_data.dart';

/// Queue management page with full queue manipulation demo.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => unawaited(player.clearQueue()),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Queue controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Load playlist / Add random track
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await player.setPlaylist(sampleTracks);
                          await player.play();
                        },
                        icon: const Icon(Icons.playlist_play),
                        label: const Text('Load Playlist'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final randomTrack =
                              sampleTracks[Random().nextInt(
                                sampleTracks.length,
                              )];
                          // Create a copy with unique ID
                          final trackToAdd = randomTrack.copyWith(
                            id: '${randomTrack.id}-${DateTime.now().millisecondsSinceEpoch}',
                          );
                          unawaited(player.addToQueue(trackToAdd));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Random'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Queue info
                StreamBuilder<MtQueueState>(
                  stream: player.queueStateStream,
                  builder: (context, snapshot) {
                    final queueState =
                        snapshot.data ?? player.currentQueueState;
                    final length = queueState.length;
                    final currentIndex = queueState.queueIndex;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoChip(
                              icon: Icons.format_list_numbered,
                              label: 'Items',
                              value: '$length',
                            ),
                            _InfoChip(
                              icon: Icons.play_circle_outline,
                              label: 'Current',
                              value: currentIndex != null
                                  ? '${currentIndex + 1}/$length'
                                  : '-',
                            ),
                            _InfoChip(
                              icon: Icons.skip_previous,
                              label: 'Previous',
                              value: queueState.hasPrevious ? 'Yes' : 'No',
                            ),
                            _InfoChip(
                              icon: Icons.skip_next,
                              label: 'Next',
                              value: queueState.hasNext ? 'Yes' : 'No',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Navigation controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<MtQueueState>(
                      stream: player.queueStateStream,
                      builder: (context, snapshot) {
                        final queueState =
                            snapshot.data ?? player.currentQueueState;
                        return OutlinedButton.icon(
                          onPressed: queueState.hasPrevious
                              ? () => unawaited(player.skipToPrevious())
                              : null,
                          icon: const Icon(Icons.skip_previous),
                          label: const Text('Previous'),
                        );
                      },
                    ),
                    StreamBuilder<MtQueueState>(
                      stream: player.queueStateStream,
                      builder: (context, snapshot) {
                        final queueState =
                            snapshot.data ?? player.currentQueueState;
                        return FilledButton.icon(
                          onPressed: queueState.length > 1
                              ? () => _showSkipToDialog(
                                  context,
                                  player,
                                  queueState,
                                )
                              : null,
                          icon: const Icon(Icons.playlist_play),
                          label: const Text('Skip to #'),
                        );
                      },
                    ),
                    StreamBuilder<MtQueueState>(
                      stream: player.queueStateStream,
                      builder: (context, snapshot) {
                        final queueState =
                            snapshot.data ?? player.currentQueueState;
                        return OutlinedButton.icon(
                          onPressed: queueState.hasNext
                              ? () => unawaited(player.skipToNext())
                              : null,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Next'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Queue list
          Expanded(
            child: MtQueueListView(
              player: player,
              emptyBuilder: (context) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.queue_music,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Queue is empty',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Load a playlist or add tracks to get started',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSkipToDialog(
    BuildContext context,
    MtAudioPlayer player,
    MtQueueState queueState,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Skip to track'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: queueState.queue.length,
              itemBuilder: (context, index) {
                final item = queueState.queue[index];
                final isCurrent = index == queueState.queueIndex;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: item.artist != null ? Text(item.artist!) : null,
                  trailing: isCurrent ? const Icon(Icons.play_arrow) : null,
                  onTap: () {
                    unawaited(player.skipToIndex(index));
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
