import 'package:equatable/equatable.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_playback_state.dart';

/// Queue state of the audio player.
///
/// Contains the list of items in the queue and the current playing index.
class MtQueueState extends Equatable {
  /// Creates an [MtQueueState].
  const MtQueueState({
    required this.queue,
    required this.queueIndex,
    required this.shuffleIndices,
    required this.repeatMode,
  });

  /// Creates an empty [MtQueueState].
  const MtQueueState.empty()
    : queue = const [],
      queueIndex = null,
      shuffleIndices = null,
      repeatMode = MtRepeatMode.off;

  /// Ordered list of items in the queue.
  final List<MtAudioItem> queue;

  /// Index of the currently playing item (null if queue is empty).
  final int? queueIndex;

  /// Shuffle indices (null if shuffle mode is off).
  final List<int>? shuffleIndices;

  /// Current repeat mode.
  final MtRepeatMode repeatMode;

  /// Whether there is a next item in the queue.
  bool get hasNext {
    if (queueIndex == null || queue.isEmpty) return false;
    if (repeatMode == MtRepeatMode.all) return true;
    return queueIndex! < queue.length - 1;
  }

  /// Whether there is a previous item in the queue.
  bool get hasPrevious {
    if (queueIndex == null || queue.isEmpty) return false;
    if (repeatMode == MtRepeatMode.all) return true;
    return queueIndex! > 0;
  }

  /// Whether the queue is empty.
  bool get isEmpty => queue.isEmpty;

  /// Whether the queue has items.
  bool get isNotEmpty => queue.isNotEmpty;

  /// Number of items in the queue.
  int get length => queue.length;

  /// Creates a copy of this state with the given fields replaced.
  MtQueueState copyWith({
    List<MtAudioItem>? queue,
    int? queueIndex,
    bool clearQueueIndex = false,
    List<int>? shuffleIndices,
    bool clearShuffleIndices = false,
    MtRepeatMode? repeatMode,
  }) {
    return MtQueueState(
      queue: queue ?? this.queue,
      queueIndex: clearQueueIndex ? null : (queueIndex ?? this.queueIndex),
      shuffleIndices: clearShuffleIndices
          ? null
          : (shuffleIndices ?? this.shuffleIndices),
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  @override
  List<Object?> get props => [
    queue,
    queueIndex,
    shuffleIndices,
    repeatMode,
  ];

  @override
  String toString() {
    return 'MtQueueState(items: ${queue.length}, currentIndex: $queueIndex)';
  }
}
