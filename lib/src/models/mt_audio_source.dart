import 'package:equatable/equatable.dart';
import 'package:mt_audio/src/models/mt_audio_item.dart';

/// Base class for audio sources.
///
/// Represents different types of audio sources that can be played.
/// Use one of the concrete implementations:
/// - [MtSingleSource] for a single audio track
/// - [MtPlaylistSource] for a playlist of tracks
/// - [MtLiveSource] for a live audio stream
sealed class MtAudioSource extends Equatable {
  const MtAudioSource();
}

/// A source representing a single audio track.
class MtSingleSource extends MtAudioSource {
  /// Creates a [MtSingleSource].
  const MtSingleSource({
    required this.item,
  });

  /// The audio item to play.
  final MtAudioItem item;

  @override
  List<Object?> get props => [item];

  @override
  String toString() => 'MtSingleSource(item: $item)';
}

/// A source representing a playlist of audio tracks.
class MtPlaylistSource extends MtAudioSource {
  /// Creates a [MtPlaylistSource].
  const MtPlaylistSource({
    required this.items,
    this.initialIndex = 0,
  });

  /// List of audio items in the playlist.
  final List<MtAudioItem> items;

  /// Index of the initial item to play (defaults to 0).
  final int initialIndex;

  @override
  List<Object?> get props => [items, initialIndex];

  @override
  String toString() =>
      'MtPlaylistSource(items: ${items.length}, initialIndex: $initialIndex)';
}

/// A source representing a live audio stream.
class MtLiveSource extends MtAudioSource {
  /// Creates a [MtLiveSource].
  const MtLiveSource({
    required this.item,
  });

  /// The live stream item.
  ///
  /// The item should have [MtAudioItem.isLive] set to true.
  final MtAudioItem item;

  @override
  List<Object?> get props => [item];

  @override
  String toString() => 'MtLiveSource(item: $item)';
}
