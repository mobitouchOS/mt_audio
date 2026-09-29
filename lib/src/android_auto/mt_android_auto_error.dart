import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

/// Android Auto error categories, mapped to `PlaybackStateCompat.ERROR_CODE_*`.
///
/// Android Auto renders these prominently over its browse and playback
/// screens, so they are the platform's way to explain a state the user has
/// to resolve on the phone.
enum MtAndroidAutoErrorCode {
  /// `ERROR_CODE_APP_ERROR` — something failed inside the app.
  appError(1),

  /// `ERROR_CODE_NOT_SUPPORTED` — the requested action is not supported.
  notSupported(2),

  /// `ERROR_CODE_AUTHENTICATION_EXPIRED` — the user must sign in on the phone.
  authenticationExpired(3),

  /// `ERROR_CODE_PREMIUM_ACCOUNT_REQUIRED` — content needs a paid plan.
  premiumAccountRequired(4);

  const MtAndroidAutoErrorCode(this.platformCode);

  /// The `PlaybackStateCompat.ERROR_CODE_*` value sent to Android.
  final int platformCode;
}

/// An error shown on Android Auto while nothing plays, until playback
/// starts or it is cleared.
class MtAndroidAutoError extends Equatable {
  /// Creates an [MtAndroidAutoError].
  const MtAndroidAutoError({required this.code, required this.message});

  /// The error category.
  final MtAndroidAutoErrorCode code;

  /// User-facing text; Android Auto displays it as-is.
  final String message;

  @override
  List<Object?> get props => [code, message];
}

/// Merges [error] into [state].
///
/// While [state] is playing the error is hidden — Android Auto would
/// otherwise cover the playback screen; the caller keeps it (see
/// [nextAndroidAutoError]) so it shows once playback stops. `null` clears
/// any previous error fields and leaves the processing state as computed
/// from the player.
PlaybackState applyAndroidAutoError(
  PlaybackState state,
  MtAndroidAutoError? error,
) {
  if (error == null || state.playing) {
    // copyWith uses a sentinel default, not a literal `null`, so these
    // explicit nulls are required to actually clear the fields — omitting
    // them would keep whatever error was previously set.
    // ignore: avoid_redundant_argument_values
    return state.copyWith(errorCode: null, errorMessage: null);
  }
  return state.copyWith(
    processingState: AudioProcessingState.error,
    errorCode: error.code.platformCode,
    errorMessage: error.message,
  );
}

/// The Android Auto error to keep after a playback update from [wasPlaying]
/// to [playing].
///
/// Only a transition from not playing to playing clears [current]: starting
/// playback resolves whatever the error asked the user to fix. An error set
/// while playing is kept — [applyAndroidAutoError] hides it until playback
/// stops — rather than being erased by the very update that sets it.
MtAndroidAutoError? nextAndroidAutoError({
  required MtAndroidAutoError? current,
  required bool wasPlaying,
  required bool playing,
}) => !wasPlaying && playing ? null : current;
