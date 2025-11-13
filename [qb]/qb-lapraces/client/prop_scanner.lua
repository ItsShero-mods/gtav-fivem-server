local SCAN_RADIUS = 30.0
local LABEL_DURATION = 5000 -- ms labels stay on screen

-- store labels to be drawn
local activeScanLabels = {}

-- Draw floating 3D text
local function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(0)
    SetTextScale(0.33, 0.33)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Get model name from hash, best-effort
local function GetModelName(hash)
    local name = GetEntityArchetypeName(hash)
    if name and name ~= "" then
        return name
    end
    return "unknown_model_" .. tostring(hash)
end

-- Command for one-time scan (populates labels)
RegisterCommand("scanprops", function()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    print("[SCAN] Scanning props around you...")

    local handle, obj = FindFirstObject()
    local success

    local count = 0
    local now = GetGameTimer()
    activeScanLabels = {} -- reset previous labels

    repeat
        if DoesEntityExist(obj) then
            local objCoords = GetEntityCoords(obj)
            local dist = #(pCoords - objCoords)

            if dist <= SCAN_RADIUS then
                local hash  = GetEntityModel(obj)
                local name  = GetModelName(hash)
                count += 1

                -- Print in F8 console
                print(("[SCAN] %s | Hash: %s | Dist: %.1fm")
                    :format(name, hash, dist))

                -- Store label to be drawn for a few seconds
                table.insert(activeScanLabels, {
                    x = objCoords.x,
                    y = objCoords.y,
                    z = objCoords.z + 1.0,
                    text = ("%s\n%s"):format(name, hash),
                    expires = now + LABEL_DURATION
                })
            end
        end

        success, obj = FindNextObject(handle)
    until not success

    EndFindObject(handle)

    print(("[SCAN] Complete. Found %d objects within %.0fm.")
        :format(count, SCAN_RADIUS))
end, false)

-- Render loop for labels
CreateThread(function()
    while true do
        local now = GetGameTimer()

        if #activeScanLabels > 0 then
            for i = #activeScanLabels, 1, -1 do
                local label = activeScanLabels[i]
                if now > label.expires then
                    table.remove(activeScanLabels, i)
                else
                    DrawText3D(label.x, label.y, label.z, label.text)
                end
            end
        end

        Wait(0) -- every frame
    end
end)
