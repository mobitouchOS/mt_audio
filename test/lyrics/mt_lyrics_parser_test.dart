import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_parser.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';

Duration _t(int minutes, int seconds, [int ms = 0]) =>
    Duration(minutes: minutes, seconds: seconds, milliseconds: ms);

/// Convenience view of a parsed document as (timestamp, text) pairs.
List<(Duration, String)> _pairs(MtLyrics lyrics) => [
  for (final l in lyrics.lines) (l.timestamp, l.text),
];

void main() {
  group('metadata tags', () {
    test('parses all recognized tags', () {
      final lyrics = MtLyricsParser.parse('''
[ti:Song Title]
[ar:The Artist]
[al:The Album]
[au:Composer]
[lr:Lyricist]
[by:LRC Maker]
[length:03:45.50]
[offset:+250]
[00:01.00]hello
''');
      expect(lyrics.title, 'Song Title');
      expect(lyrics.artist, 'The Artist');
      expect(lyrics.album, 'The Album');
      expect(lyrics.author, 'Composer');
      expect(lyrics.lyricist, 'Lyricist');
      expect(lyrics.lrcAuthor, 'LRC Maker');
      expect(lyrics.length, _t(3, 45, 500));
      expect(lyrics.offsetMs, 250);
    });

    test('tag keys are case-insensitive and values are trimmed', () {
      final lyrics = MtLyricsParser.parse('[TI:  Spaced  ]\n[Ar: Artist ]');
      expect(lyrics.title, 'Spaced');
      expect(lyrics.artist, 'Artist');
    });

    test('duplicate tags: last one wins', () {
      final lyrics = MtLyricsParser.parse('[ti:First]\n[ti:Second]');
      expect(lyrics.title, 'Second');
    });

    test('multiple inline tags on one line are all captured', () {
      final lyrics = MtLyricsParser.parse('[al:Album][ar:Artist]');
      expect(lyrics.album, 'Album');
      expect(lyrics.artist, 'Artist');
    });

    test('empty tag values are ignored', () {
      final lyrics = MtLyricsParser.parse('[ti:Real]\n[ti:]\n[ti:   ]');
      expect(lyrics.title, 'Real');
    });

    test('unknown tags are skipped', () {
      final lyrics = MtLyricsParser.parse('[re:some editor]\n[ve:1.0]');
      expect(lyrics.title, isNull);
      expect(lyrics.lines, isEmpty);
    });

    test(
      'offset defaults to 0 and accepts negative and unit-suffixed values',
      () {
        expect(MtLyricsParser.parse('').offsetMs, 0);
        expect(MtLyricsParser.parse('[offset:-300]').offsetMs, -300);
        expect(MtLyricsParser.parse('[offset:500ms]').offsetMs, 500);
        expect(MtLyricsParser.parse('[offset: 120 ]').offsetMs, 120);
      },
    );

    test('non-numeric offset leaves the default', () {
      expect(MtLyricsParser.parse('[offset:abc]').offsetMs, 0);
    });

    test('length accepts mm:ss, mm:ss.xx, hh:mm:ss and bare seconds', () {
      expect(MtLyricsParser.parse('[length:3:45]').length, _t(3, 45));
      expect(MtLyricsParser.parse('[length:3:45.5]').length, _t(3, 45, 500));
      expect(
        MtLyricsParser.parse('[length:1:02:03]').length,
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(MtLyricsParser.parse('[length:225]').length, _t(3, 45));
    });

    test('malformed length is ignored', () {
      expect(MtLyricsParser.parse('[length:abc]').length, isNull);
      expect(MtLyricsParser.parse('[length:1:2:3:4]').length, isNull);
    });
  });

  group('timed lines', () {
    test('parses a standard line into one segment', () {
      final lyrics = MtLyricsParser.parse('[00:12.34]Hello world');
      expect(lyrics.lines, hasLength(1));
      final line = lyrics.lines.single;
      expect(line.timestamp, _t(0, 12, 340));
      expect(line.segments, [
        MtLyricsSegment(text: 'Hello world', timestamp: _t(0, 12, 340)),
      ]);
    });

    test('fractional seconds: 1, 2 and 3+ digits', () {
      expect(
        _pairs(MtLyricsParser.parse('[00:01.5]a')).single.$1,
        _t(0, 1, 500),
      );
      expect(
        _pairs(MtLyricsParser.parse('[00:01.50]a')).single.$1,
        _t(0, 1, 500),
      );
      expect(
        _pairs(MtLyricsParser.parse('[00:01.500]a')).single.$1,
        _t(0, 1, 500),
      );
      expect(
        _pairs(MtLyricsParser.parse('[00:01.5009]a')).single.$1,
        _t(0, 1, 500),
      );
      expect(_pairs(MtLyricsParser.parse('[00:01]a')).single.$1, _t(0, 1));
    });

    test('minutes beyond 59 are allowed (LRC has no hours field)', () {
      final lyrics = MtLyricsParser.parse('[90:00.00]late');
      expect(lyrics.lines.single.timestamp, const Duration(minutes: 90));
    });

    test('seconds >= 60 are rejected rather than rolled over', () {
      final lyrics = MtLyricsParser.parse('[00:60.00]bad\n[00:01.00]good');
      expect(_pairs(lyrics), [(_t(0, 1), 'good')]);
    });

    test('repeated timestamps expand into one line per timestamp', () {
      final lyrics = MtLyricsParser.parse('[00:10.00][00:30.00]chorus');
      expect(_pairs(lyrics), [
        (_t(0, 10), 'chorus'),
        (_t(0, 30), 'chorus'),
      ]);
    });

    test('lines are sorted by timestamp regardless of file order', () {
      final lyrics = MtLyricsParser.parse('''
[00:30.00]third
[00:10.00]first
[00:20.00]second
''');
      expect(_pairs(lyrics).map((p) => p.$2), ['first', 'second', 'third']);
    });

    test('ties preserve file order (stable sort)', () {
      final lyrics = MtLyricsParser.parse('''
[00:10.00]original
[00:10.00]translation
''');
      expect(_pairs(lyrics).map((p) => p.$2), ['original', 'translation']);
    });

    test('empty body yields a single empty segment', () {
      final lyrics = MtLyricsParser.parse('[00:05.00]');
      expect(lyrics.lines.single.segments, [
        MtLyricsSegment(text: '', timestamp: _t(0, 5)),
      ]);
    });

    test('body whitespace is trimmed', () {
      final lyrics = MtLyricsParser.parse('[00:05.00]   padded   ');
      expect(lyrics.lines.single.text, 'padded');
    });

    test('blank lines and BOM are ignored', () {
      final lyrics = MtLyricsParser.parse('﻿[ti:T]\n\n\n[00:01.00]a\n\n');
      expect(lyrics.title, 'T');
      expect(_pairs(lyrics), [(_t(0, 1), 'a')]);
    });

    test('CRLF line endings are handled', () {
      final lyrics = MtLyricsParser.parse('[00:01.00]a\r\n[00:02.00]b\r\n');
      expect(_pairs(lyrics).map((p) => p.$2), ['a', 'b']);
    });

    test('non-standard hh:mm:ss timestamps are skipped', () {
      final lyrics = MtLyricsParser.parse(
        '[01:02:03.00]skipped\n[00:01.00]kept',
      );
      expect(_pairs(lyrics), [(_t(0, 1), 'kept')]);
    });
  });

  group('A2 enhanced segments', () {
    test('splits inline <mm:ss.xx> markers into timed segments', () {
      final lyrics = MtLyricsParser.parse(
        '[00:10.00]<00:10.00>one <00:10.50>two <00:11.00>three',
      );
      final line = lyrics.lines.single;
      expect(line.timestamp, _t(0, 10));
      expect(line.segments, [
        MtLyricsSegment(text: 'one ', timestamp: _t(0, 10)),
        MtLyricsSegment(text: 'two ', timestamp: _t(0, 10, 500)),
        MtLyricsSegment(text: 'three', timestamp: _t(0, 11)),
      ]);
      expect(line.text, 'one two three');
    });

    test('text before the first marker is anchored to the line start', () {
      final lyrics = MtLyricsParser.parse('[00:10.00]lead <00:10.50>in');
      expect(lyrics.lines.single.segments, [
        MtLyricsSegment(text: 'lead ', timestamp: _t(0, 10)),
        MtLyricsSegment(text: 'in', timestamp: _t(0, 10, 500)),
      ]);
    });

    test(
      'trailing end-time marker and adjacent markers produce no empty segments',
      () {
        final lyrics = MtLyricsParser.parse(
          '[00:10.00]<00:10.00><00:10.20>word<00:11.00>',
        );
        expect(lyrics.lines.single.segments, [
          MtLyricsSegment(text: 'word', timestamp: _t(0, 10, 200)),
        ]);
      },
    );

    test('only markers with no text yields a single empty segment', () {
      final lyrics = MtLyricsParser.parse('[00:10.00]<00:10.00><00:11.00>');
      expect(lyrics.lines.single.segments, [
        MtLyricsSegment(text: '', timestamp: _t(0, 10)),
      ]);
    });

    test('repeated timestamps shift A2 segments by the line delta', () {
      final lyrics = MtLyricsParser.parse(
        '[00:10.00][01:10.00]<00:10.00>a <00:10.50>b',
      );
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].segments.map((s) => s.timestamp), [
        _t(0, 10),
        _t(0, 10, 500),
      ]);
      expect(lyrics.lines[1].segments.map((s) => s.timestamp), [
        _t(1, 10),
        _t(1, 10, 500),
      ]);
      expect(lyrics.lines[1].text, 'a b');
    });
  });
}
