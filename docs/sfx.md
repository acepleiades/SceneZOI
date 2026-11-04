# Scene sounds

SceneZOI plays declarative clip lists in either `continuous` or `bone_distance`
mode. A node's `sfx` object contains any number of named, independently owned
emitters. There is no sound-type enum, pair-size restriction, content callback,
or separate SFX extension mechanism. Sound assets and scene choices belong to
the content pack; playback and cleanup belong to SceneZOI.

## Data

A pack declares reusable `sound_sets`. Each set has a `default` clip group and/or
`variants` selected by the scene speed (0.5, 1.0, 1.5, 2.0). A clip group contains
`clips`, a nonempty list of SoundWave object paths. Paths are validated as data, not executed.

A node references those lists through named `sfx` entries:

```json
{
  "room_tone": {
    "mode": "continuous",
    "owner": "performer",
    "sound_set": "example.ambience",
    "source": [
      {"participant": "performer", "component": "body", "bones": ["pelvis"]}
    ],
    "volume": 0.5,
    "gap": 0.1,
    "max_voices": 1
  },
  "contact": {
    "mode": "bone_distance",
    "owner": "helper",
    "sound_set": "example.contact",
    "source": [
      {"participant": "performer", "component": "body", "bones": ["hand_r"]},
      {"participant": "helper", "component": "body", "bones": ["hand_l"]}
    ],
    "distance": {
      "from": {"participant": "performer", "component": "body", "bones": ["hand_r"]},
      "to": {"participant": "helper", "component": "body", "bones": ["hand_l"]},
      "max_distance_cm": 30,
      "min_delta_cm": 0.1,
      "cooldown": 0.15,
      "sample_interval": 0.016666666666666666
    }
  }
}
```

Every owner and point explicitly names a bound role. Roles need not describe body
type or player control. Points support `head` or `body` and one to eight bone
names, using the same world-position lookup as gaze. An emitter's source follows
the average of its source points; each point averages its listed bones. Detector
endpoints can differ from the audio source. All spatial distances use Unreal
centimetres. Missing bones produce an optional error instead of silently using
another participant or a root.

Defaults are volume 1, gap 0 native-game seconds, avoid_repeat true, max_voices 4,
attenuation radius 100 cm and falloff 900 cm. `attenuation` can override
`radius_cm` and `falloff_cm`. The detector defaults match the values in the
example. Continuous emitters do not have a distance detector; their clips are
chained rather than asking Unreal to loop one fixed sound. One emitter plays
one continuous clip at a time. Distance emitters have bounded overlapping voices,
reusing idle components and stopping the oldest owned voice when the budget is
full. Histories, timers, detectors and components are separate for every emitter.

## Timing and lifecycle

Clip choice is uniform among eligible clips and avoids the previous clip when
more than one is available. Continuous playback uses duration/applied rate as a lower-bound estimate, then waits for native IsPlaying=false before recycling the clip and applying its gap. Unavailable native state uses a timer fallback; a bounded observed-wait watchdog handles broken components. This is polling, not a native completion callback.

Bone-distance playback detects a change from approaching to separating within
the proximity threshold. Reversal is confirmed by an accumulated excursion from the last extremum,
using `min_delta_cm` as hysteresis. Small per-frame movements accumulate instead
of being discarded. Plateaus retain the preceding trend. Distance/trend
updates continue during cooldown, so cooldown does not create a stale artificial
minimum. Sampling uses the shared scene clock at most once per host sample;
missed frames are not fabricated. Unlike Unity LateUpdate, the current Lua host
has no independently verified post-animation native tick hook. Native phase,
thresholds and fast-playback sampling need the first in-game checkpoint.

The requested clip playback rate follows native game time, with a 1x floor for positive slow motion and native bounds for fast-forward. Pause is a separate operation. SceneZOI's 0.5/1.0/1.5/2.0 controls select variants
and change animation/contact frequency; they never multiply a clip's pitch or
playback duration. All selected variants likewise play at the native game rate.
There is no `pitch_reference` field in the current development schema.

The shared clock now has two monotonic channels: `session_elapsed` follows the
combined animation rate, while `game_elapsed` follows native game speed alone.
SFX uses the latter for clip progress, continuous gaps, sampling intervals,
cooldowns and bounded retries. Both channels freeze during owned preparation
holds. Speed selection and node-time reset do not jump the native-time channel.
Native audio pitch changes pitch as well as duration; this is not pitch-preserving
time stretch.

The adapter reads native AudioSettings limits without changing global settings.
The current ModKit reports minimum 0.4 and maximum 2.0. Requested rates outside
those limits are clamped; scheduling uses the applied rate to avoid cutting off
continuous clips early. Consequently native game rates above the limit are capped locally. Final audible acceptance across game-time rates remains pending. Diagnostics include actual/requested rate, limit source, clip,
bucket, play counts, distance and errors.

Game pause freezes owned components and timers. An outfit preparation hold pauses
and resumes the existing continuous clip, preserves its random history, and
rebases distance detectors after the body rebuild. Navigation stops and destroys
outgoing node-owned components before the new node starts. Exit/failure cleanup
retains ownership until Stop/destruction succeeds, including partially configured
components. Missing/wrong-type assets are optional, with bounded retry; they do
not block scene-body readiness. No game audio, global mix, animation instance,
input ownership or original outfit snapshot is modified by this engine.

## Current scene configuration

Distance emitters track approaching/separating trends through cooldown, with
declarative proximity, dead-band and cooldown settings. Triggered and continuous
sounds avoid immediate repeats where the pool permits. Each emitter owns its
moving, attenuated world audio components independently. Scene speed selects
authored variants; native game time governs audio playback.

The following scene IDs record private HZoi integration examples alongside the public framework hub. HZoi is not available as a public checkout; use the schema examples above with your own assets. The recorded content declares:

- `scenezoi.standing_idle`: normal Idle expressions and no sound emitters. The
  temporary continuous kiss test was removed in animation-refresh-1 after the
  author confirmed the Kiss expressions. The generic continuous engine and
  `hzoi.kiss` library remain available for future scene declarations.
- `hzoi.standing_hand_job`: female `hand_r` to male `pelvis`, sound at the contact
  midpoint, `hzoi.kutyu`. A/B/C/D are selected at 0.5/1.0/1.5/2.0 and every chosen variant follows native game-time rate without a further
  scene-speed multiplier.
- `hzoi.standing_rear`: male `pelvis` to female `pelvis`, midpoint source,
  `hzoi.piston`, native game-time rate.

Only the female role in `hzoi.male_standing_female_kneeling_fellatio` retains the fixed O override.
Kiss uses the existing expression library and does not enable that override.
The separate voice and task-completion audio engines are implemented. Content-defined state/events must not introduce pack-specific meanings into this generic sound engine.

## Verification boundary

`Sfx.lua` owns scheduling, `SoundNative.lua` owns Unreal audio calls, and
`tools/sound_data.py` validates declarations during catalog compilation. Unit
checks cover multiple emitters/three roles, repeated bodies, closest approaches,
plateaus/cooldown, speed buckets, pause, native pitch limits, outfit holds,
optional asset recovery, bounded polyphony and cleanup retry. A commandlet smoke
check exercised native attenuation/pitch/pause methods and read the native pitch
limits. Later retail playback exposed the stale-wave failure documented below;
the corrected trial ran for 97 seconds/40 plays without SFX errors and exited
cleanly. Final audible timing still belongs to the author.
See `validation.json` for installation and the pending in-game checkpoint.


## First live corrections (sfx-2)

The original continuous hub run stopped at 13 plays with a typed `SetSound`
rejection on a cached SoundWave userdata. The bridge validity check did not
reliably identify that expired handle. Every play now resolves the wave again
from its validated object path before assigning it to the native component;
the component retains the current playing wave. Cached Lua userdata is not
native asset ownership. An isolated regression reproduces a validity query
that cannot identify the tombstone.

The first detector compared each frame's motion with the dead band. This delayed
hand reversal by about 0.1 seconds in the measured 45 Hz run and could discard
subtle movement entirely at higher frame rates. It now uses extrema-based
reversal hysteresis. The generic default remains 0.1 cm; the two HZoi contact
fixtures use 0.01 cm, tested against their measured traces. Hand events moved
from scene phase about 0.133 to 0.044, one sampled frame after their distance
minimum near 0.022. The rear fixture also fires once per measured cycle near its
minimum. These are native call/distance observations, not final audible acceptance.
The source recordings themselves are unchanged; perceived onset/accents and
other animation/body combinations still need author review.

The corrected hub lifetime trial reached 40 clip plays over 97 seconds without
SFX errors and ended `idle/ok`. Both contact trials also ended `idle/ok`.


## Native-time correction and focus policy (sfx-3)

The author clarified that SceneZOI speed must not retime audio. Earlier builds
multiplied generic clips by scene speed as well as native speed. The separate
native-time channel and removal of `pitch_reference` correct that policy; tests
cover all four scene speeds, generic/variant clips, mid-clip native rate changes,
pause, and fixed continuous duration across scene-speed changes.

In the later reported silent rear session, trigger counts were advancing without
SFX errors. The author then observed that sound stopped when the game lost focus;
the saved game setting had background audio disabled. SceneZOI preserves that
game-wide preference and continues using world audio rather than UI audio.
This observation is separate from the earlier real stale-wave error.


Animation-refresh-1 updates the idle/handjob/standing-kneeling body and attachment
clips, keeping the same timing and skeletons. Earlier native distance/phase
measurements describe the previous exports; contact alignment for the touched-up
motion needs its next author checkpoint. The rear-animation assets are unchanged.


## Slow-motion audio policy (20261103-audio-slowmotion-1)

For native game time strictly between 0 and 1, SceneZOI audio keeps its normal 1x pitch/playback rate. This covers voices, continuous/contact SFX and completion one-shots, regardless of the control causing slow motion. Pause still pauses audio; native fast-forward retains existing pitch bounds. Scene animation speed never retimes audio. Clip timers use actual audio rate, so clips can finish while animation is still moving slowly. Contact cooldowns and authored gaps retain existing game-time scheduling.


## Native audio completion (20261103-audio-finish-1)

The duration/rate estimate is now a lower bound for normal completion, not a forced stop. Once it expires, SceneZOI waits for the native AudioComponent to stop playing before recycling continuous clips, releasing one-shots or resuming normal voice after a response. This protects short tails and newly selected voice sets from audio-thread/startup delay. Pause freezes completion and its watchdog. A two-audio-second observed-wait watchdog bounds broken/looping native components; a long initial asset-loading frame does not consume this watchdog. If native state is unavailable, the existing timer fallback remains. Explicit voice-set changes, response priority fades, navigation, bounded pool stealing and Exit still intentionally stop owned playback.
