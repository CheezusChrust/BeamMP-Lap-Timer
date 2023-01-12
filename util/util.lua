local util = {}

function util.SplitString(input, sep)
    sep = sep or "%s"
    local t = {}

    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end

    return t
end

function util.FindPlayerByName(s)
    for id, name in pairs(MP.GetPlayers()) do
        if string.find(name, s) then
            return id
        end
    end

    return -1
end

function util.Msg(id, ...)
    MP.SendChatMessage(id, "[LapTimer] " .. table.concat({...}, " "))
end

function util.TableCount(tbl)
    local n = 0

    for _, _ in pairs(tbl) do
        n = n + 1
    end

    return n
end

function util.SaveTable(name, tbl)

end

function util.LoadTable(name)

end

function util.PointToLineDist(x, y, x1, y1, x2, y2)
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

function util.SecondsToClock(seconds)
    local neg = seconds < 0
    seconds = math.abs(seconds)
    local hours = string.format("%02.f", math.floor(seconds / 3600))
    local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
    local milisecs = string.format("%02.f", math.floor((seconds % 1) * 100 + 0.5))

    return (neg and "-" or "") .. mins .. ":" .. secs .. "." .. milisecs
end

return util