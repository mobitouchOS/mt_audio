# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

`mt_audio` is a standalone Flutter module providing a streams-based audio playback API with background playback, system notifications, queue management, and optional Android Auto / Apple CarPlay integration. 

**Core stack:** `just_audio` + `audio_service` + `audio_session` + `rxdart` + `mt_carplay` + `equatable`

## Commands

```bash
# Get dependencies (from module root)
flutter pub get

# Run static analysis
dart analyze .

# Run example app (from example/ directory)
cd example && flutter run

# Build example for iOS
cd example && flutter build ios --debug
```

There are no tests, code generation, or build_runner steps in this module.

## Architecture

### Layer Diagram

```
┌─────────────────────────────────────────────────────┐
│  Consumer App (uses MtAudioPlayer + widgets)        │
└─────────────┬───────────────────────────────────────┘
              │ public API
┌─────────────▼───────────────────────────────────────┐
│  MtAudioPlayer (facade)                             │
│  - Exposes BehaviorSubject streams (distinct)       │
│  - Synchronous getters for current state            │
│  - Delegates all operations to handler              │
└──────┬──────────┬───────────────────┬───────────────┘
       │          │                   │
┌──────▼──┐ ┌────▼─────────┐ ┌──────▼──────────────┐
│ Handler │ │ SessionMgr   │ │ CarPlayHandler       │
│ (internal)│ │ (internal)  │ │ (public for access)  │
└──────┬──┘ └──────────────┘ └──────────────────────┘
       │
  just_audio + audio_service
```

### Key Design Decisions

1. **Single facade pattern**: `MtAudioPlayer` is the only class consumers instantiate. Created via `MtAudioPlayer.init()` (async factory). All internal classes (`MtAudioHandler`, `MtAudioSessionManager`) are not exported.

2. **Streams-only state**: All state is exposed via `BehaviorSubject` streams from rxdart. No Riverpod, BLoC, or other state management dependency. Consumers wire it to whatever they use.

3. **Delegate pattern for car integrations**: Both Android Auto and CarPlay use abstract delegate classes (`MtAndroidAutoDelegate`, `MtCarPlayDelegate`) that the consumer implements. Delegates are provided via factory functions in `MtAudioPlayerConfig` that receive the `MtAudioPlayer` instance, solving the circular dependency (handler needs delegate, delegate needs player).

4. **Late binding for Android Auto**: Internally uses `LateBindingAndroidAutoDelegate` because `AudioService.init()` requires the handler before the player exists. The real delegate is bound after player creation. This is invisible to consumers.

5. **CarPlay uses `mt_carplay`**: `MtCarPlayHandler` manages the connection lifecycle, navigation stack (max 5 deep), template rendering (list + grid + tab bar), and automatic playback state sync via player streams.

6. **Sealed class for audio sources**: `MtAudioSource` is a sealed class with three variants: `MtSingleSource`, `MtPlaylistSource`, `MtLiveSource`.

7. **`MtAudioItem` ↔ `MediaItem` conversion**: `MtAudioItem` stores URI, headers, and `isLive` flag in the `extras` map of `MediaItem` for round-trip conversion. The `uri` field is stored as `extras['uri']`, not `MediaItem.id`.

### File Organization

- `lib/mt_audio.dart` — barrel export (defines public API surface)
- `lib/src/player/` — `MtAudioPlayer` facade + `MtAudioPlayerConfig`
- `lib/src/handler/` — `MtAudioHandler` (bridges just_audio ↔ audio_service, includes Android Auto mixin)
- `lib/src/session/` — `MtAudioSessionManager` (audio interruptions, becoming noisy)
- `lib/src/models/` — immutable data classes using `Equatable`
- `lib/src/widgets/` — pre-built UI components using `StreamBuilder`, organized by category (controls, seek_bar, speed, queue, player_info)
- `lib/src/android_auto/` — delegate interface + mixin + late-binding wrapper
- `lib/src/carplay/` — delegate interface + handler + item types
- `example/` — standalone Flutter app demonstrating all features

### Public vs Internal

**Exported** (in barrel file): All models, `MtAudioPlayer`, config, all widgets, Android Auto delegate, CarPlay delegate/handler/items.

**Not exported** (internal): `MtAudioHandler`, `MtAudioSessionManager`, `LateBindingAndroidAutoDelegate`, `MtAndroidAutoHandler` mixin.

### Shuffle Implementation

Queue state tracks `shuffleIndices` separately. `MtAudioHandler.getQueueIndex()` computes the effective queue index by inverting the shuffle indices mapping. When toggling shuffle, the handler preserves the current `MediaItem` to prevent UI flicker during the state transition.

## Conventions

- Uses `very_good_analysis` linter rules with relaxed settings: no 80-char line limit, no public API docs requirement, trailing commas preserved
- All model classes extend `Equatable`
- Sealed classes for type-safe variants (`MtAudioSource`, `MtCarPlayItem`)
- All classes prefixed with `Mt` (Mobitouch namespace)
- Widgets take `MtAudioPlayer player` as required parameter
- The example app uses a simple `InheritedWidget` (`PlayerProvider`) — not Riverpod
