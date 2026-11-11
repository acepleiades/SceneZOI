# SceneZOI

A modular, data-driven animation framework for **inZOI**, built for mod authors.

SceneZOI provides the runtime for synchronized scenes: participants, placement,
playback, presentation, navigation and cleanup. Content packs describe animations
through JSON. Independent Lua add-ons decide when to start scenes and how they
affect gameplay.

This repository contains the framework source, SDK, authoring tools and developer
documentation. Start with [developer setup](docs/installation.md) to work on the
framework or build a fork in the inZOI ModKit.

## Player downloads

Ready-to-install SceneZOI packages and player installation
instructions are available in the [public release post on Patreon](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155).
The optional adult animation pack **HZoi** is also available there. Both downloads
are free; no Patreon subscription is required.

## What you can build

| Your project | SceneZOI provides | Start here |
| --- | --- | --- |
| Animation or scene pack | Declarative scenes, named roles, shared metadata and optional presentation systems | [Content authoring](docs/authoring.md) and [package structure](docs/package-split.md) |
| Gameplay integration | Scene queries, filtered starts, session restrictions, events and results | [Add-on authoring](docs/addon-authoring.md), [API](docs/addons.md) and [SDK](sdk/README.md) |
| Scene enhancement | Temporary expression, voice, outfit, attachment, speed and task controls with independent ownership | [Add-on controls](docs/addon-controls.md) |

For example, an integration can find affectionate scenes, choose a compatible
match randomly and restrict navigation to GENERAL-rated content for the entire
session. Another add-on can observe a manually started scene, apply a temporary
effect and release its own changes when finished.

## Capabilities

- **Synchronized playback.** Body and skeletal-attachment tracks share one scene
  clock, including pause, speed changes and transitions. Playback preserves the
  game's animation instances.
- **Explicit participant roles.** Roles are independent of body type and player
  control. Runtime systems support two or more participants, repeated body types
  and independently owned resources.
- **Declarative presentation.** Scenes can select animated expressions, partial
  facial poses, gaze targets, spatial voices and SFX, outfits and animated props.
  Attachments can bind to body or head bones.
- **Localized controls and content.** Player-facing text supports the game's 15
  languages. Content packs contribute translated labels as inert JSON, with
  per-entry English fallback. See [localization](docs/localization.md).
- **Navigation and progression.** Authored navigation, transition nodes, numerical
  scene tasks, completion routes and optional visual/audio responses work through
  the same session lifetime.
- **Furniture support.** Profiles describe supported furniture, scene alignment
  and availability. Entry and cleanup coordinate occupancy reservations.
- **Owned state and cleanup.** Original outfits and participant settings are
  captured for restoration. Optional engines and add-on effects retain their own
  cleanup work for retry. Save recovery and autosave ownership are part of the
  framework.

Enabled content packages contribute inert JSON through their own native data
patches. Authors create one scene per JSON file; builds collect scene directories
automatically. Discovery has no hardcoded author list and content packs need no
executable registration code.

[Tags and directed actions](docs/scene-metadata.md) provide a shared vocabulary
with aliases and support both scene-wide and role-specific descriptions. Actions
identify actor, target and performer roles. Their definitions carry GENERAL,
SUGGESTIVE or EXPLICIT ratings, from which scene ratings are derived. Authors can
contribute namespaced dictionaries and inert add-on metadata.

SceneZOI is an all-ages framework. Its runtime contains no adult geometry or
content-pack-specific behavior. The public [HZoi-Reference](https://github.com/acepleiades/HZoi-Reference) provides a
separate adult-content authoring example with proprietary audio replaced by
silence. It is reference-only, has no repository-wide license and is optional.
See the [worked examples](docs/content-examples.md) for source links and explanations,
or begin with the all-ages [neutral scene sources](packs/scenezoi/scenes/).
SceneZOI builds and runs independently of either HZoi repository.

## Current scope and limits

- **Concurrent sessions.** Scenes can run side by side, and add-ons can start
  scenes for NPCs or autonomous scenes driven by a plan. NPC-only scenes are capped
  at two. See [concurrent and background sessions](docs/addons.md#concurrent-and-background-sessions).
- **Fixed membership.** Participants and role assignments remain fixed until Exit.
  The manual picker permits two or three total Zois; larger rosters require an
  integration and compatible authored content.
- **Small bundled library.** Neutral standing, single-bed and queen-bed hubs use
  adult-compatible male/female appearance roles. Broader roster support depends
  on the scene data supplied by content authors.
- **Direct manual entry.** Start SceneZOI remains available on the controlled Zoi
  and supported furniture. Relationship and progression rules belong to gameplay
  integrations; technical eligibility, compatibility and availability checks remain.
- **Interrupted gameplay tasks.** Scene entry cancels participants' queued
  interactions and temporarily disables autonomy. Exit restores original autonomy;
  cancelled interactions and departed gameplay groups are not reconstructed.
- **Navigation-based sessions.** Predetermined watch-only animation sequences are
  deferred. Ordinary authored transition nodes are supported.
- **Presentation boundaries.** Speech bubbles and thought icons from game scripts
  are withheld for Zois in a session, and everyone else keeps theirs. Custom facial
  poses, meshes and furniture models need their own visual fit checks.

The [validation report](validation.json) distinguishes automated checks, native
diagnostic evidence and author visual acceptance. The [runtime contracts](docs/tier1-contracts.md)
describe ownership and lifecycle guarantees in more detail.

## Content and development

If you're making an animation pack, I recommend using an AI agent to speed up
ModKit imports, scene setup and packaging. I still review how the animation
looks in-game myself. Start with the
[agent handoff](docs/authoring.md#hand-an-animation-pack-to-an-ai-agent).

From the repository root, validate and stage the framework declarations, then run
the source checks using your ModKit installation:

```powershell
$modkitRoot = "C:/Path/To/inZOIModKit"
python tools/build_catalog.py
python tools/test.py --modkit-root $modkitRoot
```

See [developer setup](docs/installation.md) for prerequisites and native asset
inputs, and [development and packaging](docs/development.md) for ModKit validation
and exact owned-payload filtering.

| Path | Purpose |
| --- | --- |
| `modkit/SceneZOI_93C44199/workspace/lua/` | Authoritative B1/B2 runtime sources and native bindings |
| `modkit/SceneZOI_93C44199/ui/` | Framework controls and manual starter |
| `packs/` | Neutral scenes, metadata dictionaries, furniture profiles and facial poses |
| `sdk/` | Public native-message client for independent Lua add-ons |
| `tools/`, `tests/` | Build, import, validation and regression tools |
| `asset-inventory.json`, `imports.json`, `animation-inventory.json` | Framework asset membership and import provenance |
| `docs/`, `validation.json` | Contracts, authoring guides and verification evidence |

Use the [documentation index](docs/README.md) to find individual subsystems.
Contributions should keep reusable runtime behavior in SceneZOI and content assets
and gameplay decisions in their respective projects. See [contributing](CONTRIBUTING.md)
for bug reports, proposals and pull requests.

## Release status and licensing

SceneZOI is publicly available. The player packages for SceneZOI and HZoi are
linked under [Player downloads](#player-downloads). Recorded checks, known limits
and author acceptance are summarized in [validation](docs/validation/README.md)
and [validation.json](validation.json). Source checks alone do not establish
rendered or audible behavior. The native-message API has a
documented version-1 contract. Internal modules and UI mailboxes are implementation
details; scene and declaration schemas have their own documented contracts.

SceneZOI is licensed under the **GNU General Public License, version 3 only
(GPL-3.0-only)**. See [LICENSE](LICENSE). Distributed forks must comply with GPLv3,
including its applicable source-code and notice requirements.

**ModKit terms:** Mods created through the inZOI ModKit must also comply with
KRAFTON's [inZOI Mods Policy](https://playinzoi.com/en/clause/mods_policy) and
applicable ModKit terms of use. Forks must comply with both SceneZOI's license and
the applicable ModKit terms. These third-party terms are separate from GPLv3.
