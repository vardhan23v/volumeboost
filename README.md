# VolumeBoost

A small, free macOS app that makes your Mac **louder than its normal 100% maximum**: up to 400%.

macOS has no volume setting above 100%. VolumeBoost captures all of the Mac's sound, turns it up, and plays it on your speakers or headphones. A soft limiter rounds off the loudest peaks, so boosted sound stays clear instead of cracking.

## Requirements
- macOS 14.2 or newer
- Swift tools (Xcode or the Command Line Tools) to build it

## Build and run
```bash
./build.sh
open VolumeBoost.app
```

The first time it runs, macOS asks for permission to record system audio. Click **Allow**. If you missed the prompt, open System Settings → Privacy & Security → Screen & System Audio Recording and turn on VolumeBoost.

## Using it
- The window has a slider (100–400%) and an on/off switch for the boost.
- If you close the window, the app keeps running and a speaker icon stays in the menu bar. Click the Dock icon or the menu-bar icon to bring the window back.
- Quit with ⌘Q, or choose "Quit VolumeBoost" from the menu-bar icon. Your sound goes back to normal.
- On small laptop speakers, about 200–250% usually sounds best. Higher settings can rattle.

## How it works
1. A Core Audio **process tap** (`CATapDescription`, a global tap that excludes this app) captures all system audio and mutes the original sound.
2. A private **aggregate device** combines that tap with your current output device.
3. An IO callback multiplies each sample by the gain, then applies a `tanh` soft-knee limiter above about −1 dBFS.
4. When you switch output devices, for example by plugging in headphones, the app rebuilds the chain for the new device.

The code is in `Sources/VolumeBoost/`: `AudioTap.swift` handles the audio and `main.swift` builds the window and menu-bar UI.

## License
Copyright © 2026 Vallur Sree Vardhan. Released under the [GNU General Public License v3.0](LICENSE) or later.
