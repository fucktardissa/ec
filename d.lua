-- Standalone Auto-Delete Script (Corrected Path)

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
-- ## THIS LINE IS UPDATED WITH THE CORRECT PATH ##
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

print("Starting auto-delete process... Pets on your teams will be ignored.")
local deletedCount = 0

-- Loop through every pet in the player's inventory
for _, petInstance in pairs(playerData.Pets) do
    -- SAFETY CHECK 1: Skip the pet if it's in the equipped list
    if equippedPetIds[petInstance.Id] then
        continue
    end

    -- Look up the pet's base data and rarity from the database
    local petBaseData = PetDatabase[petInstance.Name]
    if petBaseData and petBaseData.Rarity then
        local rarity = petBaseData.Rarity
        
        -- CHECK 2: See if this pet's rarity is in our delete list
        if raritiesToDelete[rarity] then
            print("Deleting pet: " .. petInstance.Name .. " (Rarity: " .. rarity .. ")")
            
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
        end
    end
end

print("Auto-delete complete! Deleted " .. deletedCount .. " pets.")
