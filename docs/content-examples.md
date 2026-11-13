# Worked content-pack examples

[HZoi-Reference](https://github.com/acepleiades/HZoi-Reference) is a public, reference-only content pack demonstrating
SceneZOI's inert JSON authoring model. **It contains sexual animation assets and
adult scene descriptions.** The framework's [neutral scenes](../packs/scenezoi/scenes/)
remain available as all-ages starting points.

All 702 WAVs are silent replacements because the original recordings are
proprietary. Original SoundWave packages are omitted; fresh silent imports are
described in [reference asset setup](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/docs/reference-assets.md).
The repository has no repository-wide license and is for reference only; consult
its [rights and attribution](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/README.md) before reusing any material.
The framework's GPL does not license that pack or its third-party assets.

The source links below are pinned to reference revision `4547286` so their
line anchors and these explanations stay consistent. Current SceneZOI contracts
remain authoritative. These examples do not require a private HZoi checkout.

If your pack uses HZoi resources at runtime, declare the HZoi player pack as a
dependency and reference its IDs and object paths. See
[reusing HZoi resources](authoring.md#reuse-hzoi-resources-through-a-dependency)
for setup, asset references and audio rights.

If you are starting from a rig file, follow the [first animation guide](first-animation.md)
through export, scene authoring and packaging.

## Find a complete example

| What you want to author | Source to read | Fields and relationships to inspect |
| --- | --- | --- |
| A pack extending a framework hub | [Pack manifest](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json) and [standing idle](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json) | `scene_directory`, `extensions`, `navigation`; the manifest adds entry and the scene provides return/branch edges. |
| Scene and per-role descriptions | [Idle metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L79) and [rear-scene metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L288) | `tags`, `participant_tags`, directed `actions`; mutual hugs use two records. |
| Role-specific outfit instructions | [One-role removal](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L11) and [two-role removal](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L11) | `outfits[role].remove_slots`; these are scene instructions, not UI preference writes. |
| Mutual eye contact or a self-target | [Idle gaze](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L53) and [rear-scene gaze](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L73) | Explicit `participant`, `component` and `bones` per observer. |
| Context-based expressions plus a facial pose | [Expression definition](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/expressions/pleasure_face.json) and [scene selection](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L76) | A selected set supplies `Pleasure`; `facial_pose` independently names `scenezoi.open_o`. |
| Contact-triggered sound | [Hand-scene emitter](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L84) and [manifest sound sets](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json#L12) | `bone_distance`, emitter owner/source, detector endpoints and speed-selected clip variants. |
| Voice libraries and reactions | [Archetype](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/archetype_mature.json), [context](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/context_fellatio.json), [set](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/set_megu_hiiragi_mature_fellatio.json) and [scene bindings](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L207) | Compatible body/archetype/context IDs, normal clips, named response groups and independent speaker role. |
| Numerical progress and completion actions | [Task definition](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/tasks/excitement.json) and [scene rates](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L134) | Task ID, maximum/decay, per-role rates/caps and definition-level completion sound. |
| Procedural completion effects | [Timing and responses](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L148) | Movement phase, shared slowdown and independently owned per-role shaking. |
| Exposure-driven animated attachments | [Coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/region_attachment.json), [body layout](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/body_layout.json) and [material mapping](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/skin_hair.json) | Mesh binding, profile IDs, retention and `node_animations` for pack and framework scenes. |
| Translated player-facing labels | [Localization catalog](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/localization/text.json) and [manifest registration](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json#L161) | Stable IDs, per-culture `labels` and a `localization` declaration. |
| Native declaration output | [Generated patch](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/modkit/HZoi_660649D8/Content/JsonPatch/Text_UI_patch.json) and [owned declaration list](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/modkit/HZoi_660649D8/workspace/data_files.json) | Compare authored files with build output; edit the authored inputs rather than generated rows. |

## Follow the manifest into a scene

This excerpt from the [manifest](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json) collects one JSON object per
scene file and adds an entry edge to the framework's standing hub:

```json
{
  "schema_version": 3,
  "id": "hzoi",
  "scene_directory": "hzoi/scenes",
  "extensions": [
    {
      "hub": "scenezoi.standing_idle",
      "id": "hzoi.enter",
      "target": "hzoi.standing_idle"
    }
  ]
}
```

The full manifest additionally registers expression definitions, other
`data_files` and reusable sound sets. The target
[idle scene](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L11) returns to `scenezoi.standing_idle` and
branches to three activity scenes. This extends navigation without modifying
SceneZOI's JSON. HZoi's idle does **not** declare `starting_hub: true`; manual
entry starts at a compatible framework hub, then follows the contributed edge.
See [package declarations and extensions](package-split.md#roles-entry-and-extensions).

## Distinguish scene facts from role facts

The [standing idle metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L79) contains these fields:

```json
{
  "tags": [
    "affectionate",
    "standing",
    "eye_contact"
  ],
  "participant_tags": {
    "male": [
      "standing"
    ],
    "female": [
      "standing",
      "leaning_against_partner",
      "hand_on_partner_chest",
      "arm_around_partner_hips"
    ]
  },
  "actions": [
    {
      "type": "hug",
      "actor": "male",
      "target": "female",
      "performer": "male"
    },
    {
      "type": "hug",
      "actor": "female",
      "target": "male",
      "performer": "female"
    }
  ]
}
```

`male` and `female` are this author's role IDs, not reserved runtime indices.
The same scene separately declares their appearance-body requirements and tracks.
The two hug records describe actual mutual activity; a single record would not
imply reciprocation. Role tags are not promoted into whole-scene tags. GENERAL
is derived from the registered hug action, not written into this scene.

Compare [the mixed-posture scene](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L222): standing and
kneeling belong to different roles, while eye contact describes the scene. Use
those role-specific facts when [searching metadata](scene-metadata.md).

## Connect progress to independent responses

The [task definition](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/tasks/excitement.json) registers `excitement`, maximum 90 and decay 1.
The [hand scene](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L134) authors these progression rates:

```json
{
  "tasks": {
    "male": {
      "excitement": {
        "rate": 1,
        "cap_percent": 100
      }
    },
    "female": {
      "excitement": {
        "rate": 0.5,
        "cap_percent": 50
      }
    }
  }
}
```

At default settings, the male role can reach completion from zero, while the
female role stops at 50%. Player rate settings and add-on controls can modify
progression. The idle omits task instructions, allowing the definition's decay;
an explicit rate of zero would hold progress instead.

The definition's `on_completion` supplies a body-filtered sound. Separately,
[this scene binding](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L207) makes another role
react to completion:

```json
{
  "task_completion_voices": {
    "male": {
      "excitement": [
        {
          "participant": "female",
          "context": "fellatio",
          "response": "fellatio_finish",
          "fade_out": 0.25
        }
      ]
    }
  }
}
```

The outer `male` role completes the task; `participant: "female"` identifies the
speaker. Her selected [voice set](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/set_megu_hiiragi_mature_fellatio.json#L56) supplies the named
response. The response does not pick an arbitrary archetype or change her saved
voice preference. Both ordinary clips and responses are silent in this reference.
The [rear scene](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L264) also demonstrates priority
between own-completion and partner-completion reactions.

For visual responses, inspect [movement timing and per-role effects](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/02_standing_hand_job.json#L148).
Only the male role requests shared slowdown; each role has its own shake profile.
These are presentation effects, not an automatic session end or gameplay reward.
See [tasks](scene-tasks.md), [voices](voices.md) and [completion effects](completion-effects.md).

## Trace an attachment through its profiles

To use the same mesh in a pack that depends only on SceneZOI, start with the
[standalone anatomy walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/standalone-anatomy.md).
It uses the separate authoring ZIP and your own ModKit assets, IDs and tracks.
The trace below explains how the HZoi pack itself wires the attachment.

The pinned body-profile example uses the older name-based schema. Current body
profiles use schema version 2 and omit `mesh_name`, `material_slot`,
`minimum_materials` and `compatible_layouts`. Keep the declared section/coverage
and patch fields and follow the current
[body-region contract](package-split.md#presentation-and-compatibility-profiles).
The framework handles section-preserving bodies without recognizing their mods.

The [coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/region_attachment.json) declares its mesh, pelvis binding,
body/material profile IDs and `retain_for_session`. `node_animations` maps scene
IDs to duration-matched tracks, including the framework's standing and bed hubs.
The [body profile](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/body_layout.json) describes the compatible mesh/coverage layout;
the [material profile](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/skin_hair.json) maps skin/hair appearance parameters.

Section 17, material slots and bone names are facts about these particular
assets. They are not universal defaults. A new mesh needs measured compatibility
data and its own fit tests. HZoi supplies a bed attachment animation; the paired
bed body animations and furniture profiles belong to SceneZOI. There is no
HZoi-authored bed scene or tongue mesh in this example. For ordinary named
attachments and head bindings, use [facial poses and attachments](facial-poses.md).

## Translate labels without changing identity

This excerpt from the [catalog](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/localization/text.json) connects an English source
label and an explicit Return edge to their Japanese display text:

```json
{
  "schema_version": 1,
  "id": "hzoi.localization",
  "translations": {
    "en-US": {
      "labels": {
        "scene.hzoi.standing_idle": "HZoi Standing Idle",
        "navigation.hzoi.standing_idle.neutral": "Return..."
      }
    },
    "ja-JP": {
      "labels": {
        "scene.hzoi.standing_idle": "HZoi — 立ったままの抱擁",
        "navigation.hzoi.standing_idle.neutral": "戻る..."
      }
    }
  }
}
```

The complete file supplies all 15 cultures and expression, voice and task labels.
The manifest registers it once with `kind: "localization"`. IDs, paths, tags and
actions stay unchanged. Missing entries fall back per label to English. See
[localization](localization.md) for key formats and validation limits.

## Adapt and verify

Use your own namespace, project identity, compatible assets and permissions.
Read the complete source file around an excerpt: the fragments here are not
standalone scenes or complete pack manifests. Do not copy profile section numbers
or assume these two-role scenes prove support for your new roster or skeleton.

The reference's [build wrapper](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/tools/build.py) invokes SceneZOI's generic
builder. JSON staging does not register a ModKit project, import audio, cook or
install a playable mod. Follow [content authoring](authoring.md) and
[developer setup](installation.md); use the reference's asset setup only in a
separate working environment, preserving any original project with the same ID.

Source validation can establish structure and references. Native loading,
audible behavior, new mesh fit and animation contact require their own checks.
The muted copy cannot establish the original audio's audible balance.

HZoi contains no executable integration scripts, authored transition nodes or
three-person choreography. Use [add-on authoring](addon-authoring.md), the
[SDK](../sdk/README.md), [transition examples](transitions.md) and the framework's
[participant contracts](group-support.md) for those separate concerns. Merely
cloning the reference does not enable its declarations in a running game.
