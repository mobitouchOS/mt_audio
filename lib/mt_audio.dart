/// A generic, reusable, streams-based audio package for Flutter.
///
/// Provides background audio playback with notifications, queue management,
/// and optional Android Auto support.
library;

// Re-export audio_service types needed for Android Auto
export 'package:audio_service/audio_service.dart' show MediaItem;

// Re-export just_audio types that users might need
export 'package:just_audio/just_audio.dart' show IcyMetadata;

// Android Auto
export 'src/android_auto/mt_android_auto_delegate.dart';

// CarPlay
export 'src/carplay/mt_carplay_delegate.dart';
export 'src/carplay/mt_carplay_handler.dart';
export 'src/carplay/mt_carplay_item.dart';

// Lyrics
export 'src/lyrics/mt_lyrics_controller.dart';
export 'src/lyrics/mt_lyrics_cursor.dart';
export 'src/lyrics/mt_lyrics_parser.dart';

// Models
export 'src/models/mt_audio_error.dart';
export 'src/models/mt_audio_item.dart';
export 'src/models/mt_lyrics.dart';
export 'src/models/mt_media_library_item.dart';
export 'src/models/mt_playback_state.dart';
export 'src/models/mt_position_state.dart';
export 'src/models/mt_queue_state.dart';

// Player
export 'src/player/mt_audio_player.dart';
export 'src/player/mt_audio_player_config.dart';

// Widgets - Controls
export 'src/widgets/controls/mt_play_pause_button.dart';
export 'src/widgets/controls/mt_player_builder.dart';
export 'src/widgets/controls/mt_skip_button.dart';
export 'src/widgets/controls/mt_track_skip_button.dart';

// Widgets - Lyrics
export 'src/widgets/lyrics/mt_lyrics_view.dart';

// Widgets - Player info
export 'src/widgets/player_info/mt_artwork.dart';
export 'src/widgets/player_info/mt_now_playing_info.dart';

// Widgets - Queue
export 'src/widgets/queue/mt_queue_item_tile.dart';
export 'src/widgets/queue/mt_queue_list_view.dart';

// Widgets - Seek bar
export 'src/widgets/seek_bar/mt_seek_bar.dart';

// Widgets - Speed
export 'src/widgets/speed/mt_speed_selector.dart';
