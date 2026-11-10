# Release validation

SceneZOI and HZoi are publicly available. See the [player downloads](../../README.md#player-downloads)
for the installable packages and the [validation report](../../validation.json) for
current checks and known limits.

## Versioned update (SceneZOI 1.1.3)

Version 1.1.3 fixes a recycled furniture menu row that could hide regular
interactions such as Assign Bed. The exact player ZIP passed a clean install,
fresh launch, object-menu checks, and bed scene Start and Exit. HZoi 1.1.0
remains compatible. The reported apartment scenario still awaits independent
retest. See the [release checkpoint](release-1.1.3-20261107.json).

## Versioned update: SceneZOI 1.1.2

Version 1.1.2 bounds native modal-state reads, rejects expired/old-session
replies and records panel/input diagnostics. It also defers gameplay focus while
Create a Zoi or a modal UI owns input and adds an explicit editor-exit fallback.
Pre-fix regressions reproduce permanent modal gating after a lost reply and
unsafe focus restoration during customization. Full source checks, native Lua/UI
validation, isolated packaging and the owned-payload filter pass. The accepted candidate was hot-installed with loaded cooked bytes and settings
preserved; see its [runtime checkpoint](ui-lifecycle-20261106.json). Exact ZIP
acceptance is recorded in the [release checkpoint](release-1.1.2-20261106.json).

The local baseline already exited through the save guard on CAZ entry and
allowed a second session. The customer's exact dark-panel/position-jump trigger
has not been reproduced, so these changes are hardening rather than proof of
that report's complete cause. The published 1.1.1 archives are unchanged.

## Versioned update: SceneZOI 1.1.1

Version 1.1.1 packages the accepted script-mod group-binding fix below. HZoi
remains at 1.1.0. Runtime, UI and declarations retain the tested implementation;
only the release descriptor changes. See the
[release checkpoint](release-1.1.1-20261106.json) for exact archive acceptance.
The exact ZIP passed clean-directory/fresh-process picker/playback/Exit with
the installed script mods enabled; final persisted cleanup is ok/ok and autosave
is released. No selection error was retained.

## Script-mod coexistence follow-up

A locally reproduced missing-picker failure comes from native exact-group
bindings shadowing SceneZOI's wildcard-only character callbacks. The full-group
manifest fix passes regressions and native validation; the targeted household
change passed an author playback check with the installed script mods enabled.
The protected full-group update also passed the author's fresh-launch check;
persisted final Exit/cleanup is ok/ok and autosave is released.
See the [binding checkpoint](script-mod-bindings-20261106.json) for installation
and fresh-process acceptance status. Published 1.1.0 archives are unchanged.

## Versioned update: 1.1.0

SceneZOI and HZoi are versioned together as 1.1.0 for generic automatic handling
of section-preserving body replacements. The body-region implementation retains the accepted
`20261105-body-layout-2` tests. The initial versioned clean-install test exposed
a separate native mood blend competing with facial expressions. The
`20261105-face-mood-2` follow-up preserves blinking and adds scoped blend
ownership/restoration; see the [facial checkpoint](facial-mood-20261105.json). Native owned-payload packaging and final
exact-ZIP acceptance are recorded in [the release checkpoint](release-1.1.0-20261105.json).
Both player packages must be updated together for body-profile schema 2. The final exact ZIPs passed fresh-directory/fresh-process startup and the author's facial/blink, outfit, navigation and Exit check. Persisted final Exit/cleanup
was ok/ok, autosave released and no retained error was present.

## Fresh-install correction: SceneZOI 1.0.1

A clean installation of the published 1.0 ZIP reproduced missing Start entries.
An absent request mailbox rejected the controls handshake, and prematurely cached
host identity prevented retry. Existing developer configuration masked it. The
1.0.1 initialization/retry fix passes source checks and native Lua/UI validation;
isolated packaging, exact owned-payload filtering and clean ZIP installation passed.
The exact ZIP then passed automatic startup from a fresh directory, matched the
host/controls generation and reached playback. The author confirmed it works;
final native Exit/cleanup was idle/ok with no retained error. HZoi 1.0 is unchanged. See the [checkpoint](fresh-install-startup-20261105.json).

## Actor-registration correction: 1.0.2 candidate

A real-callback regression reproduced old-object cleanup erasing a replacement
registered under the same Zoi ID. The fix removes only the ending actor's own
entry and preserves actual participant-unload cleanup. Framework/content checks,
native Lua/UI validation, packaging and update installation passed. The author
confirmed normal Start/Exit after a fresh process launch; native final state was
idle/ok with no retained error. This was an update test preserving preferences;
a separate 1.0.2 clean-directory test has not been performed.

The customer's 1.0.2 diagnostic still fails and now proves that actor callbacks
reach the runtime. Its registry contains invalid ID `-1`, with no entry or numeric
equivalent for the controlled Zoi; non-owner cleanup count is zero. It does not
prove which actor originally registered as `-1`. See [the 1.0.2 checkpoint](actor-registration-20261105.json).

## Deferred native identity: 1.0.3 candidate

Registration previously accepted an unassigned native ID and never retried.
The new real-callback regression reproduces multiple actors overwriting `-1`.
The fix waits for a valid ID, stops retrying after registration and retains that
ID for cleanup if native teardown resets it. Bounded failure diagnostics now
include registered/current actor identities. Full framework/content checks and
native Lua/UI validation, isolated owned-payload packaging and exact-ZIP update
installation pass. Settings and HZoi are preserved. The author accepted normal
Start/playback/Exit after a fresh launch; final native state is idle/ok, cleanup
is ok/ok, no retained error and the autosave lease is released. This was an update
test; a clean-directory 1.0.3 test remains unperformed. The customer's subsequent
1.0.3 test still fails: 6,661 invalid-ID attempts, 15 correctly indexed actors and
no controlled registration. A brief identity-assignment delay is insufficient to
explain that result. Native character-map comparison is the next investigation. See [the checkpoint](deferred-registration-20261105.json).

## Customer navigation follow-up

The customer reports that reducing enabled mods allows picker/standing idle entry.
The new session exits during rear-node preparation with `Configured region
material slot is unavailable`: the declared male body slot does not resolve to
its required index. This is distinct from the retained earlier registration
error. No specific mod or persistent-versus-transient layout cause is established;
repeat with only the current two packages before another runtime candidate.
See [the body-layout checkpoint](customer-body-layout-20261105.json).

## Stock/replacement body-layout correction

Removing Supponpon reproduces the body-region failure locally. The content profile
mistook its renamed slot for the stock layout. SceneZOI 1.0.4 adds shared matching
for explicit compatible layouts; HZoi 1.0.1 uses stock naming by default and declares
measured replacements. Full regressions, native validation, isolated packaging
and exact-ZIP update installation pass with settings preserved. Joint
stock/ZoiBits/Supponpon playback, outfit-mask and Exit checks passed after
separate fresh launches, with author acceptance and native idle/ok, cleanup
ok/ok and released autosave leases. Customer retest and clean-directory acceptance
remain pending. Both packages must be updated for this correction. See [the checkpoint](body-layout-fix-20261105.json).

## Generic section-preserving bodies

The next development revision (`20261105-body-layout-2`) replaces name-based
layout lists with body-profile schema 2. Current section resources govern
preparation and both masking guards; unlisted names and different total material
counts work when the declared region mapping is preserved. HZoi keeps section 17
in its data. Old profile fields/matching code are removed. Full checks, native validation, both isolated builds and filtered development
installation pass with settings preserved. The author accepted renewed stock,
Supponpon and ZoiBits playback/outfit/Exit checks. Native final snapshots confirm
Supponpon and ZoiBits idle/ok and cleanup ok/ok; stock has author acceptance
without a separate new native snapshot. No new player ZIP or clean-directory
acceptance is claimed; the earlier three configuration tests
above apply to the previous revision. See [the current checkpoint](generic-body-region-20261105.json).

## Earlier release evidence

The maintainer declared SceneZOI and HZoi ready for player release on **2026-11-04**.
This page summarizes recorded evidence; it does not announce publication. The
2026-11-05 visual bug fixes are installed by hot update; the author reported all
three bugs fixed after the requested joint checks. A later Japanese/Chinese
button-font correction is installed and the author confirmed the requested
Japanese and both Chinese glyph checks are working. Earlier visual acceptance
and accepted volume controls remain recorded separately.

| Area | Last recorded result |
| --- | --- |
| Runtime | `20261105-startup-1`, UI `20261105-startup-ui-1`; 1.0.1 clean installation/automatic startup and final Exit passed, with author confirmation |
| Automated checks | 53 framework Python tests, 32 optional private-content Python tests, 56 Lua suites with that content, nine UI suites; passed on 2026-11-05 |
| ModKit validation | Lua and UI: zero errors and warnings |
| Audio controls | Three persistent 0–200% channels; native multiplier readback includes 2.0; author reported controls working as expected |
| New task controls | Separate persistent female/male 10–500% progress; regression checks passed, joint in-game acceptance pending |
| Native discovery | Ten framework declarations; 44 with the private integration pack, zero discovery warnings on the recorded cold start |
| Localization | 15 retail language refreshes and text-entry checks passed. Later Japanese/Chinese screenshots exposed missing button glyphs; the corrected font stack passed the requested author visual checks. |
| CJK font follow-up | UI `20261105-cjk-fonts-ui-1`; full native font stack restored on navigation/Exit/restore, two focused UI suites and ModKit validation passed; author glyph checks accepted; final Exit/cleanup `ok/ok` |
| Packaging | Isolated native builds, exact filtering and matching installed hashes; four framework-owned asset packages |
| Latest joint pass | Author accepted unchanged O, expression/outfit edits, speed/pause, navigation, Exit/re-entry and bed behavior |
| Native state | Joint test ended `idle/ok` with matching Exit/cleanup `ok/ok` and no new retained error. Earlier captured participant/autosave restoration evidence remains in its checkpoint. |
| Independent add-ons | Registered separate native SDK clients and declarations loaded automatically; final API-5 suite passed 95 assertions/checked responses |

The [visual-fix checkpoint](visual-fixes-20261105.json) records the facial end-fade,
covered body-region and settings-hint regressions, verified hot installation and
author acceptance and final clean Exit.

The [CJK font checkpoint](cjk-fonts-20261105.json) records the later missing-glyph
defect, targeted fix, author glyph acceptance and final clean Exit.

The [localization checkpoint](localization-20261105.json) records the
culture sweep, source/native checks and focused author visual acceptance.

The [task-settings checkpoint](task-settings-20261105.json) records current
source/native/package evidence and the remaining joint checks. The
[audio-settings checkpoint](audio-settings-20261105.json) retains the prior
volume candidate and author acceptance.

Read the [current machine-readable report](../../validation.json) for the limits,
[API findings](addon-api-20261104.md) for failed approaches and verified integration
behavior, and [subsystem review](subsystem-review-20261104.md) for the final runtime
changes. The [facial/playback checkpoint](facial-poses-20261104.json) keeps native
readback and author acceptance separate.

## How to interpret the evidence

- Automated regressions check isolated behavior and failure handling.
- Native diagnostics establish the recorded engine/API/state observations.
- Author visual/audible acceptance establishes the tested presentation and use.
- Readiness is the maintainer's release decision; it does not certify every head,
  furniture variant, third-party mod, future asset or possible save/load combination.

The female O is accepted. New facial poses and an actual head-attached tongue mesh
still need their own fit tests. Head-parent replacement and generic eye-pose handoff
have isolated regression coverage. Fixed session membership remains a current
boundary, and only script-made bubbles are withheld for participants.

Earlier dated statements of "pending" in retained investigation notes apply to
those checkpoints; current acceptance above supersedes them where it covers the
same behavior. Exact variant coverage must not be invented. Raw development logs,
personal paths and detailed old checkpoints are retained privately, rather than
being contributor inputs. The original HZoi production checkout remains private;
its separate public [muted reference](../content-examples.md) now supplies authoring
examples. Historical audible acceptance concerns the original pack, not silent
replacement samples. Framework-only checks remain independent.
