<!-- exact:begin (exact new writes this block; bun exact.mjs update rewrites it) -->
# exact-recorder: an Exact app

`app.contract` is the view, `app.ts` its data module, `app.test.contract` its tests, `app.json`
the manifest. The app uses the exact2 checkout at `../exact2` by path (`EXACT2`
overrides it).

This file is already in your instructions. Start from the nearest pattern: `bun exact.mjs
pattern` lists them and `pattern <name>` writes one, tested. ../exact2/docs/start-here.md is the guide,
the only required reading (LLP 1115 D7). When a name is in question, `bun exact.mjs contract
vocab <name>` answers it (no name: the card, which ../exact2/docs/card.md holds too). Run
`bun exact.mjs verify` when the features work, and `verify ios` once at the end for an iPhone
app. `bun exact.mjs help` lists the verbs, and your own in app.json `"commands"`.
`bun ../exact2/scripts/exact.mjs setup --check` names what a native build lacks.
The authoring diary: `bun exact.mjs feedback status` says whether this project keeps one.
Shared data: `exact new <path> --snapback`, or `bun exact.mjs snapback` here.
Install `snapback4@0.4.29` above; ../exact2/snapback4/README.md has setup and server commands.

Generated, so don't edit: `exact.mjs`, `rust-toolchain.toml`, `.cargo/config.toml`,
`Cargo.toml`'s `[patch.crates-io]` and this block.
<!-- exact:end -->

## Wisp naming

The app and repository are named Wisp (`wisp`). Keep the internal bundle identifier `com.rami.exact-recorder` stable to preserve existing permissions and preferences. The scaffold name in the generated block above is historical; do not manually rewrite that block.

## Recorder design and verification

- This is a compact native Mac utility. Use system typography and semantic colors. The timer and recording action are the focal point; microphone and destination belong in one settings group; saved-file actions belong together.
- Show Record when idle and Pause/Resume, Finish, and a secondary Cancel while active. Preserve visible state and accessible names for icon-only floating controls.
- Compile with `bun exact.mjs contract build app.contract --json`, then run `bun exact.mjs test macos`. These tests use simulated audio and do not exercise the physical microphone or floating panel.
- Build the desktop app explicitly with `bun exact.mjs mac --bundle` before relaunching. The test executable and desktop bundle are different outputs.
- Inspect idle, recording, paused, saved, and error states at the default and minimum window sizes. Check light and dark appearances using the agent's preference controls; inspect the real bundled app and floating panel too. Do not interrupt an existing recording to relaunch.
- Use `--chrome platform` for native agent screenshots. The current framework has no `verify macos` command. Do not interpret web verification or passing state assertions as visual approval.
