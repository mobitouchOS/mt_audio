import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_audio/src/android_auto/mt_android_auto_error.dart';

void main() {
  const premium = MtAndroidAutoError(
    code: MtAndroidAutoErrorCode.premiumAccountRequired,
    message: 'Premium required',
  );

  test('platform codes match PlaybackStateCompat.ERROR_CODE_*', () {
    expect(MtAndroidAutoErrorCode.appError.platformCode, 1);
    expect(MtAndroidAutoErrorCode.notSupported.platformCode, 2);
    expect(MtAndroidAutoErrorCode.authenticationExpired.platformCode, 3);
    expect(MtAndroidAutoErrorCode.premiumAccountRequired.platformCode, 4);
  });

  test('applies the error as an error processing state', () {
    final state = applyAndroidAutoError(PlaybackState(), premium);
    expect(state.processingState, AudioProcessingState.error);
    expect(state.errorCode, 4);
    expect(state.errorMessage, 'Premium required');
  });

  test('clears a previous error when null', () {
    final errored = applyAndroidAutoError(PlaybackState(), premium);
    final cleared = applyAndroidAutoError(
      errored.copyWith(processingState: AudioProcessingState.idle),
      null,
    );
    expect(cleared.errorCode, isNull);
    expect(cleared.errorMessage, isNull);
    expect(cleared.processingState, AudioProcessingState.idle);
  });

  test('hides the error while playing', () {
    final state = applyAndroidAutoError(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
      premium,
    );
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.errorCode, isNull);
  });

  test('shows the error once a queue completes on its own', () {
    // just_audio keeps `playing` true after the last item ends.
    final state = applyAndroidAutoError(
      PlaybackState(
        playing: true,
        processingState: AudioProcessingState.completed,
      ),
      premium,
    );
    expect(state.processingState, AudioProcessingState.error);
    expect(state.errorCode, 4);
  });

  group('nextAndroidAutoError', () {
    /// Runs successive `playing` values through the helper the way
    /// `MtAudioHandler._broadcastState` does, starting from [error].
    MtAndroidAutoError? replay(
      MtAndroidAutoError? error, {
      required bool wasPlaying,
      required List<bool> events,
    }) {
      var current = error;
      var previous = wasPlaying;
      for (final playing in events) {
        current = nextAndroidAutoError(
          current: current,
          wasPlaying: previous,
          playing: playing,
        );
        previous = playing;
      }
      return current;
    }

    /// Like [replay], for full playback states mapped the way the handler
    /// maps them.
    MtAndroidAutoError? replayStates(
      MtAndroidAutoError? error, {
      required bool wasPlaying,
      required List<PlaybackState> events,
    }) => replay(
      error,
      wasPlaying: wasPlaying,
      events: [for (final state in events) isPlayingAudibly(state)],
    );

    test('clears it when playback restarts after a queue completed', () {
      PlaybackState playing(AudioProcessingState processingState) =>
          PlaybackState(playing: true, processingState: processingState);

      expect(
        replayStates(
          premium,
          wasPlaying: true,
          events: [
            playing(AudioProcessingState.ready),
            playing(AudioProcessingState.completed),
            playing(AudioProcessingState.ready),
          ],
        ),
        isNull,
      );
    });

    test('keeps an error set while playing', () {
      expect(replay(premium, wasPlaying: true, events: [true]), premium);
    });

    test('keeps it through later events while still playing', () {
      expect(
        replay(premium, wasPlaying: true, events: [true, true, true]),
        premium,
      );
    });

    test('shows it once playback stops', () {
      final error = replay(premium, wasPlaying: true, events: [true, false]);
      expect(error, premium);
      expect(
        applyAndroidAutoError(PlaybackState(), error).errorCode,
        MtAndroidAutoErrorCode.premiumAccountRequired.platformCode,
      );
    });

    test('clears it when playback goes from not playing to playing', () {
      expect(
        replay(premium, wasPlaying: true, events: [true, false, true]),
        isNull,
      );
      expect(replay(premium, wasPlaying: false, events: [true]), isNull);
    });

    test('shows an error set while idle', () {
      final error = replay(premium, wasPlaying: false, events: [false]);
      expect(error, premium);
      expect(
        applyAndroidAutoError(PlaybackState(), error).processingState,
        AudioProcessingState.error,
      );
    });
  });
}
