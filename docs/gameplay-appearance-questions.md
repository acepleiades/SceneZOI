# Body, attachment and solo-scene integration questions

Use this guide to choose bodies and skeletal attachments for individual Zois,
keep clothing changes working, and start solo scenes for NPCs or several
independent groups. Your mod chooses the meshes and gameplay rules; SceneZOI
handles playback, clothing updates and cleanup.

These examples describe the current development build. Negotiate `get_version`
and check `features.appearance_variants == 1` before making appearance calls.
For background solo starts, check `features.background_sessions == 1`.

`designer` and `/Designer/...` below are placeholders. Replace them with your
pack's actual declaration namespace and imported Unreal object paths. The names
are examples, not assets supplied by SceneZOI. SDK examples assume you have already [wired the client](addon-authoring.md#wire-the-sdk).

## I want my own anatomy meshes to take priority over HZoi. How do I do that?

Register each size or model as an `attachment_variant`, then select its ID for
the individual Zoi through the API. Put a region-replacing anatomy attachment
in the `body_region` slot. SceneZOI selects one owner for that region before
creating its components, so HZoi's automatic attachment does not compete with
your explicit choice.

Add the declaration files to your pack manifest's existing `data_files` array:

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

An attachment declaration looks like this:

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

Give the other size its own ID and mesh path. The referenced `body_profile` and
`material_profile` are separate declarations that must describe your actual
mesh and its skin coverage. Do not copy HZoi's profile IDs unless its geometry
and material contract genuinely apply to your assets.
[Coverage and material profiles](package-split.md#presentation-and-compatibility-profiles)

When starting a scene, supply choices under Zoi IDs:

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

Replace the scene and Zoi IDs with the scene you intend to play and its loaded
participants. The ordinary foreground start requires the controlled Zoi as
initiator. Background starts are described below.

Keep this selection path separate from an old `add_attachment` call or direct
scene attachment that adds the same mesh. Remove that duplicate request when
migrating. Ordinary props remain independent; SceneZOI cannot infer that an
arbitrary prop is meant to replace anatomy.

## I want different Zois to use different sizes, including female characters. How do I do that?

Choose independently for each participant ID in the same `appearance` map.
For example, one Zoi can use `designer.anatomy_medium`, while another uses
`designer.anatomy_large`. The choice does not depend on a role being named
`male`, nor does selecting an attachment change the character's body type or
make a different body animation compatible.

Declare `body: "male"` or `body: "female"` on the variant if the mesh fits only
that native body. Omit `body` only when it actually fits both. This permits a
compatible penis attachment on a female character through the same API. If the fit differs, register separate compatible variants.

The attachment must still align correctly with the target body, its anchor and
the scene motion. Similar bone names do not prove that another mesh or animation
is compatible. Match the native body-age and life-stage restrictions to the
assets you support.

## I want to choose female bodies with and without a vulva, and keep the choice through clothing changes. How do I do that?

Register the body with a vulva and the version without it as separate
`body_variant` declarations. For example, the detailed body file can contain:

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

Declare `designer.female_plain` in the same way with its own mesh. Select the
desired body when starting the scene, or change it in an existing session:

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

Here `body_region = false` deliberately disables a separate region attachment.
Use that when the selected whole body already contains what the scene needs.
Body and attachment choices are independent: you can instead choose a plain
body plus a compatible separate attachment.

SceneZOI reapplies the selected mesh after native clothing updates. It keeps the
existing animation instance and uses the game's resolved clothing coverage, so
skin covered by clothing stays hidden during undressing and redressing.

The body must use the same Skeleton asset as the native character and retain
the native body's 32 region material-slot names. Slots can be reordered and
extra slots can exist. A one-section or incompatible mesh cannot safely follow
the clothing mask and falls back to a valid body with a diagnostic. A whole-body
variant is not the small skin patch used by a `body_profile`.

The changing call must come from the add-on/client that created the session.
Do not use another add-on's integration capabilities to replace its selected
appearance. After an accepted change, wait for `get_appearance.phase` to become
`ready` before issuing another appearance or clothing change.

## I want a default body or attachment in a scene JSON, with a safe fallback. How do I do that?

Add an `appearance` object beside `tracks`. Scene JSON uses **role names**;
API calls use **Zoi IDs**:

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

Use roles that actually exist in that scene. The order is evaluated independently
for the body and each attachment slot:

1. The session's explicit API choice for the Zoi.
2. The current scene's `appearance` default for its role.
3. The scene's existing attachment or a compatible automatic coverage fallback,
   where applicable; otherwise the native body or no attachment.

If a requested variant is missing, unavailable or incompatible, SceneZOI logs a
warning and tries the valid defaults. Listing an ID does not turn an optional
missing asset into a valid choice. Inspect `get_appearance` to see what actually
resolved.

Keep defaults limited to appearance the scene needs. For an individual's
preferred anatomy or body, make the explicit API selection so navigating to
another pack does not replace that preference. A scene's defaults are evaluated
again on navigation; the explicit session selection carries across it.

## I want HZoi to remain the fallback when I do not choose anything. How do I do that?

Omit the body or slot from a new session's `appearance` map. Existing compatible
coverage declarations remain automatic fallbacks. Installing an
`attachment_variant` by itself does not make it a global default.

These values mean different things:

| Choice | Result |
| --- | --- |
| Omit a field on a new start | Inherit the scene's default or normal fallback. |
| `body_variant = false` | Explicitly use the native body. |
| `attachment_variants = {body_region = false}` | Disable that attachment slot, including its automatic fallback. |
| Omit a field in `set_appearance` | Keep its existing explicit selection. |
| `clear_appearance` for the Zoi | Remove that Zoi's explicit choices and inherit again. |

```lua
client:request(owner, "appearance.inherit_again", "clear_appearance", {
    session_id = session_id,
    participant_id = "20526",
})
```

Clearing is different from disabling. Requesting the native body does not also
disable an anatomy attachment. HZoi can be selected explicitly using its
registered `hzoi.region_attachment` ID, but only if it is installed and compatible.

## I want to remember an individual's choice without making their save depend on my body mesh. How do I do that?

Store the stable variant ID in your gameplay mod's own preference data and pass
it to SceneZOI on later starts. Discover available definitions with
`get_appearance_variants`, and inspect `get_appearance` after resolution. Keep
your preference data independent of a permanent CAS/body selection.

SceneZOI applies the body temporarily to the rendered component. It does not put
the custom mesh path into the saved `Body` or `FinalBody` mesh references. It
restores the latest native body on Exit. The session temporarily changes merge
flags to handle clothing and restores those flags during cleanup.

This avoids creating a new missing-body dependency when saving during a scene.
It cannot repair a save where another mod already selected a custom mesh as the
permanent body. Verify your own assets by saving with a selection active, then
loading that test save with SceneZOI and the provider disabled. The game's
missing-mods warning is expected; the body should still be visible. For ordinary
uninstallation, Exit, wait for cleanup and save outside scene mode first.

## I want to use a ported animation without a separate anatomy clip. How do I do that?

Omit the scene from the variant's optional `node_animations`. The attachment
uses its rest pose instead of continuing the previous scene's attachment clip.
If the pose needs a fixed angle, use **Attachment pose preview** in Scene
Settings, export the reference values, then put them into the scene's
`attachment_rest_rotations`.

The values target the resolved attachment ID, not just the selected variant ID.
For example, variant `designer.anatomy_medium` on role `giving` resolves as
`designer.anatomy_medium.giving`. Use the ID returned by `get_appearance` or the
exported CFG rather than guessing it.

A compatible attachment clip takes precedence over fixed angles. Add
`node_animations` only for clips made for that attachment's skeleton and the
scene's duration. Sharing bone names does not automatically make HZoi's clips
fit your own mesh. [Full porting and pose-preview workflow](authoring.md#port-an-animation-without-a-separate-attachment-track)

## I want an NPC to start a solo scene. How do I do that?

Use a one-Zoi roster and `background: true` on `start_scene`,
`start_random_scene` or `start_at_hub`. The initiator must be that loaded,
eligible participant. An ordinary foreground call without the flag still
requires the controlled initiator.

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

Replace the bundled idle with your own installed solo scene. The two-minute
lifetime is an explicit example, not a required duration. Autonomous starts
already use the background path; supply their normal goals or end policy.

`owner` is the loaded B2 character carrying the SDK message.
`arguments.initiator` is the Zoi starting the scene. They need not be the same
Zoi, and the message carrier need not belong to the roster. Do not put the
controlled character into every roster just because it carries your requests.

## I want another solo scene while one is already playing. How do I do that?

Make another background start with a different participant. You can use the
same SDK client and message carrier. Each session has its own roster, playback,
appearance and cleanup. Stopping one does not require stopping the other.

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

Wait for each `session_started`; `accepted: true` only means the start was queued.
Use the resulting session ID for subsequent controls. The panel follows the
controlled Zoi's session and need not be visible for an NPC-only session to play.

Reusing a participant already held by a scene is still refused with
`participant_busy`. Reusing reserved furniture returns `furniture_unavailable`.
NPC-only scenes have the cap returned as `maximum_npc_sessions` by `get_version`.
Do not interpret `maximum_sessions: 1` as a ban on background concurrency: it
describes the player's single focused session.
[Background placement, limits and lifetime](addons.md#concurrent-and-background-sessions)

## I want to find out why my choice or start failed. What should I check?

Read the API reply and later start outcome. Use a new request ID for each new
operation, and retry an identical request only with its original ID. An accepted
start can still fail during preparation.

| Symptom or reply | Check |
| --- | --- |
| `initiator_not_controlled` | An ordinary start needs the controlled initiator; use the background path for an NPC. |
| `participant_busy` | Another scene already holds at least one requested Zoi. |
| `furniture_unavailable` | The requested furniture is unavailable or reserved. |
| `no_matching_scenes` | Installed scenes, role/body requirements, required assets, furniture and restrictions. |
| `session_not_owned` | Appearance changes must use the add-on/client that created the session. |
| `session_not_ready` | Wait for preparation or the previous clothing/appearance edit to finish. |
| The call succeeded but a default mesh appears | Inspect `get_appearance`; an optional variant may have fallen back after a compatibility or asset warning. |

Ask the player for their complete `scenezoi_runtime` folder. Its rolling API and
scene histories record caller requests, rejected starts, resolved appearance and
fallback warnings. A missing optional variant does not necessarily make the
whole API call fail; inspect the resolved selection and diagnostic explanation.

For the full contract, see [appearance variants](appearance-variants.md),
[the API reference](addons.md) and [live controls](addon-controls.md).
