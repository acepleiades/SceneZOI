# SceneZOI

SceneZOI is a free, open-source animation framework for **inZOI**. It keeps Zois in sync during a scene, including on supported furniture. You can switch scenes, change playback speed, and pause. Animation packs add scenes and gameplay mods decide when to start them.

## Support the developers

**[acenetizen](https://github.com/acepleiades)** maintains SceneZOI and makes HZoi.

[![Support acenetizen on Patreon](assets/presentation/Patreon-PNG-Picture.png)](https://www.patreon.com/skyrimaceanimations)

**[SephirothValentine](https://github.com/SephirothValentine)** contributed concurrent scene support and makes VelvetZOI.

[![Support SephirothValentine on Patreon](assets/presentation/Patreon-PNG-Picture.png)](https://www.patreon.com/cw/VelvetZOI)

## Player downloads

**[Download SceneZOI](https://acepleiades.github.io/SceneZOI/)** · [Older releases](https://github.com/acepleiades/SceneZOI/releases) · [Report a problem](https://github.com/acepleiades/SceneZOI/issues/new/choose)

1. Download the packaged SceneZOI ZIP. Close inZOI and extract it into `Documents\inZOI\Mods`.
2. Open `SceneZOI_93C44199` and check that `mod_manifest.json` is directly inside. When updating, replace the old mod folder.
3. Enable **SceneZOI** in the game's mod menu, then load your save.

**With a gameplay mod**, use that mod's interactions to start a scene.

**Without a gameplay mod**, click your controlled Zoi and choose **Solo SceneZOI session** below **AI Emote**. Open the cog menu, go to **Debug**, and enable **SceneZOI manual start**. Exit the solo session. You can now open the scene picker from your controlled Zoi or supported furniture.

SceneZOI runs on its own and includes idle scenes for testing. Install a compatible content pack for more animations. For more help with play, settings or reporting a problem, see the [player guide](docs/playing.md).

## Make a mod for SceneZOI

- **Animation packs.** Get the Maya or Blender rig and exporter, then take a short loop from your editor into the game. [Make your first animation](docs/first-animation.md) · [Write and package a content pack](docs/authoring.md)
- **Gameplay mods.** Find compatible scenes, start one for the player or NPCs, and react to what happens in it. [Make a gameplay add-on](docs/addon-authoring.md) · [API reference](docs/addons.md)

## Contribute to SceneZOI

Start with the [contribution guide](CONTRIBUTING.md) for setup, tests, and pull requests. The [documentation index](docs/README.md) links to the full authoring and developer reference.

## License

SceneZOI is licensed under [GPL-3.0-only](LICENSE). The inZOI ModKit and game assets referenced by the framework remain subject to the applicable inZOI ModKit terms. The separate [HZoi Reference](https://github.com/acepleiades/HZoi-Reference) includes adult examples and has its own asset rights.
