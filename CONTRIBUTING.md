# Contributing to SceneZOI

SceneZOI welcomes reproducible bug reports, authoring/API feedback, documentation
improvements and focused runtime fixes. Start with [developer setup](docs/installation.md)
and the [documentation index](docs/README.md).

## Reports and proposals

Search existing issues before opening a new one. Use the bug-report template for
runtime, build, authoring or documentation failures; use the feature/API template
to explain a concrete mod-author use case and the current obstacle.

For bugs, include the build or commit, relevant game/ModKit versions, enabled
packs/add-ons, exact steps, expected behavior and actual behavior. Add focused
diagnostics or a minimal JSON/Lua example where available. State whether evidence
comes from an isolated test, native readback or something seen/heard in game.

Larger proposals should be discussed before implementation. SceneZOI
currently supports one controlled-initiator session with fixed participants.
Concurrent sessions, autonomous NPC starts and predetermined watch-only
sequences are deferred.

## Keep ownership clear

- SceneZOI owns reusable playback, participants, presentation, lifecycle and UI.
- Content packs own animations, attachments, audio and inert JSON declarations.
- Gameplay add-ons own availability decisions, persistence, rewards and consequences.

Keep content-pack-specific IDs, assets and runtime branches out of the framework.
Independent add-ons use the public native-message API and SDK. Preserve native
animation instances, input restoration, session snapshots, per-owner cleanup and
technical eligibility checks. Smart Zoi toggling must not be introduced.

Use [the worked content-pack examples](docs/content-examples.md) when a concrete
declaration helps explain a change. HZoi-Reference is an optional adult-content
reference with silent audio and separate rights; do not import its assets into
the framework or make default checks depend on its checkout. Link the exact
source field/revision and identify excerpts rather than presenting fragments as
complete playable scenes.

Preserve released API and schema contracts unless a breaking change is agreed.
Document migration for any agreed break. Remove obsolete internal paths that no
longer serve a supported contract. Update the relevant docs, examples and checks.

## Validate the change

For runtime or declarative-data changes, run the applicable source checks:

```powershell
python tools/build_catalog.py
python tools/test.py --modkit-root "C:/Path/To/inZOIModKit"
```

Then follow [native validation and packaging](docs/development.md) for the changed
subsystem. Keep packages filtered to their exact owned payload; never include
referenced Game/Engine assets, machine-specific inputs or generated build output
in a source contribution. Preserve user settings and preferences during local tests.

Bug fixes should include meaningful regression coverage where practical. For a
documentation-only change, check local links, examples and formatting; a native
rebuild is unnecessary. Do not claim unperformed checks or infer visual acceptance
from source/native diagnostics.

## Pull requests

Keep the change focused. Describe the original problem, resulting behavior, linked
issue, validation actually performed and any remaining limits. The pull request
template provides those prompts. For an API change, include how another mod
author would use it and update the public reference.

Preserve licensing and attribution. Contributions are made under the repository's
[GPL-3.0-only license](LICENSE), and work created through the ModKit is also subject
to its applicable terms and the [inZOI Mods Policy](https://playinzoi.com/en/clause/mods_policy).
