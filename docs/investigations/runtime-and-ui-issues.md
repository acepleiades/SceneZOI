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
| Preparation times out, including after Back | Read participant readiness and Exit entries in the same session. Distinguish an initial acquisition from an already anchored handoff. The latter uses the individual autonomy setting and task-idle guard because the aggregate native query may disagree after anchoring. [Participant regression](../../tests/participant-tasks.lua) |
| The actor is stuck or a bed remains occupied after Exit | Check the original state and restoration acknowledgements. The journal tracks participants and the specific furniture owner separately. Try movement or using the bed after Exit. [Save ownership](../tier1-contracts.md#save-and-load-ownership) · [Furniture leases](../../tests/furniture-lease.lua) |
| Normal play hitches regularly | Check whether anything is rescanning the full native Text table. Pack discovery belongs at B1 startup. [Discovery lifecycle test](../../tests/discovery-lifecycle.lua) |
| A held prop reappears when changing clothing | Appearance may reset visibility or recreate the carried object. Check the same prop during the handoff, playback and Exit. [Appearance tests](../../tests/appearance.lua) · [Native playback tests](../../tests/native.lua) |
| A scene ends after nearby gameplay interrupts a montage | Check whether the owned track was interrupted on the same animation instance. B1 can reacquire it at the shared sample when a native avoidance animation takes the slot. [Native playback tests](../../tests/native.lua) |
| Auto-mode picks an unexpected scene or runs too long | Read the initiating call in `api_trace.cfg`. Check its restrictions, goals, clock and end policy. An accepted API call only starts the asynchronous entry path. [Autonomous API](../addons.md#autonomous-scenes) · [Plan runtime tests](../../tests/plan-runtime.lua) |

The [old issue ledger](https://github.com/acepleiades/SceneZOI/blob/e0cb40d64bb8c313d5c7309c3c5605b231569892/docs/investigations/runtime-and-ui-issues.md)
has earlier reproductions and measurements for regressions that need more history.
