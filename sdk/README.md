# SceneZOI Lua SDK

Copy [lua/SceneZOIAddon/](lua/SceneZOIAddon/) into your mod's `workspace/lua/B2/`.
Follow [Add-on authoring](../docs/addon-authoring.md) to wire your B2 callbacks
and make a first request. The client uses the versioned native-message API and
includes its own JSON codec.

Use `client:request` for calls such as `get_version`, `find_scenes` and
`start_autonomous_scene`. Tick each client once with real elapsed seconds.
Refresh its native owner from the current callback for that same Zoi. If the
host changes, negotiate again and reconcile your subscriptions and integrations.
[API reference](../docs/addons.md) · [Live controls](../docs/addon-controls.md) · [Goal-driven example](../docs/addon-authoring.md#start-a-goal-driven-scene-through-the-sdk)

The SDK uses the [SceneZOI license](../LICENSE).
