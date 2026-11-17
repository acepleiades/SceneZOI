-- The client sends only the scene fields needed for participant preparation.
local V=require('SceneZOI.DataValidation')
local M={}
function M.simulation(v)
 V.fields(v,{'id','participants','outfits','cleanup_layers'},{'id','participants'})
 V.id(v.id);V.roles(v.participants);V.outfits(v.outfits or {},v.participants)
 if v.cleanup_layers then V.array(v.cleanup_layers,16);for _,name in ipairs(v.cleanup_layers)do V.name(name)end end
 return v
end
return M
