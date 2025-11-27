local pedNetId = nil
local pedEntity = nil
local isRainingMoney = false

-------------------------------------------------------
-- SPAWN PED (broadcast from server)
-------------------------------------------------------
RegisterNetEvent("testped:createPed")
AddEventHandler("testped:createPed", function(coords, heading)
    local model = `a_f_y_hipster_01`

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    -- ensure ped spawns on ground
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if foundGround then coords = vector3(coords.x, coords.y, groundZ) end

    pedEntity = CreatePed(4, model, coords.x, coords.y, coords.z, heading, true, true)

    -- make invincible/static
    FreezeEntityPosition(pedEntity, true)
    SetEntityInvincible(pedEntity, true)
    SetBlockingOfNonTemporaryEvents(pedEntity, true)

    -- network it
    pedNetId = NetworkGetNetworkIdFromEntity(pedEntity)
    SetNetworkIdExistsOnAllMachines(pedNetId, true)

    -- send net id back to server ONCE
    TriggerServerEvent("testped:storeNetId", pedNetId)
end)

-------------------------------------------------------
-- DELETE PED (everyone runs this)
-------------------------------------------------------
RegisterNetEvent("testped:deletePed")
AddEventHandler("testped:deletePed", function(netId)
    if netId then
        local entity = NetToPed(netId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    pedEntity = nil
    pedNetId = nil
end)

-------------------------------------------------------
-- Commands
-------------------------------------------------------

RegisterCommand("spawnTestPed", function()
    local p = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(p, 0.0, 2.0, 0.0)
    local heading = GetEntityHeading(p)

    TriggerServerEvent("testped:spawnForEveryone", coords, heading)
end)

RegisterCommand("deleteTestPed", function()
    TriggerServerEvent("testped:deleteForEveryone")
end)


-- OVERLAY

local activeSequence = nil
local seqIndex = 1
local seqActive = false
local seqTimeout = 0

local function generateSequence(length)
    local keys = {"W", "A", "S", "D"}
    local seq = {}

    for i = 1, length do
        seq[i] = keys[math.random(1, #keys)]
    end

    return seq
end

local sequence = generateSequence(math.random(6, 7))

local function challengeDrawText(x, y, scale, text)
    print("[VU DEBUG] Drawing Text")
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

function StartRainLoop()
    if isRainingMoney then return end
    

        -- delay 1 frame before enabling the loop
    CreateThread(function()
        Wait(0)
        isRainingMoney = true
    end)

    local ped = PlayerPedId()
    local dict = "anim@mp_player_intupperraining_cash"
    local anim = "idle_a"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    
    CreateThread(function()
        Wait(0)
        while isRainingMoney do
            -- Play the animation
            TaskPlayAnim(ped, dict, anim, 4.0, -4.0, -1, 49, 0, false, false, false)
            Wait(5000) -- adjust this for loop speed
        end
        -- Clear anim when loop stops
        ClearPedTasks(ped)
    end)

    -- MONEY LOOP — every 10 seconds remove 1 stack and give clean
    CreateThread(function()
        Wait(5000)
        while isRainingMoney do
            TriggerServerEvent("vu:launderOneBill")
            Wait(5000)
        end
    end)
    -- CHALLENGE LOOP
    CreateThread(function()
        Wait(2)

        while isRainingMoney do
            local delay = math.random(60000, 120000)
            Wait(delay)

            if not isRainingMoney then break end

            activeSequence = generateSequence(math.random(6,7))
            seqIndex = 1
            seqActive = true
            seqTimeout = GetGameTimer() + 10000

            -- Enable NUI
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "showChallenge",
                sequence = activeSequence
            })

            -- Wait until sequence ends
            while seqActive and isRainingMoney do
                Wait(0)
            end
        end
    end)
end

function StopRainLoop()
    isRainingMoney = false
    seqActive = false
    activeSequence = nil
end

RegisterNetEvent("vu:rainTick")
AddEventHandler("vu:rainTick", function(item, clean)
    lib.notify({
        title = Config.UI.notifications.success.title,
        description = "1 bill cleaned", "success",
        type = Config.UI.notifications.success.type
    })
end)


local cooldown = false
local cooldownEnd


CreateThread(function()
    while true do
        Wait(0)

        if seqActive and activeSequence then
            -- Timeout check
            if GetGameTimer() > seqTimeout then
                seqActive = false
                activeSequence = nil
                StopRainLoop()
                lib.notify({ title = "Failed", description = "You were too slow!", type = "error" })
            end
        end
    end
end)

--Main Loop

CreateThread(function()
    while true do
        Wait(0)

        -- Only interact if ped exists
        if pedEntity and DoesEntityExist(pedEntity) then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local pedCoords = GetEntityCoords(pedEntity)
            local dist = #(playerCoords - pedCoords)
            -- G Key (47)
            if (dist < 3.0 and IsControlJustPressed(0, 47)) then
                if cooldown then
                    local remaining = math.floor((cooldownEnd - GetGameTimer()) / 1000)
                    if remaining < 0 then remaining = 0 end
                    lib.notify({
                        title = Config.UI.notifications.cooldown.title,
                        description = ("%d seconds left"):format(remaining),
                        type = Config.UI.notifications.cooldown.type
                    })
                    Wait(1000)
                else
                    if not isRainingMoney then
                        StartRainLoop()
                        lib.notify({
                            title = Config.UI.notifications.start.title,
                            description = "Started throwing money", "success",
                            type = Config.UI.notifications.start.type
                        })
                    end
                end
            end

            -- X Key (73)
            if (dist >= 3.0 or IsControlJustPressed(0, 73)) and isRainingMoney then
                StopRainLoop()
                lib.notify({
                    title = Config.UI.notifications.error.title,
                    description = "Stopped throwing money", "success",
                    type = Config.UI.notifications.error.type
                })
                -- start cooldown without freezing this loop
                cooldown = true
                cooldownEnd = GetGameTimer() + 6000
                CreateThread(function()
                    Wait(5000)    -- 3 second cooldown
                    cooldown = false
                end)
            end
            -- WASD AntiAFK
            if seqActive and activeSequence then
                local nextKey = activeSequence[seqIndex]

                -- Key mapping
                local keyMap = {
                    ["W"] = 32,
                    ["A"] = 34,
                    ["S"] = 33,
                    ["D"] = 35
                }

                if IsControlJustPressed(0, keyMap[nextKey]) then
                    seqIndex = seqIndex + 1

                    if seqIndex > #activeSequence then
                        -- Completed!
                        seqActive = false
                        activeSequence = nil
                        lib.notify({
                            title = "Nice!",
                            description = "You kept the flow going!",
                            type = "success"
                        })
                    end
                end
            end
            if seqActive then
                DisableAllControlActions(0)
            end
        end
    end
end)


RegisterNUICallback("finishSequence", function(_, cb)
    seqActive = false
    activeSequence = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "hideChallenge" })

    lib.notify({
        title = "Nice!",
        description = "You kept the flow going!",
        type = "success"
    })

    cb("ok")
end)

RegisterNUICallback("failSequence", function(_, cb)
    seqActive = false
    activeSequence = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "hideChallenge" })

    StopRainLoop()

    lib.notify({
        title = "Failed!",
        description = "You missed the sequence!",
        type = "error"
    })

    cb("ok")
end)
