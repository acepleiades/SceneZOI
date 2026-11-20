# Read a complete content pack

For an all-ages example, open [SceneZOI's paired standing idle](../packs/scenezoi/scenes/standing_idle.json).
Find its named roles, body tracks and anchor participant. Then compare a
[solo idle](../packs/scenezoi/scenes/solo_idle_female.json) or
[bed hub](../packs/scenezoi/scenes/zz_bed_single_idle.json) to see what changes
with one Zoi or with furniture.

[HZoi Reference](https://github.com/acepleiades/HZoi-Reference) preserves the
definitions for 14 standing and bed scenes. Its animation assets are rest-pose
placeholders and its audio files are silent; the repository does not include
HZoi's authored motion or original recordings. Its
[authoring walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/authoring-walkthrough.md) explains
why it uses the features below and how to test them. Check its [asset rights](https://github.com/acepleiades/HZoi-Reference/blob/main/README.md#rights-and-attribution)
before reusing material. Use the [HZoi player pack](authoring.md#reuse-hzoi-resources-through-a-dependency)
if your mod depends on its actual animations or sounds.

## Follow the manifest into a scene

The [manifest](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi.json) loads one node per file from
`hzoi/scenes`. Its `extensions` entry adds a button from
`scenezoi.standing_idle` to `hzoi.standing_idle`. The
[HZoi idle](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json) links back to the
framework hub and branches to three other scenes. That is how an independent
pack adds navigation without editing SceneZOI. [Hub extensions](package-split.md#roles-entry-and-extensions)

## Add a furniture branch and optional tracks

Follow the manifest into the [queen-bed hub](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/05_queen_bed_idle.json)
and compare the [single-bed hub](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/05_single_bed_idle.json).
Each branch declares its furniture kind, keeps its roles, and uses a common
authored surface plane. The [optional queen-bed scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/09_queen_bed_aal_frontal.json)
checks whether its external clips are available. Players can use the rest of
the branch when the external library is absent.
[Furniture](furniture.md) · [Optional animation assets](authoring.md#optional-animation-assets)

## Distinguish scene facts from role facts

In [HZoi's standing idle](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json), the
metadata describes eye contact throughout the scene. Only one role leans on
the other in the production motion, so that detail
goes in `participant_tags`. Both roles hug, so `actions` records the hug
twice with the actor and target reversed. The names `male` and `female`
are the author's role IDs. Each role declares its body requirements separately.
[Metadata and ratings](scene-metadata.md)

## Connect progress to independent responses

1. [SceneZOI’s shared task definition](../packs/scenezoi/tasks/excitement.json) sets maximum
   and decay. The [hand scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/02_standing_hand_job.json)
   sets different rates and caps for its two roles in `tasks`.
2. When a participant reaches the maximum, SceneZOI resets their meter and emits
   `task_completed`. The [standing rear scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/04_standing_rear.json)
   plays its one-shot through `task_completion_sounds` and uses
   `movement_timing` and `completion_responses` for a coordinated visual effect.
3. The same rear scene shows a third path in `task_completion_voices`. The Zoi
   who speaks can be different from the one whose task completed.

[Task definitions and provider order](scene-tasks.md#choose-which-definition-a-scene-uses) · [Completion effects](completion-effects.md) · [Voice responses](voices.md#task-triggered-one-shot-voice-responses)

## Trace an attachment through its profiles

The [coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/profiles/region_attachment.json)
names a mesh and maps scene IDs to animation tracks. Its
[body profile](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/profiles/body_layout.json) describes the
section and coverage bit the game uses. Its
[material profile](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/profiles/skin_hair.json) describes which
appearance values to copy. The same coverage rule can activate an attachment
during an outfit change in an idle scene. [Compatibility profiles](package-split.md#presentation-and-compatibility-profiles)

## Find other examples

| Feature | What to look for |
| --- | --- |
| Contact sound | `bone_distance` in the [hand scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/02_standing_hand_job.json), and the named `sound_sets` in the [manifest](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi.json). |
| Gaze and expressions | `gaze` on the [standing idle](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json). The [kneeling scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json) selects an expression context and a fixed facial pose separately. |
| Translated labels | The [localization catalog](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/localization/text.json) uses scene and navigation IDs as keys. Reword the labels without changing those IDs. [Localization](localization.md) |
| Generated game data | Compare the authored files with the [native patch](https://github.com/acepleiades/HZoi-Reference/blob/main/modkit/HZoi_660649D8/Content/JsonPatch/Text_UI_patch.json). Edit the inputs in `packs/` and rebuild. |

## Adapt and verify

Use your own pack namespace and licensed assets. Keep the first test small:
one entry, one loop, and Exit. Follow the [authoring guide](authoring.md) to
build and install it.
