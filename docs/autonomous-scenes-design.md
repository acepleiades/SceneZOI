# Concurrent sessions and autonomous scenes

**Design proposal.** This describes planned behavior. The current release allows one
active session and requires a controlled initiator, including for API starts.

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
  interprets task IDs as data. For example, a romance add-on can request one
  completion of HZoi's excitement task for a Zoi whose partner has agreed to
  participate (a magic add-on can request one spell-charge completion for a
  caster whose partner has agreed to assist).

## Proposed start request

Add `start_autonomous_scene` alongside the existing [start operations](addons.md).
The names below are proposed. Reuse the current roster, role binding, placement,
query, request-status and ownership contracts where they apply.

| Input | Meaning |
| --- | --- |
| Initiator and participants | Fixed roster. Every goal names a roster member by entity ID. The normal binding resolves each Zoi's named role in the selected content. |
| `goals` | One or more `{participant_id, task_id, completions}` entries. `completions` is a positive integer, default 1, counting new completions in this session. Reject duplicate participant/task pairs and unknown tasks. |
| `restrictions` | Lifetime restrictions using the existing scene query. Apply them to entry, automatic and manual routes, completion routes and transition destinations. Use role-qualified action filters when the restriction is about who does an action. |
| `required_stages` | Selectors that must each match a stage's loop at least once. A selector may specify a stage number or allow any stage. A stage counts after its loop actually starts playing. Transitions and repeated visits to the same stage do not earn additional stage credit. |
| `stages` | A positive integer or inclusive `{min, max}` range. Default 1. Pick the count once and keep it for the session. An explicit stage number must exist for every possible count in the range. |
| `stage_preferences` | Optional ordered selectors for ranges of stages. They rank eligible nodes. Use early or late fractions of the chosen stage count so the same policy works with random counts. |
| `auto_speed` | On by default. Use a gentle stage-based speed ramp through the existing playback settings. An add-on can disable the ramp or provide a bounded profile. |

For example, a romance add-on can request one excitement completion for a
male Zoi whose partner has agreed to participate and has no goal of her own.
If she rules out fellatio, the add-on excludes that action for the entire
session. In a separate request where both agree to include it, the add-on
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
   For example, one excitement completion plus a meter at 50% is 75% of
   a two-completion goal (the same calculation applies to two spell charges).
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
Goals and required stages are both part of success. Plan required stages before
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
  goals if a viable route out exists.
- **Respect authored behavior.** Let the task engine commit completions and let
  existing completion routes, transitions and responses resolve before
  automatic navigation or successful Exit. Give each session one navigation
  decision at a time. Pause stage advancement during preparation and
  transitions. If a completion route fails, preserve the existing failure and
  cleanup semantics.
- **Bound the run.** Use a minimum loop dwell and a no-progress window to avoid
  rapid switching, plus a maximum active-game-time budget. Reset the stall timer
  when any unfinished goal advances or a required stage is satisfied, even if
  the slowest goal has yet to move. Preparation,
  cleanup and streaming losses keep their own bounded handling. A game pause
  does not consume the progress budget. If caps, holds, lost resources or
  restrictions leave no viable path, end cleanly with a reason such as
  `goal_unreachable`, `required_stage_unavailable` or `no_progress`. Never
  relax the restrictions to rescue a run.

For HZoi, a romance add-on could prefer handjob and fellatio nodes early and
vaginal sex later, if the participants have agreed to those actions. If only the
receiving Zoi has an excitement goal, a nonpenetrative node can complete the
session by itself. If both have goals, a node that caps one partner at 50% can
help early, then give way to a node that can finish the remaining goal (a magic
add-on can prefer preparation drills early and full casting later, and skip
full casting if the drill can already finish the only requested charge).

If the restrictions rule out every node capable of finishing a remaining goal,
report that the plan is unreachable. The ordering comes from the add-on's
selectors.

The optional speed ramp affects animation playback only. Task rates still use
game time, so speeding up the animation does not advance the task meter faster.
Apply the ramp as a session-owned modifier within supported playback limits.
Remove it on manual takeover or Exit and keep it independent of global game speed.

## Player control and session UI

- Bind the scene panel to the **currently controlled Zoi's** session. Switching
  between participants in different sessions switches the panel, task tray and
  controls. Switching to a Zoi outside every session hides the panel and releases
  its input capture. The other sessions keep playing. NPC-only sessions have no
  player panel.
- A session started with goals begins in auto-mode. Show an **Auto-mode** toggle
  in the main panel for that session. While it is on, manual node navigation is
  disabled in the UI and rejected by the runtime, including direct add-on
  navigation. Exit and authorized stop requests remain available. A session
  started with the manual button has no goals and omits the toggle.
- Turning auto-mode off keeps the current node, tasks, goals, stage history and
  lifetime restrictions. Manual navigation resumes as soon as any existing
  transition or handoff permits it. Goal-driven navigation, the speed ramp and
  automatic Exit are suspended. Manual play can still complete goals through the
  task engine. Stage requirements earn credit through auto-mode stage entry.
  Turning auto-mode on re-evaluates the remaining
  goals and requirements from current state. If they are already satisfied,
  finish through the normal completion path.
- UI commands carry the session ID and current revision. Clear queued input on
  a focus change and reject stale commands. Rebinding the UI has no effect on
  participant leases, appearance snapshots or cleanup.

## Runtime ownership and safety

| Area | Implementation direction |
| --- | --- |
| Session registry | Replace the singleton with a registry keyed by session ID. Index participant and furniture ownership, including pending starts. Reserve a complete roster and any furniture atomically. Keep resources reserved through cleanup or retry, and refuse overlap or excessive simultaneous sessions. |
| Playback and events | Give each session its own clock, node revision, catalog snapshot, task state, audio, attachments and retryable cleanup. Route replies, ticks and stop commands by session and lease token. A failure in one session must not halt another. Extend the API with session listing and targeted status, keeping legacy singleton reads tied to the focused session. Keep events keyed by session ID and event index. |
| World and input | Keep the game-owned animation instances and the existing possession/input safeguards. Only the focused session can own player input. Replace the controlled-Zoi distance rule for background sessions with checks for loaded, valid participants and placement. End on streaming loss or world teardown through normal cleanup. Start with a conservative concurrency cap and measure actual cost. |
| Saves and global settings | Move save-journal ownership into an always-available host so NPC-only sessions can acknowledge their journal before acquiring leases. Store original state for every committed or committing roster and keep recovery compatible with existing saves. A save requests Exit for all sessions and serializes their recovery records. Use one reference-counted autosave suspension that restores the original setting only after the last owner releases it. |
| Outcomes | Expose auto-mode state, chosen stage count, stage, requested versus actual completions, outstanding requirements and stop reason in copied session status/results. Emit stage and mode changes through the existing event mechanism. Report outcome and cleanup separately so add-ons can distinguish a successful scene from an interrupted or partially restored one. |

See the current [lifecycle contracts](tier1-contracts.md) and [add-on
controls](addon-controls.md) for the existing save, ownership and command rules.

## Implementation order

1. **Make session identity explicit while still running one session.** Introduce
   the registry and session-scoped commands, replies, clocks, snapshots and
   events. Preserve the existing manual picker and public API behavior. Verify
   Start, navigation, Exit, repeated entry and stale-reply rejection.
2. **Make shared resources safe for concurrency.** Add atomic participant and
   furniture reservations, isolated cleanup, aggregated save recovery and the
   shared autosave lease. Add tests for competing starts, cleanup retries and
   restoring multiple rosters after save/load before raising the session cap.
3. **Enable concurrent sessions and background ownership.** Add API starts for
   noncontrolled initiators and bind the player UI to possession. Test two
   disjoint scenes, switching between them and to a free Zoi, and an NPC-only
   scene. Verify that stopping one leaves the other playing, that shared
   participants/furniture are refused and that actor unload cleans up safely.
4. **Implement goal-driven auto-mode with one stage.** Add the start request
   and preflight, track real task completions per participant, choose eligible
   nodes by rate/cap, and implement bounded success/failure. Ship a neutral
   test fixture with one goal, several independent goals and repeated
   completions. Verify that exclusions stay in force and unreachable goals
   fail cleanly.
5. **Add stages, preferences and player takeover.** Add fixed/random stage
   counts, stage requirements, preference ordering, viable node variation and
   the optional speed ramp. Expose the toggle and enforce manual-navigation
   locking in both UI and API. Test mismatched progress rates, early caps,
   boundary jumps, authored transitions, completion holds and switching
   auto-mode off and back on.
6. **Validate in the game and document the public contract.** Use a separate
   example add-on to exercise the API in retail. Run manual and autonomous
   sessions side by side, force a save and recover both rosters, and verify
   multi-session cleanup and performance. Publish neutral authoring examples,
   request/response schemas and diagnostics once the behavior is verified.
