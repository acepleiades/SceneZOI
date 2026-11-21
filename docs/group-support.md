# Participants, group scenes and starting a session

<a id="fixed-membership-scenes-and-manual-entry"></a>

Use one named role for every Zoi in the animation. A solo masturbation scene
needs one role, a couple scene needs two, and a three-person scene needs three.
Same-body pairs and larger groups use the same system; the available clips and
scene declarations determine which groups can play.

The roster stays fixed until Exit. Every connected scene keeps the same roles,
even if a different Zoi takes the lead. To add or remove a participant, end that
session and start one with the new roster.

## Example role declarations

This fragment describes a three-person scene. Put it in a scene file alongside
its ID, duration, frame rate and navigation, and replace the illustrative paths:

```json
"participants": {
  "male": {"body": "male"},
  "female": {"body": "female"},
  "second_female": {"body": "female"}
},
"anchor_participant": "male",
"tracks": {
  "male": "/MyPack/Animations/ThreePerson_M.ThreePerson_M",
  "female": "/MyPack/Animations/ThreePerson_F1.ThreePerson_F1",
  "second_female": "/MyPack/Animations/ThreePerson_F2.ThreePerson_F2"
}
```

Roles are stable names, not body types or player/NPC indices. `female` and
`second_female` each require a different Zoi with a compatible appearance body.
Other role names work equally well. Import one body track per role and keep
their timing and common origin aligned. [Exporting participants](first-animation.md#4-export-each-participant)

For a complete two-person example, compare HZoi's
[standing idle](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/scenes/01_standing_idle.json)
with its activity nodes. They preserve role IDs and requirements through
navigation. The reference does not contain authored three-person choreography.

## Solo launcher and debug picker

Use the manual picker to test your pack without writing a gameplay integration:

1. Click the controlled Zoi and choose **Solo SceneZOI session**, below **AI Emote**.
2. In **Scene Settings → Debug**, enable **SceneZOI manual start**. This replaces
   the solo launcher with the picker and enables entries on supported furniture.
3. Select the intended participants. The picker permits one to three total.
   A one-person selection shows **Start Solo** when a compatible start exists.
4. Give your entry loop `starting_hub: true`, or connect it to a compatible
   existing hub. The selected roster must fit every role of an eligible start.

The bundled paired hubs require male/female appearance roles; they do not
provide entry for every possible roster. A same-body pair or three-person
selection needs a pack supplying a matching starting scene. A disabled button
or no-match toast can therefore mean the declarations do not cover that group.
See [entry and extensions](package-split.md#roles-entry-and-extensions).

The picker checks compatibility, loaded Zois, ownership and furniture
availability. Your gameplay mod decides proposal and relationship rules.
Unselecting the controlled Zoi permits an NPC-only session, using **Default NPC
Scene Length**. Larger rosters and other NPC starts use the [public API](addons.md).
The API returns failures for the caller to handle; the manual picker displays
its own notifications. [No-match handling](addon-authoring.md#handle-a-start-with-no-matching-scene)

## Gameplay-group departure

The debug picker makes its controlled requester leave their gameplay group
before opening. After selection it also makes selected NPCs leave theirs.
These are real game-group departures: native rules may dissolve a group or
stop its activity. Cancelling the picker or exiting a scene does not rebuild
the group or resume its old tasks. The direct solo launcher does not perform
this picker departure.

For a gameplay integration, finish conversations, walking and other setup
before requesting playback. Do not rely on the debug picker to choreograph an
encounter. [Plan an encounter](addon-authoring.md#plan-the-encounter)

## Attachments and cleanup

Attachments name their participant role. Two Zois can use independent instances
of the same mesh, with their own animation and materials. Ordinary attachments
can use multiple resources; the current region-replacement adapter allows one
body-region owner per participant. [Appearance choices](appearance-variants.md)

Navigation retains the roster, original outfits, anchor/furniture context and
selected speed. Exit releases the session's attachments and other owned state.
Connected scenes must keep retained attachment owner, mesh and profile identity
compatible. [Compatibility profiles](package-split.md#presentation-and-compatibility-profiles)

## Active-session safeguards

Separate rosters can run concurrent sessions. A Zoi cannot join another while
their existing session is preparing, playing or cleaning up. Check the API's
failure reply; the manual starter gives a toast and leaves the existing session
alone.

Switching the controlled Zoi changes which session the panel shows. Controlling
a Zoi outside every session hides it while the others keep playing. Each
session keeps its own roster and ownership. Furniture also needs enough free
seats for concurrent scenes. [Sofa reservations](furniture.md#sofa-authoring-and-placement)

## Participant task ownership

SceneZOI temporarily disables participant autonomy, clears queued interactions
and cancels current work through the game's cancellation path. It waits for
preparation before starting the animation and keeps unrelated tasks from taking
over during playback. Exit restores the original autonomy, collision and position.
Cancelled interactions are not reconstructed or resumed.

## Testing changes to entry

Test the intended roster through the picker, navigate between its scenes, and
Exit. Check normal movement and clothing restoration afterward. Try a roster
with no matching scene and a participant already in another session; both
should fail without disturbing the active scene. For furniture, also try an
occupied object.

After changing packs, restart the game to load their declarations. Contributors
changing native entry bindings should also follow the
[hot-update checks](development.md#hot-update-readiness) and test a fresh launch.
