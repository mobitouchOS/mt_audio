import 'package:equatable/equatable.dart';

/// Represents parsed lyrics for a song, including timing and metadata.
/// Can be used to display synchronized lyrics in a music player.
class MtLyrics extends Equatable {
  /// Creates an [MtLyrics] instance.
  const MtLyrics({
    required this.lines,
    this.offsetMs = 0,
    this.title,
    this.artist,
    this.album,
    this.author,
    this.lyricist,
    this.length,
    this.lrcAuthor,
  });

  /// The list of lyric lines.
  final List<MtLyricsLine> lines;

  /// Offset in milliseconds to adjust the timing of the lyrics.
  /// Can be positive or negative.
  /// Parsed from LRC `offset` tag if present. Default is 0 (no offset).
  final int offsetMs;

  /// Optional title of the song, parsed from LRC `ti` tag.
  final String? title;

  /// Optional artist name, parsed from LRC `ar` tag.
  final String? artist;

  /// Optional album name, parsed from LRC `al` tag.
  final String? album;

  /// Optional author of the lyrics, parsed from LRC `au` tag.
  final String? author;

  /// Optional lyricist name, parsed from LRC `lr` tag.
  final String? lyricist;

  /// Optional length of the song, parsed from LRC `length` tag.
  final Duration? length;

  /// Optional author of the LRC file, parsed from LRC `by` tag.
  final String? lrcAuthor;

  @override
  List<Object?> get props => [
    lines,
    offsetMs,
    title,
    artist,
    album,
    author,
    lyricist,
    length,
    lrcAuthor,
  ];
}

/// Represents a single line of lyrics with timing information.
/// Each line can have multiple segments for karaoke-style highlighting.
class MtLyricsLine extends Equatable {
  /// Creates an [MtLyricsLine] with the given segments and timestamp.
  const MtLyricsLine({
    required this.segments,
    required this.timestamp,
  });

  /// The list of lyric segments in this line.
  /// For standard LRC, this will typically contain one segment with the full
  /// line of lyrics. For A2-style LRC, this can contain multiple segments with
  /// timing for each word or syllable.
  final List<MtLyricsSegment> segments;

  /// The timestamp for this line of lyrics.
  /// Can be offset by the [MtLyrics.offsetMs] value when displaying
  /// synchronized lyrics.
  final Duration timestamp;

  @override
  List<Object?> get props => [segments, timestamp];
}

/// Represents a single segment of lyrics with its own timestamp.
/// Used for A2-style LRC where each word or syllable can have its own timing
/// information for karaoke-style highlighting. For standard LRC, each line
/// will typically have one segment with the full line of lyrics and the same
/// timestamp as the line.
class MtLyricsSegment extends Equatable {
  /// Creates an [MtLyricsSegment] with the given text and timestamp.
  const MtLyricsSegment({
    required this.text,
    required this.timestamp,
  });

  /// The text of this lyric segment.
  final String text;

  /// The timestamp for this segment of lyrics.
  /// This is not relative to the line timestamp, but absolute.
  final Duration timestamp;

  @override
  List<Object?> get props => [text, timestamp];
}
