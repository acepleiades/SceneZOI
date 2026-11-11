# Furniture support

Furniture is an optional, generic session context. The framework provides neutral
single-bed and queen-bed hubs using a four-second paired animation. Their source
navigation is empty and enabled packs may contribute compatible content.
The **(Debug) SceneZOI manual start** entry appears when the debug setting is
on and the object has an available profile with a compatible starting scene.
The same checks apply to furniture profiles added later. [Scene Settings](settings.md#debug-manual-start)

## Scene and profile data

A scene declares `furniture: {"kind":"bed.single", "surface_height_cm":0}` or
`bed.queen`. Height describes the support plane in the authored animation, not
the destination's global height. Entry matches furniture kind, available state
and the complete participant roster. Current bundled hubs use adult-compatible
male/female appearance roles; the runtime keeps generic named-role support.

Schema-1 `furniture_profile` declarations contain `id`, `kind`, nonempty unique
native Object row IDs in `objects`, `surface_height_cm`, optional `offset_cm`
with x/y/z and optional `yaw_degrees`. All placement coordinates are centimetres.
Malformed/conflicting declarations are isolated at runtime and rejected by source
builds. Active sessions capture the selected profile. See the public
[profile definitions](../packs/scenezoi/furniture/).

The five bundled profiles cover declared standard-single, standard-double,
alternate-double, single-futon and double-futon objects/variants. An English catalog
description or object tag does not establish support. Unknown models need tested
profile data. Profiles are extensible compatibility data, not an author whitelist.

## Content-pack attachment example

HZoi-Reference's [coverage attachment](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/profiles/region_attachment.json#L20) maps the
same four-second attachment animation to `scenezoi.bed_single_idle` and
`scenezoi.bed_queen_idle`. The body tracks and furniture profiles still come from
the [framework bed scenes](../packs/scenezoi/scenes/). This demonstrates an
optional adult-content pack extending presentation at a furniture hub; it does
not add a bed scene or establish compatibility with a new furniture model.
See [the attachment trace](content-examples.md#trace-an-attachment-through-its-profiles).

## Placement and reservation

Current standard-bed support is **68 cm** and futon support **20 cm** above the
furniture ground origin; authored hubs use a 0 cm plane. These are fixed clearance
offsets, not surface-conforming placement. Uneven bedding may have local gaps or
clipping. Only upright, unit-scale furniture is supported; wider beds do not scale Zois.

The selected object ID survives the picker handshake. Entry rechecks current
availability, then obtains a native B2 reservation before participant mutation.
Unknown/stale status is not available, and a successful preflight is not a
reservation. A changed, removed, moved or newly occupied object can still reject
entry or request ordinary cleanup. Native occupancy refresh uses a bounded cache.

Reservations have token/owner identity, idempotent retries and independent release
acknowledgements. Cleanup removes only SceneZOI's acquired temporary reason,
preserving assignment/foreign occupancy. Partial acquisitions retain ownership
for retry; participant acknowledgements alone cannot finish Exit while furniture
release remains outstanding. The save journal records the exact object/owner for
recovery. See [lifecycle contracts](tier1-contracts.md).

## Verification boundary

Source regressions cover data validation, placement, partial acquisition, delayed
release and recovery. The author reported normal bed behavior in the final joint
pass. Earlier native save/load and API trials included bed cleanup. These do not
establish every object model, menu route or third-party occupancy interaction.
Use [current validation](validation/README.md) for the recorded evidence and keep
new-model visual/occupancy tests separate from schema or asset-readiness checks.
