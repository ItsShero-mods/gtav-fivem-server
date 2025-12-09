local pedNetId = nil
local QBCore = exports['qb-core']:GetCoreObject()
local LAUNDER_RATE = 0.65          -- 85% returned as clean
local DIRTY_ITEM = "stack_of_money"
local STACK_VALUE = 1000           -- how much one stack is "worth"
                                   -- adjust if needed

RegisterNetEvent("testped:spawnForEveryone")
AddEventHandler("testped:spawnForEveryone", function(coords, heading)
    if pedNetId ~= nil then
      TriggerClientEvent("testped:deletePed", -1, pedNetId)
      pedNetId = nil
    end
    TriggerClientEvent("testped:createPed", -1, coords, heading)
end)

RegisterNetEvent("testped:deleteForEveryone")
AddEventHandler("testped:deleteForEveryone", function()
    TriggerClientEvent("testped:deletePed", -1, pedNetId)
    pedNetId = nil
end)

-- store the netid sent from the client
RegisterNetEvent("testped:storeNetId")
AddEventHandler("testped:storeNetId", function(netId)
    pedNetId = netId
end)

RegisterNetEvent("vu:launderOneBill", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Does the player have at least 1 stack item?
    local item = Player.Functions.GetItemByName(DIRTY_ITEM)
    if not item or item.amount < 1 then
        -- out of dirty cash → stop loop client-side
        TriggerClientEvent("vu:stopRainLoop", src, "You're out of dirty cash.")
        return
    end

    -- Remove 1 stack_of_money
    Player.Functions.RemoveItem(DIRTY_ITEM, 1)

    -- Calculate clean payout
    local cleanAmount = math.floor(STACK_VALUE * LAUNDER_RATE)

    -- Give clean cash
    Player.Functions.AddMoney("cash", cleanAmount, "vu-launder")

    -- Optional: feedback per tick
    TriggerClientEvent("vu:rainTick", src, DIRTY_ITEM, cleanAmount)
end)
