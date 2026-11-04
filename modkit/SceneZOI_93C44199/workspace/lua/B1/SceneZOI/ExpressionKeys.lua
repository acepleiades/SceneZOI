local M={}
function M.normalize(value)
 if type(value)~='string'or not value:match('^[ -~]+$')then return nil end
 local key=value:match('^%s*(.-)%s*$'):lower()
 if #key==0 or #key>96 then return nil end
 return key
end
function M.required(value)return assert(M.normalize(value),'Invalid expression identifier')end
return M
