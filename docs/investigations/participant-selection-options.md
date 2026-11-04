# Participant selection without changing gameplay groups

Research: 2026-10-31. Baseline: `20261031-groups-2`. Initial comparison was research only. The later cooperative probe failed;
the author then authorized the implemented leave-first policy described below.

## Findings and limits

- Current SceneZOI captures new-group confirmation before native creation. The
  grouped-requester restriction is a limitation of that adapter, not a requirement
  of SceneZOI playback. Keeping the native screen does not require keeping its
  group-editing owner.
- Installed behavior docs describe both `UB1ZoiGroupEditUIHandler` and
  `UB1CoopSelectUIHandler` using `UB1RelationshipSelectZoiWidget`. The latter has
  ordinary cooperative-selection modes and a separate completion packet. This
  provides a credible group-independent native route, not a proven Lua solution.
- Live export lookup found no matches for the widget's `RefreshUI`, its private
  `SelectEntityIdList`, or the cooperative handler's `RequestCoopSelectWidget`.
  Native documentation/examples are not proof of Lua accessibility. Entity
  `Subscribe` was not exposed in the checked lookup; the public event catalogue
  did not advertise the cooperative selection completion event. Do not infer a
  usable result callback from packet types or action lifecycle hooks alone.
- The stock `CoopSelect` action can start real cooperative gameplay after selection;
  group-specific/autonomous requests can skip UI. Reusing a meal action unchanged
  would violate the demo's selection-only intent. Required/optional cooperative
  roles exist, but minimum/maximum counts and inclusion of self need verification.
- `entity.scan_characters` exposes nearby IDs, names, age labels, distance and a
  cached `portrait_url`. A read-only live query returned three candidates with
  empty portrait URLs. Custom UI has a credible data source; reliable portrait
  loading is still unverified. `world.list_characters` also provides IDs, household
  information and cached portrait fields, but population enumeration is not proof
  that a Zoi is loaded and ready for playback.

## Cooperative-route feasibility test (2026-10-31)

After the author committed the baseline and authorized option 1, a temporary
one-shot B1 probe checked the actual loaded handler, not only SDK declarations.
The handler existed, but `RequestCoopSelectWidget`, `ShowCoopSelectWidget`,
`OnCompleteSelectZoi`, `OnCancelSelectZoi` and `SelectWidget` all returned nil.
The shared widget likewise returned nil for `RefreshUI`, `SelectEntityIdList`
and the completion/cancellation delegates; its ordinary `OnClickedOK` was a
function, confirming that exported widget functions were accessible.

The packet structs were present, but the checked packet-system classes exposed
none of `Get`, `Instance`, `Send`, `SendPacket` or `ProcessPacket`. The public
function lookup also supplied no general packet sender. Trying the UE namespace
was rejected by the bridge: project types must use INZOI. Consequently neither
the direct cooperative opener/result path nor a usable packet fallback was
established. Native action timing hooks do not supply the missing selected IDs;
running a stock activity to obtain them remains unsuitable for selection-only
entry. This is a current Lua-binding limitation, not proof that native engine
code could never support the feature.

**Outcome:** option 1 is not implementable through the clean interfaces tested.
No replacement adapter was installed. The temporary probe was removed, all 59
baseline candidate files were restored and byte-verified, and UI was remounted
after B1 reload. No group was created, edited or disbanded; no cooperative activity
was started. The grouped-requester restriction remains. Local evidence is stored
under `work/coop23` in the development workspace. Prefer the owned picker next;
do not reopen private group-state experiments as an automatic fallback.

## Subsequent decision: native departure, 20261031-groups-3

The author explicitly chose normal departure with disband fallback after testing
native group-task interruption. The demo now implements that choice. It leaves
the requester before opening the existing picker and selected NPCs after confirmed
selection. It verifies removal, disbands only the unchanged original group if
necessary, and verifies again. No reconstruction of groups/tasks is attempted.
The earlier grouped-requester restriction no longer applies. Live Default-group
and soccer evidence, cancellation consequences and untested boundaries are recorded
in [group support](../group-support.md#gameplay-group-departure).
The comparisons and recommendation below document the earlier decision process.

## Options

| Option | Advantage | Cost / unresolved condition | Assessment |
| --- | --- | --- | --- |
| Native cooperative selector, with a SceneZOI-owned result handoff | Keeps the familiar portrait/filter UI without using group editing. | Need a reachable opener and result-only callback; avoid starting native activities or inheriting acceptance/group shortcuts. | Best native candidate; implementation feasibility remains unproven. |
| SceneZOI-owned HTML/JS picker | Uses the existing supported UI stack; owns selection, limits, duplicate handling and cancellation without group writes. Can match the accepted inZOI colors/font. | Build cards, filters, keyboard/focus behavior and refreshing; verify portrait retrieval with a placeholder fallback. | Strongest practical long-term option with current exposed interfaces. |
| Draft roster built through contextual Add/Remove actions | Existing interaction triggers supply explicit target IDs; no group-selector dependency. | More clicks/camera work; needs a visible roster, confirmation and cancellation. Raw world-click interception is a separate, unverified API question. | Credible simpler alternative. Start selection on self; editing a draft is not changing an active session. |
| Use current gameplay group as a roster preset | Read membership IDs and confirm them without editing membership. | Cannot alone select unrelated Zois or subsets; groups above the demo cap need a separate selection step. | Useful shortcut alongside a general picker. |
| Temporarily remove participants, then restore | Can free the controlled requester for the existing adapter. | May change leadership/dissolve small groups, interrupt tasks and affect uninvolved members. Recreating membership is not restoration of tasks/identity. | Last-resort gameplay policy, not the preferred framework solution; whole-group disbanding has more collateral effects. |

Another native route is taking ownership of confirmation before the group update
is sent, closing the editor as cancelled after collecting IDs. It also needs
independent initial selection: existing members must not silently become scene
participants. Clean initialization/result hooks are not exposed in the checked
surface, and Slate focus/selected items are not the private roster selection.
This is a conditional research candidate, not an easy replacement hook. A supported
API extension exposing neutral open/result/cancel would be preferable to private
field manipulation. Earlier identity-copy/shadow-group experiments are not revived.

## Recommendation and proof criteria

Give the cooperative route one focused feasibility check: can the available API
open the panel for an already-grouped requester and return explicit selected IDs
without starting gameplay or changing membership? If the required interfaces are
unavailable, prefer the owned UI rather than continuing broad hook experiments.
A native-styled custom picker is preferable to modifying unrelated gameplay state
merely to obtain a selection. Keep native UI as an optional provider if feasible.

Every provider should return explicit IDs to the existing role-binding/session
entry contract. Integration chooses availability/acceptance policy; the framework
validates participants. Membership stays fixed after Start, and future automatic
NPC scenes can provide IDs without displaying a picker.

Validate two separate questions: **selection without group edits**, and **scene
compatibility while memberships remain intact**. A replacement picker solves only
the former. Compare group IDs, leaders, members and manager options before/after
cancel, confirm, scene Exit and failure; check uninvolved members and ongoing group
activities. Cover grouped initiators and grouped NPCs, leader/member roles, different
group types, cold start, control changes, minimum/below-cap selection and unload.
Do not automatically disband groups as a fallback when a test fails.

## Sources

Installed SDK binding metadata and behavior docs for the selector, its two owners,
`FB2Action_CoopSelect`, `FB1RoleInfo`, cooperative completion packets and group manager;
read-only live API/event/nearby queries; existing SceneZOI entry code. Public refs:
[native widget](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b1/classes/ub1relationshipselectzoiwidget/),
[cooperative UI handler](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b1/classes/ub1coopselectuihandler/),
[nearby query](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/cli/entity/entity-scan-characters/),
[supported web UI](https://mod-docs.playinzoi.com/docs/modkit-docs/modkit/project/uimod/01-overview/).
Raw diagnostics remain in local development artifacts.
