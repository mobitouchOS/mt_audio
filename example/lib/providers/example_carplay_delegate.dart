import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/sample_data/sample_data.dart';

/// CarPlay delegate for the mt_audio example app.
///
/// Demonstrates all CarPlay features:
/// - Tab bar navigation (Library, Playlists, Browse)
/// - List templates with sections
/// - Grid templates for visual browsing
class ExampleCarPlayDelegate implements MtCarPlayDelegate {
  /// Creates an [ExampleCarPlayDelegate].
  ExampleCarPlayDelegate({required this.player});

  /// The audio player instance.
  final MtAudioPlayer player;

  // Tab root IDs
  static const libraryId = 'library';
  static const playlistsId = 'playlists';
  static const browseId = 'browse';

  // Playlist IDs
  static const allSongsId = 'playlist-all';
  static const favoritesId = 'playlist-favorites';
  static const recentId = 'playlist-recent';

  // Browse category IDs
  static const electronicId = 'category-electronic';
  static const chillId = 'category-chill';
  static const liveId = 'category-live';

  /// Favorite tracks (first 3 songs).
  List<MtAudioItem> get _favoriteTracks => sampleTracks.take(3).toList();

  /// Recently added tracks (last 2 songs).
  List<MtAudioItem> get _recentTracks => sampleTracks.reversed.take(2).toList();

  /// Electronic tracks (songs 1, 3, 5).
  List<MtAudioItem> get _electronicTracks => [
    sampleTracks[0],
    sampleTracks[2],
    sampleTracks[4],
  ];

  /// Chill tracks (songs 2, 4).
  List<MtAudioItem> get _chillTracks => [sampleTracks[1], sampleTracks[3]];

  @override
  MtCarPlayRootConfig get rootConfig => const MtCarPlayRootConfig.tabBar(
    title: 'mt_audio Example',
    tabBarConfig: MtCarPlayTabBarConfig(
      tabs: [
        MtCarPlayTab(
          title: 'Library',
          systemIcon: 'music.note.house',
          rootId: libraryId,
        ),
        MtCarPlayTab(
          title: 'Playlists',
          systemIcon: 'list.bullet',
          rootId: playlistsId,
        ),
        MtCarPlayTab(
          title: 'Browse',
          systemIcon: 'square.grid.2x2',
          rootId: browseId,
        ),
      ],
    ),
  );

  @override
  Future<List<MtCarPlayItem>> getChildren(String? parentId) async {
    switch (parentId) {
      // Library tab - handled by getSections for sectioned content
      case libraryId:
        return [
          ...sampleTracks.map((t) => MtCarPlayPlayableItem(item: t)),
          ...liveStreams.map((t) => MtCarPlayPlayableItem(item: t)),
        ];

      // Playlists tab - show playlist folders
      case playlistsId:
        return [
          MtCarPlayBrowsableItem(
            id: allSongsId,
            title: 'All Songs',
            subtitle: '${sampleTracks.length} tracks',
            imageUri: sampleTracks.first.artworkUri,
          ),
          MtCarPlayBrowsableItem(
            id: favoritesId,
            title: 'Favorites',
            subtitle: '${_favoriteTracks.length} tracks',
            imageUri: _favoriteTracks.first.artworkUri,
          ),
          MtCarPlayBrowsableItem(
            id: recentId,
            title: 'Recently Added',
            subtitle: '${_recentTracks.length} tracks',
            imageUri: _recentTracks.first.artworkUri,
          ),
        ];

      // Playlist contents
      case allSongsId:
        return sampleTracks.map((t) => MtCarPlayPlayableItem(item: t)).toList();
      case favoritesId:
        return _favoriteTracks
            .map((t) => MtCarPlayPlayableItem(item: t))
            .toList();
      case recentId:
        return _recentTracks
            .map((t) => MtCarPlayPlayableItem(item: t))
            .toList();

      // Browse tab - show category grid
      case browseId:
        return [
          MtCarPlayBrowsableItem(
            id: electronicId,
            title: 'Electronic',
            subtitle: '${_electronicTracks.length} tracks',
            imageUri: _electronicTracks.first.artworkUri,
            templateType: MtCarPlayTemplateType.grid,
          ),
          MtCarPlayBrowsableItem(
            id: chillId,
            title: 'Chill',
            subtitle: '${_chillTracks.length} tracks',
            imageUri: _chillTracks.first.artworkUri,
            templateType: MtCarPlayTemplateType.grid,
          ),
          MtCarPlayBrowsableItem(
            id: liveId,
            title: 'Live Radio',
            subtitle: '${liveStreams.length} stations',
            imageUri: liveStreams.first.artworkUri,
            templateType: MtCarPlayTemplateType.grid,
          ),
        ];

      // Browse category contents
      case electronicId:
        return _electronicTracks
            .map((t) => MtCarPlayPlayableItem(item: t))
            .toList();
      case chillId:
        return _chillTracks.map((t) => MtCarPlayPlayableItem(item: t)).toList();
      case liveId:
        return liveStreams.map((t) => MtCarPlayPlayableItem(item: t)).toList();
      default:
        return [];
    }
  }

  @override
  Future<List<MtCarPlaySection>> getSections(String? parentId) async {
    // Library tab uses sections for grouped content
    if (parentId == libraryId) {
      return [
        MtCarPlaySection(
          header: 'Songs',
          items: sampleTracks
              .map((t) => MtCarPlayPlayableItem(item: t))
              .toList(),
        ),
        MtCarPlaySection(
          header: 'Live Radio',
          items: liveStreams
              .map((t) => MtCarPlayPlayableItem(item: t))
              .toList(),
        ),
      ];
    }

    // Default: single section from getChildren
    final children = await getChildren(parentId);
    return [MtCarPlaySection(items: children)];
  }

  @override
  Future<void> onPlayFromMediaId(String mediaId) async {
    // Check if it's a queue item (skip to index)
    final queue = player.currentQueueState.queue;
    final queueIndex = queue.indexWhere((item) => item.id == mediaId);
    if (queueIndex >= 0 && queue.isNotEmpty) {
      await player.skipToIndex(queueIndex);
      await player.play();
      return;
    }

    // Find the item in our sample data
    final allItems = [...sampleTracks, ...liveStreams];
    final item = allItems.firstWhere(
      (i) => i.id == mediaId,
      orElse: () => sampleTracks.first,
    );

    // Determine the playlist context based on the item
    final playlist = _getPlaylistForItem(mediaId);
    if (playlist != null && playlist.length > 1) {
      // Queue playback for playlist items
      final initialIndex = playlist.indexWhere((i) => i.id == mediaId);
      await player.setPlaylist(
        playlist,
        initialIndex: initialIndex >= 0 ? initialIndex : 0,
      );
    } else {
      // Single item playback
      await player.setAudioItem(item);
    }

    await player.play();
  }

  /// Returns the playlist containing the given media ID, if any.
  List<MtAudioItem>? _getPlaylistForItem(String mediaId) {
    // Check each playlist
    if (sampleTracks.any((t) => t.id == mediaId)) {
      return sampleTracks;
    }
    if (_favoriteTracks.any((t) => t.id == mediaId)) {
      return _favoriteTracks;
    }
    if (_recentTracks.any((t) => t.id == mediaId)) {
      return _recentTracks;
    }
    if (_electronicTracks.any((t) => t.id == mediaId)) {
      return _electronicTracks;
    }
    if (_chillTracks.any((t) => t.id == mediaId)) {
      return _chillTracks;
    }
    if (liveStreams.any((t) => t.id == mediaId)) {
      // Live streams don't queue, play single
      return null;
    }
    return null;
  }

  @override
  void onConnect() {}

  @override
  void onDisconnect() {}
}
