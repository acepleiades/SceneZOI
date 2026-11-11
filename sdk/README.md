# SceneZOI add-on SDK

Copy `lua/SceneZOIAddon/` into an independent native mod's `workspace/lua/B2/`.
The SDK contains its own JSON codec and uses public native messages; it does not
require private framework modules. It is covered by the repository's LICENSE.

Start with the [add-on authoring guide](../docs/addon-authoring.md), then the
[API reference](../docs/addons.md) and [controls reference](../docs/addon-controls.md).
The SDK includes request correlation/retries, host-change detection, subscription
resynchronization, integration renewal, same-entity owner refresh and public-data
helpers for roles/actions/partners/tasks/navigation. Use `client:request` for
`start_autonomous_scene`, `get_session`, `set_auto_mode` and `stop_session`.
See the [goal-driven SDK example](../docs/addon-authoring.md#start-a-goal-driven-scene-through-the-sdk)
and the [autonomous API reference](../docs/addons.md#autonomous-scenes).

There is no installed test mod, test command mailbox or test declaration in this
SDK. Repository regressions exercise the SDK using isolated fixtures.
