# Authoring a SceneZOI add-on

SceneZOI owns one active session, fixed participants, playback and cleanup.
An add-on owns its gameplay decisions, persistence, rewards and assets. Starts
require the controlled Zoi to participate. API version 1 does not add concurrent
sessions, autonomous NPC starts or predetermined watch-only sequences.

## Create and package a native project

1. Use **Create Project** in ModKit. Retain its generated project identity,
   descriptor and metadata. A manually assembled Lua scaffold is not proof of
   native registration, even if manual mounting or an export succeeds.
2. Copy [the SDK](../sdk/README.md) into `workspace/lua/B2/SceneZOIAddon/`.
   Add your B2 bindings through supported ModKit tools and validate the project.
   B1 handles client UI/config; the public SceneZOI client runs in B2.
3. Declare a dependency on `SceneZOI_93C44199`. Content remains inert JSON:
   one authored scene per file, manifest scene directories, native `Text_UI`
   declarations and retail `Text` discovery. See [metadata](scene-metadata.md)
   and [content authoring](authoring.md).
4. Package with supported `PackageUGC` and an isolated `-ExportToGameMods` directory.
   Keep generated protection/checksums; do not fabricate them for editable Lua.
   Use [the exact owned-payload filter](development.md) before installation.
   Lua/data-only packages may have zero cooked assets, no IoStore container and
   an empty asset-hash document; the filter validates their exact non-asset files.
5. Test a **fresh process launch**. Verify your callbacks and declarations loaded
   automatically, then call `get_version` through the independent SDK. Manual
   mounting or diagnostic table patching is a separate development shortcut.

## Wire the SDK

```lua
local Client = require('SceneZOIAddon.Client')
local client = Client.new('author.integration', {
  response = function(reply)
    -- Correlate request_id and branch on ok/code.
  end,
  event = function(event, instance_id)
    -- session_started means playback; session_ended includes cleanup outcome.
  end,
  instance_changed = function(previous, current)
    -- Negotiate and subscribe/register again; do not replay uncertain rewards.
  end
})

-- Forward current B2 native callbacks:
local function on_message(owner, kind, content)
  client:refresh_owner(owner)
  return client:on_message(kind, content)
end

-- Call once per client from a scheduler supplying real elapsed seconds:
local function tick(real_seconds, fresh_owner)
  client:tick(real_seconds, fresh_owner)
end
```

Keep caller entity identity stable while refreshing its current native wrapper.
`refresh_owner` updates pending retries and renewal references only for matching
entity IDs. Selecting another Zoi does not transfer that caller's registration.
Use fresh request IDs for new operations; retries reuse the identical request.
Do not drive one client's clock from both global and per-character callbacks.
The SDK needs real elapsed time even while gameplay is paused.

B1 Lua must use the native player controller for possession;
`entity.get_possessed` is B2-only from Lua. Do not treat UI-JavaScript or CLI
availability as proof that a command is available in both Lua environments.

## Three integration patterns

**Affectionate starter.** Find with `allowed_content_ratings: ["GENERAL"]`,
`required_tags: ["affectionate"]`, `required_actions: ["hug"]` and the selected
participants. Inspect returned roles and supply `bindings` when giver/receiver
identity matters. Discover suitable furniture and use `validate_start` before
starting. Preflight is not a reservation; startup still rechecks.

**Restricted encounter.** Supply `session_restrictions` to `start_at_hub` or
another start operation. A search selects the initial scene; restrictions govern
every subsequent route. Use `get_navigation` for currently available edges.
Never relax a no-match result silently.

**Observer/modifier.** Subscribe and reconcile its returned current snapshot/cursor,
including an already-running manual session. Register only needed capabilities
before task/speed/presentation writes. Observing grants no navigation ownership.
Use `request_stop` with interruption rights for an orderly foreign/manual Exit.
Release your overrides/registration when finished; do not clear another caller's
hold/mute. Persist gameplay consequences once using your own save data.

## Query real content declarations

The [worked content-pack guide](content-examples.md) links the public
HZoi-Reference metadata. With a compatible pack's declarations actually enabled,
these `find_scenes` arguments match its affectionate standing idle as well as
compatible neutral framework hubs:

```json
{
  "search": {
    "allowed_content_ratings": ["GENERAL"],
    "required_tags": ["affectionate"],
    "required_actions": ["hug"]
  }
}
```

This query omits participants, so it searches library metadata rather than
proving roster compatibility. Add `participants` and explicit `bindings` where
needed, then preflight a start. Use the same criteria in `session_restrictions`
to constrain later playback; `search` alone only selects the initial scene.
The [idle](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L95) explicitly has two directed hugs. Its activity
neighbors derive EXPLICIT and are excluded by GENERAL restrictions even when
they also contain hugs. HZoi's idle is not itself a `starting_hub`; the pack
extends the framework's starting hub. HZoi-Reference supplies content data,
not an executable API-client example, and cloning it does not install it.

## Common pitfalls observed in validation

| Failure | Authoring rule |
| --- | --- |
| Manually mounted scaffold worked, but fresh startup skipped Lua and JSON. | Create/register the native project through ModKit and test the packaged installation from a fresh process. |
| Package filtering expected an asset response/container that a Lua/data-only export did not have. | Use the zero-asset path with an exact manifest allowlist; unexpected and cooked/native payloads still fail. |
| An asset catalog entry existed but its mesh was unavailable in retail. | Check actual native loading/readiness. A catalog listing does not establish installed content. |
| A retained native wrapper stopped delivering after a host-only reload. | Keep the entity ID stable and refresh its wrapper from current callbacks. Handle instance changes and explicitly subscribe/register again. |
| The test clock advanced twice and expiry measurements became misleading. | Tick each SDK client once using real elapsed seconds; do not multiply by participant count or game speed. |
| A new run read the previous run's terminal result. | Correlate diagnostics with a run/request/session ID, not a single retained status string. |
| Accepted start/attachment/clothing commands were mistaken for completed work. | Wait for playback/readiness/events/readback; inspect later errors and final cleanup status. |
| Releasing one modifier could be mistaken for clearing all modifiers. | Holds/mutes combine across callers; release only your own layer and inspect effective state. |
| Native muting originally started then stopped a clip during clothing handoff, and intentional suppression produced a missing-response warning. | API-5 fixes both. Native presentation checks must cover preparation/re-entry and deliberate suppression, not only setter acceptance. |
| A final GENERAL hub could conceal earlier EXPLICIT playback. | Inspect the result's played history/peak rating when deciding consequences. |

Technical checks do not decide consent, relationships, payments or rewards. Native
component/asset diagnostics and author visual/audible acceptance are separate.
See [the concise validation findings](validation/addon-api-20261104.md),
[API reference](addons.md) and [control contracts](addon-controls.md).

Facial/prop integrations can pair a declared `facial_pose` override with a
head-component attachment. See [facial poses](facial-poses.md); readiness, release
and saved-preference rules are the same as other presentation overrides.
