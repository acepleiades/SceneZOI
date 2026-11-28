# Make task completion visible

<a id="task-completion-responses"></a>

A sexual scene can respond to orgasm by slowing the thrust or stroke rhythm
and adding leg shaking. Use `completion_responses` to apply these effects to
the existing loop, without exporting a separate orgasm clip. Other tasks can
use the same effects where they fit the action.

The response uses the animation's **1× baseline**, regardless of the scene
playback selector. Choosing 0.5× before completion does not double its duration.
The game's pause and fast-forward controls still affect it. Voices and contact
sounds are configured separately, so use the
[voice engine](voices.md#task-triggered-one-shot-voice-responses) for vocal reactions.

## Add a response to your scene

The JSON below is a fragment for a loop with a `male` role using `excitement`.
It slows two movement cycles and twists the listed leg bones for three seconds.
Keep the role and bone names consistent with your actual scene and skeleton.

`movement_timing` must describe your clip at 1×. For a repeating one-second
thrust or stroke cycle at 60 fps, the deepest point at frame 30 is phase 0.5.
Do not copy that timing into a clip with a different rhythm.

```json
"movement_timing": {"cycles_per_second": 1, "peak_phase": 0.5},
"completion_responses": {
  "male": {
    "excitement": {
      "enabled": true,
      "slowdown": {
        "repeats": 2,
        "high_speed": 0.5,
        "low_speed": 0.08333333333333333,
        "recovery": 0.4,
        "fallback_duration": 6
      },
      "shake": {
        "delay": 0.5,
        "duration": 3,
        "bursts": 1,
        "duty_cycle": 1,
        "frequency_hz": 18,
        "amplitude_degrees": 1.25,
        "bones": [
          {"bone":"thigh_l", "child":"calf_l", "weight":1},
          {"bone":"calf_l", "child":"foot_l", "weight":0.4}
        ]
      }
    }
  }
}
```

Put these fields in the scene JSON, alongside its `tasks`, rather than in
the shared task definition. The task must actually complete in that scene.
For example, a 50% cap prevents completion from zero even if a response is
declared. A shake-only response can omit `slowdown`.

## Check the result in game

Reach completion at different scene playback presets and compare the response
duration. With the game at Normal, it should stay the same; pausing or
fast-forwarding the game should pause or accelerate it. Check the deepest pose
lines up with the slow hold and that attachment tracks stay synchronized.

Watch the feet and furniture contacts from several angles. Reduce amplitude
or change the bone weights if the shake breaks the pose. Navigate or Exit
during the effect and confirm it leaves no continuing shake. If nothing starts,
check the task cap, exact role/task IDs, bone names and diagnostic warnings.

## Complete content-pack example

HZoi-Reference's [movement timing and response block](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/02_standing_hand_job.json)
uses one cycle per second and peak phase 0.5. The male role requests shared
slowdown plus its own shake; the female role requests only its own shake. Its
[task rates](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/02_standing_hand_job.json) cap female progress at 50%, so that authored
response does not imply she completes from zero in this node. Compare
[Standing Rear Sex](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/04_standing_rear.json), where both roles can reach 100%.
The reference clips are rest-pose
placeholders, so the blocks demonstrate response settings rather than HZoi's
authored motion. Use your own compatible clips or the installed player pack for
a motion test. The [worked guide](content-examples.md) explains the reference's
scope and independent ownership.

## Response priority

For each completion update, commit every participant's completion first. If any valid scene-local `task_completion_routes` entry matches, select the existing deterministic authored route and bypass procedural responses for that update. The destination may be a loop or a transition. If a selected route fails to load, report its failure; do not silently substitute a procedural response.

Otherwise, match `completion_responses[participant_role][exact_task_id]` to the actual completing participant. `enabled: true` explicitly opts into the supplied effects. With movement timing, a configured slowdown synchronizes to it; without timing it uses its general fallback. An omitted/disabled response causes no visual change. A shake-only response does not slow playback. Multiple tasks and any supported fixed roster, including repeated body types, use the same rules. Unknown task IDs are diagnosed and isolated at discovery. Strict source/runtime validation rejects malformed fields, unsafe values and response declarations on transition nodes.

## Regular movement timing

Use the basic repeating motion as the timing reference. A longer change in
posture can span several strokes without changing where the low-speed hold
should land in each stroke. [Basic and gradual cycles](dictionary.md#motion-and-timing)

`cycles_per_second` describes the consistent underlying movement in the exported clip at default playback speed, even when slower gestures or pose changes are layered into that clip. It is within 0.001–60; clip duration times frequency must be a positive whole number, so the uniform rhythm repeats at the clip seam.

`peak_phase` defaults to 0.5, within 0–1. It names the pose around which the lowest-speed hold is centered. For a one-second cycle authored at 60 fps, phase 0.5 is frame 30; phase 0 and 1 describe the same repeating endpoint. Cycle response boundaries are half a period before/after each peak. The engine plays at the authored 1× baseline until it reaches the next response boundary, so synchronization preserves clip phase.

Slowdown uses linear speed ramps in effect time. With default high/low values, a one-second authored cycle takes four effect seconds: 1.6 seconds to slow from 0.5 to 1/12, 0.8 seconds at 1/12, and 1.6 seconds to return to 0.5. The central pose is reached halfway through the low-speed hold. Two repeats therefore traverse two authored seconds over eight effect seconds, followed by recovery. This reproduces the reference envelope while avoiding frame-step drift through exact integration. No animation assets are generated.

## Uneven movement timing

For a rhythm that changes during a loop, replace frequency/phase with explicit equivalent peak-pose times in the original clip:

```json
"movement_timing": {"peak_times": [0.3, 1.1, 2.7]}
```

For a four-second clip, these are three authored peak moments. Markers must strictly increase, be within `[0, duration)`, and number 1–4096. Do not repeat the clip endpoint. Frequency and markers are mutually exclusive. Response boundaries lie halfway between neighboring peaks, including across the loop seam. Each side's ramp/hold duration adapts to its actual distance to the peak, so unequal intervals still put the lowest-speed hold around the authored pose. This supports changing cycle spacing; its visual quality still depends on meaningful markers. It does not infer physical contacts from bones.

## General fallback and settings

Omit `movement_timing` while supplying `enabled: true` and `slowdown` to permit the fallback. It uses 40% of `fallback_duration` to ramp high-to-low, 20% to hold and 40% to ramp back, then recovers to the authored baseline. It cannot promise alignment to a pose. `repeats` is used only for synchronized cycles; fallback duration is the complete envelope duration.

| Slowdown property | Default | Valid range |
| --- | --- | --- |
| `repeats` | 3 | Integer 1–32 |
| `high_speed` | 0.5 | 0.001–1 |
| `low_speed` | 1/12 | 0.001–high_speed |
| `recovery` | 0.4 seconds | 0.001–30 |
| `fallback_duration` | 6 seconds | 0.01–300 |

The motion response advances on native simulation time from the authored 1× baseline. At normal simulation speed, the example two-repeat envelope lasts eight seconds plus synchronization wait and 0.4 seconds of recovery at every scene playback preset. The game's pause and fast-forward controls also apply to the response. Body and attachment tracks share its sampled time. Task progression and audio follow their own clocks.

Auto-mode and the player retain control of the selected preset under their usual rules. The response temporarily supplies the animation sampling rate, and ordinary playback resumes at the selected preset and any active add-on speed factor once the profile finishes.

## Generic shaking

The shake starts after its own game-time delay, independently of synchronization wait and playback slowdown. It applies sinusoidal local rotations with a triangular fade-in/out envelope per burst. Each burst spends `duty_cycle` of its interval shaking and the rest at zero correction. It uses native game time, not scene animation speed or the slowdown multiplier. Pause freezes the current shake pose.

| Shake property | Default | Valid range |
| --- | --- | --- |
| `delay` | 0.5 seconds | 0–30 |
| `duration` | 6 seconds | 0.01–300 |
| `bursts` | 3 | Integer 1–64 |
| `duty_cycle` | 0.7 | 0.001–1 |
| `frequency_hz` | 18 | 0.001–60 |
| `amplitude_degrees` | 1.25 | 0–45 |
| `bones` | Required | 1–64 unique bone entries |
| Bone `weight` | 1 | -2–2 |

Each bone entry requires `bone` and its direct `child`. Their local longitudinal axis defines the twist. Weight controls signed intensity, allowing a counter-moving opposite side. Reference-like leg profiles use upper/lower/foot weights 1, 0.4 and 0.05, with opposite-side weights multiplied by -0.8. Twisting minimizes positional disturbance; this is not a foot-locking IK solver and cannot guarantee planted contacts for every rig/pose.

Shaking adds temporary local rotations to the existing body animation and
removes them afterward. Missing or unsupported bones warn and disable the
affected optional shake; task completion, sounds and body playback continue.
Clothing changes preserve ownership and reapply the effect to the current body.
See [runtime contracts](tier1-contracts.md) for cleanup implementation details.

## Concurrency, lifetime and diagnostics

All completions remain independent. One shared slowdown may be active at a time. Simultaneous eligible requests are sorted by role/task/participant ID, using the same stable convention as authored routes. Other participants still receive their own shaking. A later completion during an existing slowdown does not stack or queue another slowdown. Each participant owns at most one shaking response; a new completion restarts that participant's shake after releasing its previous correction. Completion indices suppress duplicate requests.

Outfit preparation freezes effect clocks and preserves ownership through body changes. Navigation cancels the slowdown and shaking; selected speed and session task progress remain. Exit releases every owned correction, retrying partial cleanup through the normal subsystem lifecycle. Transition nodes retain their existing all-task freeze and do not start these responses.

`Runtime.snapshot().completion_effects` exposes plain diagnostic state: `stage`, `source` (last participant/task key), `starts`, `shaking_participants`, and optional last `error`. It contains no mutable native objects. Independent add-ons use [version-1 session/task events and get_session](addons.md); visual responses do not redispatch completion. Logs include slowdown start/finish and heartbeat status with the current integrated speed factor and shake-owner count. This is scene-local presentation; gameplay mods should subscribe to the normal task-completion API for consequences.

Source checks verify timing and cleanup rules, but cannot judge whether a
shake fits your animation. Use your own clips or the player pack for that
visual check; HZoi Reference contains rest-pose replacements.
