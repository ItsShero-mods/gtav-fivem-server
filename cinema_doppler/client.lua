local SCREEN_MODEL = `v_ilev_cin_screen`
local RENDERTARGET_NAME = "cinscreen"

local DUI_WIDTH = 1280
local DUI_HEIGHT = 720

local runtimeTxdName = "doppler_cinema_txd"
local runtimeTxnName = "doppler_cinema_txn"

local screenRenderId = -1
local duiObj = nil
local duiHandle = nil
local isPlaying = false
local currentVideoId = nil

local lastSentVolume = -1

-----------------------------------------------------------------------
-- Utility: chat message
-----------------------------------------------------------------------
local function cinemaChat(msg)
    TriggerEvent("chat:addMessage", {
        color = { 50, 200, 255 },
        multiline = true,
        args = { "[Cinema]", msg }
    })
end

-----------------------------------------------------------------------
-- YouTube ID parsing
-----------------------------------------------------------------------
local function extractYoutubeId(input)
    if not input or input == "" then
        return nil
    end

    -- Bare ID
    if not string.find(input, "youtube") and not string.find(input, "youtu%.be") and not string.find(input, "/") and #input == 11 then
        return input
    end

    -- youtube.com/watch?v=ID
    local id = input:match("[?&]v=([^&]+)")
    if id then return id end

    -- youtu.be/ID
    id = input:match("youtu%.be/([^?&]+)")
    if id then return id end

    -- /embed/ID
    id = input:match("/embed/([^?&]+)")
    if id then return id end

    return nil
end

-----------------------------------------------------------------------
-- DUI helpers
-----------------------------------------------------------------------
local function destroyDui()
    if duiObj then
        DestroyDui(duiObj)
        duiObj = nil
        duiHandle = nil
    end
    isPlaying = false
    currentVideoId = nil
    lastSentVolume = -1
end

local function ensureDui()
    if duiObj then return end

    local resName = GetCurrentResourceName()
    local url = ("nui://%s/ui/index.html"):format(resName)

    duiObj = CreateDui(url, DUI_WIDTH, DUI_HEIGHT)
    duiHandle = GetDuiHandle(duiObj)

    local txd = CreateRuntimeTxd(runtimeTxdName)
    CreateRuntimeTextureFromDuiHandle(txd, runtimeTxnName, duiHandle)

    print("[Cinema] DUI created and texture linked.")
end

local function sendToDui(tbl)
    if not duiObj then return end
    local ok, msg = pcall(function()
        return json.encode(tbl)
    end)
    if not ok then return end
    SendDuiMessage(duiObj, msg)
end

-----------------------------------------------------------------------
-- Render target setup for Doppler cinema
-----------------------------------------------------------------------
local function setupRenderTarget()
    RequestModel(SCREEN_MODEL)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(SCREEN_MODEL) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not IsNamedRendertargetRegistered(RENDTARGET_NAME) then
        RegisterNamedRendertarget(RENDTARGET_NAME, false)
    end

    if not IsNamedRendertargetLinked(SCREEN_MODEL) then
        LinkNamedRendertarget(SCREEN_MODEL)
    end

    screenRenderId = GetNamedRendertargetRenderId(RENDTARGET_NAME)
    if screenRenderId == 0 then
        print("[Cinema] Failed to get render target id for Doppler screen")
    else
        print("[Cinema] Render target ready, id: " .. screenRenderId)
    end
end

-----------------------------------------------------------------------
-- Events from server
-----------------------------------------------------------------------
RegisterNetEvent("cinema:playYoutube", function(inputUrl, senderName)
    local videoId = extractYoutubeId(inputUrl)
    if not videoId then
        cinemaChat("Could not parse YouTube URL or ID.")
        return
    end

    ensureDui()

    currentVideoId = videoId
    isPlaying = true
    lastSentVolume = -1

    sendToDui({
        action = "play",
        videoId = videoId
    })

    local who = senderName or "Someone"
    cinemaChat(("Now playing a YouTube video set by %s."):format(who))
end)

RegisterNetEvent("cinema:stop", function(senderName)
    if isPlaying then
        sendToDui({ action = "stop" })
        isPlaying = false
        currentVideoId = nil
        lastSentVolume = -1

        local who = senderName or "Someone"
        cinemaChat(("Playback stopped by %s."):format(who))
    end
end)

RegisterNetEvent("cinema:setVolume", function(vol)
    -- Optional manual override if you ever want to wire it
    vol = math.floor(math.max(0, math.min(100, tonumber(vol) or 100)))
    sendToDui({
        action = "setVolume",
        value = vol
    })
    lastSentVolume = vol
end)

-----------------------------------------------------------------------
-- Main render and distance based volume loop
-----------------------------------------------------------------------
CreateThread(function()
    setupRenderTarget()

    local MAX_AUDIO_DIST = 70.0
    local MAX_RENDER_DIST = 200.0

    -- Rough Doppler cinema screen position, adjust if needed
    local cinemaPos = vector3(316.0, -268.0, 54.0)

    while true do
        Wait(0)

        if isPlaying and screenRenderId ~= -1 and duiHandle ~= nil then
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local dist = #(pedCoords - cinemaPos)

            ------------------------------------------------------------------
            -- Audio fade logic
            ------------------------------------------------------------------
            local targetVolume = 0

            if dist < MAX_AUDIO_DIST then
                local fade = 1.0 - (dist / MAX_AUDIO_DIST)
                if fade < 0.0 then fade = 0.0 end
                if fade > 1.0 then fade = 1.0 end

                targetVolume = math.floor(fade * 100.0)
            else
                targetVolume = 0
            end

            if targetVolume ~= lastSentVolume then
                sendToDui({
                    action = "setVolume",
                    value = targetVolume
                })
                lastSentVolume = targetVolume
            end

            ------------------------------------------------------------------
            -- Video render logic
            ------------------------------------------------------------------
            if dist < MAX_RENDER_DIST then
                SetTextRenderId(screenRenderId)
                Set_2dLayer(4)
                SetScriptGfxDrawBehindPausemenu(true)

                DrawSprite(
                    runtimeTxdName,
                    runtimeTxnName,
                    0.5, 0.5,
                    1.0, 1.0,
                    0.0,
                    255, 255, 255, 255
                )

                SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            end
        end
    end
end)

-----------------------------------------------------------------------
-- Cleanup
-----------------------------------------------------------------------
AddEventHandler("onClientResourceStop", function(resName)
    if resName == GetCurrentResourceName() then
        destroyDui()
    end
end)
