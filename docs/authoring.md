# Authoring content for SceneZOI

Content packs supply assets and inert JSON. SceneZOI supplies playback, participant
ownership, presentation and cleanup. A pack can be built independently and extend
framework hubs without editing framework source. Start with the public
[framework manifest](../packs/scenezoi.json), [neutral scene files](../packs/scenezoi/scenes/)
and [package/declaration guide](package-split.md).

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
A hub extension links your pack into enabled framework navigation. See
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
