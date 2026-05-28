import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

/// Immutable track metadata for audio playback.
///
/// Represents a single audio item with all necessary metadata for display
/// and playback. Can be converted to/from [MediaItem] for use with audio_service.
class MtAudioItem extends Equatable {
  /// Creates an [MtAudioItem].
  const MtAudioItem({
    required this.id,
    required this.uri,
    required this.title,
    this.artist,
    this.album,
    this.artworkUri,
    this.duration,
    this.isLive = false,
    this.extras,
    this.headers,
  });

  /// Creates an [MtAudioItem] from a [MediaItem].
  factory MtAudioItem.fromMediaItem(MediaItem mediaItem) {
    final extras = mediaItem.extras ?? {};
    final uriString = extras['uri'] as String?;
    final isLive = extras['isLive'] as bool? ?? false;
    final artworkUriString = extras['_artworkUri'] as String?;
    final headers = switch (extras['headers']) {
      final Map<dynamic, dynamic> rawHeaders => rawHeaders.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      _ => null,
    };

    // Remove internal fields from extras
    final cleanExtras = Map<String, dynamic>.from(extras)
      ..remove('uri')
      ..remove('isLive')
      ..remove('headers')
      ..remove('_artworkUri');

    return MtAudioItem(
      id: mediaItem.id,
      uri: uriString != null ? Uri.parse(uriString) : Uri(),
      title: mediaItem.title,
      artist: mediaItem.artist,
      album: mediaItem.album,
      artworkUri: artworkUriString != null
          ? Uri.parse(artworkUriString)
          : mediaItem.artUri,
      duration: mediaItem.duration,
      isLive: isLive,
      extras: cleanExtras.isEmpty ? null : cleanExtras,
      headers: headers,
    );
  }

  /// Unique identifier for this item.
  final String id;

  /// URI of the audio source.
  final Uri uri;

  /// Display title.
  final String title;

  /// Artist name.
  final String? artist;

  /// Album name.
  final String? album;

  /// Artwork image URI.
  final Uri? artworkUri;

  /// Duration of the audio track (null for live streams).
  final Duration? duration;

  /// Whether this is a live stream.
  final bool isLive;

  /// Custom metadata.
  final Map<String, dynamic>? extras;

  /// HTTP headers for audio source (e.g., authentication).
  final Map<String, String>? headers;

  /// Converts this item to a [MediaItem] for audio_service.
  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artworkUri,
      duration: duration,
      isLive: isLive,
      extras: {
        ...?extras,
        'uri': uri.toString(),
        'isLive': isLive,
        if (headers != null) 'headers': headers,
        if (artworkUri != null) '_artworkUri': artworkUri.toString(),
      },
    );
  }

  /// Creates a copy of this item with the given fields replaced.
  MtAudioItem copyWith({
    String? id,
    Uri? uri,
    String? title,
    String? artist,
    String? album,
    Uri? artworkUri,
    Duration? duration,
    bool? isLive,
    Map<String, dynamic>? extras,
    Map<String, String>? headers,
  }) {
    return MtAudioItem(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUri: artworkUri ?? this.artworkUri,
      duration: duration ?? this.duration,
      isLive: isLive ?? this.isLive,
      extras: extras ?? this.extras,
      headers: headers ?? this.headers,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    artist,
    album,
    uri,
    artworkUri,
    duration,
    isLive,
    extras,
    headers,
  ];

  @override
  String toString() {
    return 'MtAudioItem(id: $id, title: $title, artist: $artist, '
        'isLive: $isLive)';
  }
}
