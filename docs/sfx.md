# Add sound effects to a scene

<a id="scene-sounds"></a>

Use sound effects for skin contact, thrusts, strokes, props and ambience. A
handjob scene can play a contact sound when the hand reverses near the pelvis;
another scene might play fabric movement or a repeating background sound.

Put moans, breaths and spoken orgasm reactions in
[voice sets](voice-set-authoring.md#voices-and-sound-effects). Those follow the
Zoi's chosen voice and voice volume. Effects use the **Sound Effects** slider.

Define a reusable list of clips in your pack's `sound_sets`, then add an `sfx`
entry to each scene that should play it. Use `continuous` for chained clips or
`bone_distance` for contact timed from two moving points. Each emitter owns its
own playback and is cleaned up when its scene ends.

## Import and register sounds

1. Import the WAV files into your own inZOI ModKit project as **SoundWave**
   assets. Use **Copy Reference** on each clip. From the copied reference,
   use the object path, for example
   `/ExampleSounds/Audio/Contact.Contact`. Include the assets when you cook
   the project.
2. Add `sound_sets` to your pack manifest. Prefix the set IDs with your
   pack ID. Below is a complete manifest for a pack that supplies only
   audio. In an existing animation pack, add just the `sound_sets` field
   and keep its scene directory and extensions.

   ```json
   {
     "schema_version": 3,
     "id": "example",
     "nodes": [],
     "extensions": [],
     "sound_sets": {
       "example.ambience": {"default": {"clips": ["/ExampleSounds/Audio/Room.Room"]}},
       "example.contact": {"default": {"clips": ["/ExampleSounds/Audio/Contact.Contact"]}}
     }
   }
   ```

3. Point a scene's `sfx` emitter at the set ID, as shown below. An audio-only
   pack can publish sets for another pack to use. Agree on the IDs and have
   the consuming pack declare a dependency if those sounds should always be
   available. A sound set only plays where a scene or task response asks for it.
4. Stage the pack manifest with `tools/build_catalog.py --packs ... --project ...`,
   then package, install and restart inZOI. Test with the packaged
   SoundWaves and a scene that uses the set.
   [Pack setup and build command](authoring.md#files-and-native-project) ·
   [Package your project](development.md#isolated-packaging)

## Data

A sound set has a `default` clip group, `variants` selected by scene
playback speed (0.5, 1.0, 1.5, 2.0), or both. For example, keep everyday
contact clips in `default` and set `"scene_speed": 2` on a variant with your
faster contact clips. Each group must list at least one SoundWave object path
in `clips`.

A node references those lists through named `sfx` entries. The next block is
the **contents of `sfx`**, so place it under `"sfx": { ... }` in your scene.
Its `performer` and `helper` roles must exist in `participants`:

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

## Player volume

The [Scene Settings](settings.md) Sound Effects control supplies a persistent
0–200% gain for these emitters and task-completion sound effects. The authored
`volume` range remains 0–1; user gain is applied independently at the owned
audio component. Voices and their responses use separate controls.

## Timing and lifecycle

Clip choice is uniform among eligible clips and avoids the previous clip when
more than one is available. Continuous playback uses duration/applied rate as a lower-bound estimate, then waits for native IsPlaying=false before recycling the clip and applying its gap. Unavailable native state uses a timer fallback; a bounded observed-wait watchdog handles broken components. This is polling, not a native completion callback.

Bone-distance playback detects a change from approaching to separating within
the proximity threshold. Reversal is confirmed by an accumulated excursion from the last extremum,
using `min_delta_cm` as hysteresis. Small per-frame movements accumulate instead
of being discarded. Plateaus retain the preceding trend. Distance/trend
updates continue during cooldown, so cooldown does not create a stale artificial
minimum. The runtime samples once per host update. Check the threshold and reversal in
game at the fastest scene speed you support. A short contact can fall between
samples.

The requested clip playback rate follows native game time, with a 1x floor for positive slow motion and native bounds for fast-forward. Pause is a separate operation. SceneZOI's 0.5/1.0/1.5/2.0 controls select variants
and change animation/contact frequency; they never multiply a clip's pitch or
playback duration. All selected variants use the same native-time rules.

The shared clock has two monotonic channels: `session_elapsed` follows the
combined animation rate, while `game_elapsed` follows native game speed alone.
SFX uses the latter for clip progress, continuous gaps, sampling intervals,
cooldowns and bounded retries. Both channels freeze during owned preparation
holds. Speed selection and node-time reset do not jump the native-time channel.
Native audio pitch changes pitch as well as duration; this is not pitch-preserving
time stretch.

The adapter reads native AudioSettings limits without changing global settings.
The current ModKit reports minimum 0.4 and maximum 2.0. Requested rates outside
those limits are clamped; scheduling uses the applied rate to avoid cutting off
continuous clips early. Consequently native game rates above the limit are capped locally. Listen in game at the native speeds you intend to support. Diagnostics include actual/requested rate, limit source, clip,
bucket, play counts, distance and errors.

Game pause freezes owned components and timers. An outfit preparation hold pauses
and resumes the existing continuous clip, preserves its random history, and
rebases distance detectors after the body rebuild. Navigation stops and destroys
outgoing node-owned components before the new node starts. Exit/failure cleanup
retains ownership until Stop/destruction succeeds, including partially configured
components. Missing/wrong-type assets are optional, with bounded retry; they do
not block scene-body readiness. No game audio, global mix, animation instance,
input ownership or original outfit snapshot is modified by this engine.

## Worked example

The [HZoi hand scene](content-examples.md#find-other-examples) shows an emitter
that selects clips from a named sound set when two bones approach and separate.
Test the distance threshold and cooldown in game with each speed you support.

## Check the sound in game

Watch and listen through several cycles at different scene playback speeds.
For contact sounds, the detector uses bone distance and direction reversal,
not an animation frame marker or the visible skin surface. Choose points that
approach and separate with the contact you want, then tune distance and cooldown
if sounds are missing or repeated. The source controls where you hear the sound;
it can differ from the detector points.

Mute Sound Effects and confirm these clips stop while the Zoi's voice remains.
Navigate and Exit to check emitters stop. For silence, verify the sound-set ID,
SoundWave paths, declared roles and bone names, then read the SFX warnings in
`scenezoi_runtime`. The HZoi Reference audio files are deliberately silent.

For a one-shot sound when a task finishes, use the [completion sound guide](scene-tasks.md#data-defined-completion-sounds).
