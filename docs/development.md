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

The default build stages the framework declarations: one scene pack with five
neutral nodes, five furniture profiles, two metadata dictionaries, one facial
pose, a shared scene task, and one localization dictionary. The framework inventory owns four animation packages. Default checks are
framework-only; `--content-root` is an optional test hook for a compatible author
checkout that is already available. HZoi's private checkout is not required.
The public [HZoi-Reference guide](content-examples.md) explains its separate
rest-pose animation placeholders, silent audio and [its checks](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/reference-assets.md#run-the-reference-checks).
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

Remove deleted scripts from both the native `workspace/lua/` and prepared `lua/`
trees during synchronization. A native chunk can load by filename even without
a manifest entry, so copying new files over an old tree is insufficient.

For MCP-assisted development, the ModKit exposes `modkit_validate_lua_script` and
`modkit_validate_uimod`. Keep diagnostics with the change and fix validation errors
before packaging. Source checks, native diagnostics and in-game visual/audible
acceptance are separate forms of evidence.

## Isolated packaging

For a new SceneZOI release, set `VersionName` in the plugin descriptor before
running `tools/build_catalog.py`. This generates the Lua release number that
the runtime writes to the diagnostics. Synchronize it along with the Lua source
and prepare Lua before exporting the package.

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

SceneZOI reads the complete declaration table when B1 starts. Once a
developer has mounted a content pack in a running process, a B1 Lua reload
while idle rebuilds the catalog from the packs the game has already loaded.

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

Follow the [release checklist](validation/README.md) with the ZIP you intend to
ship. Missing native cfg keys fail reads on a fresh install. Use a profile
with no prior cfg and keep the old settings for a separate update test.

### Saves and cleanup

The controlled Zoi's session suspends scheduled autosaves if enabled. The
setting is restored when control leaves all sessions. Manual saves and forced autosaves still request ordinary cleanup. The
save recovery journal restores recorded participant state and furniture leases on
load with SceneZOI enabled. Sessions do not resume after loading.

When testing save behavior, distinguish the notification/Exit request from actual
participant and furniture restoration. Keep the framework enabled for recovery;
Exit, finish cleanup and save outside scene mode before removing a test build.
Cancelled gameplay interactions and departed groups are not resumed.

Record the checked commit, build and results with the related PR or release.
See [release checks](validation/README.md) and [runtime troubleshooting](investigations/runtime-and-ui-issues.md).

## Download site

In GitHub **Settings â†’ Pages**, choose **Deploy from a branch** and select
**main** and **/docs**. The [download page](index.html) uses the GitHub Releases
API. Update contributors and their support links in that file. English site copy
lives there and in [releases.js](site-assets/releases.js). Update related
[language files](site-assets/locales/) when changing copy. Preserve numbered
placeholders for links/formatting and match the game's translated menu names.
