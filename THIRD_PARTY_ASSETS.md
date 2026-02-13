# Third-Party Sample Assets

This document covers third-party assets used by the `mt_audio` example app.

## 1) SoundHelix audio examples

- Source: `https://www.soundhelix.com/audio-examples`
- Used in: `example/lib/sample_data/sample_data.dart`
- Current usage:
  - `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3`
  - `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3`
  - `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3`
  - `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3`
  - `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3`
- Reported usage note on the SoundHelix examples page: audio examples may be used if credit is given to SoundHelix and the artist of the respective song.

Attribution used in sample metadata:
- Artist: `T. Schürger`
- Album/source label: `SoundHelix`

## 2) Public Domain Radio live streams

- Source: `http://radio.publicdomainproject.org/en/index.html`
- Used in: `example/lib/sample_data/sample_data.dart`
- Current usage:
  - `http://relay.publicdomainradio.org/classical.mp3`
  - `http://relay.publicdomainradio.org/jazz_swing.mp3`
  - `http://relay.publicdomainradio.org/swiss_schlager.mp3`

Observed stream metadata indicates:
- "free music from publicdomain.ch"

## 3) Unsplash images

- Source license: `https://unsplash.com/license`
- Used in: `example/lib/sample_data/sample_data.dart`
- Current usage domain: `https://images.unsplash.com/...`

Unsplash license summary (as published at time of review):
- Images can be downloaded and used for free (commercial and non-commercial).
- Attribution is appreciated but not required.
- Not permitted: compiling images to replicate a competing image service.

## 4) Package screenshots in /assets

- Files:
  - `assets/home.png`
  - `assets/queue.png`
  - `assets/widgets.png`
  - `assets/carplay_menu.png`
  - `assets/carplay_now_playing.png`
- These screenshots are project assets generated from the example app UI.
- If any screenshot contains third-party marks/logos/content, verify that redistributable rights are in place before publication.

## Notes

- The example app intentionally avoids third-party radio stream services with restrictive embedding/rebroadcast terms.
- Re-check upstream terms before each public release, as third-party policies can change.
