# Choose a body and skeletal attachments

Use appearance variants to offer bodies and skeletal attachments that scenes
or gameplay mods can select for an individual Zoi. A pack can offer female bodies with and without a vulva,
several penis sizes, or other skeletal attachments. Explicit selections follow
each Zoi through scene changes, while compatible automatic attachments such as
HZoi's remain available as a fallback.

A **body variant** selects a whole skeletal body mesh. An **attachment variant**
selects a separate skeletal mesh, its binding and optional scene-specific clips.
Both choices follow the assets' native body type, age and life-stage requirements.
An attachment can fit a male body, a female body or both. Selecting it keeps the
scene's role and body-animation requirements in effect. The role can have any
name; it does not have to be called `male` to use male genitals.

Choose the part that matches what you are making:

| I want to… | Start here |
| --- | --- |
| Supply a body or several sizes of male genitals | [Register the assets](#register-the-assets). |
| Prefer a particular variant in my animation's scene data | [Set scene defaults](#set-defaults-for-a-scene). |
| Let my gameplay mod choose for each Zoi | [Choose appearance through the API](#choose-appearance-through-the-api). |
| Port a clip without a male-genitals or tongue animation | [Use attachment rest poses](authoring.md#port-an-animation-without-a-separate-attachment-track). |

Requires SceneZOI **1.5.0 or newer**. Request `get_version` and check
`features.appearance_variants == 1` before using these calls. The `designer` IDs,
`/Designer/...` paths and Zoi IDs below are examples. Replace them with your own
pack, imported assets and participants. First, [set up the SDK client](addon-authoring.md#wire-the-sdk).

## Register the assets

For male genitals, I recommend the standalone **HZoi_MaleAnatomy_v1.2.zip**.
It is the mesh used by HZoi and the supplied Maya and Blender rigs. You can
include your own copy and select it with the variant system below, without
requiring HZoi. [Download and set up your pack](authoring.md#how-do-i-make-my-animation-pack-independent-of-hzois-fallback-penis).

Give each body or attachment size a stable ID in your pack's namespace. Add its
declaration to the pack manifest's existing `data_files` list. File paths are
relative to that manifest and must stay inside its source directory.

```json
{
  "data_files": [
    {"kind": "body_variant", "file": "designer/appearance/female_body.json"},
    {"kind": "body_variant", "file": "designer/appearance/female_plain.json"},
    {"kind": "attachment_variant", "file": "designer/appearance/anatomy_medium.json"},
    {"kind": "attachment_variant", "file": "designer/appearance/anatomy_large.json"}
  ]
}
```

For a female body with integrated anatomy, use this declaration in `female_body.json`.

```json
{
  "schema_version": 1,
  "id": "designer.female_body",
  "label": "Female body with integrated anatomy",
  "body": "female",
  "body_age": "Adult",
  "growth_steps": ["Youth", "Adult"],
  "mesh": "/Designer/Bodies/FemaleBody.FemaleBody"
}
```

Declare the version without a vulva as `designer.female_plain` with its own mesh
path. A body variant supplies the complete body mesh. Its region layout must
support [clothing coverage](#check-mesh-compatibility).

An attachment variant uses the same binding fields as an ordinary attachment.

```json
{
  "schema_version": 1,
  "id": "designer.anatomy_medium",
  "label": "Medium anatomy",
  "body_age": "Adult",
  "growth_steps": ["Youth", "Adult"],
  "attachment": {
    "mesh": "/Designer/Attachments/AnatomyMedium.AnatomyMedium",
    "component": "body",
    "socket": "pelvis",
    "reference_bone": "pelvis",
    "body_profile": "designer.body_region",
    "material_profile": "designer.skin",
    "retain_for_session": true
  },
  "node_animations": {
    "designer.example_loop": "/Designer/Animations/AnatomyLoop.AnatomyLoop"
  }
}
```

Give a larger size its own ID and mesh path, such as `designer.anatomy_large`.
Use `body: "male"` or `body: "female"` if it fits only that native body type.
Omit `body` when it fits both. A compatible penis mesh can therefore be selected
for a female Zoi. Register separate variants when the bodies need different fits.

`body_profile` describes the skin region being replaced; `material_profile`
describes how the attachment matches its skin and hair. Declare profiles that
fit your geometry and materials. Reuse HZoi's profiles only when your assets
follow the same requirements. [Coverage and material profiles](package-split.md#presentation-and-compatibility-profiles)

The body-region patch must also fit the body mesh. When two bodies use the same
region layout but have different crotch shapes, use
[coverage patches fitted to each body](package-split.md#fit-a-coverage-patch-to-another-body).
SceneZOI can select the fitted patch from the body currently rendering without
changing the selected male genitals or their animation tracks.

When migrating an existing anatomy attachment, replace its old direct scene
attachment or `add_attachment` request with variant selection. Keeping both
requests creates two meshes. Ordinary props continue to use their own
attachments. Their mesh name or anchor does not identify them as a region
replacement.

### My replacement appears beside the body's original male genitals

Select the variant in the `body_region` slot and give its attachment a compatible
`body_profile`, as in the declaration above. That profile tells SceneZOI which
body region to hide and which coverage patch to show beneath your mesh. This
works for other packs' meshes and skeletons; it does not depend on HZoi's mesh
name. An explicit replacement also removes the automatic fallback for that Zoi.

`add_attachment` adds an ordinary prop. It does not replace male genitals or
claim the body's crotch region. Using it alongside a selected anatomy variant
can leave both visible. Use `set_appearance` for a replacement, and remove the
old prop request when migrating. Do not hide arbitrary body sections based only
on where an object is attached: a pelvis attachment could also be a prop that
needs the body underneath it.

For a report of two meshes, check `appearance_resolved` for the selected variant,
slot and profile, then `attachment_coverage_ready` for the attachment mesh,
selected patch, hidden section and LOD count. The latter is recorded when the
mask has actually been applied. `body_patch_selected` alone reports selection,
before that readiness check. These records stay in `scenezoi_runtime`.

## Set defaults for a scene

Add `appearance` beside `tracks` in your scene JSON. Its keys are the scene's
participant **roles**. Use a default when the scene needs a particular mesh.

```json
{
  "appearance": {
    "receiving": {
      "body_variant": "designer.female_body",
      "attachment_variants": {"body_region": false}
    },
    "giving": {
      "attachment_variants": {"body_region": "designer.anatomy_medium"}
    }
  }
}
```

The body and attachment slots are independent. In this example, `receiving`
uses the body with integrated anatomy and disables the separate region
attachment. Another Zoi could use a plain body and a separate anatomy mesh.

Use `body_region` for an attachment with a body profile. This slot selects one
region replacement per Zoi and takes priority over automatic coverage
attachments, including HZoi's. Other slots, such as `tongue` or `held_prop`,
select ordinary attachments.

For each body field or attachment slot, SceneZOI checks these choices in order.

1. The explicit API selection for that Zoi in the session.
2. The current scene's `appearance` default for that role.
3. An existing scene attachment or compatible automatic coverage fallback,
   where applicable. Otherwise, the native body or no attachment.

Missing or incompatible optional variants produce a warning and fall back to a
valid choice. Scene defaults are checked on navigation. An explicit API choice
stays until it is changed or cleared, so another pack's scene can keep using
the individual's preferred anatomy.

## Choose appearance through the API

Start operations accept `appearance`, keyed by participant **Zoi ID**. These
choices are independent of the roster and role bindings. This example selects
an attachment for one participant and a body with integrated anatomy for another.

```json
{
  "operation": "start_scene",
  "arguments": {
    "scene_id": "designer.example_loop",
    "initiator": "20522",
    "participants": ["20522", "20526"],
    "appearance": {
      "20522": {
        "attachment_variants": {"body_region": "designer.anatomy_medium"}
      },
      "20526": {
        "body_variant": "designer.female_body",
        "attachment_variants": {"body_region": false}
      }
    }
  }
}
```

For a foreground start, the initiator must be the controlled Zoi. Use
[background entry](addons.md#concurrent-and-background-sessions) for NPCs.
`start_autonomous_scene` uses that path automatically. Only the add-on/client
that started the session can change its appearance selections.

| Operation | Arguments and purpose |
| --- | --- |
| `get_appearance_variants` | `{}` returns `bodies` and `attachments` with registered definitions and compatibility metadata. An optional `body` filter accepts `male` or `female`. |
| `get_appearance` | `{ "session_id": "session.id" }` inspects explicit choices, resolved role details and effective attachment IDs. |
| `set_appearance` | `{ "session_id": "session.id", "appearance": { "20526": { "attachment_variants": { "body_region": "designer.anatomy_large" } } } }` changes supplied choices in a session owned by the caller. |
| `clear_appearance` | `{ "session_id": "session.id", "participant_id": "20526" }` removes that participant's explicit choices and uses the current defaults again. |

To switch a participant to the body with integrated anatomy during playback,
select the body and disable the separate region attachment in the same request:

```lua
client:request(owner, "appearance.integrated_body", "set_appearance", {
    session_id = session_id,
    appearance = {
        ["20526"] = {
            body_variant = "designer.female_body",
            attachment_variants = {body_region = false},
        },
    },
})
```

The value you supply determines whether SceneZOI selects, disables or inherits a choice.

| Value | Result |
| --- | --- |
| Omit a field when starting a session | Use the scene default or normal fallback. |
| `body_variant = false` | Use the native body. |
| `attachment_variants = {body_region = false}` | Disable that attachment slot, including its fallback. |
| Omit a field or slot in `set_appearance` | Keep its existing explicit choice. |
| Call `clear_appearance` for the Zoi | Remove all their explicit choices and inherit the current defaults again. |

Leave a choice out of a new session to retain HZoi's compatible automatic
fallback. Existing coverage declarations appear in `get_appearance_variants`
with `automatic_fallback: true` and can also be selected by ID. For example,
`hzoi.region_attachment` explicitly chooses HZoi's mesh when installed and
compatible. Installing an `attachment_variant` alone does not make it a global
default. Choosing the native body leaves attachment selection independent.

If your gameplay mod remembers each Zoi's preferred body or size, store the
stable variant ID in its own preference data. Check available variants and pass
that choice on later starts. SceneZOI uses these selections for the session.

## Check the result

Wait for `session_started` before using the session ID for appearance changes.
After an accepted `set_appearance` or `clear_appearance`, wait until
`get_appearance.phase` is `ready` before sending another clothing or appearance
change. These operations use the ordinary preparation path.

`get_appearance.resolved` identifies the chosen declaration. Actual mesh checks
can still keep the native body and log a warning, so inspect the visible result
and the diagnostics as well. Listing variants supplies their compatibility
metadata. SceneZOI checks the actual Zoi's native body, age and life stage before
playback, then checks the assets.

| Reply or result | What to check |
| --- | --- |
| `session_not_owned` | Send the change through the add-on/client that started the session. |
| `session_not_ready` | Wait for preparation or the current appearance change to finish. |
| `participant_not_found` | Use a Zoi ID from the session's roster. |
| A request succeeds but a fallback mesh appears | Inspect `get_appearance` and `appearance_variant_warning` in `scene_history.cfg` for the selected ID and the unavailable or incompatible resource. |

For a player report, ask for the complete `scenezoi_runtime` folder. Its rolling
API and scene histories retain the request, resolved choices and fallback
warnings. Follow the later start outcome too; an accepted start has only queued
preparation.

## Ported clips without an attachment track

Leave the scene out of the selected variant's optional `node_animations` map
when you have no attachment clip for it. The attachment resets to its rest pose
for that scene. A missing mapped clip or a duration mismatch also logs a warning
and uses the selected mesh's rest pose. Required body tracks and authored inline
attachments follow the scene's ordinary asset checks. An unavailable clip from
an unselected coverage provider does not hide an otherwise valid scene.

To find a useful angle, open **Attachment pose preview** in Scene Settings. Try
the bone rotations, export `attachment_pose_reference.cfg`, and add the values
to the scene's `attachment_rest_rotations`.
[Porting and pose-preview instructions](authoring.md#port-an-animation-without-a-separate-attachment-track)

The rotations refer to the resolved attachment ID. A selected variant's ID is
its definition ID followed by `.` and the scene role, such as
`designer.anatomy_medium.giving`. Copy the ID from `get_appearance` or the exported
CFG. A compatible clip takes priority over fixed angles. The same workflow
works for tongues and other skeletal attachments.

## Check mesh compatibility

A body variant must use the native character's Skeleton asset and retain its
32 region material-slot names. Their order can differ and extra slots can exist.
SceneZOI maps those names to the game's clothing coverage, so skin hidden by a
shirt, trousers or socks stays hidden after a clothing change. A body with
collapsed or missing region slots falls back to a valid body with a warning.

An attachment uses its own skeleton. Its mesh and animation must agree on that
skeleton and the clip must match the scene's duration. `component` is `body` by
default, or `head` for a head attachment. `socket` and `reference_bone` are
required; the reference bone avoids applying the authored root offset twice.
A head attachment cannot use a body profile, and a material profile requires
a body profile. Similar bone names alone do not establish fit or clip
compatibility.

Automatic coverage rules with a `mesh_name` condition must support both the
captured native mesh and any selected whole body. An unrestricted rule can
still qualify. Register and select a matching attachment variant when your
replacement body needs a particular fit.

Keep variant IDs stable and inside their declaring pack's namespace. Runtime
isolates invalid declarations and reports conflicting copies; it keeps the first
source in deterministic owner, ID and source order. Source builds reject
conflicting copies so authors can correct them before packaging.

## Temporary bodies and save safety

The selection changes the rendered skeletal component through the native mesh
setter and keeps the compatible native animation instance. Clothing rebuilds
reapply the selected temporary mesh after the native body is ready. Exit restores
the current native body, including newer clothing changes. Temporary mesh-merge
flags are restored during cleanup.

SceneZOI keeps the custom mesh out of the saved `Body` and `FinalBody` mesh and
`OverrideMesh` references. Gameplay mods can therefore save a preferred variant
ID without making the character's saved appearance require that temporary mesh.
Another mod's persistent body selection still has its own asset dependency.

During a clothing rebuild, the game's final skin materials can arrive after the
mesh's sections appear. SceneZOI keeps those later native materials in its
restoration snapshot and engine-owned keeper, mapped by slot name. This allows
returning to the native body while a retained attachment continues to match the
Zoi's skin.

Test the following with your own assets before publishing.

1. Select each body and attachment on its supported native body and life stages.
2. Change clothing during playback. Check the body, skin material, coverage and
   single region owner, then navigate into a scene from another pack.
3. Try the native-body and disabled-slot values, clear them, and confirm that
   the expected scene default or coverage fallback returns.
4. Visit a clip with an attachment track and one without. Check the rest pose,
   fixed angles and pose reference export with the selected mesh.
5. Exit normally and confirm appearance and movement are restored.
6. On a disposable save, save with the temporary selection active, close the
   game, disable SceneZOI and the body provider, and reload. Confirm the native
   body is visible. Repeat after a clothing change. The game's missing-mods
   warning is expected. Saving may end a session through normal cleanup.

The retail removal test confirmed that the native body remained visible and
the saved appearance contained no reference to the temporary mesh. For ordinary
removal, Exit, wait for cleanup and save outside scene mode. Other resources
follow the [save recovery contract](tier1-contracts.md#save-and-load-ownership).
