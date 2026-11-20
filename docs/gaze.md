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



## Complete source examples

The public [standing idle](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json) authors mutual head-eye targets.
The [rear scene](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/04_standing_rear.json) instead targets another role's body pelvis
and the observer's own `upperarm_l`. Compare these blocks with their declared
`participants`; the target role is explicit, not inferred from array order.
These HZoi-Reference files contain adult scene descriptions; see
[worked examples](content-examples.md) for context. Authored targets still obey
the native eye limits described above.

## Aim the head for distant targets

SceneZOI turns the eyes within the game's limits and preserves authored head
motion. If a target is far below the face, a Zoi may only glance in its
direction. Key the head toward the target in the body animation for a stronger
look.

## Navigation handoff

The outgoing gaze target stays active while the next node prepares. The arrival
applies its own target as playback starts. If it omits the target, the eyes
return forward at that point.
