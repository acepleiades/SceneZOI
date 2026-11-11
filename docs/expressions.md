# Scene expressions and personality

Current runtime and acceptance boundaries are recorded in [validation.json](../validation.json). Expression definitions use schema version 2; fixed facial poses use their separately documented schema.

Enabled independent packages supply expression sets alongside their other native declarations. SceneZOI owns ten declarations and five neutral nodes. Recorded integration checks used five expression sets from the private, optional HZoi pack; those files are not part of this checkout or required for authoring.

## Responsibilities and data

SceneZOI owns the engine, persistent per-Zoi preferences and personality panel. Content packs own their expression definitions. SceneZOI contains no built-in expression families. Removing all compatible definitions leaves the participant's face game-owned and produces a warning, without blocking scene entry.

Expression set IDs and contexts are **case-insensitive strings**, trimmed and normalized to lowercase. Internal keys are printable ASCII, 1–96 characters; spaces and punctuation are allowed. Display labels may use Unicode and are separate from identity. `Pleasure`, `PLEASURE` and `pleasure` are the same context. Idle, Pleasure and Kiss are HZoi's current authored contexts, not engine enums. Another designer may add `tongue out` or another context without engine changes.

A node optionally declares `expressions[role]` with an expression `context`, a
named `facial_pose`, or both. Contexts select animated clips from that Zoi's chosen
expression set. A facial pose fixes only the declared joints, independently of
that set. Omitted role data releases both. Missing contexts release owned clip
playback and report a warning; a valid facial pose can still apply.

```json
"expressions": {
  "lead": {"context": "Idle"},
  "partner": {"context": "Tongue Out", "facial_pose": "designer.tongue_open"}
}
```

Pose-only instructions do not require any expression set to be installed. See
[facial pose and head attachment authoring](facial-poses.md). The retired
`open_mouth` boolean is rejected; current content names `scenezoi.open_o` explicitly.

Definition schema version 2 allows partial contributions to a set:

```json
{
  "schema_version": 2,
  "id": "designer.expressive",
  "label": "Expressive",
  "body": "female",
  "contexts": {
    "Tongue Out": {
      "hold": [3, 7],
      "transition": 0.3,
      "options": [{"animation": "/Designer/Face/Example.Example", "weight": 1}]
    }
  }
}
```

Every file requires schema_version, id, body and a contexts object (which may be empty). Body is `male` or `female`, referring to appearance mesh compatibility. Label, default and aliases are optional. Contexts require a nonempty options array; omitted hold/transition inherit other contributions or use [5,11]/0.35. Option label defaults to the asset object name and weight to 1. With no `sample`, the native facial clip advances and loops with the session expression clock, retaining its authored blinking. An explicit `sample` holds that frame, including any authored eyelid pose. Unknown fields and invalid ranges are rejected. Native game clips remain references and are not redistributed.

Files from different mods may use the same normalized set ID and add distinct contexts or additional clips to an existing context. Body and explicitly supplied label/hold/transition metadata must agree. Identical clip/sample entries deduplicate; conflicting duplicate entries are rejected. Files load in sorted declaration-filename order. Each file merges transactionally: if it conflicts, none of that file's changes apply, a diagnostic warning identifies it, and other valid definitions remain usable. Build-time validation instead rejects the invalid build. An optional explicit default is allowed per body; otherwise the first compatible ID in sorted order is used. No compatible IDs means no facial animation.

Optional `aliases` list old IDs for preference migration. HZoi declares aliases for the previous `scenezoi.*` IDs; the framework has no hardcoded family migration table. UI requests and saved version-2 IDs are hex encoded so spaces/punctuation cannot corrupt the bridge. Existing version-1 preferences are still readable. Display names do not affect saved identity.

### Discovery and authoring workflow

The native declaration transport uses JSON data patches, with declarations owned and installed by each content pack. SceneZOI reads `data.table_get_all alias=Text` and selects only rows whose IDs start with `SceneZOI_Declaration_` (case-insensitively). Each selected row's raw `Text` string contains this inert envelope:

```json
{
  "schema_version": 1,
  "kind": "expression_set",
  "owner": "designer",
  "data": {"schema_version": 2, "id": "designer.expressive", "body": "female", "contexts": {}}
}
```

This repurposes the native text table as a declaration carrier; it is not a dedicated provider extension API. Existing game rows are ignored and never overridden, and payload strings are never sent through localization. All five records have exact native ModKit and retail raw-string readback after a cold start. Retail combines the `Text_UI` file into the `Text` table alias and serializes its fields as `iD`/`text`; the reader resolves column casing. No payload is localized by SceneZOI. Additional locale and activation/removal checkpoints remain pending.

`DataFiles.lua` validates each envelope independently, groups records by case-insensitive kind, and supplies `expression_set` to `ExpressionLibrary.lua`. Scene packs, body/material/coverage profiles, voices, tasks and furniture profiles have independent consumers; enabled scene graphs are assembled at runtime. Missing/malformed records warn without terminating a session. Runtime contains no content pack IDs or filename list and never executes declaration code. Limits remain 4096 declaration rows, 1 MiB per envelope, 16 MiB for the native response, and bounded JSON depth/nodes.

Discovery runs on boot, periodically while no session is active, and immediately before session capture. Unchanged records preserve the cached snapshot. This avoids treating an early boot before another pack mounts as a permanently empty library. Active sessions retain their library until Exit. Native disable/re-enable was tested in the running game: five records became zero, then five again, with zero discovery warnings throughout. Physical uninstall on a later startup remains untested.

Add expression definitions to your pack manifest's `expression_files`. From the SceneZOI checkout, use `python tools/build_catalog.py --packs <your-pack-manifest> --project <your-native-project>` to validate and stage that owner's declarations. The generic writer preserves unrelated patch entries and records packaging ownership in `workspace/data_files.json`; runtime does not read that inventory. The patch ships through ModKit as `non_ufs/JsonPatch/Text_UI_patch.json` with native manifest membership/checksums. See [package authoring](package-split.md); no private content checkout or executable pack registration is required.

SceneZOI's default build stages its own neutral scene pack and furniture profiles; HZoi builds independently. Disabling HZoi removes its contributions and leaves ten framework declarations and five neutral nodes. Active sessions retain captured libraries. Retired shared cfg and cooked DataTable transports are excluded.

## Authoring your own sets

Use the schema example above to author your own set, referencing facial clips available to your project. The framework has no built-in families or family IDs. The [public declaration workflow](package-split.md) and [facial-pose examples](facial-poses.md) demonstrate the authoring boundary. The public [Pleasure face definition](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/expressions/pleasure_face.json) now provides the corresponding
HZoi-Reference example: `default`, body compatibility, weighted Idle/Pleasure
clips and a Kiss option with an explicit `sample`. Its
[scene instruction](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L76) selects the context and adds the
independent `scenezoi.open_o` pose. The reference is optional; its stock facial
clip paths still depend on actual game assets. See [worked examples](content-examples.md).

## Engine and lifecycle

Each participant has independent loaded options, random selection history, hold timer, selected family, owned head montages and optional partial-face overlay. The engine avoids immediately repeating an option when alternatives exist. Idle defaults use 5–11 scene seconds with a 0.35-second transition; Pleasure uses 2.4–7 and 0.25. Families can author different values.

Timers use the existing shared session clock, respecting game pause, game speed and the selected scene speed. Native montage blend duration is adjusted by selected scene speed at selection time. A speed change during an already-running native blend is not retroactively retimed. The initial version blends complete facial poses; independently composable facial regions and random strength ranges are not claimed.

The native adapter installs and samples its own head montage on the existing game-owned head animation instance. Automatic end fading is disabled on that owned transient montage, so looping near the clip's end does not expose the native mood expression. Deliberate expression transitions still blend, and Exit stops the owned playback. The separate native mood-cache blend is also suppressed while a full expression clip is owned; disabling montage end fading alone does not suppress it. Each actual head instance retains its latest observed native blend weight for restoration after its owned playback retires or on Exit. Later nonzero game/foreign writes are preserved, and blend restoration retries independently of montage cleanup. Named additive poses alone do not claim this full-expression blend. See the [mood-blend checkpoint](validation/facial-mood-20261105.json). It never replaces animation instances, changes native eye/blink settings or edits face-customization data. Outgoing facial poses are held during node preparation. Appearance replacement rebinds to the current head and retires playback on its actual previous owner. Outgoing leases remain owned through their native blend deadline, measured with paused/dilated game time; only completed, inactive leases or positively invalid native instances are pruned. A failed native query retains ownership for cleanup retries. Exit retries only remaining owned playback/overlay cleanup. Native and visual results for current content are recorded in [release validation](validation/README.md); new clips and customized heads require their own acceptance.

An unavailable native expression asset, a failed native load or an asset of the wrong type is skipped. If none can load for a selected context, the scene continues, the personality panel reports the problem and the engine retries at bounded intervals. The ModKit's separate inspection commandlet could not load these native game assets, so references alone do not establish playback.

Named facial poses use owned additive corrections on the existing head
post-process instance. `FacialPoseTargets.lua` validates declared bone names and
parents against each current head, then resolves parent-local transforms before
activation. No reference animation, visible calibration or compiled pose-data
module is needed. Enabled packs supply inert `facial_pose` declarations through
their own native JSON patches. The accepted rounded O coordinates remain in
`packs/scenezoi/facial_poses/open_o.json`; this is the same path available to authors.

Only listed joints are fixed. Other joints retain their native/expression motion.
A pose owning either eyeball joint temporarily releases procedural gaze for that
participant; gaze resumes after those fixed entries are released. Ordinary mouth
poses retain gaze and blinking. Explicit eyelid poses deliberately fix eyelids.
Changing pose ID removes the preceding footprint, including joints omitted by
the new pose. Missing/incompatible poses release the old footprint and report
`facial_pose_error` without blocking playback.

Per-frame corrections subtract their preceding contribution before solving the
target. Ownership handles foreign entries, copied/rebuilt heads and cleanup
retries independently for each participant. Active heads use full detail and
always tick; previous LOD/tick settings return on release. Definitions are captured
with the session libraries. No fixed coordinates are retargeted to arbitrary face
proportions; customized heads and new poses require visual review. The accepted
female O target is preserved, with male/customized proportions still separately
subject to review. The unused reference helper and mouth-specific build path
have been removed.

## Personality panel and persistence

The supplied person icon replaces the eye placeholder immediately right of the shirt button. Outfit and personality modes share the established attached panel geometry and participant selector; opening either replaces the other. The personality mode lists the discovered compatible expression families. HZoi currently contributes four female and one male set; an empty compatible library disables the selector and explains that no sets are installed. Absolute requests have separate counters, session identity and node revision checks. Exit closes the panel and discards retries; requests arriving after stopping begins cannot persist changes. The UI rejects older acknowledgements and incompatible-body options, and serializes outfit edits with personality saves. Saving succeeds before the live preference is changed.

Body compatibility first examines the actual Head/body skeletal mesh asset name. Anonymous generated/merged assets fall back to the session's B2-validated appearance-body binding. Biological gender and controlled/NPC status are not used.

The supported `uimod.cfg_save` API writes preferences to the game's cfg directory,
which can be separate from the installed package. On the tested retail build:

```text
Documents/inZOI/Mods/InGame/SceneZOI_93C44199/scenezoi_personality/zoi_<native-entity-id>.cfg
```

The small versioned record contains the expression-set ID. It is independent of save serialization, participant role, node and roster position. The same native Zoi ID retains its preference across sessions and save loads. Newly created/copied characters with different IDs have different profiles; ID reuse across independent worlds is not distinguished by an additional world key in this first iteration. Invalid/missing/incompatible set IDs fall back to an installed body default, or no selection if none exists.

Removing a package from `Mods/SceneZOI_93C44199/` does not necessarily remove its
separate cfg data. Updates/installers must preserve the personality directory;
preferences are not included in packages. Voice selection is independent in the
same panel; see [voices](voices.md). Both preference directories must survive
updates. See [storage locations](settings.md#storage-location) before backing up,
uninstalling or resetting a development installation.

## Verification boundary

Isolated checks cover three independent roles with repeated bodies, persistent preferences, malformed/missing content, failed storage, stale/duplicate commands, paused shared time, head replacement, foreign overlays, cleanup retries, exclusive panels and UI selection. Existing group, outfits, attachment, gaze and lifecycle suites remain passing. ModKit analysis and payload/hash verification are recorded in `validation.json`. These do not substitute for author visual acceptance or native runtime playback verification.


## Current authored use and retained evidence

The framework hubs use Idle expressions without a mouth override. HZoi enables the female fixed O only in hzoi.male_standing_female_kneeling_fellatio. Kiss remains available as an explicitly sampled pose in content. Ordinary unsampled clips now advance/loop with authored blink motion; this is distinct from a guaranteed visible blink in every explicit pose.

The author accepted the refined female O, reference-free activation, continuous gaze handoff, dropdown interaction and tested family switching/Exit. Other customized heads, new authored poses and male O proportions retain separate visual-review limits. Retired curve-map/reference-sampler experiments must not be restored. Ownership/native tombstone and quaternion-round-trip regressions are summarized in the [issue ledger](investigations/runtime-and-ui-issues.md).
