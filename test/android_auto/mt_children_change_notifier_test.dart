import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/android_auto/mt_children_change_notifier.dart';

void main() {
  late MtChildrenChangeNotifier notifier;

  setUp(() => notifier = MtChildrenChangeNotifier());
  tearDown(() => notifier.dispose());

  test('notify emits on the parent subscribed by audio_service', () async {
    final events = <Map<String, dynamic>>[];
    notifier.subscribe('root').listen(events.add);

    notifier.notify('root');
    await Future<void>.delayed(Duration.zero);

    expect(events, [<String, dynamic>{}]);
  });

  test('subscribing does not emit on its own', () async {
    final events = <Map<String, dynamic>>[];
    notifier.subscribe('root').listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });

  test('the same parent reuses one stream', () {
    expect(identical(notifier.subscribe('a'), notifier.subscribe('a')), isTrue);
  });

  test('notify before subscribe is a no-op', () {
    expect(() => notifier.notify('never-loaded'), returnsNormally);
  });
}
