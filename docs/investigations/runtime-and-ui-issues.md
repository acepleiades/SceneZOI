# Troubleshooting the runtime

Ask for the [`scenezoi_runtime` folder](../playing.md#report-a-problem). Start
with `release_version.cfg`, then find the session in `scene_history*.cfg`.
Use the run/session and timestamps to match observations. Take note of which
packs contributed definitions and which add-ons called the API. The diagnostics
capture those observations from SceneZOI's point of view. Confirm which mods
were enabled with the player.

| Symptom | Where to look |
| --- | --- |
| Two meshes for male genitals, or the body's own genitals still visible | Compare `appearance_resolved` with `attachment_coverage_ready`. The first identifies the selected slot, mesh and profile; the second confirms the replacement's hidden body section and LOD count after its patch is ready. An ordinary `add_attachment` prop does not claim that region or remove another replacement. [Replacement declarations](../appearance-variants.md#my-replacement-appears-beside-the-bodys-original-male-genitals) |
| Scene controls stop responding while the game clock is paused | Check `panel_state.clock_paused` and the native scale in `playback_state`. Scene Mode deliberately locks input at scale 0; resume with the game's clock controls. Heartbeats and cleanup continue. [Playing](../playing.md) |
| Start is missing, or the picker never opens | Check launcher/host readiness and the Zoi registry. A missing native cfg key can fail the first handshake. A Lua reload needs a fresh acknowledgement, even if the UI stayed loaded. [Hot-update checks](../development.md#hot-update-readiness) · [Launcher test](../../tests/demo-entry.cjs) · [Actor registration](../../tests/actor-registration.lua) |
| A standing hub has no animations to choose | Confirm the pack declares a compatible scene for those roles and furniture. Check catalog exclusions for missing optional assets. If Auto-mode is on, check the caller's plan and navigation restrictions. [Entry and extensions](../package-split.md#roles-entry-and-extensions) · [Optional tracks](../authoring.md#optional-animation-assets) |
| Preparation times out, including after Back | Read participant readiness and Exit entries in the same session. Check each wait sample's age and its simulation counters. Valid host retries advance committed, unready participants through the same policy, task-idle and overlay checks, including when native entity ticks are delayed. Both initial acquisition and later handoffs require an explicitly disabled local and resolved autonomy policy. The native activity-eligibility query can remain true with that policy off. [Participant regression](../../tests/participant-tasks.lua) |
| Session interrupted (diagnostic code `interrupted`) | Find `participant_release` before the session end. It identifies the Zoi, preparation or playback phase, and why the simulation released the participant. If the reason is a participant error, check `simulation_diagnostic` for the native failure. [Release tests](../../tests/session-unload.lua) |
| The actor is stuck or a bed remains occupied after Exit | Check the original state and restoration acknowledgements. The journal tracks participants and the specific furniture owner separately. Try movement or using the bed after Exit. [Save ownership](../tier1-contracts.md#save-and-load-ownership) · [Furniture leases](../../tests/furniture-lease.lua) |
| Normal play hitches regularly | Check whether anything is rescanning the full native Text table. Pack discovery belongs at B1 startup. [Discovery lifecycle test](../../tests/discovery-lifecycle.lua) |
| A held prop reappears when changing clothing | Appearance may reset visibility or recreate the carried object. Check the same prop during the handoff, playback and Exit. [Appearance tests](../../tests/appearance.lua) · [Native playback tests](../../tests/native.lua) |
| A clothing checkbox is off but the garment remains, or the list shows an old outfit | Compare `wardrobe_ready` entries in `scene_history.cfg`: captured item, enabled state, expected garment, client garment and rendered component. Entry capture happens after native task cleanup and the initial layout refresh, before scene undressing. A visible component can still have hidden material sections; pair the log with a screenshot. Snapshots are recorded on entry and acknowledged clothing changes, not every frame. |
| A session ends after nearby gameplay interrupts a montage | Check whether the owned track was interrupted on the same animation instance. B1 can reacquire it at the shared sample when a native avoidance animation takes the slot. [Native playback tests](../../tests/native.lua) |
| Attachment playback fails with `PlayAnimation` | Find `attachment_animation_failed` before the runtime error. It identifies the declared animation, attachment, participant, handoff stage and any readable native validity observations. Incoming clips are resolved and validated again immediately before native playback takes ownership. A Lua reference alone does not retain an Unreal asset through appearance preparation. [Attachment lifetime regression](../../tests/attachment-animation-lifetime.lua) |
| Auto-mode picks an unexpected scene or runs too long | Read the initiating call in `api_trace.cfg`. Check its restrictions, goals, clock and end policy. An accepted API call only starts the asynchronous entry path. [Autonomous API](../addons.md#autonomous-scenes) · [Plan runtime tests](../../tests/plan-runtime.lua) |

For `participant_release` with `cause=lease_expired`, compare both sides of the
lease. The participant watchdog measures elapsed time since the latest received
renewal with the supported real-time wall clock. A native per-character tick delta can include
time before that renewal; subtracting that whole delta from a fresh lease could
expire it immediately. The watchdog does not use that accumulated delta. The
whole-second clock gets a rounding grace period before the six-second timeout
expires. A backward clock change rebases the deadline and is counted in the
diagnostic; it does not count as a received renewal.

`host_lease_diagnostic` gives each roster member's Prepare and Heartbeat
**send attempts**, the last kind and its age in unscaled host seconds, the
session's last/largest host tick delta, and the route's pending/attached state.
An attached route only confirms receiver installation; it does not prove that a
heartbeat reached or ran on the simulation side. These observations are kept in
memory and written when a participant unexpectedly releases.

`simulation_diagnostic` records the participant's received Prepare/Heartbeat
counts, tick count and accumulated tick time, last/largest delta, timeout and
wall-clock seconds since acquisition and the latest renewal. Missing renewals
despite recent host attempts point toward routing or simulation delivery.
Compare `tick_since_renew` with `elapsed`: a large accumulated delta with much
less actual time since renewal indicates the scheduling mismatch that the
real-time watchdog avoids. These fields narrow the investigation rather than
establish the cause of a reported interruption by themselves. Compare other
roster members and the same session's timestamps before blaming hardware, a
particular native task or another mod.

Preparation wait samples refresh at most once per wall-clock second while the
same phase persists. The timeout includes `seconds_since_report` rather than
presenting an old wait as a current observation. Its nested `simulation` sample
compares received Prepare/Commit/Heartbeat messages with native tick and progress
attempt counts, the age of the latest Commit, the last progress source, native
control identity, local and resolved autonomy observations, and the value last
sent to the autonomy component. Missing optional native reads are omitted; they
are not recorded as false. Compare these with `host_lease_diagnostic` on the preparation timeout to
distinguish a live disagreement from missing delivery or delayed native ticks.

During initial preparation, the host normally resends Commit after each
Prepare retry once the save and furniture barriers are ready. Compare
`commit_received` and `seconds_since_commit` with the other received-message
counts before attributing a wait to missing native ticks. A successful
Prepare-only retry test does not establish why a reported session timed out.

An isolated API audit reproduced an idle NPC whose local and resolved autonomy
were disabled while `IsAutonomyEnable()` still returned true. The game's own
autonomy setter confirmed the disabled policy and left that query true: it
describes activity eligibility, not whether the policy permits autonomous tasks.
The retained diagnostic field `autonomy_effective` is the literal result of that
query; compare `autonomy_resolved`, the local fields and task state to determine
whether SceneZOI has suppressed autonomy.

Notifications use the resolved option after changing or restoring the local value
and inheritance. Preparation requires local false, inheritance off and resolved
false, plus the existing queue cancellation, two stable idle observations and
montage/overlay settling. It no longer waits for activity eligibility to become
false, whether on initial acquisition or a later handoff. During playback the
same policy and queue guard continues to run. No aggregate native state is forced
or overridden, and Exit restores the original local value and inheritance.

The [old issue ledger](https://github.com/acepleiades/SceneZOI/blob/e0cb40d64bb8c313d5c7309c3c5605b231569892/docs/investigations/runtime-and-ui-issues.md)
has earlier reproductions and measurements for regressions that need more history.
