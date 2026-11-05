# Scene settings

The cog is the third scene tool, after Outfit Management and Personality
Management. It opens Scene Settings in the same attached panel. Only one of
these panels is open at a time; task-tray ordering, resizing, compact mode,
native-menu blocking and Exit behavior are shared.

## Task progress

Female Task Progress Rate and Male Task Progress Rate appear above the volume
controls. Both accept whole percentages from **10 to 500**, default **100**:

- 50% adds progress at half the authored rate.
- 100% preserves the authored rate.
- 200% adds progress at twice the authored rate.
- 10% adds progress at one tenth the authored rate.
- 500% adds progress at five times the authored rate.

The participant's captured **appearance body type** selects the control. Role
names, biological gender, control status and participant order do not select it.
Each participant retains independent progress. These global preferences persist
across scenes, saves and game restarts (`scenezoi_settings`, key `task_rates`),
independently of the existing `audio` preferences. Previously saved task rates
below 10% load at 10%, preserving the other valid settings. Changes affect the next
eligible task update without resetting accumulated progress.

**Effective positive rate = authored rate × player percentage / 100 × combined
add-on rate multiplier.** The player setting affects positive accumulation only;
authored negative rates and omitted-task decay retain their existing rates.
Explicit zero rates still hold. Caps, pause/preparation/transition guards,
completion holds, reset/events and direct API progress edits keep their existing
semantics. An already-ready task can still complete on the next eligible tick
at the minimum player rate; this is a rate control, not a completion hold.

## Audio volume

| Control | Applies to |
| --- | --- |
| Sound Effects | Scene continuous/contact emitters and task-completion sound effects |
| Female Voice Sets | Continuous voices and one-shot responses from sets declared with `body: female` |
| Male Voice Sets | Continuous voices and one-shot responses from sets declared with `body: male` |

Each control accepts whole percentages from **0 to 200**, default **100**. Drag
the slider and release to apply, use arrow keys (Page Up/Down steps by ten;
Home/End selects the limits), or type an exact number and press Enter or leave
the field. Saving starts on release/commit, rather than writing every drag frame.
The controls show loading, saving and storage failures. They remain usable while
playback is paused; preparation, navigation and Exit reject conflicting edits.

These are global player preferences, saved across sessions and game restarts
in SceneZOI's configuration (`scenezoi_settings`, key `audio`). They do not
depend on a particular content pack or selected participant. Other settings and
personality preferences are preserved. They are not restored to 100 on Exit.

The engine receives **authored volume × fade × user percentage / 100**. A change
updates existing owned components, including paused ones, and subsequent sounds.
It does not restart clips, alter pitch, discard a fade or clear an add-on's mute.
Female/male routing follows the selected voice set's declared body, independent
of role, participant order and player control. Authored JSON volume fields keep
their existing 0–1 limits; content authors should balance assets at 100%.

200% is a 2.0 gain multiplier, not a promise of twice the perceived loudness.
Unreal exposes a float [AudioComponent volume multiplier](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UAudioComponent).
The final output also depends on the recording, attenuation and the game's audio
mix; boosting already loud audio can cause distortion or limiting. SceneZOI
changes only its owned components, leaving ordinary game sounds and game-wide
audio/background preferences untouched.

## Storage location

SceneZOI uses the game's supported `uimod.cfg_load` / `uimod.cfg_save` commands.
They accept a mod ID, section, key and value; they expose no base-directory
override. The game chooses the cfg directory. SceneZOI does not construct an
`InGame` output path or implement a second filesystem backend.

On the tested retail build, the package is installed at
`Documents/inZOI/Mods/SceneZOI_93C44199/`, while cfg output is under
`Documents/inZOI/Mods/InGame/SceneZOI_93C44199/`:

| Subdirectory | Purpose |
| --- | --- |
| `scenezoi_settings/` | Global audio and task-rate preferences |
| `scenezoi_personality/` | Per-Zoi expression preferences |
| `scenezoi_voice/` | Per-Zoi voice preferences |
| `scenezoi_runtime/` | Runtime transport, status and diagnostics |

This data directory may exist without a `mod_manifest.json`; it is not another
installed copy. Removing the package alone can leave preferences and diagnostic
state behind. Updates should preserve the data. A completely fresh test must
back up and clear both the package and its separate cfg data while the game is
closed and scene cleanup is complete. See [the developer workflow](development.md#package-location-and-persistent-data).

## Implementation and verification

`Settings.lua` owns bounded, versioned preference storage and session-scoped
request acknowledgements. Task rates and audio have independent storage and
request counters, so editing one group cannot overwrite the other. Settings
persist before changing live rates or gains. Stale
session/revision packets cannot change the saved values; malformed records fall
back atomically to defaults. `SoundNative.lua` applies gains once to the current
unscaled level and isolates failed components for their ordinary retry/cleanup.
`settings-ui.js` supplies the custom draggable controls and exact numeric fields.

Regressions cover persistence/restart, bounds/storage failures, stale UI frames,
independent group retries, panel exclusivity, body selection, add-on factors,
task caps/decay/completion holds, audio routing, fades, paused audio, new
components and independent cleanup. Installed/native evidence and author UI/audio acceptance
are recorded separately in [validation](validation/README.md).
