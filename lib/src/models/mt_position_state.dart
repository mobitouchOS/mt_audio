import 'package:equatable/equatable.dart';

/// Position state of the audio player.
///
/// Contains information about the current playback position, buffered position,
/// and total duration.
class MtPositionState extends Equatable {
  /// Creates an [MtPositionState].
  const MtPositionState({
    required this.position,
    required this.bufferedPosition,
    required this.duration,
  });

  /// Creates an empty [MtPositionState] with all values set to zero.
  const MtPositionState.empty()
    : position = Duration.zero,
      bufferedPosition = Duration.zero,
      duration = Duration.zero;

  /// Current playback position.
  final Duration position;

  /// Buffered position ahead of the current position.
  final Duration bufferedPosition;

  /// Total duration of the audio (may be null for live streams).
  final Duration? duration;

  /// Progress as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if duration is null or zero.
  double get progress {
    if (duration == null || duration == Duration.zero) return 0;
    return (position.inMilliseconds / duration!.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Buffered progress as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if duration is null or zero.
  double get bufferedProgress {
    if (duration == null || duration == Duration.zero) return 0;
    return (bufferedPosition.inMilliseconds / duration!.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// Creates a copy of this state with the given fields replaced.
  MtPositionState copyWith({
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
  }) {
    return MtPositionState(
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [
    position,
    bufferedPosition,
    duration,
  ];

  @override
  String toString() {
    return 'MtPositionState(position: $position, bufferedPosition: '
        '$bufferedPosition, duration: $duration)';
  }
}
