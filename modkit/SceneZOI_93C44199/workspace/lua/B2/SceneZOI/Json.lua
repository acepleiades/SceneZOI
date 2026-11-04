-- Strict inert JSON reader: no evaluation, file IO or native container retention.
local M={null=setmetatable({},{__jsonkind='null'})}
function M.decode(text,maximum_bytes)
 assert(type(text)=='string'and #text<=(maximum_bytes or 1048576),'JSON is too large')
 local pos,nodes=1,0
 local function space()local _,last=text:find('^[ \t\r\n]*',pos);pos=(last or pos-1)+1 end
 local function utf8char(n)
  if n<128 then return string.char(n)elseif n<2048 then return string.char(192+math.floor(n/64),128+n%64)
  elseif n<65536 then return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)
  else return string.char(240+math.floor(n/262144),128+math.floor(n/4096)%64,128+math.floor(n/64)%64,128+n%64)end
 end
 local function str()
  assert(text:sub(pos,pos)=='"','Expected JSON string');pos=pos+1;local out={}
  while pos<=#text do
   -- Copy ordinary UTF-8 spans at once; large native tables contain many strings.
   local mark=text:find('["\\%z\1-\31]',pos)
   if not mark then error('Unterminated JSON string')end
   if mark>pos then out[#out+1]=text:sub(pos,mark-1)end
   local c=text:sub(mark,mark);pos=mark+1
   if c=='"'then return table.concat(out)end
   if c=='\\'then
    c=text:sub(pos,pos);pos=pos+1
    local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
    if c=='u'then
     local hex=text:sub(pos,pos+3);assert(hex:match('^%x%x%x%x$'),'Bad JSON unicode');pos=pos+4;local code=tonumber(hex,16)
     if code>=0xD800 and code<=0xDBFF then
      assert(text:sub(pos,pos+1)=='\\u','Missing low surrogate');pos=pos+2
      hex=text:sub(pos,pos+3);assert(hex:match('^%x%x%x%x$'),'Bad low surrogate');pos=pos+4;local low=tonumber(hex,16)
      assert(low>=0xDC00 and low<=0xDFFF,'Bad low surrogate');code=0x10000+(code-0xD800)*1024+low-0xDC00
     else assert(code<0xDC00 or code>0xDFFF,'Unpaired low surrogate')end
     out[#out+1]=utf8char(code)
    else out[#out+1]=assert(escapes[c],'Bad JSON escape')end
   else assert(c:byte()>=32,'JSON string control character');out[#out+1]=c end
  end
  error('Unterminated JSON string')
 end
 local value
 value=function(depth)
  assert(depth<=48,'JSON nesting limit');nodes=nodes+1;assert(nodes<=65536,'JSON node limit');space();local c=text:sub(pos,pos)
  if c=='"'then return str()end
  if c=='{'or c=='['then
   local object=c=='{';pos=pos+1;space();local result=setmetatable({},{__jsonkind=object and 'object'or 'array'});local close=object and '}'or ']'
   if text:sub(pos,pos)==close then pos=pos+1;return result end
   while true do
    space();local key=object and str()or #result+1
    if object then assert(result[key]==nil,'Duplicate JSON key');space();assert(text:sub(pos,pos)==':','Expected JSON colon');pos=pos+1 end
    result[key]=value(depth+1);space();c=text:sub(pos,pos);pos=pos+1
    if c==close then return result end;assert(c==',','Expected JSON comma')
   end
  end
  for word,result in pairs({['true']=true,['false']=false,['null']=M.null})do
   if text:sub(pos,pos+#word-1)==word then pos=pos+#word;return result end
  end
  local start=pos
  if c=='-'then pos=pos+1 end
  c=text:sub(pos,pos)
  if c=='0'then pos=pos+1;assert(not text:sub(pos,pos):match('%d'),'JSON leading zero')
  else assert(c:match('[1-9]'),'Expected JSON value');repeat pos=pos+1 until not text:sub(pos,pos):match('%d')end
  if text:sub(pos,pos)=='.'then pos=pos+1;assert(text:sub(pos,pos):match('%d'),'Bad JSON fraction');repeat pos=pos+1 until not text:sub(pos,pos):match('%d')end
  c=text:sub(pos,pos)
  if c=='e'or c=='E'then pos=pos+1;c=text:sub(pos,pos);if c=='+'or c=='-'then pos=pos+1 end;assert(text:sub(pos,pos):match('%d'),'Bad JSON exponent');repeat pos=pos+1 until not text:sub(pos,pos):match('%d')end
  local number=assert(tonumber(text:sub(start,pos-1)));assert(number==number and math.abs(number)<math.huge,'Non-finite JSON number');return number
 end
 local result=value(0);space();assert(pos>#text,'Trailing JSON data');return result
end
function M.array(value)return setmetatable(value or {},{__jsonkind='array'})end
function M.encode(value)
 local active={}
 local function quote(s)
  return '"'..s:gsub('[%z\1-\31\\"]',function(c)
   local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
   return escapes[c]or string.format('\\u%04x',c:byte())
  end)..'"'
 end
 local function encode(v,depth)
  assert(depth<=48,'JSON encoding depth limit')
  local t=type(v)
  if t=='string'then return quote(v)elseif t=='boolean'then return tostring(v)
  elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'Invalid JSON number');return string.format('%.17g',v)
  elseif v==M.null or(t=='table'and getmetatable(v)and getmetatable(v).__jsonkind=='null')then return 'null'end
  assert(t=='table'and not active[v],'Invalid or circular JSON value');active[v]=true
  local kind=getmetatable(v)and getmetatable(v).__jsonkind
  local array=kind=='array'or(kind==nil and #v>0);local parts={}
  if array then
   local n=0;for k in pairs(v)do assert(type(k)=='number'and k%1==0 and k>0,'Invalid JSON array key');n=n+1 end
   assert(n==#v,'Sparse JSON array')
   for _,entry in ipairs(v)do parts[#parts+1]=encode(entry,depth+1)end
  else
   local keys={};for key in pairs(v)do assert(type(key)=='string','Invalid JSON object key');keys[#keys+1]=key end;table.sort(keys)
   for _,key in ipairs(keys)do parts[#parts+1]=quote(key)..':'..encode(v[key],depth+1)end
  end
  active[v]=nil
  return(array and '['or '{')..table.concat(parts,',')..(array and ']'or '}')
 end
 return encode(value,0)
end
return M
