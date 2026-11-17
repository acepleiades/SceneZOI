# Body and attachment selection

This records the agreed direction for a combined SceneZOI update. These
interfaces are implemented in the local test build. Existing compatible body and attachment assets are
sufficient for development and testing of generic selection. The design can be
implemented independently of VelvetZOI's source and new mesh files.

## Select appearance for each participant

Content packs register attachment variants with namespaced IDs. Each variant
describes its mesh, anchor, compatible appearance, body-region coverage and
material profiles, and available scene animation tracks. Body variants are a
separate resource describing an entire compatible body mesh. The existing
`body_profile` describes a coverage region and patch and keeps that meaning.

The gameplay API supplies selections by Zoi ID when starting a session. A
session operation can change a selection after preparation. Each participant's
selection follows navigation across content packs. Gameplay integrations can
save their own character preferences and pass them on each start.

Resolve a replacement in this order.

1. Explicit API selection for the participant in the session.
2. The current scene's explicit default.
3. A compatible automatic fallback.

HZoi's coverage attachment remains a fallback. Explicit selection resolves
competing attachments for the same participant and region before components
are created. The lifecycle must release the outgoing provider and its coverage
ownership when a replacement becomes ready, including retained attachments.

Body choice and separate anatomy choice are independent. A female appearance
may use a body with integrated anatomy, a body without it, and an optional
compatible attachment. Existing role names, roster membership and animation-body
compatibility continue to govern playback.

An omitted selection requests the ordinary default. An explicit request to use
no replacement needs a distinct representation so automatic fallback does not
undo it. The final API must document this distinction. Several packs providing
fallbacks need a deterministic, documented resolution, with the selected provider
and conflicting candidates logged.

## Preserve selected bodies during appearance refresh

Determine whether VelvetZOI's bodies are native appearance overrides,
replacement garments, or meshes assigned to the rendered component. SceneZOI
uses native clothing and appearance refreshes. A mesh assigned only to the
rendered component can be rebuilt from different native appearance data.
Removing an underwear garment can also cause native default-body normalization.
The supported selection path must survive both forms of appearance refresh.

The selected body is a temporary rendering choice. Do not persist a provider's
mesh in the character's saved appearance, substitute a permanent CAS choice,
or depend on SceneZOI running at load to repair a missing body.

Native investigation found that `FinalBody` is transient, but `RefreshAll`
rebuilds it from saved appearance. A direct `FinalBody.OverrideMesh` write does
not survive that refresh. A source override scoped to `RefreshAll` also resets
on subsequent native updates. Neither route is an implemented solution.

Apply the body mesh override on the existing B1 rendering component after
the native clothing result has settled. Keep the body unmerged through the
existing participant lease, retain native skin material bindings and the native
animation graph, and reapply the selected mesh after a clothing rebuild. Neither
the persistent B1 appearance nor the B2 appearance may contain the custom path.
The native clothing test confirms this retains the current animation instance.
Saving with the selected body active after clothing changes, then loading with
SceneZOI and HZoi disabled, passed: the body remained visible and the native
appearance contained no provider mesh reference. This result covers the temporary
body, not the other scene resources covered by the existing save-recovery contract.

Capture the participant's original relevant appearance values before applying
a selection. Apply the selected body before attachment preparation and wait for
the resolved mesh and stable animation instance. Keep it through clothing
changes and navigation. Restore owned changes on Exit, failed preparation and
save recovery, respecting subsequent changes made by another owner. Capture the
latest native mesh after a clothing rebuild; never recapture a mesh we selected
as the restoration baseline.

If an optional body is unavailable, preserve the character's valid existing
native appearance. Validate the selected body's skeleton, materials and region
layout before applying dependent attachments. Asset availability alone does not
establish compatibility.

## Resolve animation compatibility

Each attachment variant provides its compatible scene-track mappings. Shared
bone names alone do not prove animation compatibility. Validate the animation
skeleton, reference transforms, anchor and scale. A variant without a compatible
clip uses its rest pose and applicable scene-specific bone rotations.

Bone-rotation references and attachment IDs need a documented relationship to
variant selection. Switching providers must not apply angles intended for a
different skeleton without compatibility validation. Scene-specific hard
requirements should be distinguishable from optional preferred variants.

## Investigate solo and concurrent starts

Current standard `start_scene`, `start_random_scene` and `start_at_hub` calls
use foreground entry unless `background: true` is supplied. Foreground entry
requires a controlled initiator and rejects another foreground start.
`start_autonomous_scene` selects the background path automatically.

Background entry supports NPC initiators and disjoint concurrent rosters.
Reusing a Zoi already assigned to a session or a reserved furniture object is
rejected. The initiating participant and the actor carrying an SDK message are
separate identities. Confirm the caller's exact API operation, arguments,
participant IDs and returned rejection code.

Reproduce the reported solo failure with actual one-role scenes. Verify a
controlled solo alongside an NPC solo, two NPC solos, two different household
members, control switches between playing participants, independent Exit, and
refusal of a genuinely shared participant or furniture object. A reproducible
framework fault gets a regression and fix. If these checks pass, document the
working API calls and add any missing diagnostic evidence needed to distinguish
the caller's failure.

## Verification and diagnostics

Test body variants with and without integrated anatomy, different attachment
sizes on multiple participants, HZoi and framework hub navigation, clothes
removed and restored, appearance rebuilds, missing assets, compatible tracks,
rest-pose fallback, interrupted preparation, ordinary Exit and save recovery.
Include HZoi enabled and disabled and simultaneous independent solo sessions.

Use a disposable save to verify the important removal case: confirm the provider
mesh is actually active, save while it is active, close the game, disable SceneZOI
and the provider, then load that save. Confirm the character has a visible native
body without SceneZOI recovery running. Restore the user's original mod state
after this check. An assertion about transient fields alone is insufficient.

Keep evidence in `scenezoi_runtime`. Record requested and selected body and
attachment variants, provider and fallback reason, compatibility failures, and
actual resolved body mesh and relevant native appearance override. For refused
starts, retain the API operation, caller, requested roster and rejection code.
Record changes when the relevant state changes to keep diagnostic volume bounded.

## Current solo verification

Isolated tests exercised the current API gates and runtime lifecycle with native
presentation stubbed. Two distinct one-participant NPC sessions were accepted
and played concurrently. Changing control moved panel focus while the other
session continued. Stopping one left the other playing, and both restored their
resources. The existing foreground and participant-overlap rejections also
behaved as documented. These checks do not establish a native playback failure
in the contributor's game.
