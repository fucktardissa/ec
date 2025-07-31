-- Standalone Auto-Delete Script (Debug Version)

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
print("--- Finding Equipped Pets ---")
local equippedPetIds = {}
if playerData.Teams then
    for teamId, teamData in pairs(playerData.Teams) do
        if teamData.Pets then
            for _, petId in ipairs(teamData.Pets) do
                print("Found equipped pet ID on team '" .. teamId .. "': " .. petId)
                equippedPetIds[petId] = true
            end
        end
    end
end
print("--- Finished Finding Equipped Pets ---")
print(" ") -- Spacer

print("--- Starting Auto-Delete Process ---")
local deletedCount = 0

-- Loop through every pet in the player's inventory
for i, petInstance in pairs(playerData.Pets) do
    print("Checking inventory pet slot #" .. i .. ": " .. petInstance.Name .. " (ID: " .. petInstance.Id .. ")")

    -- SAFETY CHECK 1: Skip the pet if it's in the equipped list
    if equippedPetIds[petInstance.Id] then
        print(" > Decision: Skipping equipped pet.")
        print(" ") -- Spacer
        continue
    end

    -- Look up the pet's base data and rarity from the database
    local petBaseData = PetDatabase[petInstance.Name]
    if petBaseData and petBaseData.Rarity then
        local rarity = petBaseData.Rarity
        print(" > Found rarity: " .. rarity)
        
        -- CHECK 2: See if this pet's rarity is in our delete list
        if raritiesToDelete[rarity] then
            print(" > Decision: Rarity is in delete list. DELETING.")
            
            -- Prepare the arguments to send to the server
            local args = {
                "DeletePet",
                petInstance.Id, -- The unique ID of the pet to delete
                1,              -- Quantity
                false           -- Is equipped (we know it's false because of our safety check)
            }
            
            -- Fire the delete event
            RemoteEvent:FireServer(unpack(args))
            deletedCount = deletedCount + 1
            
            -- Add a small delay to avoid overwhelming the server
            task.wait(0.5) 
        else
            print(" > Decision: Rarity is NOT in delete list. Skipping.")
        end
    else
        print(" > Decision: Could not find pet in database. Skipping.")
    end
    print(" ") -- Spacer
end

print("--- Auto-delete complete! Deleted " .. deletedCount .. " pets. ---")
