# Make scenes for beds and sofas

<a id="furniture-support"></a>

Declare furniture when an animation needs a bed or sofa underneath the Zois.
SceneZOI places the scene on the chosen object and reserves the space it uses.
Your clips still determine the pose and contact: the framework does not reshape
an animation to fit every cushion or mattress.

For a bed scene, connect to the matching single- or queen-bed hub. For a sofa
scene, use `sofa.pair` and author around the midpoint between two neighboring
seats. Other seats remain usable, and a suitable four-seat sofa can host two
separate scenes. Read the [HZoi examples](content-examples.md#add-a-furniture-branch-and-optional-tracks)
alongside the placement rules below.

The debug start entry appears when [manual start is enabled](settings.md#debug-manual-start)
and the selected furniture has an available, compatible starting scene. A
gameplay mod should finish walking and setup before asking for playback.

## Scene and profile data

A scene declares `furniture: {"kind":"bed.single", "surface_height_cm":0}`,
`bed.queen`, or `sofa.pair`. Height describes the support plane in the authored animation, not
the destination's global height. Entry matches furniture kind, available state
and the complete participant roster. Current bundled hubs use adult-compatible
male/female appearance roles; the runtime keeps generic named-role support.

Schema-1 `furniture_profile` declarations contain `id`, `kind`, nonempty unique
native Object row IDs in `objects`, `surface_height_cm`, optional `offset_cm`
with x/y/z and optional `yaw_degrees`. All placement coordinates are centimetres.
Malformed/conflicting declarations are isolated at runtime and rejected by source
builds. Active sessions capture the selected profile. See the public
[profile definitions](../packs/scenezoi/furniture/).

The bundled bed profiles cover declared standard-single, standard-double,
alternate-double, single-futon and double-futon objects/variants. An English catalog
description does not establish bed support. Unknown bed models need tested
profile data. Sofas use the automatic detection described below; their model IDs
do not need to appear in SceneZOI's bundled profiles.

## Example from a bed animation pack

HZoi adds a [single-bed branch](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/05_single_bed_idle.json)
and a [queen-bed branch](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/05_queen_bed_idle.json)
through its [manifest](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi.json). The idle nodes reuse the
framework’s body tracks. The [queen-bed activity](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/08_queen_bed_female_mounted_sex_kissing.json)
uses its own tracks and keeps the hub's `bed.queen` kind, 0 cm authored plane,
and role bindings. This lets players navigate without moving to a different
bed. A corresponding single-bed node can reuse those animation tracks where
they fit.

The [coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/profiles/region_attachment.json)
maps node IDs to the matching attachment animation, including both framework
bed hubs. See [the authoring walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/authoring-walkthrough.md#match-the-furniture-and-the-roster).
The linked JSON describes production HZoi's configuration. The reference clips
are rest-pose placeholders; test movement and furniture contact with your own
compatible clips or the installed player pack.

## Placement and reservation

Current standard-bed support is **68 cm** and futon support **20 cm** above the
furniture ground origin; authored hubs use a 0 cm plane. These are fixed clearance
offsets, not surface-conforming placement. Uneven bedding may have local gaps or
clipping. Only upright, unit-scale furniture is supported; wider beds do not scale Zois.

The selected object ID survives the picker handshake. Entry rechecks current
availability and caches the participants' originals in the save journal before
native preparation. Playback waits for a confirmed native B2 reservation.
Unknown/stale status is not available, and a successful preflight is not a
reservation. A changed, removed, moved or newly occupied object can still reject
entry or request ordinary cleanup. Native occupancy refresh uses a bounded cache.

Reservations have token/owner identity, idempotent retries and independent release
acknowledgements. Cleanup removes only SceneZOI's acquired temporary reason,
preserving assignment/foreign occupancy. Partial acquisitions retain ownership
for retry; participant acknowledgements alone cannot finish Exit while furniture
release remains outstanding. The save journal records the exact object/owner for
recovery. See [lifecycle contracts](tier1-contracts.md).

## Sofa authoring and placement

### Automatic sofa detection

SceneZOI identifies sofas through the native `Object_Sofa` tag or the Object
row's `Sofa` category. Translated names, Blueprint names and mesh filenames do
not determine eligibility. A mod-added sofa using that native classification
and ordinary sofa sitting slots can work without a SceneZOI compatibility patch.

The runtime reads the object's actual slot transforms and activity tags. Normal
adult `Sit` slots identify physical seats. Alternate sitting postures at the same
seat are grouped as aliases, including pass-out markers slightly farther forward.
Prop slots, child-only slots and standing activities do not add seats. Only
adjacent seats facing the same way on one straight support plane form a pair.
The runtime does not join seats diagonally across an L-shaped corner or skip
the middle seat of a three-seater.

The optional measured profiles bundled with SceneZOI remain placement corrections
for the models they describe. They are not an allowlist. Other sofas receive a
profile derived from their native slots, with stable per-object seat/pair IDs.
The same discovery supports the debug picker and furniture API. Discovery runs
in small batches; clicking an object inspects that object immediately. Native
availability still needs its ordinary B2 status reply before entry is offered.

Automatic placement follows the game's ordinary sofa Sit convention: the sitting
surface is 44 cm above the slot's ground plane, and the contact point is 53 cm
behind its approach marker. This measures neither the rendered cushion nor
arbitrary custom sitting animations. A sofa with different cushion geometry or
a different native sitting convention can supply a measured `furniture_profile`
for placement. No furniture profile can make an unsuitable pair fit the animation.

Unusable or ambiguous sofa layouts are excluded safely. Missing parents, nested
slot/socket layouts, unmatched sitting aliases and missing adjacent seats are
reported in `scenezoi_runtime/scene_history.cfg` as furniture discovery warnings.
The simulation rechecks the object's sofa classification and slot geometry before
reservation and on lease heartbeats. A rebuilt layout stops the session and
releases only its captured restrictions; unrelated occupants remain untouched.

### Starting and reserving a pair

A manual sofa start shows a short notification if the selected seats are
unavailable or no starting scene supports the selected Zois. Any entry cleanup
finishes before the panel closes. The diagnostic history keeps the furniture
and reason, including the selected pair when known. Add-on requests keep their
normal API error response; native failures and interruptions after playback
still use the error panel.

Use one paired Maya reference rig and reuse the same animation on any validated
pair of adjacent sitting spots on the same straight run of a sofa. This covers
candidate two-seat and three-seat sofas, the Island Getaway Curtain Sofa and
straight sections of three- and four-seat L-shaped sofas. Choose a pair with
the same facing, place the animation root halfway between the two sitting
spots and face it toward their shared front. Seats on opposite sides of an
L-shaped corner are unsuitable as a pair.

Replace the bed reference with one box from the floor to a representative
sitting-surface height. Measure floor-to-cushion height and usable depth on the
sample sofas. Use their native seated poses to cross-check contact and foot
placement. The box represents the usable surface around one seat pair. Keep
animation contacts independent of arms and backs. The Minimalist Sofa has no
armrests, the Modern Chesterfield has a low back, and the Quilted Pattern
Ottoman includes a seat without back or arm support. Check the Curtain Sofa
separately in-game. The paired Maya sofa reference uses a box 170 cm wide,
55 cm deep and 44 cm high, with the seat surface at Y = 44 cm in Maya.
Use it for authoring and declare `"furniture":{"kind":"sofa.pair","surface_height_cm":44}`
on scenes authored against that box. Placement subtracts this authored height
once when matching the pair to the destination's measured sitting surface.

The 44 cm authoring box does not mean every sofa has the same cushion height.
A profile moves the whole animation; SceneZOI does not fit the hips and feet
independently or change the knee bends to match a shorter seat. Lowering the
root to close a cushion gap also lowers the feet by that amount. Check the
visible cushion, butt and floor contact together. Collision measurements help
locate a surface but do not establish the rendered cushion contact by themselves.

The reservation covers the two selected physical sitting spots and all their
mapped native slots. It leaves other spots available for normal gameplay or
a second scene on a disjoint pair. A four-seat L-shaped sofa can therefore
host two scenes when each occupies a separate straight run. Pairs sharing
even one sitting spot cannot run together. Bed reservations still cover the
whole bed.

SceneZOI reserves sofa slots with the native `Restricted` occupancy reason.
`TryOccupySlot` also checks native activity tags such as `Sit` and `Sit_PassOut`,
which do not describe a SceneZOI animation. The pair lease checks native entity
eligibility and exact slot vacancy, calls native `OccupySlot` for each selected
alias, then verifies the owner and reason and rolls back any claim outside the
pair. This requires no invented native Sit interaction ID.

Heartbeats and repeated acquire requests recheck every reserved native alias.
If an alias disappears, changes owner or gains ordinary occupancy, SceneZOI
stops acknowledging the lease and releases only its captured restrictions.
Foreign occupants and unrelated occupancy reasons are preserved. A changed
ownership state that prevents safe cleanup remains pending and is logged.

A raw native slot is not necessarily a separate seat: one Zoi can hold more
than one slot while sitting, and sofas can expose extra lying or posture
targets. Map each physical spot to its exact native `component_name` and
`slot_name` aliases. Do not infer capacity from raw slot count or reserve the
whole sofa to work around an incomplete mapping. Measure the cushion contact
positions separately: a native Sit slot can be an approach target in front of
the cushion rather than the place where the Zoi actually sits.

An optional measured sofa profile adds `sitting_spots` and `seat_pairs` to the
profile fields above:

```json
{
  "sitting_spots": [
    {"id":"left","run":"front","offset_cm":{"x":-42.5,"y":0,"z":0},"yaw_degrees":0,
     "slots":[{"component_name":"ExactLeftComponent","slot_name":"ExactLeftSlot"}]},
    {"id":"right","run":"front","offset_cm":{"x":42.5,"y":0,"z":0},"yaw_degrees":0,
     "slots":[{"component_name":"ExactRightComponent","slot_name":"ExactRightSlot"}]}
  ],
  "seat_pairs": [{"id":"left_right","label":"Left seats","spots":["left","right"]}]
}
```

This fragment illustrates the schema; the component names and measurements
are placeholders. Add the profile's schema version, ID, `kind:"sofa.pair"`,
object row IDs and measured `surface_height_cm`. Spot offsets are relative
to the furniture origin and its declared surface height. The selected pair's
midpoint supplies the animation root; its shared yaw supplies the facing.
Give each straight section its own `run`. Validation rejects different runs
or facings, duplicate slot mappings and pairs that skip an intermediate seat.
It cannot prove that invented slot names or a claimed straight run match the
game model. Inspect and test each Object row receiving a measured correction.
The optional pair `label` uses the existing localization lookup. Use labels
such as `Left seats` and `Right seats` only when they describe the tested
layout. Otherwise the picker uses localized numbered seat-pair labels.

`find_furniture` returns a row for each supported pair, with `furniture_id`,
`furniture_pair_id`, `sitting_spots` and current availability. Pass both IDs
to a start operation to retain that exact pair through selection and entry.
If an API call omits the pair ID, SceneZOI chooses the first available pair ID
alphabetically. The debug picker asks the player to choose when more than one
pair fits the selected roster; one eligible pair skips that extra step.
The chosen pair is retained and rechecked before starting. Discovery and
preflight do not reserve seats; the native acquisition is still the final
authority if someone starts using them in the meantime.
Pass `participants` to `find_furniture` when checking a particular roster.
An occupied pair can be prepared when every occupant belongs to that roster:
SceneZOI ends their current interactions, brings them to a standing posture,
and waits for confirmed vacancy before reserving the selected slots. Other
Zois are not interrupted to make room.

A selected Zoi may already be sitting on a different object. After the current
task is idle, SceneZOI queues the game's real `Stand` interaction against the
captured source object. This runs the native GetUp animation and transform
restoration; changing the logical posture alone leaves the old motion alive.
Both destination-seat clearing and participant preparation share the same
tracked native queue. It is protected from task cancellation and overlay cuts.
Preparation waits for the complete interaction, Stand, released source claims,
no remaining native posture motion and a stable capsule transform before Ready.
Only an exact slot owned by that Zoi with a native Posture reason qualifies;
bystanders, non-slot postures, vehicle and water movement are left alone.
The old Sit is not restored on Exit, because another Zoi may now own that seat.
Abort/Exit lets an in-flight GetUp finish before spatial restoration. The settled
return transform updates the recovery journal before scene anchoring; original
clothing, body and autonomy snapshots remain unchanged. The preparation log
identifies the source object/slot, queue ID and whether native ownership,
animation or spatial settlement is still preventing readiness.

Exit and failed-start cleanup release only the scene's captured occupancy.
The save journal retains the selected pair and exact native slots so cleanup
can recover after a reload without claiming the spare seats. Test an occupied
pair, both disjoint pairs, ordinary use of a spare spot, navigation, Exit and
reload recovery before publishing a profile.

## Test a furniture profile

Test the actual object in game. Check that the picker offers it when free,
rejects it when occupied, aligns the scene, and lets the next Zoi use it after
Exit. See the [placement](../tests/furniture-placement.lua) and
[lease](../tests/furniture-lease.lua) tests for the underlying rules.

## Check your furniture scene

Test the actual entry button and every connected activity, not just the idle.
Inspect hip height, cushion contact, feet and kneeling partners from several
angles. Try another model of the same furniture kind: matching kind does not
guarantee identical proportions.

For sofas, try free and occupied seat pairs, a third Zoi sitting on a spare seat,
and two separate sessions on a suitable four-seater. A pair cannot skip the
middle seat or cross an L-shaped corner. An unavailable pair should reject
entry without leaving participants owned or a Dismiss panel from a new session.
For an API start, handle the returned failure in your add-on.

After Exit, confirm seats are usable again and participants can move. If entry
is absent, check `starting_hub`, the roster, furniture kind, native sofa
classification or bed profile, and current occupancy before changing clip offsets.
