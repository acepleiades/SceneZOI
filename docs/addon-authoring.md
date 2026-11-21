# Make a gameplay mod for SceneZOI

A gameplay mod gives players a reason to start an animation scene. For example,
add a dialogue option to propose sex, check whether the other Zoi accepts, find
a private place, and start a scene from an installed animation pack. Your mod
can then respond to an orgasm, an interruption, or a romantic partner walking in.

SceneZOI is an agnostic, data-driven animation framework. Sexual, suggestive and
affectionate encounters are likely to be its main use, but the same systems can
support other interactions. A vampire feeding scene could track the vampire's
satisfaction and the target's blood depletion separately.

You can make a gameplay mod without authoring animations. Use installed packs,
or supply your own scenes alongside your gameplay. SceneZOI handles synchronized
playback, scene navigation, task meters and restoration on Exit. Your mod handles
proposals, relationship rules, witnesses, rewards and other gameplay consequences.

This guide takes you from connecting your mod to SceneZOI to designing those
encounters. Keep the [API reference](addons.md) nearby for individual request
fields. For authoring help and collaboration, join the
[OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

## Plan the encounter

Decide what happens before, during and after the scene. For a sexual encounter:

1. **Before:** select eligible adult Zois, apply your relationship and consent
   rules, and let them accept or refuse. If they should walk to a bed or speak
   first, finish those game interactions before requesting scene playback.
2. **During:** choose the activities your mod allows, track progress, and decide
   whether an interruption should end the encounter.
3. **After:** check what actually played and why it ended before applying
   relationship changes, payment, pregnancy chances or cooldowns.

SceneZOI checks whether the cast, animation tracks and furniture are compatible.
Your mod decides whether the encounter should happen. A successful start is not
evidence of consent, and an ended scene is not evidence that a goal was reached.

## Create and package a native project

Create your mod through **Create Project** in ModKit. Keep its generated project
identity and add `SceneZOI_93C44199` as a dependency.

Copy [the SDK folder](../sdk/lua/SceneZOIAddon/) into your project's
`workspace/lua/B2/`. The SDK is a small Lua client that sends requests to
SceneZOI and receives replies. It includes its own JSON reader and does not
need access to SceneZOI's internal Lua modules.

**B2** is the game's simulation environment, where this client runs. **B1** is
the presentation environment used for client UI work. Set up your B2 script
bindings with ModKit, then connect the callbacks below.

If your mod also supplies animations, voices or task definitions, follow
[content-pack authoring](authoring.md) for those files. Scene declarations are
JSON data; your gameplay code belongs in your own mod.

## Wire the SDK

Create a client with an ID belonging to your mod. The examples use
`author.encounters`; replace it with your own ID.

```lua
local Client = require("SceneZOIAddon.Client")
local client = Client.new("author.encounters", {
    response = function(reply)
        if not reply.ok then
            print(reply.request_id, reply.code, reply.message)
            return
        end
        -- Use reply.request_id to identify the request being answered.
        -- Its returned data is in reply.result.
    end,
    event = function(event, instance_id)
        -- session_started means the animation is ready and playing.
        -- session_ended reports the outcome and restoration result.
    end,
    instance_changed = function(previous, current)
        -- SceneZOI restarted. Check its version and subscribe again.
        -- Do not repeat rewards whose outcome is uncertain.
    end,
})

-- Call from your B2 on_lua_message callback.
local function on_message(owner, kind, content)
    client:refresh_owner(owner)
    return client:on_message(kind, content)
end

-- Call once per client from your scheduler, using real elapsed seconds.
local function tick(real_seconds, owner)
    client:tick(real_seconds, owner)
end

local serial = 0
local function request(owner, operation, arguments)
    serial = serial + 1
    local id = "encounters." .. operation .. "." .. serial
    client:request(owner, id, operation, arguments)
    return id
end
```

These are callback helpers, not a complete ModKit script. Connect them to your
project's actual message and update callbacks. Later examples reuse `client`
and `request` from this block.

`owner` is the loaded B2 Zoi carrying your messages. Keep that Zoi's identity
stable for this client, and pass its current native object from callbacks.
Changing the controlled Zoi does not transfer ownership of an existing session.
Do not update the same client's clock once for every participant: update it once
using real seconds, including while gameplay is paused.

The helper gives every new request a new ID. The SDK retries unanswered requests
with the original ID, so a retry does not start the same scene twice. Keep the
request ID you receive to match replies, start failures and diagnostics.

## Make a first request

```lua
local version_request = request(owner, "get_version", {})
```

In the `response` callback, match `reply.request_id` to `version_request`, check
`reply.ok`, and read `reply.result.features`. Before using automatic scene
selection, check `autonomous_scenes`; before using multiple stages, also check
`autonomous_stages`. Check the feature for any other optional API you use.

Requests and events arrive later through your message callback. Wait for the
reply before using its result. [Requests and replies](addons.md#supported-transport)

## Query real content declarations

Suppose your mod offers standing vaginal sex. Replace these example IDs with
the IDs of the loaded Zois who accepted the encounter:

```lua
request(owner, "find_scenes", {
    participants = {"20522", "20526"},
    search = {
        required_tags = {"standing"},
        required_actions = {"vaginal_sex"},
    },
})
```

Read `reply.result.scenes` and each match's `bindings`, which map scene roles to Zois.
If giver and receiver matter, inspect the scene's directed actions and pin the
intended roles with `bindings`. Role names vary between packs; do not assume
every pack calls its roles `male` and `female`.

HZoi's [Standing Rear Sex definition](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/04_standing_rear.json)
is one real match for this activity. SceneZOI alone contains neutral hubs, so
this query needs an installed pack supplying the sexual animation. The public
HZoi Reference repository contains scene examples, rest-pose placeholders and
silent audio. Cloning it does not install the playable HZoi animations.

Without `participants`, a query only checks the animation library. With them,
SceneZOI also checks whether those Zois can fill the scene's roles. A search
does not reserve them or the furniture. Use `validate_start` to check your
chosen start arguments, then handle any failure from the actual start too.
[Search and restrictions](addons.md#search-and-session-restrictions)

## Start a goal-driven scene through the SDK

This example starts a compatible standing sex scene and asks both participants
to complete **Excitement** once. It needs a pack such as HZoi with suitable
standing scenes, positive task rates and a cap that permits completion for both
roles. The two IDs are examples; use the same eligible Zois you checked above.

```lua
request(owner, "start_autonomous_scene", {
    initiator = "20522",
    participants = {"20522", "20526"},
    search = {
        required_tags = {"standing"},
        required_actions = {"vaginal_sex"},
    },
    restrictions = {
        allowed_content_ratings = {"GENERAL", "SUGGESTIVE", "EXPLICIT"},
        required_tags = {"standing"},
    },
    goals = {
        {participant_id = "20522", task_id = "excitement", completions = 1},
        {participant_id = "20526", task_id = "excitement", completions = 1},
    },
    stages = 1,
    end_policy = {type = "goals"},
})
```

`search` chooses the opening activity. `restrictions` limits everything that
can play afterward, including manual navigation. Here, standing hubs and other
standing activities remain available; this is not a vaginal-sex-only restriction.
Requiring only `EXPLICIT` would exclude neutral hubs used to connect scenes.
Choose those limits according to your mod's rules.

The plan starts with Auto-mode on. With one stage, its default animation speed
is 1×. SceneZOI follows authored navigation and ends when both goals and their
completion effects have finished. You can add stages and activity preferences
later. Turning Auto-mode off pauses automatic navigation and planned Exit;
the player can still navigate manually and use Exit.

Check the start reply for acceptance, then wait for `session_started` and keep
its `session_id`. Acceptance means preparation was queued. It can still fail,
for example because a participant became busy or furniture was occupied.
Use `get_request_status` if you need to check an uncertain start.
[Automatic plans](addons.md#autonomous-scenes)

For a player-directed encounter, use `start_at_hub` or `start_scene` instead.
Ordinary starts require the controlled Zoi as initiator and participant.
Autonomous starts can use eligible loaded NPCs, including solo rosters, and can
run alongside other sessions with separate participants. The message carrier
does not have to participate in a background encounter.
[NPC and concurrent scenes](addons.md#concurrent-and-background-sessions)

## Use a bed, sofa or a different body

For furniture scenes, call `find_furniture` with the intended `participants`
and a suitable `scene_id`. Pass the returned `furniture_id` to your start.
For a sofa, also pass `furniture_pair_id`: it identifies two adjacent seats,
leaving the rest available. Preflight is a check, not a reservation.
[Furniture discovery](addon-controls.md#starting-and-finding)

If your encounter should use a particular body or male genitals attachment,
declare compatible variants and pass each Zoi's choices through the appearance
API. These choices survive clothing updates and are restored on Exit without
making the temporary body permanent in the save.
[Body and attachment selection](appearance-variants.md#choose-appearance-through-the-api)

## Read the outcome before applying consequences

On `session_ended`, inspect `result_facts.stop_reason`,
`result_facts.cleanup_complete` and, for an automatic plan, `plan.outcome`.
Check task completion counts before granting a reward that requires an orgasm.
An interruption, a timeout or a player pressing Exit can end the encounter early.

Use the played actions and `result_facts.peak_content_rating` when the type of
activity matters. The final scene may be a neutral hub even though sex happened
earlier. `history_truncated` warns that the detailed history reached its limit.

Your mod saves its own rewards, relationship changes and cooldowns. Record them
once so receiving another status reply does not pay twice. Recent results can
be queried with `get_session_result`, but SceneZOI's bounded result history is
not permanent save data. [Outcomes and history](addon-controls.md#observation-and-outcomes)

## A romantic partner catches the encounter

For example, Zoi A and Zoi B are having sex, and A's romantic partner, Zoi C,
walks into the room. Your mod should establish all three facts: a sexual action
is currently playing, C has the relevant relationship with A, and C can actually
witness it. Being on the same property is not enough to establish that C saw it.

An add-on can observe manual scenes and scenes started by another mod. Request
`subscribe` with `scope = "all"` and events such as `session_started`,
`node_entered` and `session_ended`. Use `list_sessions` to read already-running
sessions; the snapshot returned by `subscribe` alone is not a list of them all.
Keep checking witnesses while a relevant scene plays, since C may arrive later.
Limit checks to nearby loaded Zois at a modest interval instead of scanning the
whole city every frame.

Use `Client.actions(snapshot)` to get action records with participant IDs in
their `actor`, `target` and `performer` fields. Build your activity rules from
`get_definitions` and the actions you want to treat as cheating. An EXPLICIT
scene, an orgasm, a hug or a naked body alone does not tell you who cheated on
whom. For group scenes, inspect each directed action and each affected couple.

The following is gameplay logic for your mod to implement, not a SceneZOI call:

```text
While a scene is playing:
    Read its current sexual actions and the Zois involved.
    Find a loaded romantic partner of an involved Zoi.
    Check your exclusivity rules and whether that partner can see the encounter.
    If this partner has not already reacted to this encounter:
        Keep the session ID and the three Zoi IDs in your mod's pending state.
        Request ordinary SceneZOI Exit.
        Wait for session_ended and successful cleanup.
        Resolve the current native Zoi objects and confirm they are available.
        Deliver the confirmed-affair notification to the witness.
        Record successful delivery once; log a refusal instead of retrying every frame.
```

For interruption, first request `register_integration` with
`capabilities = {"interrupt"}` and wait for a successful reply. Then use:

```lua
request(owner, "request_stop", {
    session_id = session_id,
    reason = "caught_by_partner",
})
```

The creating client can stop its own scene without this registration. An
observer needs the interruption capability for manual or another mod's scenes.
The SDK renews integration registration when ticked. Release it when finished.
Wait for `session_ended` and successful cleanup before queuing a confrontation
on a former participant; SceneZOI prevents ordinary tasks during playback.
[Observation and interruption](addon-controls.md#cooperation-between-independent-add-ons)

### Connect the discovery to inZOI's cheating reactions

inZOI calls its nearby-event notifications **Howling**. Its current data includes
`Howling_Affair_Confirmed`, which selects the built-in confirmed-cheating effects.
You can deliver that notification to a specific witness through their B2
[Howling component](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b2/components/fb2howlingcomponent/).
This calls an existing game method; it does not override a static function.

In our example, **A** cheated with **B**, and **C** witnessed it. After ordinary
SceneZOI Exit has completed, call this with **C as `witness` and A as `cheater`**.
Both arguments are current, loaded native `FB2Character` objects, not the string
IDs from a SceneZOI snapshot:

```lua
local function notify_confirmed_affair(witness, cheater)
    local howling = witness:GetComponent(inzoi.EB2ComponentType.Howling)
    if not howling then
        return false
    end
    return howling:OnReceiveHowling(
        "Howling_Affair_Confirmed", cheater:GetEntityId()
    )
end

-- After your witness/relationship checks and successful scene cleanup:
-- local delivered = notify_confirmed_affair(witness_zoi, cheater_zoi)
```

This is a native game call, separate from `client:request`. It delivers a
notification to the witness you selected. Your mod must first establish that
C saw A having sex with B and that this violates their relationship rules.
Do not use it on every nearby Zoi or treat this direct delivery as a visibility
test. The normal broadcast's range and line-of-sight selection are not performed
by the example.

The ModKit data checked for this guide connects the notification to:

| Native data | What it does |
| --- | --- |
| `HowlingEffect/Effect_Affair_Confirmed` | Runs `Howling_Affair_Confirmed_React` with Self = witness and Target = cheater, and attempts a trait-appropriate native interaction. |
| `Script_Howling/Howling_Affair_Confirmed_React` | Records cheating milestones and relationship history, adds `Watch_Cheat` from witness to cheater and `Witnessing_Cheating` in the reverse direction, and applies the native trait-specific reactions and buffs. |

Use these effects deliberately. In the current data, the non-gloating branch
sets Romance and Family relationship values to **−100**. This is the game's
confirmed-affair consequence, not merely an angry animation. The script also
has its own eligibility conditions, including `IsLovable`.

The handler returns a boolean. A `true` result means it processed a native
effect, not that every scripted branch ran or a confrontation finished.
Cooldowns, current activity and missing native data can prevent delivery.
Log the result, and inspect relationship flags and records when testing. Do
not clear the game's cooldown maps or repeat the call each frame to force it.

**A three-Zoi confrontation needs the third Zoi identified too.** The current
native confrontation recruits the cheater through `Affair_Caught_Cheater` and
the other participant through `Affair_Caught_Mistress`, both from the witness's
relationship records. The confirmed-affair script supplies the first flag;
the native `Affair_Mistress_Reaction` script supplies the second, using
Self = the other participant and Target = the witness.

The native `RunScriptToAffairCouple` helper takes a native script context, not
SceneZOI's role bindings. Do not assume it identifies B from a SceneZOI scene.
If your mod wants the full three-person confrontation, bridge the actual B
from the witnessed action into that native companion-reaction path and verify
its recruitment flags before starting it. The call above is the entry to the
witness/cheater reaction; it does not promise a complete three-person scene.

This example was checked against ModKit's exported Lua signatures and native
data. Test it in the game version you support, including an unrelated bystander,
a partner who could not see the encounter, cooldown rejection and the final
relationship effects. The older `RangeReaction_AffairBySpouse` is a different,
spouse-and-`Affair`-buff-gated reaction; playing its animation alone does not
reproduce the confirmed-affair system.

## A vampire feeding encounter

A non-sexual example is feeding inspired by *Vampire: The Masquerade — Bloodlines*.
Your content pack supplies the animation and two tasks, such as
`vampires.feeding` for the vampire and `vampires.blood_depletion` for the target.
Declare their rates and completion rules on the scene. `vampire_biting` is
already a shared action; the framework does not include feeding animations or
those two task definitions. [Task authoring](scene-tasks.md)

Start the scene through the same SDK. Your gameplay mod can read task state and
listen for `task_completed`, let the player stop early, or apply a consequence
when Blood Depletion completes. Use the event's participant ID, task ID and
completion index to identify exactly whose task completed and avoid repeating
the effect. Task completion resets the meter, so checking only for a displayed
100% can miss it.

If the target should die, end the scene and wait for its restoration to finish
before applying the game's death behavior. Check that the target is still
loaded and alive. Death and persistent blood loss belong in your gameplay mod.
Remember that a gameplay outcome pending after Exit also needs your own saved
state if it must survive saving or loading during that handoff.
If death is an allowed outcome, do not give an automatic plan a Feeding goal
that ends the scene before depletion can occur: choose your goals and end policy
to match the encounter. [Task controls](addon-controls.md#live-controls)

## Character bindings alongside other script mods

Bind your scripts through ModKit and test alongside another script mod. On the
tested retail build, an exact Zoi group binding takes precedence over `"*"`.
A wildcard-only mod can therefore start its Main script while its household
character callbacks never arrive.

Use `modkit_list_lua_binding_keys` to check the keys for your target environment
and type. Exact bindings for the same group can coexist; preserve other mods'
entries. SceneZOI uses its own native participant receiver and leaves the Zoi
wildcard namespace available. Check message delivery on actual characters,
not just whether your mod's Main script ran.

For possession in B1 Lua, use the native player controller.
`entity.get_possessed` is B2-only from Lua; availability in UI JavaScript or a
CLI tool does not establish that it can be called from B1 Lua.

## Package and check your mod

Use the supported ModKit export and the [owned-payload filter](development.md#isolated-packaging).
Keep the generated Lua protection and checksums. A Lua-only mod can have no
cooked animation assets; its package still needs the correct native registration
and allowed files. Test the installed package on a fresh game launch. Manual
mounting or reloading Lua does not prove normal installation works.

Check these cases before publishing:

- Start with only the dependencies you declare. Missing animations or no
  matching scene should give a useful refusal, without silently changing the
  requested activity.
- Start while Zois are doing normal tasks, with autonomy enabled. Check entry,
  clothing, props and normal movement after Exit.
- Test pause, fast-forward, manual takeover, control changes and early Exit.
  Do not confuse SceneZOI's animation speed with the game's time controls.
- Test an interrupted or rejected start without granting completion rewards.
  For reactions, test a real witness, a partner in another room and an unrelated
  bystander, including a group scene and repeated checks of the same encounter.
- Test alongside another gameplay mod. Release only your own task holds,
  presentation changes and attachments. Appearance and effect requests may
  still be loading after acceptance; inspect their readiness and later errors.
- Test a fresh installation with no retained settings, then an existing save.
  If SceneZOI restarts, check its version and renew subscriptions and integration
  rights. Keep the same caller ID while refreshing its current native object.

For a report, ask for the player's existing `scenezoi_runtime` folder and the
steps that led to the issue. Match your request and session IDs in `api_trace.cfg`
and `scene_history.cfg`. Add useful logs in your own mod for decisions SceneZOI
cannot see, such as proposal acceptance, witness checks, native reaction calls
and payment. [Runtime diagnostics](addons.md#runtime-diagnostics)
