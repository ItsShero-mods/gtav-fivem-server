-- Models to auto-clean if they fall
local DANGER_MODELS = {
    `prop_streetlight_01`,
    `prop_streetlight_01b`,
    `prop_streetlight_02`,
    `prop_traffic_01a`,
    `prop_traffic_01b`,
    `prop_traffic_01d`,
    `prop_traffic_03b`,
    `prop_traffic_lightset_01`,
    -655644382,
    729253480,
    862871082,
    -97646180,
    -1063472968,
    431612653
}

local CLEAN_RADIUS       = 80.0
local CHECK_INTERVAL_MS  = 100
local UPRIGHT_THRESHOLD  = 15.0   -- how strict "upright" is

-- rotation based upright check, same idea as checkupright
local function isEntityUprightByRotation(entity, threshold)
    local rot   = GetEntityRotation(entity, 2)   -- degrees
    local pitch = math.abs(rot.x)
    local roll  = math.abs(rot.y)
    return (pitch < threshold and roll < threshold), pitch, roll, rot
end

-- small helper to see if a hash is in DANGER_MODELS
local function isDangerModel(model)
    for _, h in ipairs(DANGER_MODELS) do
        if model == h then
            return true
        end
    end
    return false
end

-- core pass: scan all objects, nuke fallen danger models
local function RunLamppurgePass(tag)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local pCoords = GetEntityCoords(ped)

    local handle, entity = FindFirstObject()
    if handle == -1 then return end

    local success = true
    repeat
        if DoesEntityExist(entity) then
            local model = GetEntityModel(entity)

            if isDangerModel(model) then
                local eCoords = GetEntityCoords(entity)
                local dist    = #(eCoords - pCoords)

                if dist <= CLEAN_RADIUS then
                    local upright, pitch, roll = isEntityUprightByRotation(entity, UPRIGHT_THRESHOLD)
                    local inAir = IsEntityInAir(entity)

                    if (not upright) or inAir then
                        print(("[Lamppurge%s] Deleting fallen model %s at dist %.1f (pitch %.1f roll %.1f inAir %s)")
                            :format(tag or "", tostring(model), dist, pitch, roll, tostring(inAir)))

                        SetEntityAsMissionEntity(entity, true, true)
                        DeleteObject(entity)

                        -- optional, helps stop instant respawns of map props
                        CreateModelHide(eCoords.x, eCoords.y, eCoords.z, 6.0, model, true)
                    end
                end
            end
        end

        success, entity = FindNextObject(handle)
        Wait(0)  -- do not hang a frame
    until not success

    EndFindObject(handle)
end

-- Auto during active race
CreateThread(function()
    while true do
        if CurrentRaceData
        and CurrentRaceData.RaceName ~= nil
        and CurrentRaceData.Started
        then
            RunLamppurgePass("")
        end

        Wait(CHECK_INTERVAL_MS)
    end
end)

-- Manual one shot cleanup
RegisterCommand("lamppurge", function()
    print("^3[Lamppurge] Manual lamppost cleanup pass...^0")
    RunLamppurgePass(" CMD")
    print("^2[Lamppurge] Manual cleanup pass complete.^0")
end, false)

-- Deletes ALL objects with the given model hash within radius, no upright check
RegisterCommand("lamppurgehash", function(_, args)
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    local targetHash = args[1] and tonumber(args[1])
    if not targetHash then
        print("^1Usage: /lamppurgehash <modelHash>^0")
        return
    end

    local radius = 80.0
    local handle, entity = FindFirstObject()
    if handle == -1 then
        print("^1[lamppurgehash] FindFirstObject failed.^0")
        return
    end

    print(("[lamppurgehash] Scanning for hash %s within %.0fm..."):format(targetHash, radius))

    local success = true
    local count = 0
    repeat
        if DoesEntityExist(entity) and GetEntityModel(entity) == targetHash then
            local eCoords = GetEntityCoords(entity)
            local dist = #(eCoords - pCoords)
            if dist <= radius then
                SetEntityAsMissionEntity(entity, true, true)
                DeleteObject(entity)
                CreateModelHide(eCoords, 6.0, targetHash, true)
                count = count + 1
            end
        end

        success, entity = FindNextObject(handle)
        Wait(0)
    until not success

    EndFindObject(handle)

    print(("[lamppurgehash] Deleted %d objects with hash %s.^0"):format(count, targetHash))
end, false)


RegisterCommand("checkclosestupright", function()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    -- Find *any* closest object of ANY model.
    -- We do this by scanning all objects and keeping the closest one.
    local handle, entity = FindFirstObject()
    if handle == -1 then
        print("^1[checkclosestupright] FindFirstObject failed.^0")
        return
    end

    local closest = nil
    local closestDist = math.huge
    local success = true

    repeat
        if DoesEntityExist(entity) then
            local eCoords = GetEntityCoords(entity)
            local dist = #(eCoords - pCoords)

            if dist < closestDist then
                closest = entity
                closestDist = dist
            end
        end

        success, entity = FindNextObject(handle)
        Wait(0)
    until not success

    EndFindObject(handle)

    if not closest then
        print("^1[checkclosestupright] No props found nearby.^0")
        return
    end

    local model = GetEntityModel(closest)
    local upright, pitch, roll, rot = isEntityUprightByRotation(closest, UPRIGHT_THRESHOLD)
    local inAir = IsEntityInAir(closest)

    print("^3--- Closest Prop Upright Check ---^0")
    print(("Model Hash: %s"):format(model))
    print(("Distance: %.2f"):format(closestDist))
    print(("Rotation (pitch/roll/yaw): %.2f / %.2f / %.2f"):format(rot.x, rot.y, rot.z))
    print(("Pitch: %.2f   Roll: %.2f"):format(pitch, roll))
    print(("Upright (<%d°): %s"):format(UPRIGHT_THRESHOLD, upright and "^2true^0" or "^1false^0"))
    print(("In Air: %s"):format(inAir and "^1true^0" or "^2false^0"))
end, false)