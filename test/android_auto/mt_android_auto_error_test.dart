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

  test('drops the error while playing', () {
    final state = applyAndroidAutoError(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
      premium,
    );
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.errorCode, isNull);
  });
}
