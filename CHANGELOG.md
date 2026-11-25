## 0.2.0-beta.7 - 2026-11-25

### Changed

- `MtAndroidAutoDelegate.search` returns `List<MtMediaLibraryItem>` instead of `List<MtAudioItem>`. Return `MtBrowsableItem`s for albums, playlists or other folders: Android Auto shows them as folders in the search results and opens them through `getChildren`.

### Fixed

- Android Auto: the player background no longer flashes on every play/pause. The queue is sent to the media session only when its items change, not on every sequence-state event.
- CarPlay / Android Auto: "Previous" on the first item and "Next" on the last no longer reset the progress bar to 0:00 while the audio keeps playing. "Previous" restarts the current item when there is nothing before it or after 3 seconds of playback; "Next" on the last item does nothing. `LoopMode.all` still wraps around.

### Breaking changes

- `MtAndroidAutoDelegate.search` has a new return type. Wrap existing track results in `MtPlayableItem(item: …)`.

## 0.2.0-beta.6 - 2026-09-29

### Added

- `MtAudioPlayer.setAndroidAutoError(MtAndroidAutoError?)` shows sign-in / premium / app errors on Android Auto until playback starts.
- `MtAudioPlayer.notifyAndroidAutoChildrenChanged([parentMediaId])` makes Android Auto reload a browse node.
- `MtAudioPlayerConfig.androidBrowsableRootExtras` for browse root content-style hints and search support.
- `MtAndroidAutoDelegate.onPlayFromSearch(query)` handles "Hey Google, play … on <app>".
- Remote (`http`/`https`) artwork of browse and search items is cached and served to Android Auto via `content://`.
- Remote artwork downloads time out after 10 seconds and fall back to the original URL (retried on the next browse), so a stalled cover cannot block a browse list; only JPEG, PNG, GIF and WebP bodies are cached, under a matching file extension so Android Auto gets an image MIME type.
- An Android Auto error set while playing is held back until playback stops (including when the queue completes on its own) and cleared when playback next starts. While it is active and nothing plays, `playbackStateStream` reports `MtPlaybackStatus.error` on every platform.

### Changed

- Requires `mt_carplay` `^1.5.1` (CarPlay cold-start connection status).

### Fixed

- Android Auto delegate calls now catch every thrown object, not only `Exception`s, and log each failure with its stack trace.

### Breaking changes

- `MtAndroidAutoDelegate` gained `onPlayFromSearch`. Delegates declared with `implements` must add the method; delegates declared with `extends` are unaffected (it has a no-op default).

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
