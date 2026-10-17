# Exact framework feedback

App: Exact Recorder. Framework revision: `ca66702c8f`. Platform: macOS. Session: October 16, 2026.

## What worked

- The external-app scaffold maintained the sibling checkout dependency without copying or modifying framework code.
- The existing recorder example and native-view recipe established the native-module interface quickly. `native.watch`, `native.call`, and `native.later` let the Contract UI follow native recording state without polling from TypeScript.
- `ExactModule.willQuit` provides a useful asynchronous finalization hook. `context.after` lets the same timer follow real time in the app and virtual time in authored tests.
- Device grants plus localized purpose strings produced the macOS microphone permission declaration without manual Info.plist edits.
- Native builds succeeded. Two authored macOS tests passed; initial hardware recordings exposed a format-conversion bug despite passing simulated tests. The corrected capture path produced a 48 kHz, 24-bit Shure WAV whose voice the user confirmed was clear. The user confirmed floating controls were visible and Mac playback remained normal with the Shure selected.

## Improvements supported by this session

### Give macOS the same verification entry point

Observed: `bun exact.mjs verify --help` advertises only web and iOS. Running `agent macos ... 'check both'` failed with `check: the web and iOS hosts carry it, not macos`. Separate `test macos` and screenshot commands worked.

Suggestion: implement `verify macos`, including accessibility/layout checks, appearance variants, and relaunch persistence. Until then, print a macOS-specific completion checklist in generated app instructions rather than unconditionally recommending `verify`.

### Explain native device tests as two distinct checks

Source-confirmed: the framework recorder example substitutes microphone input under `context.agent`. This app follows that convention. Its authored tests can pass without exercising physical devices or the floating NSPanel.

Suggestion: label substituted capabilities in test reports and document a separate opt-in hardware smoke workflow. The report should distinguish real file output, simulated device input, native OS dialogs, and external windows. A generic green result should not imply microphone capture was exercised.

### Expand the recorder recipe around desktop needs

Source-confirmed: the bundled recorder example uses the default microphone and app-private storage. This app needed app-owned Swift for microphone discovery/selection, a folder panel and persisted bookmark, pause/resume, and a floating recording panel.

Suggestion: add a desktop recorder recipe covering those capabilities, AVFoundation completion callbacks, pause-excluded duration, device-disconnect errors, and quit-time finalization. Prefer a reusable example/module over adding recording-specific concepts to Contract.

### Make the distinction between test builds and desktop bundles explicit

Observed: `test macos` rebuilt the standalone executable but left the existing `.app` bundle unchanged. Launching that bundle tested older native code. An explicit `mac --bundle` refreshed its native module library.

Suggestion: print both executable and bundle freshness after native tests, and provide a single build/test/launch command that guarantees the launched app contains the tested source.

### Show scaffold progress

Observed: `exact new` produced no output while its initial Contract compiler Cargo build ran. Process inspection showed `cargo build -q ... -p contract`; the scaffold directory appeared only after that completed.

Suggestion: print the current prerequisite and elapsed progress before starting silent compilation, and distinguish scaffold creation from environment checks. The final command did give useful next steps and a missing-Chrome notice.

### Keep native screenshots representative

Observed: a real app screenshot showed the title in the toolbar only. The default macOS agent screenshot also painted an inline `Exact Recorder` heading below the toolbar. The same authored UI was involved.

Suggestion: make the driver default match the shipping native chrome, or clearly document the required chrome option on macOS. This observation is a parity lead, not a diagnosed rendering defect.

## Application limits and verification

- Contract compilation completed with zero diagnostics; strict TypeScript checking passed.
- Native build and two authored macOS tests passed after simplification.
- Authored tests verify paused virtual time is excluded from the timer, resumption continues it, and stopping while paused saves successfully.
- A second live Shure take held its timer at 00:06 during a measured 23.9-second pause. After resuming, the timer ended at 00:24 and the WAV contained 24.30 seconds. Its mean level was -27.2 dB and peak -1.8 dB, without clipping.
- Real recordings were inspected with `afinfo`: 37.397333 and 40.864 seconds, mono, 48 kHz, 16-bit PCM. These early metadata checks did not prove valid audio: several files were silent or distorted. A later corrected Shure recording at 22:16:36 measured mean -31.7 dB and peak -9.5 dB, and the user confirmed clear voice playback.
- The user's confirmation establishes the floating bar was visible and playback sounded normal with the Shure selected. Bluetooth headset microphone/output quality was not tested.
- No framework source changes or external feedback submissions were made.

## Hardware capture finding

The Shure initially delivered Float32 buffers, then switched to 24-bit signed samples stored high-aligned in four bytes. Raw input measured approximately -69 to -65 dB RMS, but the automatic WAV writer produced clipped noise near -7.6 dB RMS. Removing output settings did not resolve it. The app now uses `AVCaptureAudioDataOutput`, decodes each buffer using its actual format description, rebuilds its converter when that format changes, and writes normalized samples through `AVAudioFile`. A regression test checks both format-transition directions and the saved WAV waveform.

The capture startup can still emit Core Audio converter diagnostics internally. The corrected writer produced healthy samples and user-confirmed clear voice; absence of OS diagnostics is not claimed.

## Why the first interface was weak

The initial screen accumulated features in a loose column. Its timer, settings, inactive controls, explanatory paragraphs, and saved-file actions competed for attention. Native widgets supplied platform behavior, but did not supply an information hierarchy or a coherent composition. The implementation treated visual design as a finishing pass and accepted the screen too early.

Exact's existing content-design guidance already recommends one focal point, grouped settings, and suitable content components. The failure was partly in applying that guidance. More instructions saying "make it beautiful" would not have fixed this. The useful change is an explicit visual acceptance step: choose the platform pattern and primary action before layout, inspect the actual pixels in each important state, and revise visible weaknesses before delivery. Passing state assertions does not establish good visual design.

The redesign uses a compact utility layout with system typography, a tabular timer, a meter driven by actual microphone levels, and state-specific controls. Microphone and destination are grouped together. Saved-file actions live in one result card. The single-screen app no longer declares a navigation stack or displays a disabled Back button. Persistent instructional paragraphs were reduced to contextual help. The floating panel was reduced from 430 by 60 points to 310 by 52, with a status dot, timer, pause/resume symbol, Finish, and a separate cancel symbol.

The manifest now defaults to a 440 by 600 content area. macOS retains a previous user's window frame, so an existing installation can remain larger. This redesign does not erase that preference.

## Making the improved default repeatable

- Shared agent instructions now require first-pass composition and actual rendered visual review. Project instructions specify this app's hierarchy, state checks, and the separate desktop-bundle build step.
- A reusable desktop utility pattern would help Exact users start with appropriate density, grouped settings, state-dependent actions, and a result area. This belongs in examples and recipes first; it does not require recording-specific concepts in Contract.
- A macOS verification command should capture a state gallery at default and minimum sizes in both appearances, identify which build was launched, and make auxiliary native windows inspectable. Screenshot review still requires judgment about clarity and composition.
- Native screenshots should distinguish key-window and inactive-window presentation. The round button was gray in background captures, but red when the real window became active. This was normal AppKit appearance, not a missing-tint defect, and no framework workaround was added.

Verification after redesign: Contract compilation returned zero diagnostics, three authored macOS flows passed, and the desktop bundle was rebuilt and relaunched. Idle, recording, paused, and saved states were captured; light, dark, and 380-point-wide layouts were inspected. A real Shure session exercised record, pause, resume, and cancel, returning to idle. The capture converter and WAV writer were unchanged. This pass did not repeat the listening comparison, force a hardware error state, or obtain a separate screenshot of the floating panel through the computer-use tool. The panel compiled, but its revised presentation remains a visual verification limit.

No framework source edits, vendor patches, or generated-launcher edits were made for this redesign.
