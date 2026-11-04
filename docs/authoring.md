# Production authoring status

Animation rigs and exporters are maintained separately from the framework.
SceneZOI consumes their imported animation assets and declarative scene data.

The Maya rigs/exporter have passed ModKit and in-game tests through SceneZOI.
Paired contact, deliberately touching fingers and synchronized anatomy movement
were visually verified. Measured differences are small; this is not perfect
numerical equivalence. Treat the pipeline as production-ready. Detailed accuracy
checking is optional and off by default; investigate again for a concrete defect.

The exporter installs **inZOI Export** on the **SceneZOI** shelf, identifies the
selected character's export skeleton and supports **Other skeletal mesh** by
selecting an original bone and choosing its skeleton. That mode supports separate
attachments and other skeletal meshes.

The linking tool adds another shelf button. It supplies Max-like editable linking:
a control follows a target bone/control while remaining movable, rotatable and
keyable relative to it. The link uses an appropriate parent space, rather than
constraining the animator control's own transform channels. This is useful for
keeping paired hand contact while breathing or moving.

Body motion exports **80 main movement and twist bones**. The additional reference
bones appear to support body shaping, corrective deformation and procedural systems;
their individual purposes are not all established. `SK_Base` discards certain
animated local translations, which explained the earlier thigh-control mismatch.
Validate the exported joints against the target skeleton's retargeting settings
when investigating a concrete mismatch.

Anatomy controls allow rotation on all three axes, with no independent pelvis
animation. The anatomy pelvis follows the male pelvis in the authoring scene; its
exported pelvis stays fixed. SceneZOI attaches the separate skinned mesh at runtime
and samples its local animation using the participant clock, avoiding doubled
pelvis movement. Skin and main-hair color matching were visually acceptable in the
tested setup, with hair helping conceal the texture seam.

The original standing animation source directory was inventoried directly. Its idle
uses frames 0â€“180 and the three adult sets use 0â€“600, all at 60 fps. The older
Blender test's frame range and filenames must not be substituted for this inventory.


# Scene JSON metadata

Scene schema 3 optionally supports registered `tags`, role-specific
`participant_tags` and directional `actions`. Each action names actor, target and
performer roles; a one-sided hug is one record and a mutual hug is two. Scene
ratings derive from action definitions, so do not author `content_rating` in scene
JSON. See [dictionaries, aliases, role examples and rating rules](scene-metadata.md).
The shared [add-on search and session restrictions](addons.md) consume this data.

# Scene JSON completion responses

Scene schema 3 optionally supports `movement_timing` and `completion_responses[role][task_id]`. Authored task-completion routes take priority, followed by explicitly enabled procedural responses synchronized to uniform frequency/phase or irregular peak markers. Without timing, an enabled slowdown uses its configured general fallback. Generic per-participant bone shaking is separately optional. See [the JSON examples, settings, timing and lifetime contracts](completion-effects.md). Existing scenes need no response metadata. Pack data remains inert; executable behavior belongs to SceneZOI.


# Task-triggered voice JSON

A voice set may declare named `responses` containing one-shot clips. Scene `task_completion_voices[completing_role][task_id]` rules independently name the speaking role, saved voice context, response group, fade duration and priority. The default quarter-second fade interrupts continuous voice, plays one response and then restores normal voice. Higher priority can interrupt a lower-priority line. See [voice JSON, silence, priorities and lifecycle](voices.md#task-triggered-one-shot-voice-responses). All behavior belongs to SceneZOI; content supplies inert settings and audio assets.


## Facial overrides and head attachments

Use named `expressions[role].facial_pose` declarations for fixed partial-face
overrides, with or without an animated expression context. Attachments can choose
`component: "head"` for facial bone binding. See [the schema and examples](facial-poses.md).
