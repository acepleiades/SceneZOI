# Authoring content for SceneZOI

Content packs supply assets and inert JSON. SceneZOI supplies playback, participant
ownership, presentation and cleanup. A pack can be built independently and extend
framework hubs without editing framework source. Start with the public
[framework manifest](../packs/scenezoi.json), [neutral scene files](../packs/scenezoi/scenes/)
and [package/declaration guide](package-split.md).

New to character animation? Start with [Make your first SceneZOI animation](first-animation.md)
for the Maya and Blender rigs, exporters and a first in-game test.

## Hand an animation pack to an AI agent

Give the agent this repository and the following inputs.

- **Animation files.** Provide one exported FBX per participant and any animated
  attachments. Include the role for each file, the shared frame range and frame
  rate, and the intended starting pose and placement (standing or furniture).
  If you only have an editable rig file, provide the rig and exporter too.
- **Project and access.** Give the path to your registered ModKit project and
  its authoring files, or ask the agent to help create a project. Give it access
  to ModKit for import and packaging. For a local playback test, provide a
  working SceneZOI installation and a test save with a compatible roster.
- **How to enter the scene.** Say whether it should appear in a compatible hub
  or be selectable directly from the [debug picker](group-support.md#solo-launcher-and-debug-picker).
  Mention any required attachments, clothing behavior or other content dependencies.
- **What the scene depicts.** Describe the beats, who does what to whom, and
  each role's posture and contact points so the agent can choose accurate
  actions and tags. Specify gaze targets, facial expression contexts, voice
  contexts or silence, and any sound effects and their timing. Use the
  [scene brief](first-animation.md#5-describe-the-scene-for-the-agent).

For a first standing pair, point the agent to the
[neutral standing scene](../packs/scenezoi/scenes/standing_idle.json) and the
[hub extension example](package-split.md#roles-entry-and-extensions).
Ask it to import your tracks, adapt the JSON in your own pack, and build and
[filter a test package](development.md#isolated-packaging) to its owned assets.

A successful first test means the scene appears at the intended entry, all
tracks play together, and Exit restores gameplay. Test with SceneZOI and your
pack enabled, plus any dependencies you actually declared. Have the agent report
which checks it ran. Review contact, clipping and the loop seam in-game yourself.

## Learn from a complete content pack

The [worked HZoi-Reference examples](content-examples.md) connect real manifests,
scene files, profiles, expression/voice libraries, tasks and translations. The
reference contains adult animation assets and silent replacements for proprietary
audio; it is for study and has no repository-wide license. Each subsystem guide
also links directly to relevant source sections. The neutral examples above
remain suitable for all-ages content.

## Reuse HZoi resources through a dependency

If your pack supplies animations and needs voices, sound effects, facial
expressions or a compatible attachment mesh, it can reference resources from
the installed HZoi player pack. In your native ModKit project's
`Meta/mod_manifest.json`, declare both dependencies:

```json
"dependencies": ["SceneZOI_93C44199", "HZoi_660649D8"]
```

Use the [package filter](development.md#isolated-packaging) to carry these
entries into the exported manifest. Tell players to install and enable both
mods. Keep your package inventory limited to your own payload. Use the HZoi
player build for audible testing. [HZoi downloads](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155)

| Resource | How to reference it |
| --- | --- |
| Voice sets | Set `voices[role].context` to a context HZoi supplies, such as `kiss`. SceneZOI looks up the context in the Zoi's selected compatible voice set. See [voice instructions](voices.md#scene-instructions). |
| Sound effects | Set the emitter's `sound_set` to an HZoi ID such as `hzoi.kiss`, then configure the emitter for your scene. See [scene sounds](sfx.md#data) and the [HZoi sound sets](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json#L12). |
| Expression sets | Set `expressions[role].context` to a context such as `Kiss`. HZoi's sets reference native inZOI facial animations. SceneZOI uses the Zoi's selected compatible set. For a standalone pack, define your own sets that reference native clips in place. See [expression authoring](expressions.md#responsibilities-and-data). |
| Male anatomy mesh | Reference `/HZoi_660649D8/Attachments/HZoi_MaleAnatomy.HZoi_MaleAnatomy`. HZoi's coverage profile can already supply the mesh to compatible roles. Its attachment tracks are mapped by scene ID. For synchronized movement in a new scene, author a compatible attachment track and configure its binding. See [coverage profiles](package-split.md#presentation-and-compatibility-profiles). |

**Audio rights.** HZoi's voice recordings and sound effects are proprietary.
Referencing them through the dependency leaves the audio in HZoi. To ship
those sounds in your own mod, buy the credited source assets under a license
that permits including and distributing them in your mod. Import your licensed
copies into your ModKit project and reference your own SoundWave paths. If you
extract a copy from HZoi, you still need those rights and the license must
permit reuse of that copy. Follow the creators' attribution terms. The
installed `CREDITS.txt` identifies the sources. [HZoi audio credits](https://github.com/acepleiades/HZoi-Reference/blob/main/CREDITS.txt)

Use one coverage replacement per participant. If HZoi's coverage rule
already supplies the mesh, account for it before adding a scene-local
replacement for the same region. [Standalone anatomy walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/standalone-anatomy.md#compare-with-hzois-profiles)

## Use the HZoi anatomy mesh in your own pack

Get the optional adult [male anatomy authoring kit](https://www.patreon.com/skyrimaceanimations/posts/inzoi-blender-172792014)
from the Blender rigs post. The kit is available free of charge. The source
mesh is credited to Ryan Reos’s *The Vagrant* and is subject to its own license.
Move the kit's editable assets into your own registered
ModKit project, export your own synchronized tracks and adapt the kit's
scene-local attachment example. The mesh and clips ship under your own mod's
asset paths. Players need SceneZOI and your pack. Follow the
[independent pack walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/standalone-anatomy.md)
for setup, coverage profiles and testing with HZoi disabled.

## Files and native project

Create and register your own project through ModKit. Give your pack a namespace,
author one scene per JSON file, and point the manifest at a child directory:

```json
{
  "schema_version": 3,
  "id": "designer",
  "scene_directory": "designer/scenes",
  "extensions": []
}
```

Scene files use namespaced IDs independently of filenames. Builds collect the
directory recursively and validate it before staging a native scene-pack row.
`expression_files` and `data_files` add other declarative definitions. Use your own
assets and packaging inventory; no private content checkout is needed.

From the SceneZOI checkout:

```powershell
python tools/build_catalog.py --packs "C:/MyPack/packs/designer.json" --project "C:/Path/To/DesignerProject"
```

This stages JSON, not animation imports or a native package. Follow
[developer setup](installation.md) and [packaging](development.md) for the rest.

## Scenes and participants

A scene declares `id`, `label`, `kind`, `duration`, `fps`, named `participants`,
`anchor_participant`, one body `track` per role, and `navigation`. Copy a neutral
scene as a complete structural example and replace its identity/assets with your
own. Roles describe responsibilities; they are not inferred from body type,
controlled/NPC status or roster order. Body/life-stage requirements describe actual
appearance compatibility. Mutual actions are explicitly authored in both directions.

Declare `starting_hub: true` on a compatible loop to make it eligible for entry.
The selected roster must match the entire scene. Membership and role assignments
stay fixed; connected nodes must preserve compatible roles and furniture context.
A hub extension links your pack into enabled framework navigation. A solo scene
has one role and extends `scenezoi.solo_idle_female` or `scenezoi.solo_idle_male`,
with the same role name, body and life stages as that hub. See
[participants](group-support.md), [furniture](furniture.md) and
[navigation/package extensions](package-split.md#roles-entry-and-extensions).

## Animation and attachment requirements

Body tracks must load on the compatible native skeleton and agree with authored
duration within the runtime tolerance. Paired clips use a shared origin/coordinate
setup for their intended contact. SceneZOI preserves the game's animation instances
and samples the tracks from one clock; it does not repair contact, author IK or
retarget arbitrary facial/body proportions for you.

The generic import tools validate source hashes, target skeletons and duration.
Rigs/exporters and their application-specific authoring workflows are maintained
separately. Investigate import accuracy for a concrete reproduced mismatch.

Named skeletal attachments specify their owning participant, mesh, socket and
reference bone, plus an optional duration-matched animation. The mesh uses its own
skeleton. `component` selects `body` or `head`; inverse-reference binding avoids a
double authored root offset. Resources have independent ownership and cleanup.
See [head attachments and fixed facial poses](facial-poses.md) and
[coverage/material profiles](package-split.md#presentation-and-compatibility-profiles).

## Optional animation assets

Content packs can use animations from independent libraries, including clips
originally made for another Unreal project, when the license permits that use.
This lets authors build scenes around existing animations without having to
animate them. The clips can be cooked with stock Unreal Engine and distributed
separately from the content pack. The game must be able to mount the cooked
package for its engine build and platform, resolve the animation's dependencies,
and play it on the target skeleton. [Unreal Engine content cooking](https://dev.epicgames.com/documentation/en-us/unreal-engine/cooking-content-in-unreal-engine)

Reference each clip's Unreal object path in `tracks`. Add
`"hide_if_tracks_missing": true` to a scene to make it conditional on those
assets. On catalog discovery, SceneZOI checks every role track, named attachment
mesh and animation, and any matching coverage attachment track declared for the
scene. Clips must load and match the authored duration. If a check fails, the
scene is omitted from the catalog, including API discovery and starts. Incoming
navigation, task routes and transitions that depend on the scene are also
removed. The catalog check is opt-in.

Install the cooked library before launching the game. The game and its content
loaders handle mounting. If archive signature checks block a compatible unsigned
package, use a compatible signature bypasser such as UniversalSigBypasser where
the game's terms permit it. [UniversalSigBypasser](https://github.com/rm-NoobInCoding/UniversalSigBypasser)

Test playback on the target Zoi, including looping and Exit. Then launch with
the library absent and verify that the scene disappears from navigation and API
search results.

## Optional scene data

| Behavior | Contract |
| --- | --- |
| Scene/participant tags, directed actions, calculated ratings | [Metadata](scene-metadata.md) |
| Expressions and fixed partial-face poses | [Expressions](expressions.md), [facial poses](facial-poses.md) |
| Eye targets | [Gaze](gaze.md) |
| Spatial sounds and voices | [SFX](sfx.md), [voices](voices.md) |
| Numerical tasks, completion routes and one-shot actions | [Scene tasks](scene-tasks.md) |
| Authored one-shot transition nodes | [Transitions](transitions.md) |
| Procedural completion effects and timing | [Completion responses](completion-effects.md) |

Scene ratings derive from declared actions; do not write `content_rating` into
scene JSON. Metadata describes content, while separate gameplay integrations own
availability decisions and consequences. Use [API/SDK add-ons](addon-authoring.md)
for executable integration rather than putting code in content declarations.

## Verify your pack

Run source validation, native validation and exact owned-payload filtering. Then
test fresh startup, matching/no-match entry, navigation, appearance changes,
pause/speed, Exit/re-entry and independence from optional packs as applicable.
Check actual asset readiness and retained errors; an accepted command is not
rendered acceptance. New geometry, facial targets, audio and furniture variants
need their own fit/presentation checks. Keep those results distinct from source
tests in your contribution or validation notes.

## Translated display text

Keep IDs and source labels stable. Content packs can contribute inert
[localization declarations](localization.md) for scene titles, explicit navigation
captions, expression/voice choices and task captions. Missing entries fall back
to English. Tags and actions are authoring metadata and are not translated.
