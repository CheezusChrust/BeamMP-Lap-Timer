local hook = {}
local emptyFunc = function() end

function hook.Add(name, id, func)
    local funcName = "hook_" .. name .. id
    _G[funcName] = func

    MP.RegisterEvent(name, funcName)
end

function hook.Remove(name, id)
    local funcName = "hook_" .. name .. id
    _G[funcName] = emptyFunc
end

return hook