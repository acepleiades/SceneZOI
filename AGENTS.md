# Working on SceneZOI

This repository is for framework contributors, mod authors and ModKit developers.
Read only the [subsystem docs](docs/README.md), source and tests relevant to the
task. For a reported bug, start with logs, a narrow reproduction and the
[issue ledger](docs/investigations/runtime-and-ui-issues.md). Use current source
contracts and validation evidence when older investigation notes differ.

## Contracts to preserve

- SceneZOI owns reusable runtime, playback, presentation and UI. Keep it all-ages
  and free of content-pack-specific assets or logic. Packs supply inert JSON and
  assets. Gameplay add-ons own availability decisions, persistence and consequences
  through the [public API and SDK](docs/addons.md).
- Keep default builds and tests independent of private content. Use the optional
  [HZoi-Reference examples](docs/content-examples.md) when relevant. The reference
  has muted audio and separate asset rights. Keep its assets and original HZoi audio
  out of SceneZOI.
- Keep one active session with a controlled initiator and fixed participants.
  Concurrent sessions, autonomous NPC starts and watch-only sequences are deferred.
  Preserve manual Start without relationship or progression gates, alongside technical
  eligibility, role compatibility and furniture availability. Roles are independent
  of body type and control status. Reusable subsystems support 2+ participants,
  repeated body types and independent resource ownership.
- Preserve native animation instances, the picker and input handshake, session-owned
  snapshots, independent cleanup and retries. Never toggle Smart Zoi.
- Discover enabled packages through their native `Text_UI` patches (`Text` in
  retail). Keep one scene per JSON file and use manifest scene directories.
  Do not add an author whitelist or executable pack registration.
- [Localize player-facing text](docs/localization.md) with an English fallback.
  Keep identifiers, metadata dictionaries and diagnostics untranslated.
- Preserve released API and schema contracts unless a breaking change is agreed.
  Update affected documentation, examples and checks. Remove obsolete internal
  paths once they no longer serve a supported contract.

## Source and checks

- Authoritative Lua and bindings live in
  `modkit/SceneZOI_93C44199/workspace/lua/`. Prepared `lua/` is build output.
- UI lives in `modkit/SceneZOI_93C44199/ui/`, declarations in `packs/`, and the
  public SDK in `sdk/`.

Keep fixes focused and add regression coverage when existing checks miss the
failure. Run applicable checks once after relevant changes. For source and
declaration changes, use the repository's standard checks as applicable.

```powershell
python tools/build_catalog.py
python tools/test.py --modkit-root "C:/Path/To/inZOIModKit"
```

Use `--content-root` only for relevant checks with an available, compatible
checkout. For docs-only edits, verify links, examples and formatting without
rebuilding or reinstalling the mod.

## Native testing and releases

Follow [development and packaging](docs/development.md) when building, installing
or validating in-game. Locate the actual native project and game paths.
Synchronize owned sources, prepare Lua, verify source bytes and validate in ModKit.

- Use a fresh isolated `PackageUGC` export. Check the actual exit code and
  `BUILD SUCCESSFUL`, then apply the exact owned-payload filter before installing
  or distributing. Raw exports can contain referenced Game/Engine assets.
- Check game state first. Mount, unmount or hot reload only while idle. Verify
  native-written diagnostic files before use. Close the game before replacing
  cooked containers. Back up package and cfg data separately outside Mods,
  preserve preferences, settings and attribution, and verify installed hashes.
- After any Lua reload or temporary Lua mod mount/unmount, verify the manual
  launcher before testing Start. Follow the [hot-update readiness checks](docs/development.md#hot-update-readiness)
  to recover stale UI acknowledgements or a missing Zoi registry.
- For a player release test, install the exact ZIP in a clean directory without
  old cfg. Verify automatic loading, Start, playback, Exit and re-entry after
  a fresh launch without diagnostic seeding, manual mounting or hot reload. Keep
  update testing with existing preferences separate.
- Record relevant measured changes in [validation.json](validation.json) and
  distinct bugs in the issue ledger. Separate automated checks, native readbacks
  and visual or audible acceptance. State any verification gaps and keep private
  paths, logs and proprietary data out of public reports.

Preserve existing uncommitted work. Commit, push, tag or publish only when
explicitly requested. Preserve the [GPL-3.0-only license](LICENSE), attribution
and the README's ModKit terms notice.
