# First-release validation

The maintainer declared SceneZOI and HZoi ready for player release on **2026-11-04**.
This page summarizes recorded evidence; it does not announce publication. The
2026-11-05 visual bug fixes are installed by hot update; the author reported all
three bugs fixed after the requested joint checks. A later Japanese/Chinese
button-font correction is installed and the author confirmed the requested
Japanese and both Chinese glyph checks are working. Earlier visual acceptance
and accepted volume controls remain recorded separately.

| Area | Last recorded result |
| --- | --- |
| Runtime | `20261105-visual-fixes-1`; native-message API version 1; hot activation/readiness and requested author visual checks passed |
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
have isolated regression coverage. Local-UI-wide bubble suppression, fixed session
membership and the one-session limit are intentional first-release boundaries.

Earlier dated statements of "pending" in retained investigation notes apply to
those checkpoints; current acceptance above supersedes them where it covers the
same behavior. Exact variant coverage must not be invented. Raw development logs,
personal paths and detailed old checkpoints are retained privately, rather than
being contributor inputs. The original HZoi production checkout remains private;
its separate public [muted reference](../content-examples.md) now supplies authoring
examples. Historical audible acceptance concerns the original pack, not silent
replacement samples. Framework-only checks remain independent.
