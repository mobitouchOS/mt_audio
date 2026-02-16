import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mt_audio/src/carplay/mt_carplay_handler.dart';
import 'package:mt_audio/src/handler/mt_audio_handler.dart';
import 'package:mt_audio/src/models/mt_audio_error.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_playback_state.dart';
import 'package:mt_audio/src/models/mt_position_state.dart';
import 'package:mt_audio/src/models/mt_queue_state.dart';
import 'package:mt_audio/src/player/mt_audio_player_config.dart';
import 'package:mt_audio/src/session/mt_audio_session_manager.dart';
import 'package:rxdart/rxdart.dart';

/// Main public API for the mt_audio package.
///
/// Provides a simple, streams-based interface for audio playback with
/// background support, notifications, and optional Android Auto integration.
///
/// Example:
/// ```dart
/// final player = await MtAudioPlayer.init(
///   config: MtAudioPlayerConfig(
///     notificationChannelId: 'audio',
///     notificationChannelName: 'Audio Playback',
///   ),
/// );
///
/// // Set audio source
/// await player.setAudioItem(MtAudioItem(
///   id: '1',
///   uri: Uri.parse('https://example.com/audio.mp3'),
///   title: 'My Audio',
/// ));
///
/// // Listen to state
/// player.playbackStateStream.listen((state) {
///   print('Playing: ${state.isPlaying}');
/// });
///
/// // Control playback
/// await player.play();
/// ```
class MtAudioPlayer {
  MtAudioPlayer._({
    required MtAudioHandler handler,
    required MtAudioSessionManager sessionManager,
    MtCarPlayHandler? carPlayHandler,
  }) : _handler = handler,
       _sessionManager = sessionManager,
       _carPlayHandler = carPlayHandler {
    _initStreams();
  }

  /// Initializes the audio player.
  ///
  /// Must be called once before using the player.
  static Future<MtAudioPlayer> init({
    required MtAudioPlayerConfig config,
  }) async {
    // Create handler - includes Android Auto mixin; the AA mixin methods
    // are harmless on iOS (never called by the system) and return safe defaults
    // when unbound.
    final handler = MtAudioHandler(
      ffRewindInterval: config.ffRewindInterval,
    );

    // Initialize audio service
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: config.notificationChannelId,
        androidNotificationChannelName: config.notificationChannelName,
        androidNotificationIcon:
            config.notificationIcon ?? 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        preloadArtwork: true,
        androidNotificationOngoing: true,
        fastForwardInterval: config.ffRewindInterval,
        rewindInterval: config.ffRewindInterval,
      ),
    );

    // Initialize audio session
    final sessionManager = MtAudioSessionManager(
      audioHandler: handler,
      handleInterruptions: config.handleInterruptions,
    );
    await sessionManager.init();

    // Create player instance
    final player = MtAudioPlayer._(
      handler: handler,
      sessionManager: sessionManager,
    );

    // Bind Android Auto delegate if factory provided (Android only)
    if (config.androidAutoDelegateFactory != null && Platform.isAndroid) {
      final delegate = config.androidAutoDelegateFactory!(player);
      handler.bindDelegate(delegate);
    }

    // Initialize CarPlay handler if factory provided (iOS only)
    if (config.carPlayDelegateFactory != null && Platform.isIOS) {
      final carPlayDelegate = config.carPlayDelegateFactory!(player);
      final carPlayHandler = MtCarPlayHandler(
        delegate: carPlayDelegate,
        playerStreams: (
          playbackState: player.playbackStateStream,
          positionState: player.positionStateStream,
          currentItem: player.currentItemStream,
        ),
      );
      await carPlayHandler.init();
      player._carPlayHandler = carPlayHandler;
    }

    return player;
  }

  final MtAudioHandler _handler;
  final MtAudioSessionManager _sessionManager;
  MtCarPlayHandler? _carPlayHandler;

  // Stream subscriptions
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  // Stream controllers
  late final BehaviorSubject<MtPlaybackState> _playbackStateSubject;
  late final BehaviorSubject<MtPositionState> _positionStateSubject;
  late final BehaviorSubject<MtQueueState> _queueStateSubject;
  late final BehaviorSubject<MtAudioItem?> _currentItemSubject;

  void _initStreams() {
    final playbackUiStateStream = _handler.playbackState
        .map(
          (state) => (
            processingState: state.processingState,
            playing: state.playing,
            repeatMode: state.repeatMode,
            shuffleMode: state.shuffleMode,
            speed: state.speed,
          ),
        )
        .distinct();

    final playbackQueueStateStream = _handler.playbackState
        .map(
          (state) => (
            queueIndex: state.queueIndex,
            shuffleMode: state.shuffleMode,
            repeatMode: state.repeatMode,
          ),
        )
        .distinct();

    // Playback state stream
    _playbackStateSubject = BehaviorSubject<MtPlaybackState>.seeded(
      const MtPlaybackState(status: MtPlaybackStatus.idle),
    );

    _subscriptions.add(
      Rx.combineLatest2(
        playbackUiStateStream,
        _handler.volumeStream,
        (playbackState, volume) => MtPlaybackState(
          status: _mapAudioProcessingState(
            playbackState.processingState,
            playbackState.playing,
          ),
          repeatMode: _mapRepeatMode(playbackState.repeatMode),
          shuffleEnabled:
              playbackState.shuffleMode == AudioServiceShuffleMode.all,
          volume: volume,
          speed: playbackState.speed,
        ),
      ).distinct().listen(_playbackStateSubject.add),
    );

    // Position state stream
    _positionStateSubject = BehaviorSubject<MtPositionState>.seeded(
      const MtPositionState.empty(),
    );

    _subscriptions.add(
      Rx.combineLatest3<Duration, Duration, Duration?, MtPositionState>(
        _handler.positionStream,
        _handler.playbackState
            .map((state) => state.bufferedPosition)
            .distinct(),
        _handler.durationStream.distinct(),
        (position, bufferedPosition, duration) => MtPositionState(
          position: position,
          bufferedPosition: bufferedPosition,
          duration: duration,
        ),
      ).listen(_positionStateSubject.add),
    );

    // Queue state stream
    _queueStateSubject = BehaviorSubject<MtQueueState>.seeded(
      const MtQueueState.empty(),
    );

    _subscriptions.add(
      Rx.combineLatest3(
            _handler.queue,
            playbackQueueStateStream,
            _handler.shuffleIndicesStream.whereType<List<int>>(),
            (queue, playbackState, shuffleIndices) => MtQueueState(
              queue: queue.map(MtAudioItem.fromMediaItem).toList(),
              queueIndex: playbackState.queueIndex,
              shuffleIndices:
                  playbackState.shuffleMode == AudioServiceShuffleMode.all
                  ? shuffleIndices
                  : null,
              repeatMode: _mapRepeatMode(playbackState.repeatMode),
            ),
          )
          .where(
            (state) =>
                state.shuffleIndices == null ||
                state.queue.length == state.shuffleIndices!.length,
          )
          .listen((state) {
            _queueStateSubject.add(state);
          }),
    );

    // Current item stream
    _currentItemSubject = BehaviorSubject<MtAudioItem?>.seeded(null);

    _subscriptions.add(
      _handler.mediaItem.listen((mediaItem) {
        _currentItemSubject.add(
          mediaItem != null ? MtAudioItem.fromMediaItem(mediaItem) : null,
        );
      }),
    );
  }

  MtPlaybackStatus _mapAudioProcessingState(
    AudioProcessingState state,
    bool isPlaying,
  ) {
    switch (state) {
      case AudioProcessingState.idle:
        return MtPlaybackStatus.idle;
      case AudioProcessingState.loading:
        return MtPlaybackStatus.loading;
      case AudioProcessingState.buffering:
        return MtPlaybackStatus.buffering;
      case AudioProcessingState.ready:
        return isPlaying ? MtPlaybackStatus.playing : MtPlaybackStatus.paused;
      case AudioProcessingState.completed:
        return MtPlaybackStatus.completed;
      case AudioProcessingState.error:
        return MtPlaybackStatus.error;
    }
  }

  MtRepeatMode _mapRepeatMode(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        return MtRepeatMode.off;
      case AudioServiceRepeatMode.one:
        return MtRepeatMode.one;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return MtRepeatMode.all;
    }
  }

  //* Public streams

  /// Stream of playback state changes.
  Stream<MtPlaybackState> get playbackStateStream =>
      _playbackStateSubject.stream.distinct();

  /// Stream of position state changes.
  Stream<MtPositionState> get positionStateStream =>
      _positionStateSubject.stream.distinct();

  /// Stream of queue state changes.
  Stream<MtQueueState> get queueStateStream =>
      _queueStateSubject.stream.distinct();

  /// Stream of current item changes.
  Stream<MtAudioItem?> get currentItemStream =>
      _currentItemSubject.stream.distinct();

  /// Stream of ICY metadata changes (for live streams).
  Stream<IcyMetadata?> get icyMetadataStream => _handler.icyMetadataStream;

  /// Stream of errors.
  Stream<MtAudioError?> get errorStream => _handler.errorStream;

  //* CarPlay

  /// CarPlay handler for Apple CarPlay integration.
  ///
  /// Returns null if CarPlay was not configured during initialization.
  MtCarPlayHandler? get carPlay => _carPlayHandler;

  //* Synchronous getters

  /// Current playback state.
  MtPlaybackState get currentPlaybackState => _playbackStateSubject.value;

  /// Current position state.
  MtPositionState get currentPositionState => _positionStateSubject.value;

  /// Current queue state.
  MtQueueState get currentQueueState => _queueStateSubject.value;

  /// Currently playing item (null if none).
  MtAudioItem? get currentItem => _currentItemSubject.value;

  //* Playback controls

  /// Starts or resumes playback.
  Future<void> play() => _handler.play();

  /// Pauses playback.
  Future<void> pause() => _handler.pause();

  /// Stops playback and releases resources.
  Future<void> stop() => _handler.stop();

  /// Seeks to the specified position.
  Future<void> seekTo(Duration position) => _handler.seek(position);

  /// Seeks forward by the configured interval.
  Future<void> seekForward() => _handler.fastForward();

  /// Seeks backward by the configured interval.
  Future<void> seekBackward() => _handler.rewind();

  //* Queue management

  /// Sets a single audio item as the source and replaces the current queue.
  Future<void> setAudioItem(MtAudioItem item) => _handler.setItem(item);

  /// Sets a playlist as the source and replaces the current queue.
  Future<void> setPlaylist(List<MtAudioItem> items, {int initialIndex = 0}) =>
      _handler.setPlaylist(items, initialIndex: initialIndex);

  /// Adds an item to the end of the queue.
  Future<void> addToQueue(MtAudioItem item) => _handler.addAudioItem(item);

  /// Inserts an item at the specified index in the queue.
  Future<void> insertInQueue(int index, MtAudioItem item) =>
      _handler.insertAudioItem(index, item);

  /// Removes an item from the queue at the specified index.
  Future<void> removeFromQueue(int index) => _handler.removeAudioItemAt(index);

  /// Reorders queue items.
  Future<void> reorderQueue(int oldIndex, int newIndex) =>
      _handler.reorderQueue(oldIndex, newIndex);

  /// Skips to the item at the specified index.
  Future<void> skipToIndex(int index) => _handler.skipToQueueItem(index);

  /// Skips to the next item in the queue.
  Future<void> skipToNext() => _handler.skipToNext();

  /// Skips to the previous item in the queue.
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  /// Clears the entire queue.
  Future<void> clearQueue() => _handler.clearQueue();

  //* Speed control

  /// Sets the playback speed.
  ///
  /// Typical values are between 0.5 and 2.0.
  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);

  //* Playback modes

  /// Sets the repeat mode.
  Future<void> setRepeatMode(MtRepeatMode mode) {
    final audioServiceMode = switch (mode) {
      MtRepeatMode.off => AudioServiceRepeatMode.none,
      MtRepeatMode.one => AudioServiceRepeatMode.one,
      MtRepeatMode.all => AudioServiceRepeatMode.all,
    };

    return _handler.setRepeatMode(audioServiceMode);
  }

  /// Sets whether shuffle is enabled.
  Future<void> setShuffleMode(bool enabled) {
    final audioServiceMode = enabled
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;

    return _handler.setShuffleMode(audioServiceMode);
  }

  //* Volume control

  /// Sets the player volume (0.0 to 1.0).
  Future<void> setVolume(double volume) => _handler.setPlayerVolume(volume);

  //* Lifecycle

  /// Disposes of the player and releases all resources.
  ///
  /// The player cannot be used after calling this method.
  Future<void> dispose() async {
    await _carPlayHandler?.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _playbackStateSubject.close();
    await _positionStateSubject.close();
    await _queueStateSubject.close();
    await _currentItemSubject.close();
    await _sessionManager.dispose();
    await _handler.dispose();
  }
}
