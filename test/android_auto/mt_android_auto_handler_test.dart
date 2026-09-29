import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio/src/android_auto/mt_android_auto_handler.dart';

class _Handler extends BaseAudioHandler with MtAndroidAutoHandler {
  _Handler(this.androidAutoDelegate);

  @override
  final MtAndroidAutoDelegate androidAutoDelegate;
}

class _Delegate extends MtAndroidAutoDelegate {
  final searches = <String>[];
  Object? throwOnBrowse;

  @override
  Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId) async {
    // throwOnBrowse is deliberately Object-typed to prove the mixin
    // swallows any thrown value, not just Exception/Error subtypes.
    // ignore: only_throw_errors
    if (throwOnBrowse != null) throw throwOnBrowse!;
    return const [MtBrowsableItem(id: 'a', title: 'A')];
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) async =>
      throw StateError('boom');

  @override
  Future<List<MtAudioItem>> search(String query) async =>
      throw StateError('boom');

  @override
  Future<void> onPlayFromSearch(String query) async => searches.add(query);
}

void main() {
  late _Delegate delegate;
  late _Handler handler;

  setUp(() {
    delegate = _Delegate();
    handler = _Handler(delegate);
  });

  test('getChildren maps delegate items', () async {
    final items = await handler.getChildren('root');
    expect(items.single.id, 'a');
    expect(items.single.playable, isFalse);
  });

  test('getChildren returns [] when the delegate throws an Error', () async {
    delegate.throwOnBrowse = StateError('not an Exception');
    expect(await handler.getChildren('root'), isEmpty);
  });

  test('playFromMediaId swallows delegate errors', () async {
    await expectLater(handler.playFromMediaId('x'), completes);
  });

  test('search returns [] when the delegate throws an Error', () async {
    expect(await handler.search('q'), isEmpty);
  });

  test('playFromSearch forwards the query to the delegate', () async {
    await handler.playFromSearch('kaczuszki');
    expect(delegate.searches, ['kaczuszki']);
  });

  test('onPlayFromSearch defaults to a no-op', () async {
    final minimal = _MinimalDelegate();
    await expectLater(minimal.onPlayFromSearch('x'), completes);
  });
}

class _MinimalDelegate extends MtAndroidAutoDelegate {
  @override
  Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId) async =>
      const [];

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {}

  @override
  Future<List<MtAudioItem>> search(String query) async => const [];
}
