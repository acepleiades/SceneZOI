# SceneZOI documentation

For questions, authoring help and collaboration, join the
[OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

If a guide uses a term you don't recognize, look it up in the
[SceneZOI dictionary](dictionary.md). For examples of what a gameplay
add-on can do, start with the [gameplay mod Q&A](gameplay-mod-ideas.md).

## Play

[Download and install](../README.md#player-downloads) · [Start a scene or report a problem](playing.md) · [Scene Settings](settings.md)

## Make an animation pack

1. [Make your first animation](first-animation.md). Open the Maya or Blender rig, animate the scene you want to make and export it.
2. [Write and package your first scene](authoring.md). Import the tracks, connect the scene to a hub or the picker, and test it in game.
3. [Read a complete scene](content-examples.md). Start with a neutral example from SceneZOI or study HZoi Reference's adult scene definitions, rest-pose animation placeholders and silent audio.

| I'm adding… | Read |
| --- | --- |
| Another role, furniture placement or a link from a hub | [Participants](group-support.md) · [Furniture](furniture.md) · [Pack declarations and hub extensions](package-split.md) |
| Tags, actions or translated names | [Metadata and ratings](scene-metadata.md) · [Localization](localization.md) |
| Where Zois look and how they react | [Gaze](gaze.md) · [Expression contexts](expressions.md#responsibilities-and-data) · [Facial poses](facial-poses.md) |
| Voice and sound in a scene | [Voice instructions](voices.md#scene-instructions) · [Sound effects](sfx.md) |
| A separate attachment that replaces the body's crotch region | [Shared neutral coverage patches](coverage-patches.md) · [Body and attachment choices](appearance-variants.md) |
| Excitement, orgasm effects or a one-shot between poses | [Scene tasks](scene-tasks.md) · [Completion effects](completion-effects.md) · [Transitions](transitions.md) |
| Clips from a separately installed library | [Optional animation assets](authoring.md#optional-animation-assets) |
| Alternative bodies, male genitals, tongues or other skeletal attachments | [Declare variants and set scene defaults](appearance-variants.md) |

<a id="make-a-voice-or-expression-set"></a>

## Make a voice, expression or sound pack

You can add voices, facial clips, or sounds to the content library without
authoring new body animations. Choose the guide for the kind of content you
want to make.

- [Make a voice set](voice-set-authoring.md). Import vocal clips, give them a context, and check the in-game voice volume controls. The [voice reference](voices.md) covers the full schema and one-shot responses.
- [Make an expression set](expressions.md#authoring-your-own-sets). Give Zois their own facial personality using stock or custom clips, then
  keep their choices across scenes and saves.

- [Add sound effects](sfx.md#import-and-register-sounds). Import your own clips,
  publish a reusable sound set and call it from a scene.

[Voice and expression choices](playing.md#voice-and-expression-choices) shows how players assign sets to individual Zois.

## Make a gameplay mod

Follow [Add-on authoring](addon-authoring.md) to set up the [Lua SDK](../sdk/README.md) and start a scene. Use the [API reference](addons.md) for scene searches, autonomous plans and events, and [live controls](addon-controls.md) for changes during a session.

- [How would you make a pregnancy, STI, prostitution, succubus or vampire mod?](gameplay-mod-ideas.md) Find the events, native systems and design choices for each.
- [Read HZoi Gameplay's implementation](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/gameplay-authoring.md). Follow a native invitation through venue selection, [goal-driven playback](addon-authoring.md#plan-an-encounter-from-foreplay-to-coitus) and consequences.
- [Choose each Zoi's body and attachments](appearance-variants.md#choose-appearance-through-the-api). Pass individual choices through the API, keep compatible fallbacks and restore the native body on Exit.
- [Start concurrent NPC solo scenes](addons.md#start-concurrent-solo-scenes). Use a separate roster and session for each scene; the controlled Zoi does not have to take part.

## Work on SceneZOI

- [Contributing](../CONTRIBUTING.md) explains how to report bugs and open a pull request.
- [Developer setup](installation.md) gets the source checks running. [Development and packaging](development.md) covers ModKit, native testing and GitHub Pages.
- [Architecture](architecture.md) shows where to start reading the source. [Runtime contracts](tier1-contracts.md) explains the behavior to preserve when changing it.
- [Release checks](validation/README.md) covers testing a package. [Troubleshooting the runtime](investigations/runtime-and-ui-issues.md) links recurring symptoms to the relevant code and tests.
