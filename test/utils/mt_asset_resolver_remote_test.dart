import 'dart:async';
import 'dart:convert';
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
    Duration remoteFetchTimeout = const Duration(seconds: 10),
    Future<Uint8List> Function(Uri uri)? fetch,
  }) => MtAssetResolver.forTesting(
    cacheDir: cache.path,
    contentAuthority: authority,
    remoteFetchTimeout: remoteFetchTimeout,
    fetch: (uri) async {
      fetched.add(uri);
      if (fetch != null) return fetch(uri);
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

  test(
    'falls back when the download stalls, then retries on the next call',
    () async {
      const url = 'https://cdn.test/stalled.jpg';
      var stalled = true;
      final r = resolver(
        remoteFetchTimeout: const Duration(milliseconds: 50),
        fetch: (_) => stalled
            ? Completer<Uint8List>().future
            : Future.value(Uint8List.fromList([1, 2, 3])),
      );

      // The test-side timeout turns a hang into a fast, readable failure.
      final first = await r
          .resolveMediaItemForExternalAccess(item(url))
          .timeout(const Duration(seconds: 2));
      expect(first.artUri, Uri.parse(url));

      stalled = false;
      final second = await r
          .resolveMediaItemForExternalAccess(item(url))
          .timeout(const Duration(seconds: 2));
      expect(second.artUri!.scheme, 'content');
      expect(fetched, hasLength(2));
    },
  );

  for (final (stall, sendHeaders) in [
    ('before the headers', false),
    ('mid-body', true),
  ]) {
    test('the HTTP fetcher tears down a download stalled $stall', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = <Socket>[];
      final clientClosed = Completer<void>();
      void markClosed() {
        if (!clientClosed.isCompleted) clientClosed.complete();
      }

      addTearDown(() async {
        for (final socket in accepted) {
          socket.destroy();
        }
        await server.close();
      });
      server.listen((socket) {
        accepted.add(socket);
        var answered = !sendHeaders;
        socket.listen(
          (_) {
            if (answered) return;
            answered = true;
            // Promise 1000 bytes, send 3, then go silent.
            socket
              ..add(
                ascii.encode(
                  'HTTP/1.1 200 OK\r\n'
                  'Content-Type: image/jpeg\r\n'
                  'Content-Length: 1000\r\n\r\n',
                ),
              )
              ..add([0xFF, 0xD8, 0xFF]);
          },
          onDone: markClosed,
          onError: (Object _) => markClosed(),
        );
      });
      final url = 'http://${server.address.host}:${server.port}/cover.jpg';
      final r = MtAssetResolver.forTesting(
        cacheDir: cache.path,
        contentAuthority: 'app.mt_audio.artwork',
        remoteFetchTimeout: const Duration(milliseconds: 200),
      );

      final resolved = await r
          .resolveMediaItemForExternalAccess(item(url))
          .timeout(const Duration(seconds: 5));

      expect(resolved.artUri, Uri.parse(url));
      await expectLater(
        clientClosed.future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });
  }
}
