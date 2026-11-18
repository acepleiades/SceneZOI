-- Sample only at acknowledged wardrobe boundaries, never during frame polling.
local M = {}
local function text(value) return tostring(value or "None"):sub(1, 256) end
function M.sample(current, participant, stage)
    local fields = {session_id=current.token, scene_id=current.node.id, revision=current.revision,
        participant_id=participant.id, role=participant.role, stage=stage,
        outfit_counter=participant.outfit_counter or 0, items={}}
    local ids = {}
    for id in pairs(participant.outfit_items or {}) do ids[#ids+1]=id end
    table.sort(ids)
    for index, id in ipairs(ids) do
        if index > 32 then fields.items_truncated=true; break end
        local item=participant.outfit_items[id]
        fields.items[#fields.items+1]={id=id, slot=item.key, kind=item.kind,
            captured=item.asset, expected=item.expected_asset, enabled=item.enabled}
    end
    local ok, garments = pcall(function()
        local rows={}
        local source=participant.actor.AppearanceComponent.AppearanceSetting.FinalStyle.Outfit.Garments
        local count=0
        for slot, value in pairs(source:ToTable()) do
            count=count+1
            if count > 32 then fields.garments_truncated=true; break end
            local id=text(value.GarmentId)
            if id=="None" or id=="" then id=text(value.MeshId) end
            rows[text(slot)]=id
        end
        return rows
    end)
    if ok then fields.client_garments=garments else fields.client_garments_unavailable=true end
    local rendered_ok, rendered = pcall(function()
        local rows={}
        for _, component in ipairs(participant.actor:K2_GetComponentsByClass(UE.USkeletalMeshComponent:StaticClass())) do
            local name=component:GetName()
            if name=="Garment" or ok and garments[name]~=nil then
                if #rows>=24 then fields.rendered_truncated=true; break end
                local mesh=component:GetSkeletalMeshAsset()
                rows[#rows+1]={component=name, mesh=mesh and mesh:GetName() or "None",
                    visible=component:IsVisible(), hidden=component.bHiddenInGame}
            end
        end
        return rows
    end)
    if rendered_ok then fields.rendered_garments=rendered else fields.rendered_garments_unavailable=true end
    return fields
end
return M
