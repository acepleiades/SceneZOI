local Search=require('SceneZOI.SceneSearch')
local M={}
function M.choose(nodes,roster,random,profile,ratings)
 local rows=Search.find({nodes=nodes},{starting_hub_only=true,allowed_content_ratings=ratings},roster,profile)
 local row=Search.random(rows,random)
 if row then return {node=row.scene_id,bindings=row.bindings},#rows end
end
return M
