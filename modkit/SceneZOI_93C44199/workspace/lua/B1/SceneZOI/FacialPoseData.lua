-- Inert partial facial poses. Bone layout is checked separately on the live head.
local V=require('SceneZOI.DataValidation')
local M={}
function M.validate(data,owner)
 V.fields(data,{'schema_version','id','label','poses'},{'schema_version','id','poses'})
 assert(data.schema_version==1,'Unsupported facial pose schema');V.id(data.id)
 if owner then assert(data.id:sub(1,#owner+1)==owner..'.','Facial pose namespace mismatch')end
 if data.label then V.name(data.label)end
 V.fields(data.poses,{'male','female'});assert(next(data.poses),'Empty facial pose bodies')
 for _,rows in pairs(data.poses)do
  V.array(rows,256);assert(#rows>0,'Empty facial pose');local parents={}
  for _,row in ipairs(rows)do
   V.fields(row,{'bone','parent','position','rotation'},{'bone','parent','position','rotation'})
   for _,key in ipairs({'bone','parent'})do assert(type(row[key])=='string'and #row[key]<=97 and row[key]:match('^FACIAL_[A-Za-z0-9_]+$'),'Invalid facial bone name')end
   assert(not parents[row.bone]and row.bone~=row.parent,'Duplicate/self-parent facial bone');parents[row.bone]=row.parent
   V.array(row.position,3);assert(#row.position==3,'Invalid facial position');for _,x in ipairs(row.position)do V.number(x,-200,200)end
   V.array(row.rotation,4);assert(#row.rotation==4,'Invalid facial rotation');local norm=0
   for _,x in ipairs(row.rotation)do V.number(x,-1.00001,1.00001);norm=norm+x*x end
   assert(math.abs(norm-1)<.00001,'Facial pose rotation must be a unit quaternion')
  end
  for name in pairs(parents)do local seen={};while parents[name]do assert(not seen[name],'Cyclic facial pose hierarchy');seen[name]=true;name=parents[name]end end
 end
 return data
end
function M.compile(documents)
 local result={poses={},warnings={}}
 for _,doc in ipairs(documents)do
  local ok,err=pcall(function()
   local data=M.validate(doc.data,doc.owner)
   assert(not result.poses[data.id]or V.equal(result.poses[data.id],data),'Conflicting facial pose: '..data.id)
   result.poses[data.id]=V.copy(data)
  end)
  if not ok then result.warnings[#result.warnings+1]=tostring(doc.source)..': '..tostring(err)end
 end
 return result
end
return M
