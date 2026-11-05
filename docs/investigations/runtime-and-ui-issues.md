# Runtime and UI issue ledger

Concise retained failures and regression requirements for the first-release
implementation. Current readiness and verification limits are in
[validation](../validation/README.md). Source regressions, native readbacks and
author acceptance are distinct; these findings do not imply universal coverage.
The full development transcript and raw checkpoints are archived privately.

## Entry, participants and cleanup

| Failure / boundary | Resolution and regression to retain |
| --- | --- |
| An old actor object ending after a replacement registered the same entity ID erased the replacement from the runtime registry. | Remove an entry only when it is still owned by the ending actor. Keep actual session-participant unload cleanup independent of that registry guard. The real callback [regression](../../tests/actor-registration.lua) failed before the fix and passes afterward; current actor removal, duplicates and unrelated Zois are covered. [Checkpoint](../validation/actor-registration-20261105.json). Candidate 1.0.2 also passed native validation and the author's update Start/Exit check. This does not establish the cause of the customer report below. |
| Customer Start reaches entry but the controlled ID is absent. This persists in 1.0.2 across the reported saves/Zois. | The 1.0.2 diagnostic proves callbacks execute (41 registrations, 25 unregistrations) and shows 15 remaining IDs, including invalid `-1`; no numeric equivalent of the requested ID and no non-owner cleanup are present. One-shot registration incorrectly accepts an unassigned ID. Candidate 1.0.3 rejects it and retries each bound actor until identity is ready, retaining the registered ID for teardown. The multi-actor regression failed before this fix. Native validation, packaging and the author's local update Start/playback/Exit passed with final idle/ok and cleanup ok/ok. [Checkpoint](../validation/deferred-registration-20261105.json). Customer causality/acceptance remain pending; do not equate the framework lookup failure with absence from the game world. |
| SceneZOI 1.0 fresh installs hid all Start entries: missing `selection_request` rejected the controls handshake, whose cached host identity prevented retry. Existing developer cfg and permissive UI fixtures masked it. | Initialize the absent mailbox before publishing host readiness; commit UI host identity only after successful acknowledgement and serialize polling. Tests must model native missing-key failures and transient read/write failures. [Entry](../../tests/entry.lua), [receiver](../../tests/demo-entry.cjs) and [checkpoint](../validation/fresh-install-startup-20261105.json). Native validation, exact 1.0.1 ZIP clean installation, automatic startup, playback and final Exit passed; the author confirmed it works. |
| Participant animation-instance replacement left later movement/furniture tasks stuck. | Use owned montages on the game's existing instance; stop only owned tracks. [Native playback](../../tests/native.lua). |
| A backlog advanced while the current interaction was being cancelled, causing preparation timeout. | Clear waiting work first, track cancellation by queue identity and require two idle callbacks. Keep guarding during scene ownership and restore original autonomy/inheritance. Cancelled work is not resumed. [Participant tasks](../../tests/participant-tasks.lua). |
| An outside-roster controlled Zoi could move away until participants failed. The initial 50 m trial failed; the author accepted 35 m with a half-second grace. | Query actual controller identity and request ordinary distance Exit. Preserve the measured initiating reason separately from cleanup result. [Range guard](../../tests/controller-range.lua). |
| A second Start failed silently. | Reject with a native toast, without overwriting active status or repeating stale commands. [Entry](../../tests/entry.lua) and [menu](../../tests/menu.lua). |
| Participant callbacks could finish Exit before furniture release was acknowledged. | One shared cleanup predicate covers participants, native restoration, optional/add-on engines and furniture. Preserve retry/timeout behavior. [Furniture leases](../../tests/furniture-lease.lua). |
| Save callbacks did not run on the actual Save As route; SDK Exit alone was too late for some native serialization. | Cache immutable originals through the UI SDK journal before any mutation; recover independent owners on load. SceneZOI must be enabled for recovery. [Save bridge](../../tests/save-bridge.lua). |
| Scheduled autosaves interrupted scene playback. | Suspend only an originally enabled setting, persist ownership before mutation, restore/retry on Exit/boot, and keep manual/forced-save guards. [Autosave](../../tests/autosave.lua). |
| World teardown may prevent final notifications. | Do not infer a complete final acknowledgement from an old last-exit value. The recorded interrupted trial had separate idle/state/furniture readback. Add-ons must reconcile on host change. |

## Appearance, placement and presentation

Player-facing text now uses inert localization declarations, selected from the
retail language setting at save-load initialization and session start. Framework
messages, native entry/picker text and content labels share per-entry English
fallback. A Windows-default-code-page test reader failed on the multilingual
native patch; generated JSON inputs are read explicitly as UTF-8. Translation
placeholders and conflicting documents are validated before writes. See
[localization](../localization.md) and its [regressions](../../tests/localization.lua).


| Failure / boundary | Resolution and regression to retain |
| --- | --- |
| Request acknowledgements did not prove the game's resolved outfit/body was ready. | Keep original snapshots, resolved garment acknowledgements, revision/counter checks and held outgoing poses separate. [Appearance](../../tests/appearance.lua) and [outfits](../../tests/outfit.lua). |
| Covering/non-covering edits and copied/rebuilt heads could reset visibility or ownership. | Retain independent resources, hide conservatively until readiness and rebind without recapturing originals. [Attachments](../../tests/attachment.lua), [body](../../tests/body.lua) and [materials](../../tests/materials.lua). |
| A positional reflected transform constructor produced invalid furniture placement. | Construct the transform and assign translation, quaternion and scale explicitly; retain plain-number validation snapshots. [Placement](../../tests/furniture-placement.lua). |
| Gaze briefly snapped forward during navigation. | Retain the outgoing target through preparation and atomically replace it on entry. [Gaze](../../tests/gaze.lua). |
| Sampling every expression at frame zero froze its authored blink motion. | Loop unsampled clips on scene time; explicit samples deliberately hold a pose. [Expression native adapter](../../tests/expression-native.lua). |
| After restoring animated blinks, strong mood expressions flickered through the selected face. | Disable automatic end fading on the owned sampled montage; retain explicit transition/Exit blending. A simulated native end-fade regression loops ten clips without losing ownership. [Expression native adapter](../../tests/expression-native.lua). Author reported the requested ecstatic/content check fixed; final Exit/cleanup was ok/ok. |
| Manual edits exposed a replacement body's covered region when no coverage attachment was active. | Reassert resolved garment masks for declared, layout-validated body profiles even when attachment creation is skipped; do not force uncovered sections visible. [Clothing masks](../../tests/clothing-mask.lua). Author reported the requested third-party mesh outfit checks fixed. |
| The settings persistence hint inherited large default text after the panel refactor. | Style both actual settings status IDs with the shared 12px hint rule. [Settings UI](../../tests/settings.cjs). |
| Japanese/Chinese navigation and Exit showed glyph boxes while the title rendered correctly. | The button font override omitted the game's CJK fallback faces. Use the complete native UI font variable directly on these controls. [Localization UI](../../tests/localization.cjs). The earlier Japanese visual report missed this; the author confirmed the corrected Japanese and both Chinese glyph checks work. Final Exit/cleanup was ok/ok. |
| Runtime reference calibration delayed O activation; hidden samplers disagreed with the visible head. | Use validated pack-owned fixed facial targets with no reference playback or cache. Accepted O coordinates are preserved; unsupported rigs release/report the optional pose. [Facial poses](../../tests/facial-pose.lua). |
| Quaternion round trips caused ambiguous ownership/duplicate fixed-pose rows. | Normalize rotations and compare equivalent signs; preserve foreign entries, copied-head adoption and cleanup retries. [Facial poses](../../tests/facial-pose.lua). |
| A pose-only API override could survive release when no facial clip was owned. | Release pose ownership independently of clip ownership. Switching joint subsets removes the old footprint; fixed eyeballs suspend gaze until released. [Expressions](../../tests/expressions.lua). |
| Bubble-wrapper opacity alone failed visually. | Suppress exported child content too and restore original opacity. Scope is local-UI-wide because no supported bubble-to-Zoi association was established. Markers remain participant-scoped. [Scene visuals](../../tests/scene-visuals.lua). |
| Modal native UI could leave scene controls interactive or incorrectly presented. | Use the existing blocking-state gate, release hover and move native hit bounds while blocked. Ordinary time pause is not modality. [UI lifecycle](../../tests/panel-state.cjs). |

## Audio, events and independent add-ons

The formerly inactive cog now opens [Scene Settings](../settings.md) in the shared
configuration panel. Three persistent volume channels scale authored/faded audio
once, including voice responses and paused components. The author accepted the
volume controls; retained diagnostics showed normal Exit/cleanup and no discovery
warnings. Two appearance-body task progress controls now appear above the audio
section (10–500%, default 100%). They multiply positive progress independently from decay, caps and add-on
completion holds. Regression coverage: [settings](../../tests/settings.lua),
[UI](../../tests/settings.cjs), [task rates](../../tests/task-settings.lua),
[native audio](../../tests/sfx-native.lua) and [voice routing](../../tests/voices.lua).
In-game acceptance of the new task controls is pending.


| Failure / boundary | Resolution and regression to retain |
| --- | --- |
| Audio duration/pitch incorrectly included animation speed or stopped before a native tail completed. | Separate audio/native time from animation time; wait for native playback completion with bounded fallback. [SFX native adapter](../../tests/sfx-native.lua). |
| Muted voices briefly restarted during clothing re-entry; intentionally suppressed responses logged false missing-asset warnings. | Skip muted continuous entry and distinguish suppression from asset failure. [Voices](../../tests/voices.lua) and [responses](../../tests/voice-responses.lua). |
| A mounted scaffold worked in diagnostics but did not auto-load scripts/declarations after restart. | Create/register a native project through ModKit, preserve generated metadata/protection, and test a clean process launch. [Authoring pitfalls](../addon-authoring.md). |
| Lua/data-only packaging had no cooked response/container and an empty asset-hash document. | Validate an exact assetless allowlist; reject unexpected/cooked/native payloads. [Assetless packaging](../../tests/assetless_package.py). |
| A retained native SDK wrapper stopped delivering after a host-only reload. | Refresh only the same entity's wrapper, detect host instance changes and explicitly subscribe/register again. Do not replay uncertain rewards. [SDK resynchronization](../../tests/addon-sdk-resync.lua). |
| Duplicate tick drivers distorted leases; stale terminal diagnostics were mistaken for new results. | Tick each client once with real seconds, and correlate run/request/session IDs. Acceptance is not readiness. |
| A catalog asset was unavailable in retail. | Read actual readiness and retained errors; optional effects fail independently. A catalog listing is not proof of an installed asset. [Add-on effects](../../tests/addon-effects.lua). |
| Releasing one caller's effects could interfere with another. | Caller-scoped leases, combined holds/mutes and independent retries remain mandatory. [Controls](../../tests/addon-controls.lua). |
| A GENERAL final hub could conceal earlier EXPLICIT playback. | Use bounded played history and peak rating for gameplay outcomes; current node alone is insufficient. |

Keep raw probes out of this file. For a new issue, record the reproducible trigger,
observed evidence, smallest fix, retained regression and unverified boundary.
