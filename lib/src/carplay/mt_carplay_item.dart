import 'package:equatable/equatable.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';
import 'package:mt_carplay/mt_carplay.dart';

/// Template type for browsable CarPlay items.
enum MtCarPlayTemplateType {
  /// List template with vertical scrolling items.
  list,

  /// Grid template with image-based navigation.
  grid,
}

/// Sealed class representing items in a CarPlay media library.
///
/// Use [MtCarPlayBrowsableItem] for navigable directories (folders, categories).
/// Use [MtCarPlayPlayableItem] for playable audio items.
sealed class MtCarPlayItem extends Equatable {
  const MtCarPlayItem();

  /// Converts this item to a CarPlay list item.
  ///
  /// [onSelect] is called when the item is selected, receiving the item's ID.
  /// [isPlaying] indicates if this item is currently playing.
  /// [playbackProgress] is the current progress (0.0 to 1.0) for this item.
  CPListItem toCPItem({
    required Future<void> Function(String itemId) onSelect,
    bool isPlaying = false,
    double? playbackProgress,
  });

  /// Converts this item to a CarPlay grid button.
  ///
  /// [onSelect] is called when the button is selected, receiving the item's ID.
  CPGridButton toCPButton({
    required void Function(String itemId) onSelect,
  });
}

/// A browsable (non-playable) item in the CarPlay media library.
///
/// Use this for folders, categories, or any navigable node that contains
/// child items but cannot be played directly.
///
/// Example:
/// ```dart
/// MtCarPlayBrowsableItem(
///   id: 'playlists',
///   title: 'Playlists',
///   subtitle: '12 playlists',
///   templateType: MtCarPlayTemplateType.grid,
/// )
/// ```
final class MtCarPlayBrowsableItem extends MtCarPlayItem {
  /// Creates an [MtCarPlayBrowsableItem].
  const MtCarPlayBrowsableItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUri,
    this.templateType = MtCarPlayTemplateType.list,
  });

  /// Unique identifier for this browsable item.
  final String id;

  /// Display title for this item.
  final String title;

  /// Optional subtitle (e.g., item count, description).
  final String? subtitle;

  /// Optional image URI for this item.
  final Uri? imageUri;

  /// Template type to use when navigating into this item.
  final MtCarPlayTemplateType templateType;

  @override
  CPListItem toCPItem({
    required Future<void> Function(String itemId) onSelect,
    bool isPlaying = false,
    double? playbackProgress,
  }) {
    return CPListItem(
      text: title,
      detailText: subtitle ?? '',
      image: imageUri?.toString(),
      accessoryType: CPListItemAccessoryTypes.disclosureIndicator,
      onPress: (complete, self) async {
        await onSelect(id).timeout(const Duration(seconds: 5));
        complete();
      },
    );
  }

  @override
  CPGridButton toCPButton({
    required void Function(String itemId) onSelect,
  }) {
    return CPGridButton(
      titleVariants: [
        title,
      ],
      image: imageUri?.toString() ?? '',
      onPress: () {
        onSelect(id);
      },
    );
  }

  @override
  List<Object?> get props => [id, title, subtitle, imageUri, templateType];

  @override
  String toString() => 'MtCarPlayBrowsableItem(id: $id, title: $title)';
}

/// A playable item in the CarPlay media library.
///
/// Wraps an [MtAudioItem] for display in CarPlay's media browser.
///
/// Example:
/// ```dart
/// MtCarPlayPlayableItem(item: myAudioTrack)
/// ```
final class MtCarPlayPlayableItem extends MtCarPlayItem {
  /// Creates an [MtCarPlayPlayableItem] wrapping the given [MtAudioItem].
  const MtCarPlayPlayableItem({required this.item});

  /// The audio item this playable item represents.
  final MtAudioItem item;

  @override
  CPListItem toCPItem({
    required Future<void> Function(String itemId) onSelect,
    bool isPlaying = false,
    double? playbackProgress,
  }) {
    return CPListItem(
      text: item.title,
      detailText: item.artist ?? item.album ?? '',
      image: item.artworkUri?.toString(),
      isPlaying: isPlaying,
      playbackProgress: playbackProgress,
      onPress: (complete, self) async {
        await onSelect(item.id).timeout(const Duration(seconds: 5));
        complete();
      },
    );
  }

  @override
  CPGridButton toCPButton({
    required void Function(String itemId) onSelect,
  }) {
    return CPGridButton(
      titleVariants: [
        item.title,
      ],
      image: item.artworkUri?.toString() ?? '',
      onPress: () {
        onSelect(item.id);
      },
    );
  }

  @override
  List<Object?> get props => [item];

  @override
  String toString() => 'MtCarPlayPlayableItem(item: $item)';
}
