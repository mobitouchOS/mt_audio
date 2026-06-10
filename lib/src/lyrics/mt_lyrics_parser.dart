import 'dart:convert';

import 'package:mt_audio/src/models/mt_lyrics.dart';

/// Parses lyrics in LRC format (including the A2 enhanced extension) into an
/// [MtLyrics] document.
///
/// Recognized metadata tags: `ti`, `ar`, `al`, `au`, `lr`, `by`, `length`,
/// `offset`. Unknown tags and malformed lines are silently skipped. Duplicate
/// metadata tags follow a last-one-wins policy. The returned [MtLyrics.lines]
/// are sorted by [MtLyricsLine.timestamp] with file order preserved on ties.
///
/// `offset` is stored on the returned [MtLyrics] as-is and is not folded into
/// individual line/segment timestamps — consumers apply it at display time.
abstract class MtLyricsParser {
  /// Matches a single metadata tag like `[ti:Title]`. Non-anchored so multiple
  /// inline tags on one line (e.g. `[al:Album][ar:Artist]`) are all captured
  /// by [RegExp.allMatches]. Values may not contain `[` or `]`.
  static final RegExp _metadata = RegExp(
    r'\[\s*([a-zA-Z]+)\s*:([^\[\]]*)\]',
  );

  /// Matches one or more leading `[mm:ss(.xx)?]` timestamps followed by the
  /// body. Seconds are constrained to 00-59 so a typo like `[00:60.00]` is
  /// skipped rather than silently rolled over by [Duration] normalization.
  static final RegExp _timestampPrefix = RegExp(
    r'^((?:\[\d+:[0-5]\d(?:\.\d+)?\]\s*)+)(.*)$',
  );

  /// Matches a single `[mm:ss(.xx)?]` or `<mm:ss(.xx)?>` timestamp.
  static final RegExp _timestamp = RegExp(
    r'[\[<](\d+):([0-5]\d)(?:\.(\d+))?[\]>]',
  );

  /// Captures a leading signed integer, tolerating trailing `ms`/`s` units or
  /// stray whitespace some tools emit on `[offset:...]` values.
  static final RegExp _leadingSignedInt = RegExp(r'^[+-]?\d+');

  /// Parses LRC formatted [content] into an [MtLyrics] document.
  static MtLyrics parse(String content) {
    final cleaned = content.startsWith('\uFEFF')
        ? content.substring(1)
        : content;

    final lines = <MtLyricsLine>[];
    String? title;
    String? artist;
    String? album;
    String? author;
    String? lyricist;
    String? lrcAuthor;
    Duration? length;
    var offsetMs = 0;

    for (final raw in LineSplitter.split(cleaned)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final timed = _timestampPrefix.firstMatch(line);
      if (timed != null) {
        lines.addAll(_parseTimedLine(timed.group(1)!, timed.group(2)!));
        continue;
      }

      for (final tag in _metadata.allMatches(line)) {
        final key = tag.group(1)!.toLowerCase();
        final value = tag.group(2)!.trim();
        if (value.isEmpty) continue;
        switch (key) {
          case 'ti':
            title = value;
          case 'ar':
            artist = value;
          case 'al':
            album = value;
          case 'au':
            author = value;
          case 'lr':
            lyricist = value;
          case 'by':
            lrcAuthor = value;
          case 'length':
            length = _parseLength(value) ?? length;
          case 'offset':
            final match = _leadingSignedInt.firstMatch(value);
            if (match != null) offsetMs = int.parse(match.group(0)!);
        }
      }
    }

    _stableSortByTimestamp(lines);

    return MtLyrics(
      lines: lines,
      offsetMs: offsetMs,
      title: title,
      artist: artist,
      album: album,
      author: author,
      lyricist: lyricist,
      length: length,
      lrcAuthor: lrcAuthor,
    );
  }

  static List<MtLyricsLine> _parseTimedLine(String prefix, String body) {
    final starts = _timestamp
        .allMatches(prefix)
        .map(_durationFromMatch)
        .toList();
    if (starts.isEmpty) return const [];

    final trimmedBody = body.trim();
    final firstStart = starts.first;
    final baseSegments = _parseSegments(trimmedBody, firstStart);

    final result = <MtLyricsLine>[];
    for (final start in starts) {
      final delta = start - firstStart;
      final segments = delta == Duration.zero
          ? baseSegments
          : [
              for (final s in baseSegments)
                MtLyricsSegment(text: s.text, timestamp: s.timestamp + delta),
            ];
      result.add(MtLyricsLine(segments: segments, timestamp: start));
    }
    return result;
  }

  /// Splits an A2-style [body] into timed segments anchored to [lineStart].
  /// Falls back to a single segment at [lineStart] when no inline `<...>`
  /// markers are present. Empty-text segments (from adjacent markers or a
  /// trailing end-time marker) are dropped.
  static List<MtLyricsSegment> _parseSegments(
    String body,
    Duration lineStart,
  ) {
    if (body.isEmpty) {
      return [MtLyricsSegment(text: '', timestamp: lineStart)];
    }

    final markers = _timestamp.allMatches(body).toList();
    if (markers.isEmpty) {
      return [MtLyricsSegment(text: body, timestamp: lineStart)];
    }

    final segments = <MtLyricsSegment>[];

    final firstMarkerStart = markers.first.start;
    if (firstMarkerStart > 0) {
      final leading = body.substring(0, firstMarkerStart);
      if (leading.isNotEmpty) {
        segments.add(MtLyricsSegment(text: leading, timestamp: lineStart));
      }
    }

    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      final textEnd = i + 1 < markers.length
          ? markers[i + 1].start
          : body.length;
      final text = body.substring(marker.end, textEnd);
      if (text.isEmpty) continue;
      segments.add(
        MtLyricsSegment(text: text, timestamp: _durationFromMatch(marker)),
      );
    }

    if (segments.isEmpty) {
      return [MtLyricsSegment(text: '', timestamp: lineStart)];
    }
    return segments;
  }

  static Duration _durationFromMatch(RegExpMatch m) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: _parseFraction(m.group(3)),
    );
  }

  /// Parses an LRC `length` tag value such as `3:45`, `3:45.50`, `1:02:03`,
  /// or `225` (seconds-only).
  static Duration? _parseLength(String value) {
    final dotIndex = value.indexOf('.');
    final integerPart = dotIndex < 0 ? value : value.substring(0, dotIndex);
    final fraction = dotIndex < 0 ? null : value.substring(dotIndex + 1);
    final segments = integerPart.split(':');
    if (segments.isEmpty || segments.length > 3) return null;

    final parsed = <int>[];
    for (final s in segments) {
      final i = int.tryParse(s);
      if (i == null) return null;
      parsed.add(i);
    }

    var hours = 0;
    var minutes = 0;
    var seconds = 0;
    switch (parsed.length) {
      case 1:
        seconds = parsed[0];
      case 2:
        minutes = parsed[0];
        seconds = parsed[1];
      case 3:
        hours = parsed[0];
        minutes = parsed[1];
        seconds = parsed[2];
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: _parseFraction(fraction),
    );
  }

  /// Converts a captured fractional-second group into milliseconds. A missing
  /// or empty group becomes 0; shorter groups are right-padded with zeros and
  /// longer groups are truncated.
  static int _parseFraction(String? fraction) {
    if (fraction == null || fraction.isEmpty) return 0;
    final padded = fraction.padRight(3, '0').substring(0, 3);
    return int.parse(padded);
  }

  /// Sorts [lines] by timestamp, preserving original file order on ties.
  /// [List.sort] is not contractually stable, so we decorate with the original
  /// index and sort on the (timestamp, index) tuple.
  static void _stableSortByTimestamp(List<MtLyricsLine> lines) {
    final indexed =
        [
          for (var i = 0; i < lines.length; i++) (i, lines[i]),
        ]..sort((a, b) {
          final c = a.$2.timestamp.compareTo(b.$2.timestamp);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
    for (var i = 0; i < indexed.length; i++) {
      lines[i] = indexed[i].$2;
    }
  }
}
