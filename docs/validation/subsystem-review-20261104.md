# Core and subsystem review — 2026-11-04

First-release implementation `20261104-facial-1`. Review focused on current source contracts, ownership,
API integration and existing regressions, following API-5 native acceptance.

| Area examined | Finding / action |
| --- | --- |
| Core/session/Exit | Consolidate participant, furniture and optional-engine cleanup into one predicate shared by acknowledgements and public result facts. Independent retries remain. |
| Internal/public events | The old packed `SceneZOI.Event` bridge had no runtime consumer and duplicated public JSON delivery. Remove it and its compatibility documentation; keep the deferred copied dispatcher and API event stream. |
| Entry, picker, binding/search | Current shared predicates already support manual/API entry and enforce every route. Preserve native picker/input and fixed-role ownership. |
| Playback/clock/transitions | Shared sampled native animation instances and distinct animation/game/watchdog clocks remain appropriate. No replacement system added. |
| Tasks/actions/completion responses | Cache stable task-definition ordering once per session instead of sorting for each participant/readback. Keep actual-engine completion and route priority. |
| Expressions/facial poses/gaze | Generalize O-only code/data to pack-owned partial facial poses; remove unused reference helper/compiler. Fix pose-only override release and prevent gaze from competing for fixed eye joints, including handoff. Cache unchanged expression declarations. |
| Attachments | Reuse one engine for scene/API resources. Add head-component parenting with existing inverse-reference bind, warm-up, shared clock and cleanup. |
| Outfits/body/materials | Existing snapshots, acknowledgements and independent region owners remain necessary. Head props cannot request body-region replacement. |
| Voices/SFX/completion voices | Already share native-time audio and retained cleanup; API-5 mute fixes remain. No new audio engine. |
| Furniture | Keep reservation/transform checks and release acknowledgement barrier, now covered by the shared cleanup predicate. |
| Save/autosave/range/presentation | Existing guards still serve distinct purposes; keep journal recovery, autosave lease, distance Exit and visual restoration. |
| UI/SDK | Keep the established picker/config handshake; independent mods use native API messages. Advertise new pose/head-attachment features and expose copied definitions/errors. |

No speculative rewrite, new session system or backwards-compatibility alias was
introduced. Existing accepted O coordinates are unchanged; HZoi changes only its
declarative reference. New source tests cover malformed/isolated pose data,
disjoint pose switching, pose-only release without clip ownership, gaze handoff,
head attachment replacement and public body/definition validation.

Current automated/native/package evidence is recorded in validation.json and
[the concise retail checkpoint](facial-poses-20261104.json). All 52 Lua suites,
81 Python tests and seven UI suites passed; native Lua/UI validation reported
zero errors/warnings. Both packages were isolated, filtered and installed with
matching hashes; cooked files were unchanged and user files preserved.

Cold startup loaded facial-1 and all 42 declarations with no discovery warnings.
The author confirmed that the O looks unchanged, then reported normal expression,
outfit, speed/pause, navigation, Exit and bed behavior. First/final native Exit
readbacks were idle/ok; final participant collision/autonomy/inheritance matched
their journal originals, and autosave was restored. A current animated attachment
reported zero shared-clock error during the pass.

Generic non-mouth/eye handoff and head-parent replacement have isolated regression
coverage. No new tongue mesh was created or tested; a particular mesh's rig,
alignment and appearance need separate author acceptance. The final retained
native journal belongs to the later standing scene; bed behavior here is author
acceptance, not a claimed native bed-occupancy trace.
