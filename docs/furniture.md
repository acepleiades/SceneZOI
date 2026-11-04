# Furniture support — first bed checkpoint

Runtime `20261103-furniture-fix-1`, UI `20261103-furniture-ui-1`. Furniture is optional, generic session context. This development checkpoint adds separate SceneZOI MF starting hubs for single and queen beds. Both use the same four-second neutral body animation. They have no outgoing navigation or HZoi activity scenes.

## Content and profiles

Scenes add `furniture: {"kind":"bed.single", "surface_height_cm":0}` (or `bed.queen`). The height describes the support plane in the authored animation, not a requested global height. Character entry excludes furniture scenes; furniture entry matches its profile kind and the entire selected roster. SceneZOI still supports arbitrary named roles and repeated bodies; the manual picker retains two or three total Zois and currently only MF hub data matches.

Schema-1 `furniture_profile` declarations are discovered through each enabled package's own native text patch, like other inert contributions. Fields: `id`, `kind`, nonempty unique `objects` (native Object row IDs), `surface_height_cm`, optional `offset_cm` with x/y/z, and optional `yaw_degrees`. All placement coordinates use centimetres. Profiles contain no executable callbacks. Malformed/conflicting profiles warn and isolate; source builds reject them before generated output changes. An active session captures its selected profile.

The initial five profiles group known normal-single, normal-double, alternate-double, single-futon and double-futon objects, including cosmetic variants. Object tags or catalog English descriptions alone do not establish support. Unknown objects require a profile. The object list is explicit compatibility data, not a runtime author whitelist. Other authors can contribute profiles without framework code changes.

The re-exported four-second body and optional attachment clips use a ground-level authored support plane (0 cm). Standard beds use a 68 cm target support plane and futons 20 cm, measured above the furniture ground origin. These are duvet-clearance defaults, not mattress heights or collision bounds. Initial rendered previews covered seven placed objects (Bed02, Bed02_v01, Bed05, Bed01, Bed04, Bed06_v01 and E01_Bed01) at 72/18 cm; the author then requested slightly lower standard-bed and higher futon placement, producing 70/20 cm. Bedding is uneven, so small gaps or local clipping remain possible; these values do not imply surface conformance or universal compatibility. Unit-scale upright furniture only: scaled or tilted furniture is rejected until deliberately supported. Wider beds do not scale the Zois.

## Entry and placement

The controlled-Zoi launch label and furniture launch label are **Start SceneZOI**. The native injected object entry is filtered to loaded profiled furniture with an eligible installed starting hub and a recent B2 availability result. The existing separate launcher, persistent receiver, cold-start readiness handshake, native picker cap, gameplay-group departure and focus policy remain.

The clicked object ID survives picker confirmation and the Start request. Selection rechecks availability; the runtime then acquires a B2 reservation before preparing participants. A bed becoming occupied during the picker must fail without taking it from the current user. Failure after native picker confirmation retains the existing real group-departure policy.

The furniture actor's world position and rotation plus the difference between the profile's support plane and the scene's authored support plane resolve the shared mesh anchor. Existing actor-to-mesh correction and B2 simulation pinning remain. Attachments use their existing participant-local bindings. Moving, unloading or deleting furniture cancels the session with normal cleanup. Navigation, authored task routes and transitions must preserve furniture context; a standing node cannot inherit the bed anchor implicitly.

## Exclusive use and cleanup

B2 checks native `IsInUse`, then reserves an available adult interaction slot with temporary `Restricted` occupancy. Whole-surface `CanOccupySlot` and `CanOccupySlotCheckOnlyEntity` guards prevent native users acquiring another side during that scene. Native assigned sleeping-side ownership is separate and never edited. All participants still own independent character leases; the bed reservation belongs to the session/requester and does not equate scene roster size with native sleeping capacity.

Acquisition and release have token/owner checks, idempotent retries and acknowledgement barriers. Release removes only this acquired temporary reason. Partial native mutation remains owned for cleanup; heartbeat expiry and requester teardown also release reservations. Save/load uses the SDK recovery journal: the recorded owner and object are restored even when native occupancy was saved without a surviving Lua lease. See [save ownership](tier1-contracts.md#save-and-load-ownership). An eight-real-second B2 watchdog protects against a lost B1 host; UI retains its six-second disconnect watchdog. The initial compatibility pass disables furniture scale/tilt rather than stretching characters or guessing transforms.

Native slot guards require both Lua environments to load the new build; restart for this cooked-animation installation. No temporary probes or permanent fixture scenes ship.

## Asset ownership and verification

SceneZOI owns two new neutral body clips plus its two standing clips (four asset packages). The private HZoi validation pack owns the tested bed attachment track (725 asset packages total, still 702 audio assets) and optional mapping to the neutral bed hubs for manual exposure; it supplies no new bed scene and still ships no executable code. Standing content, preferences and credits remain owned as before.

Automated coverage includes profile validation/isolation, separate single/queen eligibility and standing exclusion, clicked-object transport, occupied-bed rejection, foreign/stale/duplicate messages, partial acquisition, release retries, save-owner release, watchdog, real-runtime reserve-before-prepare, release acknowledgement, furniture disappearance and repeat entry. ModKit validation and filtered installation are separate evidence. Native object-menu injection, actual slot exclusion, bed alignment, restored normal furniture interaction and author visual acceptance must be recorded after installation; isolated tests do not establish them.

## First native correction

Furniture-fix-1 replaces an invalid positional reflected-transform call with explicit transform fields. Native tests on a standard single, standard queen and double futon now retain upright, sensible bed coordinates and complete playback/Exit without the reported error. Original participant positions and native reservation release were verified. These direct cfg trials do not establish final user alignment acceptance, all-model coverage or third-Zoi blocked-interaction behavior.

Follow-up `20261103-blink-1`: the author requested normal-bed support at 68 cm; futons remain 20 cm. Both neutral bed hubs target the female's own body `hand_l`; male gaze is omitted and therefore forward. Native eye-only limits still apply. This declaration/Lua-only update was applied and tested live without replacing loaded cooked containers.
