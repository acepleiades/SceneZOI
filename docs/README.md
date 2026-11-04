# SceneZOI documentation

These pages describe the active framework at the repository root. Dated investigation and validation records preserve evidence; they do not override current contracts or imply new visual acceptance.

| Topic | Document |
| --- | --- |
| Contributor/fork setup in ModKit | [Developer setup](installation.md) |
| Source, checks and packaging | [Development](development.md) and [contributing](../CONTRIBUTING.md) |
| Ownership and native declarations | [Package split](package-split.md) |
| Runtime architecture | [Design](architecture.md) and [lifecycle contracts](tier1-contracts.md) |
| Participants and native picker | [Group support](group-support.md) |
| Furniture | [Furniture](furniture.md) |
| Animation authoring | [Authoring](authoring.md) |
| Scene tags, actions and ratings | [Metadata](scene-metadata.md) |
| Independent add-ons | [Authoring guide](addon-authoring.md), [API](addons.md), [controls](addon-controls.md) and [SDK](../sdk/README.md) |
| Gaze and expressions | [Gaze](gaze.md), [expressions](expressions.md), [facial poses/head attachments](facial-poses.md) |
| Audio | [Voices](voices.md), [SFX](sfx.md) |
| Tasks and responses | [Scene tasks](scene-tasks.md), [completion effects](completion-effects.md) |
| One-shot nodes | [Transitions](transitions.md) |
| Reproduced issues and limits | [Investigation index](investigations/README.md) and [issue ledger](investigations/runtime-and-ui-issues.md) |
| Current verification | [Validation report](../validation.json) |

Historical validation summaries are under validation/archive/. Original large probes, local-machine paths and private diagnostics are not public authoring inputs. The retired prototype project, its old runtime/tests and anatomy assets have been removed; the separately published Blender exporter is maintained outside these repositories. The obsolete cooked-expression DataTable importer has also been removed; current expression declarations use native JSON patches.

- [Add-on controls, results and SDK extensions](addon-controls.md)
- [Add-on API validation findings and pitfalls](validation/addon-api-20261104.md)

## Optional private integration evidence

HZoi is private because it contains proprietary audio. A separate audio-muted
reference copy is planned, but is not currently available. Framework setup,
default checks and public authoring examples do not require that repository.
Use [the neutral scene sources](../packs/scenezoi/scenes/) and the schema examples
in these guides. HZoi paths/scene IDs in investigation and validation records
describe optional maintainer test evidence, not an accessible dependency.
