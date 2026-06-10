## 0.2.0-beta.5 - 2026-06-10

### Changed

- Updated `mt_carplay` to `^1.5.0` (adds Android Auto alert/grid/tab-bar, message, and pane templates, `CPSearchTemplate`, and Flutter-asset SVG support).

### Breaking changes

- `mt_carplay` 1.3.0 renamed several CarPlay enums/classes to match Apple's API (e.g. `CPListItemAccessoryTypes` → `CPListItemAccessoryType`). Consumers referencing these `mt_carplay` types directly may need to update their imports.

## 0.2.0-beta.4 - 2026-02-27

### Added

- `asset:///` artwork URI support — bundled Flutter assets are automatically extracted to the cache directory for use in system notifications, Android Auto, and CarPlay.
- `androidNotificationOngoing` option in `MtAudioPlayerConfig` to control whether the Android notification is dismissible when paused (defaults to `false`).
- `onTaskRemoved` handler to clean up playback when the app is swiped away on Android.

### Changed

- `MtArtwork` widget now supports `asset://` and `file://` URI schemes in addition to network URIs, with resolution-aware image caching (`cacheWidth`/`cacheHeight`) and `gaplessPlayback`.

### Fixed

- Skip previous/next controls are now hidden in both system notifications and the `MtTrackSkipButton` widget when the queue contains a single item.

## 0.2.0-beta.3 - 2026-02-16

### Changed

- Replaced `MtAudioSource` sealed class (`MtSingleSource`, `MtPlaylistSource`, `MtLiveSource`) with two explicit methods on `MtAudioPlayer`: `setAudioItem(MtAudioItem)` and `setPlaylist(List<MtAudioItem>, {int initialIndex})`.
- Simplified internal playback state stream and added `.distinct()` to prevent redundant emissions.

### Fixed

- `ffRewindInterval` from `MtAudioPlayerConfig` is now correctly forwarded to system media controls (lock screen, notification, Android Auto, CarPlay). Previously, system-level fast-forward/rewind buttons used default intervals instead of the configured value.

### Breaking changes

- **Removed** `MtAudioSource`, `MtSingleSource`, `MtPlaylistSource`, and `MtLiveSource` classes.
- **Removed** `MtAudioPlayer.setSource(MtAudioSource)`.
- **Added** `MtAudioPlayer.setAudioItem(MtAudioItem)` -- replaces `setSource(MtSingleSource(...))` and `setSource(MtLiveSource(...))`.
- **Added** `MtAudioPlayer.setPlaylist(List<MtAudioItem>, {int initialIndex})` -- replaces `setSource(MtPlaylistSource(...))`.

#### Migration

```dart
// Before
await player.setSource(MtSingleSource(item: track));
await player.setSource(MtLiveSource(item: stream));
await player.setSource(MtPlaylistSource(items: tracks, initialIndex: 2));

// After
await player.setAudioItem(track);
await player.setAudioItem(stream);
await player.setPlaylist(tracks, initialIndex: 2);
```

## 0.2.0-beta.2 - 2026-02-13

Reclassified `mt_audio` as a beta release while testing is ongoing.

### Changed

- Updated package version to `0.2.0-beta.2`.
- Updated README wording from production-ready to beta.
- Updated GitHub workflow branch references from `master` to `main`.

### Breaking changes

- None.

## 0.1.0 - 2026-02-12

Initial public release of `mt_audio`.

### Added

- Streams-based audio player facade (`MtAudioPlayer`) with synchronous getters.
- Background playback support with system media controls via `audio_service`.
- Queue management (set source, add/insert/remove/reorder, skip, clear).
- Playback controls (play/pause/stop/seek, fast-forward/rewind).
- Playback modes (repeat, shuffle), speed control, and volume control.
- Audio session handling for interruptions and becoming-noisy events.
- Optional Android Auto integration via delegate pattern.
- Optional Apple CarPlay integration via delegate pattern and handler.
- Reusable UI widgets for controls, seek bar, queue, speed, artwork, and now-playing info.
- Example application demonstrating package setup and usage.

### Breaking changes

- None.
