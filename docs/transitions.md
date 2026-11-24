# Connect animations with a one-shot transition

<a id="transition-scenes"></a>

A transition plays once and goes straight into the next scene. For example,
connect a standing idle to a clip where one partner kneels, then enter a looping
fellatio scene. The player does not have to return through a hub between them:

`standing idle → kneel transition → fellatio loop`

Each is a separate scene JSON file. The animation asset needs no special
transition flag; `kind: "transition"` in its scene data controls this behavior.

## Authoring

1. Export the one-shot clips for every participant, and any animated attachments,
   with the same timing. Match the opening pose to the source and the final pose
   to the destination so the cuts make sense.
2. Create the transition node below. Replace its sample paths and destination
   with your actual assets and loop ID.
3. Add a navigation button in the source loop pointing to
   `example.kneel_for_fellatio`. The transition's `destination` points to the
   fellatio loop; that loop can provide its usual navigation.

This is a complete scene-node example, to put in your pack's `scene_directory`:

```json
{
  "id": "example.kneel_for_fellatio",
  "label": "Kneel",
  "kind": "transition",
  "destination": "example.fellatio",
  "duration": 3,
  "fps": 60,
  "participants": {
    "male": {"body": "male"},
    "female": {"body": "female"}
  },
  "anchor_participant": "male",
  "tracks": {
    "male": "/ExamplePack/Animations/Kneel_M.Kneel_M",
    "female": "/ExamplePack/Animations/Kneel_F.Kneel_F"
  },
  "navigation": []
}
```

All connected nodes keep the same role IDs and requirements. If they use
furniture, keep the appropriate furniture declaration and authored plane too.
A transition accepts the usual outfits, attachments, gaze, expressions, voices
and sounds. Its manual `navigation` stays empty; it cannot be a hub or a
`starting_hub`. A loop cannot declare `destination`.

Finite chains of transitions work. Automatic cycles and self-targets are
rejected. The pack build checks known destinations; runtime resolves references
to separately installed packs. An unavailable or incompatible destination can
remove the incoming link, so check the warnings if the button is absent.

## Timing and handoff

Transition time follows both the scene playback selector and the game's pause
and fast-forward controls. A three-second clip takes six seconds at scene 0.5×,
three at 1×, and 1.5 at 2× with the game at Normal speed, plus preparation.
Changing speed affects the remaining playback without restarting the clip.

Body and attachment tracks share the same sample time. The final pose is held
while the destination prepares, then that scene starts at zero. Preparation
does not advance the transition. The handoff retains the selected speed, fixed
roster, anchor, original outfits and task progress.

Manual navigation is locked during the transition. Speed controls and Exit
remain available. If a destination's assets fail at completion, the session
ends with `transition_destination_error` and restores normally rather than
remaining stuck on the last frame.

## Make a transition play in Auto-mode

Connect the source to your one-shot through navigation. When Auto-mode chooses a
destination, it finds the shortest eligible path through those links. It plays
each transition on that path in order and skips loops that are only there to
connect the route, such as idle menus. If you add a shorter direct link to the
destination, Auto-mode can take that link instead of playing the transition.
[Auto-mode routing](addons.md#autonomous-scenes)

## Task and audio behavior

Task progression, decay and completion counts freeze throughout a transition.
They resume under the destination's rules when it is ready. This prevents an
orgasm or another task completion from firing halfway through a short pose
change. Scene voices and sound effects still use their normal playback rules;
freezing tasks does not pause all audio or the native game clock.

## Task-triggered entry

A loop can also enter a transition when a task completes. For example, send
the completing partner into an authored orgasm sequence, then return to an
idle. Set the source loop's `task_completion_routes` to the transition ID.
The task resets and emits its completion event before the transition starts.
[Task routes and failure handling](scene-tasks.md#scene-local-task-completion-routes)

## Events and public state

Gameplay add-ons receive `transition_completed` when the one-shot reaches its
duration, before its destination prepares. It means the clip finished, rather
than confirming the next scene started. Use the normal lifecycle events to
confirm arrival or detect failure. Snapshots include `node_kind` and `destination`.
[API events](addons.md)

## Check the result in game

Enter through the actual source button and watch the transition at 0.5×, 1× and
2×. Pause and resume, then try Exit partway through. Check the opening/final
poses, attachment synchronization and furniture contact. Confirm the destination
begins automatically and task progress stays unchanged during the one-shot.
If preparation is slow, the last pose should hold without looping or jumping.
