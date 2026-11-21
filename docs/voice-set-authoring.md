# Make a voice set for SceneZOI

A voice pack can add a new voice for existing scenes. It can also introduce a
context for scenes you author. Start with a few clips for one Zoi body type and
one context, then test the set in game. For sexual scenes, vocal clips include
moans, breaths and orgasm reactions; these belong in the voice system so the
player's chosen voice and male/female voice volume controls apply. The choice
persists for that Zoi across scenes and save files.

## Voices and sound effects

| What the player hears | Use | Scene Settings volume |
| --- | --- | --- |
| A Zoi moaning, breathing, speaking or making another vocal sound during a scene | A voice set and the role's `voices` context | **Female Voice Sets** or **Male Voice Sets**, according to the set's `body` |
| A Zoi saying a line when a scene task completes | A named voice response and `task_completion_voices` | The speaking Zoi's voice channel |
| Skin contact, thrust/stroke effects, prop sounds or room ambience | [Scene SFX](sfx.md) or a [task-completion sound](scene-tasks.md#data-defined-completion-sounds) | **Sound Effects** |

Put a Zoi's vocal clips in voice sets. A voice clip played through an SFX emitter
is controlled by **Sound Effects**. The Zoi's voice selection and voice volume
apply when the clip is played through the voice engine. Both systems use imported
SoundWave assets. [Audio settings](settings.md#audio-volume)

If your pack already plays vocal clips through SFX, reuse the SoundWave references
in the voice set. Switch the scene to a voice context for continuing vocal sounds
or a named response for a task-completion line, then remove the old vocal emitter
to avoid duplicate playback. Contact triggers belong to the SFX engine.

## 1. Import your clips

Import your WAVs into your registered inZOI ModKit project as SoundWave assets.
Use **Copy Reference** on each imported clip and put the Unreal object path
in the set's `clips` list. For example, a clip imported as `SW_Soft_01` under
your mod's Audio folder might have the path
`/ExampleVoices/Audio/SW_Soft_01.SW_Soft_01`. Replace the sample paths below with
your actual references.

## 2. Create an archetype, a context and a set

An **archetype** is the voice personality the player picks. A **context** is
what the scene asks for. A **set** supplies the clips for one
archetype and context on a compatible body.

For your own scenes, the files below declare a new `example_voices.pleasure`
context. Existing scenes will not request that new ID automatically.

**Adding voices to HZoi or another existing pack?** Check its scene's context
first. For HZoi's sex scenes, use `sex` in the set instead of
`example_voices.pleasure`, omit the context declaration and its manifest entry,
and make the context-providing pack a dependency. Fellatio and kissing can use
different contexts; supply a set for each one you want to cover.

Create the following files relative to your pack manifest.

**`voices/soft.json`**

```json
{
  "schema_version": 1,
  "id": "example_voices.soft",
  "label": "Soft",
  "body": "female"
}
```

**`voices/pleasure.json`**

```json
{
  "schema_version": 1,
  "id": "example_voices.pleasure",
  "label": "Pleasure"
}
```

**`voices/soft_pleasure.json`**

```json
{
  "schema_version": 1,
  "id": "example_voices.soft.pleasure",
  "label": "Soft Pleasure",
  "body": "female",
  "archetype": "example_voices.soft",
  "context": "example_voices.pleasure",
  "clips": [
    "/ExampleVoices/Audio/SW_Soft_01.SW_Soft_01",
    "/ExampleVoices/Audio/SW_Soft_02.SW_Soft_02"
  ],
  "volume": 0.8,
  "gap": 0.4
}
```

`volume` is the authored level from 0 to 1. `gap` is the number of game
seconds after one clip finishes before another can play. To add more contexts
to Soft, make a set for each one and reuse the archetype ID. For a male set,
create a male archetype and set `body` to `male` in both declarations.

## 3. Register the voice pack and use it in a scene

For a voice-only pack, save this as `packs/example_voices.json`. For an existing
content pack, append the entries to its `data_files` list and keep its scenes.

```json
{
  "schema_version": 3,
  "id": "example_voices",
  "nodes": [],
  "extensions": [],
  "data_files": [
    {"kind": "voice_archetype", "file": "voices/soft.json"},
    {"kind": "voice_context", "file": "voices/pleasure.json"},
    {"kind": "voice_set", "file": "voices/soft_pleasure.json"}
  ]
}
```

If you author the scene, add this field to its JSON and replace `speaker`
with the actual role that should speak. During the scene, SceneZOI chooses
clips from that Zoi's selected set for the requested context.

```json
"voices": {
  "speaker": {"context": "example_voices.pleasure"}
}
```

For a spoken one-shot after task completion, put the line in a named
`responses` group in the voice set. Use `task_completion_voices` in the scene
to name the completing role and the speaker. Each can be a different Zoi.
[One-shot voice response example](voices.md#task-triggered-one-shot-voice-responses)

## 4. Package and test

From the SceneZOI checkout, stage the declarations in your native project:

```powershell
python tools/build_catalog.py --packs "C:/MyPack/packs/example_voices.json" --project "C:/Path/To/ExampleVoicesProject"
```

Declare SceneZOI as a dependency and package your SoundWave assets and the
generated declarations with your own mod. Follow the
[packaging guide](development.md#isolated-packaging), then install the filtered
package and start inZOI with it enabled.

1. Start a scene that requests the voice context. Open **Personality Management**
   from the person icon. Select the speaking Zoi, the **Soft** archetype, and
   **Soft Pleasure** for the context. For a first test, select it explicitly.
   See [voice defaults](voices.md#independent-declarations) if you want a default.
2. Start with all three audio sliders at 100%. Lower **Female Voice Sets** to
   0% to mute this example, then restore it and lower **Sound Effects** to 0%.
   The voice should still play with only Sound Effects muted. For a male set,
   use **Male Voice Sets**. Also try **None** for that Zoi's voice context.
3. Choose a different set for another compatible Zoi. Try a second scene that
   requests the same context, then load another save containing the same Zois.
   Their individual choices should carry over. [How personality settings are saved](playing.md#voice-and-expression-choices)

If a clip is silent, check the scene's role and context, the selected set's
body and archetype, the SoundWave object paths, and that the declaring pack is
enabled. A different scene can request another context or omit voice. See the
[voice reference](voices.md) for persistence, defaults and playback rules.
