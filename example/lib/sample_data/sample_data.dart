import 'package:mt_audio/mt_audio.dart';

/// Sample MP3 tracks from SoundHelix (free/public).
final sampleTracks = [
  MtAudioItem(
    id: 'track-1',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    title: 'SoundHelix Song 1',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop',
    ),
    duration: const Duration(minutes: 6, seconds: 13),
  ),
  MtAudioItem(
    id: 'track-2',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    title: 'SoundHelix Song 2',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop',
    ),
    duration: const Duration(minutes: 8, seconds: 10),
  ),
  MtAudioItem(
    id: 'track-3',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
    title: 'SoundHelix Song 3',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=400&h=400&fit=crop',
    ),
    duration: const Duration(minutes: 5, seconds: 39),
  ),
  MtAudioItem(
    id: 'track-4',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    ),
    title: 'SoundHelix Song 8',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&h=400&fit=crop',
    ),
    duration: const Duration(minutes: 5, seconds: 22),
  ),
  MtAudioItem(
    id: 'track-5',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    ),
    title: 'SoundHelix Song 9',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=400&h=400&fit=crop',
    ),
    duration: const Duration(minutes: 5, seconds: 24),
  ),
  MtAudioItem(
    id: 'track-asset',
    uri: Uri.parse(
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    ),
    title: 'SoundHelix Song 4 (Asset Art)',
    artist: 'T. Schürger',
    album: 'SoundHelix',
    artworkUri: Uri.parse('asset:///assets/images/sample_cover.jpg'),
    duration: const Duration(minutes: 7, seconds: 23),
  ),
];

/// Live radio streams from Public Domain Radio.
///
/// Stream metadata indicates free music from publicdomain.ch.
final liveStreams = [
  MtAudioItem(
    id: 'live-1',
    uri: Uri.parse('http://relay.publicdomainradio.org/classical.mp3'),
    title: 'Public Domain Classical',
    artist: 'Public Domain Radio',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop',
    ),
    isLive: true,
    duration: const Duration(hours: -1),
  ),
  MtAudioItem(
    id: 'live-2',
    uri: Uri.parse('http://relay.publicdomainradio.org/jazz_swing.mp3'),
    title: 'Public Domain Jazz',
    artist: 'Public Domain Radio',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop',
    ),
    isLive: true,
    duration: const Duration(hours: -1),
  ),
  MtAudioItem(
    id: 'live-3',
    uri: Uri.parse('http://relay.publicdomainradio.org/swiss_schlager.mp3'),
    title: 'Public Domain Swiss Schlager',
    artist: 'Public Domain Radio',
    artworkUri: Uri.parse(
      'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=400&h=400&fit=crop',
    ),
    isLive: true,
    duration: const Duration(hours: -1),
  ),
];

/// All sample items combined.
final List<MtAudioItem> allSampleItems = [...sampleTracks, ...liveStreams];
