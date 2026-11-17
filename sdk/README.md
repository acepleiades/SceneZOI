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

For per-Zoi body and attachment choices, use the same generic request method:

```lua
client:request(owner, "appearance.inspect", "get_appearance_variants", {})
-- After the inspect response, choose an available compatible variant.
client:request(owner, "appearance.select", "set_appearance", {
    session_id = session_id,
    appearance = {
        [participant_id] = {
            attachment_variants = {body_region = "designer.anatomy_medium"},
        },
    },
})
```

The changing call must come from the session's creating add-on/client. Handle the
inspect reply before choosing an ID; it lists registered variants rather than
making a selection. No SDK-specific wrapper or API version change is required.
See [appearance variants](../docs/appearance-variants.md) for scene defaults,
native-body/disabled-slot values, clearing choices and temporary body behavior.

The SDK uses the [SceneZOI license](../LICENSE).
