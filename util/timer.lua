local timer = {}
local emptyFunc = function() end

function timer.Create(name, delay, reps, func)
    name = "timer_" .. name

    if _G[name] then
        MP.CancelEventTimer(name)
    end

    _G[name .. "_repsLeft"] = reps == 0 and math.huge or (reps - 1)

    _G[name] = function()
        func()

        _G[name .. "_repsLeft"] = _G[name .. "_repsLeft"] - 1

        if _G[name .. "_repsLeft"] < 0 then
            MP.CancelEventTimer(name)
        end
    end

    MP.RegisterEvent(name, name)
    MP.CreateEventTimer(name, math.floor(math.max(delay * 1000, 25)))
end

function timer.RepsLeft(name)
    name = "timer_" .. name

    return _G[name .. "_repsLeft"]
end

function timer.Simple(delay, func)
    local name = "timer_" .. string.gsub(tostring(os.clock()), "%.", "_")

    timer.Create(name, delay, 1, func)
end

function timer.Remove(name)
    name = "timer_" .. name

    if _G[name] then
        MP.CancelEventTimer(name)
    end

    _G[name] = emptyFunc
end

return timer