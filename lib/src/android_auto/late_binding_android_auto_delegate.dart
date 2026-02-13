import 'package:mt_audio/src/android_auto/mt_android_auto_delegate.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_media_library_item.dart';

/// Internal delegate that allows late binding of the actual implementation.
///
/// This is used internally by [MtAudioPlayer.init()] to break the circular
/// dependency between the audio handler (created first) and the delegate
/// (created after the player exists).
///
/// This class is NOT part of the public API.
class LateBindingAndroidAutoDelegate implements MtAndroidAutoDelegate {
  MtAndroidAutoDelegate? _delegate;

  /// Whether the delegate has been bound.
  bool get isBound => _delegate != null;

  /// Binds the actual delegate implementation.
  ///
  /// Must be called before any browsing or playback requests occur.
  void bind(MtAndroidAutoDelegate delegate) {
    _delegate = delegate;
  }

  @override
  Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId) {
    if (_delegate == null) return Future.value([]);
    return _delegate!.getChildren(parentMediaId);
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) {
    if (_delegate == null) return Future.value();
    return _delegate!.onPlayFromMediaId(mediaId);
  }

  @override
  Future<List<MtAudioItem>> search(String query) {
    if (_delegate == null) return Future.value([]);
    return _delegate!.search(query);
  }

  @override
  void onConnect() {
    _delegate?.onConnect();
  }

  @override
  void onDisconnect() {
    _delegate?.onDisconnect();
  }
}
