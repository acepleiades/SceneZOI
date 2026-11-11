# SceneZOI documentation

These pages describe the active framework at the repository root. Dated investigation and validation records preserve evidence; they do not override current contracts or imply new visual acceptance.

| Topic | Document |
| --- | --- |
| Contributor/fork setup in ModKit | [Developer setup](installation.md) |
| Source, checks and packaging | [Development](development.md) and [contributing](../CONTRIBUTING.md) |
| Ownership and native declarations | [Package split](package-split.md) |
| Runtime architecture | [Design](architecture.md) and [lifecycle contracts](tier1-contracts.md) |
| Participants and native picker | [Group support](group-support.md) |
| Concurrent sessions and auto-mode | [Add-on API](addons.md#concurrent-and-background-sessions), [design notes](autonomous-scenes-design.md) |
| Furniture | [Furniture](furniture.md) |
| Animation authoring | [Authoring](authoring.md) and [worked content-pack examples](content-examples.md) |
| Scene tags, actions and ratings | [Metadata](scene-metadata.md) |
| Independent add-ons | [Authoring guide](addon-authoring.md), [API](addons.md), [controls](addon-controls.md) and [SDK](../sdk/README.md) |
| Gaze and expressions | [Gaze](gaze.md), [expressions](expressions.md), [facial poses/head attachments](facial-poses.md) |
| Player-facing translations | [Localization](localization.md) |
| Audio | [Voices](voices.md), [SFX](sfx.md), [settings and volume](settings.md) |
| Tasks and responses | [Scene tasks](scene-tasks.md), [completion effects](completion-effects.md) |
| One-shot nodes | [Transitions](transitions.md) |
| Reproduced issues and limits | [Investigation index](investigations/README.md) and [issue ledger](investigations/runtime-and-ui-issues.md) |
| Release evidence and limits | [Validation overview](validation/README.md) and [current report](../validation.json) |

Curated validation evidence and failure notes are retained here. Raw historical
checkpoints and machine-specific diagnostics are archived privately; they are not
public authoring inputs. Current contracts take precedence over dated findings.

- [Add-on controls, results and SDK extensions](addon-controls.md)
- [Add-on API validation findings and pitfalls](validation/addon-api-20261104.md)

## Public content-pack examples

[HZoi-Reference](https://github.com/acepleiades/HZoi-Reference) is an optional, reference-only adult-content example
with proprietary audio replaced by silence. The [worked guide](content-examples.md)
maps features to complete JSON files and traces their declarations, scene
instructions and referenced libraries. Its lack of a repository-wide license
does not grant general asset reuse. All-ages examples remain in the
[neutral scene sources](../packs/scenezoi/scenes/).

The original HZoi production repository stays private. Historical validation used
that original pack; its audible acceptance is not a claim about silent playback.
Framework setup and default checks require neither checkout.
