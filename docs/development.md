# Development, validation and packaging

Start with [developer setup](installation.md) for prerequisites, the native working
project and animation inputs. Authoritative Lua lives in
`modkit/SceneZOI_93C44199/workspace/lua/`; prepared `lua/` is a build product.
UI source lives in `modkit/SceneZOI_93C44199/ui/`.

## Source checks

Run from the repository root:

```powershell
$modkitRoot = "C:/Path/To/inZOIModKit"
python tools/build_catalog.py
python tools/test.py --modkit-root $modkitRoot
```

The default build stages ten framework declarations: one scene pack with five
neutral nodes, five furniture profiles, two metadata dictionaries, one facial
pose and one localization dictionary. The framework inventory owns four animation packages. Default checks are
framework-only; `--content-root` is an optional test hook for a compatible author
checkout that is already available. HZoi's private checkout is not required.
The public [HZoi-Reference guide](content-examples.md) explains its separate
silent-audio example and optional content checks.
External packs can use `--packs` and `--project`, with their own `--inventory`
and `--plugin` arguments for filtering.

Each scene is one JSON object under `packs/scenezoi/scenes/`. A manifest's
`scene_directory` expands into the runtime nodes array. Invalid or conflicting
inputs fail before generated declarations change. Runtime discovers enabled
packages through native `Text_UI` patches enumerated as `Text` in retail; loose
repository JSON files are authoring inputs.

Expression, facial-pose, audio, task and furniture definitions use the same inert
declaration transport. The animation importer separately checks source hashes,
skeletons and duration. `SCENEZOI_SOURCE_ROOT` selects an author root and
`SCENEZOI_SKELETONS` supplies additional skeleton paths as JSON. Pack-specific
asset defaults belong in the pack's inputs.

## Native validation

Synchronize source and generated declarations to the registered working project,
preserving unrelated work. Prepare Lua and verify its bytes against
`workspace/lua/`. Validate the full Lua workspace and both UI apps in ModKit.

For MCP-assisted development, the ModKit exposes `modkit_validate_lua_script` and
`modkit_validate_uimod`. Keep diagnostics with the change and fix validation errors
before packaging. Source checks, native diagnostics and in-game visual/audible
acceptance are separate forms of evidence.

## Isolated packaging

Use supported `PackageUGC` with an explicit, fresh export directory outside the
checkout. The default packaging action can also export a raw duplicate into the
game's Mods directory; an isolated `-ExportToGameMods` avoids that side effect.

```powershell
$nativeProject = Join-Path $modkitRoot "inZOIModKit/Mods/SceneZOI_93C44199"
$buildRoot = "C:/SceneZOI-builds/my-change"
$exportRoot = Join-Path $buildRoot "raw"
$filteredRoot = Join-Path $buildRoot "filtered"

& "$modkitRoot/Engine/Build/BatchFiles/RunUAT.bat" PackageUGC `
  -Prepare=true -ugc_cook -TargetPlatform=Windows -Migration `
  "-StagingDirectory=$nativeProject" "-ExportToGameMods=$exportRoot" `
  -nocompileeditor -skipbuildeditor -installed -NoCompile `
  -NoZenDDC -ddc=NoZenLocalFallback -nocompile -nocompileuat

if ($LASTEXITCODE -ne 0) { throw "Native packaging failed." }

python tools/filter_package.py "$exportRoot/SceneZOI_93C44199" `
  "$filteredRoot/SceneZOI_93C44199" --modkit-root $modkitRoot
```

Use a new build directory for each attempt. Check the actual AutomationTool exit
code and `BUILD SUCCESSFUL`; `packaging_started` or a ZIP's existence is only an
acknowledgement or intermediate artifact.

The exact owned-payload filter checks the four inventoried framework packages,
excludes referenced Game/Engine assets, preserves declared dependencies and
verifies a registry-only companion pak. Use its filtered output for local testing
and distribution. Each independent content pack supplies its own inventory and
required attribution. Raw packaging output is not an acceptable candidate.

Lua/data-only add-ons can have an empty owned-asset inventory, no IoStore container
and an empty `mod_assethash.json`. Their filter path validates an exact non-asset
file allowlist and rejects cooked/native payloads. Keep native-generated protection
and checksums; do not fabricate them by copying an editable Lua scaffold.

## In-game validation

Test against a disposable save and a known package configuration. Check current
game/session state before interacting. Preserve local settings, expression/voice
preferences and attribution when testing an updated package, and keep rollback
copies outside the game's Mods directory. Verify candidate-to-test-copy hashes. Preserve ModKit-generated protection and
integrity metadata; do not assume its checksum strings are plain MD5 hashes of
exported bytes. Use explicit byte hashes to compare candidates and installed files.
Close inZOI before replacing cooked containers.

Reproduce narrowly, start with logs and relevant subsystem tests, and retain a
meaningful regression for a bug fix. Validate the paths affected by the change:
entry/Exit, repeated sessions, navigation, roles/ownership, optional package
independence, furniture, appearance changes and UI lifecycle as applicable.
Label checks that were not run and separate native state from rendered behavior.

Script/UI-only changes may use the established hot-update path while idle, keeping
loaded cooked bytes. Native chunk-hook changes require both Lua environments to
reload. A fresh process launch establishes automatic package/declaration loading;
manual mounting and diagnostic patching do not. Released native appearance
references can require a game restart. Matching build markers alone are insufficient.

### Hot-update readiness

Check readiness after every Lua reload or temporary Lua mod mount/unmount,
including when removing a probe at the end of a test. The controls acknowledge
the new Lua host with the same launcher identity when both UI apps stay loaded.
A new UI instance completes its own handshake before exposing Start.

1. Finish Exit and confirm the game is idle. After a mount/unmount, use
   `luamod_reload` with `Target: all` if actor registration is missing or the
   change affects both Lua environments.
2. Check that `selection_ui_ready` acknowledges the current
   `selection_host_ready` token. `selection_launcher_ready` must report ready,
   and both records must name the same controls and launcher instances. If
   readiness does not recover, remount both SceneZOI UI apps with `uimod_remount`
   for `SceneZOI_93C44199` and check that `ui_boot` changes.
3. Reopen the native interaction menu and verify playback and Exit. If selection
   fails, inspect `selection_error` and `actor_registration`. If selection
   succeeds but preparation and restoration time out after a scoped remount,
   check `last_stop`, `last_exit` and the save journal. In `lua_module_list`,
   check for `SceneZOISimulationReceiver` on the controlled Zoi and each
   addressed participant. Verify actual playback and Exit after any recovery.

The [possession and API checkpoint](validation/api-possession-20261109.json)
records how the launcher lost readiness before this handshake change.

### Package location and persistent data

Discover the installation directory and cfg directory independently. On the tested
retail setup, a manually installed `Mods/<mod_id>/` package writes cfg data under
`Mods/InGame/<mod_id>/`. The latter may contain only runtime/settings/preferences
and no `mod_manifest.json`; that is data storage, not another installed package.
Removing the package alone therefore may retain development configuration. Back
up both locations before a clean test, and preserve both during ordinary updates.

This location is selected by the game's `uimod.cfg_load` / `uimod.cfg_save` API,
not a SceneZOI path setting. The commands expose no base-directory override.
Keep supported persistence rather than replacing it solely to co-locate data
with the package. See
[settings storage](settings.md#storage-location) for the actual subdirectories.

For manual removal, Exit the scene, finish cleanup, save and close the game first.
Remove the installed package folder. Retaining the separate cfg folder preserves
preferences for reinstallation; removing or moving that data as well resets it.
For a diagnostic clean install, keep full backups of both outside Mods and start
without the old cfg data.

### Clean-install release check

Test the exact ZIP intended for distribution, not only the development install.
Close inZOI, back up existing mod folders and all settings/recovery files outside
Mods, then install into a fresh directory without carrying old runtime cfg into
the test. Launch a fresh game process and verify automatic loading, Start entries
on the controlled Zoi and supported furniture, playback, Exit and re-entry.
Do not seed configuration, manually mount scripts or hot reload to make this
acceptance pass. Preserve a separate update test with existing preferences.

SceneZOI 1.0 passed against retained developer configuration but failed on a fresh
install. A missing `selection_request` made native `cfg_load` fail, and the UI
cached host identity too early to retry its readiness acknowledgement. The test
fixture had incorrectly returned empty success for missing keys. Version 1.0.1
initializes the mailbox and retries incomplete handshakes. Keep native-style
missing-key failures in fixtures; see the [checkpoint](validation/fresh-install-startup-20261105.json)
and [issue ledger](investigations/runtime-and-ui-issues.md).

### Saves and cleanup

The controlled Zoi's session suspends scheduled autosaves if enabled. The
setting is restored when control leaves all sessions. Manual saves and forced autosaves still request ordinary cleanup. The
save recovery journal restores recorded participant state and furniture leases on
load with SceneZOI enabled. Sessions do not resume after loading.

When testing save behavior, distinguish the notification/Exit request from actual
participant and furniture restoration. Keep the framework enabled for recovery;
Exit, finish cleanup and save outside scene mode before removing a test build.
Cancelled gameplay interactions and departed groups are not resumed.

Record changed runtime/UI/data markers and measured evidence in `validation.json`.
Use the [issue ledger](investigations/runtime-and-ui-issues.md) for concise findings
and [subsystem docs](README.md) for current contracts. Documentation-only changes
do not require rebuilding or installing byte-identical runtime packages.
