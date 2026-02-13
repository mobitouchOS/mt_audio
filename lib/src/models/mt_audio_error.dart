import 'package:equatable/equatable.dart';

/// Error codes for audio playback errors.
enum MtAudioErrorCode {
  /// Failed to load the audio source.
  sourceLoadFailed,

  /// Network error while loading audio.
  networkError,

  /// Invalid audio format.
  invalidFormat,

  /// Playback was aborted.
  aborted,

  /// Audio decoding error.
  decodingError,

  /// Unknown error.
  unknown,
}

/// An audio error with a code and message.
///
/// Represents errors that can occur during audio playback.
class MtAudioError extends Equatable {
  /// Creates an [MtAudioError].
  const MtAudioError({
    required this.code,
    required this.message,
    this.details,
  });

  /// The error code.
  final MtAudioErrorCode code;

  /// Human-readable error message.
  final String message;

  /// Optional additional details about the error.
  final String? details;

  @override
  List<Object?> get props => [
    code,
    message,
    details,
  ];

  @override
  String toString() {
    final detailsStr = details != null ? ', details: $details' : '';
    return 'MtAudioError(code: $code, message: $message$detailsStr)';
  }
}

/// Exception thrown by the audio player.
///
/// Wraps an [MtAudioError] and can be thrown when audio operations fail.
class MtAudioException extends Equatable implements Exception {
  /// Creates an [MtAudioException].
  const MtAudioException(this.error);

  /// The underlying error.
  final MtAudioError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'MtAudioException: $error';
}
