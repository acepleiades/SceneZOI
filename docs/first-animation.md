# Make your first SceneZOI animation

SceneZOI is an agnostic, data-driven animation framework. However, it is the
case that sexual, suggestive and affectionate looping scenes (and transitions
connecting them) are likely to be the main use for SceneZOI animation packs,
because the game's own animation systems do not provide an adequate experience
for that. You can start with the scene you want to make.

The supplied Maya and Blender rigs and exporters have been tested to translate
their exports accurately in game, so don't be afraid of using them to already
try to make the scene you envision.
A separate practice animation is optional. If you prefer to learn the workflow
with a short standing loop before starting a more involved scene, that is fine
too. Either way, check your finished scene in game before publishing it.

I recommend working with an AI agent, especially for your first pack. Give it
this guide, the SceneZOI repository, and access to a working copy of your project.
It can help set up the rigs, inspect odd playback, import FBXs, write scene JSON,
and package the mod. You decide how the animation should look and verify the
result in-game.

For feedback on your animation or help with rigging, export and packaging, ask
in the [OStim/SceneZOI Community Discord server](https://discord.gg/RECvhVaRcU).

## 1. Install the tools and open a rig

Choose one animation editor. Both have ready-made inZOI rigs and exporters.

| Editor | Download and setup |
| --- | --- |
| **Blender** | Download Blender and check the rig post for its supported version. Open a supplied `.blend` animation rig, save a working copy, and install and enable `inzoi_motion_export.py` from Blender's Add-ons preferences. [Blender releases](https://www.blender.org/releases/) · [inZOI Blender rigs and exporter](https://www.patreon.com/skyrimaceanimations/posts/inzoi-blender-172792014) |
| **Maya** | Get Maya from Autodesk. The rigs were authored in Maya 2026. Open the paired `.ma` file and save a working copy. Extract the exporter ZIP and drag `inzoi_animation_export.py` into the viewport to add the **inZOI Export** button to the **SceneZOI** shelf. Use Display Layers to show the controls and meshes you need. For a seated scene, open the paired rig with the furniture reference box. [Autodesk Maya](https://www.autodesk.com/products/maya/free-trial) · [inZOI Maya rigs, exporter and linking tool](https://www.patreon.com/skyrimaceanimations/posts/inzoi-maya-rigs-173172317) |

For import and packaging, install the inZOI ModKit on Windows. Get the packaged
SceneZOI release for testing and the repository source for the authoring tools.
Create and register a separate ModKit project for your pack. [inZOI ModKit](https://store.epicgames.com/p/inzoi-modkit) · [SceneZOI releases](https://github.com/acepleiades/SceneZOI/releases/latest) · [Content-pack setup](authoring.md#files-and-native-project)

### Watch someone animate a rig

These videos use practice rigs. Watch how the animator poses controls, places
keyframes, and checks weight and foot contact. Use the inZOI rig's own exporter
when you get to step 4.

**Blender.** Joey Carlino demonstrates a walk cycle, starting with the rig
controls and contact poses.

[![Watch Joey Carlino animate a Blender character rig](https://i.ytimg.com/vi/nRtT7Gr6S2o/hqdefault.jpg)](https://www.youtube.com/watch?v=nRtT7Gr6S2o)

**Maya.** Alan Balodi demonstrates a walk cycle in Maya 2026 using a character
rig, with attention to timing, weight and contact.

[![Watch Alan Balodi animate a Maya character rig](https://i.ytimg.com/vi/BuaKrg8i0ZI/hqdefault.jpg)](https://www.youtube.com/watch?v=BuaKrg8i0ZI)

## 2. Set up your cast

Give each character a role name such as `initiator`, `partner` or `observer`.
Specify the appearance body for each role separately. A role name identifies
who does what and which FBX belongs to that character.

For two male bodies, two female bodies, or a scene with three or more characters,
ask the agent to assemble the cast in a copy of the rig scene. For example:

> Set up three characters in this rig file. Use male bodies for `initiator` and
> `partner` and a female body for `observer`. Give each character its own
> controls, skeleton and unique namespace or names. Preserve the inZOI skeleton
> hierarchy, proportions and scale, and keep all three in the same scene
> coordinate system. Confirm each character moves independently and can be
> selected for a separate export. Save a new file.

All participants in a scene stay bound to their roles until Exit. The in-game
debug picker supports up to three Zois. For larger casts, use an add-on and the
public API. A same-body or group scene needs a compatible entry or hub with the
same roster and placement context. For a same-body pair or a trio, a loop with
`starting_hub: true` and matching participant requirements gives you a direct
debug-picker entry. [Participant setup](group-support.md) · [Scene entry and hub extensions](package-split.md#roles-entry-and-extensions) · [Add-on API](addons.md)

## 3. Animate the scene

1. Set a frame rate and range for the scene. Use one timeline and a shared
   coordinate origin for all characters. A keyframe saves a control's pose at
   a point on that timeline. Key the starting pose, the main action and the
   ending pose with the supplied rig controls. Play through the motion between
   those keys and adjust their timing before adding details.
2. For a loop, match the final pose to the opening pose and scrub across the
   seam. For a paired or group scene, check contacts from multiple angles and
   scrub between key poses to catch hand drift, foot sliding and clipping.
   For sexual animations, check penetration and hand placement throughout the
   cycle, including the deepest and shallowest positions. For furniture, check
   the pose against the intended furniture reference.
   [Furniture authoring](furniture.md)
3. Preview the whole scene and save a short playblast or screen recording. If
   something looks wrong, give the agent the file, affected role, exact frame
   range, expected motion, and a clip of the problem. Ask it to compare the
   keyed controls, evaluated skeleton and exported or imported playback to
   identify where the mismatch first appears.

## 4. Export each participant

### Export the Zoi bodies

- **Blender.** Select a character's original Zoi armature, press **F3**, and
  choose **Export inZOI Motion Animation (150 Bones)**. Repeat for each role.
- **Maya.** In the **SceneZOI** shelf tab, click **inZOI Export** and choose
  **Zoi — 150 body bones**. Select the character's skeleton, confirm the start
  and end frames, and click **Export animation FBX…**. Repeat for each role.

Use the current exporter for the 150-bone body profile. It captures the evaluated
motion and corrective joints. Corrective motion comes from the rig or the source
clip, and the exported FBX preserves that motion.

### Export male genitals and other skeletal attachments

For an adult content pack, **male genitals are a separate skeletal mesh with
their own animation track** in the supplied HZoi rigs. Exporting the male Zoi's
body does not export the male genitals, even when you animated both together
in the same editor scene. SceneZOI itself is all-ages; content packs can supply
adult meshes and animations.

For example, a scene with a male Zoi, a female Zoi and animated male genitals
needs three animation FBXs:

| FBX example | What to export |
| --- | --- |
| `my_scene_male.fbx` | The male Zoi's body skeleton, using the 150-bone body exporter. |
| `my_scene_female.fbx` | The female Zoi's body skeleton, using the 150-bone body exporter. |
| `my_scene_male_genitals.fbx` | The separate male genitals skeleton, using the attachment exporter. |

The male genitals track belongs to an attachment on the male role. It is not
another participant. Export another attachment track for each additional
animated skeletal mesh, such as a tongue.

The [male genitals authoring kit](authoring.md#use-the-hzoi-anatomy-mesh-in-your-own-pack)
provides the editable skeletal mesh used by HZoi and by both the Maya and Blender
animation rigs. Use it to include that mesh in your own content pack without
requiring players to install HZoi. The kit works with animations authored in
either editor; its download is hosted on the Blender rigs post.

**Maya: export the male genitals.**

1. In Display Layers, show **Male_Anatomy_Skeleton** in the supplied paired rig.
   Select any original bone of that skeleton, rather than a control object or
   a bone of the male Zoi's body.
2. Click **inZOI Export** in the **SceneZOI** shelf tab. Choose **Other skeletal
   mesh — anatomy, tongue, props…**, then click **Choose skeleton from selected bone**.
3. Check the displayed skeleton, use the same **Start / End** frames as the body
   exports, and click **Export animation FBX…**. The exporter selects the whole
   attachment skeleton, including its required root, rather than only the bone
   you clicked. The supplied rig's saved attachment setup is applied automatically;
   you do not need to reset your pose before exporting.

**Blender: export the male genitals.**

1. Install and enable **`inzoi_anatomy_export.py`** as well as the body exporter.
   This Blender add-on is included in the shared authoring kit linked above.
2. Select the original male genitals armature, named **root** in the supplied
   rig. Do not select the mesh, the ARP controls, or the Zoi's body armature.
3. Press **F3**, choose **Export HZoi Male Anatomy Animation**, and export with
   the same frame range and scene FPS as the body tracks.

For the supplied male genitals, these exporters keep the attachment's root and
`pelvis` at their reference transforms while preserving the local deformation.
SceneZOI attaches the mesh to the Zoi's moving pelvis in game. Including that
same movement again in the attachment clip would move it twice. Keep the full
attachment hierarchy; do not delete its root or `pelvis` to try to fix alignment.

**Tongues and other meshes follow the same separate-track workflow**, using
their own skeletons. In Maya, use **Other skeletal mesh — anatomy, tongue,
props…** and select a bone of that mesh's skeleton. A custom attachment that
follows a Zoi needs its neutral attachment setup recorded when its rig is built;
without that setup, the exporter preserves its authored root movement. In
Blender, use an exporter appropriate to that mesh: `inzoi_anatomy_export.py`
checks the HZoi male genitals hierarchy and does not export arbitrary skeletons.

### Import the tracks and connect them to the scene

Export every body and attachment track with the **same frame range and FPS**.
In ModKit, use **Import Only Animations** and choose the skeleton that belongs
to the mesh being animated:

- Zoi body clips: **SK_Base**.
- HZoi male genitals clips: **HZoi_MaleAnatomy_Skeleton**, supplied with the
  male genitals authoring kit. Import or migrate the mesh and skeleton into
  your ModKit project before importing its animation clips.
- Tongues and other attachments: that mesh's own compatible skeleton.

Installing HZoi in the game does not install its editable ModKit assets. Use
the authoring kit when you need its mesh and skeleton in your own project.

Keep import translation and rotation offsets at zero, scale at 1, and skeleton
reference-pose updates off. Preview each imported clip on its intended mesh and
confirm their play lengths agree before authoring the scene duration.

In the scene JSON, `tracks` maps each role to its **body** clip. Supply the male
genitals or tongue clip through the attachment's `animation` field, or through
a coverage attachment profile's `node_animations` map. Give the agent the attachment's
mesh, skeleton, owning role and exported clip so it can configure the binding.
[Male genitals setup and import walkthrough](https://github.com/acepleiades/HZoi-Reference/blob/main/docs/standalone-anatomy.md)
· [Animated tongue example](facial-poses.md#select-the-pose-and-attach-an-animated-mesh)
· [Attachment and coverage profiles](package-split.md#presentation-and-compatibility-profiles)

If you are porting an animation and have no separate male genitals or tongue
track, you can still attach the mesh and use its rest pose or fixed bone angles
for that scene. Use a separate animation clip when it needs movement of its own.
[Port an animation without a separate attachment track](authoring.md#port-an-animation-without-a-separate-attachment-track)

## 5. Describe the scene for the agent

Give the agent your FBXs, a preview, the intended role bindings, and a description
of what actually happens. The agent can draft the JSON from your description.
Review its tags and directed actions before building. [Metadata and ratings](scene-metadata.md) · [Worked examples](content-examples.md)

Describe sexual actions directly: who penetrates whom, who gives or receives
oral sex, and whether the movement is mutual. Describe affectionate contact
just as clearly. Accurate actions let SceneZOI classify the scene and let
gameplay mods find the interaction they need; an `intimate` mood tag alone
does not describe what happens.

Copy and fill in this brief:

```text
Scene name, pack namespace and intended in-game entry
Standing or furniture type, alignment and anchor role
Loop or one-shot transition, FPS, export range and imported duration
Each role's appearance body, age requirements and FBX filename
Each skeletal attachment, its owning role, mesh, skeleton and separate FBX, if animated
Opening pose, main beats and final pose
Who does what to whom, who drives the movement, and whether it is mutual
Scene-wide mood and each role's posture, orientation and contact points
Where each role should look and any head or eye movement already keyed
Facial expression context for each role and any fixed facial pose
Voice context for each speaker, or silence
Sound effects, their source and when they should play, or none
Scene tasks for each role, progression and effects at completion, if any
Any props, outfit changes, required libraries and navigation destinations
```

Name the gaze target concretely, such as the partner's face or the initiator's
own raised hand. Describe a two-way action in both directions so the agent
can record each one. Mention if the clip already animates head movement so you
can review how the gaze settings interact with it. If you need presentation
assets, the authoring guide explains how to use an installed HZoi dependency.
[Gaze](gaze.md) · [Expressions](expressions.md) · [Voices](voices.md) · [Sound effects](sfx.md) · [HZoi resources](authoring.md#reuse-hzoi-resources-through-a-dependency)

For a sexual scene, you can use SceneZOI's shared **Excitement** task. Specify
which roles gain progress, when they can complete it, and the sounds, voices
and movement effects you want at completion. HZoi Reference provides complete
scene examples. [Scene tasks](scene-tasks.md) · [Completion effects](completion-effects.md)

A non-sexual example is vampire feeding, inspired by *Vampire: The Masquerade
— Bloodlines*. The vampire could fill a **Feeding** task while the target fills
a **Blood Depletion** task. A gameplay mod could let the player stop before the
target is drained, or kill the target when Blood Depletion completes. SceneZOI
provides synchronized animation, task progress and completion events; the
gameplay mod implements feeding rules and consequences.
[Add-on authoring](addon-authoring.md) · [Task events](addons.md#events-and-ownership)

## 6. Package and test in-game

Stage the scene JSON, check the imported asset paths and durations, and
package the mod using the owned-payload filter. An agent can handle these steps
with the project and scene brief you supplied. The authoring
guide shows how to create the manifest and register the scene files. The
packaging guide covers the isolated ModKit export and filtering.
[Authoring and staging](authoring.md#files-and-native-project) · [Packaging](development.md#isolated-packaging)

Install the filtered test build alongside SceneZOI and any declared
dependencies. Use the intended entry or turn on **SceneZOI manual start**
under **Debug** in Scene Settings for a compatible picker test. Check that each
Zoi plays the right role, the tracks stay aligned through the loop, gaze and
audio behave as intended, and **Exit** returns everyone to gameplay. If a
problem appears only in-game, give the agent the scene ID, roster, reproduction
steps, and a short recording or diagnostic log. [Player setup](../README.md#player-downloads) · [In-game validation](development.md#in-game-validation)
