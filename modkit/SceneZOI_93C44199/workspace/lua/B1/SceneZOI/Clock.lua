-- Owns scene time and native-game time. Watchdogs use unscaled host time.
local Config = require("SceneZOI.Config")
local M = {}
M.__index = M

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function M.delta(value)
    return finite(value) and math.max(value, 0) or 0
end

function M.game_scale()
    local system = assert(inzoi.UB1System.Get(), "Game client system is unavailable")
    local manager = assert(system:GetTimeManager(), "Game time manager is unavailable")
    local scale = manager:GetTimeScale()
    assert(finite(scale) and scale >= 0, "Game returned an invalid time scale")
    -- This is the effective simulation multiplier, including pause reasons.
    -- Do not multiply by the separate real-seconds-to-calendar-minutes ratio.
    return scale
end

function M.new()
    return setmetatable({index = 2, elapsed = 0, session_elapsed = 0, game_elapsed = 0, scale = 0, effective = 0}, M)
end

function M:select(index)
    assert(type(index) == "number" and index % 1 == 0 and Config.playback_speeds[index], "Invalid playback speed")
    local changed = self.index ~= index
    self.index = index
    self.effective = self.scale * Config.playback_speeds[index] * (self.modifier or 1)
    return changed
end

function M:reset_node()
    self.elapsed = 0
    self.modifier = 1
end

function M:advance(real_dt, game_scale, modifier)
    assert(finite(game_scale) and game_scale >= 0, "Invalid game time scale")
    self.modifier = modifier or self.modifier or 1
    assert(finite(self.modifier) and self.modifier > 0 and self.modifier <= 2.000001, "Invalid playback modifier")
    self.scale = game_scale
    self.effective = game_scale * Config.playback_speeds[self.index] * self.modifier
    local elapsed = M.delta(real_dt) * self.effective
    self.game_elapsed = self.game_elapsed + M.delta(real_dt) * game_scale
    self.elapsed = self.elapsed + elapsed
    self.session_elapsed = self.session_elapsed + elapsed
end

function M:position(duration, kind)
    assert(duration > 0, "Node duration must be positive")
    if kind == "transition" then
        -- Do not seek a paused montage to its native end boundary (which can retire it).
        local epsilon = math.min(duration / 2, math.max(0.0001, duration * 0.000001))
        return math.min(self.elapsed, duration - epsilon)
    end
    return self.elapsed % duration
end

function M:finished(duration, kind)
    return kind == "transition" and self.elapsed >= duration
end

return M
