# Tags, actions and calculated content ratings

Optional bounded, namespaced scene/role/action/dictionary `addon_data` is described
in [the add-on controls reference](addon-controls.md#inert-metadata-and-sdk-helpers).

Scene metadata is inert JSON. It describes animations for discovery and session
restrictions; it does not execute gameplay effects or replace existing playback,
task, sound, expression or outfit instructions.

## Registered dictionaries

SceneZOI supplies `packs/scenezoi/metadata/tags.json` and `actions.json`. They are
native `tag_dictionary` and `action_dictionary` declarations contributed through
the same enabled-package Text_UI/Text transport as other content. Third-party
packages can register their own schema-1 dictionaries in the pack manifest.
Paths in `data_files` are relative to that manifest and stay within its directory.

```json
"data_files": [
  {"kind": "tag_dictionary", "file": "author/metadata/tags.json"},
  {"kind": "action_dictionary", "file": "author/metadata/actions.json"}
]
```

For a pack with ID `author`, the tag dictionary could look like this:

```json
{
  "schema_version": 1,
  "id": "author.tags",
  "tags": [
    {
      "id": "author.comforting",
      "aliases": ["author.consoling"],
      "description": "Comforting interaction."
    }
  ]
}
```

An action dictionary uses an `actions` array. Each action requires `id`,
`description` and `content_rating`. Both dictionary types accept optional
`aliases` and namespaced `addon_data`.

```json
{
  "schema_version": 1,
  "id": "author.actions",
  "actions": [
    {
      "id": "author.hand_signal",
      "description": "Gives a hand signal to another participant.",
      "content_rating": "GENERAL"
    }
  ]
}
```

Optional action fields `actor_description`,
`target_description`, `performer_description`, `actor_requirements` and
`target_requirements` explain semantic roles/capabilities. These capability names
are descriptive metadata in v1; no new anatomy-detection system is introduced.
Appearance-body/life-stage/furniture eligibility remains enforced independently.

Core names are global vocabulary. Custom definitions and aliases must use their
owner namespace. Aliases are case-normalized, trimmed, and whitespace/hyphens
normalize to underscores. Canonical IDs are normalized identifiers. Unknown
references fail validation. Ambiguous aliases/conflicting definitions are rejected
by author builds; runtime isolates the conflicting definitions and dependent
scenes, with warnings, independently of load order.

At runtime, SceneZOI merges dictionaries from enabled packs. Scenes that
reference a custom term need its provider enabled. The catalog builder
validates terms against the core dictionaries and the dictionaries supplied
to that build. A native `dependencies` entry alone does not import another
pack's dictionary into a standalone build. For a standalone build, use core
terms or register your own namespaced terms in your manifest.

SceneZOI curates 85 actions using anatomical canonical names, full-word aliases
and the author's reviewed content ratings. Tail-specific vocabulary is excluded.
These definitions describe activity; they do not add assets or gameplay effects.
`blowjob` resolves to `fellatio`;
`rimjob` resolves to `anilingus`; `hugging`, `embrace` and `embracing` resolve to
`hug`. Unused action ratings remain reviewable defaults.

## JSON naming and alias format

Use lowercase words separated by underscores for canonical IDs and aliases:
`anal_fingering`, `finger_anus`, `fingering_anus`, `anus_fingering`. Do not author
spaces, hyphens, camelCase, initials or glued multiword spellings such as
`analfingering` or `fingeranus`. Full-word job compounds are an intentional
exception: `handjob` and `hand_job`, `buttjob` and `butt_job`, `breastjob` and
`breast_job`. Ordinary single words such as `anilingus` remain valid.

Canonical names prefer anatomical/clinical terms. Aliases preserve the same
meaning; broad shorthand such as `sex`, `smothering`, `fingering` or `hj` is not
part of core vocabulary. Holding is not automatically groping. Vulva, vagina,
clitoris, scrotum and testicles are distinct anatomical terms. Authored dictionary
aliases must already use normalized spelling; query normalization remains a
convenience. Neither validator can infer English word boundaries: authors must
follow this convention when adding new single-word-looking IDs.

Custom dictionary IDs/aliases retain their existing owner namespace, for example
`author.gentle_care`. Descriptions and labels use ordinary prose. JSON has no
comments; document the format here rather than adding unsupported fields to a
dictionary. A valid core tag entry is:

```json
{"id":"all_fours","aliases":["on_all_fours","hands_and_knees"],"description":"Posture supported on hands and knees."}
```

## Scene fields

```json
"tags": ["affectionate", "eye_contact"],
"participant_tags": {
  "lead": ["standing"],
  "partner": ["standing"]
},
"actions": [
  {"type": "hug", "actor": "lead", "target": "partner", "performer": "lead"}
]
```

`tags` describes the scene broadly. `participant_tags` maps existing named roles
to registered tags and supports different postures in one scene. Both fields use
the same tag dictionary. They remain separate scopes: a scene tag is not copied
onto its participants, and a role tag is not automatically promoted to the whole
scene. Search uses `required_tags` for the scene and `participant_tags[role]` for
the specific actor. `actions` records directed activities. All role references must exist. Omitted target and performer
default to actor. These names never imply gender, appearance body or player/NPC
ownership.

A hug is one-sided. Mutual hugging is two records, one per direction. No reverse
action is inferred. Performer may equal actor or target; for example an action's
anatomical actor/target assignment can remain fixed while the target performs its
active movement. Duplicate identical canonical action records are rejected.

## Content rating

`content_rating` is **not an authored scene field**. Each action definition must
use the hardcoded enum `GENERAL`, `SUGGESTIVE`, or `EXPLICIT`. The scene's public
rating is the highest of all its actions: GENERAL < SUGGESTIVE < EXPLICIT.
An affectionate tag cannot lower it. Unknown enum values fail validation.

Scenes without actions remain unclassified, not implicitly GENERAL. Scenes omitting optional action metadata
can still load unrestricted, but rating-restricted searches/sessions exclude them.
Authors must describe all rating-relevant activities; omitted activities cannot
affect a derived rating. These labels classify declared actions, not automatically
detected visuals, voice choices or manual clothing changes.

The examples below include the public [neutral scenes](../packs/scenezoi/scenes/)
and [HZoi-Reference](https://github.com/acepleiades/HZoi-Reference). Read the actual [idle metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/01_standing_idle.json#L79),
[mixed-posture metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/03_male_standing_female_kneeling_fellatio.json#L222) and
[rear-scene metadata](https://github.com/acepleiades/HZoi-Reference/blob/45472868392ec78f2a182f88463e1128a3c11042/packs/hzoi/scenes/04_standing_rear.json#L288) alongside the descriptions. These are
adult-content source examples, not framework assets or a grant to reuse them.
The [worked guide](content-examples.md#distinguish-scene-facts-from-role-facts)
traces the two directed hugs and separate scene/role scopes.

| Scenes | Whole-scene tags | Role facts and directed actions |
| --- | --- | --- |
| Framework standing hub; HZoi standing idle | affectionate, standing, eye_contact | Both standing and mutually hugging. Female leans against male, hand on his chest and arm around his hips. |
| Both bed hubs | affectionate, lying | Male supine and looking up; female on her side, leg over his leg, head on his shoulder, hand on his chest and looking at her own hand. Mutual hugs; male holds female waist. |
| HZoi standing handjob | standing, eye_contact, intimate | Female eager/devoted presentation; female-to-male handjob; mutual hugs and waist holding. |
| HZoi standing/kneeling fellatio | eye_contact | Male standing upright and pleased; female kneeling and looking up. Female performs fellatio and holds male penis at its base for positioning. No hug or handjob is inferred. |
| HZoi standing rear | standing | Female facing away and bent forward; male behind her, energetic, performing vaginal penetration and holding her waist and wrist. |

In these examples, the idle and hub scenes are GENERAL and the activity scenes are EXPLICIT.
`fellatio`, `spanking` and `gesture` are not core tags: the first two activities
are represented by actions, and the last was too broad. Static contact such as
`hand_on_partner_chest`, `head_on_partner_shoulder` or `leg_over_partner_leg`
describes a pose. Explicit holding/hugging activity is a directed action.
`holding_penis_at_base` describes support/positioning; it does not imply a handjob.
Mood tags such as `eager`, `devoted`, `pleased` and `intimate` record the author's
description of the presentation, not participant personality or gameplay eligibility.

The existing scene roles happen to be named male/female; the schema supports
arbitrary roles and repeated appearance bodies. Existing asset tracks, alignment,
gaze, sounds and runtime directives were not changed by these annotations.

See [add-on API](addons.md) for queries, random selection and lifetime restrictions.


## Describe the pose, not a culturally named position

Core tags favor observable posture, orientation, relative placement and contact.
A reader or AI speech add-on should be able to combine those facts with directed
actions without knowing an English sexual-position nickname. Named-position
labels vary across communities and are not a universal description of movement.
The core tag dictionary therefore omits `anvil`, `bodyguard`, `butterfly`,
`cowgirl`, `reverse_cowgirl`, `doggy_style`, `mating_press`, `missionary` and
`spooning`, including their position-name aliases. No core query silently expands
those old names into a guessed combination.

This is the framework maintainer's vocabulary preference, not a ban on other
authors' terminology. Enabled mods can contribute their own namespaced tags and
aliases through `tag_dictionary` declarations. A speech add-on may define
`voice_author.reverse_cowgirl`, or derive a localized label from core facts.
Conflicting definitions and unnamespaced custom vocabulary still fail the common
validation rules. Content authors explicitly apply any custom tag; registering a
definition does not automatically classify scenes.

The vocabulary review used 290 OARE and 272 OA3PP scene files as input. Their pack
IDs and legacy concatenated spellings are not universal core vocabulary. The
current dictionary contains 63 tags. Romantic, platonic, affectionate and cuddling
remain separate concepts with no implied hierarchy.

### Author role-specific facts

Use `participant_tags` for each role's posture/contact and `tags` for whole-scene
descriptors. `facing_partner`, `facing_away` and `facing_same_direction` describe
torso orientation, independently of head/gaze or `eye_contact`. `knees_near_chest`,
`knees_near_shoulders` and `thighs_against_torso` refer to that participant's own
body. `on_top`/`on_bottom` describe relative placement, not dominance, gender or
which role performs the movement. Actor/target/performer retain their independent
action meanings; no posture changes those assignments.

For partner-relative tags, the intended partner is the other role in the relevant
directed action. In larger rosters, inspect that action's actor/target to resolve
the pair. Unary participant tags alone cannot represent multiple contradictory
relationships for one role; ambiguous group cases need an add-on's explicit
interpretation or namespaced metadata. No new relational schema or automatic
position classifier is introduced by this vocabulary update.

### Worked descriptions

These are illustrative variants, not universal definitions or visual assertions
about the existing animations. Author only facts actually depicted. Add-ons may
interpret these facts in their own language and terminology.

| Familiar review label | Facts to describe instead |
| --- | --- |
| Mating press | Receiving role `lying_on_back`, `legs_raised`, `knees_near_shoulders`, `thighs_against_torso`; penetrating role `on_top`; directed penetration action. |
| Reverse cowgirl | Receiving role `on_top`, `straddling_partner`, `facing_away`; other role `lying_on_back`, `on_bottom`; performer can be receiving role. Add `kneeling`, `sitting` or leaning tags only for the actual variant. |
| Cowgirl | Receiving role `on_top`, `straddling_partner`, `facing_partner`; other role `lying_on_back`, `on_bottom`. |
| Rear entry on hands and knees | Receiving role `all_fours`, `facing_away`; other role `behind_partner`; specify the actual action separately. |
| Missionary | Receiving role `lying_on_back`, `on_bottom`; other role `on_top`, `between_partner_legs`; torso orientation toward the partner. |
| Butterfly / surface-edge variant | Receiving role `lying_on_back`, `at_surface_edge`, `torso_supported_by_surface`, with the actual leg posture; other role between the partner's legs. |
| Anvil / raised-leg variant | Receiving role `lying_on_back`, `legs_raised`, `knees_near_shoulders`; describe the other role's actual posture and action. |
| Bodyguard / standing rear-contact variant | Both `standing`; one `behind_partner`, optionally `chest_against_partner_back`; other `facing_away`. |
| Spooning / side-by-side contact | Both `lying_on_side`, `facing_same_direction`; one `behind_partner`, optionally `chest_against_partner_back`; the other `in_front_of_partner`. Author a hug/other action only if depicted. |

Full [metadata fragments](examples/descriptive-metadata.json) include nine worked
examples. They contain no animation assets and are not installed playable scenes.
Search uses the same `participant_tags` and `action_filters` predicates as session
restrictions; an add-on can require facts on the penetration target rather than
assuming a female role name or player/NPC status. Missing facts do not match.

`idle` does not imply GENERAL or a starting hub; `transition` does not set node
kind; `undressing` does not change outfits. Tags do not determine content ratings.
Describe what each animation depicts. Registering a tag makes the term
available for authors and queries. To apply it to a scene, include it in
`tags` or `participant_tags`.
