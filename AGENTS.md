<!-- exact:begin (exact new writes this block; bun exact.mjs update rewrites it) -->
# exact-recorder: an Exact app

`app.contract` is the view, `app.ts` its data module, `app.test.contract` its tests, `app.json`
the manifest: set its `app.name` and `app.id` before the first build. The app uses the exact2
checkout at `../expo-exact` by path (`EXACT2` overrides it).

This file is already in your instructions. Start from the nearest pattern: `bun exact.mjs
pattern` lists them and `pattern <name>` writes one, tested. ../expo-exact/docs/start-here-site.md (a site) or
../expo-exact/docs/start-here.md is the only required reading. `bun exact.mjs contract vocab <name>` answers a
name (none: the card); `bun exact.mjs docs <heading words>` a guide's
section. Run `bun exact.mjs verify` when the features work, and `verify ios|android` at the end for a
phone app. When an iPhone app is ready for the person to try, run `bun exact.mjs share` and give
them the link it prints; run it again after each change they should see. `bun exact.mjs help` lists the verbs, and your own in app.json `"commands"`.
`bun exact.mjs update` refreshes files. `bun exact.mjs lock` repairs Cargo lock drift.
`bun exact.mjs update --without linux` stops shipping Linux.
`bun ../expo-exact/scripts/exact.mjs setup --check` names what a native build lacks.
Shared data: `exact new <path> --snapback`, or `bun exact.mjs snapback` here.
Install `snapback4@0.4.33` above; ../expo-exact/snapback4/README.md has setup and server commands.

Generated, so don't edit: `exact.mjs`, `rust-toolchain.toml`, `.cargo/config.toml`,
`Cargo.toml`'s `[patch.crates-io]` and this block.

## Feedback (required)

When a doc was wrong or missing, a workaround was needed, something took several tries or a
command confused you, record it: `bun exact.mjs feedback note "<what happened>"`. It attaches
exact2's commit and the last exit code, never output or code. `bun exact.mjs feedback status` says
whether notes are sent and whether to keep a diary; under `never`, skip all of this.
<!-- exact:end -->

## Wisp naming

The app and repository are named Wisp (`wisp`). Keep the internal bundle identifier `com.rami.exact-recorder` stable to preserve existing permissions and preferences. The scaffold name in the generated block above is historical; do not manually rewrite that block.

## Recorder design and verification

- Wisp's turquoise palette is defined in `app.tamber`; use its brand and surface tokens for branded UI. Keep `brand.fill` consistent with the native `AccentColor` catalog and manifest theme color. Errors, warnings, and recording status retain their semantic colors. Logo sources and generation prompts live in `assets/`.
- This is a compact native Mac utility. Use system typography and semantic colors. The timer and recording action are the focal point; microphone and destination belong in one settings group; saved-file actions belong together.
- Show Record when idle and Pause/Resume, Finish, and a secondary Cancel while active. Preserve visible state and accessible names for icon-only floating controls.
- Compile with `bun exact.mjs contract build app.contract --json`, then run `bun exact.mjs test macos`. These tests use simulated audio and do not exercise the physical microphone or floating panel.
- Build the desktop app explicitly with `bun exact.mjs mac --bundle` before relaunching. The test executable and desktop bundle are different outputs.
- Inspect idle, recording, paused, saved, and error states at the default and minimum window sizes. Check light and dark appearances using the agent's preference controls; inspect the real bundled app and floating panel too. Do not interrupt an existing recording to relaunch.
- Use `--chrome platform` for native agent screenshots. The current framework has no `verify macos` command. Do not interpret web verification or passing state assertions as visual approval.
