# Scene gaze data

The gaze subsystem controls eyes only. Blinking remains game-owned; head,
neck and spine animation are preserved. The current facial adapter supports the
tested stock male/female facial rigs. Participant roles and targets are generic;
the gaze engine has no fixed pair, gender, or controlled/NPC indices. The current starter matches data-defined roles; removed group fixtures remain isolated-test rosters only; see [group support](group-support.md).

Add an optional `gaze` object to a scene node. Each key names an observing role.
Each target names another declared role (or the observer's own role), a skeletal
component (`head` or `body`), and one to eight unique bone names. Bone names are
case-sensitive. Multiple bones define their average world position.

```json
"gaze": {
  "male": {
    "participant": "female",
    "component": "head",
    "bones": ["FACIAL_L_Eye", "FACIAL_R_Eye"]
  },
  "female": {
    "participant": "female",
    "component": "body",
    "bones": ["upperarm_l"]
  }
}
```

The first example aims the male's eyes at the midpoint of the female's eyes.
The second aims the female's eyes at her own left shoulder joint. Body `pelvis` is a
single-bone target; the eyes use the separate Head mesh. Actual bones are checked
at runtime before starting the node; names are never treated as executable text.

Omitted observers look forward relative to their animated head. Missing `gaze`
or an empty object makes every participant look forward. Targets reset at every
node change, including repeated/same-node entry, and never carry over implicitly.
The arriving target is applied with playback; held outgoing poses and the scene's
existing outfit preparation remain intact.

Target positions follow the animated bones every sample. Mutual eye contact and
self-targets work without fixed participant ordering. Far-away/behind targets
remain declared targets; the resulting eye rotations are clamped instead of
turning the head or enlarging the eye range. Limits come from the active game's
HeadAnimInstance (tested eye-local Pitch ±17 and Roll ±5 degrees, corresponding
to horizontal/vertical eye motion). Pack data cannot override those limits.

The adapter appends two owned local `FB1AdditiveBoneData` corrections to the
existing Head post-process instance. These entries use a zero additive scale delta
and depth -1. This preserves eye size and propagates rotation to the child
`FACIAL_L_EyeParallel` / `FACIAL_R_EyeParallel` bones as well as the parent eyes. The native facial-shape entries and animation
instances remain in place. Only the eye corrections are written: no eyelid,
expression, translation, scale, head or spine data is changed. Unlike an absolute
component-space pose, a local correction follows the animated head without a
previous-frame head orientation. Updates do not issue per-frame CLI commands.

The correction's rotation is clamped to the active game's eye-look limits. The
final shaped eye-bone transform can also contain the game's existing facial DNA
and blink animation; it is not numerically identical to the gaze correction.
Targets are measured against the current native eye orientation with SceneZOI's
preceding correction removed, preventing feedback. Missing data applies an identity
correction, leaving the game's forward eye pose and native facial motion intact.

The session retains ownership of just its two appended entries. Copied head data
is adopted, discarded entries are recreated after refresh, and corrections do not
accumulate during navigation or clothing changes. Exit removes only those owned
entries from surviving instances. Partial cleanup retries only remaining entries;
retired destroyed instances cannot retain visible control. Native face customization
and other authors' entries are preserved. This does not add UI controls, head
following, random glances, expression playback, or a replacement blinking system.

The standing framework/HZoi idles declare mutual eye contact and the first two HZoi
branches. The rear node declares male-to-female pelvis and female-to-own-left
shoulder. The neutral framework pack's gaze data contains no adult asset reference.

Validation distinguishes isolated checks, native rotation/state checks, and the
author's final visual acceptance. See `validation.json` for the current build.


## Tier3-2 correction

The author's visual test of tier3-1 identified enlarged female eyes and no visible
male eye movement. Native readback confirmed both defects: the neutral scale was
incorrectly written as (1,1,1) in a scale-delta field, doubling parent-eye scale;
depth 0 left the male EyeParallel child bones at their original orientation.
Tier3-2 writes (0,0,0) and propagates the rotation to descendants. Eye look limits,
scene targets, native blinking, and entry removal on Exit remain in effect.
Regression checks model the native additive scale and child-bone rules, rather
than checking only the requested rotation and restored entry counts.


## Eye-only reach in the rear node

A live check on 2026-10-31 confirmed that the male target is the female body's
pelvis bone. Once the authored pose had settled, reaching it required roughly
57–66 degrees of downward eye rotation during the sampled part of the loop.
The active native vertical gaze limit was 5 degrees, and both eyes' scene
corrections remained at that limit. The declared target was retained throughout.
This small glance can appear nearly forward. Full fixation on that target needs
a more downward authored head pose or a future optional head-following mode;
SceneZOI currently preserves authored head animation and native eye limits.


## Continuous node handoff (expressions-10)

Leaving a node keeps its outgoing target map and role bindings active while the body pose is held and the arriving node prepares. The session temporarily clears its arriving bindings during preparation; gaze uses its retained outgoing bindings throughout that interval. At playback entry, both maps are replaced and sampled immediately. This removes the explicit forward reset previously issued on leave. Omitted targets still mean forward in the arriving node; no previous target is inherited after entry. Ownership, copied-head recovery, native limits and Exit cleanup are unchanged. Regression checks retain moving outgoing targets through preparation and apply an omitted target only at entry.

Expressions-10 final checkpoint: the author confirmed both the gaze forward-reset fix and immediate O activation. Final packaged family switching, hub navigation, Exit and re-entry passed; a 130-second native run after the ownership correction also ended with a clean Exit.

## Neutral bed gaze

Both neutral bed hubs direct the female role toward her own body hand_l. Male gaze is omitted and therefore forward. Standard-bed support is currently 68 cm and futons 20 cm. Native readback/playback passed; final blink/gaze visual acceptance remains separate.
