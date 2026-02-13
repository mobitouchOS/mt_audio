import 'package:equatable/equatable.dart';

/// Playback status of the audio player.
enum MtPlaybackStatus {
  /// Player is idle (no audio loaded).
  idle,

  /// Player is loading audio.
  loading,

  /// Player is buffering.
  buffering,

  /// Player is currently playing.
  playing,

  /// Player is paused.
  paused,

  /// Player has completed playback.
  completed,

  /// Player encountered an error.
  error,
}

/// Repeat mode for playback.
enum MtRepeatMode {
  /// No repeat (play through once and stop).
  off,

  /// Repeat the entire queue.
  all,

  /// Repeat the current item only.
  one,
}

/// Complete playback state of the audio player.
///
/// Contains all information about the current playback state including
/// status, repeat mode, shuffle, volume, and playback speed.
class MtPlaybackState extends Equatable {
  /// Creates an [MtPlaybackState].
  const MtPlaybackState({
    required this.status,
    this.repeatMode = MtRepeatMode.off,
    this.shuffleEnabled = false,
    this.volume = 1.0,
    this.speed = 1.0,
  });

  /// Current playback status.
  final MtPlaybackStatus status;

  /// Current repeat mode.
  final MtRepeatMode repeatMode;

  /// Whether shuffle mode is enabled.
  final bool shuffleEnabled;

  /// Current volume (0.0 to 1.0).
  final double volume;

  /// Current playback speed (typically 0.5 to 2.0).
  final double speed;

  /// Whether the player is currently playing.
  bool get isPlaying => status == MtPlaybackStatus.playing;

  /// Whether the player is currently paused.
  bool get isPaused => status == MtPlaybackStatus.paused;

  /// Whether the player is loading or buffering.
  bool get isLoading =>
      status == MtPlaybackStatus.loading ||
      status == MtPlaybackStatus.buffering;

  /// Whether the player is in an error state.
  bool get hasError => status == MtPlaybackStatus.error;

  /// Creates a copy of this state with the given fields replaced.
  MtPlaybackState copyWith({
    MtPlaybackStatus? status,
    MtRepeatMode? repeatMode,
    bool? shuffleEnabled,
    double? volume,
    double? speed,
  }) {
    return MtPlaybackState(
      status: status ?? this.status,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    repeatMode,
    shuffleEnabled,
    volume,
    speed,
  ];

  @override
  String toString() {
    return 'MtPlaybackState(status: $status, repeatMode: $repeatMode, '
        'shuffleEnabled: $shuffleEnabled, volume: $volume, speed: $speed)';
  }
}
