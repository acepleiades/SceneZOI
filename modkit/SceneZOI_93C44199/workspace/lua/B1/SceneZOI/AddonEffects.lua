-- Optional presentation uses the existing attachment/outfit engines and original snapshots.
local V=require('SceneZOI.DataValidation')
local Control=require('SceneZOI.AddonControl')
local Attachment=require('SceneZOI.Attachment')
local M={};local orphans={}
local function person(s,id)
 for _,p in ipairs(s.participants)do if p.id==id then return p end end
 error('participant_not_found')
end
function M.outfit(s,key,id,item,enabled)
 local p=person(s,id);local piece=assert(p.outfit_items and p.outfit_items[item],'outfit_item_not_found')
 V.boolean(enabled);local k=id..'|'..item
 s.addon_outfit_slots=s.addon_outfit_slots or {}
 s.addon_outfit_slots[k]=s.addon_outfit_slots[k]or {participant_id=id,item_id=item,baseline=piece.enabled}
 local layer=Control.layer(s,key);layer.outfits=layer.outfits or {};layer.outfits[k]=enabled;layer.outfit_serials=layer.outfit_serials or {};layer.outfit_serials[k]=Control.touch(layer)
 return {accepted=true,phase='pending',item_id=item}
end
function M.player_outfit(s,pid,item,enabled)
 local k=pid..'|'..item
 if s.addon_outfit_slots then s.addon_outfit_slots[k]=nil end
 for _,layer in pairs(s.addon_controls or {})do if layer.outfits then layer.outfits[k]=nil end end
end
function M.attach(s,key,args)
 local p=person(s,args.participant_id);V.id(args.effect_id)
 local spec=args.attachment
 V.fields(spec,{'mesh','component','socket','reference_bone','animation'},{'mesh','socket','reference_bone'})
 if spec.component~=nil then assert(spec.component=='head'or spec.component=='body','Invalid attachment component')end
 V.asset(spec.mesh);V.name(spec.socket);V.name(spec.reference_bone);if spec.animation then V.asset(spec.animation)end
 s.addon_attachments=s.addon_attachments or {};local count=0;for _ in pairs(s.addon_attachments)do count=count+1 end;assert(count<32,'attachment_limit')
 local k=key..'|'..args.effect_id
 assert(not s.addon_attachments[k],'effect_already_exists')
 spec=V.copy(spec);spec.participant=p.role
 local ctx={node={attachment=spec},participants={p},defer_visibility=true}
 ctx.attachment_asset,ctx.body_profile,ctx.attachment_animation=Attachment.load(ctx.node,s.duration)
 s.addon_attachments[k]={key=key,effect_id=args.effect_id,participant=p,context=ctx,phase='pending',age=0,duration=s.duration}
 return {accepted=true,phase='pending',effect_id=args.effect_id}
end
local function restore(row)
 local component=row.context.attachment and row.context.attachment.component
 if component then
  local ok,valid=pcall(function()return UE.UKismetSystemLibrary.IsValid(component)end)
  if ok and valid==false then row.context.attachment=nil;row.phase='released';row.error=nil;return true end
 end
 local ok,err=pcall(Attachment.restore,row.context)
 if ok then row.phase='released';row.error=nil else row.phase='releasing';row.error=tostring(err)end
 return ok
end
function M.release(s,key,effect_id)
 if effect_id then V.id(effect_id)end
 for k,row in pairs(s.addon_attachments or {})do
  if row.key==key and(not effect_id or row.effect_id==effect_id)then row.retired=true;if restore(row)then s.addon_attachments[k]=nil end end
 end
end
function M.restore(s)
 local complete=true
 for k,row in pairs(s.addon_attachments or {})do
  row.retired=true
  if restore(row)then s.addon_attachments[k]=nil else complete=false end
 end
 if not complete then error('Add-on attachment cleanup will retry')end
end
function M.retain(s)
 if s.addon_attachments and next(s.addon_attachments)then orphans[#orphans+1]=s end
end
function M.idle()
 for i=#orphans,1,-1 do if pcall(M.restore,orphans[i])then table.remove(orphans,i)end end
end
function M.tick(s,dt,apply_outfit)
 for k,row in pairs(s.addon_attachments or {})do
  if not(s.addon_controls or {})[row.key]then row.retired=true end
  if row.retired then if restore(row)then s.addon_attachments[k]=nil end
  elseif row.phase~='failed'then
   local ok,err=pcall(function()
    if row.context.attachment_animation and math.abs(row.duration-s.duration)>.0001 then error('Attachment duration incompatible after navigation')end
    if s.preparing then
     if row.context.attachment then row.context.attachment.component:SetHiddenInGame(true,true)end
     return
    end
    row.age=row.age+dt
    local prepared=Attachment.prepare(row.context,row.participant.actor)
    if prepared and Attachment.ready(row.context)then
     Attachment.enter(row.context);Attachment.sample(row.context,s.clock:position(s.duration,s.node.kind));row.phase='active'
    elseif row.age>8 then error('Attachment readiness timed out')end
   end)
   if not ok then
    local cause=tostring(err);row.retired=true;restore(row);row.phase='failed';row.error=cause
    s.addon_effect_diagnostics=s.addon_effect_diagnostics or {};s.addon_effect_diagnostics[#s.addon_effect_diagnostics+1]={key=row.key,effect_id=row.effect_id,error=cause}
    if #s.addon_effect_diagnostics>32 then table.remove(s.addon_effect_diagnostics,1)end
    print('[SceneZOI] Add-on attachment failed: '..row.effect_id..': '..cause)
   end
  end
 end
 if s.preparing or s.stopping then return end
 local keys={};for k in pairs(s.addon_outfit_slots or {})do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do
  local slot=s.addon_outfit_slots[k];local p=person(s,slot.participant_id);local piece=p.outfit_items and p.outfit_items[slot.item_id]
  local desired,latest,owned=slot.baseline,-1,false
  for _,layer in pairs(s.addon_controls or {})do
   local sequence=layer.outfit_serials and layer.outfit_serials[k]or layer.serial
   if layer.outfits and layer.outfits[k]~=nil and sequence>latest then desired,latest,owned=layer.outfits[k],sequence,true end
  end
  -- Respect an unrelated change instead of restoring over it.
  if piece and slot.last_applied~=nil and piece.enabled~=slot.last_applied then slot.baseline=piece.enabled end
  if piece and piece.enabled~=desired then
   slot.last_applied=desired
   apply_outfit(p,slot.item_id,desired);return
  end
  if not owned then s.addon_outfit_slots[k]=nil end
 end
end
function M.snapshot(s,key)
 local rows={}
 for _,row in pairs(s.addon_attachments or {})do if row.key==key then rows[#rows+1]={effect_id=row.effect_id,participant_id=row.participant.id,phase=row.phase,error=row.error}end end
 table.sort(rows,function(a,b)return a.effect_id<b.effect_id end)
 local errors=require('SceneZOI.Json').array({});for _,e in ipairs(s.addon_effect_diagnostics or {})do if e.key==key then errors[#errors+1]={effect_id=e.effect_id,error=e.error}end end
 return {attachments=require('SceneZOI.Json').array(rows),errors=errors,overrides=V.copy((s.addon_controls or {})[key]or {})}
end
return M
