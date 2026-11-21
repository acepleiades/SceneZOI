# Contributing to SceneZOI

## Get started

1. Fork SceneZOI and clone your fork. Follow [developer setup](docs/installation.md) to run the checks on Windows with ModKit, Python and Node.js.
2. Make a branch for your change. Use the [source map](docs/architecture.md) to find the relevant code and tests. The default checks work with the framework checkout alone.
3. Open a pull request against `main`. Explain the problem, what changes for players or authors, and how you checked it. Link an issue if one exists.

For authoring help or to discuss a proposed integration with other developers,
join the [OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

## Where to edit

| Change | Source |
| --- | --- |
| Runtime and game bindings | [`workspace/lua/`](modkit/SceneZOI_93C44199/workspace/lua/) inside the ModKit overlay |
| In-game controls and launcher | [`ui/`](modkit/SceneZOI_93C44199/ui/) inside the overlay |
| Built-in scenes, profiles and translations | [`packs/`](packs/) |
| Public gameplay integration | [`sdk/`](sdk/) and the [API docs](docs/addons.md) |
| Download site | [`docs/index.html`](docs/index.html) and [site assets](docs/site-assets/) |

ModKit generates the installed `lua/` directory from `workspace/lua/`. Make source edits in the workspace. Check [pack ownership](docs/package-split.md) before adding new assets or declarations. SceneZOI is an all-ages framework. Gameplay rules and pack assets belong in their respective projects.

## Add a tag

Add new scene and participant tags to SceneZOI's
[`packs/scenezoi/metadata/tags.json`](packs/scenezoi/metadata/tags.json), update
the metadata/search tests, and submit a pull request. Use plain shared IDs and
check existing IDs and aliases first. Content packs use that vocabulary instead
of adding their own tag dictionaries. [Tag authoring](docs/scene-metadata.md)

## Test your change

- For a bug fix, reproduce the failure and keep a regression where the suite can catch it. For a native change, also test the affected behavior in game, including Exit if you touch scene lifecycle.
- For API or schema changes, check existing callers and update the affected docs and examples.
- For a docs change, check commands, examples, links and headings. For translated UI text, keep the English fallback and update the [localization entries](docs/localization.md).
- In the PR, say which checks you ran. If you tried the change in-game, include the result you saw. A Lua regression and an in-game playback test answer different questions. [Release checks](docs/validation/README.md)

## Report a bug

Search the [existing issues](https://github.com/acepleiades/SceneZOI/issues) first. For a player report, follow the [instructions for sending diagnostics](docs/playing.md#report-a-problem). For authoring or API problems, include the smallest scene JSON or SDK call that reproduces it. Include the version or commit and any required content packs.

Contributions follow the [repository license](LICENSE) and the applicable inZOI ModKit terms. Keep proprietary assets, private logs and machine-specific paths out of the patch.
