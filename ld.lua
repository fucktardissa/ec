-- Advanced Auto-Delete & Shiny Script (with Tiers & Fixes)

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
    CheckInterval = 1.0 -- Reduced interval for faster checking
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
    -- NOTE: This can break if the game updates its UI.
    local storageLabel = PlayerGui.ScreenGui.Inventory.Frame.Top.StorageHolder.Storage
    if not storageLabel then return false end
    
    local text = storageLabel.Text
    local current, max = text:match("(%d+)/(%d+)")
    if not (current and max) then return false end
    
    return tonumber(current) >= tonumber(max)
end

local function getPetCountsAndInstances()
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return {} end
    
    local petGroups = {}
    for _, petInstance in pairs(playerData.Pets) do
        if not petGroups[petInstance.Name] then
            petGroups[petInstance.Name] = {Count = 0, Instances = {}}
        end
        -- ## FIX 1: Correctly count stacked pets ##
        petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + (petInstance.Amount or 1)
        table.insert(petGroups[petInstance.Name].Instances, petInstance)
    end
    return petGroups
end

local shinyRequirements = {
    ["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10
}

-- ## Main Automation Loop ##
print("Advanced Pet Manager started. To stop, run: getgenv().Config.AutoManagePets = false")

while getgenv().Config.AutoManagePets do
    if isInventoryFull() then
        print("Inventory is full. Starting pet management...")
        
        -- Priority 1: Try to make a shiny pet
        local petGroups = getPetCountsAndInstances()
        local shinyCrafted = false
        for petName, groupData in pairs(petGroups) do
            local petBaseData = PetDatabase[petName]
            if petBaseData and petBaseData.Rarity then
                local rarity = petBaseData.Rarity
                local requiredAmount = shinyRequirements[rarity]
                if requiredAmount and table.find(getgenv().Config.RARITY_TO_SHINY, rarity) and groupData.Count >= requiredAmount then
                    print("Found " .. groupData.Count .. "/" .. requiredAmount .. " of '" .. petName .. "'. Crafting shiny...")
                    RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                    shinyCrafted = true
                    task.wait(1) -- Wait a moment for the craft to process
                    break -- Stop after crafting one shiny
                end
            end
        end

        -- Priority 2: If no shiny was made, proceed to deletion
        if not shinyCrafted then
            print("No shinies could be crafted. Deleting unwanted pets...")
            local playerData = LocalData:Get()
            if not playerData or not playerData.Pets then continue end

            local petsToDelete = {}
            for _, petInstance in pairs(playerData.Pets) do
                if not petInstance.Equipped then
                    local petBaseData = PetDatabase[petInstance.Name]
                    local shouldDelete = false

                    if table.find(getgenv().Config.PETS_TO_DELETE, petInstance.Name) then
                        shouldDelete = true
                    elseif petBaseData and petBaseData.Rarity then
                        local rarity = petBaseData.Rarity
                        if rarity == "Legendary" then
                            local petTier = getPetTier(petInstance.Name)
                            if petInstance.Shiny and getgenv().Config.DELETE_LEGENDARY_SHINY then shouldDelete = true
                            elseif petInstance.Mythic and getgenv().Config.DELETE_LEGENDARY_MYTHIC then shouldDelete = true
                            elseif petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE then shouldDelete = true
                            end
                        elseif table.find(getgenv().Config.RARITY_TO_DELETE, rarity) then
                            shouldDelete = true
                        end
                    end
                    
                    if shouldDelete then
                        table.insert(petsToDelete, petInstance)
                    end
                end
            end
            
            -- ## FIX 2: Delete multiple pets in one cycle ##
            if #petsToDelete > 0 then
                print("Found " .. #petsToDelete .. " pets to delete.")
                for _, pet in pairs(petsToDelete) do
                    if not isInventoryFull() then 
                        print("Inventory has space. Stopping deletion cycle.")
                        break -- Stop if inventory is no longer full
                    end
                    print("Deleting '" .. pet.Name .. "' (Rarity: " .. (PetDatabase[pet.Name] and PetDatabase[pet.Name].Rarity or "Unknown") .. ")")
                    RemoteEvent:FireServer("DeletePet", pet.Id, 1, false)
                    task.wait(0.2) -- Small delay between deletions to avoid network spam
                end
            else
                warn("Inventory is full, but no pets matched the deletion rules.")
            end
        end
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("Advanced Pet Manager has stopped.")
