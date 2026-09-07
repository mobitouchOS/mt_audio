import 'package:flutter/widgets.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_controller.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_cursor.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';

/// Builder widget that exposes the current lyrics position for custom UI.
///
/// Rebuilds whenever the [MtLyricsController] cursor moves to a new line or
/// segment. The [builder] receives an [MtLyricsState] with the full lyrics
/// document and the active indices, so it can render a single line, a
/// scrolling list, or karaoke-style word highlighting.
///
/// Example:
/// ```dart
/// MtLyricsBuilder(
///   controller: lyricsController,
///   builder: (context, state) {
///     return ListView.builder(
///       itemCount: state.lines.length,
///       itemBuilder: (context, i) => Text(
///         state.lines[i].text,
///         style: state.isActiveLine(i) ? activeStyle : inactiveStyle,
///       ),
///     );
///   },
/// )
/// ```
class MtLyricsBuilder extends StatelessWidget {
  /// Creates an [MtLyricsBuilder].
  const MtLyricsBuilder({
    required this.controller,
    required this.builder,
    super.key,
  });

  /// The lyrics controller driving this builder.
  final MtLyricsController controller;

  /// Builder function that receives the current lyrics state.
  final Widget Function(BuildContext context, MtLyricsState state) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MtLyricsCursor>(
      // Keyed on the controller so a new controller gets a fresh subscription
      // and its seeded cursor instead of the previous controller's snapshot.
      key: ObjectKey(controller),
      stream: controller.cursorStream,
      initialData: controller.cursor,
      builder: (context, snapshot) {
        final state = MtLyricsState(
          lyrics: controller.lyrics,
          cursor: snapshot.data ?? controller.cursor,
        );
        return builder(context, state);
      },
    );
  }
}

/// Lyrics state exposed to the [MtLyricsBuilder] builder function.
class MtLyricsState {
  /// Creates an [MtLyricsState].
  const MtLyricsState({
    required this.lyrics,
    required this.cursor,
  });

  /// The lyrics document being tracked.
  final MtLyrics lyrics;

  /// The current position within [lyrics].
  final MtLyricsCursor cursor;

  /// All lines of the lyrics document.
  List<MtLyricsLine> get lines => lyrics.lines;

  /// Index of the active line, or `-1` before the first line plays.
  int get lineIndex => cursor.lineIndex;

  /// Index of the active segment within the active line, or `-1` when no
  /// segment is active.
  int get segmentIndex => cursor.segmentIndex;

  /// Whether any line is currently active.
  bool get hasLine => cursor.hasLine;

  /// The active line, or `null` before the first line plays.
  MtLyricsLine? get currentLine => hasLine ? lines[lineIndex] : null;

  /// The active segment, or `null` when no segment is active.
  MtLyricsSegment? get currentSegment {
    final line = currentLine;
    if (line == null) return null;
    if (segmentIndex < 0 || segmentIndex >= line.segments.length) return null;
    return line.segments[segmentIndex];
  }

  /// Whether the line at [index] is the active line.
  bool isActiveLine(int index) => hasLine && index == lineIndex;

  /// Whether the segment at [index] of the active line is the active segment.
  bool isActiveSegment(int index) => hasLine && index == segmentIndex;
}
