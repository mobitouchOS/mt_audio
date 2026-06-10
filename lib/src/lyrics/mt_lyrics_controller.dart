import 'dart:async';

import 'package:mt_audio/src/lyrics/mt_lyrics_cursor.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';
import 'package:rxdart/rxdart.dart';

/// Tracks the current line and segment within an [MtLyrics] document as
/// playback advances.
///
/// Wire it up by passing an audio player's position stream:
/// ```dart
/// final controller = MtLyricsController(
///   lyrics: parsed,
///   position: player.positionStream,
/// );
/// ```
///
/// The controller applies [MtLyrics.offsetMs] internally: a positive offset
/// shifts the lookup position forward (lyrics appear earlier); a negative
/// offset shifts it backward (lyrics appear later).
///
/// ## Preconditions
/// * `lyrics.lines` must be sorted ascending by timestamp. Lines produced
///   by `MtLyricsParser` satisfy this; hand-built [MtLyrics] must too.
/// * Within each line, `line.segments` must be sorted ascending by
///   timestamp.
/// * `position` should be a broadcast stream if you intend to use it
///   elsewhere — the controller subscribes immediately on construction.
///
/// ## Behavior notes
/// * Errors arriving on `position` are silently dropped (rather than
///   forwarded to [cursorStream]) so a transient player error does not
///   permanently break the cursor.
/// * When multiple lines share the same timestamp (e.g. original + a
///   translation), the cursor lands on the last one in file order. Merge
///   such lines in your own data layer if you need to surface both.
class MtLyricsController {
  /// Creates a controller that tracks [lyrics] against `position` updates.
  MtLyricsController({
    required this.lyrics,
    required Stream<Duration> position,
  }) : assert(_isSortedByTimestamp(lyrics), _kSortError) {
    _subscription = position.map(_cursorAt).listen(
      _emit,
      onError: _swallowError,
    );
  }

  static const String _kSortError =
      'MtLyrics.lines and MtLyricsLine.segments must be sorted ascending by '
      'timestamp.';

  /// The lyrics being tracked.
  final MtLyrics lyrics;

  final _cursor = BehaviorSubject<MtLyricsCursor>.seeded(
    MtLyricsCursor.empty,
  );
  late final StreamSubscription<MtLyricsCursor> _subscription;

  /// Reactive cursor. Replays the latest value to new subscribers and emits
  /// only when the line or segment index changes.
  Stream<MtLyricsCursor> get cursorStream => _cursor.stream;

  /// Synchronous read of the latest cursor.
  MtLyricsCursor get cursor => _cursor.value;

  /// The current line, or `null` before the first line plays.
  MtLyricsLine? get currentLine =>
      cursor.hasLine ? lyrics.lines[cursor.lineIndex] : null;

  /// The current segment, or `null` when no segment is active. See
  /// [MtLyricsCursor.segmentIndex] for the cases that yield `null`.
  MtLyricsSegment? get currentSegment {
    if (!cursor.hasLine) return null;
    final segments = lyrics.lines[cursor.lineIndex].segments;
    if (cursor.segmentIndex < 0 || cursor.segmentIndex >= segments.length) {
      return null;
    }
    return segments[cursor.segmentIndex];
  }

  void _emit(MtLyricsCursor next) {
    if (_cursor.isClosed) return;
    if (next != _cursor.value) _cursor.add(next);
  }

  // Silently dropped: a transient error on the position stream should not
  // permanently break cursor consumers via BehaviorSubject's cached error.
  void _swallowError(Object _, StackTrace _) {}

  MtLyricsCursor _cursorAt(Duration position) {
    if (lyrics.lines.isEmpty) return MtLyricsCursor.empty;
    final lookup = position + Duration(milliseconds: lyrics.offsetMs);
    final lineIndex = _findLineIndex(lookup);
    if (lineIndex < 0) return MtLyricsCursor.empty;
    final segmentIndex = _findSegmentIndex(lineIndex, lookup);
    return MtLyricsCursor(
      lineIndex: lineIndex,
      segmentIndex: segmentIndex,
    );
  }

  /// Largest index `i` with `lines[i].timestamp <= position`, or `-1` when
  /// [position] precedes the first line.
  int _findLineIndex(Duration position) {
    final lines = lyrics.lines;
    if (position < lines.first.timestamp) return -1;
    var lo = 0;
    var hi = lines.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lines[mid].timestamp <= position) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Largest segment index `i` with `segments[i].timestamp <= position`, or
  /// `-1` when the line has no segments or [position] precedes the first
  /// segment.
  int _findSegmentIndex(int lineIndex, Duration position) {
    final segments = lyrics.lines[lineIndex].segments;
    if (segments.isEmpty) return -1;
    if (position < segments.first.timestamp) return -1;
    if (segments.length == 1) return 0;
    var lo = 0;
    var hi = segments.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (segments[mid].timestamp <= position) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Cancels the position subscription and closes [cursorStream]. Safe to
  /// call multiple times.
  Future<void> dispose() async {
    await _subscription.cancel();
    if (!_cursor.isClosed) await _cursor.close();
  }
}

bool _isSortedByTimestamp(MtLyrics lyrics) {
  for (var i = 1; i < lyrics.lines.length; i++) {
    if (lyrics.lines[i].timestamp < lyrics.lines[i - 1].timestamp) {
      return false;
    }
  }
  for (final line in lyrics.lines) {
    for (var i = 1; i < line.segments.length; i++) {
      if (line.segments[i].timestamp < line.segments[i - 1].timestamp) {
        return false;
      }
    }
  }
  return true;
}
