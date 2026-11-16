# Playing with SceneZOI

[Download the latest SceneZOI ZIP and follow the installation steps](../README.md#player-downloads).

## Start a scene

- **With a gameplay mod**, use the interactions it adds. Leave debug start off unless you also want to pick scenes yourself.
- **Without a gameplay mod**, open **Solo SceneZOI session** below **AI Emote** on your controlled Zoi. Click the cog, turn on **Debug → SceneZOI manual start**, and exit. Use the new picker interaction on your controlled Zoi or on supported furniture. Choose whoever should take part and start the scene.

The framework includes solo and paired idle scenes. What appears next depends on the installed animation packs, the Zois you chose, and where the scene is taking place. For example, a bed scene needs a supported bed and clips made for that placement.

## While a scene is playing

- Use the scene panel to pick another animation, adjust playback speed, or **Exit**. Pausing inZOI pauses the scene. If an add-on started a scene with **Auto-mode**, turn it off to take manual control when the add-on permits it.
- You can switch to a free Zoi and start a second household scene. Switch back to a participant to see the first scene's panel and use **Exit**.
- Use the cog for sound, voices, task progress rates and other options. [Scene Settings](settings.md)

## Optional HZoi pack

[HZoi](https://www.patreon.com/skyrimaceanimations/posts/scenezoi-hzoi-174452155) adds adult animations. To use it, install its player ZIP in the same Mods folder, check for `HZoi_660649D8/mod_manifest.json`, and enable both mods. Use the instructions on that post for optional assets. The public HZoi Reference repository is for authors studying scene files.

## Report a problem

1. Tell us what you were trying to do, which packs and gameplay mods were enabled, and what happened. Include the interaction you used to start the scene, and whether **Exit** returned the Zois to normal gameplay.
2. Open `Documents\inZOI\Mods\InGame\SceneZOI_93C44199` and zip the **scenezoi_runtime** folder. It contains recent scenes and API calls as well as the SceneZOI release version. If the folder is missing, check [where inZOI writes settings and diagnostics](settings.md#storage-location).
3. Attach the ZIP to your [bug report](https://github.com/acepleiades/SceneZOI/issues/new/choose). Check it for details you prefer to keep private before posting it publicly.
