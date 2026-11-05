# First-release validation

The maintainer declared SceneZOI and HZoi ready for player release on **2026-11-04**.
This page summarizes recorded evidence; it does not announce publication or claim
new tests were performed during the final documentation review.

| Area | Last recorded result |
| --- | --- |
| Runtime | `20261104-facial-1`; native-message API version 1 |
| Automated checks | 49 framework Python tests, 32 optional private-content Python tests, 52 Lua suites with that content, seven UI suites; passed |
| ModKit validation | Lua and UI: zero errors and warnings |
| Native discovery | Nine framework declarations; 42 with the private integration pack, zero discovery warnings on the recorded cold start |
| Packaging | Isolated native builds, exact filtering and matching installed hashes; four framework-owned asset packages |
| Latest joint pass | Author accepted unchanged O, expression/outfit edits, speed/pause, navigation, Exit/re-entry and bed behavior |
| Final native state | `idle/ok`, captured participant settings restored and autosave restored |
| Independent add-ons | Registered separate native SDK clients and declarations loaded automatically; final API-5 suite passed 95 assertions/checked responses |

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
being contributor inputs. HZoi remains private; framework-only checks are independent.
