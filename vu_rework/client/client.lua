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
end

function StopRainLoop()
    isRainingMoney = false
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
        end
    end
end)

