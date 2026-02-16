import 'package:mt_audio/src/carplay/mt_carplay_item.dart';

/// Configuration for the CarPlay root template.
///
/// Use the named constructors to create either a list or tab bar root:
///
/// ```dart
/// // List root template
/// MtCarPlayRootConfig.list(title: 'My Music App');
///
/// // Tab bar root template
/// MtCarPlayRootConfig.tabBar(
///   title: 'My Music App',
///   tabBarConfig: MtCarPlayTabBarConfig(tabs: [...]),
/// );
/// ```
class MtCarPlayRootConfig {
  /// Creates a list root template configuration.
  const MtCarPlayRootConfig.list({
    required this.title,
    this.systemIcon = 'music.note.list',
    this.emptyViewTitle = 'No Content',
    this.emptyViewSubtitle = 'Add content to see it here',
  }) : templateType = MtCarPlayRootTemplateType.list,
       tabBarConfig = null;

  /// Creates a tab bar root template configuration.
  const MtCarPlayRootConfig.tabBar({
    required this.title,
    required MtCarPlayTabBarConfig this.tabBarConfig,
    this.systemIcon = 'music.note.list',
    this.emptyViewTitle = 'No Content',
    this.emptyViewSubtitle = 'Add content to see it here',
  }) : templateType = MtCarPlayRootTemplateType.tabBar;

  /// Title shown on the root template.
  final String title;

  /// SF Symbol name for the root template icon.
  final String systemIcon;

  /// Title shown when the content list is empty.
  final String emptyViewTitle;

  /// Subtitle shown when the content list is empty.
  final String emptyViewSubtitle;

  /// Type of root template.
  final MtCarPlayRootTemplateType templateType;

  /// Configuration for tab bar template.
  ///
  /// Only used when [templateType] is [MtCarPlayRootTemplateType.tabBar].
  final MtCarPlayTabBarConfig? tabBarConfig;
}

/// Root template type for CarPlay.
enum MtCarPlayRootTemplateType {
  /// List template with sections.
  list,

  /// Tab bar template with multiple tabs.
  tabBar,
}

/// Configuration for a tab in CarPlay tab bar.
class MtCarPlayTab {
  /// Creates an [MtCarPlayTab].
  const MtCarPlayTab({
    required this.title,
    required this.systemIcon,
    required this.rootId,
  });

  /// Tab display title.
  final String title;

  /// SF Symbol name for the tab icon.
  final String systemIcon;

  /// Root ID to use when browsing this tab's content.
  final String rootId;
}

/// Configuration for CarPlay tab bar template.
class MtCarPlayTabBarConfig {
  /// Creates an [MtCarPlayTabBarConfig].
  const MtCarPlayTabBarConfig({required this.tabs});

  /// List of tabs to display.
  final List<MtCarPlayTab> tabs;
}

/// A section of CarPlay content with an optional header.
///
/// Used to group items in a list template with section headers.
class MtCarPlaySection {
  /// Creates an [MtCarPlaySection].
  const MtCarPlaySection({
    required this.items,
    this.header,
  });

  /// Optional section header text.
  final String? header;

  /// Items in this section.
  final List<MtCarPlayItem> items;
}

/// Abstract delegate for handling CarPlay communication.
///
/// Implement this class to provide your app's CarPlay integration.
/// The delegate handles both configuration (via [rootConfig]) and content
/// browsing/playback.
///
/// Example:
/// ```dart
/// class MyCarPlayDelegate implements MtCarPlayDelegate {
///   MyCarPlayDelegate({required this.player});
///   final MtAudioPlayer player;
///
///   @override
///   MtCarPlayRootConfig get rootConfig => MtCarPlayRootConfig.list(
///     title: 'My Music App',
///   );
///
///   @override
///   Future<List<MtCarPlayItem>> getChildren(String? parentId) async {
///     if (parentId == null) {
///       return [
///         MtCarPlayBrowsableItem(id: 'songs', title: 'Songs'),
///         MtCarPlayBrowsableItem(id: 'albums', title: 'Albums'),
///       ];
///     }
///     // ... return children for parentId
///     return [];
///   }
///
///   @override
///   Future<void> onPlayFromMediaId(String mediaId) async {
///     final track = await getTrack(mediaId);
///     await player.setAudioItem(track);
///     await player.play();
///   }
/// }
/// ```
abstract class MtCarPlayDelegate {
  /// Configuration for the CarPlay root template.
  MtCarPlayRootConfig get rootConfig;

  /// Returns the children of the specified parent ID.
  ///
  /// CarPlay will call this method to browse your media library.
  /// Return a list of [MtCarPlayItem]s representing the children of [parentId].
  ///
  /// Use [MtCarPlayBrowsableItem] for navigable directories (folders, categories).
  /// Use [MtCarPlayPlayableItem] for playable audio items.
  ///
  /// Common parent IDs:
  /// - null: Root level of the library
  /// - Custom IDs: Used for nested browsing (e.g., 'playlists', 'albums')
  Future<List<MtCarPlayItem>> getChildren(String? parentId);

  /// Handles playback request for the specified media ID.
  ///
  /// Called when the user selects a playable item from CarPlay.
  /// Load and start playing the media associated with [mediaId].
  Future<void> onPlayFromMediaId(String mediaId);

  /// Returns sections for the specified parent ID.
  ///
  /// Override this method to provide grouped content with section headers.
  /// By default, this creates a single section from [getChildren] results.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<List<MtCarPlaySection>> getSections(String? parentId) async {
  ///   return [
  ///     MtCarPlaySection(
  ///       header: 'Recently Played',
  ///       items: await getRecentTracks(),
  ///     ),
  ///     MtCarPlaySection(
  ///       header: 'Favorites',
  ///       items: await getFavoriteTracks(),
  ///     ),
  ///   ];
  /// }
  /// ```
  Future<List<MtCarPlaySection>> getSections(String? parentId) async {
    final children = await getChildren(parentId);
    return [MtCarPlaySection(items: children)];
  }

  /// Called when CarPlay connects.
  ///
  /// Override to perform actions when the CarPlay session starts.
  void onConnect() {}

  /// Called when CarPlay disconnects.
  ///
  /// Override to perform cleanup when the CarPlay session ends.
  void onDisconnect() {}
}
