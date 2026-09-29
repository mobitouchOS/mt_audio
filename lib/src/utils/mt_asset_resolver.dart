import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('com.mobitouchos.mt_audio/artwork');

/// Downloads remote artwork bytes; injectable for tests.
typedef MtRemoteArtworkFetcher = Future<Uint8List> Function(Uri uri);

/// Internal utility that resolves `asset:///` URIs to `file://` URIs
/// by extracting assets from the Flutter bundle to the cache directory.
///
/// On Android, also supports resolving to `content://` URIs for cross-process
/// access (required by Android Auto, which runs in a separate process).
class MtAssetResolver {
  MtAssetResolver._(
    this._cacheDir,
    this._contentAuthority, {
    MtRemoteArtworkFetcher? fetch,
    Duration remoteFetchTimeout = const Duration(seconds: 10),
  }) : _injectedFetch = fetch,
       _remoteFetchTimeout = remoteFetchTimeout;

  /// A resolver over an explicit cache directory, for tests.
  @visibleForTesting
  factory MtAssetResolver.forTesting({
    required String cacheDir,
    String? contentAuthority,
    MtRemoteArtworkFetcher? fetch,
    Duration remoteFetchTimeout = const Duration(seconds: 10),
  }) => MtAssetResolver._(
    cacheDir,
    contentAuthority,
    fetch: fetch,
    remoteFetchTimeout: remoteFetchTimeout,
  );

  final String _cacheDir;
  final String? _contentAuthority;
  final MtRemoteArtworkFetcher? _injectedFetch;

  /// Upper bound for one remote artwork download. Android Auto browse and
  /// search results wait for every item's artwork, so a stalled server
  /// must cost one late cover, not the whole list.
  final Duration _remoteFetchTimeout;
  final Map<String, Uri> _resolved = {};
  final Map<String, Future<Uri>> _inFlight = {};

  /// Shared by every remote download: a browse list of ~100 covers from one
  /// CDN reuses a few keep-alive connections instead of opening a client
  /// (and a socket) per item.
  late final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = _remoteFetchTimeout
    ..maxConnectionsPerHost = 6;

  /// Initializes the resolver with a cache directory.
  ///
  /// On Android, queries the native plugin for the artwork ContentProvider
  /// authority so that [resolveForExternalAccess] can produce `content://`
  /// URIs accessible by Android Auto.
  static Future<MtAssetResolver> init() async {
    final dir = await getApplicationCacheDirectory();
    final cacheDir = '${dir.path}/mt_audio_assets';
    await Directory(cacheDir).create(recursive: true);

    String? authority;
    if (Platform.isAndroid) {
      try {
        authority = await _channel.invokeMethod<String>(
          'getContentProviderAuthority',
        );
      } on MissingPluginException {
        debugPrint(
          'mt_audio: MtAudioPlugin not registered; '
          'asset:// artwork will fall back to file:// URIs that Android Auto '
          "cannot read across processes. Artwork won't appear on Android Auto. "
          'Ensure the plugin is registered (rerun `flutter pub get` and a '
          'full rebuild after upgrading mt_audio).',
        );
      }
    }

    return MtAssetResolver._(cacheDir, authority);
  }

  /// Returns `true` if [uri] uses the `asset` scheme.
  static bool isAssetUri(Uri? uri) => uri != null && uri.scheme == 'asset';

  /// Extracts the Flutter asset key from an `asset:///` URI.
  ///
  /// Example: `asset:///assets/images/cover.png` → `assets/images/cover.png`
  static String assetKey(Uri uri) {
    final path = uri.path;
    return path.startsWith('/') ? path.substring(1) : path;
  }

  /// Resolves [uri] to a `file://` URI if it uses the `asset` scheme.
  ///
  /// Returns the original URI unchanged for non-asset schemes.
  /// Use this for in-process access (notifications, just_audio).
  Future<Uri> resolve(Uri uri) async {
    if (!isAssetUri(uri)) return uri;

    final key = assetKey(uri);
    final cached = _resolved[key];
    if (cached != null) return cached;

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _extract(key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlight.remove(key));
    }
  }

  /// Resolves [uri] for cross-process access (Android Auto).
  ///
  /// On Android (when the ContentProvider authority is available), this
  /// extracts the asset to the cache directory and returns a `content://`
  /// URI served by the native `MtAudioArtworkProvider`. On other platforms or when no
  /// authority is configured, falls back to [resolve].
  Future<Uri> resolveForExternalAccess(Uri uri) async {
    if (!isAssetUri(uri)) return uri;

    // Ensure the asset is extracted to the cache directory.
    final fileUri = await resolve(uri);

    if (_contentAuthority != null) {
      final key = assetKey(uri);
      return Uri(scheme: 'content', host: _contentAuthority, path: '/$key');
    }

    return fileUri;
  }

  static bool _isRemote(Uri uri) =>
      uri.scheme == 'http' || uri.scheme == 'https';

  /// Downloads remote artwork into the provider's cache and returns its
  /// `content://` URI — Android Auto runs in another process and does not
  /// load remote URLs for browse items. Any failure returns [uri] unchanged.
  Future<Uri> _resolveRemoteForExternalAccess(Uri uri) async {
    if (_contentAuthority == null) return uri;

    final key = 'remote/${_stableHash(uri.toString())}';
    final cached = _resolved[key];
    if (cached != null) return toContentUri(cached) ?? uri;

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _cacheRemote(uri, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlight.remove(key));
    }
  }

  /// Reuses the file a previous process cached for [key] or downloads [uri]
  /// into a new one. Remote keys map to the cached file's `file://` URI in
  /// [_resolved], like asset keys; callers get its `content://` URI.
  Future<Uri> _cacheRemote(Uri uri, String key) async {
    try {
      final file = _cachedRemoteFile(key) ?? await _downloadRemote(uri, key);
      final fileUri = Uri.file(file.path);
      _resolved[key] = fileUri;
      return toContentUri(fileUri) ?? uri;
    } on Object catch (error) {
      debugPrint(
        'mt_audio: remote artwork $uri not cached for Android Auto: $error',
      );
      return uri;
    }
  }

  File? _cachedRemoteFile(String key) => _imageSignatures
      .map((signature) => File('$_cacheDir/$key.${signature.$1}'))
      .where((file) => file.existsSync())
      .firstOrNull;

  /// Downloads [uri] to `<key>.<image extension>`; throws when the bytes are
  /// not an image, so a captive-portal page or JSON error that came back
  /// with a 200 is never cached as artwork.
  Future<File> _downloadRemote(Uri uri, String key) async {
    // Write through `<key>.part` and rename it onto the target so a process
    // death mid-write (routine on Android) never leaves a truncated file at
    // the target — targets are atomic-or-absent, so the bare `existsSync()`
    // in `_cachedRemoteFile` stays safe. The `.part` name carries no
    // extension (the image type is only known once the bytes arrive), so a
    // stale one from a crash is always found and cleared here.
    final partFile = File('$_cacheDir/$key.part');
    if (partFile.existsSync()) await partFile.delete();
    final bytes = await (_injectedFetch ?? _httpFetch)(
      uri,
    ).timeout(_remoteFetchTimeout);
    final extension = _imageExtension(bytes);
    if (extension == null) {
      throw const FormatException('not a JPEG, PNG, GIF or WebP image');
    }
    await partFile.parent.create(recursive: true);
    await partFile.writeAsBytes(bytes, flush: true);
    return partFile.rename('$_cacheDir/$key.$extension');
  }

  /// Leading bytes of the image types cached as remote artwork, keyed by the
  /// file extension `MtAudioArtworkProvider.getType` maps to a MIME type.
  /// `null` matches any byte (WebP's RIFF chunk size).
  static const _imageSignatures = <(String, List<int?>)>[
    ('jpg', [0xFF, 0xD8, 0xFF]),
    ('png', [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    ('gif', [0x47, 0x49, 0x46, 0x38]),
    // RIFF <4-byte chunk size> WEBP
    (
      'webp',
      [0x52, 0x49, 0x46, 0x46, null, null, null, null, 0x57, 0x45, 0x42, 0x50],
    ),
  ];

  static String? _imageExtension(Uint8List bytes) => _imageSignatures
      .where((signature) => _startsWith(bytes, signature.$2))
      .map((signature) => signature.$1)
      .firstOrNull;

  static bool _startsWith(Uint8List bytes, List<int?> signature) =>
      bytes.length >= signature.length &&
      signature.indexed.every(
        (entry) => entry.$2 == null || bytes[entry.$1] == entry.$2,
      );

  /// Downloads [uri] over the shared client within [_remoteFetchTimeout],
  /// counted from the call so time queued for a free connection counts too.
  ///
  /// Past the deadline the connection is destroyed, not merely abandoned:
  /// `abort` ends a request still waiting for its headers, and cancelling a
  /// half-read body closes its socket (the client never pools it), so a
  /// stalled server cannot pin one of the shared connections.
  Future<Uint8List> _httpFetch(Uri uri) async {
    final started = Stopwatch()..start();
    final request = await _httpClient.getUrl(uri);
    final bytes = Completer<Uint8List>();
    StreamSubscription<List<int>>? body;
    final deadline = Timer(_remoteFetchTimeout - started.elapsed, () {
      final error = TimeoutException(
        'artwork download timed out',
        _remoteFetchTimeout,
      );
      request.abort(error);
      if (body == null || bytes.isCompleted) return;
      unawaited(body.cancel());
      bytes.completeError(error);
    });
    try {
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        // Cancelling the unread body releases the connection.
        await response.listen(null).cancel();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final builder = BytesBuilder(copy: false);
      body = response.listen(
        builder.add,
        onError: bytes.completeError,
        onDone: () => bytes.complete(builder.takeBytes()),
        cancelOnError: true,
      );
      return await bytes.future;
    } finally {
      deadline.cancel();
    }
  }

  /// FNV-1a 64-bit — a file name that is stable across app launches
  /// (`String.hashCode` is not guaranteed to be). VM integers wrap at 64
  /// bits, which is exactly the modulus FNV needs.
  static String _stableHash(String value) {
    // mt_audio ships only for Android/iOS (see pubspec.yaml platforms),
    // never compiled to JS; the exact 64-bit FNV-1a offset basis is
    // required for correctness.
    // ignore: avoid_js_rounded_ints
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  Future<Uri> _extract(String key) async {
    final ByteData data;
    try {
      data = await rootBundle.load(key);
    } on Exception catch (e) {
      throw Exception(
        "Failed to load asset '$key' from bundle. "
        'Ensure the asset is declared in pubspec.yaml. '
        'Original error: $e',
      );
    }

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final file = File('$_cacheDir/$key');

    // Skip the write only if the cached file exists AND its bytes match the
    // bundled asset. Length alone is insufficient — a same-size update (e.g.
    // a re-encoded image with identical byte count) would leave stale artwork
    // in the cache across sessions.
    if (!await _cachedFileMatches(file, bytes)) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }

    final fileUri = Uri.file(file.path);
    _resolved[key] = fileUri;
    return fileUri;
  }

  Future<bool> _cachedFileMatches(File file, Uint8List bytes) async {
    final existingLength = await file.length().onError((_, _) => -1);
    if (existingLength != bytes.length) return false;

    final Uint8List existing;
    try {
      existing = await file.readAsBytes();
    } on FileSystemException {
      return false;
    }

    for (var i = 0; i < bytes.length; i++) {
      if (existing[i] != bytes[i]) return false;
    }
    return true;
  }

  /// Resolves the artwork URI of an [MtAudioItem].
  ///
  /// Returns the item unchanged if its artwork is not an asset URI.
  Future<MtAudioItem> resolveItem(MtAudioItem item) async {
    if (!isAssetUri(item.artworkUri)) return item;
    final resolved = await resolve(item.artworkUri!);
    return item.copyWith(artworkUri: resolved);
  }

  /// Resolves the artwork URI of a [MediaItem] for in-process access.
  ///
  /// Returns the item unchanged if its artwork is not an asset URI.
  Future<MediaItem> resolveMediaItem(MediaItem item) async {
    if (!isAssetUri(item.artUri)) return item;
    final resolved = await resolve(item.artUri!);
    return item.copyWith(artUri: resolved);
  }

  /// Resolves the artwork URI of a [MediaItem] for cross-process access.
  ///
  /// On Android, bundled assets and remote images become `content://` URIs
  /// served by `MtAudioArtworkProvider`. Other URIs are returned unchanged.
  Future<MediaItem> resolveMediaItemForExternalAccess(MediaItem item) async {
    final artUri = item.artUri;
    if (artUri == null) return item;
    if (isAssetUri(artUri)) {
      return item.copyWith(artUri: await resolveForExternalAccess(artUri));
    }
    if (_isRemote(artUri)) {
      return item.copyWith(
        artUri: await _resolveRemoteForExternalAccess(artUri),
      );
    }
    return item;
  }

  /// Converts a `file://` URI in the asset cache to a `content://` URI.
  ///
  /// Returns `null` if [uri] is not a `file://` URI within the cache
  /// directory or if no ContentProvider authority is configured.
  Uri? toContentUri(Uri? uri) {
    if (_contentAuthority == null || uri == null || uri.scheme != 'file') {
      return null;
    }
    final path = uri.toFilePath();
    if (!path.startsWith('$_cacheDir/')) return null;
    final key = path.substring(_cacheDir.length + 1);
    return Uri(scheme: 'content', host: _contentAuthority, path: '/$key');
  }
}
