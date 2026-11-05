# Voices

SceneZOI supports optional, participant-owned continuous voices. SceneZOI owns discovery, validation, preferences, UI, spatial playback and cleanup. Content packs own archetypes, contexts, sets and Sound Waves. The framework has no built-in voice families, context enum or HZoi identifiers. Task-completion one-shot responses are described below.

## Independent declarations

Use the existing native declaration transport and pack `data_files` entries with kinds `voice_archetype`, `voice_context` and `voice_set`. Each declaration has `schema_version: 1`. IDs and context references are case-insensitive, trimmed printable ASCII strings (up to 96 characters), separate from display labels. Labels are plain text. A malformed/conflicting declaration is isolated with a warning; unresolved or body-incompatible set references are omitted. Independent authors can reference an existing archetype/context or supply new ones. Build-time malformed declarations fail before generated output changes.

```json
{"schema_version":1,"id":"designer.calm","label":"Calm","body":"female","default":true}
```

An archetype requires `id`, `label` and appearance `body` (`female` or `male`). Optional `default: true` opts that body into initial voice assignment. No compatible declared default means silence, even if other voice sets exist. Multiple defaults warn and resolve deterministically by sorted ID. A character's explicit saved silence always wins.

```json
{"schema_version":1,"id":"conversation","label":"Conversation"}
```

A context requires `id` and `label`. Contexts are data, not runtime enums. The personality panel creates controls from the current discovered contexts. Newly enabled declarations refresh at startup, while idle, and before Start; an active session keeps its library until Exit, like expressions and the scene graph.

```json
{
  "schema_version":1,"id":"designer.calm.conversation","label":"Example voice",
  "body":"female","archetype":"designer.calm","context":"conversation",
  "clips":["/Designer/Audio/SW_Example.SW_Example"],"volume":0.8,"gap":0.25
}
```

A set requires `body`, `archetype`, `context` and 1–512 unique SoundWave paths. `volume` defaults to 1 (range 0–1); `gap` defaults to 0 (range 0–60 native-game seconds). There are no executable callbacks or implicit gender/player indices. Male sets use the same schema and engine.

## Complete content-pack example

HZoi-Reference connects an [archetype](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/archetype_mature.json),
[context](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/context_fellatio.json) and [voice set](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/voices/set_megu_hiiragi_mature_fellatio.json) through matching IDs.
The [scene voice instruction](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L85) selects the context;
[completion bindings](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L207) independently name
the completing role and speaker, then resolve a named `responses` group from
the speaker's chosen set. Its [manifest](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi.json#L161) registers
all three declaration kinds. All reference WAVs are silent because the original
recordings are proprietary, so these files demonstrate structure and timing,
not audible quality or balance. See [the worked trace](content-examples.md#connect-progress-to-independent-responses).

## Player volume

[Scene Settings](settings.md) provides separate persistent 0–200% gains for female
and male voice sets. They scale both normal clips and responses after authored
volume/fades, without changing assignments or clearing add-on mutes.

## Scene instructions

```json
"voices": {"speaker": {"context": "conversation"}}
```

The role must belong to the fixed roster. Missing role instructions, absent assignments, unavailable contexts or an explicit silent choice produce no voice. An absent/failed optional asset does not block body playback. Sound failures appear in voice status and retry at bounded intervals. No voice configuration is inherited implicitly from the previous node.

## Personality and persistence

Voice controls appear below expressions in Personality Management. Select an archetype, then a set for each context. Choosing a different archetype atomically replaces all context mappings with the first compatible set in sorted ID order; unavailable contexts remain silent. A context can also be set to None. Every persisted mapping is checked against that one archetype, context and body. Cross-archetype requests never save.

Preferences use the native entity ID under `scenezoi_voice/zoi_<id>.cfg` in the
game-selected framework cfg directory, independently of save serialization and
session roles. On the tested build this is beneath
`Documents/inZOI/Mods/InGame/SceneZOI_93C44199/`, even when the package is installed
directly under `Mods/`. See [storage locations](settings.md#storage-location).
Preferences retain an explicit silent archetype and silent contexts. Missing pack
IDs become silent without overwriting stored choices; later sessions recover them
after re-enabling the pack. Newly introduced contexts have no assignment until
selected or an archetype reset. Identical native IDs across independent worlds
are not distinguished by a world key. Installers must preserve both expression
and voice preference directories.

Requests have session identity, monotonically increasing counters, expected node revisions and stopping/preparation guards. Saving succeeds before a preference changes in memory. The UI retries absolute requests, rejects stale acknowledgements and incompatible frames, and serializes edits against expressions/outfits/navigation. Voice preferences have their own mailbox and acknowledgement.

Expression defaults continue to use expression-set `default: true` declarations, then the first compatible sorted ID. HZoi marks Pleasure face for female bodies and Confident for male bodies. Existing valid per-Zoi choices remain in force; no HZoi reference is added to the framework.

## Playback and ownership

Every participant owns an independent continuous emitter at the head's jaw bone. The engine reuses SFX's owned, attenuated world audio, asset re-resolution, native pitch limits, optional asset recovery and retryable destruction. No game audio/mix/background-audio preference is changed. Multiple repeated-body participants and concurrent SFX are supported.

Clip choice is uniform among candidates outside the last three successfully played clips. Small pools reduce the exclusion window to `clip_count - 1`, so one-clip sets repeat and two-clip sets alternate without random retry loops. Each set's delay follows native completion after the duration/rate lower-bound estimate, using the same bounded IsPlaying polling and timer fallback as SFX. No native completion callback is introduced.

Scene speed never retimes a voice clip. Native game time controls rate and pause, within the native audio pitch limits. Outfit preparation pauses the current clip and preserves history; navigation stops/destroys outgoing node voices, and arriving roles use their requested contexts. Live preference edits replace only that participant's source. Cleanup failures retain ownership for retry; Exit releases every owned source independently.

## Validation

Isolated Lua/browser tests cover dynamic contexts, malformed data, defaults, persistence, silence, single-archetype resets, male/repeated-body owners, timing, held outfits, live edits, missing assets, cleanup retry and UI acknowledgement/Exit behavior. Recorded maintainer checks with the private HZoi pack additionally verified imported clip ownership, exclusion of response clips from continuous loops, four complete contexts, both silent hubs and renamed scene navigation. ModKit validation and installed hashes are recorded in `validation.json`. These are separate from the author's in-game audio/UI/Exit acceptance.


## Slow-motion audio policy (20261103-audio-slowmotion-1)

For native game time strictly between 0 and 1, SceneZOI audio keeps its normal 1x pitch/playback rate. This covers voices, continuous/contact SFX and completion one-shots, regardless of the control causing slow motion. Pause still pauses audio; native fast-forward retains existing pitch bounds. Scene animation speed never retimes audio. Clip timers use actual audio rate, so clips can finish while animation is still moving slowly. Contact cooldowns and authored gaps retain existing game-time scheduling.


## Task-triggered one-shot voice responses

Runtime `20261103-voice-responses-1` adds optional named `responses` to schema-1 voice sets. These are variants of the participant's already selected set, not new personality contexts or separate archetype choices:

```json
"responses": {
  "praise": {"clips":["/Example/Audio/Praise.Praise"], "volume":0.8},
  "surprise": {"clips":["/Example/Audio/Surprise.Surprise"]}
}
```

Up to 64 response groups are allowed, each with 1–512 unique SoundWave paths. Response names use the same case-insensitive normalized identifiers as voice contexts. `volume` is optional, within 0–1, and inherits the voice set's volume. Empty/malformed/conflicting groups are rejected; imported assets remain owned by the supplying pack. Existing normal `clips`, delays, context choices and persistent preferences are unchanged.

Scene schema 3 adds an optional role/task-to-rules map:

```json
"task_completion_voices": {
  "caster": {
    "spell_charge": [
      {"participant":"listener", "context":"conversation", "response":"praise", "fade_out":0.25, "priority":20}
    ]
  }
}
```

The outer role identifies **who completed the exact registered task**. `participant` independently names **who speaks**. Neither role, task, response name nor body has built-in meaning. This supports a participant reacting to their own completion or another participant's completion, for any supported fixed roster. No male/female/control-index inference occurs.

Each rule requires `participant`, `context` and `response`; all roles must exist in the scene. Optional `fade_out` defaults to 0.25 audio seconds (range 0–5). Optional integer `priority` defaults to 0 (range -1000–1000). There may be up to 32 rules per role/task. Unknown tasks are diagnosed and their rules disabled at discovery. Unavailable groups/assets warn without interrupting normal voice or scene playback. No voice assignment, a silent context, or an unavailable archetype means silence; responses never borrow another set or archetype. Set selection uses the speaker's saved preference for the explicit context.

### Fade, playback and return

The current continuous voice fades to zero, is stopped, and stays suppressed while one random response clip plays once from that speaker's head/jaw position. If no normal voice is playing, the response can start immediately. The response uses its group's or set's full configured volume. Continuous voice then resumes with restored volume, the existing recent-clip history and configured gap. Other participants and SFX keep independent channels. Normal-loop clips and response clips have separate selection behavior: responses use uniform random choice, like the reference implementation.

Fades and response duration use actual audio playback time: native pause freezes them, native positive slow motion retains normal pitch/duration, and fast-forward follows bounded native audio rate. Scene animation speed and procedural slowdown do not stretch or pitch the clips. This uses world audio and preserves the game's background-audio setting.

### Priority and lifetime

There is one response channel per speaker. Simultaneous requests are sorted by descending priority, then deterministic role/task/rule key. A higher-priority response replaces an in-progress lower-priority response with a quick fade; a lower-priority request during a higher-priority response is discarded rather than replayed belatedly. Equal-priority requests queue up to eight pending clips per speaker; duplicates of the same completion index/rule are ignored. A new higher-priority request clears that speaker's old pending queue. Different speakers remain independent.

Preparation/outfit holds pause audio and fading. A started response survives a prepared navigation handoff; incoming continuous voice remains suppressed until it finishes. Unstarted queued requests are cleared on navigation. A live context/archetype change or silence choice invalidating the selected set cancels the active response and its queue. Exit independently stops/destroys every response component, retaining ownership for cleanup retries after partial native failures. Optional response failure releases the channel after cleanup so normal voice can recover.

Task reset/events, definition-level completion sounds, authored routes and procedural effects keep their existing semantics. Voice routing is processed after all update completions are collected and before scene handoff. An authored destination does not silently remove an explicitly configured completion voice; the started line follows the same participant across preparation. This is presentation, not a gameplay consequence or pack-supplied executable callback.

Logs identify speaker, selected set and response on successful playback; heartbeat status reports plays/active channels and optional errors. Tests cover three independent speakers, fades, priority suppression/preemption, own/partner identity, random groups, continuous resumption, pause/slow-motion/native rate, scene speed independence, navigation, silent/live preferences, missing assets, partial play and retryable cleanup. Native audible acceptance is recorded separately in validation reports.


## Native audio completion (20261103-audio-finish-1)

The duration/rate estimate is now a lower bound for normal completion, not a forced stop. Once it expires, SceneZOI waits for the native AudioComponent to stop playing before recycling continuous clips, releasing one-shots or resuming normal voice after a response. This protects short tails and newly selected voice sets from audio-thread/startup delay. Pause freezes completion and its watchdog. A two-audio-second observed-wait watchdog bounds broken/looping native components; a long initial asset-loading frame does not consume this watchdog. If native state is unavailable, the existing timer fallback remains. Explicit voice-set changes, response priority fades, navigation, bounded pool stealing and Exit still intentionally stop owned playback.
