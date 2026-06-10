@Tags(['network'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_parser.dart';

const _samples = [
  ('Coldplay', 'Yellow'),
  ('Queen', 'Bohemian Rhapsody'),
  ('Adele', 'Hello'),
  ('The Beatles', 'Hey Jude'),
  ('Imagine Dragons', 'Believer'),
  ('Ed Sheeran', 'Shape of You'),
];

Future<String?> _fetchSyncedLyrics(String artist, String track) async {
  final uri = Uri.parse(
    'https://lrclib.net/api/get'
    '?artist_name=${Uri.encodeQueryComponent(artist)}'
    '&track_name=${Uri.encodeQueryComponent(track)}',
  );
  final client = HttpClient();
  try {
    final req = await client.getUrl(uri);
    req.headers.set(
      'User-Agent',
      'mt_audio LRC parser test (https://github.com/mobitouchOS/mt_audio)',
    );
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final synced = json['syncedLyrics'];
    return synced is String && synced.isNotEmpty ? synced : null;
  } on SocketException {
    return null;
  } finally {
    client.close();
  }
}

/// Independent scan for the last non-empty value of metadata tag [key].
/// Mirrors the parser's "skip-empty, last-one-wins" policy.
String? _scanLastTagValue(String lrc, String key) {
  final pattern = RegExp(
    '\\[\\s*$key\\s*:([^\\[\\]]*)\\]',
    caseSensitive: false,
  );
  String? last;
  for (final match in pattern.allMatches(lrc)) {
    final value = match.group(1)!.trim();
    if (value.isNotEmpty) last = value;
  }
  return last;
}

typedef _LinePair = ({Duration ts, String text});

/// Independent scan that extracts every (timestamp, text) pair from raw LRC,
/// expanding repeated timestamp prefixes and stripping A2 inline markers from
/// text so it can be compared to the parser's segment-joined text.
Set<_LinePair> _scanRawLines(String lrc) {
  final result = <_LinePair>{};
  final prefixPattern = RegExp(
    r'^((?:\[\d+:[0-5]\d(?:\.\d+)?\]\s*)+)(.*)$',
  );
  final tsPattern = RegExp(r'\[(\d+):([0-5]\d)(?:\.(\d+))?\]');
  final a2Pattern = RegExp(r'<\d+:[0-5]\d(?:\.\d+)?>');

  for (final raw in LineSplitter.split(lrc)) {
    final line = raw.trim();
    final prefixMatch = prefixPattern.firstMatch(line);
    if (prefixMatch == null) continue;
    final prefix = prefixMatch.group(1)!;
    final body = prefixMatch.group(2)!.trim().replaceAll(a2Pattern, '');

    for (final ts in tsPattern.allMatches(prefix)) {
      final mins = int.parse(ts.group(1)!);
      final secs = int.parse(ts.group(2)!);
      final fracStr = ts.group(3);
      var ms = 0;
      if (fracStr != null && fracStr.isNotEmpty) {
        ms = int.parse(fracStr.padRight(3, '0').substring(0, 3));
      }
      result.add((
        ts: Duration(minutes: mins, seconds: secs, milliseconds: ms),
        text: body,
      ));
    }
  }
  return result;
}

void main() {
  for (final (artist, track) in _samples) {
    test('parses LRCLIB lyrics correctly: $artist - $track', () async {
      final synced = await _fetchSyncedLyrics(artist, track);
      if (synced == null) {
        markTestSkipped('No synced lyrics available for $artist - $track');
        return;
      }

      final lyrics = MtLyricsParser.parse(synced);

      final preview = synced.substring(0, synced.length.clamp(0, 400));
      printOnFailure('Raw LRC (first 400 chars):\n$preview');
      printOnFailure(
        'Parsed: ${lyrics.lines.length} lines, '
        'title="${lyrics.title}", artist="${lyrics.artist}", '
        'album="${lyrics.album}", length=${lyrics.length}, '
        'offsetMs=${lyrics.offsetMs}',
      );

      // Every metadata tag the file contains must match the parsed field.
      expect(
        lyrics.title,
        equals(_scanLastTagValue(synced, 'ti')),
        reason: 'ti mismatch',
      );
      expect(
        lyrics.artist,
        equals(_scanLastTagValue(synced, 'ar')),
        reason: 'ar mismatch',
      );
      expect(
        lyrics.album,
        equals(_scanLastTagValue(synced, 'al')),
        reason: 'al mismatch',
      );
      expect(
        lyrics.author,
        equals(_scanLastTagValue(synced, 'au')),
        reason: 'au mismatch',
      );
      expect(
        lyrics.lyricist,
        equals(_scanLastTagValue(synced, 'lr')),
        reason: 'lr mismatch',
      );
      expect(
        lyrics.lrcAuthor,
        equals(_scanLastTagValue(synced, 'by')),
        reason: 'by mismatch',
      );

      final offsetRaw = _scanLastTagValue(synced, 'offset');
      if (offsetRaw == null) {
        expect(lyrics.offsetMs, equals(0), reason: 'offset should default 0');
      } else {
        final leading = RegExp(r'^[+-]?\d+').firstMatch(offsetRaw);
        if (leading != null) {
          expect(
            lyrics.offsetMs,
            equals(int.parse(leading.group(0)!)),
            reason: 'offset mismatch',
          );
        }
      }

      // Length: just assert presence parity (exact value depends on form,
      // and the parser's own _parseLength is what we are testing).
      final lengthRaw = _scanLastTagValue(synced, 'length');
      expect(
        lyrics.length != null,
        equals(lengthRaw != null),
        reason: 'length presence mismatch',
      );

      // Every (timestamp, text) pair in the raw file must appear in the parsed
      // lines (and vice versa). This catches dropped lines, ghost segments,
      // and timestamp drift in one check.
      final expected = _scanRawLines(synced);
      final actual = {
        for (final line in lyrics.lines)
          (
            ts: line.timestamp,
            text: line.segments.map((s) => s.text).join(),
          ),
      };
      expect(
        actual,
        equals(expected),
        reason: 'parsed (timestamp, text) pairs do not match raw scan',
      );

      // Lines come out sorted ascending.
      for (var i = 1; i < lyrics.lines.length; i++) {
        expect(
          lyrics.lines[i].timestamp,
          greaterThanOrEqualTo(lyrics.lines[i - 1].timestamp),
        );
      }
    });
  }
}
