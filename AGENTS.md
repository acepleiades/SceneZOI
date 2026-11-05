# Working on SceneZOI

## Repository purpose

This repository is for framework contributors, mod authors and developers building
forks in the inZOI ModKit. Read [README.md](README.md),
[CONTRIBUTING.md](CONTRIBUTING.md) and the relevant subsystem documentation before
changing its contract. Use [developer setup](docs/installation.md) and
[development](docs/development.md) for build prerequisites and native workflows.

Current source contracts and validation reports take precedence over dated
investigation notes. Consult relevant existing tests and the concise
[issue ledger](docs/investigations/runtime-and-ui-issues.md) when investigating a
known subsystem. Do not front-load every historical document.

## Ownership and release scope

- SceneZOI owns the reusable runtime, participants, placement, playback,
  navigation, outfits, attachments, expressions, gaze, audio, tasks, transitions,
  completion responses, furniture and UI. Keep it all-ages and free of adult
  geometry or content-pack-specific runtime logic.
- Content packs own their assets and inert JSON. Gameplay integrations own
  availability decisions, persistence and consequences. Independent add-ons use
  the public native-message API and SDK; private runtime modules are not that API.
- The first release supports one active session with a controlled initiator and
  fixed participants. Concurrent/NPC-autonomous sessions and predetermined
  watch-only sequences are deferred. Do not expand that scope without a request.
- Preserve unrestricted manual Start entry together with technical eligibility,
  role/participant compatibility and furniture availability checks. Roles remain
  distinct from body type and control status; reusable subsystems support 2+
  participants, repeated bodies and independent resource ownership.

HZoi's production checkout is private and contains proprietary audio. Its separate
public [HZoi-Reference](https://github.com/acepleiades/HZoi-Reference) copy provides adult-content authoring examples
with silent audio. Start with [worked examples](docs/content-examples.md) for
feature-to-file mappings and pinned source links. The reference is optional and
reference-only, with no repository-wide license; it is not an executable add-on.
Keep SceneZOI's default build/tests independent of it. Never copy original HZoi
audio or content-pack-specific assets/runtime logic into SceneZOI. When adding
examples, distinguish complete files from excerpts and measured asset-specific
values from reusable contracts. Verify source links against the referenced
revision; do not infer runtime or visual acceptance from the example's existence.

## Source layout and contracts

- Authoritative Lua: `modkit/SceneZOI_93C44199/workspace/lua/`.
- UI: `modkit/SceneZOI_93C44199/ui/`. Public add-on SDK: `sdk/`.
- Framework declarations: `packs/`. Author one scene per JSON file; manifests
  specify scene directories collected by the build. Do not recreate `demo/` or
  `prototype/` source trees.
- Enabled native packages contribute their own inert `Text_UI` JSON patches;
  retail discovery uses `Text`. No author whitelist, executable content-pack
  registration or discovery limited to SceneZOI's package.
- Use localization declarations/formatters for player-facing text; consult
  `docs/localization.md`. Keep identifiers, metadata dictionaries and diagnostics
  untranslated. English fallback must work without optional packs.
- Preserve game animation instances, the native picker/input handshake,
  session-owned original snapshots and independent cleanup/retry behavior. Never
  introduce Smart Zoi toggling.
- For unreleased contract changes, update author data, SDK/API docs and tests;
  remove replaced code instead of retaining obsolete compatibility paths. Preserve
  existing user settings, personality preferences and attribution during updates.

## Checks and evidence

Run applicable checks from the repository root using the available ModKit root:

```powershell
python tools/build_catalog.py
python tools/test.py --modkit-root "C:/Path/To/inZOIModKit"
```

The default build/tests must work independently of any private content checkout.
Use `--content-root` only when a compatible external author checkout is available
and its integration checks are relevant. Each content owner has its own native
project and asset inventory; see [package ownership](docs/package-split.md).

Start with logs and narrow reproductions. Make the smallest sound fix and retain
meaningful regression coverage where warranted. Repeat checks only after relevant
changes or failures. Documentation-only or byte-identical source relocations do
not require native rebuilding/reinstallation. Check links, examples and formatting.

Keep automated results, native diagnostic evidence and visual/audible acceptance
distinct. Record applicable runtime/UI/data changes and measured evidence in
`validation.json`; update the issue ledger for distinct resolved/deferred bugs.
Keep raw probes, private paths and proprietary dumps outside public documentation.
If native tools or asset inputs are unavailable, run independent checks and state
what remains unverified.

## Native builds and requested in-game tests

Discover the actual checkout, registered native project and ModKit paths from the
current environment or user. Do not assume a maintainer's drive letters, username,
sibling repositories or authorization to modify another installation.

For native changes, synchronize owned sources/declarations to the registered
working project while preserving unrelated work. Prepare Lua, verify it against
`workspace/lua/`, and validate Lua/UI in ModKit. Native binary asset inputs are
separate from the source checkout; do not invent missing assets or metadata.

Package through supported `PackageUGC` with a fresh isolated
`-ExportToGameMods` directory, avoiding the default raw export into the game Mods
root. Verify AutomationTool exit 0 and `BUILD SUCCESSFUL`, then run the exact
owned-payload filter. Raw exports can include referenced Game/Engine assets and
must never be installed or distributed as candidates.

When an installed test build is requested or already authorized, finish the
verified installation; packaging alone does not complete that request. Check the
game/session state first and avoid interrupting active scenes or house editing.
Mounting or unmounting even a separate diagnostic Lua mod can unload existing
Lua sessions. Perform all mount/unmount/reload operations only while idle.
Verify diagnostic files byte-for-byte: one native write-file route reported
success after truncating a longer script to 2047 bytes.

Cooked-container replacement requires the game closed. Back up outside Mods,
preserve settings/preferences/credits, update only owned payloads and verify
installed hashes. Use the established idle hot-update path only when appropriate,
preserving loaded cooked bytes. Do not infer live acceptance from installation.

Locate installed packages and persistent cfg data separately. In the observed
retail setup, a package installed directly under `Mods/<mod_id>/` writes cfg data
under `Mods/InGame/<mod_id>/`. A data-only directory without `mod_manifest.json`
is not a duplicate installation. Back up both locations as applicable; preserve
settings/recovery data and do not assume removing a package folder resets cfg.
The supported `uimod.cfg_*` API chooses this output location and exposes no
base-directory override; SceneZOI supplies only the mod ID, section and key/value.
Do not mistake that native storage behavior for a hardcoded framework path.

Before declaring a player release tested, install the exact distributable ZIP in
a fresh mod directory and launch a fresh game process. Back up existing installs,
settings and recovery data outside Mods first; do not carry development cfg files
into this clean test. Verify automatic startup, Start entries, playback and Exit
without diagnostic seeding, manual mounting or hot reload. Also retain separate
update tests with existing preferences. A restart with old cfg is not a first
installation test.

SceneZOI 1.0 missed this distinction: native `cfg_load` rejects absent keys, while
the UI fixture returned empty success and development cfg masked the missing
request mailbox. Initialize required mailboxes before readiness; cache completed
host identity only after acknowledgement succeeds and retry transient failures.
Retain [entry](tests/entry.lua) and [receiver](tests/demo-entry.cjs) regressions.
See the [recorded cause and acceptance](docs/validation/fresh-install-startup-20261105.json).

A customer 1.0.2 snapshot contained an invalid `-1` registry entry while the
controlled ID was absent. Do not assume Zoi `on_begin` guarantees an assigned ID:
retry each initially unassigned actor until ready, and retain its registered ID
for teardown after a native reset. Keep the multi-actor/teardown regression in
[actor registration](tests/actor-registration.lua). This observed weakness is not
yet established as the complete cause of that customer's failure.

HZoi's original body profile mistakenly treated Supponpon's `Material_018` slot
name as stock. Stock uses `shader_body_shader18` at the same index. Always test
body-region profiles without replacers as well as with replacements. Body-profile
schema 2 declares section/coverage mapping and patch resources, without mesh or
participant-material name lists. Share current-section readiness checks across
preparation and clothing/active guards. Replacers preserving that mapping work
without registration; differently partitioned geometry is not automatically mapped. See the
[generic section checkpoint](docs/validation/generic-body-region-20261105.json).

Preserve existing uncommitted work. Do not commit, push, tag or publish without an
explicit instruction. Preserve [LICENSE](LICENSE), GPL-3.0-only attribution and
the README reminder that forks must comply with applicable ModKit terms as well.
