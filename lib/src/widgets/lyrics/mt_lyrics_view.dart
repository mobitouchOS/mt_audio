import 'package:flutter/material.dart';

import 'package:mt_audio/src/lyrics/mt_lyrics_controller.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_cursor.dart';

/// Displays the currently active lyric line from an [MtLyricsController].
///
/// For standard LRC lines the line text is rendered with [activeStyle]. For
/// A2-enhanced lines (multiple segments), the active word/syllable uses
/// [activeStyle] while the rest use [inactiveStyle], giving a karaoke-style
/// highlight as playback advances.
///
/// Shows [placeholder] before the first line plays.
class MtLyricsView extends StatelessWidget {
  /// Creates an [MtLyricsView].
  const MtLyricsView({
    required this.controller,
    this.activeStyle,
    this.inactiveStyle,
    this.placeholder = '',
    this.textAlign = TextAlign.center,
    super.key,
  });

  /// The lyrics controller driving this view.
  final MtLyricsController controller;

  /// Style applied to the active line (and the active segment in A2 mode).
  final TextStyle? activeStyle;

  /// Style applied to non-active segments in A2 mode. Ignored for standard
  /// LRC lines, which render entirely in [activeStyle].
  final TextStyle? inactiveStyle;

  /// Text shown before any line is active.
  final String placeholder;

  /// Alignment of the rendered text.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackActive = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final fallbackInactive = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return StreamBuilder<MtLyricsCursor>(
      stream: controller.cursorStream,
      initialData: controller.cursor,
      builder: (context, snapshot) {
        final cursor = snapshot.data ?? MtLyricsCursor.empty;

        if (!cursor.hasLine) {
          return Text(
            placeholder,
            style: inactiveStyle ?? fallbackInactive,
            textAlign: textAlign,
          );
        }

        final line = controller.lyrics.lines[cursor.lineIndex];
        final segments = line.segments;

        // Standard LRC: one segment, render the whole line as active.
        if (segments.length <= 1) {
          return Text(
            segments.isEmpty ? '' : segments.first.text,
            style: activeStyle ?? fallbackActive,
            textAlign: textAlign,
          );
        }

        // A2: highlight the active segment, dim the rest.
        return Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < segments.length; i++)
                TextSpan(
                  text: segments[i].text,
                  style: i == cursor.segmentIndex
                      ? (activeStyle ?? fallbackActive)
                      : (inactiveStyle ?? fallbackInactive),
                ),
            ],
          ),
          textAlign: textAlign,
        );
      },
    );
  }
}
