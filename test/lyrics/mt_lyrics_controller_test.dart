import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_controller.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_cursor.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';

MtLyricsSegment _seg(int seconds, String text) => MtLyricsSegment(
  text: text,
  timestamp: Duration(seconds: seconds),
);

MtLyricsLine _line(int seconds, String text) => MtLyricsLine(
  segments: [_seg(seconds, text)],
  timestamp: Duration(seconds: seconds),
);

MtLyrics _lyrics(List<MtLyricsLine> lines, {int offsetMs = 0}) => MtLyrics(
  lines: lines,
  offsetMs: offsetMs,
);

/// Drives a controller by pushing positions through a [StreamController].
class _Driver {
  _Driver(MtLyrics lyrics, {int offsetMs = 0})
    : _position = StreamController<Duration>.broadcast() {
    controller = MtLyricsController(
      lyrics: offsetMs == 0
          ? lyrics
          : MtLyrics(lines: lyrics.lines, offsetMs: offsetMs),
      position: _position.stream,
    );
  }

  final StreamController<Duration> _position;
  late final MtLyricsController controller;

  Future<MtLyricsCursor> push(Duration position) async {
    _position.add(position);
    // Let the microtask queue flush so the controller processes the event.
    await Future<void>.delayed(Duration.zero);
    return controller.cursor;
  }

  Future<void> dispose() async {
    await controller.dispose();
    await _position.close();
  }
}

void main() {
  group('MtLyricsCursor', () {
    test('empty is sentinel with -1, -1', () {
      expect(MtLyricsCursor.empty.lineIndex, -1);
      expect(MtLyricsCursor.empty.segmentIndex, -1);
      expect(MtLyricsCursor.empty.hasLine, isFalse);
    });

    test('equality via Equatable', () {
      const a = MtLyricsCursor(lineIndex: 2, segmentIndex: 1);
      const b = MtLyricsCursor(lineIndex: 2, segmentIndex: 1);
      const c = MtLyricsCursor(lineIndex: 2, segmentIndex: 0);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hasLine reflects lineIndex >= 0', () {
      expect(const MtLyricsCursor(lineIndex: 0, segmentIndex: 0).hasLine, isTrue);
      expect(MtLyricsCursor.empty.hasLine, isFalse);
    });
  });

  group('MtLyricsController basics', () {
    test('emits seeded empty before any position', () async {
      final driver = _Driver(_lyrics([_line(1, 'a')]));
      expect(driver.controller.cursor, equals(MtLyricsCursor.empty));
      await driver.dispose();
    });

    test('stays empty when position precedes first line', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b')]));
      final c = await driver.push(const Duration(seconds: 5));
      expect(c, equals(MtLyricsCursor.empty));
      await driver.dispose();
    });

    test('lands on first line at its exact timestamp', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b')]));
      final c = await driver.push(const Duration(seconds: 10));
      expect(c.lineIndex, 0);
      expect(c.segmentIndex, 0);
      await driver.dispose();
    });

    test('advances to next line as position crosses boundary', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b'), _line(30, 'c')]));
      expect((await driver.push(const Duration(seconds: 15))).lineIndex, 0);
      expect((await driver.push(const Duration(seconds: 20))).lineIndex, 1);
      expect((await driver.push(const Duration(seconds: 25))).lineIndex, 1);
      expect((await driver.push(const Duration(seconds: 35))).lineIndex, 2);
      await driver.dispose();
    });

    test('handles seek backwards', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b'), _line(30, 'c')]));
      await driver.push(const Duration(seconds: 30));
      expect(driver.controller.cursor.lineIndex, 2);
      final back = await driver.push(const Duration(seconds: 5));
      expect(back, equals(MtLyricsCursor.empty));
      await driver.dispose();
    });

    test('stays on last line indefinitely', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b')]));
      final c = await driver.push(const Duration(minutes: 99));
      expect(c.lineIndex, 1);
      await driver.dispose();
    });

    test('empty lines list always returns empty cursor', () async {
      final driver = _Driver(_lyrics(const []));
      final c = await driver.push(const Duration(seconds: 10));
      expect(c, equals(MtLyricsCursor.empty));
      await driver.dispose();
    });

    test('single line is always selected once we cross it', () async {
      final driver = _Driver(_lyrics([_line(5, 'only')]));
      expect(await driver.push(const Duration(seconds: 4)), equals(MtLyricsCursor.empty));
      expect((await driver.push(const Duration(seconds: 5))).lineIndex, 0);
      expect((await driver.push(const Duration(seconds: 500))).lineIndex, 0);
      await driver.dispose();
    });

    test('currentLine and currentSegment helpers track cursor', () async {
      final driver = _Driver(_lyrics([_line(10, 'hello'), _line(20, 'world')]));
      await driver.push(const Duration(seconds: 25));
      expect(driver.controller.currentLine?.segments.first.text, 'world');
      expect(driver.controller.currentSegment?.text, 'world');
      await driver.dispose();
    });
  });

  group('A2 segment tracking', () {
    test('walks segments inside a single line', () async {
      final line = MtLyricsLine(
        timestamp: const Duration(seconds: 10),
        segments: [
          _seg(10, 'hello '),
          _seg(11, 'beautiful '),
          _seg(12, 'world'),
        ],
      );
      final driver = _Driver(_lyrics([line]));
      expect((await driver.push(const Duration(seconds: 10))).segmentIndex, 0);
      expect(
        (await driver.push(const Duration(seconds: 11))).segmentIndex,
        1,
      );
      expect(
        (await driver.push(const Duration(seconds: 12))).segmentIndex,
        2,
      );
      expect(
        (await driver.push(const Duration(seconds: 13))).segmentIndex,
        2,
      );
      await driver.dispose();
    });

    test('A2 line with later first segment: segmentIndex is -1 until segment starts', () async {
      final line = MtLyricsLine(
        timestamp: const Duration(seconds: 10),
        segments: [_seg(12, 'a'), _seg(15, 'b')],
      );
      final driver = _Driver(_lyrics([line]));

      var c = await driver.push(const Duration(seconds: 11));
      expect(c.lineIndex, 0);
      expect(c.segmentIndex, -1);
      expect(driver.controller.currentSegment, isNull);

      c = await driver.push(const Duration(seconds: 12));
      expect(c.segmentIndex, 0);

      c = await driver.push(const Duration(seconds: 15));
      expect(c.segmentIndex, 1);

      await driver.dispose();
    });

    test('single-segment A2 line respects the precondition guard', () async {
      final line = MtLyricsLine(
        timestamp: const Duration(seconds: 10),
        segments: [_seg(15, 'late')],
      );
      final driver = _Driver(_lyrics([line]));

      var c = await driver.push(const Duration(seconds: 12));
      expect(c.lineIndex, 0);
      expect(c.segmentIndex, -1);

      c = await driver.push(const Duration(seconds: 15));
      expect(c.segmentIndex, 0);

      await driver.dispose();
    });

    test('segmentIndex resets across line boundary', () async {
      final l1 = MtLyricsLine(
        timestamp: const Duration(seconds: 10),
        segments: [_seg(10, 'a '), _seg(11, 'b')],
      );
      final l2 = MtLyricsLine(
        timestamp: const Duration(seconds: 20),
        segments: [_seg(20, 'c '), _seg(21, 'd')],
      );
      final driver = _Driver(_lyrics([l1, l2]));
      var c = await driver.push(const Duration(seconds: 11));
      expect(c.lineIndex, 0);
      expect(c.segmentIndex, 1);

      c = await driver.push(const Duration(seconds: 20));
      expect(c.lineIndex, 1);
      expect(c.segmentIndex, 0);
      await driver.dispose();
    });
  });

  group('offset', () {
    test('positive offset shifts lookup forward (lyrics appear earlier)', () async {
      // Lines at 10s, 20s. With offsetMs=+2000, lookup at position 8s should
      // resolve to line 0 because 8s + 2s = 10s.
      final driver = _Driver(
        _lyrics([_line(10, 'a'), _line(20, 'b')]),
        offsetMs: 2000,
      );
      expect((await driver.push(const Duration(seconds: 8))).lineIndex, 0);
      expect(
        (await driver.push(const Duration(seconds: 17))).lineIndex,
        0,
      );
      expect(
        (await driver.push(const Duration(seconds: 18))).lineIndex,
        1,
      );
      await driver.dispose();
    });

    test('negative offset shifts lookup backward (lyrics appear later)', () async {
      final driver = _Driver(
        _lyrics([_line(10, 'a'), _line(20, 'b')]),
        offsetMs: -2000,
      );
      // Position 10s + (-2s) = 8s, before line 0 → empty.
      expect(await driver.push(const Duration(seconds: 10)), equals(MtLyricsCursor.empty));
      // Position 12s + (-2s) = 10s → line 0.
      expect((await driver.push(const Duration(seconds: 12))).lineIndex, 0);
      await driver.dispose();
    });
  });

  group('lifecycle', () {
    test('cursorStream replays seeded empty to new subscribers', () async {
      final driver = _Driver(_lyrics([_line(10, 'a')]));
      final first = await driver.controller.cursorStream.first;
      expect(first, equals(MtLyricsCursor.empty));
      await driver.dispose();
    });

    test('distinct: identical cursors do not double-emit', () async {
      final driver = _Driver(_lyrics([_line(10, 'a'), _line(20, 'b')]));
      final emitted = <MtLyricsCursor>[];
      final sub = driver.controller.cursorStream.listen(emitted.add);

      await driver.push(const Duration(seconds: 11));
      await driver.push(const Duration(seconds: 12));
      await driver.push(const Duration(seconds: 13));

      await sub.cancel();
      // Seeded empty + one transition to line 0 = 2 emissions.
      expect(emitted, [
        MtLyricsCursor.empty,
        const MtLyricsCursor(lineIndex: 0, segmentIndex: 0),
      ]);
      await driver.dispose();
    });

    test('dispose can be called multiple times', () async {
      final driver = _Driver(_lyrics([_line(10, 'a')]));
      await driver.controller.dispose();
      await driver.controller.dispose();
      await driver._position.close();
    });

    test('pre-roll positions do not re-emit seeded empty', () async {
      final driver = _Driver(_lyrics([_line(10, 'a')]));
      final emitted = <MtLyricsCursor>[];
      final sub = driver.controller.cursorStream.listen(emitted.add);

      // All before the first line — every cursor maps to empty.
      await driver.push(const Duration(seconds: 5));
      await driver.push(const Duration(seconds: 6));
      await driver.push(const Duration(seconds: 7));

      await sub.cancel();
      expect(emitted, [MtLyricsCursor.empty]);
      await driver.dispose();
    });

    test('swallows position-stream errors and keeps emitting', () async {
      final position = StreamController<Duration>.broadcast();
      final controller = MtLyricsController(
        lyrics: _lyrics([_line(10, 'a'), _line(20, 'b')]),
        position: position.stream,
      );

      final emitted = <MtLyricsCursor>[];
      final errors = <Object>[];
      final sub = controller.cursorStream.listen(
        emitted.add,
        onError: errors.add,
      );

      position.addError(Exception('transient'));
      await Future<void>.delayed(Duration.zero);
      position.add(const Duration(seconds: 11));
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty);
      expect(emitted.last.lineIndex, 0);

      await sub.cancel();
      await controller.dispose();
      await position.close();
    });
  });

  group('preconditions', () {
    test('asserts on unsorted lines', () {
      expect(
        () => MtLyricsController(
          lyrics: MtLyrics(
            lines: [_line(20, 'first'), _line(10, 'second')],
          ),
          position: const Stream<Duration>.empty(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on unsorted segments within a line', () {
      final badLine = MtLyricsLine(
        timestamp: const Duration(seconds: 10),
        segments: [_seg(15, 'b'), _seg(12, 'a')],
      );
      expect(
        () => MtLyricsController(
          lyrics: _lyrics([badLine]),
          position: const Stream<Duration>.empty(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
