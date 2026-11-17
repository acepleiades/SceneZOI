# Body, attachment and solo-scene integration questions

> Temporary guide: these questions will be folded into SceneZOI's main authoring documentation.

Use your own body and anatomy meshes, choose them for each Zoi, and start solo
scenes for NPCs. Your mod decides who takes part and which meshes they use.
SceneZOI handles animation playback, clothing changes and restoring the characters
when the scene ends.

Requires SceneZOI **1.5.0 or newer**. Before using these calls, request
`get_version`. Appearance selection requires
`features.appearance_variants == 1`. Background solo scenes require
`features.background_sessions == 1`.

`designer`, `/Designer/...` and the Zoi IDs below are examples. Replace them with
your pack ID, imported Unreal object paths and the Zois taking part. The meshes
in the examples are not included with SceneZOI. First, [set up the SDK client](addon-authoring.md#wire-the-sdk).

## I want my own anatomy meshes to take priority over HZoi. How do I do that?

Give each size or model its own `attachment_variant` declaration. Select its ID
for the Zoi when starting the scene. Use the `body_region` slot for anatomy that
replaces a body region. Your explicit choice takes priority over HZoi's automatic
attachment, so both meshes won't be added at once.

Add the files to your pack manifest's existing `data_files` list:

```json
{
  "data_files": [
    {"kind": "attachment_variant", "file": "designer/appearance/anatomy_medium.json"},
    {"kind": "attachment_variant", "file": "designer/appearance/anatomy_large.json"},
    {"kind": "body_variant", "file": "designer/appearance/female_detailed.json"},
    {"kind": "body_variant", "file": "designer/appearance/female_plain.json"}
  ]
}
```

Example of an attachment variant:

```json
{
  "schema_version": 1,
  "id": "designer.anatomy_medium",
  "label": "Medium anatomy",
  "body_age": "Adult",
  "growth_steps": ["Adult"],
  "attachment": {
    "mesh": "/Designer/Attachments/AnatomyMedium.AnatomyMedium",
    "component": "body",
    "socket": "pelvis",
    "reference_bone": "pelvis",
    "body_profile": "designer.body_region",
    "material_profile": "designer.skin",
    "retain_for_session": true
  }
}
```

Give the other size its own ID and mesh path. `body_profile` describes the skin
region being replaced; `material_profile` describes how to match its skin and
hair. Declare profiles that fit your mesh. Only reuse HZoi's profiles if your
geometry and materials follow the same rules. See [coverage and material profiles](package-split.md#presentation-and-compatibility-profiles).

Select the attachment for a Zoi when starting a scene:

```lua
client:request(owner, "start.with_appearance", "start_scene", {
    scene_id = "designer.example_loop",
    initiator = "20522",
    participants = {"20522", "20526"},
    appearance = {
        ["20522"] = {
            attachment_variants = {body_region = "designer.anatomy_medium"},
        },
    },
})
```

For a normal foreground start, `initiator` must be the controlled Zoi. For NPCs,
use the background start explained below.

Attention: if your mod already adds this mesh through `add_attachment` or a
direct scene attachment, remove that old request when switching to variant
selection. Keeping both requests adds the mesh twice. Ordinary props are still
separate attachments; SceneZOI doesn't assume that every attached mesh replaces
anatomy.

## I want different Zois to use different sizes, including female characters. How do I do that?

Choose a variant for each Zoi ID in the same `appearance` map. For example, one
can use `designer.anatomy_medium`, and another can use `designer.anatomy_large`.
The scene role doesn't have to be named `male` for a Zoi to use an anatomy mesh.

Use `body: "male"` or `body: "female"` if the attachment only fits that body type.
Omit `body` if it fits both. A compatible penis mesh can therefore be attached
to a female character through the same API. If each body needs a different fit,
register a variant for each one.

Attention: the attachment still needs to line up with the body, its anchor and
the scene's motion. Similar bone names don't guarantee compatibility. Set
`body_age` and `growth_steps` to the ages and life stages your assets support.
Choosing an attachment doesn't change the Zoi's body type or make an incompatible
body animation work.

## I want to choose female bodies with and without a vulva, and keep the choice through clothing changes. How do I do that?

Give the body with a vulva and the version without it separate `body_variant`
declarations. Example:

```json
{
  "schema_version": 1,
  "id": "designer.female_detailed",
  "label": "Female body with integrated anatomy",
  "body": "female",
  "body_age": "Adult",
  "growth_steps": ["Adult"],
  "mesh": "/Designer/Bodies/FemaleDetailed.FemaleDetailed"
}
```

Declare `designer.female_plain` with the other mesh path. Choose the body when
starting the scene, or use `set_appearance` to change it during a scene:

```lua
client:request(owner, "appearance.detailed_body", "set_appearance", {
    session_id = session_id,
    appearance = {
        ["20526"] = {
            body_variant = "designer.female_detailed",
            attachment_variants = {body_region = false},
        },
    },
})
```

`body_region = false` disables the separate anatomy attachment. Use this if the
whole body already includes the anatomy you need. You can also choose a plain
body and a separate attachment; the two choices are independent.

SceneZOI reapplies the chosen body after clothing changes and keeps the existing
animation instance. It uses the game's clothing coverage to hide skin under
shirts, trousers and socks. Removing clothes exposes those regions again;
redressing hides them again.

Requirements: the body must use the same Skeleton asset as the native character
and keep its 32 region material-slot names. You can change their order or add
extra slots. A body with collapsed or missing regions cannot follow the clothing
mask and falls back to a valid body, with a warning in the logs. Supply a whole
body mesh here, not the small skin patch used by a `body_profile`.

Only the add-on/client that started the session can change its appearance.
After a change is accepted, wait until `get_appearance.phase` is `ready` before
sending the next clothing or appearance change.

## I want a default body or attachment in a scene JSON, with a safe fallback. How do I do that?

Add `appearance` beside `tracks` in your scene JSON. Use **role names** in the
scene file, and **Zoi IDs** in API calls:

```json
{
  "appearance": {
    "receiving": {
      "body_variant": "designer.female_detailed",
      "attachment_variants": {"body_region": false}
    },
    "giving": {
      "attachment_variants": {"body_region": "designer.anatomy_medium"}
    }
  }
}
```

Use roles that exist in your scene. SceneZOI chooses the body and each attachment
slot in this order:

1. The explicit API choice for that Zoi in the session.
2. The current scene's `appearance` default.
3. The scene's existing attachment or a compatible automatic fallback. Otherwise,
   the native body or no attachment.

If a requested variant is missing or incompatible, SceneZOI logs a warning and
tries the valid defaults. Use `get_appearance` to see which choice was actually
applied.

Keep scene defaults to meshes that the animation needs. Use the
API for a Zoi's preferred body or anatomy, so changing to another pack's scene
doesn't replace that preference. Scene defaults are checked on each navigation;
explicit API choices stay until you change or clear them.

## I want HZoi to remain the fallback when I do not choose anything. How do I do that?

Leave that body or attachment slot out of the new session's `appearance` map.
Existing compatible coverage declarations remain the fallback. Installing an
`attachment_variant` alone doesn't make it the default for every Zoi.

Attention: leaving a choice out, disabling it and clearing it do different things:

| Value | What happens |
| --- | --- |
| Omit a field when starting a session | Use the scene's default or normal fallback. |
| `body_variant = false` | Use the native body. |
| `attachment_variants = {body_region = false}` | Disable that attachment slot, including its fallback. |
| Omit a field in `set_appearance` | Keep its existing explicit choice. |
| Call `clear_appearance` for the Zoi | Remove their explicit choices and use the current defaults again. |

```lua
client:request(owner, "appearance.inherit_again", "clear_appearance", {
    session_id = session_id,
    participant_id = "20526",
})
```

Using the native body doesn't also disable an anatomy attachment. To choose
HZoi explicitly, use `hzoi.region_attachment`, provided it is installed and
compatible with that Zoi.

## I want to remember an individual's choice without making their save depend on my body mesh. How do I do that?

Save the stable variant ID in your gameplay mod's own preference data. Check
available choices with `get_appearance_variants`, then pass the preferred ID on
later starts. Use `get_appearance` to check what was applied.

SceneZOI temporarily changes the rendered body. It doesn't write the custom
mesh into the saved `Body` or `FinalBody` mesh references. Exit restores the
latest native body. The temporary merge flags used for clothing are also restored.

This avoids adding the temporary body mesh as a requirement for the character's
saved appearance. It doesn't repair a save where another mod already selected
a custom mesh as the permanent body.

Test your own assets: save with the selection active, close the game, disable
SceneZOI and the body provider, then load that test save. A missing-mods warning
is expected; the body should still be visible. For ordinary removal, Exit the
scene, wait for cleanup and save outside scene mode first.

## I want to use a ported animation without a separate anatomy clip. How do I do that?

Leave that scene out of the variant's optional `node_animations` map. The
attachment uses its rest pose instead of carrying over the previous scene's clip.

To adjust the angle, open **Attachment pose preview** in Scene Settings. Try the
bone rotations, export the reference values, and add them to the scene's
`attachment_rest_rotations`. See the [porting and pose-preview instructions](authoring.md#port-an-animation-without-a-separate-attachment-track).

Attention: the rotations use the resolved attachment ID. For example,
`designer.anatomy_medium` on role `giving` becomes
`designer.anatomy_medium.giving`. Copy the ID from `get_appearance` or the exported
CFG rather than guessing it.

If a compatible clip is supplied, it takes priority over fixed angles. Only add
clips that fit the attachment's skeleton and the scene's duration. Sharing bone
names doesn't automatically make HZoi's clips compatible with another mesh.

## I want an NPC to start a solo scene. How do I do that?

Use a one-Zoi roster and set `background: true` on `start_scene`,
`start_random_scene` or `start_at_hub`. The initiator must be that loaded,
eligible participant. A foreground start without this flag still requires the
controlled Zoi.

```lua
client:request(owner, "solo.npc_one", "start_scene", {
    scene_id = "scenezoi.solo_idle_female",
    initiator = "20526",
    participants = {"20526"},
    bindings = {female = "20526"},
    background = true,
    lifetime = {deadline_seconds = 120},
})
```

Replace the bundled idle with your installed solo scene. The two-minute lifetime
is only an example; choose the duration your mod needs. Autonomous starts
already use the background path. Supply their usual goals or end policy.

`owner` is the loaded B2 character carrying the SDK message. `initiator` is the
Zoi starting the scene. They can be different characters, and the message carrier
doesn't need to join the scene. Don't add the controlled character to every
roster just because it sends your requests.

## I want another solo scene while one is already playing. How do I do that?

Start another background session with a different participant. You can use the
same SDK client and message carrier. Each session keeps its own participants,
playback, appearance and cleanup. Ending one doesn't end the others.

```lua
client:request(owner, "solo.npc_two", "start_scene", {
    scene_id = "scenezoi.solo_idle_male",
    initiator = "20524",
    participants = {"20524"},
    bindings = {male = "20524"},
    background = true,
    lifetime = {deadline_seconds = 120},
})
```

Wait for each `session_started` event before using its session ID for controls.
`accepted: true` only tells you that the start was queued. The scene panel
follows the controlled Zoi; an NPC-only scene can run without showing a panel.

A Zoi already in another scene is still rejected with `participant_busy`.
Reserved furniture returns `furniture_unavailable`. Read `maximum_npc_sessions`
from `get_version` for the NPC-session limit. `maximum_sessions: 1` describes the
player's single focused session; it doesn't prohibit background sessions.
[Background placement and lifetime](addons.md#concurrent-and-background-sessions)

## I want to find out why my choice or start failed. What should I check?

Read the API reply and the later start outcome. Use a new request ID for each
new operation. Retry the same request with its original ID. A start can be
accepted and still fail during preparation.

| Reply or problem | What to check |
| --- | --- |
| `initiator_not_controlled` | Use the controlled initiator for a foreground start, or the background path for an NPC. |
| `participant_busy` | A requested Zoi is already in another scene. |
| `furniture_unavailable` | The furniture is unavailable or reserved. |
| `no_matching_scenes` | Check installed scenes, body requirements, required assets, furniture and restrictions. |
| `session_not_owned` | Use the add-on/client that started the session for appearance changes. |
| `session_not_ready` | Wait for the current preparation or appearance change to finish. |
| The call succeeded, but a default mesh appears | Use `get_appearance` and read the warning. An optional variant may have fallen back. |

Ask the player for the complete `scenezoi_runtime` folder. The rolling API and
scene histories record requests, rejected starts, resolved appearance and
fallback warnings. A missing optional variant doesn't always make the call fail;
the resolved result and warning explain what happened.

For more details: [Appearance variants](appearance-variants.md),
[API reference](addons.md), [Live controls](addon-controls.md).
