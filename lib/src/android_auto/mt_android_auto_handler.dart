import 'package:audio_service/audio_service.dart';

import 'package:mt_audio/src/android_auto/mt_android_auto_delegate.dart';

/// Mixin that adds Android Auto support to [BaseAudioHandler].
///
/// This mixin delegates Android Auto browsing and playback requests
/// to an [MtAndroidAutoDelegate].
mixin MtAndroidAutoHandler on BaseAudioHandler {
  /// The Android Auto delegate that supplies content.
  MtAndroidAutoDelegate get androidAutoDelegate;

  // Every entry point catches Object, not just Exception: a delegate's
  // StateError or TypeError must degrade to an empty result instead of
  // escaping into audio_service's media browser callbacks.

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      final items = await androidAutoDelegate.getChildren(parentMediaId);
      return items.map((item) => item.toMediaItem()).toList();
    } on Object catch (_) {
      return [];
    }
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      await androidAutoDelegate.onPlayFromMediaId(mediaId);
    } on Object catch (_) {
      return;
    }
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      await androidAutoDelegate.onPlayFromSearch(query);
    } on Object catch (_) {
      return;
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final items = await androidAutoDelegate.search(query);
      return items.map((item) => item.toMediaItem()).toList();
    } on Object catch (_) {
      return [];
    }
  }
}
