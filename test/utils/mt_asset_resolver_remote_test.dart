import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/utils/mt_asset_resolver.dart';

/// A JPEG/JFIF header — enough for the resolver's signature check.
final _jpeg = Uint8List.fromList(
  [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46],
);

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
      return _jpeg;
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
    expect(file.readAsBytesSync(), _jpeg);
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
      // The `.part` file is named after the URL hash alone — the image
      // type, and so the target's extension, is only known once the
      // bytes arrive.
      final partFile = File(
        targetFile.path.replaceFirst(RegExp(r'\.jpg$'), '.part'),
      );
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
      expect(targetFile.readAsBytesSync(), _jpeg);
      expect(partFile.existsSync(), isFalse);
    },
  );

  test('downloads again when the OS evicted the cached file', () async {
    final r = resolver();
    final first = await r.resolveMediaItemForExternalAccess(
      item('https://cdn.test/a.jpg'),
    );
    final file = File('${cache.path}${first.artUri!.path}')..deleteSync();

    final second = await r.resolveMediaItemForExternalAccess(
      item('https://cdn.test/a.jpg'),
    );

    expect(fetched, hasLength(2));
    expect(second.artUri, first.artUri);
    expect(file.existsSync(), isTrue);
  });

  test('reuses the cached file in a fresh process', () async {
    final first = await resolver().resolveMediaItemForExternalAccess(
      item('https://cdn.test/a.jpg'),
    );
    final second = await resolver().resolveMediaItemForExternalAccess(
      item('https://cdn.test/a.jpg'),
    );

    expect(second.artUri, first.artUri);
    expect(fetched, hasLength(1));
  });

  for (final (extension, bytes) in [
    ('jpg', _jpeg.toList()),
    ('png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
    ('gif', ascii.encode('GIF89a')),
    (
      'webp',
      [...ascii.encode('RIFF'), 0x24, 0, 0, 0, ...ascii.encode('WEBPVP8 ')],
    ),
  ]) {
    test('caches a $extension body under a .$extension name', () async {
      final resolved = await resolver(
        fetch: (_) async => Uint8List.fromList(bytes),
      ).resolveMediaItemForExternalAccess(item('https://cdn.test/cover'));

      // MtAudioArtworkProvider.getType derives the MIME type from it.
      expect(resolved.artUri!.path, endsWith('.$extension'));
      final file = File('${cache.path}${resolved.artUri!.path}');
      expect(file.readAsBytesSync(), bytes);
    });
  }

  for (final (kind, body) in [
    ('an HTML error page', utf8.encode('<!DOCTYPE html><h1>Blocked</h1>')),
    ('a JSON body', utf8.encode('{"error":"not found"}')),
    (
      'a non-WebP RIFF file',
      [...ascii.encode('RIFF'), 0x24, 0, 0, 0, ...ascii.encode('WAVE')],
    ),
    ('an empty body', <int>[]),
  ]) {
    test('falls back and caches nothing for $kind', () async {
      const url = 'https://cdn.test/a.jpg';
      final resolved = await resolver(
        fetch: (_) async => Uint8List.fromList(body),
      ).resolveMediaItemForExternalAccess(item(url));

      expect(resolved.artUri, Uri.parse(url));
      expect(cache.listSync(recursive: true).whereType<File>(), isEmpty);
    });
  }

  test(
    'falls back when the download stalls, then retries on the next call',
    () async {
      const url = 'https://cdn.test/stalled.jpg';
      var stalled = true;
      final r = resolver(
        remoteFetchTimeout: const Duration(milliseconds: 50),
        fetch: (_) =>
            stalled ? Completer<Uint8List>().future : Future.value(_jpeg),
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
