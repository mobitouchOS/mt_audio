import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/utils/mt_asset_resolver.dart';

void main() {
  late Directory cache;
  late List<Uri> fetched;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('mt_audio_art');
    fetched = [];
  });
  tearDown(() => cache.deleteSync(recursive: true));

  MtAssetResolver resolver({
    String? authority = 'app.mt_audio.artwork',
    bool fail = false,
  }) => MtAssetResolver.forTesting(
    cacheDir: cache.path,
    contentAuthority: authority,
    fetch: (uri) async {
      fetched.add(uri);
      if (fail) throw const SocketException('offline');
      return Uint8List.fromList([1, 2, 3]);
    },
  );

  MediaItem item(String art) =>
      MediaItem(id: 'x', title: 'X', artUri: Uri.parse(art));

  test('serves remote artwork through the content provider', () async {
    final resolved = await resolver().resolveMediaItemForExternalAccess(
      item('https://cdn.test/a.jpg'),
    );

    expect(resolved.artUri!.scheme, 'content');
    expect(resolved.artUri!.host, 'app.mt_audio.artwork');
    expect(resolved.artUri!.path, startsWith('/remote/'));
    final file = File('${cache.path}${resolved.artUri!.path}');
    expect(file.readAsBytesSync(), [1, 2, 3]);
  });

  test('downloads each URL once', () async {
    final r = resolver();
    await r.resolveMediaItemForExternalAccess(item('https://cdn.test/a.jpg'));
    await r.resolveMediaItemForExternalAccess(item('https://cdn.test/a.jpg'));
    expect(fetched, hasLength(1));
  });

  test('falls back to the original URI when the download fails', () async {
    final resolved = await resolver(
      fail: true,
    ).resolveMediaItemForExternalAccess(item('https://cdn.test/a.jpg'));
    expect(resolved.artUri, Uri.parse('https://cdn.test/a.jpg'));
  });

  test(
    'leaves remote artwork alone without a content provider (iOS)',
    () async {
      final resolved = await resolver(
        authority: null,
      ).resolveMediaItemForExternalAccess(item('https://cdn.test/a.jpg'));
      expect(resolved.artUri, Uri.parse('https://cdn.test/a.jpg'));
      expect(fetched, isEmpty);
    },
  );

  test(
    'recovers from a truncated .part file left by a crashed download',
    () async {
      // Learn the deterministic on-disk path for this URL using a
      // throwaway resolver, then delete the target it wrote so only a
      // stale `.part` remains — as if a previous process died mid-write.
      final learner = resolver();
      final learned = await learner.resolveMediaItemForExternalAccess(
        item('https://cdn.test/c.jpg'),
      );
      final targetFile = File('${cache.path}${learned.artUri!.path}');
      final partFile = File('${targetFile.path}.part');
      targetFile.deleteSync();
      partFile.writeAsStringSync('garbage');

      // A fresh resolver over the same cache directory simulates a new
      // process: its in-memory caches are empty, so it must consult disk.
      fetched.clear();
      final resolved = await resolver().resolveMediaItemForExternalAccess(
        item('https://cdn.test/c.jpg'),
      );

      expect(fetched, hasLength(1));
      expect(resolved.artUri, learned.artUri);
      expect(targetFile.readAsBytesSync(), [1, 2, 3]);
      expect(partFile.existsSync(), isFalse);
    },
  );
}
