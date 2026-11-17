# Choose a body and skeletal attachments

Use appearance variants when a gameplay mod needs to choose a body or attachment
for an individual Zoi. For example, a pack can offer two compatible female bodies
and several anatomy meshes, while another pack continues to supply its usual
fallback. Installing a fallback pack must not replace an explicit selection.

A **body variant** selects a whole skeletal body mesh. An **attachment variant**
selects a separate skeletal mesh, its binding and optional scene-specific clips.
The choice is independent of the Zoi's gender or the scene role name. Compatibility
still follows the native body type, age and life stage required by the assets.
An attachment may support either body type or both; declare its actual fit.

## Register the assets

Add declarations to your pack's existing `data_files`. Paths are relative to the
pack manifest, inside its source directory. Use your own pack ID as the namespace
and your own imported Unreal object paths.

```json
{
  "data_files": [
    {"kind": "body_variant", "file": "designer/appearance/female_body.json"},
    {"kind": "attachment_variant", "file": "designer/appearance/anatomy.json"}
  ]
}
```

A body variant contains the complete body mesh, not a coverage patch:

```json
{
  "schema_version": 1,
  "id": "designer.female_body",
  "label": "Female body with detailed anatomy",
  "body": "female",
  "body_age": "Adult",
  "growth_steps": ["Youth", "Adult"],
  "mesh": "/Designer/Bodies/FemaleBody.FemaleBody"
}
```

`body` is required and accepts `male` or `female`. Optional `body_age` and
`growth_steps` restrict eligibility further. Match these values to the native
appearance traits your mesh supports. The mesh must use the expected character
skeleton asset as the native character body, and preserve the sections, materials and clothing behavior your pack
depends on. Matching bone names on a different Skeleton asset is insufficient;
the selection cannot retarget an incompatible mesh for you.

Whole-body variants must retain the native body's 32 region material-slot names.
The order can differ and extra slots can exist. SceneZOI uses those names to map
the resolved clothing mask to the chosen body, so skin hidden by a shirt, trousers
or socks stays hidden after clothing changes. A mesh with collapsed or missing
region slots cannot safely reproduce that mask and falls back to a valid body.

An attachment variant uses the same binding fields as an ordinary attachment:

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

Omit `body` only when the attachment fits both supported native body types.
`component` is `body` by default, or `head` for a head attachment. `socket` and
`reference_bone` are required. The reference bone keeps the attachment aligned
without applying its authored root offset twice. An animation map is optional;
each mapped clip must fit that scene's timing and the selected attachment's own
skeleton. Similar bone names alone do not establish compatibility.

If a mapped optional clip is missing or has the wrong duration, SceneZOI logs a
warning and keeps the selected attachment in its rest pose for that scene.
An unavailable clip from an unselected coverage provider does not hide an
otherwise valid scene. Required body tracks and authored inline attachments
still follow the scene's ordinary asset checks.

`body_profile` describes a region replacement and `material_profile` supplies its
material mapping. These IDs reference separate declarations; they do not name a
whole body variant. A material profile requires a body profile, and a head
attachment cannot use a body profile. See
[coverage and material profiles](package-split.md#presentation-and-compatibility-profiles).

Keep each variant's ID stable. Definitions must use their declaring pack's
namespace. Runtime isolates invalid declarations and reports conflicting copies;
it keeps the first source in deterministic owner, ID and source order. Source
builds reject conflicting copies so authors can fix them before packaging.

## Set defaults for a scene

Add `appearance` beside `tracks` in your scene JSON. Its keys are the scene's
participant roles, not Zoi IDs:

```json
{
  "appearance": {
    "receiving": {
      "body_variant": "designer.female_body",
      "attachment_variants": {
        "body_region": "designer.anatomy_medium"
      }
    }
  }
}
```

A selection has two independent parts: `body_variant` and a map of named
`attachment_variants` slots. Use `body_region` for an attachment with a body
profile. Region replacement has a single owner per Zoi, so the selected variant
replaces the automatic region attachment instead of competing with it. Other
slots, such as `tongue` or `held_prop`, can select ordinary attachments. These
meshes need no anatomical classification.

For each field or attachment slot, selection follows this order:

1. An explicit selection supplied by the session's gameplay integration.
2. The current scene's `appearance` default for that role.
3. Existing scene attachments and automatic coverage behavior, where applicable,
   or the native body.

An omitted field inherits the next choice. `body_variant: false` explicitly uses
the native body. An attachment slot set to `false` disables that slot, including
its automatic fallback. These choices remain independent: requesting the native
body does not also disable an anatomy attachment. Scene defaults are evaluated
again on navigation; an explicit session selection remains until changed or
cleared.

Keep scene defaults limited to meshes the scene genuinely needs. Let gameplay
integrations choose an individual Zoi's anatomy without changing otherwise
interchangeable animation clips. A supplied selection must pass compatibility
and asset checks; use the resulting API error or runtime warning to fix missing
IDs, profiles or assets.

Automatic coverage rules with a `mesh_name` condition remain conservative when
a different whole body is selected: the rule must support both the captured
native mesh and the selected mesh. An unrestricted rule can still qualify.
For your own replacement body, register a matching `attachment_variant` and
select it explicitly rather than depending on a legacy mesh-specific fallback.

## Choose appearance through the API

The ordinary version-1 request envelope and SDK generic request method are
unchanged. Start operations accept `appearance`, keyed by participant **Zoi ID**.
The roster and role bindings remain independent of this map:

Check `get_version.features.appearance_variants == 1` before using this feature.

```json
{
  "operation": "start_scene",
  "arguments": {
    "scene_id": "designer.example_loop",
    "initiator": "20522",
    "participants": ["20522", "20526"],
    "appearance": {
      "20526": {
        "body_variant": "designer.female_body",
        "attachment_variants": {
          "body_region": "designer.anatomy_medium"
        }
      }
    }
  }
}
```

Use these operations to inspect or change an existing session:

| Operation | Arguments and purpose |
| --- | --- |
| `get_appearance_variants` | `{}` returns `bodies` and `attachments` with registered definitions and compatibility metadata. An optional `body` filter accepts `male` or `female`. |
| `get_appearance` | `{ "session_id": "session.id" }` inspects explicit choices and resolved role details, including effective attachment IDs. |
| `set_appearance` | `{ "session_id": "session.id", "appearance": { "20526": { "attachment_variants": { "body_region": "designer.anatomy_medium" } } } }` changes explicit choices in a session owned by the caller. |
| `clear_appearance` | `{ "session_id": "session.id", "participant_id": "20526" }` removes that participant's explicit choices, exposing the current scene defaults and automatic fallback again. |

`set_appearance` patches the supplied participant fields and attachment slots.
Omitting a field preserves its existing explicit choice. Use `false` to request
the native body or disable a slot; use `clear_appearance` to inherit again.
Listing variants returns compatibility metadata, not a guarantee that every
listed choice fits a particular Zoi. A declaration-only scene preview has no
actual participant age or life stage. SceneZOI resolves the choices again from
captured native traits before playback, then checks the actual assets.
The API does not save these choices as a permanent character customization.
If your gameplay mod keeps an individual preference, store its stable variant
ID in your own data and supply it on later starts after checking availability.

Existing coverage declarations also appear in the attachment results with
`automatic_fallback: true`. Their registered IDs can be explicitly selected
without republishing the assets as a new variant. Modern `attachment_variant`
definitions do not become automatic global defaults merely by being installed.

Use `set_appearance` for the built-in selection path. `add_attachment` remains
available for an independently owned temporary prop; it is not a preference
that should silently displace another owner's body-region replacement.

When migrating an existing anatomy attachment, replace its old direct scene or
`add_attachment` declaration with the selected variant. Keeping both requests
creates two meshes. Ordinary props remain independent; SceneZOI cannot infer
that a prop is meant to replace a body region from its mesh name or anchor.

## Ported clips without an attachment track

Selecting an anatomy mesh does not require a separate attachment clip. When
the current scene supplies none for that mesh, SceneZOI resets it to its rest
pose rather than carrying the previous scene's attachment animation forward.
Optional `attachment_rest_rotations` can then angle editable bones for that
scene. An actual compatible clip takes precedence over fixed angles.

For example, a port can use its existing body animation, select the desired
anatomy variant, and angle its base bone in Scene Settings. Follow
[port an animation without a separate attachment track](authoring.md#port-an-animation-without-a-separate-attachment-track)
to preview the angles and export `attachment_pose_reference.cfg`. Copy the
resolved attachment ID from that file rather than guessing from the mesh name.
A selected variant's effective ID is its definition ID followed by `.` and the
scene role: `designer.anatomy_medium.receiving` in the examples above.
`get_appearance` also reports the resolved ID. The same workflow applies to
tongues and other skeletal attachments.

## Temporary bodies and save safety

The body override changes the Zoi's rendered skeletal component through the
native mesh setter. It keeps the same compatible skeleton and native animation
instance. It does not rewrite the body mesh choices or `OverrideMesh` references
in `Body` or `FinalBody`. The session temporarily disables mesh merging and
restores those flags during cleanup. Clothing rebuilds reapply the selected
temporary mesh after the native body is ready. Exit restores the current native
body, preserving a newer clothing rebuild rather than forcing an older snapshot.

The game can install its final skin materials after a clothing rebuild has
exposed the new mesh's sections. SceneZOI keeps these later native materials in
the restoration snapshot and its engine-owned keeper, mapped by slot name.
Returning to the native body must not restore an earlier factory material and
prevent a retained attachment from matching the Zoi's skin.

This distinction prevents a scene-only custom mesh from becoming a required
body asset in the player's save. It does not repair a save where a different
mod already selected a missing custom mesh as the persistent body.

Before publishing a pack or this framework change, test all of the following:

1. Select each body and attachment on its supported native body and life stages.
2. Change clothing during playback; check the body, skin material, coverage and
   single region owner. Then navigate into a scene from another pack.
3. Try the native-body and disabled-slot values, clear them, and confirm that
   the expected scene default or coverage fallback returns.
4. Visit a clip with an attachment track and one without. Check the rest pose,
   fixed angles and pose reference export with the selected mesh.
5. Exit normally and confirm appearance and movement are restored.
6. Save with the temporary selection active. Close the game, disable its packs,
   reload that save, and confirm the native body remains available. Repeat the
   save/reload after a clothing change. A save may end the session as part of
   SceneZOI's existing cleanup behavior.

The retail test saved an active temporary body after clothing changes, disabled
SceneZOI and the body provider, and loaded that save. The native body remained
visible; the saved appearance contained no reference to the temporary mesh.
The game's missing-mods warning is expected in this test. This verifies the body
mesh dependency. For ordinary removal of SceneZOI, Exit, wait for cleanup and
save outside scene mode. Other resources still follow the existing
[save recovery contract](tier1-contracts.md#save-and-load-ownership).
