# Make an expression set for SceneZOI

<a id="scene-expressions-and-personality"></a>

An expression set gives a Zoi a facial personality. Two Zois can play the same
sexual animation and show different expressions because each uses their own
chosen set. The scene asks for a context, such as `Pleasure` or `Kiss`, and the
set supplies the facial clips for it. The player's choice follows that Zoi
across scenes and save files with the same native entity ID.

You can offer new expressions for existing packs without making body animations.
This guide uses the game's facial clips; you can also import your own compatible
clips. For authoring help, join the
[OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

## Authoring your own sets

### 1. Choose the contexts your scenes use

Read `expressions` in a scene you want to support. HZoi uses contexts including
`Idle`, `Pleasure` and `Kiss`. These are shared names chosen by authors, not a
fixed engine list. Reuse the requested context to make your set work there;
inventing a new context does not make existing scenes request it.

This fragment belongs in a scene with roles named `male` and `female`:

```json
"expressions": {
  "male": {"context": "Pleasure"},
  "female": {"context": "Pleasure", "facial_pose": "scenezoi.open_o"}
}
```

The two roles request the same context, but resolve it through their own sets.
The female role also requests a fixed open-mouth pose, useful for fellatio.
Use that pose only where the action needs it. A context chooses facial animation;
a [facial pose](facial-poses.md) holds specific joints on top of it.

### 2. Write the set

Save this complete definition as `expressions/soft.json` beside your pack
manifest. It references a stock female facial clip used by HZoi Reference.

```json
{
  "schema_version": 2,
  "id": "designer.soft",
  "label": "Soft",
  "body": "female",
  "contexts": {
    "Pleasure": {
      "hold": [3, 7],
      "transition": 0.3,
      "options": [{
        "animation": "/Game/Characters/Anims/Interaction/Female/Emotion/Facial/ANIM_F_Face_Sensual.ANIM_F_Face_Sensual",
        "weight": 1
      }]
    }
  }
}
```

Add more options for variety. `weight` controls their relative chance of being
picked; `hold` gives the range of scene seconds before another selection.
`transition` controls the blend. Without `sample`, a clip plays and retains its
authored blinking. Add `"sample": 4.5`, for example, to hold its pose at 4.5 seconds,
including its eyelid pose. A sampled closed eye will stay closed.

Provide each context you want to support. Adding only `Pleasure` leaves scenes
requesting `Idle` or `Kiss` without a matching clip in this set. Compare the
[complete Pleasure face set](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/expressions/pleasure_face.json)
for weighted options, several contexts and a sampled kiss.

### Discovery and authoring workflow

For an expression-only pack, save this as `packs/designer.json`. In an existing
animation pack, append `expression_files` and keep its other entries.

```json
{
  "schema_version": 3,
  "id": "designer",
  "nodes": [],
  "extensions": [],
  "expression_files": ["expressions/soft.json"]
}
```

The filename is relative to the manifest. Stage the declarations from the
SceneZOI checkout:

```powershell
python tools/build_catalog.py --packs "C:/MyPack/packs/designer.json" --project "C:/Path/To/DesignerProject"
```

Declare SceneZOI as a dependency, [package](development.md#isolated-packaging)
your native project, install it and restart inZOI. Stock clip paths reference
game assets; package your own imported clips if you use those instead.
See [package declarations](package-split.md) for the generated native patch.

### 3. Check the result in game

1. Enter a scene that requests `Pleasure`. In **Personality Management** (the
   person icon), select the compatible female Zoi and choose **Soft**.
2. Watch a full expression change and inspect the face from several angles.
   Try a second compatible Zoi with a different set in the same scene.
3. Navigate to a scene using another context. Check it has an option in the set
   if you expect an expression there. Also test a mouth pose with gaze enabled.
4. Exit, start another scene, and load a save containing the same Zoi. Their
   chosen set should remain selected; the temporary mouth pose should not.

If the set is absent, check `expression_files`, its appearance `body`, and the
installed build. If it is selectable but does not play, check the context and
clip path. Missing or unusable clips warn without stopping body animation.
The public reference has rest-pose body tracks, so use your own animations or
the player pack to judge the full scene.

## Responsibilities and data

SceneZOI supplies playback, per-Zoi preferences and the personality panel.
Packs supply expression sets. With no compatible set installed, SceneZOI leaves
the face to the game and warns without blocking entry.

Set IDs and contexts are trimmed, case-insensitive printable ASCII strings,
1–96 characters. Spaces and punctuation are allowed. Display labels can use
Unicode. `Pleasure` and `pleasure` name the same context. Keep a stable,
pack-prefixed set ID so updates preserve player choices.

Every schema-2 file requires `schema_version`, `id`, `body` (`female` or `male`)
and `contexts`, which may be empty. Each declared context requires a nonempty
`options` array. Option labels default to the asset name and weights to 1.
Omitted `hold` and `transition` inherit other contributions or use `[5, 11]`
and `0.35`. Optional `default: true` selects a body default; otherwise the first
compatible set ID in sorted order is used. A saved compatible choice wins.

Scene instructions can supply a context, `facial_pose`, or both. Omission
releases the previous instruction. A missing context releases owned clip
playback; a valid facial pose can still apply. Pose-only instructions need no
expression set. Name `scenezoi.open_o` explicitly for the bundled mouth pose.

### Shared IDs and conflicts

Use different IDs for independent personalities. Authors can deliberately share
a set ID to contribute contexts or clips, but must coordinate its settings.
Body and explicitly supplied label, hold and transition must agree. Identical
clip/sample entries deduplicate; conflicting entries reject that contributing
file as a whole. Runtime processes declaration filenames in sorted order,
warns about the rejected file and retains the other valid contributions.
Author builds reject the conflict before staging.

Optional `aliases` migrate saved choices from old IDs. Display labels do not
change saved identity. See [shared declarations](authoring.md#shared-declarations-and-conflicting-ids)
before extending another author's set. Ask its author or the
[community Discord](https://discord.gg/RECvhVaRcU) to agree on shared contexts.

## Engine and lifecycle

Every participant has independent option selection and timers. Options avoid
immediate repetition when alternatives exist. Hold times follow the shared
scene clock: game pause, game speed and the scene playback selector apply.
An already-running native blend is not retimed by a later speed change.

SceneZOI holds the outgoing expression during preparation, rebinds it after
clothing/head changes and releases its own playback on Exit. It preserves the
game's head animation instance and face customization. A missing asset is
skipped; if none can load, body playback continues and the personality panel
reports the problem. New clips need an in-game check on the faces they support.

A fixed pose affects only listed joints. Owning an eyeball joint temporarily
releases procedural gaze; ordinary mouth poses keep gaze and blinking. Custom
face proportions can change the fit of a pose. See [facial poses](facial-poses.md)
and [runtime contracts](tier1-contracts.md) for the detailed ownership rules.

## Personality panel and persistence

Expression choices belong to the native Zoi ID, independently of the scene,
role, roster order or game save. On the tested game build they are stored at:

```text
Documents/inZOI/Mods/InGame/SceneZOI_93C44199/scenezoi_personality/zoi_<native-entity-id>.cfg
```

The same ID retains its choice across saves. A newly created or copied Zoi with
a different ID has a separate profile. Independent worlds reusing an ID are
not distinguished by a world key. Missing or incompatible sets fall back to
an installed body default, or no selection if none exists. Compatibility uses
the appearance meshes and validated body binding, rather than biological gender
or whether the player controls the Zoi.

Preserve `scenezoi_personality` and the separate `scenezoi_voice` preferences
when updating a package. They may live apart from the installed mod files.
See [storage locations](settings.md#storage-location) before resetting them.
