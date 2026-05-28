import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('com.mobitouchos.mt_audio/artwork');

/// Internal utility that resolves `asset:///` URIs to `file://` URIs
/// by extracting assets from the Flutter bundle to the cache directory.
///
/// On Android, also supports resolving to `content://` URIs for cross-process
/// access (required by Android Auto, which runs in a separate process).
class MtAssetResolver {
  MtAssetResolver._(this._cacheDir, this._contentAuthority);

  final String _cacheDir;
  final String? _contentAuthority;
  final Map<String, Uri> _resolved = {};
  final Map<String, Future<Uri>> _inFlight = {};

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
        authority =
            await _channel.invokeMethod<String>('getContentProviderAuthority');
      } on MissingPluginException {
        // Plugin not registered — content:// URIs won't be available.
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

    // Only write if the cached file is missing or has a different size,
    // so unchanged assets survive across sessions without redundant I/O.
    final existingLength = await file.length().onError((_, _) => -1);
    if (existingLength != bytes.length) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }

    final fileUri = Uri.file(file.path);
    _resolved[key] = fileUri;
    return fileUri;
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
  /// On Android, produces `content://` URIs accessible by Android Auto.
  /// Returns the item unchanged if its artwork is not an asset URI.
  Future<MediaItem> resolveMediaItemForExternalAccess(MediaItem item) async {
    if (!isAssetUri(item.artUri)) return item;
    final resolved = await resolveForExternalAccess(item.artUri!);
    return item.copyWith(artUri: resolved);
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
