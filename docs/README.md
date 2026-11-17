# SceneZOI documentation

## Play

[Download and install](../README.md#player-downloads) · [Start a scene or report a problem](playing.md) · [Scene Settings](settings.md)

## Make an animation pack

1. [Make your first animation](first-animation.md). Open the Maya or Blender rig, animate a short loop and export it.
2. [Write and package your first scene](authoring.md). Import the tracks, connect the scene to a hub or the picker, and test it in game.
3. [Read a complete scene](content-examples.md). Start with a neutral example from SceneZOI or follow the illustrated features in HZoi Reference, which contains adult examples and silent audio.

| I'm adding… | Read |
| --- | --- |
| Another role, furniture placement or a link from a hub | [Participants](group-support.md) · [Furniture](furniture.md) · [Pack declarations and hub extensions](package-split.md) |
| Tags, actions or translated names | [Metadata and ratings](scene-metadata.md) · [Localization](localization.md) |
| Where Zois look and how they react | [Gaze](gaze.md) · [Expression contexts](expressions.md#responsibilities-and-data) · [Facial poses](facial-poses.md) |
| Voice and sound in a scene | [Voice instructions](voices.md#scene-instructions) · [Sound effects](sfx.md) |
| A progress meter, an effect at completion or a transition | [Scene tasks](scene-tasks.md) · [Completion effects](completion-effects.md) · [Transitions](transitions.md) |
| Clips from a separately installed library | [Optional animation assets](authoring.md#optional-animation-assets) |
| A temporary body or a choice of anatomy and other skeletal attachments | [Appearance variants](appearance-variants.md) |

## Make a voice or expression set

- [Make a voice set](voice-set-authoring.md). Import vocal clips, give them a context, and check the in-game voice volume controls. The [voice reference](voices.md) covers the full schema and one-shot responses.
- [Make an expression set](expressions.md#authoring-your-own-sets). Group facial clips by context so Zois in the same scene can react differently.

[Voice and expression choices](playing.md#voice-and-expression-choices) shows how players assign sets to individual Zois.

## Make a gameplay mod

Follow [Add-on authoring](addon-authoring.md) to set up the [Lua SDK](../sdk/README.md) and start a scene. Use the [API reference](addons.md) for scene searches, autonomous plans and events, and [live controls](addon-controls.md) for changes during a session.

## Work on SceneZOI

- [Contributing](../CONTRIBUTING.md) explains how to report bugs and open a pull request.
- [Developer setup](installation.md) gets the source checks running. [Development and packaging](development.md) covers ModKit, native testing and GitHub Pages.
- [Architecture](architecture.md) shows where to start reading the source. [Runtime contracts](tier1-contracts.md) explains the behavior to preserve when changing it.
- [Release checks](validation/README.md) covers testing a package. [Troubleshooting the runtime](investigations/runtime-and-ui-issues.md) links recurring symptoms to the relevant code and tests.
