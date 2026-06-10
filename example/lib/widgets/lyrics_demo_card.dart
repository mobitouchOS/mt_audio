import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';

const _sampleLrc = '''
[ti:mt_audio Lyrics Demo]
[ar:mt_audio]
[00:00.00]Press play to follow the lyrics
[00:15.00]Each line lights up at its timestamp
[00:30.00]Standard LRC files just work
[00:45.00]A2 enhanced karaoke is supported too
[01:00.00]<01:00.00>Try <01:00.40>highlighting <01:01.00>each <01:01.50>word
[01:15.00]Pretty neat for a Saturday hack
[01:30.00]Seek the player to test
[02:00.00]Lines stay sorted and snappy
[03:00.00]That's the demo — enjoy!
''';

/// Example widget that wires up an [MtLyricsController] to the demo player
/// and renders the active line using [MtLyricsView].
class LyricsDemoCard extends StatefulWidget {
  const LyricsDemoCard({required this.player, super.key});

  final MtAudioPlayer player;

  @override
  State<LyricsDemoCard> createState() => _LyricsDemoCardState();
}

class _LyricsDemoCardState extends State<LyricsDemoCard> {
  late final MtLyricsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MtLyricsController(
      lyrics: MtLyricsParser.parse(_sampleLrc),
      position: widget.player.positionStateStream.map((s) => s.position),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.music_note, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Lyrics (synthetic LRC)',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: Center(
                child: MtLyricsView(
                  controller: _controller,
                  placeholder: 'Press play to follow along…',
                  activeStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  inactiveStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
