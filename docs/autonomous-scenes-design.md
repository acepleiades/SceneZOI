# Concurrent sessions and autonomous scenes

**Design notes.** Implemented; the public contract is in the
[add-on API](addons.md#concurrent-and-background-sessions). This page keeps the
reasoning behind it. Field names follow the implementation where they differ.

A **session** is the fixed roster, placement, task state and cleanup that survive
navigation. A **node** is one authored animation or transition within that session.
**Auto-mode** is a session setting that lets SceneZOI choose when and where to
navigate. Concurrency and auto-mode are separate capabilities. A manual session
can coexist with an autonomous session, and an autonomous session can run with
the currently controlled Zoi.

## Who starts a session

- The manual **Start SceneZOI** button keeps its existing entry flow and technical
  checks. The player can start it while other Zois are in separate sessions.
- A new autonomous start operation can use a currently controlled Zoi, another
  controllable household Zoi, or an NPC as the initiator. The initiator belongs to
  the roster. The add-on supplies the participants and placement context.
- The gameplay add-on decides who wants to participate, what they agree to do,
  and what happens afterward. SceneZOI verifies technical eligibility, reserves
  the roster and furniture, plays eligible nodes and reports the outcome. It
  interprets task IDs as data. For example, a sexual gameplay add-on can start
  a consensual sex scene and request one orgasm for a participant by targeting
  one completion of HZoi's excitement task (a magic add-on can request one
  spell-charge completion for a caster whose partner has agreed to assist).

## Proposed start request

Add `start_autonomous_scene` alongside the existing [start operations](addons.md).
The names below are proposed. Reuse the current roster, role binding, placement,
query, request-status and ownership contracts where they apply.

| Input | Meaning |
| --- | --- |
| Initiator and participants | Fixed roster. Every goal names a roster member by entity ID. The normal binding resolves each Zoi's named role in the selected content. |
| `goals` | For a goal-driven plan, one or more `{participant_id, task_id, completions}` entries. `completions` is a positive integer, default 1, counting new completions in this session. May be omitted for timed and add-on-controlled plans. Reject duplicate participant/task pairs and unknown tasks. |
| `restrictions` | Lifetime restrictions using the existing scene query. Apply them to entry, automatic and manual routes, completion routes and transition destinations. Use role-qualified action filters when the restriction is about who does an action. |
| `required_stages` | Selectors that must each match a stage's loop at least once. A selector may specify a stage number or allow any stage. A stage counts after its loop actually starts playing. Transitions and repeated visits to the same stage do not earn additional stage credit. |
| `stages` | A positive integer or inclusive `{min, max}` range. Default 1. Pick the count once and keep it for the session. An explicit stage number must exist for every possible count in the range. |
| `stage_preferences` | Optional ordered selectors for ranges of stages. They rank eligible nodes. Use early or late fractions of the chosen stage count so the same policy works with random counts. |
| `end_policy` | End on goals, after a duration, or on add-on request. Timed plans specify a duration and clock. All policies remain subject to safety stops. |
| `task_progress_multiplier` | A bounded positive factor, default 1, applied to positive task progress while in auto-mode. It changes how quickly goals fill and leaves animation speed independent. |
| `auto_speed` | On by default. Use a gentle stage-based speed ramp through the existing playback settings. An add-on can disable the ramp or provide a bounded profile. |

For example, a sexual gameplay add-on can request one orgasm for a male Zoi
whose partner agrees to a sexual encounter and does not want an orgasm herself.
The request gives him one excitement completion and leaves her out of the
goal list. If she rules out fellatio, the add-on excludes that action for
the entire session. In a separate request where both agree to include it, the add-on
can require a stage that contains it (a magic add-on can request one
spell-charge completion for the caster alone, exclude the use of a focus
stone in one session, or require a focus-stone stage in another).

A requirement and a restriction that cannot both be satisfied produce a
structured refusal. Use a bounded request size and stage count, and return the
chosen count and session ID in the accepted plan or subsequent status.

Participants without goals have no effect on stage timing or the finish
condition. Their authored task progress and completion effects still work as
usual. Add-ons should choose suitable restrictions when that matters to the
interaction.

## How progress determines the stage

Use the real [scene task engine](scene-tasks.md) as the source of progress and
completion counts. For each requested participant/task pair:

1. Count completions committed since entry. If the goal has reached its requested
   count, its progress is 100%.
2. Otherwise compute `(completed_count + current_value / task_maximum) / requested_count`.
   For example, one orgasm plus an excitement meter at 50% is 75% of a
   two-orgasm goal (the same calculation applies to two spell charges).
3. Take the **minimum across all goals** for the session. With four stages, 0–25%
   is stage 1, 25–50% stage 2, 50–75% stage 3, and 75–100% stage 4. At an exact
   boundary, the next stage is due. If two Zois are at 80% and 35% of their
   excitement goals, the session is in stage 2 (two casters at the same
   percentages of their spell-charge goals are also in stage 2). Once a stage
   is entered, decay cannot move the session backward. Use current values when
   choosing what to play next.

A Zoi who has finished contributes 100%, so the remaining goals set the pace.
Counting completions also keeps the progress measure continuous when a task
resets to zero. A meter at maximum under a completion hold still needs a real
completion event before the goal is satisfied.

Advance through stages in order. If an update crosses several boundaries,
queue the due stages and enter them through normal playback handoffs, with at
least one playing update before progressing again. This gives required stages
a chance to play. At each new stage, prefer a different eligible loop when that
still serves the plan. Reuse the current loop if it is the only viable choice.
Goals and required stages are both part of plan completion. Plan required stages before
the final completion where possible. If goals finish early, play any remaining
required stages when reachable and within the session budget. A reused loop
counts once it has played in the new stage.

## How auto-mode chooses nodes

At entry and each stage boundary, use the existing [scene search and
restrictions](addons.md) with the fixed roster, anchor and furniture context.
Follow authored navigation edges and compatible [transitions](transitions.md).
If cross-node direct entry is supported, use the same validated direct-navigation
path with explicit content-author permission for auto-mode handoffs. A matching
tag alone never permits a jump to a different placement or incompatible node.

- **Check feasibility.** Read the authored rate and cap for each bound
  participant's requested task. A positive rate can contribute while there is
  room below the cap. A handjob node that caps the giving partner's excitement
  at 50% can advance her early goal but cannot finish it (a practice drill
  capped at 50% can advance a spell charge but cannot finish it). Omitted, zero
  and negative rates cannot advance that goal. Reject a
  request when available data shows a goal or required stage cannot be reached.
  Check routes from the proposed start, including the ability to leave required
  stages and reach completion-capable nodes. Report uncertainty separately if
  a bounded planning search cannot establish a viable route.
- **Choose for the current stage.** Prefer nodes that satisfy a pending stage
  requirement or advance the least-progressed unfinished goals toward the next
  boundary. Rank viable candidates with the caller's stage preferences. Use a
  session seed for ties and variation, and prefer a different loop at a stage
  change when viable. Reassess if the current node hits a cap or otherwise
  stops advancing a requested goal. A required node may briefly advance no
  goals if a viable route out exists. For a timed plan without goals, select
  from the eligible stage candidates without a rate or cap requirement.
- **Respect authored behavior.** Let the task engine commit completions and let
  existing completion routes, transitions and responses resolve before
  automatic navigation or successful Exit. Give each session one navigation
  decision at a time. Pause stage advancement during preparation and
  transitions. If a completion route fails, preserve the existing failure and
  cleanup semantics.
- **Bound the run.** Use a minimum loop dwell and a no-progress window to avoid
  rapid switching, plus a separate maximum active-playback budget. Reset the stall timer
  when any unfinished goal advances or a required stage is satisfied, even if
  the slowest goal has yet to move. Preparation,
  cleanup and streaming losses keep their own bounded handling. A game pause
  does not consume the active-playback budget. If caps, holds, lost resources
  or restrictions leave no viable path to an outstanding requirement, end
  cleanly with a reason such as
  `goal_unreachable`, `required_stage_unavailable` or `no_progress`. Never
  relax the restrictions to rescue a run.

For HZoi, a sexual gameplay add-on could prefer handjob and fellatio nodes early and
vaginal sex later, if the participants have agreed to those actions. If only the
receiving Zoi has an orgasm goal, a nonpenetrative node can complete the
session by itself. If both want an orgasm, a node that caps one partner's
excitement at 50% can help early, then give way to a node that can finish the
remaining goal (a magic
add-on can prefer preparation drills early and full casting later, and skip
full casting if the drill can already finish the only requested charge).

If the restrictions rule out every node capable of finishing a remaining goal,
report that the plan is unreachable. The ordering comes from the add-on's
selectors.

The optional speed ramp affects animation playback only. Task rates still use
game time, so speeding up the animation does not advance the task meter faster.
Apply the ramp as a session-owned modifier within supported playback limits.
Remove it on manual takeover or Exit and keep it independent of global game speed.

To make the task itself faster or slower, compose the plan's progress multiplier
with the existing player and add-on task rate factors. Reuse the task engine's
bounds, caps and completion holds. It scales positive authored rates while
auto-mode is enabled. For example, use 2× to make the HZoi excitement meter fill
faster at the same animation speed (use 0.5× to slow a spell charge). Use the
effective rate in planning and stall detection. Remove the plan multiplier on
manual takeover and restore it on resuming auto-mode.

## How a session ends

- **On goals (default for goal plans).** End when all requested completions and
  required stages are satisfied and the resulting authored completion response
  or transition has resolved. Report which goals and requirements were met.
- **After a duration.** End after the requested amount of active playback. This
  works with or without task goals. Goals drive stage progression when supplied.
  A timer-only plan can hold one loop or divide the duration evenly across stages.
  Report unmet goals or stage requirements if the requested duration expires
  first. For example, a sexual gameplay add-on can
  run an approved scene for ten game minutes (a GENERAL-only cuddle can run for
  the same duration without any task definitions).
- **On add-on request.** Suppress automatic successful Exit. The owning add-on
  may stop early or wait for its own gameplay condition and use the existing
  session-scoped `stop_session` operation. When goals and required stages are
  satisfied and their authored response resolves, publish that milestone once
  and enter a bounded waiting state. Hold the last eligible loop and suspend
  goal-driven navigation. Hold progression on fulfilled requested tasks during
  this wait to avoid extra completions. An add-on-controlled plan with neither
  goals nor a stage timer stays in one stage. For example, the add-on can continue
  after the requested orgasm until its own interaction ends (a training add-on
  can continue after a spell charge until a lesson finishes).

A timed plan or budget declares **game time** or **unscaled real playback time**.
At 3× game speed, a 10-minute game-time plan takes about 3 minutes and 20 seconds
of real playback. A 10-minute real-playback plan still takes 10 minutes. Neither
clock accrues while paused or preparing. The overall safety deadline is separate
and can run on wall time, including while paused.

Every session that can continue without a player panel needs a finite lifetime.
Use a bounded default even for background starts through the existing operations
with no goals. For add-on-owned background sessions, require a renewable owner
lease or a fixed deadline, with a hard ceiling either way. A manual session that
loses the panel on possession change gets a bounded background interval. Apply
no-progress detection only while there is an outstanding plan milestone to
advance. Use the bounded wait instead after goals are satisfied. Player Exit,
save, world loss, owner expiry and runtime failures still use normal cleanup.
Report goal satisfaction, stop reason and cleanup outcome separately.

## Placement and reservations

The current start API accepts a furniture ID or uses the authored standing
anchor resolved from the roster. For background entry, add a placement context
with either a supported furniture ID or that standing anchor, a maximum
participant-to-anchor start distance, and an exit position policy. Validate
distance before reserving the roster and again before playback. The gameplay
add-on handles approach and gathering. SceneZOI may align nearby participants
as part of normal playback.

Reserve furniture and a minimum spacing footprint around standing anchors
across pending and active sessions in the same loaded area. Keep reservations
through cleanup or transfer them to scoped recovery when necessary. A world
position override can be added later if it can be validated against loaded
placement and the scene's authored requirements. Keep restoring the original
position as the default. An opt-in stay-at-end policy applies only to ordinary
Exit with a safe end position. Save recovery and interrupted cleanup still use
the original snapshot.

## Player control and session UI

- Bind the scene panel to the **currently controlled Zoi's** session. Switching
  between participants in different sessions switches the panel, task tray and
  controls. Switching to a Zoi outside every session hides the panel and releases
  its input capture. The other sessions keep playing. NPC-only sessions have no
  player panel.
- A session started with an automatic plan begins in auto-mode. Show an
  **Auto-mode** toggle in the main panel for that session. While it is on, manual
  node navigation is
  disabled in the UI and rejected by the runtime, including direct add-on
  navigation. Exit and authorized stop requests remain available. A session
  started with the manual button has no automatic plan and omits the toggle.
- Turning auto-mode off keeps the current node, tasks, goals, stage history and
  lifetime restrictions. Manual navigation resumes as soon as any existing
  transition or handoff permits it. Automatic navigation, the animation speed
  ramp, the plan's task multiplier and planned Exit are suspended. A timed
  plan's clock also pauses. Background safety deadlines still apply. Manual play
  can still complete goals through the task engine. Stage requirements earn
  credit through auto-mode stage entry. Turning auto-mode on re-evaluates the
  remaining goals and requirements from current state. If the plan is already
  satisfied, apply its configured end policy.
- UI commands carry the session ID and current revision. Clear queued input on
  a focus change and reject stale commands. Rebinding the UI has no effect on
  participant leases, appearance snapshots or cleanup.

## Runtime ownership and safety

| Area | Implementation direction |
| --- | --- |
| Session registry | Replace the singleton with a registry keyed by session ID. Index participant and furniture ownership, including pending starts. Reserve a complete roster and any furniture atomically. Keep resources reserved through cleanup or retry, and refuse overlap or excessive simultaneous sessions. |
| Playback and events | Give each session its own clock, node revision, catalog snapshot, task state, audio, attachments and retryable cleanup. Route replies, ticks and stop commands by session and lease token. A failure in one session must not halt another. Extend the API with session listing and targeted status, keeping legacy singleton reads tied to the focused session. Keep events keyed by session ID and event index. |
| World and input | Keep the game-owned animation instances and the existing possession/input safeguards. Only the focused session can own player input. Replace the controlled-Zoi distance rule for background sessions with checks for loaded, valid participants and placement. End on streaming loss or world teardown through normal cleanup. Start with a conservative concurrency cap and measure actual cost. |
| Outcomes | Expose auto-mode state, chosen stage count, stage, requested versus actual completions, outstanding requirements and stop reason in copied session status/results. Emit stage and mode changes through the existing event mechanism. Report outcome and cleanup separately so add-ons can distinguish a successful scene from an interrupted or partially restored one. |

See the current [lifecycle contracts](tier1-contracts.md) and [add-on
controls](addon-controls.md) for the existing save, ownership and command rules.

## Save recovery, streaming and autosave

- **Recover by resource.** Keep the save journal available even when no scene
  panel is visible. Persist a versioned record for each committing or committed
  session before mutating its participants or furniture. On load, read the full
  journal before admitting starts, then index unresolved records by participant
  and furniture. Recover loaded resources immediately and retry absent ones on
  registration using the supported simulation authority. Refuse only starts
  that overlap unresolved resources. Keep missing records in subsequent saves
  and scope them to the loaded save/world and stable entity identity. Retire
  them only after an acknowledgement or authoritative confirmation the entity
  was permanently removed. Migrate old single-session records.
- **Keep autosaves available during background play.** Only the session that
  contains the currently controlled Zoi may suspend autosaves. Reconcile the
  single global setting lease on possession changes and Exit. Transfer directly
  between eligible sessions where possible. Restore the original setting when
  there is no eligible owner. An ordinary autosave can occur during NPC-only
  scenes. Any save requests Exit for every session and serializes their cached
  recovery records. Track autosave suspension, failed settings restoration and
  per-resource save recovery as separate states.
- **Report streaming loss accurately.** Stop the affected session with
  `participant_unloaded` and clean up remaining loaded participants, furniture
  and effects. Drop stale client handles immediately. Treat the missing
  participant as released only if simulation ownership was actually released
  or the entity was permanently removed. If simulation restoration cannot be
  verified yet, retain the snapshot for deferred recovery. Report restored,
  released on unload, or deferred recovery per participant. Reserve
  `restore_timeout` for cleanup that genuinely timed out, and keep the
  original stop reason separately.

## Add-on events and scene visuals

- **Scope events.** Add `focused`, `owned` and `all` subscription scopes.
  Default existing unscoped subscriptions to the focused scene and require
  explicit opt-in to all scenes. Route an add-on's own start results and
  lifecycle events to its owner independently of focus. Capture focus at event
  emission so a possession change or Exit cannot drop a queued event. Preserve
  session ID and event index in payloads.
- **Isolate delivery failures.** The current native send protects the call but
  evaluates the actor ID and encodes the payload outside the protected block.
  Protect the full delivery, retire confirmed-dead subscriber endpoints, and
  continue sending to other subscribers. For background sessions, validate a
  supported delivery endpoint independent of the initiating Zoi's lifetime.
  Retain bounded results by session/request ID so the add-on can retrieve them
  after reconnecting even if a live notification was missed.
- **Limit overhead visual work.** Scope marker and bubble suppression to
  participants across active sessions. Prefer owner-aware widget hooks or a
  cache refreshed on changes. If a widget scan is needed, throttle it and
  restore tracked state as ownership changes. Leave bystander bubbles visible,
  including when widget ownership cannot be established. Profile live with and
  without the scan before assigning the reported frame cost to it.

## Findings in the current code

- [SaveBridge](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/SaveBridge.lua)
  waits for all journal acknowledgements and suspends recovery during active
  playback. [Runtime](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Runtime.lua)
  and [AddonAPI](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/AddonAPI.lua)
  use that global state and [Autosave](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Autosave.lua)
  together to reject starts with `restore_pending`.
- Runtime stops with `participant_unloaded` when a participant unregisters,
  but the cleanup barrier still waits for restoration acknowledgements. A
  missing actor can therefore produce a separate `restore_timeout`.
- AddonAPI currently filters subscriptions by event name only, and one stale
  actor can throw before its protected send. The delivery loop then skips the
  remaining subscribers for that event.
- [SceneVisuals](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/SceneVisuals.lua)
  already limits selection markers to scene participants. Its speech-bubble
  path scans the full widget class on each active tick and suppresses all
  matches. The reported 7 ms has not been attributed to that scan by profiling.

## Implementation order

1. **Harden event delivery now.** Protect the full send and test that a
   despawned subscriber cannot prevent delivery to another subscriber. This
   correction also applies to the current single-session release.
2. **Make session identity explicit while still running one session.** Introduce
   the registry, session-scoped commands, clocks, snapshots and event scopes.
   Preserve manual picker behavior and test legacy subscriptions alongside
   focused, owned and all-session views.
3. **Make shared resources safe before raising the cap.** Add atomic roster,
   furniture and standing-space reservations, save journaling with per-resource
   recovery, foreground-only autosave ownership and explicit unload outcomes.
   Test a missing NPC after load, an unrelated start during recovery, repeated
   saves with unresolved records, and autosaves while NPC scenes are playing.
4. **Enable concurrent and background sessions.** Add bounded background
   lifetimes, independent add-on delivery, and possession-based UI focus. Test
   two disjoint scenes, competing starts, switching control, NPC-only playback,
   owner loss, and streaming loss. Verify that stopping one leaves the other
   playing.
5. **Implement one-stage plans and end policies.** Add goal, duration and
   add-on-controlled endings, both playback clocks and the task progress
   multiplier. Test caps, repeated completions, the 3× timing difference,
   add-on-controlled Exit, and timeout when the owner never calls stop.
6. **Add stages, preferences and manual takeover.** Add fixed/random stage
   counts, required stages, eligible node variation and the optional animation
   speed ramp. Test unequal task rates, early caps, boundary jumps, authored
   transitions, completion holds and switching auto-mode off and back on.
7. **Profile and validate in retail.** Verify participant-scoped visuals and
   compare frame timings with the widget scan isolated. Exercise mixed manual
   and autonomous sessions using a separate add-on. Publish the request,
   response and recovery contracts once verified, with neutral fixtures for
   automated tests.
