# Runtime architecture

A scene is a fixed cast of Zois playing synchronized tracks. Each session owns
its own clock, current scene, temporary changes and cleanup. The panel follows
the Zoi under player control. Several sessions can run at once.

## Follow a scene through the code

Links below point to the Lua or UI source in the ModKit overlay.

| When | Start here |
| --- | --- |
| Client Lua starts | [DataFiles](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/DataFiles.lua) reads the game data table. [Catalog](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Catalog.lua) validates definitions and builds the scene graph. |
| The player clicks Start | [Launcher UI](../modkit/SceneZOI_93C44199/ui/scenezoi-starter/), [StartingScenes](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/StartingScenes.lua) and [Binding](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Binding.lua). The picker and the API use the same catalog. |
| An add-on asks to start | [AddonAPI](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/AddonAPI.lua) handles the public request. [Plan](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Plan.lua) drives autonomous scenes. |
| Zois prepare and furniture is reserved | [Runtime](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Runtime.lua) coordinates [Session](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Session.lua), [SaveBridge](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/SaveBridge.lua), B2 participants and [Furniture](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Furniture.lua). The session waits for the save journal before changing gameplay state. |
| Tracks play or change | [Clock](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Clock.lua) drives [Playback](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Playback.lua). [Subsystems](../modkit/SceneZOI_93C44199/workspace/lua/B1/SceneZOI/Subsystems.lua) manages optional presentation. |
| A scene ends | Runtime coordinates cleanup. Each owner releases its resources, and the save journal keeps any restoration still outstanding. |

## Three boundaries that matter

- **B1 and B2.** B1 runs client-side playback, UI coordination and the API host.
  B2 runs simulation changes such as interaction cancellation and autonomy. Use
  native messages to cross that boundary. The [Lua guide](../modkit/SceneZOI_93C44199/workspace/lua/AGENTS.md)
  has the binding conventions and differences from UI JavaScript.
- **Pack data and runtime.** ModKit installs `Text_UI` patches, which the game
  exposes as `Text`. B1 builds the catalog at startup. Each session keeps the
  definitions it starts with. Restart inZOI to load newly installed packs.
  [Pack declarations](package-split.md)
- **Public API and internals.** Gameplay mods use the versioned SDK and native
  messages. The rest of the Lua runtime and UI mailboxes are internal. The
  player picker and add-on starts share role, furniture and resource checks.
  [Public API](addons.md)

For changes to ownership, read the [runtime contracts](tier1-contracts.md).
For a bug report, use [runtime troubleshooting](investigations/runtime-and-ui-issues.md)
to find the relevant diagnostic and regression.
