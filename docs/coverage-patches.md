# Use SceneZOI's crotch coverage patches

SceneZOI includes neutral crotch coverage meshes. They contain no male genitals:
on their own, they leave a smooth, closed body. An animation pack can attach its
own male genitals above that surface without depending on HZoi.

For a compatible male body layout, set this field in your attachment declaration:

```json
"body_profile": "scenezoi.male_crotch"
```

The [shared profile](../packs/scenezoi/profiles/male_crotch.json) hides body
region 17 and supplies the appropriate neutral patch. It uses the stock patch
for the stock body, Supponpon and unlisted meshes, and the fitted patch for the
ZoiBits male body asset. Clothing and body rebuilds cause selection to run again.
You do not need to register a second copy of this profile or package these meshes.

| Framework asset | Fits |
| --- | --- |
| `/SceneZOI_93C44199/Compatibility/StockCoveragePatch.StockCoveragePatch` | The stock male body and stock-compatible cutouts, including Supponpon. |
| `/SceneZOI_93C44199/Compatibility/ZoiBitsMaleCoveragePatch.ZoiBitsMaleCoveragePatch` | The tested ZoiBits Male v4 cutout. |

ZoiBits Male v3 and v4 share
`/NaturalSkin_B5AE5C0D/Mesh/SKM_Male_Base_NS.SKM_Male_Base_NS`. Updates retaining
that path select the fitted patch too. The current fit was checked against v4;
a future change to its geometry or skinning can still require refitting.

## What belongs in my pack?

Supply your attachment mesh, skeleton, materials, textures and any attachment
animation tracks. If the mesh needs skin or hair matching, declare a material
profile for its own material slots and parameters. That is separate from the
shared coverage profile.

Register the mesh as an [attachment variant](appearance-variants.md#register-the-assets)
and select it in the scene's `appearance[role].attachment_variants.body_region`.
An explicit API selection takes priority over that scene default. Either selects
one region replacement for the Zoi, replacing the automatic fallback when present.
An ordinary `add_attachment` prop does not claim or hide this body region.

For the supplied male genitals mesh, follow the
[independent-pack Q&A](authoring.md#how-do-i-make-my-animation-pack-independent-of-hzois-fallback-penis).
Using the shared neutral patch does not choose HZoi's male genitals or require
its animation pack. SceneZOI does not attach anything merely because this profile
is installed.

## I need a patch for another body

The shared profile requires the declared region/coverage bit 17, material slot
`shader_body_shader18`, the compatible body skeleton and the `Body_Muscle` morph.
An unlisted body receives the stock default, but matching region numbers alone
does not establish that the shape fits.

For a different cutout, fit a neutral patch and declare your own body profile
with its own ID. You may reference SceneZOI's stock mesh as your default and use
`patch_mesh_overrides` for your other fits. A different region layout needs its
own compatible profile. [Profile and fitting instructions](package-split.md#fit-a-coverage-patch-to-another-body)

Match the boundary's positions, skin weights and morphs, and preserve UV seams,
normals and tangents. Check raised knees, spread legs, crouching, hip twists,
every LOD, clothing changes and Exit. A patch that closes the gap while standing
can still separate or show a lighting seam in motion.

The source meshes are included under the framework's
[Compatibility folder](../modkit/SceneZOI_93C44199/Content/Compatibility/).
They are game-derived support assets and retain the applicable game and ModKit
asset terms. They are separate from HZoi's original animation-motion license.
