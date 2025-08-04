--[[
    ============================================================
    -- ## STANDALONE POTION TESTER ##
    ============================================================
    --
    -- PURPOSE:
    -- This script is designed to test the core logic of finding
    -- and using the single best version of a specific potion type.
    --
    -- HOW TO USE:
    -- 1. Change the POTION_TO_TEST value below to the potion
    --    you want to test (e.g., "Lucky", "Speed", "Coins").
    -- 2. Run the script.
    -- 3. Check the developer console for output. It will tell you
    --    what it found and what it's trying to use.
    --
]]

-- ================== CONFIGURATION ==================
local Config = {
    -- Change this value to test different potions.
    -- The script will find the BEST version of this potion you own.
    -- (e.g., if you have Lucky I, II, and IV, it will find Lucky IV).
    POTION_TO_TEST = "Lucky",

    -- The number of potions to use. Set to 1 for simple testing.
    AMOUNT_TO_USE = 1
}
-- ===================================================


-- ## Setup: Services & Modules ##
print("--- POTION TESTER: Initializing... ---")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
print("Services and Modules loaded.")

-- ## Core Potion Finding Logic ##
task.spawn(function()
    local potionNameToFind = Config.POTION_TO_TEST
    print("Searching for the best '" .. potionNameToFind .. "' potion in your inventory...")

    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then
        warn("Could not access player potion data.")
        return
    end

    local bestPotionFound = nil

    -- Loop through every single potion stack in the player's inventory.
    for _, potionInstance in pairs(playerData.Potions) do
        -- Check if the potion's name matches the type we're looking for (e.g., "Lucky" is in "Lucky V")
        if string.match(potionInstance.Name, potionNameToFind) then
            print("  - Found a candidate: '" .. potionInstance.Name .. "' (Level " .. tostring(potionInstance.Level) .. "), Amount: " .. tostring(potionInstance.Amount))
            
            -- If we haven't found any potion yet, or if this one is a higher level, it's the new best.
            if not bestPotionFound or potionInstance.Level > bestPotionFound.Level then
                print("    ^ This is the new best version found so far.")
                bestPotionFound = potionInstance
            end
        end
    end

    -- ## Final Action ##
    if bestPotionFound then
        print("--- TEST RESULT: The best potion found was '" .. bestPotionFound.Name .. "' (Level " .. bestPotionFound.Level .. ") with " .. bestPotionFound.Amount .. " available. ---")
        
        if bestPotionFound.Amount >= Config.AMOUNT_TO_USE then
            print("Attempting to use " .. Config.AMOUNT_TO_USE .. "x of this potion...")
            
            -- The remote event requires the arguments to be sent separately, not in a table.
            -- Format: "UsePotion", PotionName (string), PotionLevel (number), AmountToUse (number)
            local name = bestPotionFound.Name
            local level = bestPotionFound.Level
            local amount = Config.AMOUNT_TO_USE

            local success, err = pcall(function()
                RemoteEvent:FireServer("UsePotion", name, level, amount)
            end)

            if success then
                print("SUCCESS: RemoteEvent:FireServer('UsePotion', '" .. name .. "', " .. level .. ", " .. amount .. ") was called successfully.")
            else
                print("ERROR: The remote event call failed. Error: " .. tostring(err))
            end
        else
            print("Could not use potion: Not enough available (Need " .. Config.AMOUNT_TO_USE .. ", Have " .. bestPotionFound.Amount .. ").")
        end
    else
        print("--- TEST RESULT: No potions of type '" .. potionNameToFind .. "' were found in your inventory. ---")
    end

    print("--- POTION TESTER: Script finished. ---")
end)
