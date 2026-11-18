# Troubleshooting the runtime

Ask for the [`scenezoi_runtime` folder](../playing.md#report-a-problem). Start
with `release_version.cfg`, then find the session in `scene_history*.cfg`.
Use the run/session and timestamps to match observations. Take note of which
packs contributed definitions and which add-ons called the API. The diagnostics
capture those observations from SceneZOI's point of view. Confirm which mods
were enabled with the player.

| Symptom | Where to look |
| --- | --- |
| Start is missing, or the picker never opens | Check launcher/host readiness and the Zoi registry. A missing native cfg key can fail the first handshake. A Lua reload needs a fresh acknowledgement, even if the UI stayed loaded. [Hot-update checks](../development.md#hot-update-readiness) · [Launcher test](../../tests/demo-entry.cjs) · [Actor registration](../../tests/actor-registration.lua) |
| A standing hub has no animations to choose | Confirm the pack declares a compatible scene for those roles and furniture. Check catalog exclusions for missing optional assets. If Auto-mode is on, check the caller's plan and navigation restrictions. [Entry and extensions](../package-split.md#roles-entry-and-extensions) · [Optional tracks](../authoring.md#optional-animation-assets) |
| Preparation times out, including after Back | Read participant readiness and Exit entries in the same session. Check each wait sample's age and its simulation counters. Valid host retries advance committed, unready participants through the same task and autonomy checks, including when native entity ticks are delayed. Distinguish initial acquisition from an already anchored handoff; the latter uses the individual autonomy setting and task-idle guard because the aggregate native query may disagree after anchoring. [Participant regression](../../tests/participant-tasks.lua) |
| Scene ended with `interrupted` | Find `participant_release` before the session end. It identifies the Zoi, preparation or playback phase, and why the simulation released the participant. If the reason is a participant error, check `simulation_diagnostic` for the native failure. [Release tests](../../tests/session-unload.lua) |
| The actor is stuck or a bed remains occupied after Exit | Check the original state and restoration acknowledgements. The journal tracks participants and the specific furniture owner separately. Try movement or using the bed after Exit. [Save ownership](../tier1-contracts.md#save-and-load-ownership) · [Furniture leases](../../tests/furniture-lease.lua) |
| Normal play hitches regularly | Check whether anything is rescanning the full native Text table. Pack discovery belongs at B1 startup. [Discovery lifecycle test](../../tests/discovery-lifecycle.lua) |
| A held prop reappears when changing clothing | Appearance may reset visibility or recreate the carried object. Check the same prop during the handoff, playback and Exit. [Appearance tests](../../tests/appearance.lua) · [Native playback tests](../../tests/native.lua) |
| A scene ends after nearby gameplay interrupts a montage | Check whether the owned track was interrupted on the same animation instance. B1 can reacquire it at the shared sample when a native avoidance animation takes the slot. [Native playback tests](../../tests/native.lua) |
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

The [old issue ledger](https://github.com/acepleiades/SceneZOI/blob/e0cb40d64bb8c313d5c7309c3c5605b231569892/docs/investigations/runtime-and-ui-issues.md)
has earlier reproductions and measurements for regressions that need more history.
