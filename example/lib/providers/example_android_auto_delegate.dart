import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/sample_data/sample_data.dart';

/// Example implementation of [MtAndroidAutoDelegate] for Android Auto.
///
/// Provides a browsable media hierarchy with two categories:
/// - Songs: Sample MP3 tracks
/// - Live Radio: Live streaming stations
class ExampleAndroidAutoDelegate extends MtAndroidAutoDelegate {
  /// Creates an [ExampleAndroidAutoDelegate].
  ExampleAndroidAutoDelegate({required this.player});

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Root media ID for the library.
  static const rootId = 'root';

  /// Media ID for the Songs category.
  static const songsId = 'songs';

  /// Media ID for the Live Radio category.
  static const liveRadioId = 'live';

  /// Flip to see Android Auto's error surface on the Desktop Head Unit.
  static bool showPremiumError = false;

  @override
  Future<List<MtMediaLibraryItem>> getChildren(String? parentMediaId) async {
    // Root level - return categories
    if (parentMediaId == null || parentMediaId == rootId) {
      if (showPremiumError) {
        player.setAndroidAutoError(
          const MtAndroidAutoError(
            code: MtAndroidAutoErrorCode.premiumAccountRequired,
            message: 'Available with Premium. Details in the phone app.',
          ),
        );
        return const [];
      }
      player.setAndroidAutoError(null);

      return const [
        MtBrowsableItem(id: songsId, title: 'Songs'),
        MtBrowsableItem(id: liveRadioId, title: 'Live Radio'),
      ];
    }

    // Songs category
    if (parentMediaId == songsId) {
      return sampleTracks.map((t) => MtPlayableItem(item: t)).toList();
    }

    // Live Radio category
    if (parentMediaId == liveRadioId) {
      return liveStreams.map((t) => MtPlayableItem(item: t)).toList();
    }

    return [];
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {
    final item = allSampleItems.firstWhere(
      (i) => i.id == mediaId,
      orElse: () => throw ArgumentError('Unknown media ID: $mediaId'),
    );
    await player.setAudioItem(item);
    await player.play();
  }

  @override
  Future<List<MtAudioItem>> search(String query) async {
    final lowerQuery = query.toLowerCase();
    return allSampleItems
        .where(
          (i) =>
              i.title.toLowerCase().contains(lowerQuery) ||
              (i.artist?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  @override
  Future<void> onPlayFromSearch(String query) async {
    final matches = query.isEmpty ? sampleTracks : await search(query);
    if (matches.isEmpty) return;
    await player.setPlaylist(matches);
    await player.play();
  }

  @override
  void onConnect() {}

  @override
  void onDisconnect() {}
}
