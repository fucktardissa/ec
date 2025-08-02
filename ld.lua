--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoManagePets = true,
    RARITY_TO_SHINY = {"Common", "Unique", "Rare", "Epic", "Legendary"},
    PETS_TO_DELETE = {},
    RARITY_TO_DELETE = {"Common", "Unique", "Rare"},
    DELETE_LEGENDARY_SHINY = false,
    DELETE_LEGENDARY_MYTHIC = false,
    -- Maximum legendary tier to delete. If set to 2, it will delete Tier 1 and Tier 2 legendaries.
    MAX_LEGENDARY_TIER_TO_DELETE = 2,
    CheckInterval = 2.0 -- MODIFICATION: Shortened the interval for faster checks
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)

-- ## Helper Functions ##
local function getPetTier(petName)
    local T1 = {["Emerald Golem"]=true, ["Inferno Dragon"]=true, ["Unicorn"]=true, ["Flying Pig"]=true, ["Lunar Serpent"]=true, ["Electra"]=true, ["Dark Serpent"]=true, ["Inferno Cube"]=true, ["Crystal Unicorn"]=true, ["Cyborg Phoenix"]=true, ["Neon Wyvern"]=true}
    local T2 = {["Neon Elemental"]=true, ["Green Hydra"]=true, ["Stone Gargoyle"]=true, ["Gummy Dragon"]=true}
    local T3 = {["NULLVoid"]=true, ["Virus"]=true, ["Demonic Hydra"]=true, ["Hexarium"]=true, ["Rainbow Shock"]=true, ["Space Invader"]=true, ["Bionic Shard"]=true, ["Neon Wire Eye"]=true, ["Equalizer"]=true, ["Candy Winged Hydra"]=true, ["Rock Candy Golem"]=true}

    if T1[petName] then return 1 end
    if T2[petName] then return 2 end
    if T3[petName] then return 3 end

    return 0 -- Not a tiered legendary
end

local function isInventoryFull()
    local storageLabel = PlayerGui.ScreenGui.Inventory.Frame.Top.StorageHolder.Storage
    local text = storageLabel.Text
    local current, max = text:match("(%d+)/(%d+)")
    current, max = tonumber(current), tonumber(max)
    return current and max and current >= max
end

-- ## Main Automation Loop ##
print("IMPROVED Advanced Pet Manager started. To stop, run: getgenv().Config.AutoManagePets = false")

while getgenv().Config.AutoManagePets do
    -- Only run the logic if the inventory is full
    if isInventoryFull() then
        print("Inventory is full. Starting batch pet management...")
        local playerData = LocalData:Get()
        if not (playerData and playerData.Pets) then
            task.wait(getgenv().Config.CheckInterval)
            continue
        end

        --- MODIFICATION: The entire logic below is restructured for batch processing.

        -- Priority 1: Craft ALL possible shiny pets first.
        -- We loop until no more shinies can be made in a pass.
        local shiniesCraftedInPass
        repeat
            shiniesCraftedInPass = false
            local petGroups = {} -- Recalculate pet groups each time
            for _, petInstance in pairs(playerData.Pets) do
                if not petGroups[petInstance.Name] then
                    petGroups[petInstance.Name] = {Count = 0, Instances = {}}
                end
                petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + 1
                table.insert(petGroups[petInstance.Name].Instances, petInstance)
            end

            for petName, groupData in pairs(petGroups) do
                local petBaseData = PetDatabase[petName]
                if petBaseData and petBaseData.Rarity then
                    local rarity = petBaseData.Rarity
                    local requiredAmount = {["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10}[rarity]
                    
                    if requiredAmount and table.find(getgenv().Config.RARITY_TO_SHINY, rarity) and groupData.Count >= requiredAmount then
                        print("Found " .. groupData.Count .. "/" .. requiredAmount .. " of '" .. petName .. "'. Crafting shiny...")
                        RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                        shiniesCraftedInPass = true
                        task.wait(0.2) -- Small delay to prevent network spam
                        -- NOTE: We DO NOT break here, allowing it to find other shinies to craft.
                    end
                end
            end
            if shiniesCraftedInPass then
                task.wait(1) -- Wait for inventory to update after crafting pass
                playerData = LocalData:Get() -- Re-fetch data
            end
        until not shiniesCraftedInPass

        -- Priority 2: If inventory is STILL full, proceed with batch deletion.
        while isInventoryFull() do
            local petDeletedInPass = false
            local allPets = {}
            for _, p in pairs(playerData.Pets) do table.insert(allPets, p) end

            if #allPets == 0 then break end -- Exit if no pets left to check

            for i = #allPets, 1, -1 do
                local petInstance = allPets[i]
                local petBaseData = PetDatabase[petInstance.Name]
                
                -- Skip equipped pets
                if petInstance.Equipped then continue end
                
                local shouldDelete = false
                local deleteReason = ""

                -- Check deletion conditions
                if table.find(getgenv().Config.PETS_TO_DELETE, petInstance.Name) then
                    shouldDelete = true
                    deleteReason = "name: " .. petInstance.Name
                elseif petBaseData and petBaseData.Rarity then
                    local rarity = petBaseData.Rarity
                    if rarity == "Legendary" then
                        if petInstance.Shiny and getgenv().Config.DELETE_LEGENDARY_SHINY then
                            shouldDelete = true
                            deleteReason = "Legendary Shiny: " .. petInstance.Name
                        elseif petInstance.Mythic and getgenv().Config.DELETE_LEGENDARY_MYTHIC then
                            shouldDelete = true
                            deleteReason = "Legendary Mythic: " .. petInstance.Name
                        else
                            local petTier = getPetTier(petInstance.Name)
                            if petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE then
                                shouldDelete = true
                                deleteReason = "Legendary Tier " .. petTier .. " pet: " .. petInstance.Name
                            end
                        end
                    elseif table.find(getgenv().Config.RARITY_TO_DELETE, rarity) then
                        shouldDelete = true
                        deleteReason = "rarity '" .. rarity .. "': " .. petInstance.Name
                    end
                end
                
                -- If a reason to delete was found, fire the event
                if shouldDelete then
                    print("Deleting pet by " .. deleteReason)
                    RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                    petDeletedInPass = true
                    table.remove(allPets, i) -- Remove from our local table to avoid re-checking
                    task.wait(0.2) -- Small delay
                    break -- MODIFICATION: Break from this inner loop to re-check if inventory is still full
                end
            end
            
            -- If we looped through all pets and couldn't delete anything, break the loop to avoid getting stuck
            if not petDeletedInPass then
                warn("Inventory is full, but no deletable pets found based on current rules.")
                break
            end
            
            task.wait(0.5) -- Wait for inventory to update
            playerData = LocalData:Get() -- Re-fetch data
        end
        print("Pet management cycle complete.")
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("IMPROVED Advanced Pet Manager has stopped.")
