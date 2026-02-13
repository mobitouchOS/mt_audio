import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/providers/player_provider.dart';

/// State inspector page showing all streams and state values in real-time.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('State & Debug'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Playback state
          _StateCard(
            title: 'playbackStateStream',
            icon: Icons.play_circle_outline,
            child: StreamBuilder<MtPlaybackState>(
              stream: player.playbackStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? player.currentPlaybackState;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('status', state.status.name),
                    _StateRow('isPlaying', '${state.isPlaying}'),
                    _StateRow('isPaused', '${state.isPaused}'),
                    _StateRow('isLoading', '${state.isLoading}'),
                    _StateRow('repeatMode', state.repeatMode.name),
                    _StateRow('shuffleEnabled', '${state.shuffleEnabled}'),
                    _StateRow('volume', state.volume.toStringAsFixed(2)),
                    _StateRow('speed', '${state.speed}x'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Position state
          _StateCard(
            title: 'positionStateStream',
            icon: Icons.timer,
            child: StreamBuilder<MtPositionState>(
              stream: player.positionStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? player.currentPositionState;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('position', _formatDuration(state.position)),
                    _StateRow(
                      'bufferedPosition',
                      _formatDuration(state.bufferedPosition),
                    ),
                    _StateRow('duration', _formatDuration(state.duration)),
                    _StateRow(
                      'progress',
                      '${(state.progress * 100).toStringAsFixed(1)}%',
                    ),
                    _StateRow(
                      'bufferedProgress',
                      '${(state.bufferedProgress * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Queue state
          _StateCard(
            title: 'queueStateStream',
            icon: Icons.queue_music,
            child: StreamBuilder<MtQueueState>(
              stream: player.queueStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? player.currentQueueState;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('length', '${state.length}'),
                    _StateRow('currentIndex', '${state.queueIndex ?? 'null'}'),
                    _StateRow('isEmpty', '${state.isEmpty}'),
                    _StateRow('hasNext', '${state.hasNext}'),
                    _StateRow('hasPrevious', '${state.hasPrevious}'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Current item
          _StateCard(
            title: 'currentItemStream',
            icon: Icons.music_note,
            child: StreamBuilder<MtAudioItem?>(
              stream: player.currentItemStream,
              builder: (context, snapshot) {
                final item = snapshot.data ?? player.currentItem;
                if (item == null) {
                  return const Text(
                    'null (no track loaded)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('id', item.id),
                    _StateRow('title', item.title),
                    _StateRow('artist', item.artist ?? 'null'),
                    _StateRow('album', item.album ?? 'null'),
                    _StateRow('isLive', '${item.isLive}'),
                    _StateRow('duration', _formatDuration(item.duration)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ICY Metadata (for live streams)
          _StateCard(
            title: 'icyMetadataStream',
            icon: Icons.sensors,
            child: StreamBuilder<IcyMetadata?>(
              stream: player.icyMetadataStream,
              builder: (context, snapshot) {
                final metadata = snapshot.data;
                if (metadata == null) {
                  return const Text(
                    'null (no ICY metadata)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('title', metadata.info?.title ?? 'null'),
                    _StateRow('url', metadata.info?.url ?? 'null'),
                    _StateRow('genre', metadata.headers?.genre ?? 'null'),
                    _StateRow(
                      'bitrate',
                      '${metadata.headers?.bitrate ?? 'null'}',
                    ),
                    _StateRow('station', metadata.headers?.name ?? 'null'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Error stream
          _StateCard(
            title: 'errorStream',
            icon: Icons.error_outline,
            color: theme.colorScheme.errorContainer,
            child: StreamBuilder<MtAudioError?>(
              stream: player.errorStream,
              builder: (context, snapshot) {
                final error = snapshot.data;
                if (error == null) {
                  return const Text(
                    'No errors',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StateRow('code', error.code.name),
                    _StateRow('message', error.message),
                    if (error.details != null)
                      _StateRow('details', error.details!),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Text(
            'Actions',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.stop()),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.pause()),
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.play()),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.setVolume(0)),
                icon: const Icon(Icons.volume_off),
                label: const Text('Mute'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.setVolume(1)),
                icon: const Icon(Icons.volume_up),
                label: const Text('Full Volume'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(player.setSpeed(1)),
                icon: const Icon(Icons.restore),
                label: const Text('Reset Speed'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Warning about dispose
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calling dispose() will permanently stop the player. '
                    'You will need to restart the app to use the player again.',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => _showDisposeConfirmation(context, player),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Dispose Player'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80), // Space for mini player
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'null';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final ms = duration.inMilliseconds.remainder(1000);
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  void _showDisposeConfirmation(BuildContext context, MtAudioPlayer player) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dispose Player?'),
          content: const Text(
            'This will permanently stop the player and release all resources. '
            'You will need to restart the app to use the player again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                unawaited(player.dispose());
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Player disposed. Restart the app to continue.',
                    ),
                  ),
                );
              },
              child: const Text('Dispose'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.icon,
    required this.child,
    this.color,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
