-- Character customization is a lifecycle boundary, not an ordinary time pause.
local Config=require('SceneZOI.Config')
local Json=require('SceneZOI.Json')
local M={}
local elapsed=0
local state={known=false,blocked=false,editor=false}

function M.refresh()
    local ok,success,message,data=pcall(inzoi.cli.execute,'ui.get_blocking')
    if not ok or not success then state={known=false,blocked=false,editor=false};return state end
    local parsed,value=pcall(Json.decode,data or message or '')
    if not parsed or type(value)~='table' or type(value.blocked)~='boolean' or type(value.pause_reasons)~='table' then
        state={known=false,blocked=false,editor=false};return state
    end
    local editor=false
    for _,reason in ipairs(value.pause_reasons)do if reason=='CharacterCustomization'then editor=true end end
    state={known=true,blocked=value.blocked,editor=editor}
    elapsed=0
    return state
end

function M.update(dt,needed)
    if not needed then state={known=false,blocked=false,editor=false};elapsed=0;return state end
    elapsed=elapsed+dt
    if not state.known or elapsed>=Config.poll_interval then return M.refresh() end
    return state
end

function M.can_restore_input()
    -- Recheck immediately before focusing: a save may have opened the editor
    -- since the last runtime poll. Never dismiss or unpause another UI owner.
    local current=M.refresh()
    return current.known and not current.blocked and not current.editor,current
end

return M
