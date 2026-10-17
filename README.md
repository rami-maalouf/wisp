# Exact Recorder

A small macOS audio recorder built with Exact. Choose a microphone and destination folder, then record uncompressed WAV audio. Pause and resume keep one recording and exclude paused time. A draggable floating bar stays above other windows with the timer, Pause/Resume, End, and Cancel controls. Cancel works while recording or paused, stops microphone capture, moves only the current take to Trash, and resets the timer.

## Run

Requires the sibling `../exact2` checkout and its native build dependencies.

```sh
bun exact.mjs mac --run
```

To build without launching:

```sh
bun exact.mjs mac --bundle
```

The build prints the path to `Exact Recorder.app`. The microphone and destination folder are remembered between launches. Microphone permission is requested when recording starts. Stop or End finishes the WAV file before reporting it saved. Show in Finder reveals the last completed recording.

## Playback quality

The recorder captures only the selected microphone. It does not capture system output, enable microphone monitoring, change the default output device, adjust playback volume, or enable voice processing. It initially prefers the built-in microphone, then another non-Bluetooth microphone.

For normal headphone playback while recording, select the Mac microphone or a wired/USB microphone, such as a Shure MV7+. A Bluetooth headset used as both microphone and headphones may switch to its lower-quality two-way mode. This is a device/OS limitation; selecting a separate microphone avoids requesting that mode. [Apple's explanation](https://support.apple.com/en-us/102217).

## Implementation

- `app.contract`: Exact UI and recording controls.
- `app.ts`: typed bridge between Exact resources/mutations and native operations.
- `modules/apple/Recorder.swift`: recording state, folder selection, saved preferences, timer, and shutdown.
- `modules/apple/CaptureRecorder.swift`: sample-buffer capture, pause/resume, signal levels, and file finalization on a serial queue.
- `modules/apple/PCMNormalizer.swift`: conversion based on each buffer’s actual PCM layout, including USB microphone format changes.
- `modules/apple/RecordingBar.swift`: nonactivating floating AppKit panel.

The intended platform is macOS 14 or later. The generated web/iOS/Linux scaffolds are not supported recording targets; the web data source reports that recording requires macOS.

## Verification

```sh
bun exact.mjs contract build app.contract --json
bun exact.mjs test macos
swiftc modules/apple/AudioSignal.swift modules/apple/PCMNormalizer.swift tests/AudioSignalTests.swift -o .exact/audio-signal-tests
.exact/audio-signal-tests
bunx --package typescript tsc --noEmit --strict --target ES2022 --module esnext --moduleResolution bundler app.ts
```

Exact's agent mode supplies two simulated microphones and writes a synthetic WAV into isolated test storage. Tests exercise selection, control availability, timer pause/resume, stop while paused, and repeat recording. They do not prove physical microphone capture or floating-panel interactions.

After correcting a USB microphone format-conversion defect, live validation produced a 48 kHz, 24-bit Shure MV7+ WAV. Its peak was -9.5 dB and the user confirmed clear voice playback. The user confirmed the floating bar was visible and playback sounded normal with the Shure selected. See `docs/exact-experience.md` for framework feedback and remaining verification limits.

After changing native code, use `bun exact.mjs mac --bundle` before launching the desktop app. The test command updates its standalone test executable, not an existing desktop bundle. Stop and quit the app before replacing its bundle.
