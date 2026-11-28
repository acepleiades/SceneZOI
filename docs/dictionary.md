# SceneZOI dictionary

This guide explains the terms used in SceneZOI's guides, JSON files, and API.
Start here if you're deciding what goes in a scene, what belongs in its pack,
or what a gameplay mod needs to do around it.

## Framework, content, and gameplay

- **Animation framework.** SceneZOI is the system that plays synchronized
  animation tracks on Zois. It also handles placement, navigation, task meters,
  audio, and cleanup when a session ends. SceneZOI includes neutral starting
  scenes that packs can build on.
- **Content pack.** An installed package that supplies assets, SceneZOI data,
  or both. An **animation pack** is a content pack that supplies scenes backed
  by animation tracks. A voice pack can supply voices for scenes from other
  packs. An expression pack can use the game's own facial clips to give those
  same scenes new facial performances.
- **Gameplay add-on.** A mod that decides when to start a session and what
  happens in the game because of it. For example, HZoi supplies animation
  scenes, while HZoi Gameplay handles invitations, witnesses, and relationship
  changes. An add-on can use compatible scenes from any installed pack.
- **Pack manifest and declaration.** The manifest is the pack's index. It
  identifies its scenes, shared sounds, and other data files. A declaration is
  a record with a specific purpose, such as a voice set or furniture profile.
  The build tool turns the source JSON into native `Text_UI` entries that
  SceneZOI discovers from enabled mods. See the
  [packaging workflow](authoring.md#files-and-native-project) and the
  [built-in manifest](../packs/scenezoi.json).

## Sessions, scenes, and participants

- **Session.** One run from start through cleanup. The same two Zois might sit
  together, switch to a sexual activity, and return to the sitting idle in
  one session. SceneZOI keeps the roster, bindings, placement, and progress
  as the session moves through those scenes.
- **Scene, or node.** One entry in a pack, with a stable ID and its own JSON
  file. It describes what plays at that point in the session, including the
  tracks, participants, timing, and any expressions, task changes, or navigation.
  A scene can include separate motion for each Zoi and for an attachment.
- **Track.** One imported animation clip bound to a body or a skeletal mesh.
  The body tracks for a scene share a timeline and coordinate origin so the
  animated Zois line up. See [Make your first animation](first-animation.md).
- **Optional animation tracks.** A scene can use tracks from a separate
  library. Set `hide_if_tracks_missing: true` to show that scene only
  when its required assets load and the clips match its duration. SceneZOI
  hides the scene and the navigation links to it when the check fails.
  [Optional animation assets](authoring.md#optional-animation-assets)
- **Roster, role, and binding.** The roster is the list of Zois in the session.
  A role is an authored name such as `initiator` or `partner`. A binding
  assigns a particular Zoi to that role. Each role declares its appearance
  body requirements separately, so two different roles can use the same body
  type. The roster and bindings stay fixed until Exit. See
  [Participants and group scenes](group-support.md).
- **Loop.** A scene that plays its motion repeatedly until another scene takes
  over or the session ends. Match the final pose to the opening pose so the
  repeat is continuous.
- **Hub and starting hub.** A hub is a scene used as a navigation junction,
  often an idle. A loop marked `starting_hub: true` can be an eligible entry
  for the debug picker. Pack extensions can add navigation choices to an
  existing hub. See the [built-in standing hub](../packs/scenezoi/scenes/standing_idle.json)
  and [hub extensions](package-split.md#roles-entry-and-extensions).
- **One-shot and transition.** A one-shot plays once. For motion, a scene with
  `kind: "transition"` plays once and then hands off to its `destination`.
  For example, a kneeling transition can connect a standing idle to a
  looping activity. A one-shot voice or sound can also play during a loop.
  See [Transitions](transitions.md).
- **Navigation and Auto mode.** Navigation links connect scenes, and players
  can follow the available options. In Auto mode, SceneZOI chooses eligible
  loops for an add-on's plan and plays any authored transitions on the route.
  A hub used only to connect the route adds no idle wait. See
  [Autonomous scenes](addons.md#autonomous-scenes).

## Tasks, goals, and stages

- **Scene task.** Progress tracked per Zoi during a session. A task definition
  gives the meter a maximum, starting value, and decay rate. A scene sets each
  role's gain rate and cap for that task. For example, a scene can raise one
  Zoi's **Excitement** to 100% and cap another's at 50%. A vampire pack can
  define its own Feeding and Blood Depletion tasks. inZOI's action queue
  separately handles native interactions such as walking to a bed. See
  [Scene tasks](scene-tasks.md) and the [shared Excitement definition](../packs/scenezoi/tasks/excitement.json).
- **Completion.** When a task actually reaches its maximum, SceneZOI resets
  its meter and emits `task_completed`. The shared Excitement task supplies
  `orgasm` as its `completion_event` label. Use the completion event to count
  what actually happened, even after the meter resets.
- **Goal.** An add-on's requested number of additional completions for a
  specific Zoi and task. For instance, an encounter can set one Excitement
  completion as the goal for each participant. One Zoi completing twice
  counts toward that Zoi's goal. The partner still has their own goal.
- **Stage.** A step in an Auto plan that can change scene preferences or
  speed. In a four-stage plan, an add-on can make later stages due at 25%,
  50%, and 75% of the leading goal. A stage can continue the current loop,
  and the goals can finish before the last stage. See the
  [Auto progress and result rules](addons.md#acceptance-progress-and-results).
- **Completion effects.** Scene-authored effects for a task finishing. A scene
  might play a sound, ask a Zoi's chosen voice for a reaction, slow the motion,
  shake selected bones, or enter an authored scene through a completion route.
  A gameplay mod can separately use the recorded result for consequences
  such as a relationship change. See [Completion effects](completion-effects.md).

## Describe what happens

- **Tag.** A registered description of the whole scene or one role. Put shared
  facts such as `eye_contact` in `tags`. Put a role's posture such as
  `kneeling` in `participant_tags`. Propose new shared tag definitions in
  [SceneZOI's tag dictionary](../packs/scenezoi/metadata/tags.json).
- **Action.** A directed activity record. It names the action type, the actor,
  the target, and optionally the performer if useful. For a mutual hug, use
  a record in each direction. The performer field lets authors describe who
  does the active movement when that differs from the action's actor. See
  [scene metadata](scene-metadata.md#scene-fields) and the
  [shared action definitions](../packs/scenezoi/metadata/actions.json).
- **Content rating.** Each action definition sets `content_rating` to
  `GENERAL`, `SUGGESTIVE`, or `EXPLICIT`. In the shared dictionary, `hug` is
  GENERAL, `tongue_kiss` is SUGGESTIVE, and `fellatio` is EXPLICIT. The scene
  takes the highest rating of its actions. A scene without actions is
  unclassified and is excluded when a search requires a rating. See
  [Content rating](scene-metadata.md#content-rating).
- **Sexual activity classification.** Some actions also describe the kind of
  sexual activity in `sexual_activity`. The three values are `non_penetrative`
  (such as a handjob), `penetrative_non_coital` (such as fellatio), and `coital`
  (vaginal intercourse). This field helps an add-on choose what fits a stage.
  The action's content rating is a separate field.

Describe what plays and which role does it. An accurate rating lets a
GENERAL-only launcher find compatible scenes. Directed actions let a gameplay
mod tell whether a witness saw an intimate action involving a particular Zoi.
An Auto plan can use activity types and postures to pick a scene that fits.
The framework reads the data authors supply. Undeclared actions cannot guide
those choices. See [a complete metadata example](content-examples.md#distinguish-scene-facts-from-role-facts).

## Voice, sound, and expression

- **Voice archetype.** A family of vocal performances. Think of it as a *kei*
  (系), a type or style such as **Mature**. The idea is to group clips from
  multiple seiyuu or voice actors whose performances fit the same family.
  With one archetype selected for a Zoi, different actors can supply suitable
  performances for different contexts. For HZoi's **Mature** archetype, one
  set names Megu Hiiragi for sex and another names Shinonoi Rin for kissing.
  The reference shows how the sets are assigned using silent placeholders.
  [Sex set](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/voices/set_megu_hiiragi_mature_sex.json) ·
  [Kissing set](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/voices/set_shinonoi_rin_mature_kiss.json)
- **Voice context.** What the scene asks a role to sound like at that moment,
  such as kissing, breathing, or moaning during sex. The player's saved choice
  for the Zoi determines which set supplies that context.
- **Voice set.** A collection of vocal clips for an archetype, a context, and
  a compatible appearance body. A set can also have named one-shot responses
  such as `orgasm` or `partner_orgasm`. A scene can name the completing role
  and a different speaking role, so the partner reacts in their own voice.
  Players assign an archetype and choose a set for each context in
  [Personality Management](playing.md#voice-and-expression-choices).
  See [Make a voice set](voice-set-authoring.md) and
  [voice responses](voices.md#task-triggered-one-shot-voice-responses).
- **Expression context and set.** The scene asks for a facial context such as
  `Pleasure` or `Kiss`. The selected expression set supplies facial clips for
  that context. Two Zois can show different expressions in the same scene.
  [Expressions](expressions.md)
- **Facial pose.** A fixed shape for selected facial joints. It can apply
  on its own or over an expression clip, leaving the other joints free to
  animate. A pose definition supplies the target transforms for compatible
  heads. [Define a facial pose](facial-poses.md#define-a-pose)
- **Mouth pose.** A facial pose that holds a specific mouth shape. SceneZOI's
  bundled rounded O, `scenezoi.open_o`, supplies jaw and lip transforms for
  compatible male and female heads. Select it with `facial_pose` inside the role's
  `expressions` entry. For example, use it with `context: "Pleasure"` so the
  Zoi keeps their chosen expression while the mouth holds the O shape.
  A separate tongue mesh can have its own synchronized attachment track.
  [Use a mouth pose or attach a tongue](facial-poses.md#select-the-pose-and-attach-an-animated-mesh)
- **Gaze.** The eye target for a role, such as the midpoint between a partner's
  eyes. SceneZOI aims the eyes within their native limits. Aim the head and
  neck in the animation itself for targets outside that range.
  [Gaze](gaze.md)
- **Sound effects (SFX).** Scene audio for contact, props, and ambience. A
  scene can choose from a shared sound set or detect contact timing from the
  movement of named bones. A moan put in `sfx` plays the scene's chosen sound
  through the **Sound Effects** slider, bypassing the player's per-Zoi voice
  choice and voice volume. Use a voice context or response for vocal clips
  you want the chosen voice to supply. See [Sound effects](sfx.md).
- **Sound set and emitter.** A sound set lists reusable audio clips. An
  emitter is a scene instruction that chooses the set, where the sound
  comes from, and when it plays. For example, an emitter can chain ambience
  clips or play a contact sound as two bones approach and separate.
  [Sound effects](sfx.md)

## Motion and timing

**Basic cycle** and **gradual cycle** describe layers of animation you author.
The basic cycle is the repeating movement that sets the rhythm, such as one
thrust or stroke. The gradual cycle spans several repeats. A Zoi might lean
forward and back over four strokes or shift their posture across several
thrusts. Export the combined motion as a loop. A four-second loop can contain
four one-second basic cycles and one slower movement that closes at the seam.

In scene JSON, use `movement_timing` to describe the basic rhythm for a
synchronized procedural orgasm response. For a one-second cycle at 60 fps,
frames 0 and 60 match. When the deepest pose is at frame 30, author
`"movement_timing": {"cycles_per_second": 1, "peak_phase": 0.5}`.
In a four-second loop with that rhythm, the deep pose recurs at 0.5, 1.5,
2.5, and 3.5 seconds. If the peak spacing varies, use `peak_times` to list
the actual peak times in seconds at 1× playback.

When Excitement completes and the scene has enabled a slowdown, SceneZOI
uses that timing to slow and hold around the deepest pose. It can add a
separate shake over the animation. It runs the effect on the existing clip,
so one loop can show both the ordinary movement and the orgasm. The slowdown
uses the clip's 1× baseline and follows the game's pause and fast-forward.
An authored completion route can instead play a supplied animation.
See [Completion effects and timing](completion-effects.md#regular-movement-timing)
and the [worked task and response example](content-examples.md#connect-progress-to-independent-responses).

**Scene playback speed** controls how fast the clips play. The **game clock**
controls simulation time, including scene task progress and decay. It also
pauses or fast-forwards the session with the game. Slowing an animation to
0.5× leaves the task rate unchanged.
[Playback controls](playing.md#during-a-session) ·
[Task progression](scene-tasks.md#per-scene-progression)

## Placement, appearance, and the add-on API

- **Anchor.** The position and orientation used to place a scene. A furniture
  scene also declares a supported kind and the surface height in the authored
  clip. **Furniture profiles** connect supported game furniture to placement
  data. A sofa scene uses the midpoint of its selected adjacent seat pair.
  See [Furniture](furniture.md).
- **Body variant and attachment.** A body variant selects a skeletal body mesh.
  An attachment is a separate mesh, such as a tongue or male genitals, with a
  binding and optionally its own animation track. A **coverage patch** fills
  a section of the body hidden for a compatible attachment. See
  [Appearance variants](appearance-variants.md) and [Coverage patches](coverage-patches.md).
- **Attachment rest pose.** The unanimated shape of a skeletal attachment.
  When you port an animation without a compatible attachment track, use the
  mesh's rest pose or set fixed bone angles for that scene with
  `attachment_rest_rotations`. A compatible track takes priority.
  [Ported clips without an attachment track](appearance-variants.md#ported-clips-without-an-attachment-track)
- **Preflight and reservation.** A preflight (`validate_start`) checks
  whether the session can start with the current roster, content and venue.
  SceneZOI rechecks availability during preparation and makes the actual
  reservation then. A seat pair that was free during preflight can be
  occupied by the time the Zois arrive.
  [Starting and finding](addon-controls.md#starting-and-finding) ·
  [Furniture reservations](furniture.md#placement-and-reservation)
- **B1, B2, and the SDK.** B1 is the game's client and presentation environment.
  B2 runs the simulation and native gameplay interactions. Gameplay mods call
  SceneZOI through the public Lua SDK in B2. A request being accepted starts
  the handoff. `session_started` confirms the animation actually began, and
  `session_ended` provides its outcome. See [Add-on authoring](addon-authoring.md)
  and the [API reference](addons.md).
