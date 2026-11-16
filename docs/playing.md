# Playing with SceneZOI

[Download the latest SceneZOI ZIP and follow the installation steps](../README.md#player-downloads).

## Start a scene

- **With a gameplay mod**, use the interactions it adds. Leave debug start off unless you also want to pick scenes yourself.
- **Without a gameplay mod**, open **Solo SceneZOI session** below **AI Emote** on your controlled Zoi. Click the cog, turn on **Debug → SceneZOI manual start**, and exit. Use the new picker interaction on your controlled Zoi or on supported furniture. Choose whoever should take part and start the scene.

Animation packs can add choices to the built-in solo and paired idle hubs. What you see depends on which packs are installed, which Zois you chose, and where the scene is taking place. For example, a bed scene needs a supported bed and clips made for that placement.

If you have an idea for how scenes should fit into the game, you can
[build your own gameplay add-on](addon-authoring.md) with the SceneZOI API.

## While a scene is playing

- Use the scene panel to pick another animation, adjust playback speed, or **Exit**. Pausing inZOI pauses the scene. If an add-on started a scene with **Auto-mode**, turn it off to take manual control when the add-on permits it.
- You can switch to a free Zoi and start a second household scene. Switch back to a participant to see the first scene's panel and use **Exit**.
- Use the cog for sound, voices, task progress rates and other options. [Scene Settings](settings.md)

## Voice and expression choices

Open **Personality Management** from the person icon in the scene panel and
select a Zoi. Choose an expression set, then pick a voice archetype and its
voice set for each context. You can choose **None** for a voice context.

For example, give one Zoi a soft voice and subtle expressions. Give another
Zoi a more animated voice and expression set. When a scene asks both for the
same kind of reaction, each uses their own sets. Those choices follow each Zoi
into later scenes and into other save files containing them.

SceneZOI stores these choices in its local settings by the game's Zoi ID.
Loading an earlier save with the same Zoi keeps your current choices. A copy
of the character with a different ID has its own choices. Keep the content
packs with those sets enabled to use them. [Settings storage](settings.md#storage-location)

## Optional HZoi pack

[HZoi](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155) adds adult animations. To use it, install its player ZIP in the same Mods folder, check for `HZoi_660649D8/mod_manifest.json`, and enable both mods. Use the instructions on that post for optional assets. The public HZoi Reference repository is for authors studying scene files.

## Report a problem

1. Tell us what you were trying to do, which packs and gameplay mods were enabled, and what happened. Include the interaction you used to start the scene, and whether **Exit** returned the Zois to normal gameplay.
2. Open `Documents\inZOI\Mods\InGame\SceneZOI_93C44199` and zip the **scenezoi_runtime** folder. It contains recent scenes and API calls as well as the SceneZOI release version. If the folder is missing, check [where inZOI writes settings and diagnostics](settings.md#storage-location).
3. Attach the ZIP to your [bug report](https://github.com/acepleiades/SceneZOI/issues/new/choose). Check it for details you prefer to keep private before posting it publicly.
