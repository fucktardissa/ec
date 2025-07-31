-- Standalone Auto-Delete Script (Final Version)

---------------------------------------------------------------------
-- ## CONFIGURATION ##
-- Set the rarities you want to delete to 'true'.
---------------------------------------------------------------------
local raritiesToDelete = {
    ["Common"] = true,
    ["Unique"] = true,
    ["Rare"] = false,
    ["Epic"] = false,
    ["Legendary"] = false,
    ["Secret"] = false
}
---------------------------------------------------------------------

-- Get essential services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load game modules
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets) 
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- Get all player data
local playerData = LocalData:Get()
if not playerData then
    warn("Could not load player data. Stopping script.")
    return
end

-- Safety first: Get a list of all pet IDs that are currently equipped on any team.
local equippedPetIds = {}
if playerData.Teams then
    for _, teamData in pairs(playerData.Teams) do
        if teamData.Pets then
            for _, petId in ipairs(teamData.Pets) do
                equippedPetIds[petId] = true
            end
        end
    end
end

-- ## PHASE 1: IDENTIFY PETS TO DELETE ##
print("Phase 1: Reading inventory and identifying pets to delete...")
local petsToDelete = {} -- Create a new, temporary list

-- Loop through every pet in the player's inventory to read them
for _, petInstance in pairs(playerData.Pets) do
    -- Skip if pet is equipped
    if equippedPetIds[petInstance.Id] then
        continue
    end

    -- Look up the pet's rarity
    local petBaseData = PetDatabase[petInstance.Name]
    if petBaseData and petBaseData.Rarity then
        local rarity = petBaseData.Rarity
        
        -- If rarity matches our list, add its ID to our temporary list
        if raritiesToDelete[rarity] then
            print("  > Marked for deletion: " .. petInstance.Name .. " (Rarity: " .. rarity .. ")")
            table.insert(petsToDelete, {Id = petInstance.Id, Name = petInstance.Name})
        end
    end
end
print("Phase 1 Complete. Found " .. #petsToDelete .. " pets to delete.")
print(" ") -- Spacer

-- ## PHASE 2: DELETE THE IDENTIFIED PETS ##
print("Phase 2: Sending delete commands...")

if #petsToDelete > 0 then
    -- Now, loop through our safe, temporary list
    for _, petInfo in ipairs(petsToDelete) do
        print("  > Deleting: " .. petInfo.Name)
        
        local args = {
            "DeletePet",
            petInfo.Id, -- The unique ID of the pet to delete
            1,          -- Quantity
            false       -- Is equipped (always false)
        }
        
        RemoteEvent:FireServer(unpack(args))
        
        -- Wait a moment before deleting the next one
        task.wait(0.5) 
    end
end

print("--- Auto-delete complete! Deleted " .. #petsToDelete .. " pets. ---")
