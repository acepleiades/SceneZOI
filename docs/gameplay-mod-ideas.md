# How would you create a gameplay mod for SceneZOI?

You can add pregnancy, STIs or other consequences to scenes that already
play in your game. You can also start your own encounters, such as a paid
booking or a vampire feeding scene. The examples below show what to listen
for, what to look up in inZOI and where your mod makes the gameplay decisions.

[Pregnancy](#how-would-you-create-a-pregnancy-mod-for-scenezoi) ·
[STIs](#how-would-you-create-an-sti-mod-for-scenezoi) ·
[Prostitution](#how-would-you-create-a-prostitution-mod-for-scenezoi) ·
[Succubi and incubi](#how-would-you-create-a-succubus-or-incubus-mod-for-scenezoi) ·
[Vampires](#how-would-you-create-a-vampire-mod-for-scenezoi)

## Listen to sessions from any add-on

Set up the Lua SDK using the [add-on authoring guide](addon-authoring.md#wire-the-sdk).
This subscription uses `request` and `owner` from that guide. Use
`scope = "all"` to receive events from manual starts, HZoi Gameplay and other
add-ons. Choose only the events your mod needs.

```lua
request(owner, "subscribe", {
    scope = "all",
    events = {
        "session_started", "node_entered", "node_leaving",
        "task_completed", "session_ended",
    },
})
```

Use `session_started` to confirm playback, `node_entered` and `node_leaving`
to follow activity changes, and `task_completed` for the exact moment a Zoi
finishes a task. For consequences that need the Zois back in normal gameplay,
wait for `session_ended` and check `result_facts.cleanup_complete`. If your mod
loads during a session, use `list_sessions` and `get_session` to establish what
is currently running. A snapshot can show a completion count without telling
you what was happening when that completion occurred.

Keep your gameplay records on your side. For a task consequence, use the host
instance, session, participant, task and completion index to tell one event
from another. A booking or a pending native outcome can have its own saved ID
so it settles only once across reloads. SceneZOI retains recent results in the
current host, so resolve missed events promptly.
[Events and ownership](addons.md#events-and-ownership) ·
[Session results and history](addon-controls.md#observation-and-outcomes)

## How would you create a pregnancy mod for SceneZOI?

I would make it a separate add-on that watches SceneZOI sessions. That way,
it can work with **HZoi Gameplay**, other gameplay mods and manual starts.
It needs to know what was happening when the relevant Zoi finished.

### Identify the right completion

Listen for `task_completed` and check `event.task.id == "excitement"`.
Read the directed actions in that event. SceneZOI copies the current scene
before following any completion route. Reading the scene later could give
you the one that played *after* the orgasm.

For vaginal sex, match a `vaginal_sex` action whose **actor** is the completing
Zoi. Its **target** is the receiving Zoi. The SDK resolves role names to
Zoi IDs, so this also works when a scene has more than two roles. Use
`actor` and `target` for this check. `performer` tells you who drives the
movement and can be either Zoi.
[Action fields](scene-metadata.md#scene-fields) · [Completion events](scene-tasks.md#completion-and-subscriptions)

```lua
local Client = require("SceneZOIAddon.Client")

-- Call from the event handler. Return the distinct targets to check.
local function conceptionCandidates(event)
    local targets, seen = {}, {}
    if event.name ~= "task_completed"
        or not event.participant_id or not event.task or event.task.id ~= "excitement" then
        return targets
    end

    for _, action in ipairs(Client.actions(event, event.participant_id)) do
        if action.type == "vaginal_sex" and action.actor == event.participant_id
            and action.target and action.target ~= action.actor and not seen[action.target] then
            targets[#targets + 1] = action.target
            seen[action.target] = true
        end
    end
    return targets
end
```

This finds candidates for your mod's conception rule. A vaginal-sex action
and an orgasm establish what was playing at completion. Internal ejaculation
is a separate detail. A scene may withdraw or route to a separate climax
animation. For packs you've checked, you can choose to treat completion
during particular loops as internal. For stricter support, agree on an
`addon_data` field with pack authors, or propose a shared convention for
completion scenes. Read the annotation from the action or scene that
actually played. [Extension metadata](addon-controls.md#inert-metadata-and-sdk-helpers)

Take a snapshot of protection and fertility at the qualifying completion,
then record the conception roll once per completion and receiving Zoi.
If the protected state is on, skip the roll under this design. A second
contraceptive method can use its own rule. You can choose to start the
native pregnancy after SceneZOI restores the Zois.

### Use inZOI's pregnancy system

Check native eligibility before applying the result. inZOI exposes
`CanPregnancy` for checking a pair and `FB2BioComponent` for reading
pregnancy state. The native condition includes physical sex, existing
pregnancy and household capacity. Check its behavior with your script
context, including autonomous starts. An appearance body or attachment
doesn't determine whether inZOI can represent the pregnancy.
[Native condition](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-condition/cond-canpregnancy/)

A documented Lua entry point is `FB2BioComponent:Pregnancy(FatherEntityId)`
on the receiving Zoi. It has no success return value. Check the native
state afterward and verify the correct parents and pregnancy progression
in a test save. The native script commands also document a **Prepare**
and **Start** sequence. Use the game's pregnancy system so it can carry
the result through save and load.
[Bio component](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b2/components/fb2biocomponent/) ·
[Native pregnancy commands](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-pregnancy/)

### Add the condom control

I would start with a condom button in every **EXPLICIT** scene and have it
on by default. Keep the setting as the participants change positions. Turning
it off affects later activity and completions. If you have a compatible
skeletal mesh variant with a condom, use it to show the choice in the scene.

Two parts of that design are good candidates for a SceneZOI pull request.

- **A slot on the Scene Mode panel.** You can make a separate
  [ModKit UI panel](https://mod-docs.playinzoi.com/docs/modkit-docs/modkit/project/uimod/01-overview/)
  today. Use the focused session and `content_rating` to decide when its
  button applies. For a button that moves, hides and reappears with Scene
  Mode, the framework would need to expose a panel slot or visibility and
  placement state. Session focus alone can't tell you whether the panel is
  hidden behind Game Options.
- **An attachment override that works across add-ons.** A session creator
  can use `set_appearance` to select a registered variant in the Zoi's
  `body_region` attachment slot, then check the effective variant using
  `get_appearance` after preparation. An observer
  can't use it to replace HZoi Gameplay's attachment. An integration with
  the `attachments` capability can add its own component, which could
  work for an overlay fitted to a particular anatomy mesh. A generic
  replacement should use the existing appearance readiness and cleanup
  path, check track and mesh compatibility, and restore the prior variant
  when its owner releases it.
  [Appearance selection](appearance-variants.md#choose-appearance-through-the-api) ·
  [Temporary presentation](addon-controls.md#temporary-presentation)

The protection setting can work before the mesh feature exists. Show the
logical setting and whether the visual is available. A queued swap can
still fail to load. If a pregnancy add-on and an STI add-on both offer
condoms, let them share one protection state and one toggle.
[Propose an API addition](../CONTRIBUTING.md)

A partner could ask to use a condom, ask to remove it, object to a change,
or end the encounter. A risk-taking Zoi could get a thrill and a cautious
Zoi could feel anxious or relieved. Those moodlets can still make sense when
the player switches to a non-coital scene to finish. Keep the reaction to
the decision separate from the chance of pregnancy.
[Native moodlets](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-addbuff/)

## How would you create an STI mod for SceneZOI?

Watch the activities as they play. Transmission can happen without an orgasm,
so an STI mod should follow scene changes and actual contact between the
relevant roles. The same observer can work during HZoi Gameplay, another
add-on's scene or a manual start.

### Model the route of exposure

Start with a few infections. Give each one routes and body sites that match
how it can spread. An EXPLICIT rating tells you how to classify the scene.
The action and its roles tell you which body sites were involved. Read the
infection state of both Zois to decide which could have exposed the other.

| Activity | What to model |
| --- | --- |
| Vaginal or anal sex | Chlamydia and gonorrhea can spread through either. The site exposed depends on the activity and role. [CDC on chlamydia](https://www.cdc.gov/chlamydia/about/index.html) · [CDC on gonorrhea](https://www.cdc.gov/gonorrhea/about/index.html) |
| Oral sex | Gonorrhea, chlamydia, syphilis, herpes and HPV can spread through oral sex. For example, an infection can pass from the genitals to the throat or from the throat to the genitals. HIV risk from oral sex is much lower than from anal or vaginal sex. [CDC on oral sex](https://www.cdc.gov/sti/about/about-sti-risk-and-oral-sex.html) |
| Skin contact involving an affected area | Herpes, HPV and syphilis can spread through contact with an area a condom may leave uncovered. Model coverage where it matters. [CDC prevention guidance](https://www.cdc.gov/std/treatment-guidelines/clinical-primary.htm) |
| Oral–anal contact, if you include it | This route can also transmit hepatitis A and B and some intestinal infections. Give it its own rules if your content describes that contact. [CDC on oral sex](https://www.cdc.gov/sti/about/about-sti-risk-and-oral-sex.html) |

Condoms and other barriers can reduce risk where they cover the relevant
contact. For example, condoms offer protection against infections spread
by genital fluids such as chlamydia and gonorrhea. A condom may cover only
part of the area involved in a skin-contact infection. Other forms of birth
control can prevent pregnancy without providing the same protection from STIs.
Choose probabilities for your game's balance.
[CDC on condoms](https://www.cdc.gov/condom-use/index.html)

Record the action, direction and protection state for each visit. Follow
`node_entered` and `node_leaving`, and use actual playing time to distinguish
an entered scene from a sampled one. For example, compare
`result_facts.playing_game_seconds` in snapshots before and after an observed
interval. It advances during gameplay playback, so a pause doesn't add
exposure. When protection changes, keep the earlier interval and start a new
one. The final `played_scenes` list helps check whether an action played,
but it can't reconstruct every protection change.
[Playback and history fields](addon-controls.md#observation-and-outcomes)

### Make testing and disclosure part of the gameplay

Give Zois a way to book a test, get the result after some game time and
arrange treatment or follow-up. Some infections can be symptomless.
Keep the infection state separate from what a Zoi knows. A result can
say which infection or site was tested and when, so a partner can talk about
their last test rather than having a permanent **Safe** status.
[CDC on testing](https://www.cdc.gov/sti/testing/)

Start with a UI panel for test appointments and results, plus a native
interaction such as **Talk About STI Testing**. A Zoi could share a result,
say they haven't been tested or decline to discuss it. A custom entry on
the native phone would need its own prototype. The [ModKit UI guide](https://mod-docs.playinzoi.com/docs/modkit-docs/modkit/project/uimod/01-overview/)
shows how to build a panel you can use today.

Test both mods with an early Exit, a change of scene immediately before
completion, a three-Zoi session where only two have the relevant contact,
and a protection change mid-scene. Include a manual start and a start from
HZoi Gameplay. Check that a missing result or duplicate event can't apply
the same outcome twice.

## How would you create a prostitution mod for SceneZOI?

Build a booking app where a Zoi can register as a sex worker, go on duty, or
hire a worker. Start with a ModKit UI panel that opens from a keybind or
an interaction. A native phone app entry would need separate verification.
You can use inZOI's custom mobile messages for a booking confirmation or
client reply. [ModKit UI triggers](https://mod-docs.playinzoi.com/docs/modkit-docs/modkit/project/uimod/02-files/#02-3-triggers) ·
[Custom mobile messages](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-custommobilemessage/)

Give each booking an ID and store the worker, client, quoted fee, venue and
any special request. Reuse HZoi Gameplay's approach to invitations, walking
to the venue, preflight and scene start. Your booking rules decide who can
make or accept an offer. Call `validate_start` before confirming a booking
that needs a particular activity or task goal, then recheck the plan when
they arrive. If nothing fits, let the player choose another offer or venue.
[HZoi Gameplay's invitation flow](https://github.com/acepleiades/HZoi-Gameplay/blob/main/docs/gameplay-authoring.md) ·
[Handling a scene that doesn't match](addon-authoring.md#handle-a-start-with-no-matching-scene)

A client could offer a bonus if a particular action actually plays, if the
client completes Excitement, or if both happen. For a required action in
Auto-mode, add a `required_stages` entry with a matching action query. For
a completion requirement, set a goal for the client's Zoi ID. When deciding
the payout, read `result_facts.played_scenes` for actions that played.
Count completed tasks from `task_completed` and reconcile against the
final task counts. A selected animation, a preflight match or a full meter
alone won't earn the bonus. [Autonomous plans](addons.md#autonomous-scenes) ·
[Outcome and playback history](addon-controls.md#observation-and-outcomes)

Settle the booking after `session_ended` and confirmed cleanup. Decide whether
an interrupted booking earns a partial fee. Give each booking one settlement
record and recover missing end events with `get_session_result` while the
host retains a result. The app can show an unresolved booking if the result
or a transfer is uncertain. For the in-game payment, prototype a balance check
on the payer and test the native `ExchangeCurrency` execution, including
which entity pays and who receives the funds. [Currency component](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b2/components/fb2currencycomponent/) ·
[Native currency exchange](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-exchangecurrency/)

For a fixed fee, set the native exchange minimum and maximum to that same
amount. Try it with two separate households and confirm both balances. Keep
the fee and any bonus in the same booking settlement so a retry can't pay
either one again. If the contract says the client must finish *during* a
particular action, compare the action and completing participant in the
same `task_completed` event. A final completion count and a separate list
of played actions can't establish that timing.

Make scams and violence separate booking outcomes. A dishonest client might
refuse to pay, or a risky booking could lead to a confrontation after the
Zois return to normal gameplay. Test the fight interaction or supply your
own encounter. You can give the worker a moodlet to show what happened.
Distinguish those deliberate outcomes from an animation failing to start.
[Native moodlets](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-addbuff/)

## How would you create a succubus or incubus mod for SceneZOI?

Start with a night encounter or a **Summon** ritual on an object. Use the
B2 simulation clock to check the hour. Keep a save-scoped record of which
Zois are succubi or incubi, whether they know, and their powers. That gives
you a playable supernatural Zoi, an NPC who appears at night, and a way for a
Zoi to discover their own nature through a quest or the first time they drain
someone. inZOI's playable ghosts are a useful reference for state-specific
interactions, abilities and feedback. The exposed ghost and life APIs give
you existing behavior to study. A new native life state would be a separate
prototype. [Game clock API](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b2/systems/fb2timemanager/) ·
[Playable ghosts](https://playinzoi.com/en/news/9309) ·
[Life component API](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/luaapi/b2/components/fb2lifecomponent/)

Subscribe to `task_completed` and `session_ended` with `scope = "all"` if
you want this to work during scenes started by another add-on. Match a
supernatural Zoi and a human participant by their IDs and check the active
scene's declared actions before applying a drain. For example, each qualifying
Excitement completion could remove a measured amount of Energy from the human
and grant the succubus or incubus a temporary buff. Record the session,
participant, task ID and completion index so the same completion applies
once. [SceneZOI events](addons.md#events-and-ownership) ·
[How HZoi Gameplay applies native need changes](https://github.com/acepleiades/HZoi-Gameplay/blob/main/prototype/queen-bed/HZoiGameplay_4BD2AC16/lua/B2/EncounterConsequences.lua)

If you want a severe drain to be fatal, track a separate vitality reserve and
decide when it runs out. Queue the outcome from the drain event, ask the scene
to stop, and apply native death after confirmed cleanup once the target is
loaded and alive. Stopping a scene started by another add-on requires the
`interrupt` capability. [Interrupting a session](addon-controls.md#cooperation-between-independent-add-ons) ·
[Native death execution](https://mod-docs.playinzoi.com/docs/modkit-docs/wiki/script-execution/exec-death/)

## How would you create a vampire mod for SceneZOI?

Author a non-sexual feeding encounter using the shared `vampire_biting`
action. It can be GENERAL when all of its actions are GENERAL. Packs can
also add vampire biting to suggestive or explicit scenes and declare the
other actions that occur there. Use separate tasks for the vampire's Feeding
and the target's Blood Depletion, with rates that give the vampire time to
release the target after feeding. [Vampire example](addon-authoring.md#a-vampire-feeding-encounter) ·
[Define a task](scene-tasks.md#register-a-definition)

For a *Vampire: The Masquerade — Bloodlines* style choice, let Feeding
completion fill the vampire's reserve and let the player decide when to
let go. Use `end_policy = {type = "addon"}` and leave Feeding out of the
plan's goals. Handle both task completions in your own code. This keeps
the scene running after the vampire is satisfied.
[End policies](addons.md#end-policies-and-safety-stops) ·
[Task completion and repeated events](scene-tasks.md#completion-and-subscriptions)

### Give the player a reason to stop

Set the task rates so Feeding can finish early, leaving time to let the
target go before Blood Depletion maxes out. Keep the scene open after the
first task completes. On the second task, record which target reached the
limit, end the session and resolve the outcome after cleanup. On an early
Exit, the final task state can tell you how far Blood Depletion got.
Use that to account for the blood taken so far. Decide whether it is enough
to satisfy the vampire and whether the target recovers, passes out or dies.
Keep blood and hunger in your own save data between sessions.

In a test save, try stopping as soon as Feeding completes, continuing
until Blood Depletion completes, and ending early through SceneZOI's
**Exit**. Repeat with the same target to check that your saved blood
reserve and the session meter agree. For a sexual version, add the other
directed actions that actually play so pregnancy, STIs or other observers
can make their own decisions.
