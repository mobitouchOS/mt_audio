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
[01:30.00]Tap a line to seek the player
[02:00.00]Lines stay sorted and snappy
[03:00.00]That's the demo — enjoy!
''';

const _rowHeight = 40.0;
const _visibleRows = 5;

/// Example widget that wires an [MtLyricsController] to the demo player and
/// renders the full lyrics as a scrolling list using [MtLyricsBuilder].
///
/// The active line is highlighted and kept centered; A2 lines highlight the
/// active word; tapping any line seeks the player to that line.
class LyricsDemoCard extends StatefulWidget {
  const LyricsDemoCard({required this.player, super.key});

  final MtAudioPlayer player;

  @override
  State<LyricsDemoCard> createState() => _LyricsDemoCardState();
}

class _LyricsDemoCardState extends State<LyricsDemoCard> {
  late final MtLyricsController _controller;
  final _scroll = ScrollController();
  int _scrolledTo = -1;

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
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls so the active line sits in the middle of the viewport. Runs
  /// after the frame so the list has laid out before we animate.
  void _keepActiveLineCentered(int lineIndex) {
    if (lineIndex == _scrolledTo) return;
    _scrolledTo = lineIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = lineIndex < 0
          ? 0.0
          : (lineIndex - (_visibleRows ~/ 2)) * _rowHeight;
      unawaited(
        _scroll.animateTo(
          target.clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    final inactiveStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lyrics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Lyrics (synthetic LRC)',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _rowHeight * _visibleRows,
              child: MtLyricsBuilder(
                controller: _controller,
                builder: (context, state) {
                  _keepActiveLineCentered(state.lineIndex);
                  return ListView.builder(
                    controller: _scroll,
                    itemExtent: _rowHeight,
                    itemCount: state.lines.length,
                    itemBuilder: (context, i) {
                      final line = state.lines[i];
                      final isActive = state.isActiveLine(i);
                      return InkWell(
                        onTap: () => widget.player.seekTo(line.timestamp),
                        child: Center(
                          child: _LyricsLineText(
                            line: line,
                            activeSegment: isActive ? state.segmentIndex : null,
                            style: isActive ? activeStyle : inactiveStyle,
                            highlightStyle: activeStyle,
                            dimStyle: inactiveStyle,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders one line. When [activeSegment] is non-null and the line has
/// multiple segments, the active word gets [highlightStyle] and the rest
/// [dimStyle] for a karaoke effect. Otherwise the whole line uses [style].
class _LyricsLineText extends StatelessWidget {
  const _LyricsLineText({
    required this.line,
    required this.activeSegment,
    required this.style,
    required this.highlightStyle,
    required this.dimStyle,
  });

  final MtLyricsLine line;
  final int? activeSegment;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final TextStyle? dimStyle;

  @override
  Widget build(BuildContext context) {
    if (activeSegment == null || line.segments.length <= 1) {
      return Text(line.text, style: style, textAlign: TextAlign.center);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < line.segments.length; i++)
            TextSpan(
              text: line.segments[i].text,
              style: i == activeSegment ? highlightStyle : dimStyle,
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
