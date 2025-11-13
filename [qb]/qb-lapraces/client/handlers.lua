-- Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for k, v in pairs(CreatorData.Checkpoints) do
            if v.editorCheckpointHandle then
                DeleteCheckpoint(v.editorCheckpointHandle)
                v.checkpointHandle = nil
            end
        end

        for k, v in pairs(CurrentRaceData.Checkpoints) do
            if CurrentRaceData.Checkpoints[k] ~= nil then
                if v.checkpointHandle then
                    DeleteCheckpoint(v.checkpointHandle)
                    v.checkpointHandle = nil
                end
            end
        end
    end
end)