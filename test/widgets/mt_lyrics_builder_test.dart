import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_controller.dart';
import 'package:mt_audio/src/lyrics/mt_lyrics_cursor.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';
import 'package:mt_audio/src/widgets/lyrics/mt_lyrics_builder.dart';

MtLyricsLine _line(int seconds, String text) => MtLyricsLine(
  timestamp: Duration(seconds: seconds),
  segments: [
    MtLyricsSegment(
      text: text,
      timestamp: Duration(seconds: seconds),
    ),
  ],
);

const _a2Line = MtLyricsLine(
  timestamp: Duration(seconds: 30),
  segments: [
    MtLyricsSegment(text: 'one ', timestamp: Duration(seconds: 30)),
    MtLyricsSegment(text: 'two ', timestamp: Duration(seconds: 31)),
    MtLyricsSegment(text: 'three', timestamp: Duration(seconds: 32)),
  ],
);

class _Harness {
  _Harness(List<MtLyricsLine> lines)
    : lyrics = MtLyrics(lines: lines),
      position = StreamController<Duration>.broadcast() {
    controller = MtLyricsController(
      lyrics: lyrics,
      position: position.stream,
    );
  }

  final MtLyrics lyrics;
  final StreamController<Duration> position;
  late final MtLyricsController controller;

  Future<void> dispose() async {
    await controller.dispose();
    await position.close();
  }

  /// Emits [value] and pumps through both async stream hops
  /// (position -> controller -> StreamBuilder).
  Future<void> seek(WidgetTester tester, Duration value) async {
    position.add(value);
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  group('MtLyricsState', () {
    test('exposes lyrics, cursor and derived getters', () {
      final lyrics = MtLyrics(lines: [_line(10, 'a'), _a2Line]);
      const cursor = MtLyricsCursor(lineIndex: 1, segmentIndex: 2);
      final state = MtLyricsState(lyrics: lyrics, cursor: cursor);

      expect(state.lines, same(lyrics.lines));
      expect(state.lineIndex, 1);
      expect(state.segmentIndex, 2);
      expect(state.hasLine, isTrue);
      expect(state.currentLine, same(_a2Line));
      expect(state.currentSegment, same(_a2Line.segments[2]));
      expect(state.isActiveLine(1), isTrue);
      expect(state.isActiveLine(0), isFalse);
      expect(state.isActiveSegment(2), isTrue);
      expect(state.isActiveSegment(0), isFalse);
    });

    test('empty cursor yields no line, no segment', () {
      final state = MtLyricsState(
        lyrics: MtLyrics(lines: [_line(10, 'a')]),
        cursor: MtLyricsCursor.empty,
      );

      expect(state.hasLine, isFalse);
      expect(state.currentLine, isNull);
      expect(state.currentSegment, isNull);
      expect(state.isActiveLine(0), isFalse);
      expect(state.isActiveSegment(0), isFalse);
    });

    test('segmentIndex -1 on an active line yields null segment', () {
      const state = MtLyricsState(
        lyrics: MtLyrics(lines: [_a2Line]),
        cursor: MtLyricsCursor(lineIndex: 0, segmentIndex: -1),
      );

      expect(state.currentLine, same(_a2Line));
      expect(state.currentSegment, isNull);
      expect(state.isActiveSegment(0), isFalse);
    });
  });

  group('MtLyricsBuilder', () {
    testWidgets('builds synchronously from the controller cursor', (
      tester,
    ) async {
      final h = _Harness([_line(10, 'hello')]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MtLyricsBuilder(
            controller: h.controller,
            builder: (context, state) =>
                Text(state.hasLine ? state.currentLine!.text : 'idle'),
          ),
        ),
      );

      expect(find.text('idle'), findsOneWidget);
    });

    testWidgets('rebuilds when the cursor advances', (tester) async {
      final h = _Harness([_line(10, 'hello'), _line(20, 'world')]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MtLyricsBuilder(
            controller: h.controller,
            builder: (context, state) =>
                Text(state.currentLine?.text ?? 'idle'),
          ),
        ),
      );

      await h.seek(tester, const Duration(seconds: 10));
      expect(find.text('hello'), findsOneWidget);

      await h.seek(tester, const Duration(seconds: 20));
      expect(find.text('world'), findsOneWidget);
    });

    testWidgets('exposes the active segment for karaoke rendering', (
      tester,
    ) async {
      final h = _Harness([_a2Line]);
      addTearDown(h.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MtLyricsBuilder(
            controller: h.controller,
            builder: (context, state) =>
                Text(state.currentSegment?.text ?? 'none'),
          ),
        ),
      );

      await h.seek(tester, const Duration(seconds: 31));
      expect(find.text('two '), findsOneWidget);
    });

    testWidgets('switches subscription when the controller changes', (
      tester,
    ) async {
      final first = _Harness([_line(10, 'first')]);
      final second = _Harness([_line(10, 'second')]);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget build(MtLyricsController controller) => MaterialApp(
        home: MtLyricsBuilder(
          controller: controller,
          builder: (context, state) => Text(state.currentLine?.text ?? 'idle'),
        ),
      );

      await tester.pumpWidget(build(first.controller));
      await first.seek(tester, const Duration(seconds: 10));
      expect(find.text('first'), findsOneWidget);

      await tester.pumpWidget(build(second.controller));
      await tester.pump();
      expect(find.text('idle'), findsOneWidget);

      await second.seek(tester, const Duration(seconds: 10));
      expect(find.text('second'), findsOneWidget);
    });
  });
}
