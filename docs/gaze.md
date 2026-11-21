# Choose where Zois look

<a id="scene-gaze-data"></a>

Use `gaze` to make partners look at each other's eyes, or at the part of the
body involved in an action. For example, in a fellatio scene the seated partner
can look at the other Zoi's head while that Zoi looks toward the pelvis.
Gaze adjusts the eyes; animate the head and neck toward the intended target.

## Add a target to the scene

Add this fragment to a scene with `male` and `female` roles for mutual eye contact:

```json
"gaze": {
  "male": {
    "participant": "female",
    "component": "head",
    "bones": ["FACIAL_L_Eye", "FACIAL_R_Eye"]
  },
  "female": {
    "participant": "male",
    "component": "head",
    "bones": ["FACIAL_L_Eye", "FACIAL_R_Eye"]
  }
}
```

Each key is the observing role. `participant` names the role being looked at,
including the observer's own role for a self-target. `component` chooses the
`head` or `body` skeleton. One to eight case-sensitive bone names define the
target; several bones use their average world position. The example aims at
the midpoint between each partner's eyes.

For a pelvis target, replace the target's `component` with `body` and its
`bones` with `["pelvis"]`. Role IDs must match `participants` in your scene;
they need not be named after body types. Group scenes use the same format.

## Aim the head for distant targets

The eyes can only turn within the game's eye-look limits. They do not rotate
the head, neck or spine. A target behind the Zoi or far below the face may
therefore produce only a small glance. Pose the head toward it in Maya or Blender
if the intended action needs a stronger look. This matters when partners face
away from each other: requesting eye contact cannot turn their bodies around.

The tested native eye-local limits are Pitch ±17 and Roll ±5 degrees, used for
horizontal and vertical motion. The active game supplies the limits; scene data
cannot enlarge them. Blinking and other facial animation remain separate.
A [fixed facial pose](facial-poses.md) that owns an eyeball temporarily takes
priority over gaze for that participant.

## Complete source examples

Compare the [standing idle's mutual eye contact](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json)
with [Standing Fellatio](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json)
and [Sofa Fellatio](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/12_sofa_fellatio.json).
Read each `gaze` block alongside the declared roles and intended head motion.
These files are real scene data; the reference body animations are rest-pose
placeholders. Use your clips or the player pack to check moving contacts.

## Navigation handoff

The outgoing target stays active while the next scene prepares. The new scene
applies its target when playback starts. Omitting a role, omitting `gaze`, or
using an empty object makes the affected eyes look forward relative to the
animated head. Targets never carry over implicitly, even on same-scene entry.
Clothing changes rebind the gaze to the current head; Exit removes its owned
corrections. See [runtime contracts](tier1-contracts.md) for implementation details.

## Check the result in game

1. Watch a full loop from the front, side and above. Confirm both roles look
   at the intended body part as the partners move.
2. Try the scene's expressions and mouth pose together with gaze. Check the
   eyes still move, unless the facial pose deliberately fixes them.
3. Navigate to a scene with another target, then one without gaze. The eyes
   should change target and then return forward. Also try a clothing change.

If a look seems weak, check the head orientation and native limits first. If
the target is missing, verify the role, `head`/`body` selection and exact bone
names. Missing data reports an optional error and leaves the forward eye pose;
it does not stop the scene or silently target another participant.
