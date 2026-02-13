import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mt_audio/src/carplay/mt_carplay_delegate.dart';
import 'package:mt_audio/src/carplay/mt_carplay_item.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_playback_state.dart';
import 'package:mt_audio/src/models/mt_position_state.dart';
import 'package:mt_carplay/mt_carplay.dart';
import 'package:rxdart/rxdart.dart';

/// Function type for accessing player streams.
///
/// Used internally to break circular dependency between handler and player.
typedef MtCarPlayPlayerStreams = ({
  Stream<MtPlaybackState> playbackState,
  Stream<MtPositionState> positionState,
  Stream<MtAudioItem?> currentItem,
});

/// Manages CarPlay integration for audio apps.
///
/// Handles connection lifecycle, template updates, navigation stack,
/// and automatic playback state synchronization with the player.
///
/// Example:
/// ```dart
/// final handler = MtCarPlayHandler(
///   delegate: myCarPlayDelegate,
///   playerStreams: (
///     playbackState: player.playbackStateStream,
///     positionState: player.positionStateStream,
///     currentItem: player.currentItemStream,
///   ),
/// );
/// await handler.init();
/// ```
class MtCarPlayHandler {
  /// Creates a CarPlay handler.
  ///
  /// [delegate] provides content, configuration, and handles callbacks.
  /// [playerStreams] provides streams for automatic state synchronization.
  MtCarPlayHandler({
    required MtCarPlayDelegate delegate,
    required MtCarPlayPlayerStreams playerStreams,
  }) : _delegate = delegate,
       _playerStreams = playerStreams;

  final MtCarPlayDelegate _delegate;
  final MtCarPlayPlayerStreams _playerStreams;

  FlutterCarplay? _carplay;
  bool _isConnected = false;

  String? _currentPlayingId;
  bool _isPlaying = false;
  double? _currentProgress;

  final _connectionController = StreamController<bool>.broadcast();
  final Map<String, List<CPListItem>> _rootItemRegistry = {};
  final Map<String, List<CPListItem>> _pushedItemRegistry = {};

  StreamSubscription<void>? _combinedStateSubscription;

  /// Whether CarPlay is currently connected.
  bool get isConnected => _isConnected;

  /// Stream of connection status changes.
  Stream<bool> get connectionStream => _connectionController.stream;

  MtCarPlayRootConfig get _rootConfig => _delegate.rootConfig;

  /// Gets all registered CPListItem instances for a given audio item ID.
  ///
  /// Returns items from both root and pushed registries.
  List<CPListItem> _getRegisteredItems(String? id) {
    if (id == null) return [];
    return [
      ...?_rootItemRegistry[id],
      ...?_pushedItemRegistry[id],
    ];
  }

  /// Initializes the CarPlay handler.
  ///
  /// Must be called once before CarPlay can be used.
  Future<void> init() async {
    _carplay = FlutterCarplay();
    _carplay!.addListenerOnConnectionChange(_onConnectionChange);

    _subscribeToPlayerStreams();

    // Check if CarPlay is already connected (may connect before Flutter is ready)
    if (FlutterCarplay.connectionStatus == 'connected') {
      _isConnected = true;
      _delegate.onConnect();
    }

    await _setupRootTemplate();
  }

  void _subscribeToPlayerStreams() => _combinedStateSubscription =
      Rx.combineLatest3<
            MtPlaybackState,
            MtPositionState,
            MtAudioItem?,
            (MtPlaybackState, MtPositionState, MtAudioItem?)
          >(
            _playerStreams.playbackState,
            _playerStreams.positionState,
            _playerStreams.currentItem,
            (playbackState, positionState, currentItem) {
              return (playbackState, positionState, currentItem);
            },
          )
          .throttleTime(
            const Duration(milliseconds: 150),
            leading: true,
            trailing: true,
          )
          .listen(
            (event) => _onPlayerEvent(event.$1, event.$2, event.$3),
          );

  void _onPlayerEvent(
    MtPlaybackState playbackState,
    MtPositionState positionState,
    MtAudioItem? currentItem,
  ) {
    if (!_isConnected) return;

    // Handle track change
    if (currentItem?.id != _currentPlayingId) {
      final oldCpItems = _getRegisteredItems(_currentPlayingId);

      for (final cpItem in oldCpItems) {
        _updateCPListItem(cpItem: cpItem, isPlaying: false, progress: 0);
      }

      _currentPlayingId = currentItem?.id;
    }

    // Update current item's playback state
    final cpItems = _getRegisteredItems(currentItem?.id);

    if (cpItems.isEmpty) return;

    for (final cpItem in cpItems) {
      _updateCPListItem(
        cpItem: cpItem,
        isPlaying: playbackState.isPlaying,
        progress: positionState.progress,
      );
    }

    _isPlaying = playbackState.isPlaying;
    _currentProgress = positionState.progress;
  }

  /// Safely updates a [CPListItem]'s playback state.
  ///
  /// Wrapped in try-catch to handle a bug in mt_carplay where
  /// `updateCPListItem` casts `currentRootTemplate` to `CPListTemplate`
  /// even when the root is a `CPTabBarTemplate` (for items on pushed
  /// templates).
  void _updateCPListItem({
    required CPListItem cpItem,
    required bool isPlaying,
    required double progress,
  }) {
    try {
      cpItem
        ..setIsPlaying(isPlaying)
        ..setPlaybackProgress(progress);
    } on Exception catch (e) {
      debugPrint('CarPlay: failed to update CPListItem: $e');
    }
  }

  void _onConnectionChange(ConnectionStatusTypes status) {
    final wasConnected = _isConnected;
    _isConnected = status == ConnectionStatusTypes.connected;
    _connectionController.add(_isConnected);

    if (_isConnected && !wasConnected) {
      _delegate.onConnect();
      unawaited(_carplay?.forceUpdateRootTemplate());
    } else if (!_isConnected && wasConnected) {
      _delegate.onDisconnect();
    }
  }

  Future<void> _setupRootTemplate() async {
    _rootItemRegistry.clear();
    _pushedItemRegistry.clear();

    switch (_rootConfig.templateType) {
      case MtCarPlayRootTemplateType.list:
        await _setListRootTemplate();
      case MtCarPlayRootTemplateType.tabBar:
        await _setTabBarRootTemplate();
    }
  }

  Future<void> _setListRootTemplate() async {
    final sections = await _delegate.getSections(null);
    final cpSections = _buildCPSections(sections, null, isRoot: true);

    final template = CPListTemplate(
      sections: cpSections,
      title: _rootConfig.title,
      systemIcon: _rootConfig.systemIcon,
      emptyViewTitleVariants: [_rootConfig.emptyViewTitle],
      emptyViewSubtitleVariants: [_rootConfig.emptyViewSubtitle],
    );

    await FlutterCarplay.setRootTemplate(
      rootTemplate: template,
    );
  }

  Future<void> _setTabBarRootTemplate() async {
    final tabConfig = _rootConfig.tabBarConfig;
    if (tabConfig == null || tabConfig.tabs.isEmpty) {
      // Fall back to list template if no tabs configured
      await _setListRootTemplate();
      return;
    }

    final templates = <CPListTemplate>[];

    for (final tab in tabConfig.tabs) {
      final sections = await _delegate.getSections(tab.rootId);
      final cpSections = _buildCPSections(sections, tab.rootId, isRoot: true);

      templates.add(
        CPListTemplate(
          sections: cpSections,
          title: tab.title,
          systemIcon: tab.systemIcon,
          emptyViewTitleVariants: [_rootConfig.emptyViewTitle],
          emptyViewSubtitleVariants: [_rootConfig.emptyViewSubtitle],
        ),
      );
    }

    final tabBar = CPTabBarTemplate(templates: templates);

    await FlutterCarplay.setRootTemplate(
      rootTemplate: tabBar,
    );
  }

  List<CPListSection> _buildCPSections(
    List<MtCarPlaySection> sections,
    String? parentId, {
    bool isRoot = false,
  }) {
    return sections.map((section) {
      final items = section.items.map((item) {
        return _buildCPItem(item, parentId, isRoot: isRoot);
      }).toList();

      return CPListSection(
        header: section.header,
        items: items,
      );
    }).toList();
  }

  CPListItem _buildCPItem(
    MtCarPlayItem item,
    String? parentId, {
    bool isRoot = false,
  }) {
    final isCurrentItem = switch (item) {
      MtCarPlayPlayableItem(item: final audioItem) =>
        audioItem.id == _currentPlayingId,
      MtCarPlayBrowsableItem() => false,
    };

    final cpItem = item.toCPItem(
      onSelect: (itemId) => _onItemSelected(item, itemId, parentId),
      isPlaying: isCurrentItem && _isPlaying,
      playbackProgress: isCurrentItem ? _currentProgress : null,
    );

    if (item is MtCarPlayPlayableItem) {
      final registry = isRoot ? _rootItemRegistry : _pushedItemRegistry;
      (registry[item.item.id] ??= []).add(cpItem);
    }

    return cpItem;
  }

  Future<void> _onItemSelected(
    MtCarPlayItem item,
    String itemId,
    String? parentId,
  ) async {
    switch (item) {
      case MtCarPlayBrowsableItem():
        await _navigateToItem(item);
      case MtCarPlayPlayableItem():
        await showNowPlaying();
        unawaited(
          _delegate.onPlayFromMediaId(itemId).then((_) {
            debugPrint('Played playable item: $itemId');
          }),
        );
    }
  }

  Future<void> _navigateToItem(MtCarPlayBrowsableItem item) async {
    _pushedItemRegistry.clear();

    final sections = await _delegate.getSections(item.id);
    final cpSections = _buildCPSections(sections, item.id);

    switch (item.templateType) {
      case MtCarPlayTemplateType.list:
        final listTemplate = CPListTemplate(
          sections: cpSections,
          title: item.title,
          systemIcon: _rootConfig.systemIcon,
          emptyViewTitleVariants: [_rootConfig.emptyViewTitle],
          emptyViewSubtitleVariants: [_rootConfig.emptyViewSubtitle],
        );

        await FlutterCarplay.push(template: listTemplate);

      case MtCarPlayTemplateType.grid:
        // Build grid buttons from items
        final children = await _delegate.getChildren(item.id);
        final gridButtons = children.map((child) {
          return child.toCPButton(
            onSelect: (childId) => _onItemSelected(child, childId, item.id),
          );
        }).toList();

        final gridTemplate = CPGridTemplate(
          title: item.title,
          buttons: gridButtons,
        );

        await FlutterCarplay.push(template: gridTemplate);
    }
  }

  /// Refreshes the CarPlay content.
  ///
  /// Call this when the underlying data changes.
  Future<void> refresh() async {
    await _setupRootTemplate();
  }

  /// Pops the top template from the navigation stack.
  ///
  /// Returns false if already at root.
  Future<bool> pop() async {
    return FlutterCarplay.pop();
  }

  /// Pops to the root template.
  Future<void> popToRoot() async {
    await FlutterCarplay.popToRoot();
  }

  /// Shows the Now Playing screen.
  ///
  /// The Now Playing template displays information from the app's
  /// active media session (automatically populated by audio_service).
  Future<void> showNowPlaying() async {
    await FlutterCarplay.showSharedNowPlaying();
  }

  /// Disposes resources.
  Future<void> dispose() async {
    _carplay?.removeListenerOnConnectionChange();
    await _combinedStateSubscription?.cancel();
    await _connectionController.close();
  }
}
