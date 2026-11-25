import 'package:mt_audio/src/models/mt_media_library_item.dart';

/// Abstract delegate for handling Android Auto communication.
///
/// Implement this class to provide your app's Android Auto integration.
/// The delegate handles media library browsing, playback requests, and search.
///
/// Example:
/// ```dart
/// class MyAndroidAutoDelegate extends MtAndroidAutoDelegate {
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
///     await player.setAudioItem(track);
///     await player.play();
///   }
///
///   @override
///   Future<List<MtMediaLibraryItem>> search(String query) async {
///     final tracks = await repository.searchTracks(query);
///     return [for (final track in tracks) MtPlayableItem(item: track)];
///   }
///
///   @override
///   Future<void> onPlayFromSearch(String query) async {
///     final matches = await repository.searchTracks(query);
///     if (matches.isEmpty) return;
///     await player.setAudioItem(matches.first);
///     await player.play();
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
  /// Return the items matching the search [query]: [MtPlayableItem]s for
  /// tracks and [MtBrowsableItem]s for albums, playlists or other folders.
  /// Android Auto opens a browsable result through [getChildren], like a
  /// folder in the browse tree. Return an empty list if nothing matches.
  Future<List<MtMediaLibraryItem>> search(String query);

  /// Handles a voice request such as "Hey Google, play … on `<app>`".
  ///
  /// [query] is empty when the user asked to play the app without naming
  /// anything — resume or start something sensible. Defaults to a no-op so
  /// existing delegates keep compiling when they `extend` this class.
  Future<void> onPlayFromSearch(String query) async {}

  /// Called when Android Auto connects.
  ///
  /// Override to perform actions when the Android Auto session starts.
  void onConnect() {}

  /// Called when Android Auto disconnects.
  ///
  /// Override to perform cleanup when the Android Auto session ends.
  void onDisconnect() {}
}
