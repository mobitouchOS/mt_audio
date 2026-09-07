import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/models/mt_lyrics.dart';

void main() {
  group('MtLyricsLine.text', () {
    test('joins segment text in order', () {
      const line = MtLyricsLine(
        timestamp: Duration.zero,
        segments: [
          MtLyricsSegment(text: 'one ', timestamp: Duration.zero),
          MtLyricsSegment(text: 'two ', timestamp: Duration(seconds: 1)),
          MtLyricsSegment(text: 'three', timestamp: Duration(seconds: 2)),
        ],
      );
      expect(line.text, 'one two three');
    });

    test('is empty for a line with no segments', () {
      const line = MtLyricsLine(timestamp: Duration.zero, segments: []);
      expect(line.text, '');
    });
  });
}
