import 'package:audio_service/audio_service.dart';

import 'package:mt_audio/src/android_auto/mt_android_auto_delegate.dart';

/// Mixin that adds Android Auto support to [BaseAudioHandler].
///
/// This mixin delegates Android Auto browsing and playback requests
/// to an [MtAndroidAutoDelegate].
mixin MtAndroidAutoHandler on BaseAudioHandler {
  /// The Android Auto delegate that supplies content.
  MtAndroidAutoDelegate get androidAutoDelegate;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    try {
      final items = await androidAutoDelegate.getChildren(parentMediaId);
      return items.map((item) => item.toMediaItem()).toList();
    } on Exception catch (_) {
      // Return empty list on error to avoid breaking Android Auto UI
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
    } on Exception catch (_) {
      // Log error but don't throw to avoid breaking Android Auto
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
    } on Exception catch (_) {
      // Return empty list on error
      return [];
    }
  }
}
