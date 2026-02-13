import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_media_library_item.dart';

/// Abstract delegate for handling Android Auto communication.
///
/// Implement this class to provide your app's Android Auto integration.
/// The delegate handles media library browsing, playback requests, and search.
///
/// Example:
/// ```dart
/// class MyAndroidAutoDelegate implements MtAndroidAutoDelegate {
///   MyAndroidAutoDelegate({required this.player});
///   final MtAudioPlayer player;
///
///   @override
///   Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId) async {
///     if (parentMediaId == null || parentMediaId == 'root') {
///       return [
///         MtBrowsableItem(id: 'playlists', title: 'Playlists'),
///         MtBrowsableItem(id: 'recent', title: 'Recently Played'),
///       ];
///     }
///     // ... return children for parentMediaId
///     return [];
///   }
///
///   @override
///   Future<void> onPlayFromMediaId(String mediaId) async {
///     final track = await getTrack(mediaId);
///     await player.setSource(MtSingleSource(item: track));
///     await player.play();
///   }
///
///   @override
///   Future<List<MtAudioItem>> search(String query) async {
///     return await repository.searchTracks(query);
///   }
/// }
/// ```
abstract class MtAndroidAutoDelegate {
  /// Returns the children of the specified parent media ID.
  ///
  /// Android Auto will call this method to browse your media library.
  /// Return a list of [MtMediaLibraryItem]s representing the children of
  /// [parentMediaId].
  ///
  /// Use [MtBrowsableItem] for navigable directories (folders, categories).
  /// Use [MtPlayableItem] for playable audio items.
  ///
  /// Common parent IDs:
  /// - null or 'root': Root level of the library
  /// - Custom IDs: Used for nested browsing (e.g., 'playlists', 'albums')
  Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId);

  /// Handles playback request for the specified media ID.
  ///
  /// Called when the user selects a playable item from Android Auto.
  /// Load and start playing the media associated with [mediaId].
  Future<void> onPlayFromMediaId(String mediaId);

  /// Handles search requests from Android Auto.
  ///
  /// Return a list of [MtAudioItem]s matching the search [query].
  /// Return an empty list if no results are found.
  Future<List<MtAudioItem>> search(String query);

  /// Called when Android Auto connects.
  ///
  /// Override to perform actions when the Android Auto session starts.
  void onConnect() {}

  /// Called when Android Auto disconnects.
  ///
  /// Override to perform cleanup when the Android Auto session ends.
  void onDisconnect() {}
}
