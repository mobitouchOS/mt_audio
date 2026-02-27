import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio/src/android_auto/late_binding_android_auto_delegate.dart';
import 'package:mt_audio/src/android_auto/mt_android_auto_handler.dart';
import 'package:mt_audio/src/utils/mt_asset_resolver.dart';
import 'package:rxdart/rxdart.dart';

/// Internal audio handler that manages audio playback.
///
/// This class bridges just_audio and audio_service, handling all playback
/// operations and state management.
class MtAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, MtAndroidAutoHandler {
  /// Creates an [MtAudioHandler].
  MtAudioHandler({
    required MtAssetResolver assetResolver,
    Duration ffRewindInterval = const Duration(seconds: 10),
  }) : _assetResolver = assetResolver,
       _ffRewindInterval = ffRewindInterval,
       _androidAutoDelegate = LateBindingAndroidAutoDelegate() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final MtAssetResolver _assetResolver;

  /// Fast-forward and rewind interval
  final Duration _ffRewindInterval;

  final LateBindingAndroidAutoDelegate _androidAutoDelegate;

  /// Whether queue synchronization is currently suppressed to avoid feedback loops
  /// (e.g. flickering during reorder)
  bool _suppressQueueSync = false;

  final _errorSubject = BehaviorSubject<MtAudioError?>.seeded(null);
  final _volumeSubject = BehaviorSubject<double>.seeded(1);

  /// Allows for smoother seek bar updates by emitting optimistic position updates immediately on seek.
  /// Note that this is NOT a 1:1 replacement for local seekbar state management, as it handles all other controls too.
  final _optimisticPositionSubject = BehaviorSubject<Duration?>.seeded(null);

  Duration? _optimisticPosition;
  Timer? _optimisticPositionResetTimer;

  /// Stream of position updates.
  Stream<Duration> get positionStream =>
      Rx.combineLatest2<Duration, Duration?, Duration>(
        _player.positionStream.startWith(_player.position),
        _optimisticPositionSubject.stream,
        (playerPosition, optimisticPosition) =>
            optimisticPosition ?? playerPosition,
      ).distinct();

  /// Stream of duration updates.
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of ICY metadata updates (for live streams).
  Stream<IcyMetadata?> get icyMetadataStream => _player.icyMetadataStream;

  /// Stream of errors.
  Stream<MtAudioError?> get errorStream => _errorSubject.stream.distinct();

  /// Stream of shuffle indices.
  Stream<List<int>> get shuffleIndicesStream => _player.shuffleIndicesStream;

  /// Stream of volume changes.
  Stream<double> get volumeStream => _volumeSubject.stream.distinct();

  void _init() {
    // Bridge player state to audio_service playback state
    _player.playbackEventStream.listen(_broadcastState);
    _player.positionStream.listen(_maybeClearOptimisticPosition);

    // Forward playback errors to error subject
    _player.errorStream.listen((error) {
      _errorSubject.add(
        MtAudioError(
          code: MtAudioErrorCode.unknown,
          message: error.message ?? 'Playback error',
          details: error.toString(),
        ),
      );
    });

    // Initialize queue from player sequence
    _player.sequenceStateStream.listen((sequenceState) {
      if (_suppressQueueSync) return;
      _emitQueue(sequenceState.effectiveSequence);
    });

    // Update current media item
    Rx.combineLatest4<int?, List<MediaItem>, bool, List<int>?, MediaItem?>(
      _player.currentIndexStream,
      queue,
      _player.shuffleModeEnabledStream,
      _player.shuffleIndicesStream,
      (index, queue, shuffleModeEnabled, shuffleIndices) {
        final queueIndex = getQueueIndex(
          index,
          shuffleModeEnabled,
          shuffleIndices,
        );
        return (queueIndex != null && queueIndex < queue.length)
            ? queue[queueIndex]
            : null;
      },
    ).distinct().listen(mediaItem.add);
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final isLive = mediaItem.valueOrNull?.isLive ?? false;
    final processingState = _player.processingState;
    final queueIndex = getQueueIndex(
      event.currentIndex,
      _player.shuffleModeEnabled,
      _player.shuffleIndices,
    );
    final queueLength = queue.valueOrNull?.length ?? 0;
    final controls = _getControls(
      playing: playing,
      isLive: isLive,
      queueLength: queueLength,
    );

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: _getSystemActions(isLive: isLive),
        androidCompactActionIndices: List.generate(
          controls.length.clamp(0, 3),
          (i) => i,
        ),
        processingState: _mapProcessingState(processingState),
        playing: playing,
        updatePosition: _optimisticPosition ?? _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex,
      ),
    );
  }

  Duration _clampToDuration(Duration position) {
    var clamped = position;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    }

    final duration = _player.duration;
    if (duration != null && clamped > duration) {
      clamped = duration;
    }

    return clamped;
  }

  /// Sets an optimistic position that will be reflected in the playback state until the next actual position update from the player.
  void _setOptimisticPosition(Duration position) {
    _optimisticPosition = position;
    _optimisticPositionSubject.add(position);

    _optimisticPositionResetTimer?.cancel();
    _optimisticPositionResetTimer = Timer(
      const Duration(seconds: 1),
      _clearOptimisticPosition,
    );

    _broadcastState(_player.playbackEvent);
  }

  /// Clears the optimistic position if the actual position from the player is close enough to it, indicating that the seek has been processed.
  void _maybeClearOptimisticPosition(Duration actualPosition) {
    final optimisticPosition = _optimisticPosition;
    if (optimisticPosition == null) return;

    final delta = (actualPosition - optimisticPosition).abs();
    if (delta <= const Duration(milliseconds: 350)) {
      _clearOptimisticPosition();
    }
  }

  void _clearOptimisticPosition() {
    if (_optimisticPosition == null) return;

    _optimisticPosition = null;
    _optimisticPositionSubject.add(null);
    _optimisticPositionResetTimer?.cancel();
    _optimisticPositionResetTimer = null;
  }

  List<MediaControl> _getControls({
    required bool playing,
    required bool isLive,
    required int queueLength,
  }) {
    final showSkipControls = !isLive && queueLength > 1;
    return [
      if (showSkipControls) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (showSkipControls) MediaControl.skipToNext,
    ];
  }

  Set<MediaAction> _getSystemActions({required bool isLive}) {
    return {
      if (!isLive) ...{
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
    };
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  /// Sets a single audio item as the source.
  Future<void> setItem(MtAudioItem item) async {
    try {
      final resolved = await _assetResolver.resolveItem(item);
      final audioSource = _createAudioSource(resolved);
      await _player.setAudioSource(audioSource);
      _errorSubject.add(null);
    } catch (e) {
      final error = MtAudioError(
        code: MtAudioErrorCode.sourceLoadFailed,
        message: 'Failed to load audio source',
        details: e.toString(),
      );
      _errorSubject.add(error);
      rethrow;
    }
  }

  /// Sets a playlist of audio items as the source.
  Future<void> setPlaylist(
    List<MtAudioItem> items, {
    int initialIndex = 0,
  }) async {
    try {
      final resolved = await Future.wait(items.map(_assetResolver.resolveItem));
      await _player.setAudioSources(
        resolved.map(_createAudioSource).toList(),
        initialIndex: initialIndex,
      );
      _errorSubject.add(null);
    } catch (e) {
      final error = MtAudioError(
        code: MtAudioErrorCode.sourceLoadFailed,
        message: 'Failed to load audio source',
        details: e.toString(),
      );
      _errorSubject.add(error);
      rethrow;
    }
  }

  AudioSource _createAudioSource(MtAudioItem item) {
    return AudioSource.uri(
      item.uri,
      tag: item.toMediaItem(),
      headers: item.headers,
    );
  }

  void _emitQueue(List<IndexedAudioSource> effectiveSequence) {
    queue.add(
      effectiveSequence.map((source) => source.tag as MediaItem).toList(),
    );
  }

  /// Adds an audio item to the end of the queue.
  Future<void> addAudioItem(MtAudioItem item) async {
    final resolved = await _assetResolver.resolveItem(item);
    await _player.addAudioSource(_createAudioSource(resolved));
  }

  /// Inserts an audio item at the specified index.
  Future<void> insertAudioItem(int index, MtAudioItem item) async {
    final sourceIndex = _effectiveToSourceIndex(index, allowEnd: true);
    if (sourceIndex == null) return;

    final resolved = await _assetResolver.resolveItem(item);
    await _player.insertAudioSource(sourceIndex, _createAudioSource(resolved));
  }

  /// Removes an audio item at the specified index.
  Future<void> removeAudioItemAt(int index) async {
    final sourceIndex = _effectiveToSourceIndex(index);
    if (sourceIndex == null) return;

    await _player.removeAudioSourceAt(sourceIndex);
  }

  /// Reorders queue items.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final currentQueue = List<MediaItem>.from(queue.valueOrNull ?? const []);
    if (currentQueue.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= currentQueue.length) return;
    if (newIndex < 0 || newIndex >= currentQueue.length) return;
    if (oldIndex == newIndex) return;

    final currentQueueIndex = playbackState.value.queueIndex;
    final reorderedCurrentIndex = _reorderedIndex(
      oldIndex: oldIndex,
      newIndex: newIndex,
      targetIndex: currentQueueIndex,
    );

    // Emit optimistic queueIndex to avoid transient highlight jumps while
    // queue and playback streams converge after a move.
    if (reorderedCurrentIndex != null &&
        reorderedCurrentIndex != currentQueueIndex) {
      playbackState.add(
        playbackState.value.copyWith(queueIndex: reorderedCurrentIndex),
      );
    }

    if (!_player.shuffleModeEnabled) {
      await _player.moveAudioSource(oldIndex, newIndex);
      return;
    }
    final currentPosition = _player.position;
    final wasPlaying = _player.playing;

    final reorderedQueue = List<MediaItem>.from(currentQueue);
    final movedItem = reorderedQueue.removeAt(oldIndex);
    reorderedQueue.insert(newIndex, movedItem);

    _suppressQueueSync = true;
    try {
      await _player.setAudioSources(
        reorderedQueue
            .map((item) => _createAudioSource(MtAudioItem.fromMediaItem(item)))
            .toList(),
        initialIndex: reorderedCurrentIndex,
        initialPosition: currentPosition,
      );

      await setShuffleMode(AudioServiceShuffleMode.none);

      queue.add(reorderedQueue);

      if (wasPlaying) {
        await _player.play();
      }
    } finally {
      _suppressQueueSync = false;
    }
  }

  int? _effectiveToSourceIndex(int index, {bool allowEnd = false}) {
    if (!_player.shuffleModeEnabled) {
      final queueLength = queue.valueOrNull?.length ?? 0;
      final maxIndex = allowEnd ? queueLength : queueLength - 1;
      if (index < 0 || index > maxIndex) return null;
      return index;
    }

    final effectiveIndices = _player.effectiveIndices;
    if (allowEnd && index == effectiveIndices.length) {
      return _player.sequence.length;
    }

    if (index < 0 || index >= effectiveIndices.length) return null;
    return effectiveIndices[index];
  }

  int? _reorderedIndex({
    required int oldIndex,
    required int newIndex,
    required int? targetIndex,
  }) {
    if (targetIndex == null) return null;
    if (targetIndex == oldIndex) return newIndex;

    if (oldIndex < targetIndex && targetIndex <= newIndex) {
      return targetIndex - 1;
    }

    if (newIndex <= targetIndex && targetIndex < oldIndex) {
      return targetIndex + 1;
    }

    return targetIndex;
  }

  /// Clears the entire queue.
  Future<void> clearQueue() async {
    await _player.clearAudioSources();
    mediaItem.add(null);
  }

  /// Computes the effective queue index taking shuffle mode into account.
  int? getQueueIndex(
    int? currentIndex,
    bool shuffleModeEnabled,
    List<int>? shuffleIndices,
  ) {
    final effectiveIndices = _player.effectiveIndices;
    final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
    for (var i = 0; i < effectiveIndices.length; i++) {
      shuffleIndicesInv[effectiveIndices[i]] = i;
    }
    return (shuffleModeEnabled &&
            ((currentIndex ?? 0) < shuffleIndicesInv.length))
        ? shuffleIndicesInv[currentIndex ?? 0]
        : currentIndex;
  }

  //* BaseAudioHandler overrides

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _clearOptimisticPosition();
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final targetPosition = _clampToDuration(position);
    _setOptimisticPosition(targetPosition);
    await _player.seek(targetPosition);
  }

  @override
  Future<void> skipToNext() async {
    _setOptimisticPosition(Duration.zero);
    await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    _setOptimisticPosition(Duration.zero);
    await _player.seekToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final sourceIndex = _effectiveToSourceIndex(index);
    if (sourceIndex == null) return;

    // This jumps to the beginning of the queue item at [index].
    _setOptimisticPosition(Duration.zero);
    await _player.seek(Duration.zero, index: sourceIndex);
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + _ffRewindInterval;
    await seek(newPosition);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - _ffRewindInterval;
    await seek(newPosition);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
    }

    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final isEnabled = shuffleMode == AudioServiceShuffleMode.all;

    // Preserve current media item to prevent flicker during state transition
    final currentMediaItem = mediaItem.valueOrNull;

    if (isEnabled) {
      await _player.shuffle();
    }

    await _player.setShuffleModeEnabled(isEnabled);

    // Recompute queueIndex after shuffle state changes
    final queueIndex = getQueueIndex(
      _player.currentIndex,
      _player.shuffleModeEnabled,
      _player.shuffleIndices,
    );

    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode: shuffleMode,
        queueIndex: queueIndex,
      ),
    );

    // Re-emit the current media item to override any transient incorrect values
    // from the combineLatest4 stream during the shuffle state transition
    if (currentMediaItem != null) {
      mediaItem.add(currentMediaItem);
    }
  }

  /// Sets the player volume.
  Future<void> setPlayerVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(clampedVolume);
    _volumeSubject.add(clampedVolume);
  }

  /// Binds the actual Android Auto delegate.
  ///
  /// This must be called after player creation but before any Android Auto
  /// browsing requests occur.
  void bindDelegate(MtAndroidAutoDelegate delegate) {
    _androidAutoDelegate.bind(delegate);
  }

  /// Whether the delegate has been bound.
  bool get isDelegateBound => _androidAutoDelegate.isBound;

  @override
  MtAndroidAutoDelegate get androidAutoDelegate => _androidAutoDelegate;

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final items = await super.getChildren(parentMediaId, options);
    return Future.wait(items.map(_assetResolver.resolveMediaItem));
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final items = await super.search(query, extras);
    return Future.wait(items.map(_assetResolver.resolveMediaItem));
  }

  /// Disposes of this handler and releases resources.
  Future<void> dispose() async {
    _optimisticPositionResetTimer?.cancel();
    await _optimisticPositionSubject.close();
    await _errorSubject.close();
    await _volumeSubject.close();
    await _player.dispose();
  }
}
