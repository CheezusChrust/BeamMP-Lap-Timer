local ltUtil = {}

function ltUtil.SplitString(input, sep)
    sep = sep or "%s"
    local t = {}

    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end

    return t
end

function ltUtil.FindPlayerByName(s)
    for id, name in pairs(MP.GetPlayers()) do
        if string.find(string.lower(name), string.lower(s)) then
            return id
        end
    end
end

function ltUtil.Msg(id, ...)
    MP.SendChatMessage(id, "[LapTimer] " .. table.concat({...}, " "))
end

function ltUtil.TableCount(tbl)
    local n = 0

    for _ in pairs(tbl) do
        n = n + 1
    end

    return n
end

function ltUtil.SaveConfig(name, config)
    FS.CreateDirectory("laptimer")

    local f = io.open("laptimer/" .. name .. ".json", "w+")

    if f then
        f:write(Util.JsonPrettify(Util.JsonEncode(config)))
        f:close()
    end
end

function ltUtil.LoadConfig(name)
    local f = io.open("laptimer/" .. name .. ".json", "r")

    if f then
        local config = Util.JsonDecode(f:read("*all"))
        f:close()

        return config
    else
        return
    end
end

function ltUtil.GetVehicle(id)
    local vehicles = MP.GetPlayerVehicles(id)

    if not vehicles then return end

    for vehID, _ in pairs(MP.GetPlayerVehicles(id)) do
        return vehID
    end
end

function ltUtil.GetPos(id)
    local vehID = ltUtil.GetVehicle(id)

    if not vehID then return end

    return MP.GetPositionRaw(id, vehID).pos
end

function ltUtil.PointToLineDist(x, y, x1, y1, x2, y2)
    local A = x - x1
    local B = y - y1
    local C = x2 - x1
    local D = y2 - y1

    local dot = A * C + B * D
    local len_sq = C * C + D * D
    local param = -1
    if len_sq ~= 0 then --in case of 0 length line
        param = dot / len_sq
    end

    local xx
    local yy

    if param < 0 then
        xx = x1
        yy = y1
    elseif param > 1 then
        xx = x2
        yy = y2
    else
        xx = x1 + param * C
        yy = y1 + param * D
    end

    local dx = x - xx
    local dy = y - yy

    return math.sqrt(dx * dx + dy * dy)
end

function ltUtil.SecondsToClock(seconds)
    local neg = seconds < 0
    seconds = math.abs(seconds)
    local hours = string.format("%02.f", math.floor(seconds / 3600))
    local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
    local milisecs = string.format("%02.f", math.floor((seconds % 1) * 100 + 0.5))

    return (neg and "-" or "") .. mins .. ":" .. secs .. "." .. milisecs
end

return ltUtil