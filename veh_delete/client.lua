-- Config
local MAX_DELETE_DISTANCE = 12.0      -- max distance to find a vehicle
local ALLOW_DELETE_WHILE_INSIDE = false -- if false, you must be outside the vehicle
local NETWORK_CONTROL_TIMEOUT = 2000  -- ms

-- Enumerator helpers (safe way to iterate vehicles)
local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next
        disposeFunc(iter)
    end)
end

local function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

-- Find the closest vehicle to the player within maxDistance
local function GetClosestVehicleToPlayer(maxDistance)
    local ped = PlayerPedId()
    local px, py, pz = table.unpack(GetEntityCoords(ped, true))
    local closestVeh = nil
    local closestDist = maxDistance + 0.0001

    for vehicle in EnumerateVehicles() do
        if DoesEntityExist(vehicle) then
            local vx, vy, vz = table.unpack(GetEntityCoords(vehicle, true))
            local dist = #(vector3(px, py, pz) - vector3(vx, vy, vz))
            if dist < closestDist then
                closestDist = dist
                closestVeh = vehicle
            end
        end
    end

    return closestVeh, closestDist
end

-- Request network control of an entity and wait until we have it (or timeout)
local function RequestNetworkControl(entity, timeoutMs)
    timeoutMs = timeoutMs or NETWORK_CONTROL_TIMEOUT
    local start = GetGameTimer()
    if not NetworkHasControlOfEntity(entity) then
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and (GetGameTimer() - start) < timeoutMs do
            Wait(10)
        end
    end
    return NetworkHasControlOfEntity(entity)
end

-- Safely delete vehicle (tries to get control, set mission entity, delete)
local function DeleteVehicleSafe(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    -- try request control
    local gotControl = RequestNetworkControl(vehicle, NETWORK_CONTROL_TIMEOUT)
    if not gotControl then
        -- couldn't get control; try to at least mark as mission entity (best-effort)
        -- but deletion probably won't propagate without control
        SetEntityAsMissionEntity(vehicle, true, true)
    else
        SetEntityAsMissionEntity(vehicle, true, true)
    end

    -- attempt deletion
    DeleteVehicle(vehicle)
    Wait(50)

    -- final cleanup
    if DoesEntityExist(vehicle) then
        -- try more aggressive steps
        SetVehicleHasBeenOwnedByPlayer(vehicle, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
        DeleteVehicle(vehicle)
        Wait(50)
    end

    -- ensure removed
    return not DoesEntityExist(vehicle)
end

-- Main function: find and delete closest vehicle
local function DeleteClosestVehicle()
    local ped = PlayerPedId()

    -- If disallowing deleting while inside a vehicle, check
    if not ALLOW_DELETE_WHILE_INSIDE then
        if IsPedInAnyVehicle(ped, false) then
            TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Get out of the vehicle to delete nearby vehicles.' } })
            return
        end
    end

    local vehicle, dist = GetClosestVehicleToPlayer(MAX_DELETE_DISTANCE)
    if not vehicle then
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'No vehicle within ' .. tostring(MAX_DELETE_DISTANCE) .. ' meters.' } })
        return
    end

    -- Avoid deleting player ped (safety)
    if vehicle == ped then
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Closest entity is not a vehicle.' } })
        return
    end

    -- Optionally avoid deleting certain models (e.g., emergency vehicles) - you can customize
    -- local model = GetEntityModel(vehicle)
    -- if model == GetHashKey("police") then ... end

    TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Deleting vehicle (distance: ' .. string.format("%.2f", dist) .. 'm)...' } })

    local success = DeleteVehicleSafe(vehicle)
    if success then
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Vehicle removed.' }, color = {0,255,0} })
    else
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Failed to remove vehicle (no network control).' }, color = {255,0,0} })
    end
end

-- Register command and keymapping
RegisterCommand('delveh', function()
    DeleteClosestVehicle()
end, false)

RegisterKeyMapping('delveh', 'Delete closest vehicle', 'keyboard', 'K') -- default K, change as you like

-- Optional: debug command to print distance of closest vehicle
RegisterCommand('closestveh', function()
    local v, d = GetClosestVehicleToPlayer(MAX_DELETE_DISTANCE * 5)
    if v then
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'Closest vehicle at ' .. string.format("%.2f", d) .. ' meters.' } })
    else
        TriggerEvent('chat:addMessage', { args = { '[VEH-DEL]', 'No vehicle found.' } })
    end
end, false)
