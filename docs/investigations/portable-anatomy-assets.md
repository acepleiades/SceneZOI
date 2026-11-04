# Portable anatomy assets and bind-pose preservation

**Investigated:** 2026-10-22, inZOI ModKit / Unreal 5.6.1.

## Problem

Copying the prototype's `.uasset` files into a differently named mod folder does
not rewrite their internal `/SceneZOI_93C44199/` references. A reusable asset pack
needs a consistent package root and complete dependencies.

The distribution copy uses `/Game/HZoiMaleAnatomy/`. Recipients first preserve
that folder under project Content, then move the entire folder into their mod
through the Content Browser and save. Editor moves update references; Explorer
moves do not. These are editable assets, not cooked game-install files.

## Preserving the tested asset

The mesh/animation skeleton properties are read-only through the inspected
Python interface. The portable mesh and clip were imported from FBX against a
copied independent skeleton; materials/textures were copied and their references
remapped. Soft preview references also needed remapping.

Reimport introduced a small bind-pose discrepancy: exported rest-bone positions
differed by up to about 0.408 mm. `SkeletonModifier` read the tested original
mesh's local reference transforms and applied them to the portable mesh only.
After committing and saving, the repeated comparison found matching rest-bone
and vertex positions. The provided fallback mesh FBX was exported afterward.
Reimporting assets should therefore include a reference-pose comparison.

Python material-slot edits also required assigning each modified struct back
into its array before setting the mesh's materials; changing an iterated struct
alone did not persist the material assignment. A fresh asset reload caught this.

## Verification and limits

- Ten editable packages; no remaining SceneZOI asset references. The optional
  stock skin patch retains dependencies on existing ModKit skeleton, material,
  physics and LOD assets, which are not included as replacements.
- Original and portable meshes: 13,288 triangles, matching vertex positions and
  rest-bone positions in the exported comparison. Vertex splitting differed
  (14,366 versus 14,399 vertices); nearest-position skin-weight differences were
  at most approximately 0.000092. UV layer counts matched.
- All eight test-animation tracks at all 60 samples matched the original pose
  values; duration approximately 1.966667 seconds. This was an offline comparison,
  not a new live test of the portable copy in another author's mod.
- FBX mesh comparison required commandlet rendering. `NullRHI` raised a
  `MeshObject` assertion in this build. Diagnostic exports used source mesh data
  with material baking disabled.
- ZIP contents and per-file hashes were verified. Original SceneZOI assets and
  installed game content were unchanged; temporary distribution content was removed.

## Sources

- [Epic: working with assets](https://dev.epicgames.com/documentation/en-us/unreal-engine/working-with-assets-in-unreal-engine)
- [Epic: SkeletonModifier](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/SkeletonModifier?application_version=5.6)
- [Epic: FbxExportOption](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/FbxExportOption?application_version=5.6)
