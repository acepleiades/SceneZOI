# Scene runtime contracts

These contracts describe the current framework. “Tier 1” in the filename is historical; later optional engines extend the same ownership and lifecycle. See [validation](../validation.json) for current recorded build markers and separate acceptance evidence.

## Ownership

| Owner | Responsibility |
| --- | --- |
| Runtime | Entry, preparation, requests, retries, watchdogs, navigation and Exit coordination |
| Session | Fixed participants/roles, original restoration snapshots, anchor/furniture context, speed and session lifetime |
| Binding | Explicit distinct Zoi-to-role assignments, actual appearance-body compatibility and independent control identity |
| Catalog | Validated native scene declarations, cross-pack links and asset loading before mutation |
| Playback / Clock | Owned montage bindings and one shared sampled animation clock on existing game instances |
| Subsystems | Optional node engines, explicitly retained session resources and independent retryable cleanup |
| Events | Deferred copied snapshots, isolated observers and best-effort native client notifications |
| UI | Acknowledged state and absolute session/revision-scoped requests, not restoration or animation ownership |
| B2 participant/furniture leases | Task interruption, original autonomy/inheritance, collision/position restoration and exclusive furniture reservation |

SceneZOI stops only its own montages. It never replaces the game's animation instance or toggles Smart Zoi. Membership and named-role assignments remain fixed until Exit. The picker supports one to three Zois with compatible authored roles, including repeated body types. The bundled neutral library includes two solo standing hubs and three adult-compatible male/female paired hubs.

The B1 actor registry maps each Zoi ID to its latest registered native actor.
An ending object removes that entry only if it still owns it; late or repeated
cleanup cannot erase a replacement object with the same ID. Unloading an actual
session participant still requests normal cleanup even if the registry now
contains a replacement. See [actor registration regressions](../tests/actor-registration.lua).

B2 leases disable autonomy before interruption, clear native waiting queues before cancelling current work, and wait for two idle callbacks before preparation. Cancellation is keyed by current queue identity, so a successor/new task is independently interrupted without repeatedly cancelling the same asynchronous exit. Task checks continue after readiness. Exit/failure/expiry restores the original autonomy value and inheritance through the existing retryable cleanup. Waiting tasks are cancelled, not serialized or replayed; there is no established supported queue-pause contract.

## Save and load ownership

Autosave is a global settings lease separate from the per-save participant journal. Only the session containing the controlled Zoi can suspend autosave. The lease transfers when control moves between sessions and restores the setting when control leaves all sessions. Initial acquisition reads `gameplay.get_settings` once and persists `autosave_lease` locally before calling `gameplay.set_autosave enable=false` only for an originally enabled setting. Normal/error completion and mod unload restore that owned enabled flag. Failed restores retry independently while idle and block new acquisition; boot recovers an outstanding persisted lease after an interrupted runtime. The interval and an originally disabled setting are never written. A released record cannot override later user preferences. The existing SDK provider remains active for manual saves and forced autosaves.

SceneZOI uses the supported UI SDK SaveState channel (`wf.state.scenezoiSaveJournal`). Each B2 participant first offers a primitive original-state record without taking ownership. B1 publishes a complete roster plus optional furniture owner/ID; the live controls view caches it and acknowledges that exact client/sequence/token before B1 can reserve furniture or commit participant autonomy/task/collision changes. Navigation and appearance edits never replace this entry record.

The synchronous SDK save provider requests Exit for every active session with reason `saving` and returns the cached multi-session journal. The native callback is late relative to some B2 serialization: an asynchronous Exit alone is not a pre-serialization barrier. Lua `on_savegame` callbacks and the pseudo-simulation manager override did not dispatch on the tested retail route and are not relied upon. The unsupported override was removed.

On SDK load delivery, controls block entry and submit the journal to B1. B2 restores each original collision/autonomy value and inheritance, position/rotation and mesh-merge flags, removes only SceneZOI's exact temporary costume while preserving other outfit layers, puts back a work uniform if an older recovery record confirms it was borrowed, and removes Restricted occupancy only for the recorded furniture owner on the recorded object. Participant and furniture acknowledgements are independent; retries retain unfinished work and skip acknowledged owners. Unresolved records carry over in later saves until their resources are confirmed released or restored. Adding a new session preserves older records. The new session waits for the UI to acknowledge a readable journal before committing participant or furniture changes. Entries that overlap unrecovered resources are refused. No scene, interaction queue, attachment or animation is resumed.

This recovery requires SceneZOI to remain enabled on load. Exit, finish cleanup and save outside scene mode before removal. It does not retroactively repair saves made by older builds that lack a journal, and is not a claim about unrelated save-file corruption.

## Time and navigation

Animation advances by unscaled host delta × effective native game time scale × selected scene speed, with an optional shared procedural-completion multiplier. Speeds are 0.50, 1.00, 1.50 and 2.00, default 1.00. Native pause freezes animation. Speed survives navigation and resets for a new session. Preparation holds do not accrue catch-up time. Heartbeats, Exit and cleanup remain independent of animation time.

Task rates/decay and audio scheduling use native-game time independently of the animation selector. Positive native slow motion retains normal audio rate; pause is separate. See [tasks](scene-tasks.md), [voices](voices.md) and [SFX](sfx.md).

Navigation validates/loads the destination before changing the outgoing pose. Existing zero-rate owned montages hold their shared sample through participant acknowledgements, resolved appearance, attachment readiness and arriving preparation. Revisions/counters reject stale work. At readiness, synchronized tracks switch together; original session snapshots are never recaptured. Target load failure leaves the current node intact; mutation/preparation failure requests normal cleanup.

Loops and [one-shot transitions](transitions.md) are supported. Transition nodes clamp at the final pose, lock manual navigation, freeze all tasks/decay and hand off to a declared compatible destination. Speed and Exit remain usable. No automatic transition choreography is invented.

## Outfits and appearance

Each participant lease captures original garment/accessory descriptions and ownership once. Automatic remove_slots directives accumulate in SceneZOI's sparse Script layer; omitted directives retain current state. A game work outfit (Job costume tag, in the Script slot as the newest layer) is taken off for the scene and put back afterwards; any other foreign Script ownership is refused. Manual controls toggle only session-entry pieces and preserve original materials/transforms/accessory data. A later node's explicit removal can override a manual restore. Base styles and original snapshots are not rewritten.

Requests, resolved appearance and session-entry originals are distinct. B2 acknowledges the game's resolved garment results, including native underwear normalization. B1 waits for those results, a stable game instance and optional material/body readiness. Outfit edits hold the current pose/time, then resume without restarting the node. Counters/revisions prevent stale acknowledgements; Exit discards pending UI retries and releases the original state through independent cleanup.

Coverage attachments are declared by content through coverage_attachment, body_profile and material_profile. Resolved garment coverage, not slot names or “all clothes removed”, controls activation/visibility; already exposed bodies and manual edits at neutral hubs use the same generic rule. The retired attachment_extensions authoring field is rejected. Specific coverage bits, mesh layouts and replacement geometry belong to the content owner.

Retained attachments keep independent owner/component/material/body snapshots across navigation. Their tracks share the participant clock; unrelated non-covering edits can preserve visible playback through readiness. Covering or unknown edits retain hide-before-ready. Mesh rebuilds reassert required layout without recapturing originals. Parent native structs remain alive while borrowed fields are read. Missing readiness and partial cleanup must remain retryable.

## Events and UI lifecycle

SceneZOI.Events.subscribe(name, callback) and unsubscribe(handle) operate within the framework B1 dispatcher; wildcard subscription observes all events. Each observer receives an independent plain snapshot. Deferred delivery retains queued notifications beyond the flush budget rather than discarding them. Independent add-ons receive copied lifecycle/task/routing events through the JSON SceneZOI.API.Event contract. The obsolete packed client bridge is removed; no durable cross-host replay is promised.

Separate session-scoped mailboxes carry navigation, speed, outfits, personality, Exit and heartbeat. Absolute requests, monotonic counters and node revisions prevent duplicates or stale work from changing a newer session. A separate preloaded launcher and persistent controls receiver retain host-generation readiness and native picker/input restoration. The Hide tab preserves heartbeat; modal native blocking gates presentation/input without treating ordinary pause as modality.

## Add-on sessions and restrictions

Independent B2 mods use native JSON messages through the versioned SDK. Acceptance
queues startup; it does not bypass group departure, UI save-journal acknowledgement,
technical eligibility or preparation. Fixed participant roles, save protection and
normal cleanup retain the same owners as manual sessions. Only the creating
add-on/client owns navigation and `stop_session`; a registered integration with
interruption rights may request ordinary Exit through `request_stop`. The player
retains Exit.

One shared predicate handles metadata queries, random selection and session-owned
restrictions. The backend enforces restrictions for direct/UI navigation, automatic
transition chains and task-completion destinations, and publishes filtered controls.
An action's highest declared enum rating determines the scene rating; unclassified
scenes cannot match an explicit rating filter. [Metadata](scene-metadata.md) is inert
and does not implement consent/gameplay decisions or detect rendered content.

## Regression and acceptance constraints

Retain meaningful checks for first-click/cancel/repeat entry, explicit repeated-body roles, delayed preparation, native-instance preservation, original outfit restoration, resolved-underwear acknowledgements, rebuild barriers, independent retained attachments and partial cleanup failures. Furniture adds reserve-before-prepare and release-acknowledgement barriers. Test movement/furniture use after Exit as well as repeated playback. See the [issue ledger](investigations/runtime-and-ui-issues.md).

Automated suites, native numerical diagnostics and author visual acceptance establish different things. Consult [validation](../validation.json), not historical marker literals, before testing a loaded build. The [public native-message API is version 1](addons.md). Internal Lua modules, UI mailboxes and manual picker transport are private development interfaces. Scene metadata and schema compatibility are documented separately.

## Control focus and duplicate entry

Actual B1 controller identity, not the participant's captured entry-control trait, selects the focused session. The panel, task tray, input and autosave suspension follow that session. Control can move anywhere without ending a scene. A manual household scene ends with `lifetime_expired` after 60 real seconds without its panel. Returning resets that interval. NPC-only picker starts and add-on background sessions have bounded lifetimes. Closed-panel input uses a currently registered world-context actor. A failed or missing controller lookup is not treated as a switch.

Busy entry is a native toast and rejection, including stale launcher/native/runtime requests. The active session's status mailbox is preserved; duplicate rejected commands do not repeatedly toast. Optional toast failures cannot end the existing session. last_stop records the initiating reason, last_exit records final and initiating results, and controller_range retains the latest bounded distance/readiness diagnostic. An older last_error is not evidence of a new failure.

## Overhead presentation

SceneVisuals owns temporary hidden flags only on the fixed scene roster's selected-marker components. Outside-roster markers remain under ordinary game control. It does not deactivate native effects, replace assets or change global cheats/settings. New/replaced objects are covered; initial flags are preserved. Exit/error/mod unload restore independently, with failed cleanup retried while idle and positive invalidity retiring released objects. Optional presentation errors cannot abort gameplay/participant cleanup. Another owner changing a value after our final write wins over snapshot restoration. Retain `tests/scene-visuals.lua`; native rendered acceptance is separate.

Speech bubbles and thought icons are withheld at their source. The B2 `Scripts.B2Script_SpeechBubble` chunk drops `AddSpeechBubble` and `AddInnerThoughtIcon` for a Zoi held by a participant lease and passes every other call to the game unchanged. A Zoi joining a scene also loses its script thought icon and its last speech bubble. A failed lookup passes the bubble through. Icons the game sends without a script command (interaction, talk, social reaction and gathering categories) are not covered. The chunk is a single native override, so another mod defining the same chunk conflicts with it. Retain `tests/speech-bubbles.lua`.

## Actor registration

A bound Zoi can initially have native Invalid ID (`-1`). Do not index that shared
sentinel: retry its registration until a valid ID is available, then stop retrying.
Retain the ID that was registered for teardown, since the native actor may have
already reset it. An ending actor removes only its own entry; actual session
participant-unload cleanup remains independent. See the
[callback regressions](../tests/actor-registration.lua).
