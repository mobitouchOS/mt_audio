import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/providers/player_provider.dart';

/// Widget showcase page demonstrating all available widgets.
class WidgetsPage extends StatelessWidget {
  const WidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Gallery'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // MtPlayPauseButton variations
          _WidgetSection(
            title: 'MtPlayPauseButton',
            description:
                'Animated play/pause button with loading state support.',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      MtPlayPauseButton(
                        player: player,
                        size: 40,
                      ),
                      const SizedBox(height: 4),
                      Text('Small (40)', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Column(
                    children: [
                      MtPlayPauseButton(
                        player: player,
                        size: 56,
                      ),
                      const SizedBox(height: 4),
                      Text('Default (56)', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Column(
                    children: [
                      MtPlayPauseButton(
                        player: player,
                        size: 72,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(height: 4),
                      Text('Large (72)', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),

          // MtSkipButton variations
          _WidgetSection(
            title: 'MtSkipButton',
            description: 'Skip forward/backward buttons.',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      MtSkipButton(
                        player: player,
                        direction: MtSkipDirection.backward,
                      ),
                      const SizedBox(height: 4),
                      Text('Backward', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Column(
                    children: [
                      MtSkipButton(
                        player: player,
                        direction: MtSkipDirection.forward,
                      ),
                      const SizedBox(height: 4),
                      Text('Forward', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  Column(
                    children: [
                      MtSkipButton(
                        player: player,
                        direction: MtSkipDirection.forward,
                        size: 56,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 4),
                      Text('Custom', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),

          // MtSeekBar variations
          _WidgetSection(
            title: 'MtSeekBar',
            description: 'Seek bar with buffered progress and position labels.',
            children: [
              const Text('Default style:'),
              const SizedBox(height: 8),
              MtSeekBar(player: player),
              const SizedBox(height: 24),
              const Text('Custom style (no labels):'),
              const SizedBox(height: 8),
              MtSeekBar(player: player, showLabels: false),
            ],
          ),
          const Divider(height: 32),

          // MtArtwork variations
          _WidgetSection(
            title: 'MtArtwork',
            description: 'Album artwork with placeholder and error handling.',
            children: [
              StreamBuilder(
                stream: player.currentItemStream,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          MtArtwork(
                            artworkUri: item?.artworkUri,
                            size: 80,
                          ),
                          const SizedBox(height: 4),
                          Text('80x80', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          MtArtwork(
                            artworkUri: item?.artworkUri,
                            size: 100,
                            borderRadius: 50,
                          ),
                          const SizedBox(height: 4),
                          Text('Circular', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          const MtArtwork(
                            artworkUri: null,
                            size: 80,
                            borderRadius: 4,
                          ),
                          const SizedBox(height: 4),
                          Text('Placeholder', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const Divider(height: 32),

          // MtNowPlayingInfo variations
          _WidgetSection(
            title: 'MtNowPlayingInfo',
            description: 'Displays current track title, artist, and album.',
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MtNowPlayingInfo(
                    player: player,
                    alignment: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MtNowPlayingInfo(
                    player: player,
                    showAlbum: true,
                    titleStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    artistStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // MtSpeedSelector variations
          _WidgetSection(
            title: 'MtSpeedSelector',
            description: 'Segmented button for selecting playback speed.',
            children: [
              const Text('Default speeds:'),
              const SizedBox(height: 8),
              MtSpeedSelector(player: player),
              const SizedBox(height: 24),
              const Text('Custom speeds:'),
              const SizedBox(height: 8),
              MtSpeedSelector(
                player: player,
                speeds: const [0.5, 1.0, 1.5, 2.0],
              ),
            ],
          ),
          const Divider(height: 32),

          // MtPlayerBuilder example
          _WidgetSection(
            title: 'MtPlayerBuilder',
            description: 'Builder widget for completely custom player UIs.',
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MtPlayerBuilder(
                    player: player,
                    builder: (context, state) {
                      return Column(
                        children: [
                          Text(
                            'Custom UI Example',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state.currentItem?.title ?? 'No track',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: state.progress,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                color: theme.colorScheme.onPrimaryContainer,
                                onPressed: player.skipToPrevious,
                              ),
                              FilledButton.tonal(
                                onPressed: state.isPlaying
                                    ? player.pause
                                    : player.play,
                                child: Icon(
                                  state.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next),
                                color: theme.colorScheme.onPrimaryContainer,
                                onPressed: player.skipToNext,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80), // Space for mini player
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _WidgetSection extends StatelessWidget {
  const _WidgetSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}
