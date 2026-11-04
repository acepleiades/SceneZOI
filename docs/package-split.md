# Framework and content package ownership

SceneZOI provides the reusable runtime and UI. Content packs provide assets and
inert declarations; gameplay integrations use the separate native-message API.
SceneZOI must build and run independently of any private content repository.
Current checks and acceptance boundaries are in [validation.json](../validation.json).

## Available authoring references

The public [framework manifest](../packs/scenezoi.json),
[neutral scenes](../packs/scenezoi/scenes/), [metadata dictionaries](../packs/scenezoi/metadata/)
and [facial-pose definition](../packs/scenezoi/facial_poses/open_o.json) demonstrate
the native declaration workflow. Expression, voice, SFX and task guides provide
schemas and examples for contributions using your own assets.

HZoi is a private optional pack used in recorded maintainer integration tests. It
contains proprietary audio and is not available as a public checkout. A separate
reference copy with that audio muted is planned, but is not yet available. HZoi
names and paths in historical validation records describe that test environment;
they are not prerequisites or files supplied by this repository.

## Package responsibilities

| Project | Owns |
| --- | --- |
| SceneZOI | Runtime, UI, manual starter, three neutral hubs, five furniture profiles, metadata dictionaries, a fixed facial pose and four body animation packages. |
| Content pack | Its animations, meshes, audio, expression/voice sets, compatibility profiles, scene JSON and navigation extensions. No executable content-pack registration. |
| Gameplay add-on | Its own Lua, gameplay decisions, persistence and consequences, using the public API/SDK. |

Do not put pack-specific asset paths, scene IDs, expression defaults or anatomy
profiles into the framework. Geometry comes from the character meshes and enabled
content declarations. SceneZOI has no content-pack dependency; its manual starter
retains technical eligibility/availability checks without gameplay progression gates.

## Native declarations and author builds

Each enabled package appends uniquely named `SceneZOI_Declaration_...` rows through
its own native `Content/JsonPatch/Text_UI_patch.json`. The source table is `Text_UI`
(row struct `Text`); retail enumeration uses alias `Text`. No shared directory,
executable pack script, author list or generated runtime catalog is required.

An envelope contains `schema_version`, `kind`, `owner` and inert `data`. Consumers
include `scene_pack`, `expression_set`, `facial_pose`, `body_profile`,
`material_profile`, `coverage_attachment`, `voice_archetype`, `voice_context`,
`voice_set`, `scene_task`, `furniture_profile`, `tag_dictionary` and
`action_dictionary`. Unknown kinds remain inert. Executable add-ons use the
[versioned API](addons.md) instead of private runtime modules.

Create one scene JSON object per file. A pack manifest names a child
`scene_directory`; the build recursively collects and validates its files into a
native scene-pack declaration. `expression_files` and `data_files` list other
authoring inputs relative to the manifest; these lists are not runtime loose-file
manifests. Each `data_files` entry has a `kind` and relative JSON `file`.

From the SceneZOI checkout, stage the framework or an independent author's pack:

```powershell
python tools/build_catalog.py
python tools/build_catalog.py --packs "C:/MyPack/packs/designer.json" --project "C:/Path/To/DesignerProject"
```

Every owner needs its own native project. The generic writer preserves unrelated
patch entries and records owned declarations in `workspace/data_files.json` for
packaging; runtime does not read that inventory. Native packaging carries the
patch as `non_ufs/JsonPatch/Text_UI_patch.json` with manifest membership/checksums.
The framework default stages nine declarations with three neutral scene nodes.

Discovery runs at startup, while idle and before Start. Active sessions retain
their captured graph/libraries. Malformed contributions are isolated with warnings;
unavailable or roster-incompatible edges are omitted. Disabling/removing a package
removes its contributions at the next idle discovery. B1 publishes a discovered
UI catalog; B2 receives a validated current-node snapshot during preparation.

## Roles, entry and extensions

Any eligible loop may declare `starting_hub: true`, separately from its navigation
`hub` identifier. The starter matches the entire selected roster to distinct roles
using appearance body and optional body-age/growth requirements, then selects an
eligible start uniformly. Roles are independent of body type and control status.

Current neutral hubs require adult-compatible male/female appearance roles.
Character entry selects standing scenes; supported furniture selects a matching
profile. Other rosters need compatible authored data. The manual picker permits
two or three Zois; the runtime/API supports larger fixed rosters. No match shows
an explanatory notification and restores input without creating a session.

A pack can extend a framework hub without editing its JSON:

```json
"extensions": [{
  "hub": "scenezoi.standing_idle",
  "id": "designer.enter",
  "target": "designer.standing_idle"
}]
```

The target must be supplied by the pack and meet compatibility/restriction checks.
Extensions link in memory only while enabled. Membership, role bindings, original
snapshots and anchor/furniture context remain session-owned.

## Presentation and compatibility profiles

`coverage_attachment` data selects compatible participant traits, an exposed render
section, attachment asset/bones, profile IDs, optional per-node animation mappings
and retained lifetime. Each matching role receives its own named resource. Manual
outfit changes can activate it without visiting a particular pack scene first.

`body_profile` data describes actual coverage, render-section/mesh layout, material
requirements and replacement patch. `material_profile` maps source textures or
appearance colors to declared material parameters. Bone names, coverage bits,
regions and layout IDs are pack-specific compatibility data, not universal maps.
Test new profiles against the actual target meshes. Region replacement currently
permits one adapter per participant; ordinary attachments support multiple owners.

Expressions, facial poses, voices, SFX, tasks and completion responses follow the
same ownership boundary. Missing optional content must not install pack-specific
runtime defaults. See the [subsystem index](README.md) for authoring contracts.

## Packaging and verification

Use the framework's [asset inventory](../asset-inventory.json) for its four packages,
and a separate inventory for your pack. The generic filter accepts `--plugin` and
`--inventory`, excludes referenced Game/Engine payloads, verifies declaration
sidecars and retains only the package's registry in its companion pak.

Author dependencies belong in native `Meta/mod_manifest.json` under `dependencies`.
The filter preserves them in the output manifest's `Dependencies`; the tested
native exporter omits them otherwise. Automatic enablement/load-order enforcement
by the game's mod manager is not established by that declaration alone.

Follow [development](development.md) for native validation, isolated packaging and
requested local testing. Only validate external packs you actually have available;
report those checks separately from the independent framework suite. Preserve user
settings, per-Zoi preferences and credits, and distinguish installation/hash checks
from in-game acceptance.
