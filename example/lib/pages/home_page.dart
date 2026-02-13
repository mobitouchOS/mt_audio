import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/providers/player_provider.dart';
import 'package:mt_audio_example/sample_data/sample_data.dart';

/// Source type for the player.
enum SourceType { single, playlist, live }

/// Main player demo page with full controls.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SourceType _sourceType = SourceType.single;
  int _selectedTrackIndex = 0;
  int _selectedLiveIndex = 0;
  double _volume = 1;

  @override
  Widget build(BuildContext context) {
    final player = PlayerProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('mt_audio Demo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Source type selector
            SegmentedButton<SourceType>(
              segments: const [
                ButtonSegment(
                  value: SourceType.single,
                  label: Text('Single'),
                ),
                ButtonSegment(
                  value: SourceType.playlist,
                  label: Text('Playlist'),
                ),
                ButtonSegment(
                  value: SourceType.live,
                  label: Text('Live'),
                ),
              ],
              selected: {_sourceType},
              onSelectionChanged: (selected) {
                setState(() => _sourceType = selected.first);
              },
            ),
            const SizedBox(height: 16),

            // Track/stream selector
            if (_sourceType == SourceType.live) ...[
              _buildDropdown(
                label: 'Live Stream',
                initialValue: _selectedLiveIndex,
                items: liveStreams.asMap().entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value.title),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLiveIndex = value ?? 0);
                },
              ),
            ] else ...[
              _buildDropdown(
                label: 'Track',
                initialValue: _selectedTrackIndex,
                items: sampleTracks.asMap().entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value.title),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedTrackIndex = value ?? 0);
                },
              ),
            ],
            const SizedBox(height: 8),

            // Load source button
            FilledButton.icon(
              onPressed: () => _loadSource(player),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                _sourceType == SourceType.playlist
                    ? 'Load Playlist'
                    : 'Load & Play',
              ),
            ),
            const SizedBox(height: 32),

            // Artwork
            Center(
              child: StreamBuilder(
                stream: player.currentItemStream,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  return MtArtwork(
                    artworkUri: item?.artworkUri,
                    borderRadius: 16,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Now playing info
            MtNowPlayingInfo(
              player: player,
              showAlbum: true,
            ),
            const SizedBox(height: 24),

            // Seek bar (hidden for live streams)
            StreamBuilder(
              stream: player.currentItemStream,
              builder: (context, snapshot) {
                final isLive = snapshot.data?.isLive ?? false;
                if (isLive) {
                  return Center(
                    child: Chip(
                      avatar: const Icon(Icons.sensors, size: 16),
                      label: const Text('LIVE'),
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                  );
                }
                return MtSeekBar(
                  player: player,
                );
              },
            ),
            const SizedBox(height: 16),

            // Main controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous track
                MtTrackSkipButton(
                  player: player,
                  direction: MtTrackSkipDirection.previous,
                  iconSize: 32,
                ),
                const SizedBox(width: 8),
                // Seek backward
                MtSkipButton(
                  player: player,
                  direction: MtSkipDirection.backward,
                  size: 48,
                ),
                const SizedBox(width: 8),
                // Play/Pause
                MtPlayPauseButton(
                  player: player,
                  size: 64,
                  iconSize: 40,
                ),
                const SizedBox(width: 8),
                // Seek forward
                MtSkipButton(
                  player: player,
                  direction: MtSkipDirection.forward,
                  size: 48,
                ),
                const SizedBox(width: 8),
                // Next track
                MtTrackSkipButton(
                  player: player,
                  direction: MtTrackSkipDirection.next,
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Repeat and shuffle controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playback Mode',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.maxFinite,
                      child: _RepeatModeSelector(player: player),
                    ),
                    const SizedBox(height: 12),
                    _ShuffleToggle(player: player),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Speed selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playback Speed',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    MtSpeedSelector(
                      player: player,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Volume slider
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.volume_down),
                        Expanded(
                          child: Slider(
                            value: _volume,
                            onChanged: (value) {
                              setState(() => _volume = value);
                              unawaited(player.setVolume(value));
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Space for mini player
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<void> _loadSource(MtAudioPlayer player) async {
    MtAudioSource source;

    switch (_sourceType) {
      case SourceType.single:
        source = MtSingleSource(item: sampleTracks[_selectedTrackIndex]);
      case SourceType.playlist:
        source = MtPlaylistSource(
          items: sampleTracks,
          initialIndex: _selectedTrackIndex,
        );
      case SourceType.live:
        source = MtLiveSource(item: liveStreams[_selectedLiveIndex]);
    }

    await player.setSource(source);
    await player.play();
  }
}

class _RepeatModeSelector extends StatelessWidget {
  const _RepeatModeSelector({required this.player});

  final MtAudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MtPlaybackState>(
      stream: player.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.currentPlaybackState;

        return SegmentedButton<MtRepeatMode>(
          segments: const [
            ButtonSegment(
              value: MtRepeatMode.off,
              icon: Icon(Icons.repeat),
              label: Text('Off'),
            ),
            ButtonSegment(
              value: MtRepeatMode.one,
              icon: Icon(Icons.repeat_one),
              label: Text('One'),
            ),
            ButtonSegment(
              value: MtRepeatMode.all,
              icon: Icon(Icons.repeat),
              label: Text('All'),
            ),
          ],
          selected: {state.repeatMode},
          onSelectionChanged: (selected) {
            unawaited(player.setRepeatMode(selected.first));
          },
        );
      },
    );
  }
}

class _ShuffleToggle extends StatelessWidget {
  const _ShuffleToggle({required this.player});

  final MtAudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MtPlaybackState>(
      stream: player.playbackStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? player.currentPlaybackState;

        return SwitchListTile(
          title: const Text('Shuffle'),
          secondary: Icon(
            Icons.shuffle,
            color: state.shuffleEnabled
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          value: state.shuffleEnabled,
          onChanged: (value) => unawaited(player.setShuffleMode(value)),
        );
      },
    );
  }
}
