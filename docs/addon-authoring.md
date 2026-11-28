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

[HZoi Gameplay](https://github.com/acepleiades/HZoi-Gameplay) is a working
open-source add-on. Read its
[gameplay authoring notes](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/gameplay-authoring.md)
to follow a real invitation through venue selection, playback and outcomes.

Looking for a starting point for your own idea? The
[gameplay mod Q&A](gameplay-mod-ideas.md) covers pregnancy, STIs, paid
encounters, succubi and vampires. It points to the SceneZOI events and inZOI
systems each idea needs. See the [dictionary](dictionary.md) for terms used
across both guides.

## Plan the encounter

Decide what happens before, during and after the scene. In the case of a sexual
encounter:

1. **Before:** your gameplay add-on determines the eligibility of the Zois for
   the scene. If they should walk to a bed or speak first, your add-on's scripts
   should finish those game interactions before requesting scene playback.
2. **During:** choose the activities your mod allows, track progress, and decide
   whether an interruption should end the encounter.
3. **After:** check what actually played and why it ended before applying things
   such as relationship changes, payment, pregnancy chances or cooldowns.

SceneZOI checks whether the characters, animation tracks and furniture are
compatible. For example, your add-on may request a scene with a large number of
participants. If no installed scene fits that group, the API returns
`no_matching_scenes`. Your add-on should use that reply to tell the player that
no suitable scene was found. SceneZOI's manual picker already displays its own
notification for this case. See the [no-match handling example](#handle-a-start-with-no-matching-scene)
for a toast and recovery flow.

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

## Handle a start with no matching scene

Suppose the player requests a sexual encounter for three Zois, but the installed
packs have no scene matching that group and activity. The start reply returns
`ok = false` and `code = "no_matching_scenes"`.

Your add-on can show a message, clear its pending encounter, and let the player
choose another activity or group. Release any reservations your mod made for
that attempt. Completion rewards belong to a scene that actually played; this
attempt never started.

If your add-on chooses the venue, it can preflight the next candidate before
giving up. If the player chose a specific bed, give them the choice of trying
a different spot. Keep the encounter's activity and eligibility rules in
place during retries. For an example that tries the next ranked venue, look
for `nextVenue` in [HZoi Gameplay's invitation handler](https://github.com/acepleiades/HZoi-Gameplay/blob/main/prototype/queen-bed/HZoiGameplay_4BD2AC16/lua/B2/Components/VenueInvite.lua).

For a player-requested encounter, the following B2 helper sends a notification
to your own B1 script. Define it before creating your SDK client and call it
from the `response` callback. Pass the current message carrier from
`on_lua_message` as `owner` and the request ID you kept when calling `request`
as `start_request_id`. Store the carrier in a local variable before forwarding
the message to `client:on_message`, so the response callback can use it:

```lua
-- B2: handle the reply for this particular start attempt.
local function handle_start_reply(owner, reply, start_request_id)
    if reply.request_id == start_request_id
        and not reply.ok and reply.code == "no_matching_scenes" then
        -- Clear this attempt from your mod's pending encounters here.
        inzoi.message.send_to_client(
            owner:GetEntityId(), "author.encounters.notice", "no_matching_scenes"
        )
        return true
    end
    return false
end
```

Bind a B1 script to the same Zoi carrying those messages. This receiver displays
the toast. Use your mod's namespace for the message type and its translated
player text:

```lua
-- B1: a separate script on the message carrier.
local M = {}

function M.on_lua_message(self, owner, kind, content)
    if kind ~= "author.encounters.notice" or content ~= "no_matching_scenes" then
        return
    end
    local message = "No compatible animation was found for this group and activity. "
        .. "Try another activity or check your animation packs."
    local ok, error_message = inzoi.cli.execute(
        "toast.show message=" .. string.format("%q", message)
        .. " lifetime=5 immediate=true"
    )
    if not ok then
        print("Encounter notification failed:", error_message)
    end
end

return M
```

`toast.show` is a client presentation command, so this example forwards the
message from B2 to B1 instead of calling it in the API response callback itself.
The SDK and SceneZOI do not display this toast for the add-on. Log the failed
request ID and your requested activity as well, so a player report can be matched
to `api_trace.cfg`.

For an automatic NPC attempt, you may prefer to log the no-match result quietly
and try again when the group, activity or available content changes. A repeated
background check does not need a player notification every time.

For `find_scenes`, zero matches is a successful search: check
`reply.result.count == 0`, rather than expecting this error code.
`validate_start` reports a failed check through `reply.result.valid == false`
and `reply.result.code`. Neither operation starts a scene.

## Start a goal-driven scene through the SDK

This example starts a compatible standing sex scene and asks both participants
to complete **Excitement** once. It needs a pack such as HZoi with suitable
standing scenes, positive task rates and a cap that permits completion for both
roles. The two IDs are examples; use the same eligible Zois you checked above.

```lua
local arguments = {
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
}
request(owner, "start_autonomous_scene", arguments)
```

`search` chooses the opening activity. `restrictions` limits everything that
can play afterward, including manual navigation. Here, standing hubs and other
standing activities remain available; this is not a vaginal-sex-only restriction.
Requiring only `EXPLICIT` would exclude neutral hubs used to connect scenes.
Choose those limits according to your mod's rules.

The plan starts with Auto-mode on. With one stage, its default animation speed
is 1×. SceneZOI follows authored navigation and ends when both goals and their
completion effects have finished. Turning Auto-mode off pauses automatic
navigation and planned Exit. The player can still navigate manually and use Exit.

Check the start reply for acceptance, then wait for `session_started` and keep
its `session_id`. Acceptance means preparation was queued. It can still fail,
for example because a participant became busy or furniture was occupied.
Use `get_request_status` if you need to check an uncertain start.
[Automatic plans](addons.md#autonomous-scenes)

Use `start_at_hub` or `start_scene` to let the player choose each activity
from the outset. Ordinary starts require the controlled Zoi as initiator
and participant.
Autonomous starts can use eligible loaded NPCs, including solo rosters, and can
run alongside other sessions with separate participants. The message carrier
does not have to participate in a background encounter.
[NPC and concurrent sessions](addons.md#concurrent-and-background-sessions)

## Plan an encounter from foreplay to coitus

Use a staged plan when your mod should choose the order of activities. HZoi
Gameplay does this for both player invitations and NPC encounters. The Zois
start with foreplay when a viable opening is available, then favor coitus as
their Excitement goals progress.
[HZoi Gameplay's start request](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/autonomous-scene-start.md)

In the previous example, add this block after building `arguments` and before
calling `request`. This example uses three common action IDs so it can work
with packs that supply different combinations of those activities.

```lua
local foreplay = {
    any_actions = {"handjob", "fellatio"},
    excluded_actions = {"vaginal_sex"},
}
local coitus = {any_actions = {"vaginal_sex"}}

arguments.search = {any_actions = {"handjob", "fellatio", "vaginal_sex"}}
arguments.stages = 4
arguments.stage_progress = "fastest"
arguments.stage_priorities = {
    {stage = 1, matches = {foreplay, coitus}},
    {stage = 2, matches = {foreplay, coitus}},
    {stage = 3, matches = {coitus, foreplay}},
    {stage = 4, matches = {coitus, foreplay}},
}
```

Check `autonomous_stage_progress`, `autonomous_stage_priorities` and
`autonomous_joint_goal_routes` in the version reply for this setup. With four
stages, the leading goal makes later stages due at 25%, 50% and 75%. Ending
still requires both goals. A stage can keep the current loop or pick another
reachable loop. Four stages can play four different loops, fewer loops, or a
single loop that lets both participants finish.

For example, if a pack supplies only one compatible coitus loop, the second
preference can make it the opening too. If a foreplay loop advances the
meters but cannot finish both goals, SceneZOI looks for a route that can
finish the remaining goals. A disconnected coitus loop is unavailable to
that route, but SceneZOI can start from it if it can finish both goals. Use
`required_stages` only when an activity must actually play for the plan to
count as complete. Use `auto_restrictions` for rules that apply during Auto-mode
and lifetime `restrictions` for rules that also apply to manual navigation.
[Stage priorities and routes](addons.md#acceptance-progress-and-results)

Before sending an invitation, preflight the plan with `validate_start` and
`start_mode = "start_autonomous_scene"`. On a current host, check
`reply.ok`, `reply.result.valid` and `route_uncertain`. A successful, proven
route can reach every goal together with the selected Zois, roles and venue.
`no_matching_scenes` means the entry search came up empty.
`goal_unreachable` means the available plan cannot complete its goals.
`route_uncertain` means the check could not prove the route. Decide whether
to try another venue or report the problem. If the Zois have to walk,
set `check_start_distance = false` on the first preflight. Run a new preflight
with the distance check enabled after both Zois arrive.
[No-match handling](#handle-a-start-with-no-matching-scene) ·
[HZoi Gameplay's plan builder](https://github.com/acepleiades/HZoi-Gameplay/blob/main/prototype/queen-bed/HZoiGameplay_4BD2AC16/lua/B2/EncounterArguments.lua)

## Use a bed, sofa or a different body

For furniture scenes, call `find_furniture` with the intended `participants`
and a suitable `scene_id`. Pass the returned `furniture_id` to your start.
For a sofa, also pass `furniture_pair_id`: it identifies two adjacent seats,
leaving the rest available. Preflight is a check, not a reservation.
[Furniture discovery](addon-controls.md#starting-and-finding)

If players should start an encounter from a furniture menu, declare an
`interaction_menu` UI Mod trigger with `"id": "scenezoi_furniture"`,
`"target": "object"` and your own `label_key`. SceneZOI shows that entry on
objects with a supported bed or sofa profile, including sofas it discovers
from native sitting slots. Add `"filter": {"objectCategory": ["Bed", "Sofa"]}`
to have inZOI skip the entry when it opens menus for other kinds of furniture.
In this filter, `objectCategory` reads the object's inZOI `filterCategory`.
Set that field to `Bed` or `Sofa` when creating these objects in ModKit.
The entry uses the ModKit icon on the left. Your trigger still handles the click. Pass its
`targetEntityId` to your add-on and check availability for the chosen Zois
before requesting playback. [Furniture profiles](furniture.md)

If your interaction needs a localized caption or a fallback icon, register the
row with SceneZOI instead of searching for its widget from your add-on. Check
`get_version.features.shared_interaction_menu == 1`. Add an
`interaction_menu` declaration to the same native declaration table used by
content packs. Its `data.entries` list can style entries in both native menus.
For example:

```json
{
  "entries": [
    {
      "id": "_UIMod_MyAddOn_12345678/venue~scenezoi_furniture",
      "menu": "object",
      "label": "Invite Here",
      "translations": { "fr-fr": "Inviter ici" }
    }
  ]
}
```

For a native interaction use its exact interaction bag ID. Set `menu` to
`object` for furniture or ground, or `talk` for the conversation tray. Use
lowercase locale keys and supply an English fallback in `label`. An optional
object `icon` supplies a texture only when the native icon is missing.
Object rows can also declare `mood_locks` using the native emotion IDs that
disable the interaction at intensity 3 or higher. Keep the same restriction
in the code that accepts the click. If the game has no tooltip for a mood,
you can supply a fallback in `data.mood_tooltip` with its own `label` and
`translations`. The declaration styles the row during
the shared menu pass. Your add-on still handles invitations, eligibility
and gameplay outcomes. HZoi Gameplay uses this for its bed, sofa, ground and
Romance menu options. Its walkthrough shows the native picker handoff and
where to recheck the chosen partner and seat pair.
[Menus and venue checks in HZoi Gameplay](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/gameplay-authoring.md#add-the-interaction-and-get-an-answer)

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
not permanent save data. HZoi Gameplay records each participant's task
completions and uses confirmed cleanup to apply relationship changes.
[Outcomes and history](addon-controls.md#observation-and-outcomes)
· [HZoi Gameplay's encounter ledger](https://github.com/acepleiades/HZoi-Gameplay/blob/main/prototype/queen-bed/HZoiGameplay_4BD2AC16/lua/B2/EncounterLedger.lua)

## A romantic partner catches the encounter

For example, Zoi A and Zoi B are having sex, and A's romantic partner, Zoi C,
walks into the room. Your mod should establish all three facts: a sexual action
is currently playing, C has the relevant relationship with A, and C can actually
witness it. Being on the same property is not enough to establish that C saw it.

An add-on can observe sessions started manually or by another mod. Request
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

This is a native game call, separate from `client:request`. Your mod selects C
using its own relationship and witness checks, then delivers the notification
to C. Direct delivery skips the normal broadcast's range and line-of-sight
selection; those checks belong in your witness detection.

The ModKit data checked for this guide connects the notification to:

| Native data | What it does |
| --- | --- |
| `HowlingEffect/Effect_Affair_Confirmed` | Runs `Howling_Affair_Confirmed_React` with Self = witness and Target = cheater, and attempts a trait-appropriate native interaction. |
| `Script_Howling/Howling_Affair_Confirmed_React` | Records cheating milestones and relationship history, adds `Watch_Cheat` from witness to cheater and `Witnessing_Cheating` in the reverse direction, and applies the native trait-specific reactions and buffs. |

In the current data, the non-gloating branch sets Romance and Family
relationship values to **−100**. This is the game's
confirmed-affair consequence, not merely an angry animation. The script also
has its own eligibility conditions, including `IsLovable`.

The handler returns a boolean. A `true` result means it processed a native
effect, not that every scripted branch ran or a confrontation finished.
Cooldowns, current activity and missing native data can prevent delivery.
Log the result and inspect relationship flags and records when testing. Native
cooldowns remain in effect, so log a refusal rather than retrying every frame.

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

For a working implementation, HZoi Gameplay traces around walls and doors,
records who caught whom, and delivers the native reaction after restoration.
[Witness and cheating implementation](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/gameplay-authoring.md#handle-witnesses-and-interruptions)

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

The [vampire mod Q&A](gameplay-mod-ideas.md#how-would-you-create-a-vampire-mod-for-scenezoi)
shows how to keep the player's choice to stop feeding separate from the
feeding and blood-depletion meters.

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
