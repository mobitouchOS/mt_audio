import 'package:mt_audio/src/android_auto/mt_android_auto_delegate.dart';
import 'package:mt_audio/src/carplay/mt_carplay_delegate.dart';
import 'package:mt_audio/src/player/mt_audio_player.dart';

/// Factory function type for creating a CarPlay delegate with player access.
///
/// The factory is invoked after [MtAudioPlayer] is created, allowing the
/// delegate to receive the player instance for controlling playback.
///
/// Example:
/// ```dart
/// MtAudioPlayerConfig(
///   carPlayDelegateFactory: (player) => MyCarPlayDelegate(player: player),
/// )
/// ```
typedef MtCarPlayDelegateFactory =
    MtCarPlayDelegate Function(
      MtAudioPlayer player,
    );

/// Factory function type for creating an Android Auto delegate with player access.
///
/// The factory is invoked after [MtAudioPlayer] is created, allowing the
/// delegate to receive the player instance for controlling playback.
///
/// Example:
/// ```dart
/// MtAudioPlayerConfig(
///   androidAutoDelegateFactory: (player) => MyAndroidAutoDelegate(player: player),
/// )
/// ```
typedef MtAndroidAutoDelegateFactory =
    MtAndroidAutoDelegate Function(
      MtAudioPlayer player,
    );

/// Configuration for [MtAudioPlayer].
///
/// Contains all settings needed to initialize the audio player.
class MtAudioPlayerConfig {
  /// Creates an [MtAudioPlayerConfig].
  const MtAudioPlayerConfig({
    required this.notificationChannelId,
    required this.notificationChannelName,
    this.notificationIcon,
    this.ffRewindInterval = const Duration(seconds: 10),
    this.carPlayDelegateFactory,
    this.androidAutoDelegateFactory,
    this.handleInterruptions = true,
    this.androidNotificationOngoing = false,
  });

  /// Notification channel ID for Android.
  final String notificationChannelId;

  /// Notification channel name for Android.
  final String notificationChannelName;

  /// Notification icon resource name (e.g., 'mipmap/ic_launcher').
  ///
  /// If null, uses the app's launcher icon.
  final String? notificationIcon;

  /// Interval for fast-forward and rewind actions.
  final Duration ffRewindInterval;

  /// Factory for Apple CarPlay delegate (optional).
  ///
  /// If null, CarPlay support is disabled.
  /// The factory receives the [MtAudioPlayer] instance, allowing the delegate
  /// to control playback without circular dependency issues.
  ///
  /// Example:
  /// ```dart
  /// carPlayDelegateFactory: (player) => MyCarPlayDelegate(player: player),
  /// ```
  final MtCarPlayDelegateFactory? carPlayDelegateFactory;

  /// Factory for Android Auto delegate (optional).
  ///
  /// If null, Android Auto support is disabled.
  /// The factory receives the [MtAudioPlayer] instance, allowing the delegate
  /// to control playback without circular dependency issues.
  ///
  /// Example:
  /// ```dart
  /// androidAutoDelegateFactory: (player) => MyAndroidAutoDelegate(player: player),
  /// ```
  final MtAndroidAutoDelegateFactory? androidAutoDelegateFactory;

  /// Whether to automatically handle audio interruptions (phone calls, etc.).
  ///
  /// Defaults to true.
  final bool handleInterruptions;

  /// Whether the Android notification should be ongoing (non-dismissible).
  ///
  /// When false (the default), the notification can be dismissed when paused.
  /// Set to true to keep the notification persistent at all times.
  final bool androidNotificationOngoing;
}
