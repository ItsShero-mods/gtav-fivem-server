local function spawnVehicle(modelName)
    if not modelName or modelName == "" then
        print("No vehicle model specified.")
        return
    end

    local model = GetHashKey(modelName)

    -- Check if model is valid
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        print(("Model '%s' is not a valid vehicle."):format(modelName))
        return
    end

    -- Request model
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(50)
        timeout = timeout + 50
        if timeout > 5000 then -- 5 seconds timeout
            print("Failed to load model in time.")
            return
        end
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    -- Offset the spawn a little in front of the player
    local forwardX = math.sin(math.rad(heading)) * 5.0
    local forwardY = math.cos(math.rad(heading)) * 5.0
    local spawnX = coords.x + forwardX
    local spawnY = coords.y + forwardY
    local spawnZ = coords.z

    -- Create the vehicle
    local vehicle = CreateVehicle(model, spawnX, spawnY, spawnZ, heading, true, false)

    if not DoesEntityExist(vehicle) then
        print("Vehicle creation failed.")
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- Set some basic properties
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetPedIntoVehicle(playerPed, vehicle, -1)

    -- Optional: clean car and turn engine on
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, true, true, false)

    -- Release model
    SetModelAsNoLongerNeeded(model)

    print(("Spawned vehicle: %s"):format(modelName))
end

-- Chat command: /car adder
RegisterCommand('car', function(source, args)
    local modelName = args[1] or "adder" -- default to adder if no arg
    spawnVehicle(modelName)
end, false)

-- Optional keybind (example: F6) – you can customize this
-- This will always spawn an 'adder' when F6 is pressed
RegisterKeyMapping('car', 'Spawn a vehicle (adder by default)', 'keyboard', 'F6')


RegisterCommand("listvehicles", function()
    local vehicles = GetAllVehicleModels()


    exports.chat:addMessage({
        color = { 255, 255, 255 }, -- White
        args = { "Vehicles", json.encode(vehicles, { indent = true }) }
    })
end)
