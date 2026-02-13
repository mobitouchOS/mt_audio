import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

/// Manages audio session configuration and interruption handling.
///
/// This class handles:
/// - Audio session configuration for music playback
/// - Interruption events (phone calls, other apps)
/// - "Becoming noisy" events (headphone disconnection)
/// - Device changes (audio route changes)
class MtAudioSessionManager {
  /// Creates an [MtAudioSessionManager].
  MtAudioSessionManager({
    required AudioHandler audioHandler,
    bool handleInterruptions = true,
  }) : _audioHandler = audioHandler,
       _handleInterruptions = handleInterruptions;

  final AudioHandler _audioHandler;
  final bool _handleInterruptions;

  late final AudioSession _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  /// Initializes the audio session.
  Future<void> init() async {
    _session = await AudioSession.instance;

    // Configure session for music playback
    await _session.configure(
      const AudioSessionConfiguration.music(),
    );

    if (_handleInterruptions) {
      // Handle interruptions (phone calls, alarms, etc.)
      _interruptionSubscription = _session.interruptionEventStream.listen(
        _handleInterruption,
      );

      // Handle becoming noisy (headphone disconnection)
      _becomingNoisySubscription = _session.becomingNoisyEventStream.listen(
        _handleBecomingNoisy,
      );
    }
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    switch (event.type) {
      case AudioInterruptionType.duck:
        // Lower volume during interruption
        // This is typically handled automatically by the OS
        break;

      case AudioInterruptionType.pause:
        // Pause playback
        if (event.begin) {
          await _audioHandler.pause();
        } else {
          // Optionally resume when interruption ends
          // We don't auto-resume to give user control
        }

      case AudioInterruptionType.unknown:
        break;
    }
  }

  Future<void> _handleBecomingNoisy(void event) async {
    // Pause when headphones are disconnected
    await _audioHandler.pause();
  }

  /// Disposes of this manager and releases resources.
  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
  }
}
