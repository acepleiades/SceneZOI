# SceneZOI

SceneZOI is a free, open-source animation framework for **inZOI**. It keeps Zois in sync during a scene, including on supported furniture. You can switch scenes, change playback speed, and pause. Animation packs add scenes and gameplay mods decide when to start them.

**[Join the OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU)** for player help, content creation and collaboration with other mod authors. The community covers SceneZOI, HZoi and inZOI modding, as well as OStim Standalone and related Skyrim mods.

## Support the developers

**[acenetizen](https://github.com/acepleiades)** maintains SceneZOI and makes HZoi.

[![Support acenetizen on Patreon](assets/presentation/Patreon-PNG-Picture.png)](https://www.patreon.com/skyrimaceanimations)

## Player downloads

**[Download SceneZOI](https://acepleiades.github.io/SceneZOI/)** · [Older releases](https://github.com/acepleiades/SceneZOI/releases) · [Report a problem](https://github.com/acepleiades/SceneZOI/issues/new/choose)

1. Download the packaged SceneZOI ZIP. Close inZOI and extract it into `Documents\inZOI\Mods`.
2. Open `SceneZOI_93C44199` and check that `mod_manifest.json` is directly inside. When updating, replace the old mod folder.
3. Enable **SceneZOI** in the game's mod menu, then load your save.

**With a gameplay mod**, use that mod's interactions to start a scene.

**Without a gameplay mod**, click your controlled Zoi and choose **Solo SceneZOI session** below **AI Emote**. Open the cog menu, go to **Debug**, and enable **SceneZOI manual start**. Exit the solo session. You can now open the scene picker from your controlled Zoi or supported furniture.

SceneZOI runs on its own. Animation packs can add new scenes to its built-in idle hubs. For more help with play, settings or reporting a problem, see the [player guide](docs/playing.md).

## Make a mod for SceneZOI

- **Port existing animations.** Retarget the body tracks to inZOI and build a scene around them. If you're missing a separate track for anatomy or another attachment, pose the mesh in game and use an AI assistant to transfer the preview values into your scene JSON. [Porting workflow](docs/authoring.md#port-existing-animations) · [Missing attachment tracks](docs/authoring.md#port-an-animation-without-a-separate-attachment-track)
- **Create animations.** Use the Maya or Blender rig and exporter to make sexual, suggestive or affectionate scenes, or other interactions the game does not provide. [Make your first animation](docs/first-animation.md) · [Write and package a content pack](docs/authoring.md)
- **Voice sets.** Give Zois their own voices for existing scenes or new ones. [Make a voice set](docs/voice-set-authoring.md)
- **Expression sets.** Give Zois different facial reactions in the same scene. You can use the game's facial animation clips. [Make an expression set](docs/expressions.md#authoring-your-own-sets)
- **Bodies and skeletal attachments.** Offer alternative bodies, male genitals, tongues or props. Choose a mesh for each Zoi and keep it through clothing changes without making it their permanent saved body. [Body and attachment choices](docs/appearance-variants.md)
- **Gameplay mods.** Find compatible scenes, start one for the player or NPCs, and react to what happens in it. [Make a gameplay add-on](docs/addon-authoring.md) · [API reference](docs/addons.md)

Each Zoi can have their own voice and expression choices, which carry over across scenes and save files. [Personality Management](docs/playing.md#voice-and-expression-choices)

For male genitals, I recommend using the same mesh as HZoi and the supplied
Maya and Blender rigs. The [standalone asset pack](docs/authoring.md#how-do-i-make-my-animation-pack-independent-of-hzois-fallback-penis)
lets you include it in your own animation pack without requiring HZoi.

## Contribute to SceneZOI

Start with the [contribution guide](CONTRIBUTING.md) for setup, tests, and pull requests. The [documentation index](docs/README.md) links to the full authoring and developer reference.

## License

SceneZOI is licensed under [GPL-3.0-only](LICENSE). The inZOI ModKit and game assets referenced by the framework remain subject to the applicable inZOI ModKit terms. The separate [HZoi Reference](https://github.com/acepleiades/HZoi-Reference) includes adult examples and has its own asset rights.
