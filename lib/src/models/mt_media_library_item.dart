import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

import 'package:mt_audio/src/models/mt_audio_item.dart';

/// Sealed class representing items in an Android Auto media library.
///
/// Use [MtBrowsableItem] for navigable directories (folders, categories).
/// Use [MtPlayableItem] for playable audio items.
sealed class MtMediaLibraryItem extends Equatable {
  const MtMediaLibraryItem();

  /// Converts this item to a [MediaItem] for audio_service.
  MediaItem toMediaItem();
}

/// A browsable (non-playable) item in the media library.
///
/// Use this for folders, categories, or any navigable node that contains
/// child items but cannot be played directly.
///
/// Example:
/// ```dart
/// MtBrowsableItem(
///   id: 'playlists',
///   title: 'Playlists',
///   subtitle: '12 playlists',
/// )
/// ```
final class MtBrowsableItem extends MtMediaLibraryItem {
  /// Creates an [MtBrowsableItem].
  const MtBrowsableItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.artworkUri,
    this.extras,
  });

  /// Unique identifier for this browsable item.
  final String id;

  /// Display title for this item.
  final String title;

  /// Optional subtitle (e.g., item count, description).
  final String? subtitle;

  /// Optional artwork URI for this item.
  final Uri? artworkUri;

  /// Additional custom data.
  final Map<String, dynamic>? extras;

  @override
  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: subtitle,
      artUri: artworkUri,
      playable: false,
      extras: extras,
    );
  }

  @override
  List<Object?> get props => [id, title, subtitle, artworkUri, extras];

  @override
  String toString() => 'MtBrowsableItem(id: $id, title: $title)';
}

/// A playable item in the media library.
///
/// Wraps an [MtAudioItem] for display in Android Auto's media browser.
///
/// Example:
/// ```dart
/// MtPlayableItem(item: myAudioTrack)
/// ```
final class MtPlayableItem extends MtMediaLibraryItem {
  /// Creates an [MtPlayableItem] wrapping the given [MtAudioItem].
  const MtPlayableItem({required this.item});

  /// The audio item this playable item represents.
  final MtAudioItem item;

  @override
  MediaItem toMediaItem() {
    final mediaItem = item.toMediaItem();
    // Ensure playable is true (it should be by default, but be explicit)
    return mediaItem.copyWith(playable: true);
  }

  @override
  List<Object?> get props => [item];

  @override
  String toString() => 'MtPlayableItem(item: $item)';
}
