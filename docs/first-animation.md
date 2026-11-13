# Make your first SceneZOI animation

Start with a short standing loop. A Zoi shifts their weight, waves, and returns
to the opening pose. For a paired version, add a second Zoi who reacts. A small
scene lets you test the whole workflow before you spend time polishing a longer
animation.

I recommend working with an AI agent, especially for your first pack. Give it
this guide, the SceneZOI repository, and access to a working copy of your project.
It can help set up the rigs, inspect odd playback, import FBXs, write scene JSON,
and package the mod. You decide how the animation should look and verify the
result in-game.

## 1. Install the tools and open a rig

Choose one animation editor. Both have ready-made inZOI rigs and exporters.

| Editor | Download and setup |
| --- | --- |
| **Blender** | Download Blender 4.1, the version used to make the rigs. Open a supplied `.blend` file, save a working copy, and install and enable `inzoi_motion_export.py` from Blender's Add-ons preferences. [Blender releases](https://www.blender.org/releases/) · [inZOI Blender rigs and exporter](https://www.patreon.com/skyrimaceanimations/posts/inzoi-blender-172792014) |
| **Maya** | Get Maya from Autodesk. The rigs were authored in Maya 2026. Open the paired `.ma` file and save a working copy. Extract the exporter ZIP and drag `inzoi_animation_export.py` into the viewport to add the **inZOI Export** button to the **SceneZOI** shelf. Use Display Layers to show the controls and meshes you need. [Autodesk Maya](https://www.autodesk.com/products/maya/free-trial) · [inZOI Maya rigs, exporter and linking tool](https://www.patreon.com/skyrimaceanimations/posts/inzoi-maya-rigs-173172317) |

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

Give each character a role name such as `greeter`, `partner` or `observer`.
Specify the appearance body for each role separately. A role name identifies
who does what and which FBX belongs to that character.

For two male bodies, two female bodies, or a scene with three or more characters,
ask the agent to assemble the cast in a copy of the rig scene. For example:

> Set up three characters in this rig file. Use male bodies for `greeter` and
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
   For furniture, check the pose against the intended furniture reference.
   [Furniture authoring](furniture.md)
3. Preview the whole scene and save a short playblast or screen recording. If
   something looks wrong, give the agent the file, affected role, exact frame
   range, expected motion, and a clip of the problem. Ask it to compare the
   keyed controls, evaluated skeleton and exported or imported playback to
   identify where the mismatch first appears.

## 4. Export each participant

- **Blender.** Select a character's original Zoi armature, press **F3**, and
  choose **Export inZOI Motion Animation (80 Bones)**. Repeat for each role.
- **Maya.** Open **SceneZOI → inZOI Export**, choose **Zoi — 80 motion bones**,
  select the character's skeleton, confirm the start and end frames, and click
  **Export animation FBX…**. Repeat for each role.

Keep one FBX per role and export every track with the same frame range and FPS.
Use clear filenames such as `wave_greeter.fbx` and `wave_partner.fbx`. Export any
animated attachments separately with the same timing. In ModKit, import the
body FBXs with **Import Only Animations** and select **SK_Base**. Attachments
use their own compatible skeleton. Preview the imported clips and confirm
their play lengths agree before authoring the scene duration.

## 5. Describe the scene for the agent

Give the agent your FBXs, a preview, the intended role bindings, and a description
of what actually happens. The agent can draft the JSON from your description.
Review its tags and directed actions before building. [Metadata and ratings](scene-metadata.md) · [Worked examples](content-examples.md)

Copy and fill in this brief:

```text
Scene name, pack namespace and intended in-game entry
Standing or furniture type, alignment and anchor role
Loop or one-shot transition, FPS, export range and imported duration
Each role's appearance body, age requirements and FBX filename
Opening pose, main beats and final pose
Who does what to whom, who drives the movement, and whether it is mutual
Scene-wide mood and each role's posture, orientation and contact points
Where each role should look and any head or eye movement already keyed
Facial expression context for each role and any fixed facial pose
Voice context for each speaker, or silence
Sound effects, their source and when they should play, or none
Any props, outfit changes, required libraries and navigation destinations
```

Name the gaze target concretely, such as the partner's face or the greeter's
own raised hand. Describe a two-way action in both directions so the agent
can record each one. Mention if the clip already animates head movement so you
can review how the gaze settings interact with it. If you need presentation
assets, the authoring guide explains how to use an installed HZoi dependency.
[Gaze](gaze.md) · [Expressions](expressions.md) · [Voices](voices.md) · [Sound effects](sfx.md) · [HZoi resources](authoring.md#reuse-hzoi-resources-through-a-dependency)

## 6. Package and test in-game

Ask the agent to stage the scene JSON, verify the imported asset paths and
durations, and package the mod using the owned-payload filter. The authoring
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
