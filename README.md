# SceneZOI

A modular, data-driven animation framework for **inZOI**, built for mod authors.

SceneZOI provides the runtime for synchronized scenes: participants, placement, playback, presentation, navigation and cleanup. Content packs describe animations through JSON. Independent Lua add-ons decide when to start scenes and how they affect gameplay.

This repository contains the framework source, SDK, authoring tools and developer documentation. Start with [developer setup](docs/installation.md) to work on the framework or build a fork in the inZOI ModKit.

## Support the Developers

SceneZOI is free and open source, developed with contributions from multiple authors. If you enjoy the framework and want to support its continued development, you can support its developers individually.

### acenetizen (acepleiades) — Maintainer and Lead SceneZOI Developer

Repository maintainer and primary developer of SceneZOI and author of HZoi.

[![Become a patron](assets/presentation/Patreon-PNG-Picture.png)](https://www.patreon.com/skyrimaceanimations)

### SephirothValentine — Contributor and VelvetZOI Developer

SceneZOI contributor responsible for implementing concurrent multi-scene support. Also the creator of **VelvetZOI**, a comprehensive gameplay mod for inZOI that builds upon SceneZOI to integrate adult interactions and gameplay systems.

[![Become a patron](assets/presentation/Patreon-PNG-Picture.png)](https://www.patreon.com/cw/VelvetZOI)

## Player downloads

**[Download SceneZOI — Latest Release](https://github.com/acepleiades/SceneZOI/releases/latest)**

Ready-to-install SceneZOI packages are distributed through [GitHub Releases](https://github.com/acepleiades/SceneZOI/releases). Each release includes the downloadable mod package, installation instructions and release notes.

SceneZOI is free and works independently of other mods.

The optional adult animation pack **HZoi** is available separately through the [public SceneZOI & HZoi Patreon post](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155). Both SceneZOI and HZoi are free; no Patreon subscription is required.

### Installation and how to use

1. **Download:** Get the latest SceneZOI ZIP from [GitHub Releases](https://github.com/acepleiades/SceneZOI/releases/latest). The optional **HZoi** content pack is available in the attachments of the [public Patreon post](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155).

2. **Install:** Close inZOI and extract the ZIP files into `Documents\inZOI\Mods`. The resulting folders should be `SceneZOI_93C44199` and, if installing HZoi, `HZoi_660649D8`, each containing `mod_manifest.json` directly inside. Replace the previous folders when updating.

3. **Enable:** Enable SceneZOI and, if installed, HZoi in the game's mod management menu.

4. **Play:** Load your save and select **Solo SceneZOI session** below **AI Emote** on your controlled Zoi. This starts a solo scene and gives you access to Scene Settings. If you reached this point, **SceneZOI is working on your mod list**. *You can press Exit now, or continue reading if you're not using SceneZOI gameplay mods.*

5. **If you're not using SceneZOI gameplay mods**, enable **SceneZOI manual start** under **Debug** in Scene Settings (the **cog icon**). This allows you to click your controlled Zoi and supported furniture to bring up a manual picker for starting SceneZOI sessions manually.

6. **Gameplay mods**, such as VelvetZOI (on [Nexus Mods](https://www.nexusmods.com/inzoi/mods/1804) and [Patreon](https://www.patreon.com/VelvetZOI/posts/velvetzoi-public-174762693)), can start scenes through gameplay using SceneZOI's public API.

Please report any errors or unexpected behavior, including what you were doing when the problem occurred.

**Do not download the repository's source code ZIP to install SceneZOI.** Use the packaged files from GitHub Releases.

## What you can build

| Your project | SceneZOI provides | Start here |
| --- | --- | --- |
| Animation or scene pack | Declarative scenes, named roles, shared metadata and optional presentation systems | [Content authoring](docs/authoring.md) and [package structure](docs/package-split.md) |
| Gameplay integration | Scene queries, filtered starts, concurrent and autonomous sessions, restrictions, events and results | [Add-on authoring](docs/addon-authoring.md), [API](docs/addons.md) and [SDK](sdk/README.md) |
| Scene enhancement | Temporary expression, voice, outfit, attachment, speed and task controls with independent ownership | [Add-on controls](docs/addon-controls.md) |

For example, an integration can find affectionate scenes, choose a compatible match randomly and restrict navigation to GENERAL-rated content for the entire session. Another add-on can observe a manually started scene, apply a temporary effect and release its own changes when finished.

Gameplay add-ons can also create background or autonomous scenes involving NPCs, with navigation controlled by task goals, stages, restrictions and end policies.

## Capabilities

- **Synchronized playback.** Body and skeletal-attachment tracks share one scene clock, including pause, speed changes and transitions. Playback preserves the game's animation instances.
- **Concurrent sessions.** Multiple scenes can run independently, each with its own participants, playback state, tasks and cleanup. Gameplay add-ons can initiate background and autonomous sessions.
- **Explicit participant roles.** Roles are independent of body type and player control. Runtime systems support solo and multi-Zoi rosters, repeated body types and independently owned resources.
- **Declarative presentation.** Scenes can select animated expressions, partial facial poses, gaze targets, spatial voices and SFX, outfits and animated props. Attachments can bind to body or head bones.
- **Localized controls and content.** Player-facing text supports the game's 15 languages. Content packs contribute translated labels as inert JSON, with per-entry English fallback. See [localization](docs/localization.md).
- **Navigation and progression.** Authored navigation, transition nodes, numerical scene tasks, completion routes and optional visual/audio responses work through the same session lifetime.
- **Furniture support.** Profiles describe supported furniture, scene alignment and availability. Entry and cleanup coordinate occupancy reservations.
- **Public add-on API.** Independent Lua add-ons can discover compatible scenes, start sessions, control navigation, observe events and manage temporary scene behavior without depending on framework internals.
- **Owned state and cleanup.** Original outfits and participant settings are captured for restoration. Optional engines and add-on effects retain their own cleanup work for retry. Save recovery and autosave ownership are part of the framework.

Enabled content packages contribute inert JSON through their own native data patches. Authors create one scene per JSON file; builds collect scene directories automatically. Discovery has no hardcoded author list and content packs need no executable registration code.

[Tags and directed actions](docs/scene-metadata.md) provide a shared vocabulary with aliases and support both scene-wide and role-specific descriptions. Actions identify actor, target and performer roles. Their definitions carry GENERAL, SUGGESTIVE or EXPLICIT ratings, from which scene ratings are derived. Authors can contribute namespaced dictionaries and inert add-on metadata.

SceneZOI is an all-ages framework. Its runtime contains no adult geometry or content-pack-specific behavior. The public [HZoi-Reference](https://github.com/acepleiades/HZoi-Reference) provides a separate adult-content authoring example with proprietary audio replaced by silence. It is reference-only, has no repository-wide license and is optional.

See the [worked examples](docs/content-examples.md) for source links and explanations, or begin with the all-ages [neutral scene sources](packs/scenezoi/scenes/).

SceneZOI builds and runs independently of either HZoi repository.

## Current scope and limits

- **Concurrent sessions.** Scenes can run side by side, and add-ons can start background or autonomous scenes. Autonomous plans can drive navigation using task goals, stages, restrictions and end policies. Up to 15 NPC-only sessions can run alongside household sessions. The panel and autosave suspension follow the controlled Zoi's session. A save requests Exit for every active session. See [concurrent and background sessions](docs/addons.md#concurrent-and-background-sessions).
- **Fixed membership.** Participants and role assignments remain fixed until Exit. The manual picker supports one to three Zois with compatible content. The player can unselect the controlled Zoi to start a scene between the selected Zois. Larger rosters require an integration and compatible authored content.
- **Bundled scenes.** Two solo standing hubs use stock idle clips. The paired standing, single-bed and queen-bed hubs use adult-compatible male/female appearance roles. Packs can contribute starting scenes for other rosters.
- **Solo entry and debug starts.** Choose **Solo SceneZOI session** below **AI Emote** on the controlled Zoi to start a solo scene and reach Scene Settings. Enable **SceneZOI manual start** under **Debug** to use the native picker on the controlled Zoi or any supported available furniture. Debug starts default to off.
- **Manual session cleanup.** Manual sessions clean up after 60 seconds away from their panel. Returning to the panel resets the timer. Unresolved save-recovery records are retained until cleanup is confirmed.
- **Interrupted gameplay tasks.** Scene entry cancels participants' queued interactions and temporarily disables autonomy. Exit restores original autonomy; cancelled interactions and departed gameplay groups are not reconstructed.
- **Navigation-based sessions.** Predetermined watch-only animation sequences are deferred. Ordinary authored transition nodes are supported.
- **Presentation boundaries.** Speech bubbles and thought icons from game scripts are withheld for Zois in a session, and everyone else keeps theirs. Custom facial poses, meshes and furniture models need their own visual fit checks.

The [validation report](validation.json) distinguishes automated checks, native diagnostic evidence and author visual acceptance. The [runtime contracts](docs/tier1-contracts.md) describe ownership and lifecycle guarantees in more detail.

## Content and development

If you're making an animation pack, I recommend using an AI agent to speed up ModKit imports, scene setup and packaging. I still review how the animation looks in-game myself. Start with the [agent handoff](docs/authoring.md#hand-an-animation-pack-to-an-ai-agent).

From the repository root, validate and stage the framework declarations, then run the source checks using your ModKit installation:

```powershell
$modkitRoot = "C:/Path/To/inZOIModKit"
python tools/build_catalog.py
python tools/test.py --modkit-root $modkitRoot
```

See [developer setup](docs/installation.md) for prerequisites and native asset inputs, and [development and packaging](docs/development.md) for ModKit validation and exact owned-payload filtering.

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

Contributions should keep reusable runtime behavior in SceneZOI and content assets and gameplay decisions in their respective projects. See [contributing](CONTRIBUTING.md) for bug reports, proposals and pull requests.

## Community and contributions

SceneZOI is intended to be a community-extensible framework rather than a system dependent on a single developer.

Its source code is publicly available so other developers can contribute improvements, maintain forks and build independent animation packs or gameplay integrations.

The goal is to provide shared infrastructure that animation authors and gameplay modders can rely on without needing to implement their own animation framework or depend exclusively on the original author for continued development.

**Contributor acknowledgment:**

- **@SephirothValentine** — Implementation of multi-scene support, introduced in SceneZOI 1.2.0.

Additional contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for information about reporting bugs, proposing features and submitting changes.

## Release status and licensing

SceneZOI is publicly available, with ready-to-install packages distributed through [GitHub Releases](https://github.com/acepleiades/SceneZOI/releases).

Version **1.2.0** introduced concurrent sessions, autonomous scene support through the public API, the new solo scene interaction and improved session cleanup. See the [1.2.0 release notes](https://github.com/acepleiades/SceneZOI/releases/tag/v1.2.0) for details.

The optional HZoi content pack is distributed separately through [Patreon](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155).

Recorded checks, known limits and author acceptance are summarized in [validation](docs/validation/README.md) and [validation.json](validation.json). Source checks alone do not establish rendered or audible behavior.

The native-message API has a documented version-1 contract. Internal modules and UI mailboxes are implementation details; scene and declaration schemas have their own documented contracts.

SceneZOI is licensed under the **GNU General Public License, version 3 only (GPL-3.0-only)**. See [LICENSE](LICENSE). Distributed forks must comply with GPLv3, including its applicable source-code and notice requirements.

**ModKit terms:** Mods created through the inZOI ModKit must also comply with KRAFTON's [inZOI Mods Policy](https://playinzoi.com/en/clause/mods_policy) and applicable ModKit terms of use. Forks must comply with both SceneZOI's license and the applicable ModKit terms. These third-party terms are separate from GPLv3.
