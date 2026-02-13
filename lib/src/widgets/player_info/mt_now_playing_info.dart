import 'package:flutter/material.dart';

import 'package:mt_audio/src/player/mt_audio_player.dart';

/// Displays the currently playing track's title, artist, and album.
///
/// Automatically updates when the current item changes.
class MtNowPlayingInfo extends StatelessWidget {
  /// Creates an [MtNowPlayingInfo].
  const MtNowPlayingInfo({
    required this.player,
    this.titleStyle,
    this.artistStyle,
    this.albumStyle,
    this.showAlbum = false,
    this.alignment = TextAlign.center,
    super.key,
  });

  /// The audio player instance.
  final MtAudioPlayer player;

  /// Text style for the title.
  final TextStyle? titleStyle;

  /// Text style for the artist.
  final TextStyle? artistStyle;

  /// Text style for the album.
  final TextStyle? albumStyle;

  /// Whether to show the album name.
  final bool showAlbum;

  /// Text alignment.
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder(
      stream: player.currentItemStream,
      builder: (context, snapshot) {
        final item = snapshot.data ?? player.currentItem;

        if (item == null) {
          return Center(
            child: Text(
              'No track playing',
              style: artistStyle ?? theme.textTheme.bodyMedium,
              textAlign: alignment,
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              style:
                  titleStyle ??
                  theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: alignment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.artist != null) ...[
              const SizedBox(height: 8),
              Text(
                item.artist!,
                style: artistStyle ?? theme.textTheme.bodyLarge,
                textAlign: alignment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showAlbum && item.album != null) ...[
              const SizedBox(height: 4),
              Text(
                item.album!,
                style:
                    albumStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                textAlign: alignment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}
