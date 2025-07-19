-- Define the module
local M = {}

-- Function to initialize aiming logic
function M.start_aiming(api)
    -- Cache for storing aiming state
    local cache = {
        is_aiming = false -- Flag to track if the player is currently aiming
    }
    -- Save the cache to the player's data
    api:cacheScriptData(cache)
    return true
end

local function getReloadTimingFromParam(param)
    local aim_start = param.aim_start * 1000
    local aim_end = aim_end * 1000
    -- 这两个判断是用来检查以上 12 个参数是否有缺失的，若有缺失则不获取任何参数。其实是可以写进一个判断语句的，但是这样的话整个句子会过长影响阅读所以我就拆成 3 个了
    if (aim_start == nil or aim_end) then
        return nil
    end
    -- 顺序返回获取到的这 12 个参数
    return static_idle
end

-- Function to handle right-click input
function M.tick_aim(api)
    -- Retrieve cached data
    local cache = api:getCachedScriptData()

    -- Check if the player is holding the right mouse button
    if api:isRightClickHeld() then
        -- If not already aiming, start aiming
        if not cache.is_aiming then
            cache.is_aiming = true
            api:playAnimation("aim_start") -- Play aim start animation
        end
        -- Continue playing aim loop animation
        api:playAnimation("aim_loop")
    else
        -- If the player releases the right mouse button, stop aiming
        if cache.is_aiming then
            cache.is_aiming = false
            api:playAnimation("aim_end") -- Play aim end animation
        end
    end

    -- Update cache data
    api:cacheScriptData(cache)
end

-- Return the module
return M
