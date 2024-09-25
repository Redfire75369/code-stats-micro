VERSION = "1.0.2"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local util = import("micro/util")
local strings = import("strings")
local time = import("time")

local timerInterval = time.ParseDuration("10s")
local pulse = {}

function getCurrentTime()
    local timestamp = os.date("%Y-%m-%dT%H:%M:%S%z")
    return string.format("%s:%s", string.sub(timestamp, 1, -3), string.sub(timestamp, -2, -1))
end

local function sendPulse(apiKey, apiUrl)
    if apiKey == nil or apiKey == "" or next(pulse) == nil then
        return
    end

    local body = {
        coded_at = getCurrentTime(),
        xps = {}
    }

    local totalXp = 0

    for fileType, xp in pairs(pulse) do
        table.insert(body.xps, {
            language = getLanguage(fileType),
            xp = xp,
        })
        totalXp = totalXp + xp
    end

    local body = json.encode(body)

    local args = {
        "-s",
        "-H", "Content-Type: application/json",
        "-H", string.format("Content-Length: %d", #body),
        "-H", string.format("X-API-Token: %s", apiKey),
        "-A", string.format("micro/%s code-stats-micro/%s", util.SemVersion:string(), VERSION),
        "-d", body,
        "-w", "\n%{http_code}",
        apiUrl,
    }

    local output, err = shell.ExecCommand("curl", unpack(args))
    if err ~= nil then
        micro.Log("codestats:", "Error while executing curl", output)
        micro.InfoBar():Message("Error while executing curl", output)
        return
    end

    local lines = strings.Split(output, "\n")

    local body = nil
    pcall(function() body = json.decode(lines[1]) end)
    local status = tonumber(lines[2])

    if body ~= nil and status ~= nil then
        if status == 201 and body.ok ~= nil and body.ok == "Great success!" then
            micro.Log("codestats:", string.format("Successful pulse: %d XP", totalXp))
            pulse = {}
        else
            local error = ""
            if body.error ~= nil then
                error = body.error
            end

            local failed = string.format("Failed pulse (code %d) %s", status, error)
            micro.Log("codestats:", failed)
            micro.InfoBar():Message(failed)
        end
    end
end

local function sendPulseTimer(final)
    return function()
        local apiKey = config.GetGlobalOption("codestats.apikey")
        local apiUrl = config.GetGlobalOption("codestats.apiurl")
        sendPulse(apiKey, apiUrl)
        if not final then
            micro.After(timerInterval, sendPulseTimer(false))
        end
    end
end

function init()
    config.RegisterCommonOption("codestats", "apikey", nil)
    config.RegisterCommonOption("codestats", "apiurl", "https://codestats.net/api/my/pulses")

    micro.After(timerInterval, sendPulseTimer(false))
end

function onBeforeTextEvent(sbuf, textEvent)
    local def = sbuf.syntaxDef

    local fileType
    if def == nil then
        fileType = def.header.FileType
    else
        fileType = "unknown"
    end

	if pulse[fileType] == nil then
		pulse[fileType] = 0
	end

	pulse[fileType] = pulse[fileType] + 1
end
