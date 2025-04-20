local hook = require("util/hook")
local timer = require("util/timer")
local ltUtil = require("util/util")

local config = {}

config.pointToPoint = 1 -- If non-zero, ignore lap count and treat as a point-to-point rally - the start line is now the finish line
config.totalLaps = 3 -- Total lap count
config.minLapTime = 5 -- Minimum time, in seconds, before detecting a car after event start OR after a car completes a lap
config.countdown = 5 -- How many seconds to count down after running /start, 0 to start instantly
config.p1 = {0, 0}
config.p2 = {0, 0}

-- Ignore everything below here

local started = false
local timerObj
local racers = {}
local finishedRacers = 0
local finishStr = "Final results:"
local admins = {}

local function tostring2(var)
    if type(var) == "table" then
        local ret = "{" .. tostring2(var[1])

        for i = 2, #var do
            ret = ret .. ", " .. tostring2(var[i])
        end

        return ret .. "}"
    else
        return tostring(var)
    end
end

hook.Add("onConsoleInput", "LapTimer_ConControl", function(str)
    local args = ltUtil.SplitString(str)

    if args[1] == "lt" then
        if args[2] == "promote" then
            if args[3] then
                local id = ltUtil.FindPlayerByName(args[3])

                if id then
                    admins[id] = true

                    return "Promoted " .. MP.GetPlayers()[id] .. " to lap timer admin"
                else
                    return "Couldn't find player with name '" .. (args[3] or "") .. "'"
                end
            else
                return "You must specify a player name"
            end
        end

        if args[2] == "demote" then
            if args[3] then
                local id = ltUtil.FindPlayerByName(args[3])

                if id and admins[id] then
                    admins[id] = nil

                    return "Demoted " .. MP.GetPlayers()[id] .. " from lap timer admin"
                else
                    return "Couldn't find admin with name '" .. (args[3] or "") .. "'"
                end
            else
                return "You must specify a player name"
            end
        end

        if args[2] == "config" then
            if args[3] then
                if config[args[3]] then
                    if args[4] then
                        config[args[3]] = tonumber(args[4])

                        return "Set " .. args[3] .. " to " .. config[args[3]]
                    else
                        return args[3] .. " = " .. config[args[3]]
                    end
                else
                    return "Invalid key '" .. args[3] .. "'"
                end
            else
                local ret = "Config:"

                for k, v in pairs(config) do
                    ret = ret .. "\n" .. k .. " = " .. tostring2(v)
                end

                return ret
            end
        end

        if args[2] == "savecfg" then
            if args[3] then
                ltUtil.SaveConfig(args[3], config)

                return "Saved configuration '" .. args[3] .. "'"
            else
                return "You must specify a configuration name"
            end
        end

        if args[2] == "loadcfg" then
            if args[3] then
                local newConfig = ltUtil.LoadConfig(args[3])

                if newConfig then
                    config = newConfig

                    return "Loaded configuration '" .. args[3] .. "'"
                else
                    return "Couldn't find configuration with name '" .. (args[3] or "") .. "'"
                end
            else
                return "You must specify a configuration name"
            end
        end
    end
end)

local function addRacer(ply)
    racers[ply] = {
        filterTime = 0,
        lap = 0,
        lastLapDuration = 0,
        lastLapFinishTime = 0,
        fastestLap = math.huge
    }
end

local function reset()
    racers = {}
    timer.Remove("Countdown")
    started = false
    finishedRacers = 0
    finishStr = "Final Results:"
end

hook.Add("onChatMessage", "LapTimer_ChatControl", function(id, _, str)
    local args = ltUtil.SplitString(str)

    if args[1] ~= "/lt" then
        return
    end

    if not admins[id] then
        ltUtil.Msg(id, "You must be an admin to use this command")

        return 1
    end

    if args[2] == "p1" then
        local pos = ltUtil.GetPos(id)

        if not pos then
            ltUtil.Msg(id, "You are not in a vehicle")

            return 1
        end

        config.p1 = pos

        ltUtil.Msg(id, "Set p1 to " .. math.floor(config.p1[1]) .. ", " .. math.floor(config.p1[2]))

        return 1
    end

    if args[2] == "p2" then
        local pos = ltUtil.GetPos(id)

        if not pos then
            ltUtil.Msg(id, "You are not in a vehicle")

            return 1
        end

        config.p2 = pos

        ltUtil.Msg(id, "Set p2 to " .. math.floor(config.p2[1]) .. ", " .. math.floor(config.p2[2]))

        return 1
    end

    if args[2] == "add" and args[3] then
        local ply = ltUtil.FindPlayerByName(args[3])

        if ply == -1 then
            ltUtil.Msg(id, "Player not found")

            return 1
        end

        if racers[ply] then
            ltUtil.Msg(id, "Player already in event")

            return 1
        end

        addRacer(ply)

        ltUtil.Msg(id, "Added " .. MP.GetPlayers()[ply])

        return 1
    end

    if args[2] == "remove" and args[3] then
        local ply = ltUtil.FindPlayerByName(args[3])

        if not ply or not racers[ply] then
            ltUtil.Msg(id, "Player not found in event")

            return 1
        end

        racers[ply] = nil

        if started then
            ltUtil.Msg(-1, MP.GetPlayers()[ply] .. " has retired from the event")
        end

        if not next(racers) then
            reset()
        end

        ltUtil.Msg(id, "Removed " .. MP.GetPlayers()[ply])

        return 1
    end

    if args[2] == "start" then
        if started then
            ltUtil.Msg(id, "An event is currently running, type '/lt reset' to reset the script")

            return 1
        end

        if not next(racers) then
            ltUtil.Msg(id, "No players added to event")

            return 1
        end

        if config.p1[1] == config.p2[1] and config.p1[2] == config.p2[2] then
            ltUtil.Msg(id, "Start line not defined!")

            return 1
        end

        local count = ltUtil.TableCount(racers)

        if config.countdown == 0 then
            started = true
            timerObj = MP.CreateTimer()

            for _, data in pairs(racers) do
                data.lastLapFinishTime = 0
                data.filterTime = 0
            end

            ltUtil.Msg(-1, "A " .. ((config.pointToPoint ~= 0) and "rally" or ("race with " .. count .. " driver" .. (count > 1 and "s" or ""))) .. " has been started!")
        else
            timer.Create("LapTimer_Countdown", 1, config.countdown + 1, function()
                local time = timer.RepsLeft("LapTimer_Countdown")

                local txt

                if time == config.countdown then
                    txt = "A " .. ((config.pointToPoint ~= 0) and "rally" or ("race with " .. count .. " driver" .. (count > 1 and "s" or ""))) .. " is starting in " .. time .. "..."
                elseif time > 0 then
                    txt = time .. "..."
                else
                    txt = "GO!"
                end

                ltUtil.Msg(-1, txt)

                if time == 0 then
                    started = true
                    timerObj = MP.CreateTimer()

                    for _, data in pairs(racers) do
                        data.lastLapFinishTime = 0
                        data.filterTime = 0
                    end
                end
            end)
        end

        return 1
    end

    if args[2] == "savecfg" then
        if not args[3] then
            ltUtil.Msg(id, "You must specify a name for the configuration")

            return 1
        end

        if ltUtil.SaveConfig(args[3], config) then
            ltUtil.Msg(id, "Saved configuration as '" .. args[3] .. "'")
        else
            ltUtil.Msg(id, "Failed to save configuration")
        end

        return 1
    end

    if args[2] == "loadcfg" then
        if not args[3] then
            ltUtil.Msg(id, "You must specify a name for the configuration")

            return 1
        end

        local loadedConfig = ltUtil.LoadConfig(args[3])

        if not loadedConfig then
            ltUtil.Msg(id, "Failed to load configuration")

            return 1
        end

        config = loadedConfig

        ltUtil.Msg(id, "Loaded configuration '" .. args[3] .. "'")

        return 1
    end

    if args[2] == "config" then
        if args[3] then
            if config[args[3]] then
                if args[4] then
                    config[args[3]] = tonumber(args[4])

                    ltUtil.Msg(id, "Set " .. args[3] .. " to " .. config[args[3]])
                else
                    ltUtil.Msg(id, args[3] .. " = " .. config[args[3]])
                end
            else
                ltUtil.Msg(id, "Invalid key '" .. args[3] .. "'")
            end
        else
            ltUtil.Msg(id, "Key not specified")
        end

        return 1
    end

    if args[2] == "reset" then
        reset()

        ltUtil.Msg(id, "Script has been reset")

        return 1
    end

    ltUtil.Msg(id, "Invalid command")

    return 1
end)

hook.Add("onPlayerDisconnect", "LapTimer_PlayerLeave", function(id)
    if racers[id] then
        ltUtil.Msg(-1, MP.GetPlayers()[id] .. " has retired from the event")
    end

    racers[id] = nil
end)

local function checkHitFinish(onHit)
    if not racers or not next(racers) then return end

    for racer, data in pairs(racers) do
        local pos = ltUtil.GetPos(racer)

        if pos then
            local distToFinish = ltUtil.PointToLineDist(pos[1], pos[2], config.p1[1], config.p1[2], config.p2[1], config.p2[2])

            if os.time() - data.filterTime > config.minLapTime and distToFinish < 2 then
                data.filterTime = os.time()
                onHit(racer)
            end
        else
            ltUtil.Msg(-1, MP.GetPlayers()[racer] .. " has retired from the event")

            racers[racer] = nil

            if ltUtil.TableCount(racers) == 0 then
                reset()
            end
        end
    end
end

local function onHitFinishP2P(id)
    local totalTime = timerObj:GetCurrent()

    ltUtil.Msg(-1, MP.GetPlayers()[id] .. " has finished with a time of " .. ltUtil.SecondsToClock(totalTime))

    finishedRacers = finishedRacers + 1

    if finishedRacers == ltUtil.TableCount(racers) then
        reset()
    end
end

local function onHitFinish(id)
    racers[id].lap = racers[id].lap + 1
    local lastLapDuration = os.time() - racers[id].lastLapFinishTime
    racers[id].lastLapFinishTime = os.time()

    local name = MP.GetPlayers()[id]

    if racers[id].lap > 1 then
        if lastLapDuration < racers[id].fastestLap and racers[id].lap > 1 then
            racers[id].fastestLap = lastLapDuration
        end

        racers[id].lastLapDuration = lastLapDuration
    end

    if racers[id].lap < config.totalLaps + 1 then
        local prev = racers[id].lap == 1 and "" or (" (prev lap: " .. ltUtil.SecondsToClock(lastLapDuration) .. ")")
        ltUtil.Msg(-1, name .. " is on lap " .. racers[id].lap .. prev)
    else
        racers[id].filterTime = math.huge
        ltUtil.Msg(-1, name .. " has finished with an overall time of " .. ltUtil.SecondsToClock(timerObj:GetCurrent()) .. " and a best lap of " .. ltUtil.SecondsToClock(racers[id].fastestLap))
        finishedRacers = finishedRacers + 1
        finishStr = finishStr .. "\n" .. finishedRacers .. ". " .. name .. " (" .. ltUtil.SecondsToClock(timerObj:GetCurrent()) .. ", best: " .. ltUtil.SecondsToClock(racers[id].fastestLap) .. ")"

        if finishedRacers == ltUtil.TableCount(racers) then
            for _, v in ipairs(ltUtil.SplitString(finishStr, "\n")) do
                ltUtil.Msg(-1, v)
            end

            reset()
        end
    end
end

timer.Create("LapTimer_Interval", 0, 0, function()
    if not started then return end

    if config.pointToPoint ~= 0 then
        checkHitFinish(onHitFinishP2P)

        return
    end

    checkHitFinish(onHitFinish)
end)

print("LapTimer loaded!")