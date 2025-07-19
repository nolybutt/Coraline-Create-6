-- 脚本的位置是 "{命名空间}:{路径}"，那么 require 的格式为 "{命名空间}_{路径}"
-- 注意！require 取得的内容不应该被修改，应仅调用
local default = require("tacz_default_state_machine")
local STATIC_TRACK_LINE = default.STATIC_TRACK_LINE
local MAIN_TRACK = default.MAIN_TRACK
local main_track_states = default.main_track_states
local static_track_top = default.static_track_top

local GUN_KICK_TRACK_LINE = default.GUN_KICK_TRACK_LINE
local gun_kick_state = default.gun_kick_state

local inspect_state = setmetatable({}, {__index = main_track_states.inspect})
local idle_state = setmetatable({}, {__index = main_track_states.idle})

-- 相当于 obj.value++
local function increment(obj)
    obj.value = obj.value + 1
    return obj.value - 1
end

local FIRE_MODE_TRACK = increment(static_track_top)
local SWITCH_MODE_TRACK = increment(static_track_top)

-- 检查当前是否还有弹药
local function isNoAmmo(context)
    return (not context:hasBulletInBarrel()) and (context:getAmmoCount() <= 0)
end

local function runReloadAnimation(context)
    local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
    local ext = context:getMagExtentLevel()
    if (isNoAmmo(context)) then
        if (ext == 0) then
            context:runAnimation("reload_empty", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 1) then
            context:runAnimation("reload_empty_xmag_1", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 2) then
            context:runAnimation("reload_empty_xmag_2", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 3) then
            context:runAnimation("reload_empty_xmag_3", track, false, PLAY_ONCE_STOP, 0.2)
        else
            context:runAnimation("reload_empty", track, false, PLAY_ONCE_STOP, 0.2)
        end
    else
        if (ext == 0) then
            context:runAnimation("reload_tactical", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 1) then
            context:runAnimation("reload_tactical_xmag_1", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 2) then
            context:runAnimation("reload_tactical_xmag_2", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 3) then
            context:runAnimation("reload_tactical_xmag_3", track, false, PLAY_ONCE_STOP, 0.2)
        else
            context:runAnimation("reload_tactical", track, false, PLAY_ONCE_STOP, 0.2)
        end
    end
end

local function runInspectAnimation(context)
    local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
    local ext = context:getMagExtentLevel()
    if (isNoAmmo(context)) then
        if (ext == 3) then
            context:runAnimation("inspect_empty_xmag_3", track, false, PLAY_ONCE_STOP, 0.2)
        else
            context:runAnimation("inspect_empty", track, false, PLAY_ONCE_STOP, 0.2)
        end
    else
        if (ext == 3) then
            context:runAnimation("inspect_xmag_3", track, false, PLAY_ONCE_STOP, 0.2)
        elseif (ext == 1 or ext == 2) then
            context:runAnimation("inspect_xmag_12", track, false, PLAY_ONCE_STOP, 0.2)
        else
            context:runAnimation("inspect", track, false, PLAY_ONCE_STOP, 0.2)
        end
    end
end

function idle_state.transition(this, context, input)
    if (input == INPUT_RELOAD) then
        runReloadAnimation(context)
        return this.main_track_states.idle
    end
    if (input == INPUT_PUT_AWAY) then
        local put_away_time = context:getPutAwayTime()
        local track = context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK)
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, SWITCH_MODE_TRACK))
        context:runAnimation("put_away", track, false, PLAY_ONCE_HOLD, put_away_time * 0.75)
        context:setAnimationProgress(track, 1, true)
        context:adjustAnimationProgress(track, -put_away_time, false)
        return this.main_track_states.final
    end
    if (input == INPUT_INSPECT) then
        runInspectAnimation(context)
        return inspect_state
    end
    return main_track_states.idle.transition(this, context, input)
end

local fire_mode_state = {
    semi = {},
    auto = {},
    draw = {}
}

function fire_mode_state.draw.update(this, context)
    context:trigger(this.INPUT_MODE_DRAW)
end

function fire_mode_state.draw.transition(this, context, input)
    if (input == this.INPUT_MODE_DRAW) then
        if (context:getFireMode() == SEMI) then
            context:runAnimation("static_semi", context:getTrack(STATIC_TRACK_LINE, FIRE_MODE_TRACK), true, PLAY_ONCE_HOLD, 0)
            return fire_mode_state.semi
        elseif (context:getFireMode() == AUTO) then
            context:runAnimation("static_auto", context:getTrack(STATIC_TRACK_LINE, FIRE_MODE_TRACK), true, PLAY_ONCE_HOLD, 0)
            return fire_mode_state.auto
        end
    end
end

function fire_mode_state.semi.update(this, context)
    local track = context:getTrack(STATIC_TRACK_LINE, FIRE_MODE_TRACK)
    if (context:isHolding(track)) then
        context:runAnimation("static_semi", track, true, PLAY_ONCE_HOLD, 0)
    end
    if (context:getFireMode() == AUTO) then
        context:trigger(this.INPUT_MODE_AUTO)
    end
end

function fire_mode_state.semi.transition(this, context, input)
    if (input == this.INPUT_MODE_AUTO) then
        context:runAnimation("switch_auto", context:getTrack(STATIC_TRACK_LINE, SWITCH_MODE_TRACK), false, PLAY_ONCE_STOP, 0)
        return fire_mode_state.auto
    end
    if (input == INPUT_SHOOT or input == INPUT_RELOAD or input == INPUT_INSPECT) then
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, SWITCH_MODE_TRACK))
    end
end

function fire_mode_state.auto.update(this, context)
    local track = context:getTrack(STATIC_TRACK_LINE, FIRE_MODE_TRACK)
    if (context:isHolding(track)) then
        context:runAnimation("static_auto", track, true, PLAY_ONCE_HOLD, 0)
    end
    if (context:getFireMode() == SEMI) then
        context:trigger(this.INPUT_MODE_SEMI)
    end
end

function fire_mode_state.auto.transition(this, context, input)
    if (input == this.INPUT_MODE_SEMI) then
        context:runAnimation("switch_semi", context:getTrack(STATIC_TRACK_LINE, SWITCH_MODE_TRACK), false, PLAY_ONCE_STOP, 0)
        return fire_mode_state.semi
    end
    if (input == INPUT_SHOOT or input == INPUT_RELOAD or input == INPUT_INSPECT) then
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, SWITCH_MODE_TRACK))
    end
end

function inspect_state.transition(this, context, input)
    if (input == INPUT_FIRE_SELECT) then
        context:stopAnimation(context:getTrack(STATIC_TRACK_LINE, MAIN_TRACK))
        return this.main_track_states.idle
    end
    return main_track_states.inspect.transition(this, context, input)
end

-- HOPE STATE
local shoot_animations = {
    "shoot_1", "shoot_2", "shoot_3", "shoot_4",
    "shoot_5", "shoot_6", "shoot_7", "shoot_8"
}
local shoot_animation_index = 1
local last_shoot_animation = "shoot_last"
local bolt_catch_animation = "static_bolt_caught"

local function getNextShootAnimation()
    return shoot_animations[math.random(#shoot_animations)]
end

local shoot_state = setmetatable({}, { __index = gun_kick_state })

function shoot_state.transition(this, context, input)
    if input ~= INPUT_SHOOT then return nil end

    local fireMode = context:getFireMode()
    if fireMode ~= SEMI and fireMode ~= AUTO and fireMode ~= BURST then
        return nil
    end

    local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)

    if context:getAmmoCount() == 0 then
        context:runAnimation(last_shoot_animation, track, true, PLAY_ONCE_STOP, 0)
        context:setFlag("played_shoot_last", true)
    else
        local anim = getNextShootAnimation()
        context:runAnimation(anim, track, true, PLAY_ONCE_STOP, 0)
    end

    return nil
end

function idle_state.transition(this, context, input)
    local track = context:findIdleTrack(GUN_KICK_TRACK_LINE, false)

    if context:getAmmoCount() == 0
        and context:getFlag("played_shoot_last")
        and not context:isTrackPlaying(track) then
        context:runAnimation(bolt_catch_animation, track, true, PLAY_ONCE_STOP, 0)
        context:setFlag("played_shoot_last", false)
    end

    return main_track_states.idle.transition(this, context, input)
end

-- HOPE STATE END

local M = setmetatable({
    gun_kick_state = setmetatable({}, { __index = shoot_state }),
    idle = idle_state,
    main_track_states = setmetatable({
        inspect = inspect_state
    }, { __index = main_track_states }),
    FIRE_MODE_TRACK = FIRE_MODE_TRACK,
    SWITCH_MODE_TRACK = SWITCH_MODE_TRACK,
    INPUT_MODE_SEMI = "input_mode_semi",
    INPUT_MODE_BURST = "input_mode_burst",
    INPUT_MODE_AUTO = "input_mode_auto",
    INPUT_MODE_DRAW = "input_mode_draw",
    fire_mode_state = fire_mode_state
}, { __index = default })

function M:initialize(context)
    default.initialize(self, context)
end

function M:states()
    return {
        self.base_track_state,
        self.bolt_caught_states.normal,
        self.main_track_states.start,
        self.gun_kick_state,
        self.movement_track_states.idle,
        self.ADS_states.normal,
        self.slide_states.normal,
        self.fire_mode_state.draw
    }
end

return M
