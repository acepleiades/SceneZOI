# Facial poses and head attachments

Runtime `20261104-facial-1` generalizes the accepted fixed O controller. Existing
expression contexts still select looping or sampled facial animation assets.
A named `facial_pose` fixes an arbitrary subset of facial joints on top of that
animation. This is a fixed bone pose, not a new animated-region compositor or a
face-customization/morph editor. Only explicitly listed bones are affected.

## Define a pose

Add an entry to your pack manifest's `data_files`:

```json
{"kind": "facial_pose", "file": "my_pack/facial_poses/tongue_open.json"}
```

Each file contains schema version 1, a namespaced `id`, optional `label`, and a
`poses` object with `female`, `male`, or both. Each body array contains 1–256
unique facial-bone rows. For example, this structural illustration holds a brow;
use measured coordinates appropriate to the actual rig for your own definition:

```json
{
  "schema_version": 1,
  "id": "my_pack.brow_pose",
  "label": "Brow pose",
  "poses": {
    "female": [{
      "bone": "FACIAL_L_Brow",
      "parent": "FACIAL_C_FacialRoot",
      "position": [0, 0, 0],
      "rotation": [0, 0, 0, 1]
    }]
  }
}
```

Bone and parent names must start with `FACIAL_` and must match the live rig.
`position` is the target translation relative to that bone's immediate parent,
in centimetres; `rotation` is its local unit quaternion `[x,y,z,w]`. These are
absolute target local transforms, **not additive offsets**. Capture/export the
evaluated desired pose on a compatible native head; do not guess a jaw angle or
copy world/component coordinates. Source and runtime validators reject unknown
fields, non-finite/out-of-bounds coordinates, non-unit rotations, duplicate joints
and hierarchy cycles. Rows may be unordered; runtime applies skeleton order.

Use the bundled [rounded O](../packs/scenezoi/facial_poses/open_o.json) as a real
reference. Its coordinates are not an automatic fit for every customized face.
Missing definitions, missing body variants or incompatible live skeletons leave
an optional-subsystem diagnostic (`facial_pose_error`) and do not stop the scene.
Malformed files are isolated; conflicting duplicate IDs are rejected. Removing a
pose or switching to one with different bones releases the previous owned entries.

## Select the pose and attach an animated mesh

```json
"expressions": {
  "performer": {"context": "Tongue Out", "facial_pose": "my_pack.tongue_open"}
},
"attachments": {
  "tongue": {
    "participant": "performer",
    "component": "head",
    "socket": "FACIAL_C_Jaw",
    "reference_bone": "tongue_root",
    "mesh": "/MyPack/Tongue.Tongue",
    "animation": "/MyPack/Lick.Lick"
  }
}
```

The references above are illustrative assets, not shipped content. Omit `context`
to use only the fixed pose. Choose an actual exported parent bone and a reference
bone in your mesh's independent skeleton. The reference bind transform is inverted
before attachment, preventing a double root offset. `component` is `body` by
default or `head`; head bindings follow the current head component after an
appearance rebuild. Body-region/material replacement applies only to body bindings.

An attachment's authored animation must match scene duration. It uses the shared
scene time, pause, speed and loop position with native notifies suppressed. It
does not inherit the Zoi skeleton or synthesize tongue motion. Correct mesh rig,
skin weights, attachment alignment and authored animation are the pack author's
responsibility. New components warm up hidden; participants and attachments reveal
at the existing playback barrier. Ownership, retention and retryable cleanup work
as for other attachments. Framework resources contain no tongue/adult geometry.

## Existing scene example

HZoi-Reference's [expression instruction](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L76) selects
`Pleasure` for both roles and `scenezoi.open_o` only for the female role. The
named pose is the public [framework definition](../packs/scenezoi/facial_poses/open_o.json),
not an embedded content-pack controller. This demonstrates context plus pose;
HZoi does not supply a tongue mesh or a head-attachment scene. Its
[body coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/region_attachment.json) illustrates a different binding path.
See the [worked guide](content-examples.md) for the reference's scope and rights.

## Independent add-ons

Negotiate `get_version.features.facial_poses` and `head_attachments`. Use
`get_facial_poses` to inspect installed definitions. `set_expression_override`
accepts `facial_pose` alone, an `expression_set`/`context` pair, or all three.
The latest active caller replaces that participant's expression instruction;
omitted fields are not inherited from the scene. `clear_expression_override`,
lease expiry and Exit release that caller's layer and restore the next effective
instruction. Saved preferences are unchanged. `add_attachment` accepts the same
optional head/body component selection. Both paths use the ordinary engines.

Visual acceptance is still needed for new poses and a real tongue asset. Source
and native validation cannot establish mesh fit, facial appearance or licking
choreography. See [expressions](expressions.md), [authoring](authoring.md) and
[API controls](addon-controls.md).
