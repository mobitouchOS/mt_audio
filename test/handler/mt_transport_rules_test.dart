import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/handler/mt_transport_rules.dart';

void main() {
  group('isSameQueue', () {
    const a = MediaItem(id: 'a', title: 'A');
    const b = MediaItem(id: 'b', title: 'B');

    test('the same objects in the same order are the same queue', () {
      expect(isSameQueue([a, b], [a, b]), isTrue);
      expect(isSameQueue(const [], const []), isTrue);
    });

    test('no previous queue is a change', () {
      expect(isSameQueue(null, [a]), isFalse);
    });

    test('an item replaced under the same id is a change', () {
      const renamed = MediaItem(id: 'a', title: 'A (new artwork)');
      expect(renamed, a, reason: 'MediaItem.== compares only the id');
      expect(isSameQueue([a, b], [renamed, b]), isFalse);
    });

    test('added, removed and reordered items are a change', () {
      expect(isSameQueue([a], [a, b]), isFalse);
      expect(isSameQueue([a, b], [a]), isFalse);
      expect(isSameQueue([a, b], [b, a]), isFalse);
    });
  });

  group('skipPreviousAction', () {
    test('restarts the first item', () {
      expect(
        skipPreviousAction(hasPrevious: false, position: Duration.zero),
        SkipPreviousAction.restart,
      );
    });

    test('restarts an item that has played past the threshold', () {
      expect(
        skipPreviousAction(
          hasPrevious: true,
          position: const Duration(seconds: 4),
        ),
        SkipPreviousAction.restart,
      );
    });

    test('moves to the previous item within the threshold', () {
      expect(
        skipPreviousAction(hasPrevious: true, position: restartThreshold),
        SkipPreviousAction.previous,
      );
      expect(
        skipPreviousAction(
          hasPrevious: true,
          position: const Duration(seconds: 1),
        ),
        SkipPreviousAction.previous,
      );
    });
  });
}
