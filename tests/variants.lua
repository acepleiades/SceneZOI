package.path = "modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;" .. package.path
local V = require("SceneZOI.DataValidation")
local Variants = require("SceneZOI.VariantData")
local body = {schema_version = 1, id = "example.female", body = "female", mesh = "/Example/Female.Female"}
local attachment = {schema_version = 1, id = "example.prop", attachment = {
    mesh = "/Example/Prop.Prop", component = "body", socket = "pelvis", reference_bone = "pelvis",
}}
assert(Variants.validate_body(body, "example").mesh == body.mesh)
assert(Variants.validate_attachment(attachment, "example").attachment.mesh == attachment.attachment.mesh)
local selection = {body_variant = false, attachment_variants = {body_region = false, tongue = "example.prop"}}
local selected = Variants.validate_selection(selection)
assert(selected.body_variant == false and selected.attachment_variants.body_region == false)
assert(selected ~= selection and selected.attachment_variants ~= selection.attachment_variants)
Variants.validate_scene({female = selection}, {female = {body = "female"}})
assert(not pcall(Variants.validate_scene, {missing = selection}, {female = {body = "female"}}))

for _, mutation in ipairs({
    function(v) v.id = "another.female" end,
    function(v) v.id = "example." end,
    function(v) v.schema_version = 2 end,
    function(v) v.body = "unknown" end,
    function(v) v.mesh = "Female" end,
    function(v) v.growth_steps = {} end,
    function(v) v.growth_steps = {"Adult", "Adult"} end,
    function(v) v.override = true end,
}) do
    local invalid = V.copy(body)
    mutation(invalid)
    assert(not pcall(Variants.validate_body, invalid, "example"))
end
for _, mutation in ipairs({
    function(v) v.attachment.animation = "/Example/Clip.Clip" end,
    function(v) v.attachment.component = "face" end,
    function(v) v.attachment.component = "head"; v.attachment.body_profile = "example.region" end,
    function(v) v.attachment.material_profile = "example.skin" end,
    function(v) v.attachment.retain_for_session = "yes" end,
    function(v) v.node_animations = {scene = "not an asset"} end,
    function(v) v.node_animations = false end,
}) do
    local invalid = V.copy(attachment)
    mutation(invalid)
    assert(not pcall(Variants.validate_attachment, invalid, "example"))
end
for _, invalid in ipairs({
    {body_variant = true}, {body_variant = "/Example/Female.Female"}, {attachment_variants = {body_region = true}},
    {attachment_variants = {body_region = "bad id"}}, {saved = true},
}) do
    assert(not pcall(Variants.validate_selection, invalid))
end
local too_many = {attachment_variants = {}}
for index = 1, 17 do too_many.attachment_variants["slot" .. index] = false end
assert(not pcall(Variants.validate_selection, too_many))

local later = V.copy(body)
later.mesh = "/Example/Other.Other"
local rows = {
    {owner = "example", source = "z-last", data = later},
    {owner = "example", source = "a-first", data = body},
    {owner = "foreign", source = "invalid-owner", data = body},
}
local registry = Variants.compile({by_kind = {
    body_variant = rows, attachment_variant = {{owner = "example", source = "prop", data = attachment}},
}})
assert(registry.bodies[body.id].mesh == body.mesh and registry.bodies[body.id]._owner == "example")
assert(registry.attachments[attachment.id].attachment.mesh == attachment.attachment.mesh)
assert(#registry.warnings == 2)
local reverse = {}
for index = #rows, 1, -1 do reverse[#reverse + 1] = rows[index] end
assert(V.equal(registry.bodies, Variants.compile({by_kind = {body_variant = reverse}}).bodies))
assert(body._owner == nil and attachment._owner == nil, "Registration must preserve source declarations")
local malformed = Variants.compile({by_kind = {body_variant = {
    {owner = "example", source = "invalid-object", data = 1},
    {owner = "example", source = "valid-object", data = body},
}}})
assert(malformed.bodies[body.id] and #malformed.warnings == 1, "One invalid record must not prevent other variants")

local scene = {id = "example.scene", label = "Example", kind = "loop", duration = 1, fps = 30,
    participants = {female = {body = "female"}}, anchor_participant = "female",
    tracks = {female = "/Example/Clip.Clip"}, navigation = {}, appearance = {female = selection}}
assert(require("SceneZOI.SceneData").node(scene, "example").appearance.female.body_variant == false)
print("Appearance variant data passed: namespaced definitions, copied selections, disabled values, role validation and deterministic conflict isolation.")
