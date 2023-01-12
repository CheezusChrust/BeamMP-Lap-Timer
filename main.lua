local hook = require("util/hook")
local timer = require("util/timer")
local util = require("util/util")

local pointToPoint = true --If true, ignore lap count and treat as a point-to-point rally - the start line is now the finish line
local totalLaps = 3 --Total lap count
local minLapTime = 30 --Minimum time, in seconds, before detecting a car after event start OR after a car completes a lap

local countdown = 5 --How many seconds to count down after running /start, 0 to start instantly

--Ignore everything below here

local started = false
local startTime
local racers = {}
local finishedRacers = 0
local finishStr = "Final results:"
local admins = {}
local p1 = {0, 0}
local p2 = {0, 0}

hook.Add("onConsoleInput", "LapTimer_ConControl", function(str)
    local args = util.SplitString(str)

    if args[1] == "lt" then
        if args[2] == "admin" then
            local id = util.FindPlayerByName(args[3])

            if id > -1 then
                admins[id] = true

                return "Promoted " .. MP.GetPlayers()[id] .. " to lap timer admin"
            else
                return "Couldn't find player with name '" .. args[3] .. "'"
            end
        end

        if args[2] == "demote" then
            local id = util.FindPlayerByName(args[3])

            if id > -1 and admins[id] then
                admins[id] = nil

                return "Demoted " .. MP.GetPlayers()[id] .. " from lap timer admin"
            else
                return "Couldn't find admin with name '" .. args[3] .. "'"
            end
        end
    end
end)

local function addRacer(ply)
    racers[ply] = {
        filterTime = 0,
        lap = 0,
        lastLapTime = 0,
        lastLapSysTime = 0, --systime at which the last lap was completed
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
    local args = util.SplitString(str)

    if args[1] ~= "/lt" then
        return
    end

    if not admins[id] then
        --util.Msg(id, "You must be an admin to use this command.")

        --return 1
    end

    if args[2] == "add" and args[3] then
        local ply = util.FindPlayerByName(args[3])

        if ply == -1 then
            util.Msg(id, "Player not found")

            return 1
        end

        if racers[ply] then
            util.Msg(id, "Player already in event")

            return 1
        end

        addRacer(ply)

        util.Msg(id, "Added " .. MP.GetPlayers()[ply])

        return 1
    end

    if args[2] == "remove" and args[3] then
        local ply = util.FindPlayerByName(args[3])

        if ply == -1 or not racers[ply] then
            util.Msg(id, "Player not found in event")

            return 1
        end

        racers[ply] = nil

        if started then
            util.Msg(-1, MP.GetPlayers()[ply] .. " has retired from the event")
        end

        if not next(racers) then
            reset()
        end

        util.Msg(id, "Removed " .. MP.GetPlayers()[ply])

        return 1
    end

    if args[2] == "start" then
        if started then
            util.Msg(id, "An event is currently running, type '/lt reset' to reset the script")

            return 1
        end

        if not next(racers) then
            util.Msg(id, "No players added to event")

            return 1
        end

        local count = util.TableCount(racers)

        if countdown == 0 then
            started = true
            startTime = timer.systime()

            for _, data in pairs(racers) do
                data.lastLapSysTime = 0
                data.filterTime = 0
            end

            util.Msg(-1, "A " .. (pointToPoint and "rally" or ("race with " .. count .. " driver" .. (count > 1 and "s" or ""))) .. " has been started!")
        else
            timer.Create("LapTimer_Countdown", 1, countdown + 1, function()
                local time = timer.RepsLeft("LapTimer_Countdown")

                local txt

                if time == countdown then
                    txt = "A " .. (pointToPoint and "rally" or ("race with " .. count .. " driver" .. (count > 1 and "s" or ""))) .. " is starting in " .. time .. "..."
                elseif time > 0 then
                    txt = time .. "..."
                else
                    txt = "GO!"
                end

                util.Msg(-1, txt)

                if time == 0 then
                    started = true
                    startTime = os.clock()

                    for _, data in pairs(racers) do
                        data.lastLapSysTime = 0
                        data.filterTime = 0
                    end
                end
            end)
        end

        return 1
    end

    if args[2] == "reset" then
        reset()

        util.Msg(id, "Script has been reset")

        return 1
    end

    util.Msg(id, "Invalid command")

    return 1
end)

hook.Add("onPlayerDisconnect", "LapTimer_PlayerLeave", function(id)
    util.Msg(-1, MP.GetPlayers()[id] .. " has retired from the event")

    racers[id] = nil
end)

local function checkHitFinish(onHit)
    if not next(racers) then return end
end

local function onHitFinishP2P(id)
    local totalTime = os.clock() - startTime

    util.Msg(-1, MP.GetPlayers()[id] .. " has finished with a time of " .. util.SecondsToClock(totalTime))

    racers[id].fastestLap = totalTime
    racers[id].lastLapTime = totalTime

    reset()
end

local function onHitFinish(id)
    racers[id].lap = racers[id].lap + 1
    local lastLapTime = os.clock() - racers[id].lastLapSysTime
    racers[id].lastLapSysTime = os.clock()

    local name = MP.GetPlayers()[id]

    if racers[id].lap > 1 then
        if lastLapTime < racers[id].fastestLap and racers[id].lap > 1 then
            racers[id].fastestLap = lastLapTime
        end

        racers[id].lastLapTime = lastLapTime
    end

    if racers[id].lap < totalLaps + 1 then
        local prev = racers[id].lap == 1 and "" or (" (prev lap: " .. util.SecondsToClock(lastLapTime) .. ")")
        util.Msg(-1, name .. " is on lap " .. racers[id].lap .. prev)
    else
        racers[id].filterTime = math.huge
        util.Msg(-1, name .. " has finished with an overall time of " .. util.SecondsToClock(os.clock() - startTime) .. " and a best lap of " .. util.SecondsToClock(racers[id].fastestLap))
        finishedRacers = finishedRacers + 1
        finishStr = finishStr .. "\n" .. finishedRacers .. ". " .. name .. " (" .. util.SecondsToClock(timer.systime() - startTime) .. ", best: " .. util.SecondsToClock(racers[id].fastestLap) .. ")"

        if finishedRacers == util.TableCount(racers) then
            util.Msg(-1, finishStr)

            reset()
        end
    end
end

timer.Create("LapTimer_Interval", 0, 0, function()
    if not started then return end

    if pointToPoint then
        checkHitFinish(onHitFinishP2P)

        return
    end

    checkHitFinish(onHitFinish)
end)