import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mt_audio/src/utils/mt_asset_resolver.dart';

/// Artwork image widget with placeholder and error handling.
///
/// Displays album/track artwork from a URI, with fallback to placeholder.
class MtArtwork extends StatelessWidget {
  /// Creates an [MtArtwork].
  const MtArtwork({
    required this.artworkUri,
    this.size = 200,
    this.borderRadius = 8.0,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  /// URI of the artwork image.
  final Uri? artworkUri;

  /// Size of the artwork (width and height).
  final double size;

  /// Border radius for rounded corners.
  final double borderRadius;

  /// Widget to show while loading or if artworkUri is null.
  final Widget? placeholder;

  /// Widget to show on error.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget defaultPlaceholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (artworkUri == null) {
      return placeholder ?? defaultPlaceholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: _buildImage(
        artworkUri!,
        placeholder: placeholder ?? defaultPlaceholder,
        errorWidget: errorWidget ?? defaultPlaceholder,
      ),
    );
  }

  Widget _buildImage(
    Uri uri, {
    required Widget placeholder,
    required Widget errorWidget,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelSize = (size * MediaQuery.devicePixelRatioOf(context))
            .ceil();

        return switch (uri.scheme) {
          'asset' => Image.asset(
            MtAssetResolver.assetKey(uri),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: pixelSize,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => errorWidget,
          ),
          'file' => Image.file(
            File(uri.toFilePath()),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: pixelSize,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => errorWidget,
          ),
          _ => Image.network(
            uri.toString(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: pixelSize,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
            errorBuilder: (context, error, stackTrace) => errorWidget,
          ),
        };
      },
    );
  }
}
