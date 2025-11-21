local pedNetId = nil
local pedEntity = nil
local isRainingMoney = false
local rainStarting = false

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

function InteractWithPed()
    if not pedEntity or not DoesEntityExist(pedEntity) then
        print("[TestPed] No ped to interact with.")
        return
    end

    -- player animation
    PlayMakeItRainAnim()

    -- ped reaction
    PlayPedAmbientSpeechNative(pedEntity, "GENERIC_HI", "SPEECH_PARAMS_FORCE")

    print("[TestPed] Interaction successful.")
end

function StartRainLoop()
    print("^2[DEBUG] StartRainLoop called!^0")  
    if isRainingMoney or rainStarting then return end
    
    rainStarting = true

        -- delay 1 frame before enabling the loop
    CreateThread(function()
        Wait(0)
        isRainingMoney = true
        rainStarting = false
    end)

    local ped = PlayerPedId()
    local dict = "anim@mp_player_intupperraining_cash"
    local anim = "idle_a"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end

    CreateThread(function()
        Wait(1)
        print("^2[DEBUG] Starting Animation!^0")  
        print(isRainingMoney)
        while isRainingMoney do
            -- Play the animation
            TaskPlayAnim(ped, dict, anim, 4.0, -4.0, -1, 49, 0, false, false, false)

            Wait(4000) -- adjust this for loop speed
        end

        -- Clear anim when loop stops
        ClearPedTasks(ped)
    end)

    -- MONEY LOOP — every 5 seconds remove 1 stack and give clean
    CreateThread(function()
        Wait(10000)
        while isRainingMoney do
            TriggerServerEvent("vu:launderOneBill")
            Wait(10000)
        end
    end)
end

function StopRainLoop()
    if not isRainingMoney then return end
    isRainingMoney = false
end

RegisterNetEvent("vu:rainTick")
AddEventHandler("vu:rainTick", function(item, clean)
    print(("[VU] Laundered one '%s' into $%d clean"):format(item, clean))
    lib.notify({
        title = Config.UI.notifications.success.title,
        description = "1 bill cleaned", "success",
        type = Config.UI.notifications.success.type
    })
end)

CreateThread(function()
    local canInteract = true
    while true do
        Wait(0)


        -- Only interact if ped exists
        if pedEntity and DoesEntityExist(pedEntity) then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local pedCoords = GetEntityCoords(pedEntity)
            local dist = #(playerCoords - pedCoords)
            -- G Key (47)
            if dist < 3.0 and IsControlJustPressed(0, 47) and canInteract then
                print("[VU Debug]: I'm cleaning cash")
                canInteract = false
                if not isRainingMoney and not rainStarting then
                    StartRainLoop()
                    lib.notify({
                        title = Config.UI.notifications.start.title,
                        description = "Started throwing money", "success",
                        type = Config.UI.notifications.start.type
                    })
                SetTimeout(600, function()
                    canInteract = true -- UNLOCK
                end)
                end
            end


            -- X Key (73)
            if (dist >= 3.0 or IsControlJustPressed(0, 73)) and isRainingMoney and canInteract then
                print("[VU Debug]: I'm stopping throwing cash")
                canInteract = false
                StopRainLoop()
                lib.notify({
                    title = Config.UI.notifications.error.title,
                    description = "Stopped throwing money", "success",
                    type = Config.UI.notifications.error.type
                })
                SetTimeout(600, function()
                    canInteract = true -- UNLOCK
                end)
            end
        end
    end
end)
