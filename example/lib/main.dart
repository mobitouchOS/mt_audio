import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';
import 'package:mt_audio_example/app.dart';
import 'package:mt_audio_example/providers/example_android_auto_delegate.dart';
import 'package:mt_audio_example/providers/example_carplay_delegate.dart';
import 'package:mt_audio_example/providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the audio player with Android Auto and CarPlay support
  // Using factory functions eliminates circular dependency issues
  final player = await MtAudioPlayer.init(
    config: MtAudioPlayerConfig(
      notificationChannelId: 'mt_audio_example',
      notificationChannelName: 'Audio Playback',
      // Factory receives player instance - no holder pattern needed!
      androidAutoDelegateFactory: (player) =>
          ExampleAndroidAutoDelegate(player: player),
      carPlayDelegateFactory: (player) =>
          ExampleCarPlayDelegate(player: player),
    ),
  );

  runApp(
    PlayerProvider(
      player: player,
      child: const MtAudioExampleApp(),
    ),
  );
}
