import 'package:flutter/material.dart';
import 'package:mt_audio/mt_audio.dart';

/// InheritedWidget that provides access to the [MtAudioPlayer] instance.
class PlayerProvider extends InheritedWidget {
  const PlayerProvider({
    required this.player,
    required super.child,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Gets the player from the widget tree.
  static MtAudioPlayer of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<PlayerProvider>();
    assert(provider != null, 'No PlayerProvider found in context');
    return provider!.player;
  }

  /// Gets the player from the widget tree without registering for updates.
  static MtAudioPlayer read(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<PlayerProvider>();
    assert(provider != null, 'No PlayerProvider found in context');
    return provider!.player;
  }

  @override
  bool updateShouldNotify(PlayerProvider oldWidget) {
    return player != oldWidget.player;
  }
}
