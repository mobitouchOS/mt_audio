import 'package:flutter/material.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_audio/src/models/mt_playback_state.dart';
import 'package:mt_audio/src/models/mt_position_state.dart';
import 'package:mt_audio/src/models/mt_queue_state.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';
import 'package:rxdart/rxdart.dart';

/// Builder widget that exposes player state and actions for custom UI.
///
/// Use this to build completely custom player interfaces that respond
/// to player state changes.
///
/// Example:
/// ```dart
/// MtPlayerBuilder(
///   player: player,
///   builder: (context, state) {
///     return Column(
///       children: [
///         Text(state.currentItem?.title ?? 'No track'),
///         Text('${state.position} / ${state.duration}'),
///         ElevatedButton(
///           onPressed: state.isPlaying ? player.pause : player.play,
///           child: Text(state.isPlaying ? 'Pause' : 'Play'),
///         ),
///       ],
///     );
///   },
/// )
/// ```
class MtPlayerBuilder extends StatefulWidget {
  /// Creates an [MtPlayerBuilder].
  const MtPlayerBuilder({
    required this.player,
    required this.builder,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Builder function that receives player state and actions.
  final Widget Function(BuildContext context, MtPlayerState state) builder;

  @override
  State<MtPlayerBuilder> createState() => _MtPlayerBuilderState();
}

class _MtPlayerBuilderState extends State<MtPlayerBuilder> {
  late Stream<_CombinedState> _combinedStream;

  @override
  void initState() {
    super.initState();
    _combinedStream = _combineStreams(widget.player);
  }

  @override
  void didUpdateWidget(MtPlayerBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _combinedStream = _combineStreams(widget.player);
    }
  }

  static Stream<_CombinedState> _combineStreams(MtAudioPlayer player) {
    return Rx.combineLatest4(
      player.playbackStateStream,
      player.positionStateStream,
      player.queueStateStream,
      player.currentItemStream,
      (playbackState, positionState, queueState, currentItem) => _CombinedState(
        playbackState: playbackState,
        positionState: positionState,
        queueState: queueState,
        currentItem: currentItem,
      ),
    ).throttleTime(
      const Duration(milliseconds: 150),
      leading: true,
      trailing: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return StreamBuilder<_CombinedState>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        final playbackState =
            snapshot.data?.playbackState ?? player.currentPlaybackState;
        final positionState =
            snapshot.data?.positionState ?? player.currentPositionState;
        final queueState =
            snapshot.data?.queueState ?? player.currentQueueState;
        final currentItem = snapshot.data?.currentItem ?? player.currentItem;

        final state = MtPlayerState(
          playbackState: playbackState,
          positionState: positionState,
          queueState: queueState,
          currentItem: currentItem,
          speed: playbackState.speed,
        );

        return widget.builder(context, state);
      },
    );
  }
}

class _CombinedState {
  const _CombinedState({
    required this.playbackState,
    required this.positionState,
    required this.queueState,
    required this.currentItem,
  });

  final MtPlaybackState playbackState;
  final MtPositionState positionState;
  final MtQueueState queueState;
  final MtAudioItem? currentItem;
}

/// Player state exposed to builder function.
class MtPlayerState {
  /// Creates an [MtPlayerState].
  const MtPlayerState({
    required this.playbackState,
    required this.positionState,
    required this.queueState,
    required this.currentItem,
    required this.speed,
  });

  /// Current playback state.
  final MtPlaybackState playbackState;

  /// Current position state.
  final MtPositionState positionState;

  /// Current queue state.
  final MtQueueState queueState;

  /// Currently playing item.
  final MtAudioItem? currentItem;

  /// Current playback speed.
  final double speed;

  /// Whether the player is playing.
  bool get isPlaying => playbackState.isPlaying;

  /// Whether the player is paused.
  bool get isPaused => playbackState.isPaused;

  /// Whether the player is loading.
  bool get isLoading => playbackState.isLoading;

  /// Current position.
  Duration get position => positionState.position;

  /// Total duration.
  Duration? get duration => positionState.duration;

  /// Playback progress (0.0 to 1.0).
  double get progress => positionState.progress;
}
