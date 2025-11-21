local PERMISSION = "cinema.manage"

local function denyMessage(source, msg)
    if source ~= 0 then
        TriggerClientEvent("chat:addMessage", source, {
            color = { 255, 50, 50 },
            multiline = true,
            args = { "[Cinema]", msg }
        })
    else
        print("[Cinema] " .. msg)
    end
end

RegisterCommand("cinema_play", function(source, args, raw)
    local url = table.concat(args, " ")

    if url == "" then
        denyMessage(source, "Usage: /cinema_play <YouTube URL or video ID>")
        return
    end

    if source ~= 0 and not IsPlayerAceAllowed(source, PERMISSION) then
        denyMessage(source, "You do not have permission to control the cinema.")
        return
    end

    local senderName = source ~= 0 and GetPlayerName(source) or "Console"

    TriggerClientEvent("cinema:playYoutube", -1, url, senderName)
end, false)

RegisterCommand("cinema_stop", function(source, args, raw)
    if source ~= 0 and not IsPlayerAceAllowed(source, PERMISSION) then
        denyMessage(source, "You do not have permission to control the cinema.")
        return
    end

    local senderName = source ~= 0 and GetPlayerName(source) or "Console"
    TriggerClientEvent("cinema:stop", -1, senderName)
end, false)

-- Optional volume command if you want per client volume
RegisterCommand("cinema_volume", function(source, args, raw)
    if #args < 1 then
        denyMessage(source, "Usage: /cinema_volume <0-100>")
        return
    end

    local vol = tonumber(args[1])
    if not vol or vol < 0 or vol > 100 then
        denyMessage(source, "Volume must be between 0 and 100.")
        return
    end

    -- Only affects the caller
    TriggerClientEvent("cinema:setVolume", source, vol)
end, false)
