import 'package:equatable/equatable.dart';

import 'package:mt_audio/src/models/mt_lyrics.dart';

/// Snapshot of the current playback position within an [MtLyrics] document.
class MtLyricsCursor extends Equatable {
  /// Creates an [MtLyricsCursor] at the given line and segment.
  const MtLyricsCursor({
    required this.lineIndex,
    required this.segmentIndex,
  });

  /// Cursor state before the first line plays, or when there are no lines.
  static const empty = MtLyricsCursor(lineIndex: -1, segmentIndex: -1);

  /// Index of the line currently being sung — the latest line whose effective
  /// timestamp is `<=` the current position — or `-1` before any line plays.
  final int lineIndex;

  /// Index of the active segment within the current line, or `-1` when no
  /// segment is active. A `-1` value can occur in three situations:
  /// * [lineIndex] is `-1` (no line is active),e
  /// * the current line's segments list is empty,
  /// * the current line is active but every segment timestamp is still in
  ///   the future (A2 lines whose first segment starts later than the line
  ///   itself).
  ///
  /// For standard (non-A2) LRC the value is `0` once the line is active.
  final int segmentIndex;

  /// `true` once [lineIndex] points to a real line. Does not imply
  /// [segmentIndex] is non-negative — see [segmentIndex].
  bool get hasLine => lineIndex >= 0;

  @override
  List<Object?> get props => [lineIndex, segmentIndex];
}
