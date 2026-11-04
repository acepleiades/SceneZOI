# Runtime and UI issue ledger

Reviewed: 2026-11-04. Current recorded runtime: `20261104-dictionary-1`. Current source and validation paths are at the repository root. Dated entries below describe their own checkpoint, not unresolved current behavior unless explicitly stated.
Use this index before revisiting a subsystem; detailed contracts and dated evidence
remain in the linked notes. These are findings for the tested game/assets, not
universal Unreal or replacement-body guarantees. Keep one row per distinct issue;
update it when new evidence changes the explanation.

## Recent entry fixes

The author confirmed both fixes after reloading the save and testing three
picker openings, including the first attempt after loading.

| ID | Symptom / established finding | Current resolution and refactor constraint |
| --- | --- | --- |
| UI-01 | Scene entry appeared on other Zois. `character` targets them generally; a tested `self` target injected nothing. NPC mod rows are rendered talk-entry widgets outside the normal talk item array. Filtering that array missed them. | Filter only our rendered object/talk widgets by their stable injected ID and actual target Zoi ID. Preserve other entries; recheck identity in the launcher. See [menu adapter](../../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOIStarter/Menu.lua). |
| UI-02 | Entry needed alternating attempts; the first launcher split improved repeats but still needed extra attempts after loading. Menu activation shared the persistent controls view, and startup could accept requests before the host/receiver were ready. | Keep a separate preloaded launcher, hide it after handoff, and retain the framework controls view. Gate entry on host-generation, receiver and launcher readiness; let the original activation wait. See [entry contracts](../group-support.md#start-scenezoi-and-the-native-picker) and `tests/demo-entry.cjs`, `entry.lua`, `menu.lua`. |

The complete remedy is tested and accepted. The exact native internal ordering
behind every lost activation was not independently isolated. View toggling and
startup readiness must not be presented as a measured account of every failed
click. A diagnostic calling a native selection handler on a closed menu does not
reproduce a real menu activation.

Avoidable false starts in this repair were testing direct picker requests before
the real menu route, filtering the wrong collection, continuing with unreliable
input automation, and treating a proposed native cause as established before
checking cold startup. These added iteration cost; they are not engine requirements.

## Earlier problems worth preserving

| ID | Symptom / finding | Preserve when changing the subsystem |
| --- | --- | --- |
| LIFE-01 | Direct sequence playback changed animation mode/instances; repeat-only checks missed later movement/furniture failures. | Keep the game's animation instance, stop only scene-owned montages, restore autonomy/input and test movement/furniture after Exit. No Smart Zoi toggling. [Runtime ownership](../tier1-contracts.md#ownership). |
| PLAY-01 | Default idles flashed between nodes while preparation ran. | Load/validate the next node while retaining the outgoing pose; switch synchronized tracks after readiness. Do not stop current playback at the start of preparation. [Pose handoff](../tier1-contracts.md#time-and-navigation). |
| OUTFIT-01 | Rapid edits timed out because the game normalized underwear slots; readiness incorrectly expected original IDs in unaffected slots. | Separate immutable entry snapshots, requested switches and acknowledged resolved appearance. Wait for resolved results; keep revision/counter guards. Faster toggling was not proven to be the cause. [Resolved acknowledgement](../tier1-contracts.md#outfits-and-appearance). |
| ATTACH-01 | Material matching read a missing body mesh during retained-attachment rebuild; a host discarded a not-ready result. Native outfit refresh also reset merge settings. | Propagate preparation readiness before dependent work. Reassert required layout without recapturing original settings; retain ownership/snapshots and retry restoration. [Rebuild barrier](../tier1-contracts.md#outfits-and-appearance). |
| ATTACH-02 | Outfit refresh briefly exposed replacement geometry; hiding every attachment during every edit then caused another visible blink. | Preserve masking through refresh. Determine coverage from resolved garment masks, not slot names. Keep an exposed attachment visible for known non-covering edits while retaining readiness checks. Section 17 plus the stock patch remains a tested Supponpon mapping. [Visual continuity](../tier1-contracts.md#outfits-and-appearance), [non-covering edits](../tier1-contracts.md#outfits-and-appearance). |
| UI-03 | Toolbar was present but clipped. The real generated window manager wrote inline overflow hiding; a mocked preview missed it. | Test the actual scaffold, computed clipping and hit bounds. Preserve the targeted overflow override and generated manager. [Clipping fix](../tier1-contracts.md#events-and-ui-lifecycle). |
| GAZE-01 | Female eyes enlarged; male visible eyes did not follow the correction. | Additive scale is a delta: neutral is `(0,0,0)`. Propagate to EyeParallel descendants with depth -1; preserve native shaping, blinking and limits. A far-down target can remain clamped. [Gaze findings](../gaze.md). |
| DEV-01 | Loaded build markers did not prevent released appearance-reference failures after Lua reload. Some native hook dispatch survived repeated unmount/mount cycles. | These are distinct reload hazards. Fully reload Lua environments after changing native chunk hooks, then check actual group membership. If released appearance references persist, restart the game; their underlying bridge cause remains unproven. A marker alone does not validate a reload. [Reload records](../tier1-contracts.md#outfits-and-appearance), [hook reload note](../group-support.md#development-and-evidence). |
| PACK-01 | Raw ModKit packaging included referenced game/Engine assets and obsolete test clips. | Use the existing payload filter; verify mod-only assets, registry-only companion pak and installed hashes. Replace changed cooked containers only with the game closed. [Packaging tool](../../tools/filter_package.py). |
| GROUP-01 | Existing-group edits bypassed new-group capture; independent cooperative opener/result APIs also returned nil in-game. | **20261031-groups-3:** retain native picker; normally remove requester before opening and selected NPCs after confirmation. Verify membership; disband only the unchanged original group if removal fails. Real departures are not restored on cancel/Exit. Live Default-group and soccer checks passed; fallback has isolated coverage. [Policy and limits](../group-support.md#gameplay-group-departure). |

Authoring accuracy findings remain in [the investigation index](README.md).
Rigs/exporters are production-ready; reopen accuracy work for a concrete problem.

## Debugging rules learned

- Reproduce the author's actual route first. Direct cfg requests, handler calls,
  isolated mocks, loaded markers and screenshots prove different things.
- For entry changes, test the first click after loading, cancellation/repeat entry,
  controlled versus NPC menus, and control changes. Reproduce failure before the
  fix where feasible; keep targeted regressions and author visual acceptance.
- Separate a proposed cause from native readback and accepted behavior. Change one
  suspected boundary at a time; state when several changes jointly resolved it.
- Use direct game/ModKit tools first. When input automation repeatedly fails, stop
  retrying that path and request one bounded manual reproduction with logging ready.
- Keep error causes after cleanup and distinguish stale diagnostics from a new
  failure. Store large probes locally; record only the finding, limit and regression
  here. Update this ledger when a new distinct failure is resolved or deferred.


The [participant-selection comparison](participant-selection-options.md) records
the cooperative API failure and alternative approaches. The author subsequently
chose leave-first native selection. Automatic group reconstruction remains absent.


## Expressions first iteration â€” validation limit

`20261031-expressions-1` references native facial sequences from FacialExpression and Face_HugKiss data. A separate ModKit commandlet could not load those game-only references; native playback and appearance remain for the first in-game checkpoint. Missing optional clips do not abort the scene and are reported in the personality panel. Preserve independent role ownership, owned-head-montage cleanup, jaw-overlay adoption and the native blink/gaze owners. Do not present isolated montage mocks or build markers as visual verification. See [expression contracts](../expressions.md).

## Expressions pre-test review (expressions-2)

These findings come from isolated regressions and source review; none is a claim of an observed in-game facial defect. Ownership loss, unfinished-jaw adoption and stopping-session preference writes were also reproduced against the unchanged expressions-1 source. Native playback and appearance still await the author checkpoint.

| ID | Established finding | Resolution and retained regression |
| --- | --- | --- |
| EXP-01 | The adapter discarded retiring montage ownership immediately when the active query returned false or threw. Inactivity also occurs during blend-out. | Retain ownership until a native-time blend deadline and confirmed inactivity, or positive instance invalidity. Retry failed cleanup/query calls. Test paused retirement, temporary query/stop failure, head replacement and bounded completed-lease retention. |
| EXP-02 | An unfinished jaw setup could adopt another owner's neutral jaw entry after head replacement; a near-neutral acquired correction could also match the foreign entry first. | Only successfully acquired old overlays can adopt copied head state. Prefer the recorded array position; ambiguous fallback matches remain errors instead of overwriting/removing a guessed entry. Failed jaw-state reads retain ownership until a cleanup retry or positive native invalidity. Preserve foreign-entry/rebuilt-head and temporary-read/cleanup regressions. |
| EXP-03 | Throwing loaders and wrong-type native objects escaped the optional-asset fallback. | Validate each asset inside its own protected load; skip failures, retain the cause and use bounded retries. Test exceptions and non-animation objects. |
| UI-04 | A queued personality request could persist after stopping began; the UI could accept an older acknowledgement or a body-incompatible profile row. | Ignore stopping/ended requests, validate complete profile frames before acceptance, reject decreasing acknowledgements and serialize personality saves with outfit edits. Retain Exit, stale-frame and body checks. |
| DATA-01 | Rejected expression definitions could leave freshly written scene outputs beside stale expression outputs. | Validate both inputs before writing any output. A regression verifies that an invalid definition leaves all six generated files unchanged. |
| EXP-04 | A mouth override starting from zero after a prior restore reset its opening transition every sample, preventing reopening. | Distinguish zero at the start of opening from completed closing. Retain an open/close/reopen regression before testing retryable cleanup. |

## First expression live checkpoint (2026-11-01)

| ID | Observed failure | Fix and regression |
| --- | --- | --- |
| UI-05 | In the game, the expression HTML select displayed every option and could not be clicked. Mock select change events had missed this. | Use the established button/list picker; test opening, click selection, closure and request retries. Use the native Japanese font fallback stack for the author's bilingual labels. Rendered acceptance remains pending. |
| EXP-05 | Live Exit repeatedly failed on `Montage_Stop` argument 2: the old owned montage was rejected as nil/incompatible, despite a surviving head animation instance. | Treat positive montage invalidity or the exact typed-handle rejection as a released known-owned montage; retain retries for other failures. Regression includes a collected handle with an unavailable validity helper. Garbage collection is consistent with the stale dynamic handles, but was not independently traced. Native clip selection/cycling is present in the live log; rendered appearance remains author-owned acceptance. |

The expressions-3 author-driven session `ui.1793507256950.752611.1.1` acknowledged and applied personality selections, cycled native clips and ended with `ok` after more than a minute. No cleanup retry/timeout appeared in that session. Japanese glyph appearance and final facial appearance still require author confirmation.

The author confirmed dropdown interaction, Japanese label rendering and Exit on expressions-3. Its decorative arrow rendered as a rectangular glyph; expressions-4 removes that suffix and displays the expression label alone. Existing UI assertions now compare the exact unadorned label. This does not establish acceptance of all facial poses.

Expressions-5 doubles built-in expression hold intervals at the author's request. The author reports that the procedural mouth override lowers the jaw too far without opening the lips; visible mouth opening is not accepted, and that implementation remains unchanged in this timing-only update.

Expressions-6 disables the mouth declaration on `hzoi.standing_kneeling` at the author's request; the unresolved generic jaw implementation is retained without changes.

Expressions-7 enables the existing mouth override on the framework standing hub's female role for focused debugging. The reported excessive jaw movement/closed lips remains unresolved; timing definitions and HZoi's disabled mouth declaration are preserved.

Mouth investigation after expressions-7: installed curve-node field edits and repository jaw-only code differed. A temporary runtime node-reference setter trial is now installed; the first test failed earlier in catalog loading because the female hub sequence was unavailable. Cooked container hashes still match expressions-7. Cause of the load failure is unproven; restart/retest requested. The setter trial has no visual acceptance and is not a packaged release.

After the restart the author reported no picker. Recovery restored the only two payload differences (experimental Main/OpenMouth) to verified expressions-7. All 68 packaged hashes match; cooked files and preferences were preserved. A fresh Lua host started after explicit mounting; its controls acknowledgement matched but launcher readiness was `none`. UI remount restored launcher readiness. Manual picker/hub test is pending. These readbacks establish a startup readiness gap, not its full underlying cause. The mouth experiment is disabled during recovery.

The runtime node-reference mouth experiment left evaluated jaw near zero and lip seal near one, then the game crashed during a second scene entry. Crash context records an invalid TSet resize assertion with Lua on the native stack. A borrowed map from a temporary `FB1CurveBlendDescription` is a suspected lifetime fault, not a symbolized conclusion. The trial was rolled back; all 68 expressions-7 payload hashes match. Preserve owning native structs for borrowed containers and do not reuse this trial. Mouth opening remains unresolved.

Expressions-8: live hierarchy inspection confirmed that `FACIAL_C_Jaw` and `FACIAL_C_LowerLipRotation` are independent children of `FACIAL_C_FacialRoot`. The former jaw-only 22-degree correction therefore moved the jaw without carrying the lips. The adapter now owns separate corrections for both roots, reduced to 10 degrees each. A native game screenshot shows visible opening; sustained appearance and final author acceptance remain separate checks. Original expression timings and declarations are retained. Runtime curve-node/map experiments were abandoned after ineffective curve readbacks and a native container crash; no borrowed curve maps are retained in this implementation.

The author accepted the paired-root mouth opening/proportions in expressions-8 as a checkpoint before further shape changes. Native screenshots also show opening across Exit/re-entry. The curve-map experiment and its probes are retired.


## Fixed mouth shape (expressions-9)

The paired-root opening remained expression-dependent. A reference-sampled lower-face pose now holds evaluated mouth joints in parent space while upper-face expressions continue. Capture excludes inactive detail/scaffold joints observed far below the head; including them produced large corrections. Only plain numeric poses survive between native reads and additive-array writes. No curve maps or runtime node references are retained.

The author accepted the refined rounded O, raised with reduced lower-teeth exposure. Four-family switching measured less than 0.03 mm joint-position error on the current female head; this does not establish vertex invariance or other-head appearance. Preserve three-owner/repeated-body tests, foreign-entry ownership, copied-head adoption, reference failures and retryable cleanup including prior head LOD/tick settings. Calibration currently samples its reference for 0.5 scene seconds on entry.


## Continuous facial handoff (expressions-10)

Gaze explicitly wrote a forward correction in `leave_node`, causing the reported neutral interval during preparation. It now keeps the outgoing target active and replaces the complete map at arriving playback entry; missing arriving data still intentionally means forward. Preserve delayed-preparation, moving-target and omitted-target regressions.

The 0.5-second visible mouth reference was replaced by precomputed native-rig pose data, validated by bone name/parent and applied on the first sample. Custom clips using the same rig need no separate capture. A hidden-head sampler produced materially different local mouth poses from the live reference (including rest-like controls); its precise native evaluation difference was not isolated. That sampler and its cache are retired, rather than using their inaccurate output. Preserve reference-free first activation, independent repeated-body owners, head replacement, unsupported-rig fallback and owned-entry cleanup. Customized facial geometry and male pose proportions still need visual acceptance.

The first continuous-gaze trial failed because `Session.change_node` clears `session.bindings` before preparation finishes. The gaze context now retains the outgoing binding map as well as its targets, replacing both on entry. The regression explicitly clears session bindings during delayed preparation.

A longer mouth trial ended with ambiguous correction ownership and a cleanup timeout. An isolated native-round-trip simulation reproduced duplicate entries when equivalent quaternions differed in magnitude. The controller now normalizes observed/solved rotations and compares normalized components with sign equivalence. The exact cause of the live ambiguity was not independently isolated; stale probe state and native rounding were possible contributors. The save was reloaded to discard abandoned native entries before final checks. Preserve the failing-before-fix round-trip regression and fresh-session long-run/Exit checkpoint.

Expressions-10 final checkpoint: the author confirmed both the gaze forward-reset fix and immediate O activation. Final packaged family switching, hub navigation, Exit and re-entry passed; a 130-second native run after the ownership correction also ended with a clean Exit.


## HZoi audio import (audio-1)

The headless sound factory initially created default Bink data before per-asset PCM was applied and emitted a handled missing-BINKA-decoder ensure. All 703 saved assets subsequently reloaded as PCM. The importer now selects PCM as its process-local factory default; it does not modify project audio defaults on disk. A separate export/readback pass emitted transient `SoundWave_0` WAV-parse errors despite producing seven readable, sample-checked exports. Do not interpret a Python report alone as a clean commandlet exit. The final cook/package succeeded, and exact payload membership/hash checks passed. Runtime voice/SFX playback and audible acceptance remain future checkpoints.


## Scene sounds: first implementation (sfx-1)

ModKit's native AudioSettings report a 0.4â€“2.0 pitch range. The sound adapter
clamps locally without changing global game audio and accounts for applied pitch
when estimating clip completion; faster combined animation rates can exceed the
available audio rate. Native attenuation/pitch/pause calls passed a headless
smoke check. This is not audible playback or retail Lua validation. Bone-distance
sampling reuses gaze's world bone lookup, but the Lua host's exact evaluation
phase and fast-rate minima still require a live checkpoint. Preserve independent
three-role emitters, pause/speed buckets, bounded polyphony, partial-component
ownership and retryable Stop/destruction regressions. The hub test declares
continuous kiss directly in its normal sound list; no SFX extension layer exists.


## Sound live corrections (sfx-2)

| ID | Observed failure | Fix and regression |
| --- | --- | --- |
| SFX-01 | Hub playback stopped at 13 plays; subsequent `SetSound` calls rejected cached native-wave userdata as nil/incompatible. The validity guard had not caused fresh loading. | Resolve the SoundWave by its validated path on every playback; the audio component owns the playing wave. Preserve a tombstone whose validity query is unavailable, plus long native cycling and Exit checks. |
| SFX-02 | Hand events occurred about 0.1 seconds after the measured minimum. Comparing each frame's delta with the dead band could also lose subtle motion at high frame rates. | Confirm reversal using movement accumulated from the last extremum. Retain 45/144 Hz sub-threshold-per-frame regressions; fixture hysteresis is 0.01 cm. Native hand events moved to one sampled frame after the minimum; rear events occur every measured cycle. Recording accents/final audible alignment remain author validation. |

The corrected hub trial completed 40 plays over 97 seconds with no SFX error and
clean Exit; both measured contact trials also ended cleanly. These establish
native scheduling/cleanup, while final audible timing remains author-owned.


## Native sound time and packaging export (sfx-3)

| ID | Observation | Resolution and regression |
| --- | --- | --- |
| SFX-03 | Piston triggers continued advancing without errors while the author heard silence. The author observed muting on loss of focus; saved background audio was disabled. | Preserve the game's background-audio preference. This does not invalidate the earlier independently reproduced stale-wave failure. No focus workaround or UI audio conversion. |
| SFX-04 | Generic clip pitch/duration incorrectly included SceneZOI's animation multiplier. | Audio uses a separate shared-clock native-time channel; scene speed only selects variants and changes contact frequency. Remove the obsolete pitch-reference field. Preserve all-four-speed duration/rate checks, mid-clip native speed changes and pause. |
| PACK-02 | UAT created a fresh ZIP, then failed while extracting over an existing raw duplicate at the Mods root. Windows identified inZOI holding its containers open. | Use PackageUGC with an isolated export directory and check actual exit code. The rerun ended BUILD SUCCESSFUL/0; filter it before installation. Quarantine the raw duplicate outside Mods with the game closed. Do not mistake dispatch acknowledgement or ZIP existence for complete packaging success. |


## Animation touch-up refresh (animation-refresh-1)

The first reimport attempt could not save the idle animation because ModKit held
its file open (Windows sharing error 32); content hashes confirmed that attempt
changed nothing. Reopening ModKit released the locks, and the established importer
then replaced exactly eleven animation packages with exit code 0. The three rear
packages, body/attachment skeletons and all other mod content retained their
hashes. Keep explicit selected-source reimports and pre/post hash checks; a failed
save/report must not be treated as a completed update. The temporary hub Kiss
expression/audio test is removed at the author's request. Earlier contact traces
remain historical evidence for the previous animation exports.

## Expression definition discovery (expression-data-1)

Retail Lua's static analysis rejects `io`, `debug`, unregistered external modules and unlisted UE types, including in unused source files. Early probe failures were initially mistaken for retained startup code; restart requests did not fix the rejected source. Native asset-registry access succeeds in retail Lua, so definitions now use inert JSON in native DataTables discovered across mounted mods. Keep probes outside installed Lua, inspect validation diagnostics before requesting restarts, and validate the complete source set. Preserve cross-mod/case-insensitive merging, transactional bad-file isolation, missing-body/context optional behavior, old-ID preference migration, dynamic dropdown options and repeated-body cleanup tests. Cooked definition discovery/author acceptance is recorded separately in validation.json.

Retail checkpoint failed: the registry returned no HZoi definition tables although all five cooked payloads and manifest class entries were verified. Direct loading a known table returned its exact JSON and made that one table appear in subsequent registry results. Non-forced ScanPathsSynchronous did not expose the remaining tables, and the native enabled-plugin list excludes this UGC mod. Generic registry access alone therefore does not prove installed-mod discovery. The author reported both body selectors empty; normal Exit succeeded. Temporary Main probes were removed and every installed payload hash restored. Startup discovery remains unresolved; do not describe this build as accepted or fully working.

## Shared declaration directory (data-files-1)

Public `uimod.cfg_load` with no key enumerates a known section and returns names plus text. It read five separate HZoi JSON envelopes from `scenezoi_data/` with no warnings. Adding an unlisted second-author file after packaging produced six records and a new selectable set without changing/recompiling any framework payload. The author confirmed English options, selection/facial playback and Exit. Removal returned discovery to five records; candidate hashes still match. Tests retain arbitrary filenames/kinds, cross-file merging, optional malformed files, cache refresh/removal and unmanaged-file ownership. Existing cooked bytes were preserved; no containers changed while the game was open. This verifies a shared physical directory, not automatic enumeration of separate mod roots. Independent-pack install/uninstall/disable handling remains a distribution contract to verify; cold process startup was not tested in this checkpoint.


## Native declaration registration experiment (native-data-1)

The shared cfg test did not establish independent ModKit pack discovery. A separate HZoi project now owns five native Text_UI Append records carrying inert JSON in raw strings; normal ModKit packaging includes its patch and checksum without a shared-folder installer or content-pack code. All five strings have exact native ModKit readback. The experimental reader ignores ordinary rows and the retired cfg directory, preserves unchanged snapshots, and refreshes before entry to handle later mounts. Both packages are installed; retail discovery and enable/disable/update/uninstall behavior remain pending. Preserve case-insensitive cross-owner merging, missing-library optional behavior, preferences and group ownership. A native external-change Reload dialog blocked MCP validation; author Reload restored it. Check modal state before requesting restarts.

Retail registration checkpoint: `Text_UI` is an editor/source-file name, not a retail CLI alias. Shipping exposes the composite alias `Text` with `iD`/`text` columns. The separate HZoi package applied all five rows on a cold process start and preserved exact payload strings. Native-data-2 uses the verified alias and case-insensitive columns; after the Lua/UI-only correction, SceneZOI reports five records and zero warnings. Preserve captured-retail-shape coverage; editor readback alone does not establish retail query shape. UI/playback/Exit and activation/removal remain pending.

Acceptance: author confirmed both selectors, changing sets/facial playback and normal Exit. Native HZoi disable changed SceneZOI 5 -> 0 definitions, and re-enable restored 5, with zero discovery warnings. Native-data-3 retains that transport and caches unchanged native responses before parsing; isolated first-parse time for the 658 KB packet was ~161 ms before string-span optimization and ~91 ms after. Cached reads skip parsing/compilation; native query cost is not included in that benchmark. Preserve read-error recovery as well as changed/removed records. Physical uninstall, content update/load-order and another authorâ€™s actual package remain distinct untested cases.

## Package split (20261102-split-1)

Observed during isolated refactor verification: passing `assert(value, message)` directly to the JSON decoder forwarded the message as its size argument, rejecting every Prepare snapshot. Assign the decoded value first. Session/lifecycle tests now cover the full encoded B1-to-B2 handoff.

Scene graph discovery, starting-hub matching and exposure profiles replace generated catalogs and built-in anatomy mappings. Source tests cover repeated bodies, distinct role ownership, absent packs, invalid contributions and arbitrary starting-scene roles; native/live results are recorded in `validation.json`. Preserve the startup handshake and group-departure flow while renaming the neutral starter modules.

Split-1 live entry initially failed before Start: `entity.get_character_info` is B2-authority-only and cannot be called by B1 Lua, even though the external MCP can call it. The trait reader now reads exported `FB1AppearanceSetting.Gender`, `BodyAgeType` and `GrowthStep` directly, with skeletal-body preference and native enum comparisons. `tests/traits.lua` forbids CLI access to retain this scope boundary. The picker decline acknowledgement also retains its request token so authorized focus restoration can complete.

Split-1 acceptance: author confirmed MF entry, first manual exposure at the neutral
hub, HZoi's four scene nodes/expressions/sounds/attachment playback and normal Exit/
movement. With HZoi disabled, native discovery fell from ten declarations/five nodes
to one declaration/one neutral node (zero warnings); framework-only controls and Exit
passed. Re-enable restored all ten declarations/five nodes with zero warnings. Author
also confirmed the native no-eligible-starting-scene toast. See `validation.json`.


## Voice subsystem (20261102-voice-1)

Voice-set metadata and customization use native voice declarations, independently owned SceneZOI emitters and per-Zoi preference files. Context UI is populated at runtime. Reuse the continuous SFX native-time and asset-lifetime fixes; scene speed must not change voice clip rate. Archetype changes reset all context choices atomically, and saved None choices remain silent. No climax/reaction engine is introduced. Isolated regressions cover repeated-body/male owners, missing content, persistence/storage/stale commands, recent-three history, holds and cleanup retries. ModKit checks and installation are recorded separately; native audible/UI acceptance remains for the author. See [voices](../voices.md).


## Voice personality UI spacing and wrapping (20261102-voice-ui-2)

The author accepted voice behavior and supplied screenshots of ordinary words split mid-word in the scene title/navigation. Those elements used `overflow-wrap: anywhere`; the UI now explicitly uses normal word boundaries with `break-word` fallback for oversized tokens, including picker labels. The expression persistence note was still generated but had been placed after all voice controls, below the visible scroll area. It now precedes voice controls directly after the expression picker; the extra archetype margins are reduced. Preserve that status ordering, narrow-window word wrapping, scrolling and unchanged generated window manager. Browser checks at 260Ã—338, existing UI regressions and ModKit UI validation passed. Only three packaged UI files/checksum metadata were installed; cooked/Lua hashes stayed unchanged. Native UI remount succeeded while idle with matching host/receiver readiness and the new UI marker. Actual in-game visual acceptance of this polish remains with the author.


## Live declaration refresh readback (20261102-hzoi-voice-4)

A direct native `data.patch` Override of one existing HZoi scene-pack Text field acknowledged but its subsequent single-row readback differed from the installed raw declaration. The attempt stopped at that mismatch; command acknowledgement did not establish success. The author chose a game restart, and the endpoint became unavailable during shutdown before rollback/readback could be verified. The correctly packaged/installed native JSON patch was independently validated and hash-verified; loaded cooked assets and Lua remained byte-identical. Use a fresh native package load for this checkpoint. Future direct Text refresh work must first verify its string serialization and exact native readback; do not treat this attempt as accepted live hot-loading.

## Tier 4 event delivery (2026-11-03)

`TASK-01`: Source review found the existing event dispatcher discarded pending notifications after its 64-event flush budget. The generic task implementation retains pending notifications for the next flush. An isolated 70-event regression verifies delivery without loss; this is a source-level robustness fix, not a claim of a previously observed live failure. Task snapshots/observers remain copied and deferred. See [task contracts and boundaries](../scene-tasks.md).

## Task-ring native rendering (2026-11-03, tasks-ui-2)

`TASK-02`: The author observed full colored task rings and left-aligned percentages in-game although the Chromium preview showed partial rings. UI revision 2 uses explicit SVG arc geometry instead of dashed strokes, a matching fixed SVG viewport, and a flex-centered text overlay. A temporary native numerical display showed a gray 0% track and a blue quarter-ring at 25%; text centers at 0/25/50/75/100% differed from ring centers by less than 0.001 px. The temporary display was removed. Packaged UI was hot-installed/remounted while idle, preserving all Lua, cooked files and settings. Retain zero/partial/full geometry, centering, scrolling and combined-panel tests. Authored group choreography remains untested; isolated task tests now cover 3/4/16/64 participants.


## Procedural completion timing and bone ownership (2026-11-03)

`EFFECT-01`: SceneZOI combines a shared playback-rate envelope with per-character local bone twists, integrating the envelope analytically over its existing shared clock to avoid phase drift or feedback when native/user speed changes. Movement markers/frequency and all body-specific profiles are content data. The current B1 export exposes `UB1BonePostProcessAnimInstance.AdditiveBones`; the new adapter owns appended body corrections independently of gaze/mouth facial rows and native fitting, including copied post-process arrays and partial cleanup. Isolated tests cover exact midpoint phase, markers/wrap, pause/speed changes, 3+ owners, body/attachment clock agreement, authored-route priority, no accumulation and preserved foreign rows. Native body-shaking appearance remains pending author acceptance; API availability and mocked adapter checks do not establish rendered appearance or foot locking.


## Positive slow-motion audio pitch (2026-11-03)

`AUDIO-01`: Author observed pitched-down voices during native 0.1x camera slow motion; native conversation voices retain normal speed. SoundNative now floors requested audio rate at 1x before native pitch bounds. Pause stays separate; fast-forward and world spatialization remain. Existing duration accounting already divides scaled delta by game scale and multiplies actual audio rate. Tests cover subnormal rates, mid-clip changes, pause/resume, voice/continuous timing, completion one-shot expiry and fast-forward caps. Native audible acceptance remains pending.


## Task-triggered voice interruption (2026-11-03)

`VOICE-02`: Continuous voice fades over 0.25 seconds before a random response. SceneZOI owns one response channel per participant, independently of animation/SFX. Named response groups stay inside the selected context/archetype; explicit task-role-to-speaker rules avoid body/index assumptions. Higher priority suppresses or fades out lower-priority lines. Equal-priority pending requests are bounded, navigation clears pending queues while a started line survives preparation, and silence/preferences/Exit release ownership. Tests retain mid-response priority preemption, simultaneous task completions selecting the female speaker, continuous volume/history restoration, pause/slow-motion timing and partial native cleanup. Native audible behavior remains pending author acceptance.


## Short voice tails after live set changes (2026-11-03)

`AUDIO-02`: Author reported clipped endings after selecting Cute A2/B1 during an active scene. A temporary live probe found timer-driven stops while the native component still reported playing; the user also reported a run sounding fixed while only logging was installed, so audible reproduction was intermittent. All 44 A2 source WAV hashes match the inventory; sampled native durations agree with WAV frame counts. Normal completion now waits for native IsPlaying=false after estimated expiry, covering continuous voices/SFX, completion one-shots and response return. Native-state waiting is bounded without spending the watchdog on an initial loading hitch; pause and explicit interruption semantics remain. Regressions cover asynchronous tails, live set replacement and subsequent clips, native completion/fallback, deliberate cleanup and watchdog bounds. Native audible acceptance is separate from source/native state evidence.


## Controls hiding and native menu modality (20261103-panel-state-ui-1)

The author observed Hide ending a session with `ui_disconnected`, and controls remaining bright/usable over the Game Menu. The game's injected Hide listener uses native `userHide`, bypassing SceneZOI's existing DOM-only closure. Capture that button (including icon descendants) before native/scaffold listeners; collapse to a small reachable **Show SceneZOI** tab instead. Keep the native view, its heartbeat and the six-second disconnect watchdog unchanged. Preserve expanded dimensions/placement, attached-panel state and reset on session closure/new entry.

The supported Cohtml view API does not expose native UMG layer placement. The presentation controller polls public `ui.get_blocking`, mirrors the native dark scrim on all scene/task/config surfaces, consumes DOM input, releases hover, and moves the native hit rectangle off-screen while modal UI blocks gameplay. This is local dimming/input gating, **not** verified native reparenting below the game's scrim. Native time pause by itself never blocks controls. Disable the game's injected direct root-only rect watcher; retain scaffold/attached-panel reports through the presentation gate. End any pending drag/resize before entering the blocked state.

Framework regressions, browser renders, native Lua/UI validation, isolated packaging/filtering and installed hashes passed. Only three UI files plus checksum metadata changed; Lua/cooked assets, HZoi and preferences were preserved. UI remount while idle reports the new marker, matching host/receiver readiness, and no UI error key. The author was editing the house in Build Mode; no gameplay-mode change or scene entry was performed. Actual running-scene Hide/restore and native menu presentation/input acceptance remain pending. Retain hidden-heartbeat, late-injected-button, modal input/hit bounds, ordinary pause, restore geometry and existing panel reflow regressions.


Restore-tab follow-up (`20261103-panel-state-ui-2`): the author's screenshot showed a monospace-looking inherited control font. The tab now explicitly names the same native proportional faces as the scene buttons. It supports primary-button dragging, a four-pixel click threshold, viewport clamping, immediate hit-rectangle updates and full-size window-position persistence. A native click following drag completion is consumed; an ordinary click restores the panel at the moved position. Framework/drag regressions, browser font/drag checks and native validation passed. The filtered UI-only update is installed/remounted with the new marker and matching startup readiness; Lua/cooked files and HZoi stayed unchanged. Actual in-game font and pointer-drag acceptance remain pending.


## Initial furniture lifecycle (20261103-furniture-1)

`FURN-01`: The new isolated real-runtime regression found a participant-release callback could finish Exit before the bed reservation's release acknowledgement. Both completion paths now require the furniture barrier; delayed acknowledgement, retry and repeat-entry checks pass. This was a source-level defect caught before installation, not an observed live failure. Preserve partial-acquisition ownership, native temporary occupancy versus assigned-side ownership, save/load cleanup and B1/B2 scope boundaries. Native collision rays and overall mesh bounds do not establish the lying plane: futon support is provisionally 5 cm and needs rendered alignment acceptance.

`FURN-02`: Final source review found unavailable-bed rejection could occur before a pending picker object existed, omitting focus authorization. The error path now uses the requester's captured actor when no picker exists. The isolated entry regression verifies authorization without opening the picker; this was not an observed live input failure.


## Invalid bed anchor transform (20261103-furniture-fix-1)

`FURN-03`: Author's first single-bed entry reached playback, then stopped with `Scene montage stopped unexpectedly`; cleanup restored standing posture and cleared the reservation. Native reproduction also produced `furniture_changed`. A coordinate trace captured Z=-1299358.9 and inverted rotation during playback while the bed's simulation transform remained unchanged. The new C++-style positional `FTransform(FRotator, position, scale)` call did not construct the intended transform in retail. Use a default reflected FTransform and explicit Translation/Rotation/Scale3D assignments; upright furniture uses a yaw quaternion. Keep parent transforms alive while reading child fields and store original validation coordinates as plain values. Do not bypass montage ownership checks or replace the game animation instance.

The new placement regression rejects positional transform construction and checks realistic coordinates, rotated offsets, low-surface height compensation and independent snapshots. Complete source/native validation passes. B1-only live reloads and native sessions on a normal single, normal queen and double futon passed stable playback, sensible coordinates, original-position restoration and reservation release; screenshots show the authored pose. The filtered packaged Lua correction preserves all loaded cooked bytes, HZoi and preferences. Native backend trials are distinct from a full picker-route retest, third-Zoi occupancy exclusion and author visual acceptance.

### 2026-11-03 â€” bed duvet reference

The original 45 cm mattress reference visibly intersected bedding. The author re-exported the same three four-second tracks at ground support height 0. Furniture profile data now targets 70 cm on standard beds and 20 cm on futons; the existing authored-to-profile transform needs no runtime change. Seven native compensated previews completed playback and restored original positions, including the new E01 queen. The author watched and accepted the revised heights. Ground-level clips were reimported, checked, cooked in isolated exports, filtered and installed with the game closed. Do not apply the old 45 cm compensation again. New cooked-clip post-install live verification and actual third-Zoi occupancy acceptance remain separate.

## Facial blink suppression (20261103-blink-1)

`FACE-01`: Ordinary expression clips were repeatedly sampled at frame zero, freezing the native eyelid motion contained in those clips. Native idle blink curves reached about 0.98; the held male scene face stayed below 0.06 in the diagnostic trial. Options without an explicit authored `sample` now advance and loop on the expression/session clock. Explicit samples retain fixed-pose semantics, including intentionally closed eyelids. Guard calls hold outgoing poses, paused time does not advance clips, and replacement heads preserve facial time. Both participants produced blink curves above 0.98 in the corrected 20-second bed trial, followed by idle/ok Exit. No synthetic blink controller, animation-instance replacement or HZoi-specific runtime behavior was added. Keep looping, pause/guard, replacement-head and explicit-pose regressions. Full source/native checks and isolated packaged hot installation passed with existing cooked bytes preserved; visual author acceptance remains separate. The same update lowers normal-bed profiles to 68 cm (futons remain 20) and sets both neutral bed hubs' female gaze to their own body `hand_l`; omitted male gaze remains forward. Live native row readback and packaged playback/Exit passed.

## Release source layout (2026-11-03)

The active framework moved from the former demo source tree to the repository root. The unused historical prototype project, binary anatomy assets and old fixture tests were removed. Active lifecycle/native/outfit/attachment/material suites remain; the Blender attachment exporter was briefly moved to HZoi developer tools before its later removal at the author's request because it is published separately. Runtime/UI/declaration bytes and production import inventories are preserved by this source-only migration. No new live behavior or visual acceptance is claimed. Current documentation separates entry contracts, historical evidence and native/visual boundaries.

## Retired developer-tool cleanup (2026-11-03)

The separately published Blender exporter and its local guide were removed from HZoi. The archived import_expression_data.py was also removed: it belonged to the retired Unreal DataTable expression-discovery experiment and is not called by any active build/test command. Current expression_data.py validation and native Text_UI declaration staging remain in use. This removes developer-only files and documentation references; installed runtime, declarations and binary assets are unchanged.

## Graceful control-distance and duplicate-start handling (20261104-guardrails-3)

LIFE-02: The author's outside-roster walk-away attempt ended with restore_timeout. An older retained error described input restoration using an invalid native actor; it did not prove the fresh attempt's initiating cause. The initial 50m/1s safeguard also failed its live trial. Guardrails-2 added bounded controller_range data, last_stop, initial/final last_exit reasons and concrete cleanup-error retention, and reduced the limit to 20m/0.5s. The author accepted that trial, then requested 35m. Guardrails-3 keeps the half-second grace and uses 35m. The final author-driven trial ended idle/controller_too_far with matching initial/final reasons at approximately 37.3m after the grace period. The author confirmed toast, clean closure and participant usability, and preferred this distance. The normal cleanup barrier completed; no particular native streaming/LOD cause of the old failure is asserted.

Retain actual-controller identity checks, inside-roster control swaps, nearby spectators, 3D anchor distance, exact boundary/grace reset, initial preparation fallback and transient native-query handling. Delayed input restoration uses a currently registered context rather than an unloaded entry actor. last_error can remain historical; correlate it with current last_stop/last_exit identity and timestamps.

UI-06: A second Start previously returned silently in the launcher. It now shows a native already-in-progress toast, with native entry/runtime guards for stale-state races. Foreign busy requests preserve the active status mailbox and do not repeatedly toast; optional toast failure cannot end the existing session. The author accepted the ordinary active-scene toast. Preparing/exiting, stale requests and failure paths retain automated coverage.

ENTRY-03: The author recalled failures with a singing park NPC, but reported on 2026-11-04 that entry now works in the latest sessions. No singing-specific runtime change was made; do not attribute this acceptance to a speculative interruption fix. Other queued/noninterruptible activities remain separate test cases.

Final verification: 41 Lua suites, 57 Python tests and five JavaScript suites passed. Native Lua/UI checks reported zero errors/warnings; final isolated packaging exited 0, exact four-asset filtering passed, installed hashes matched and all loaded cooked bytes/HZoi/settings/preferences were preserved. At that checkpoint, runtime guardrails-3 and unchanged UI guardrails-ui-1 were active. Broader furniture, visual/audio and forced-world-transition acceptance boundaries remain as recorded separately.

## Participant interaction backlog (20261104-queue-1)

ENTRY-04: The author reported preparation failure after queueing many hydrant interactions, then confirmed that a single conversation was interrupted correctly. The retained preparation error says prepare_timeout; later successful sessions had overwritten the matching stop/exit identity. Source and a failing-before-fix regression establish the queue failure mechanism: interaction.cancel advances to the next waiting interaction, autonomy disablement does not stop user-queued work, and the old cancel_pending latch then suppresses cancellation of a successor.

The participant lease now clears native waiting work before cancelling the current interaction, tracks cancellation by queue identity, and waits for two idle callbacks before readiness. The same guard continues during ready/playback ownership. Original autonomy value/inheritance and existing independent cleanup remain unchanged. A supported reliable queue-pause mechanism was not established; the author authorized cancelling queues as fallback. Cancelled work is not resumed. No Smart Zoi toggling, private queue mutation or new native hooks were added.

Retain long/waiting-only queues, single conversation, asynchronous cancellation, newly queued/current work during playback, clear/cancel failure, original autonomy inheritance and lease expiry regressions. All 42 Lua suites, 57 Python tests and five JavaScript suites passed; full native Lua validation reported zero errors/warnings. Isolated packaging exited 0 and exact four-asset filtering/hash-verified installation preserved cooked/UI/content/settings/preferences/HZoi bytes. Both Lua hosts reloaded while idle with matching host/receiver and ready launcher. The author subsequently confirmed queued-participant entry/cancellation and target-participant entry. An outside nonparticipant continued attempting queued interactions but could not complete them against the scene-owned target; those outsider queues were not cleared. Native state later read idle/ok. This accepts the reported queue scenarios without claiming all activity/Exit edge cases.

The preceding guardrails-4 checkpoint also corrected preparation-only distance fallback to resolve the declared anchor role before bindings exist. Its role-order regression and native checks passed; the accepted 35m running-scene policy is unchanged. Queue-1 includes this correction. Earlier guardrails-3 author distance acceptance is retained separately from queue-1 activation evidence.

## Scene overhead presentation (20261104-visuals-1)

UI-07: The author supplied screenshots of the constant selected-Zoi marker and nearby thought bubbles obscuring a bed scene. Native exports identify AB1Player.PlayerSelectedFxComponent as the selected-avatar Niagara component and UB1SpeechBubbleWidget as the overhead bubble root. The behavior docs mention SetForceHidePlumbob, but that function is not exported; no unsupported call or global cheat is used.

SceneVisuals temporarily hides only those marker components and zeros overhead speech/thought bubble opacity during scene preparation/playback. It preserves the game's FX activation/assets and bubble visibility/expiry/pooling, plus the original hidden flags/opacities. Repeated sessions, new/replaced markers, late bubbles, partial mutations, retryable independent restoration, native invalidity and foreign presentation changes have regression coverage. Exit/error/unload restore presentation; optional failures do not abort the scene and idle ticks retry restoration. overhead_visuals retains bounded counts/errors.

All 43 Lua suites, 57 Python tests and five JavaScript suites passed. Final native Lua validation has zero errors/warnings; isolated packaging exited 0, exact four-asset filtering passed and installed hashes match with cooked/UI/HZoi/settings/preferences preserved. B1 activation read idle/ok with matching host/receiver generation, ready launcher and zero visual leases. Actual marker/bubble disappearance, control switching and restoration after Exit remain pending author visual acceptance.

### Visuals-2 follow-up

The author accepted marker disappearance on visuals-1 but supplied a screenshot showing thought bubbles still rendered. Wrapper opacity is therefore not an accepted bubble fix; animation refresh is a possible explanation, not a traced cause. The author considers remaining bubbles minor and authorized keeping the investigation bounded.

Visuals-2 limits marker leases to the fixed scene roster, so a controlled outsider retains the normal marker and a controlled participant remains hidden. An isolated regression checks outside ownership, scope retirement/re-entry and original flag restoration. The bubble follow-up also suppresses exported visual children (background, portrait, icon, text and switchers), with per-child original opacity retained. Its regression covers wrapper/content refresh and independent restoration. overhead_visuals_active retains the last active counts/error after Exit; earlier idle diagnostics had overwritten that evidence.

All 43 Lua suites, 57 Python tests and five JavaScript suites passed; full native Lua validation has zero errors/warnings. Isolated packaging exited 0, exact four-asset filtering and installed hashes passed; cooked/UI/HZoi/preferences were preserved. Idle/ok and host/receiver/launcher readiness read back. Actual participant-to-outsider-to-participant switching and bubble-child suppression remain pending author acceptance. No bubble success is inferred from mock checks.

Visuals-2 author checkpoint: the author confirmed working behavior and a large visual improvement, including the reported marker/control-switch result. Bubbles also disappear for nonparticipants (tested household). This follows implementation scope: all local overhead bubble widgets are suppressed during a scene, not a household-specific rule. Marker hiding remains roster-scoped.

A focused export check found no Target actor/ID member on UB1SpeechBubbleWidget (including available inherited metadata); FB1SpeechBubbleObjectData exports only SpeechBubbleWidget and the handler exports ActiveObjects/WidgetPool without an owner association. This does not prove participant-only suppression impossible, but it is not an established small change through supported APIs. Recommend retaining the accepted local-UI-wide bubble suppression for the first release and treating narrower scope as deferred investigation. No runtime changes or new installation were needed for this acceptance/documentation update.

## Saving during scene mode â€” open finding (2026-11-04)

LIFE-03: The author saved during a scene and loaded successfully with participants standing at the same translation; that placement is accepted. The author confirms their autonomy was disabled beforehand, so the loaded disabled values do not establish an autonomy leak. Fresh runtime state is idle/ok.

Read-only reflection found simulation bCollisionEnabled=false on both Zois from the last retained roster (20522/20526), while the other two household Zois report true. This is the flag SceneZOI disables during participant preparation. Its pre-scene baseline was not captured here, so attributing the values to this save requires a controlled reproduction. It is nevertheless a concrete cleanup concern rather than evidence that coincident coordinates corrupt a save.

B2 on_savegame attempts outfit/position/collision/autonomy restoration and returns an empty module state. on_begin discards the in-memory lease; no original restoration snapshot survives for load-time recovery if altered flags were serialized. Native serialization/callback ordering and the exact source of the observed false flags remain untraced. No save-file corruption was established, and successful loading is not proof of comprehensive gameplay-state restoration. Investigate before first release; interim advice is to Exit before saving. No runtime changes or gameplay mutations were made for this assessment.

### LIFE-03 resolution â€” SDK save journal (2026-11-04)

The author actual bed Save As did not dispatch the save-1 pseudo-simulation manager override or Lua save/load callbacks. That override was removed. The supported UI SDK SaveState provider and load delivery did dispatch. A trial provider requested Exit successfully, but loading still produced false collision flags: the notification is too late for an asynchronous Exit to be the sole protection.

Save-2 caches complete immutable participant originals and the optional furniture owner/object in SDK save data, acknowledged by the controls view before native participant/furniture mutation. Saving requests normal Exit. Loading gates entry while B2 restores original collision, autonomy/inheritance, transforms/body layout, exact temporary outfit and recorded furniture occupancy. Independent owner acknowledgements retain unfinished cleanup and avoid replaying completed owners. Older saves lacking this journal are not retroactively repaired; SceneZOI must remain enabled on load. Exit, complete cleanup and save again outside scene mode before removing it.

44 Lua suites, 57 Python tests and six JavaScript suites passed, plus the saved-furniture retry/duplicate/deleted-object regression. Native Lua/UI validation reports zero errors/warnings; isolated packaging exited 0, the exact four-asset filter and installation hashes passed, with cooked assets and HZoi unchanged. Actual bed Save As and autosave both ended with saving reason. Both test-slot reloads completed the recovery barrier, restored collision on all four household Zois, preserved their pre-existing disabled autonomy and left all bed slots empty/unlocked. The author repeated bed entry after manual reload successfully. Autosave settings were returned to enabled/15 minutes. These diagnostics do not establish broader visual, ordinary-interaction or every roster/outfit combination, nor do they establish unrelated save-file corruption.

A subsequent ordinary Save outside scene mode and reload did not issue a fresh recovery request; all four original collision/autonomy values and empty bed occupancy remained correct. The game was left open, idle and paused in the test slot.

### LIFE-04 â€” scheduled autosaves during scene mode (2026-11-04)

The author requested suspending scheduled autosaves to avoid interrupting scenes, while retaining LIFE-03 protection for forced saves. Autosave-1 leases only the global enabled flag: persist ownership before disabling an enabled setting, restore after normal/error Exit or mod unload, retry failed restoration independently while idle and recover outstanding ownership on framework boot. Originally disabled autosave and the interval are untouched. No save callback, journal or participant/furniture safeguard was removed.

All 45 Lua suites, 57 Python tests and six JavaScript suites pass; native Lua/UI validation has zero errors/warnings. Targeted tests cover enabled/disabled originals, no recapture, read/persistence/partial-native failures, idle retries and fresh-environment boot recovery. The actual bed-entry test read autosave disabled while playing and enabled after normal Exit, with interval 15 unchanged. A second bed session started with autosave already disabled; a real manual save still triggered the existing saving Exit, and autosave remained disabled. Test preferences were restored afterward. Process-crash recovery has isolated coverage; no deliberate game crash or foreign mod autosave was injected. The SDK autosave route retains its prior native evidence, and its source/UI bytes are unchanged by this revision.

### World-transition acceptance follow-up (2026-11-04)

The author reports no apparent failure in the latest transition test and says the other suggested early-cancellation, furniture, three-participant and framework-only checks had already been tried. Exact variants/models were not enumerated. Retained diagnostics identify queen-bed sequence 2 stopping as interrupted, matching released autosave ownership, then a fresh idle/ok runtime. Native readback shows autosave enabled at interval 15, both last-roster participants (20522/20524) with collision/autonomy/inheritance matching their captured originals, and bed 4794 empty/unlocked.

The final last_exit record still belongs to preceding sequence 1. The interruption/startup records and current-state checks are useful evidence; they do not provide a matching complete old-session Exit acknowledgement or every teardown step. No runtime change was made or reinstall required for this checkpoint.


## Independent add-on API and metadata (20261104-addons-3)

ADDON-01: Separate B2 native-message communication is now verified in retail with
an independently installed source-only developer mod. Its B1 controller initially
used `entity.get_possessed`, which is B2-only in Lua; the native player controller
provides B1 identity. Public requests retain technical checks and the UI SDK save
journal barrier. Do not substitute direct private runtime calls as transport proof.

Native trials verified dictionary/alias and role queries, all three start modes,
GENERAL-only hub navigation filtering, rejected direct explicit navigation, busy
refusal, copied events/context and repeat Exit. Original collision/autonomy and
autosave enabled/15-minute settings were restored. Source regressions additionally
cover foreign ownership, retry deduplication, status isolation for clients reusing
request IDs, registry conflicts, directional actions, transition/task restrictions
and failure paths. JSON copying preserves null and empty arrays. These are native
and automated results, not new author visual acceptance. Concurrent NPC sessions
remain deferred. The temporary developer add-on is removed after validation.


## Descriptive dictionary policy (20261104-dictionary-1)

ADDON-02: The initial names/aliases retained shorthand,
culturally named positions and overly broad synonyms. The author approved
anatomical canonical names, full-word underscore aliases, removal of six tail
actions, explicit rating corrections and factual pose descriptions. Core now has
55 tags and 82 actions. Nine named-position tags are replaced by 20 descriptors
for posture/orientation/placement/contact; third-party namespaced dictionaries
remain supported. This is a metadata policy update, not a position-classification
engine. Do not infer gender/control status, performer or a relationship requirement
from posture. Group unary tags do not encode arbitrary pair-specific relations.
Retain regressions for role-correct descriptive queries, custom named-position
definitions, authored alias spelling and the nine worked metadata fragments.
Existing animations were not visually reclassified. See [metadata](../scene-metadata.md).


## Add-on control/observation contract (20261104-api-4)

ADDON-03: Public access previously lacked explicit role intent, structured preflight,
supported furniture discovery, observer interruption/modifiers and recoverable end
facts. API version 1 now exposes those through the existing independent native
transport. Registration grants narrowly scoped expiring rights; subscription does
not grant navigation ownership. One active session, controlled initiator, fixed
membership and ordinary navigable playback remain unchanged.

The real task engine owns completion/reset/events despite external progress/rate/
hold commands. Temporary voice/expression/clothing/prop controls retain caller and
participant ownership, do not save preferences, and release independently on Exit,
failure or lease expiry. Player clothing edits supersede that item's overrides;
UI commands and native outfit counters are independent. Destroyed native props
retire on a supported invalidity result, while unknown/failed cleanup retains its
retry lease. Recent end facts distinguish initiating reason and cleanup barrier,
and count only positive playing time. Rich snapshots are avoided for per-frame
internal active/idle checks.

Retain regressions for pinned same-body roles, competing holds/mutes/expressions,
clothing baseline/player priority, orphan cleanup and destroyed components,
real-engine completion, bounded result/annotation storage, subscription snapshots,
duplicate/stale events and host-change callbacks submitting fresh SDK requests.
The separate temporary developer harness uses creator/observer/abandoned clients,
neutral declarations, explicit commands and bounded failure/event diagnostics.

Full combined checks passed 52 Lua suites, 74 Python tests and seven UI suites;
focused post-review service/effect/SDK checks passed. ModKit Lua/UI static validation
has zero errors/warnings. Isolated PackageUGC exited 0, exact four-owned-asset
filtering passed, and all 124 framework plus 12 developer files match installed
hashes. HZoi/preferences/unowned files remain unchanged. Native Lua protection is
verified against the isolated export; editable inputs match native/prepared source.
New live API/SDK/effect/furniture behavior and visual acceptance are pending author
launch/authorization. See [API controls](../addon-controls.md) and
[the acceptance guide](../validation/addon-api-20261104.md). Remove the temporary
driver/fixtures and unmount the developer mod after acceptance; retain the SDK and
source regressions.


## API/SDK native acceptance and voice-mute follow-up (20261104-api-5)

ADDON-04: Actual API-4/5 retail trials passed the independent creator/observer
suite; the final API-5 run made 98 assertions/checked-response checks, including
role-pinned matching/preflight, inert scene/role/action data, ownership refusals,
speed, task inspection/set/modify, competing holds and real completion, scoped
presentation, attachment readiness/removal/error handling, navigation, expiry,
observer interruption/results and bed entry/release. Four participants' original
collision/autonomy, autosave/settings, controlled identity and bed slots match
the captured baseline after cleanup.

A manually started voiced HZoi scene additionally verified late subscription,
observer rights, independent native voice mutes, unmute/resume, 14 real seconds of
paused lease renewal with frozen task/play accounting, unchanged saved preferences
and observer Exit. These are native diagnostics, not inferred author visual or
audible acceptance. A real muted clothing handoff on API-5 kept the emitter play
count unchanged, then resumed after release; outsider control preserved observer
writes and the scene, and a loaded expression override reported no participant
error. Source regression found/fixed the two associated defects: Voices.enter
could play before immediately muting, and intentionally suppressed completion
responses produced a false unavailable-response warning.

B1-only host reload first timed out with retained developer owner wrappers.
Refreshing the wrapper while retaining the entity ID resolved the case; SDK
refresh_owner(owner)/tick(real_seconds,owner) now formalize same-entity refresh
for pending retries and renewals without handing control to another Zoi. The
preserved B2 SDK then observed the instance-change callback, rejected old host
state/registration, and subscribed/registered afresh. Retain that native case
and the SDK outsider/refreshed-owner source regression.

Test-only setup corrections: remove duplicate bound/global driver ticks, correlate
new runs rather than accepting retained terminal diagnostics, use an actually
installed skeletal asset, and explicitly enable the developer manifest. Temporary
test declarations were applied through supported retail Text patches; this does
not establish cold-start loading of the source-only developer fixture package.
The framework's enabled-package discovery architecture is unchanged.

Full source checks passed 52 Lua suites, 74 Python tests and seven UI suites;
focused updated SDK tests passed. Native Lua/UI validation is zero errors/warnings.
Isolated UAT/filtering passed with exactly four owned assets. The API-5 hot update
verified equal owned cooked content and retained every loaded cooked byte, changing
only Config/Voices/VoiceResponses plus the manifest. All 124 framework and 12
developer files match verified hashes; HZoi/preferences remain unchanged. Game
left idle with test registrations/subscriptions released. Keep temporary scripts
for author acceptance, then remove/unmount them as documented.


## Registered native add-on startup and assetless packaging (20261104-api-5)

ADDON-05: Cold startup exposed that the earlier manually mounted Lua scaffold
neither activated automatically nor contributed its JSON declarations. Enabling
its ad-hoc manifest/export was insufficient; ModKit also rejected that unregistered
project for Lua validation. Preserve this distinction from successful native-message
API tests after manual mounting. Create/register native projects through ModKit.

The replacement SceneZOIAddonExample_6F2CD7DE was created through ModKit, accepted
full Lua validation with zero errors/warnings, and packaged through isolated UAT.
Its native Lua/data-only export has no cooked response/container and an empty
asset-hash document. The exact payload filter now supports that case with a strict
manifest file allowlist and rejects unexpected files, declared assets and cooked/
native payloads. Five regressions retain the valid/empty-hash and rejection cases.

Fresh process launch then loaded the SDK and both declaration rows automatically,
without Lua mounting or retail data_patch. The full creator/observer suite passed
again after that startup, with normal cleanup. Original settings, controlled Zoi,
all four collision/autonomy states and tested bed slots match baseline. Thirteen
developer package files and 124 framework files match verified candidates; no
cooked developer assets or referenced Game/Engine payloads were installed.

The old scaffold copies are quarantined outside both Mods directories and editable
sources/tests/docs point to the registered example. Full source checks passed 52
Lua suites, 79 Python tests and seven UI suites, with focused SDK checks after the
source-path/lint cleanup. This supersedes the earlier cold-start limitation; author
visual/audible acceptance remains separate. Keep current temporary tests pending
acceptance, then remove their driver/fixtures and unmount the developer mod.


### API acceptance cleanup (2026-11-04)

At the author's request, remove the accepted native/legacy test mods, projects,
controllers, fixture declarations and local API-only work areas. The game was
closed, so no test package remains loaded and its declarations will not return
on startup. Framework/HZoi installed files and native framework Lua are byte-identical.
The reusable SDK is now sdk/lua/SceneZOIAddon; isolated regression coverage remains.
Current contracts and authoring pitfalls are in [the authoring guide](../addon-authoring.md),
[API](../addons.md), [controls](../addon-controls.md) and
[concise findings](../validation/addon-api-20261104.md). Earlier temporary paths
and pending-removal notes above are historical checkpoints, superseded by this cleanup.


## Generic facial poses and core review (20261104-facial-1)

FACE-02: API expression overrides could acquire a fixed pose without a facial clip,
then fail to release it on a node with no expression instruction because cleanup
was conditional on clip ownership. Always release the owned pose independently.
Retain pose-only acquire/clear/expiry regression. Generalize fixed target data to
native `facial_pose` declarations; remove the O-specific boolean/modules/compiler
and unused reference helper. Preserve accepted O coordinates, foreign-entry and
head/LOD cleanup tests. Eye-containing poses suspend procedural gaze until their
footprint is removed. Head-component attachment selection uses the existing engine.

CORE-01: Remove the unused pre-API packed event bridge; current add-ons use copied
JSON events. Share one cleanup barrier between callbacks and public result facts,
cache task ordering and unchanged expression data. See [review findings](../validation/subsystem-review-20261104.md)
and [facial authoring](../facial-poses.md). Automated/native evidence and author
visual acceptance are recorded separately in the current validation report.

Facial-1 retail checkpoint: 42 declarations/zero discovery warnings on cold
startup. The author accepted unchanged O appearance and normal controls,
navigation, Exit and bed behavior. Native final Exit was idle/ok, captured
participant collision/autonomy/inheritance matched, and autosave was restored.
New tongue geometry/head-prop visual fit remains untested. See the current
[review evidence](../validation/facial-poses-20261104.json).
