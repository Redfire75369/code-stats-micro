VERSION = "1.1.0"

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

local function curlArgs(apiKey, apiUrl)
    local body = {
        coded_at = getCurrentTime(),
        xps = {},
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
        "-s", "-S",
        "-H", "Content-Type: application/json",
        "-H", string.format("Content-Length: %d", #body),
        "-H", string.format("X-API-Token: %s", apiKey),
        "-A", string.format("micro/%s code-stats-micro/%s", util.SemVersion:string(), VERSION),
        "-d", body,
        "-w", "\n%{http_code}",
        apiUrl,
    }

    return args, totalXp
end

local function onCurlExit(output)
    if data.error ~= nil then
        micro.Log("codestats:", "Error -", data.error)
        micro.InfoBar():Message("Error - ", data.error)
        if not data.final then
            micro.After(timerInterval, sendPulseTimer(false))
        end
        return
    end

    local lines = strings.Split(output, "\n")

    local body = nil
    pcall(function() body = json.decode(lines[1]) end)
    local status = tonumber(lines[2])

    if body ~= nil and status ~= nil then
        if status == 201 and body.ok ~= nil and body.ok == "Great success!" then
            micro.Log("codestats:", string.format("Successful pulse: %d XP", data.totalXp))
            pulse = {}
        else
            local error = body.error or body
            local failed = string.format("Failed pulse (code %d) %s", status, error)
            micro.Log("codestats:", failed)
            micro.InfoBar():Message(failed)
        end
    else
        local error = body or "Unknown error"
        local failed = string.format("Failed pulse and malformed output (code %d) %s", status, error)
        micro.Log("codestats:", failed)
        micro.InfoBar():Message(failed)
    end

    if not data.final then
        micro.After(timerInterval, sendPulseTimer(false))
    end
end

local function sendPulse(apiKey, apiUrl, final)
    if apiKey == nil or apiKey == "" or next(pulse) == nil then
        if not final then
            micro.After(timerInterval, sendPulseTimer(false))
        end
        return
    end

    local args, totalXp = curlArgs(apiKey, apiUrl)
    local data = {}
    data.totalXp = totalXp
    data.final = final

    local function onStderr(chunk)
        data.error = (data.error or "") .. chunk
    end

    shell.JobSpawn("curl", args, nil, onStderr, onCurlExit, data)
end

function sendPulseTimer(final)
    return function()
        local apiKey = config.GetGlobalOption("codestats.apikey")
        local apiUrl = config.GetGlobalOption("codestats.apiurl")
        sendPulse(apiKey, apiUrl, final)
    end
end

function init()
    config.RegisterCommonOption("codestats", "apikey", nil)
    config.RegisterCommonOption("codestats", "apiurl", "https://codestats.net/api/my/pulses")

    micro.After(timerInterval, sendPulseTimer(false))
end

function onBeforeTextEvent(sbuf)
    local def = sbuf.syntaxDef
    local fileType = def ~= nil and def.header.FileType or "unknown"
    pulse[fileType] = (pulse[FileType] or 0) + 1
end
