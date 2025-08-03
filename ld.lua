-- Advanced Auto-Delete & Shiny Script (v3)

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
    MAX_LEGENDARY_TIER_TO_DELETE = 2,
    CheckInterval = 1.0
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
    
    return 0
end

local function isInventoryFull()
    local storageLabel = PlayerGui.ScreenGui.Inventory.Frame.Top.StorageHolder.Storage
    if not storageLabel then return false end
    
    local text = storageLabel.Text
    local current, max = text:match("(%d+)/(%d+)")
    if not (current and max) then return false end
    
    return tonumber(current) >= tonumber(max)
end

-- ## THE FIX IS IN THIS FUNCTION ##
local function getPetCountsAndInstances()
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return {} end
    
    local petGroups = {}
    for _, petInstance in pairs(playerData.Pets) do
        -- Only count pets for crafting if they are NOT shiny
        if not petInstance.Shiny then
            if not petGroups[petInstance.Name] then
                petGroups[petInstance.Name] = {Count = 0, Instances = {}}
            end
            petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + (petInstance.Amount or 1)
            table.insert(petGroups[petInstance.Name].Instances, petInstance)
        end
    end
    return petGroups
end

local shinyRequirements = {
    ["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10
}

-- ## Main Automation Loop ##
print("Advanced Pet Manager started. To stop, run: getgenv().Config.AutoManagePets = false")

while getgenv().Config.AutoManagePets do
    -- ## ACTION 1: ALWAYS CHECK FOR SHINY CRAFTING ##
    local petGroups = getPetCountsAndInstances()
    for petName, groupData in pairs(petGroups) do
        local petBaseData = PetDatabase[petName]
        if petBaseData and petBaseData.Rarity then
            local rarity = petBaseData.Rarity
            local requiredAmount = shinyRequirements[rarity]
            if requiredAmount and table.find(getgenv().Config.RARITY_TO_SHINY, rarity) and groupData.Count >= requiredAmount then
                print("Found " .. groupData.Count .. "/" .. requiredAmount .. " of normal '" .. petName .. "'. Crafting shiny...")
                RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                task.wait(1)
                break
            end
        end
    end

    -- ## ACTION 2: ONLY DELETE PETS WHEN INVENTORY IS FULL ##
    if isInventoryFull() then
        print("Inventory is full. Checking for pets to delete...")
        local playerData = LocalData:Get()
        
        if playerData and playerData.Pets then
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
                            elseif petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE and not petInstance.Shiny and not petInstance.Mythic then shouldDelete = true
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
            
            if #petsToDelete > 0 then
                print("Found " .. #petsToDelete .. " pets to delete.")
                for _, pet in pairs(petsToDelete) do
                    if not isInventoryFull() then 
                        print("Inventory has space. Stopping deletion cycle.")
                        break
                    end
                    print("Deleting '" .. pet.Name .. "' (Shiny: " .. tostring(pet.Shiny or false) .. ")")
                    RemoteEvent:FireServer("DeletePet", pet.Id, 1, false)
                    task.wait(0.2)
                end
            else
                warn("Inventory is full, but no pets matched the deletion rules.")
            end
        end
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("Advanced Pet Manager has stopped.")
