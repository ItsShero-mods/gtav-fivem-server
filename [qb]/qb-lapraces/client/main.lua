QBCore = exports['qb-core']:GetCoreObject()
Countdown = 1
ToFarCountdown = 10
FinishedUITimeout = false
BLIP_WINDOW = 3  -- how many upcoming checkpoints to show

RaceData = {
    InCreator = false,
    InRace = false,
    ClosestCheckpoint = 0,
}

CreatorData = {
    RaceName = nil,
    Checkpoints = {},
    TireDistance = 3.0,
    ConfirmDelete = false,
}

CurrentRaceData = {
    RaceId = nil,
    RaceName = nil,
    Checkpoints = {},
    Started = false,
    CurrentCheckpoint = nil,
    TotalLaps = 0,
    Lap = 0,
    checkpointHandle = nil,
}

CheckpointConfig = {
    type = 45,  -- 0 or 4 or 45 etc. 45 is a nice ring style
    defaultRadiusMultiplier = 1.1,  -- applied to your gate width for visual radius
    color = { r = 255, g = 255, b = 0, a = 200 }, -- default yellow
    height = { near = 3.0, far = 3.0 },           -- cylinder height
}



-- Functions

function GetGroundZ(x, y, z)
    local _, groundZ = GetGroundZFor_3dCoord(x, y, z + 15.0, 0)
    return groundZ
end

function CreateRaceBlipForIndex(i)
    local cp = CurrentRaceData.Checkpoints[i]
    if not cp or not cp.coords then return end

    -- if it already exists, do nothing
    if cp.blip then return cp.blip end

    local blip = AddBlipForCoord(cp.coords.x, cp.coords.y, cp.coords.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.6)                 -- default, we will override for "next" one
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, 26)
    ShowNumberOnBlip(blip, i)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Checkpoint: "..i)
    EndTextCommandSetBlipName(blip)

    cp.blip = blip
    return blip
end

function RemoveRaceBlipForIndex(i)
    local cp = CurrentRaceData.Checkpoints[i]
    if cp and cp.blip then
        RemoveBlip(cp.blip)
        cp.blip = nil
    end
end

function SetRaceBlipScaleForIndex(i, scale)
    local cp = CurrentRaceData.Checkpoints[i]
    if cp and cp.blip then
        SetBlipScale(cp.blip, scale)
    end
end

function GetWrappedIndex(base, offset)
    -- this sets checkpoints to 1-X, where X is the total per lap. Only called if race is lapped.
    local total = #CurrentRaceData.Checkpoints
    if total == 0 then return nil end

    local idx = base + offset
    -- wrap positive
    while idx > total do
        idx = idx - total
    end
    -- wrap negative if ever needed
    while idx < 1 do
        idx = idx + total
    end

    return idx
end

function UpdateBlipWindow()
    if not CurrentRaceData.Checkpoints or #CurrentRaceData.Checkpoints == 0 then return end
    if not CurrentRaceData.CurrentCheckpoint then return end

    local total = #CurrentRaceData.Checkpoints
    local current = CurrentRaceData.CurrentCheckpoint

    -- needed[i] = offsetAhead (1, 2, 3) if that index should have a blip
    local needed = {}

    for offset = 1, BLIP_WINDOW do
        local idx

        if CurrentRaceData.TotalLaps == 0 or CurrentRaceData.TotalLaps == 1 then
            -- point to point, no wrap at the end
            idx = current + offset
            if idx <= total then
                needed[idx] = offset
            end
        else
            -- lapped race, wrap around
            idx = GetWrappedIndex(current, offset)
            needed[idx] = offset
        end
    end

    -- turn on the ones we need, turn off the others
    for i = 1, total do
        local offsetAhead = needed[i]
        if offsetAhead then
            CreateRaceBlipForIndex(i)
            -- make the immediate next checkpoint's blip bigger
            local scale = (offsetAhead == 1) and 1.0 or 0.6
            SetRaceBlipScaleForIndex(i, scale)
        else
            RemoveRaceBlipForIndex(i)
        end
    end

    -- point GPS route to the next checkpoint
    -- local nextIndex = GetWrappedIndex(current, 1)
    -- if nextIndex and CurrentRaceData.Checkpoints[nextIndex] then
    --     local nextCp = CurrentRaceData.Checkpoints[nextIndex]
    --     SetNewWaypoint(nextCp.coords.x, nextCp.coords.y)
    -- end
end



function DrawText3Ds(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText("STRING")
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x,y,z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function GetClosestCheckpoint()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    for id, _ in pairs(CreatorData.Checkpoints) do
        if current ~= nil then
            if #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z)) < dist then
                current = id
                dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            end
        else
            dist = #(pos - vector3(CreatorData.Checkpoints[id].coords.x, CreatorData.Checkpoints[id].coords.y, CreatorData.Checkpoints[id].coords.z))
            current = id
        end
    end
    RaceData.ClosestCheckpoint = current
end

function CreatorUI()
    CreateThread(function()
        while true do
            if RaceData.InCreator then
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = true,
                })
            else
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = false,
                })
                break
            end
            Wait(200)
        end
    end)
end

local _DeleteCheckpoint = DeleteCheckpoint  -- save the native

function DeleteCheckpoint()
    print("In Delete Checkpoint Function")
    if CurrentRaceData.checkpointHandle then
        _DeleteCheckpoint(CurrentRaceData.checkpointHandle) -- call the native
        CurrentRaceData.checkpointHandle = nil
        print("[RACE DEBUG] Deleted active checkpoint marker")
    else
        print("[RACE DEBUG] No active checkpoint marker")
    end
end

function SaveRace()
    local RaceDistance = 0

    for k, v in pairs(CreatorData.Checkpoints) do
        if k + 1 <= #CreatorData.Checkpoints then
            local checkpointdistance = #(vector3(v.coords.x, v.coords.y, v.coords.z) - vector3(CreatorData.Checkpoints[k + 1].coords.x, CreatorData.Checkpoints[k + 1].coords.y, CreatorData.Checkpoints[k + 1].coords.z))
            RaceDistance = RaceDistance + checkpointdistance
        end
    end

    CreatorData.RaceDistance = RaceDistance

    TriggerServerEvent('qb-lapraces:server:SaveRace', CreatorData)

    QBCore.Functions.Notify('Race: '..CreatorData.RaceName..' is saved!', 'success')

    for id,_ in pairs(CreatorData.Checkpoints) do
        if CreatorData.Checkpoints[id].blip ~= nil then
            RemoveBlip(CreatorData.Checkpoints[id].blip)
            _DeleteCheckpoint(CreatorData.Checkpoints[id].editorCheckpointHandle)
            CreatorData.Checkpoints[id].blip = nil
            CreatorData.Checkpoints[id].editorCheckpointHandle = nil
        end
        if CreatorData.Checkpoints[id] ~= nil then
            if CreatorData.Checkpoints[id].pileleft ~= nil then
                local coords = CreatorData.Checkpoints[id].offset.left
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[id].pileleft = nil
            end
            if CreatorData.Checkpoints[id].pileright ~= nil then
                local coords = CreatorData.Checkpoints[id].offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, 0, 0, 0)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                CreatorData.Checkpoints[id].pileright = nil
            end
        end
    end

    RaceData.InCreator = false
    CreatorData.RaceName = nil
    CreatorData.Checkpoints = {}
end

function AddCheckpoint()
    local PlayerPed = PlayerPedId()
    local PlayerPos = GetEntityCoords(PlayerPed)
    local PlayerVeh = GetVehiclePedIsIn(PlayerPed)
    local Offset = {
        left = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, -CreatorData.TireDistance, 0.0, 0.0)).z,
        },
        right = {
            x = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).x,
            y = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).y,
            z = (GetOffsetFromEntityInWorldCoords(PlayerVeh, CreatorData.TireDistance, 0.0, 0.0)).z,
        }
    }

    CreatorData.Checkpoints[#CreatorData.Checkpoints+1] = {
        coords = {
            x = PlayerPos.x,
            y = PlayerPos.y,
            z = PlayerPos.z,
        },
        offset = Offset
    }

    local v = CreatorData.Checkpoints[#CreatorData.Checkpoints]
    if not v or not v.coords or not v.offset then return end

    local center = v.coords

    -- use your existing left/right offset to size the ring
    local gateWidth = #(vector3(v.offset.left.x, v.offset.left.y, v.offset.left.z)
                    - vector3(v.offset.right.x, v.offset.right.y, v.offset.right.z))

    local baseRadius = gateWidth
    local radius = v.cpRadius or (baseRadius * CheckpointConfig.defaultRadiusMultiplier)
    local col = v.cpColor or CheckpointConfig.color

    v.hitRadius = radius

    local groundZ = GetGroundZ(center.x, center.y, center.z)

    local cp = CreateCheckpoint(
        CheckpointConfig.type,
        center.x, center.y, groundZ,
        center.x, center.y, groundZ,  -- direction not important for a simple ring
        radius,
        col.r, col.g, col.b, col.a,
        #CreatorData.Checkpoints
    )

    CreatorData.Checkpoints[#CreatorData.Checkpoints].editorCheckpointHandle = cp

    if CheckpointConfig.height then
        SetCheckpointCylinderHeight(
            cp,
            CheckpointConfig.height.near,
            CheckpointConfig.height.far,
            radius
        )
    end

    for id, CheckpointData in pairs(CreatorData.Checkpoints) do
        if CheckpointData.blip ~= nil then
            RemoveBlip(CheckpointData.blip)
        end

        CheckpointData.blip = AddBlipForCoord(CheckpointData.coords.x, CheckpointData.coords.y, CheckpointData.coords.z)

        SetBlipSprite(CheckpointData.blip, 1)
        SetBlipDisplay(CheckpointData.blip, 4)
        SetBlipScale(CheckpointData.blip, 0.8)
        SetBlipAsShortRange(CheckpointData.blip, true)
        SetBlipColour(CheckpointData.blip, 26)
        ShowNumberOnBlip(CheckpointData.blip, id)
        SetBlipShowCone(CheckpointData.blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..id)
        EndTextCommandSetBlipName(CheckpointData.blip)
    end

end

function RemoveCheckpoint()
    if CreatorData.Checkpoints[#CreatorData.Checkpoints].blip ~= nil then
        RemoveBlip(CreatorData.Checkpoints[#CreatorData.Checkpoints].blip)
    end
    if CreatorData.Checkpoints[#CreatorData.Checkpoints].editorCheckpointHandle ~= nil then
        print("Attempting to delete 3d checkpoint")
        _DeleteCheckpoint(CreatorData.Checkpoints[#CreatorData.Checkpoints].editorCheckpointHandle)
    else
        print("editorCheckpointHandle is nil/doesn't exist")
    end
    CreatorData.Checkpoints[#CreatorData.Checkpoints] = nil
end

function CreatorLoop()
    CreateThread(function()
        while RaceData.InCreator do
            local PlayerPed = PlayerPedId()
            local PlayerVeh = GetVehiclePedIsIn(PlayerPed)

            if PlayerVeh ~= 0 then
                if IsControlJustPressed(0, 161) or IsDisabledControlJustPressed(0, 161) then
                    AddCheckpoint()
                end

                if IsControlJustPressed(0, 162) or IsDisabledControlJustPressed(0, 162) then
                    if CreatorData.Checkpoints ~= nil and next(CreatorData.Checkpoints) ~= nil then
                        RemoveCheckpoint()
                    else
                        QBCore.Functions.Notify('You have not placed any checkpoints yet..', 'error')
                    end
                end

                if IsControlJustPressed(0, 311) or IsDisabledControlJustPressed(0, 311) then
                    if CreatorData.Checkpoints ~= nil and #CreatorData.Checkpoints >= 2 then
                        SaveRace()
                    else
                        QBCore.Functions.Notify('You must have at least 10 checkpoints', 'error')
                    end
                end

                if IsControlJustPressed(0, 40) or IsDisabledControlJustPressed(0, 40) then
                    if CreatorData.TireDistance + 1.0 ~= 16.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance + 1.0
                    else
                        QBCore.Functions.Notify('You can not go higher than 15')
                    end
                end

                if IsControlJustPressed(0, 39) or IsDisabledControlJustPressed(0, 39) then
                    if CreatorData.TireDistance - 1.0 ~= 1.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance - 1.0
                    else
                        QBCore.Functions.Notify('You cannot go lower than 2')
                    end
                end
            else
                local coords = GetEntityCoords(PlayerPedId())
                DrawText3Ds(coords.x, coords.y, coords.z, 'You must be in a vehicle')
            end

            if IsControlJustPressed(0, 163) or IsDisabledControlJustPressed(0, 163) then
                if not CreatorData.ConfirmDelete then
                    CreatorData.ConfirmDelete = true
                    QBCore.Functions.Notify('Press [9] again to confirm', 'error', 5000)
                else
                    for _, CheckpointData in pairs(CreatorData.Checkpoints) do
                        if CheckpointData.blip ~= nil then
                            RemoveBlip(CheckpointData.blip)
                        end
                    end

                    for id,_ in pairs(CreatorData.Checkpoints) do
                        if CreatorData.Checkpoints[id].pileleft ~= nil then
                            local coords = CreatorData.Checkpoints[id].offset.left
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, 0, 0, 0)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            CreatorData.Checkpoints[id].pileleft = nil
                        end

                        if CreatorData.Checkpoints[id].pileright ~= nil then
                            local coords = CreatorData.Checkpoints[id].offset.right
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, 0, 0, 0)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            CreatorData.Checkpoints[id].pileright = nil
                        end
                    end

                    for id, cp in pairs(CreatorData.Checkpoints) do
                        if cp.editorCheckpointHandle then
                            DeleteCheckpoint(cp.editorCheckpointHandle)
                            cp.editorCheckpointHandle = nil
                        end
                    end

                    RaceData.InCreator = false
                    CreatorData.RaceName = nil
                    CreatorData.Checkpoints = {}
                    QBCore.Functions.Notify('Race-editor canceled!', 'error')
                    CreatorData.ConfirmDelete = false
                end
            end
            Wait(3)
        end
    end)
end

function RaceUI()
    CreateThread(function()
        while true do
            if CurrentRaceData.Checkpoints ~= nil and next(CurrentRaceData.Checkpoints) ~= nil then
                if CurrentRaceData.Started then
                    CurrentRaceData.RaceTime = CurrentRaceData.RaceTime + 1
                    CurrentRaceData.TotalTime = CurrentRaceData.TotalTime + 1
                end
                SendNUIMessage({
                    action = "Update",
                    type = "race",
                    data = {
                        CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint,
                        TotalCheckpoints = #CurrentRaceData.Checkpoints,
                        TotalLaps = CurrentRaceData.TotalLaps,
                        CurrentLap = CurrentRaceData.Lap,
                        RaceStarted = CurrentRaceData.Started,
                        RaceName = CurrentRaceData.RaceName,
                        Time = CurrentRaceData.RaceTime,
                        TotalTime = CurrentRaceData.TotalTime,
                        BestLap = CurrentRaceData.BestLap,
                    },
                    racedata = RaceData,
                    active = true,
                })
            else
                if not FinishedUITimeout then
                    FinishedUITimeout = true
                    SetTimeout(10000, function()
                        FinishedUITimeout = false
                        SendNUIMessage({
                            action = "Update",
                            type = "race",
                            data = {},
                            racedata = RaceData,
                            active = false,
                        })
                    end)
                end
                break
            end
            Wait(12)
        end
    end)
end

function SetupRace(sRaceData, Laps)
    RaceData.RaceId = sRaceData.RaceId
    CurrentRaceData = {
        RaceId = sRaceData.RaceId,
        Creator = sRaceData.Creator,
        RaceName = sRaceData.RaceName,
        Checkpoints = sRaceData.Checkpoints,
        Started = false,
        CurrentCheckpoint = 1,
        TotalLaps = Laps,
        Lap = 1,
        RaceTime = 0,
        TotalTime = 0,
        BestLap = 0,
        Racers = {}
    }

    for k, v in pairs(CurrentRaceData.Checkpoints) do
        -- Center of the checkpoint (you are already using this for distance and blips)
        local center = v.coords
        CurrentRaceData.Checkpoints[k].blip = AddBlipForCoord(center.x, center.y, center.z)
        SetBlipSprite(CurrentRaceData.Checkpoints[k].blip, 1)
        SetBlipDisplay(CurrentRaceData.Checkpoints[k].blip, 4)
        SetBlipScale(CurrentRaceData.Checkpoints[k].blip, 0.6)
        SetBlipAsShortRange(CurrentRaceData.Checkpoints[k].blip, true)
        SetBlipColour(CurrentRaceData.Checkpoints[k].blip, 26)
        ShowNumberOnBlip(CurrentRaceData.Checkpoints[k].blip, k)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..k)
        EndTextCommandSetBlipName(CurrentRaceData.Checkpoints[k].blip)
    end

    RaceUI()
end

function showNonLoopParticle(dict, particleName, coords, scale)
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(0)
    end
    UseParticleFxAssetNextCall(dict)
    local particleHandle = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, scale, false, false, false)
    SetParticleFxLoopedColour(particleHandle, 0, 255, 0 ,0)
    return particleHandle
end

function DoPilePfx()
    if CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint] ~= nil then
        local Timeout = 500
        local Size = 2.0
        local left = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.left, Size)
        local right = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.right, Size)

        SetTimeout(Timeout, function()
            StopParticleFxLooped(left, false)
            StopParticleFxLooped(right, false)
        end)
    end
end

function GetMaxDistance(cpData)
    if cpData.hitRadius then
        -- small buffer so you don’t have to be pixel-perfect
        return cpData.hitRadius * 0.75
    end

    -- fallback if hitRadius not set yet (shouldn't really happen once race is started)
    local Distance = #(vector3(cpData.offset.left.x, cpData.offset.left.y, cpData.offset.left.z)
                    - vector3(cpData.offset.right.x, cpData.offset.right.y, cpData.offset.right.z))

    return Distance  -- or Distance * 0.75, etc. if you want it tighter
end

function SecondsToClock(seconds)
    seconds = tonumber(seconds)
    local retval
    if seconds <= 0 then
        retval = "00:00:00";
    else
        local hours = string.format("%02.f", math.floor(seconds/3600));
        local mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
        local secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
        retval = hours..":"..mins..":"..secs
    end
    return retval
end

function FinishRace()
    TriggerServerEvent('qb-lapraces:server:FinishPlayer', CurrentRaceData, CurrentRaceData.TotalTime, CurrentRaceData.TotalLaps, CurrentRaceData.BestLap)
    if CurrentRaceData.BestLap ~= 0 then
        QBCore.Functions.Notify('Race finished in '..SecondsToClock(CurrentRaceData.TotalTime)..', with the best lap: '..SecondsToClock(CurrentRaceData.BestLap))
    else
        QBCore.Functions.Notify('Race finished in '..SecondsToClock(CurrentRaceData.TotalTime))
    end
    for k, _ in pairs(CurrentRaceData.Checkpoints) do
        for k, _ in pairs(CurrentRaceData.Checkpoints) do
            if CurrentRaceData.checkpointHandle then
                DeleteCheckpoint(CurrentRaceData.checkpointHandle)
                CurrentRaceData.checkpointHandle = nil
            end

            if CurrentRaceData.checkpointHandle then
                DeleteCheckpoint(CurrentRaceData.checkpointHandle)
                CurrentRaceData.checkpointHandle = nil
            end
        end
    end
    UpdateBlipWindow()
    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.RaceId = nil
    RaceData.InRace = false
end

function Info()
    local PlayerPed = PlayerPedId()
    local plyVeh = GetVehiclePedIsIn(PlayerPed, false)
    local IsDriver = GetPedInVehicleSeat(plyVeh, -1) == PlayerPed
    local returnValue = plyVeh ~= 0 and plyVeh ~= nil and IsDriver
    return returnValue, plyVeh
end

function IsInRace()
    local retval = false
    if RaceData.InRace then
        retval = true
    end
    return retval
end

function IsInEditor()
    local retval = false
    if RaceData.InCreator then
        retval = true
    end
    return retval
end

function RefreshCheckpointMarker()
    -- remove previous marker if it exists
    if CurrentRaceData.checkpointHandle then
        DeleteCheckpoint(CurrentRaceData.checkpointHandle)
        CurrentRaceData.checkpointHandle = nil
    end

    -- safety checks
    if not CurrentRaceData.Checkpoints or #CurrentRaceData.Checkpoints == 0 then return end
    if not CurrentRaceData.Started then return end

    -- "next" checkpoint is same logic you use in the main race loop
    local nextIndex
    if CurrentRaceData.CurrentCheckpoint + 1 > #CurrentRaceData.Checkpoints then
        nextIndex = 1
    else
        nextIndex = CurrentRaceData.CurrentCheckpoint + 1
    end

    local v = CurrentRaceData.Checkpoints[nextIndex]
    if not v or not v.coords or not v.offset then return end

    local center = v.coords

    -- use your existing left/right offset to size the ring
    local gateWidth = #(vector3(v.offset.left.x, v.offset.left.y, v.offset.left.z)
                    - vector3(v.offset.right.x, v.offset.right.y, v.offset.right.z))

    local baseRadius = gateWidth
    local radius = v.cpRadius or (baseRadius * CheckpointConfig.defaultRadiusMultiplier)
    local col = v.cpColor or CheckpointConfig.color

    v.hitRadius = radius

    local groundZ = GetGroundZ(center.x, center.y, center.z)

    local cp = CreateCheckpoint(
        CheckpointConfig.type,
        center.x, center.y, groundZ,
        center.x, center.y, groundZ,  -- direction not important for a simple ring
        radius,
        col.r, col.g, col.b, col.a,
        nextIndex
    )

    if CheckpointConfig.height then
        SetCheckpointCylinderHeight(
            cp,
            CheckpointConfig.height.near,
            CheckpointConfig.height.far,
            radius
        )
    end

    CurrentRaceData.checkpointHandle = cp
    CurrentRaceData.activeCheckpointIndex = nextIndex
end


exports('IsInEditor', IsInEditor)
exports('IsInRace', IsInRace)