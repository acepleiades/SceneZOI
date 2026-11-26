# Playing with SceneZOI

[Download the latest SceneZOI ZIP and follow the installation steps](../README.md#player-downloads).

A **session** lasts from entry to Exit and keeps the same participants. It can contain several **scenes**. Each scene has its own animation and choices in the panel.

<a id="start-a-scene"></a>

## Start a session

- **With a gameplay mod**, use the interactions it adds. Leave debug start off unless you also want to pick scenes yourself.
- **Without a gameplay mod**, open **Solo SceneZOI Session** below **AI Emote** on your controlled Zoi. Click the cog, turn on **Debug â†’ SceneZOI manual start**, and exit. Use the new picker interaction on your controlled Zoi or on supported furniture. Choose whoever should take part and start the session.

Animation packs can add choices to the built-in solo and paired idle hubs. What you see depends on which packs are installed, which Zois you chose, and where the scene is taking place. For example, a bed scene needs a supported bed and clips made for that placement.

If you have an idea for how scenes should fit into the game, you can
[build your own gameplay add-on](addon-authoring.md) with the SceneZOI API.

<a id="while-a-scene-is-playing"></a>

## During a session

- Use the scene panel to pick another scene, adjust playback speed, or select **Exit** to end the session. Pausing inZOI pauses playback. If an add-on started the session with **Auto-mode**, turn it off to take manual control when the add-on permits it.
- You can switch to a free Zoi and start a second household session. Switch back to a participant to see the first session’s panel and use **Exit**.
- Use the cog for sound, voices, task progress rates and other options. [Scene Settings](settings.md)

When the game's clock is paused, SceneZOI shows **Paused with the game clock**
and locks its scene controls, including navigation, clothing, settings and Exit.
Resume the game with its clock controls to use them again. This keeps pose and
clothing changes from jumping ahead while physics are frozen. SceneZOI's own
animation speed is separate. Choosing 0.5x does not pause or lock the panel.

When a gameplay add-on ends the session shown in the panel, SceneZOI can show
its reason, such as the Zois choosing to stop after someone walked in. After
successful cleanup, **Dismiss** counts down from 10 seconds and closes the panel.
Click it to close the panel sooner. A technical failure stays visible until you
dismiss it. Background sessions without a panel do not open one to show an ending.

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

1. Tell us what you were trying to do, which packs and gameplay mods were enabled, and what happened. Include the interaction you used to start the session, and whether **Exit** returned the Zois to normal gameplay.
2. Open `Documents\inZOI\Mods\InGame\SceneZOI_93C44199` and zip the **scenezoi_runtime** folder. It contains recent scenes and API calls as well as the SceneZOI release version. If the folder is missing, check [where inZOI writes settings and diagnostics](settings.md#storage-location).
3. Attach the ZIP to your [bug report](https://github.com/acepleiades/SceneZOI/issues/new/choose). Check it for details you prefer to keep private before posting it publicly.
