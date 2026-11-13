# Fixed-membership scenes and manual entry

Scene schema 3 uses explicit stable roles. Session membership and assignments remain fixed until Exit. Roles are neither body types nor controlled/NPC indices; repeated bodies and independently owned attachments are supported. Runtime systems support solo and multi-Zoi rosters. A disappearing participant ends the session through normal cleanup.

Each node declares participants and one body track per role. Connected destinations preserve role IDs and requirements. Integrations supply distinct Zoi IDs for every role; the framework checks actual appearance compatibility and loaded participants. Navigation retains original outfits, leases, anchor/furniture context, speed and session-owned resources. Both looping and [transition](transitions.md) nodes are supported.

## Example role declarations

HZoi-Reference's [standing idle](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L30) declares two named
roles, appearance-body/life-stage requirements, an explicit anchor and one body
track per role. Its [navigation](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L11) leads to scenes with
the same role IDs. This is a two-person example, not evidence of authored group
choreography. See [worked examples](content-examples.md) for its adult-content
scope; use the neutral framework scenes for an all-ages starting point.

## Solo launcher and debug picker

By default, **Solo SceneZOI session** appears below **AI Emote** on the controlled
Zoi. It starts a compatible GENERAL-rated solo scene directly, with the ordinary
panel and Scene Settings. Enable **SceneZOI manual start** under **Debug** in
[Scene Settings](settings.md#debug-manual-start) to replace the solo entry with
the native picker and show the debug entry on supported available furniture.

The debug picker includes the controlled Zoi and permits up to two partners, one to three total. With nobody else picked its button reads **Start Solo** and is enabled only when a one-role `starting_hub` scene matches the Zoi and the clicked furniture; otherwise it stays disabled, as it did before. The full roster is matched to eligible starting_hub declarations; roles are bound explicitly and an eligible start is selected uniformly. Current neutral standing/single/queen hubs declare adult MF roles, and two solo standing hubs (`scenezoi.solo_idle_female`, `scenezoi.solo_idle_male`) play the game's own idle clip for that body. Same-body or three-person rosters currently find no eligible hub unless compatible content contributes one; this is data, not an engine pair/body restriction.

There are no relationship, willingness, progression, random acceptance or reward checks in this manual starter. Technical body/life-stage, identity, loaded-participant, ownership and furniture availability checks remain. No eligible scene produces a native toast and restores focus without creating a session. Unselecting the controlled Zoi in the picker starts a scene where the first picked Zoi stands, between the selected Zois, on the background path, with no panel, for the NPC scene length in Scene Settings. Add-ons remain the other NPC-only entry, though generic runtime ownership does not intrinsically require the initiator to be controlled.

The solo and debug character entries are shown only on the controlled Zoi. The manifest's native character target is filtered by the stable injected widget ID and actual current controller target; ordinary interactions/other mods remain intact. Furniture entry is separately filtered by profile, eligible hub and recent availability. The launcher rechecks identity/context before opening the picker.

The transparent scenezoi-starter launcher is separate from persistent scenezoi controls. Cold entry requires readiness from the current Lua host and a matched launcher and controls instance. After a Lua-only restart, the same controls instance acknowledges the new host while the launcher stays hidden. The launcher waits before dispatch and hides after handoff without suspending controls. Clicked furniture IDs survive confirmation and Start, and availability is rechecked before reservation/preparation.

The selection bridge uses the native B2ZoiGroupManager Create hook, not a non-ticking lifecycle binding. Confirmation is captured before gameplay group creation. Default-group picker capacity is borrowed only during initialization and restored immediately. Native group-options controls are hidden only for this picker. Cancellation, real-time expiry and ordinary group creation remain separate.

## Gameplay-group departure

The debug picker makes the controlled requester leave their existing gameplay group before it opens. After confirmed selection and loaded-roster validation, selected NPCs leave theirs. Unselected members are not explicitly removed.

GroupDeparture calls RemoveZoiGroupMember with UserSelf and checks actual membership. Only if the participant remains in the same unchanged original group does it call BreakZoiGroup and verify again. Concurrent movement to a different group causes failure rather than disbanding the new group. Opening waits two simulation callbacks for the requester's native update. No private group-state edits, identity spoofing or shadow groups remain.

These are real departures. Native minimum-membership rules may dissolve a group, and activities may stop or continue with remaining members. Cancelling, failed entry and Exit do not rebuild groups or resume interrupted activities. No SceneZOI gameplay group is created. The debug picker uses this departure policy. The direct solo launcher starts without a picker or a gameplay-group departure.

Historical live tests covered four-member Default groups, leader/member requesters, cancellation, two source groups and the author's soccer activity. Broader group/activity compatibility is not established. Isolated checks retain failed leave/disband, unchanged-group fallback and concurrent-group-change cases. [Earlier selector research](investigations/participant-selection-options.md) records why the clean cooperative route was unavailable through tested Lua exports.

## Attachments and cleanup

Named attachments explicitly select participant roles. Separate same-asset instances on different Zois retain independent components, animation, materials, body state and retryable cleanup. Retained owner/mesh/profile identity cannot change across nodes. Ordinary attachments support multiple owners/resources; the current region-replacement adapter permits one body-region owner per participant. Content defines compatibility and geometry through [native profile declarations](package-split.md).

## Development and evidence

Removed MM/FF/MFF/MMF scene fixtures remain synthetic test rosters only. The framework supplies five neutral nodes; maintainer integration tests also used four standing nodes from the private HZoi pack. The suite covers repeated bodies, independent resources, shared clocks, held navigation, second-owner failure and cleanup. Historical multi-person diagnostics are not acceptance of unprovided group choreography.

After changing native chunk hooks/bindings, reload both Lua environments while no scene is active, then verify actual group membership and successful entry. Repeated remounts retained stale dispatch in a tested session. Released appearance-reference failures may require restarting the game. Matching build markers alone are insufficient. Consult [current validation](../validation.json) and the [issue ledger](investigations/runtime-and-ui-issues.md).

## Active-session safeguards

Sessions can run side by side, each with its own roster. Starting a scene for a Zoi that is already in one, while that scene is preparing, playing or cleaning up, displays a native toast and leaves the active session and participant ownership untouched. The launcher handles ordinary clicks; native entry/runtime guards cover stale-state races without overwriting the current session's status.

Switching control is allowed at any time. The panel follows the controlled Zoi: a participant of another session shows that session, and a Zoi outside every session hides the panel while the other sessions keep playing. A picker-started NPC-only session uses the **Default NPC Scene Length** setting. An unknown or transient control lookup is not treated as a switch.

The last_exit diagnostic stores client, sequence, final result and initiating exit reason. Restoration failures retain their own error result. Input restoration uses a currently registered world-context actor rather than an unloaded participant retained from session entry.

## Participant task ownership

Acquiring a participant disables autonomy, clears their native waiting interaction queue and cancels the current interaction through its normal cancellation path. Readiness waits for two idle callbacks. The lease continues clearing new queued work and interrupts independently identified current tasks during playback. Cleanup restores the original autonomy value/inheritance, collision and position independently. Interrupted activities and cancelled queues are not resumed or reconstructed. The author permitted cancellation as fallback because a supported reliable queue-pause mechanism has not been established. See `tests/participant-tasks.lua` and the current acceptance boundary in [validation](../validation.json).
