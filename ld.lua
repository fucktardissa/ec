-- Advanced Auto-Delete & Shiny Script (with Tiers)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoManagePets = true,
    RARITY_TO_SHINY = {"Common", "Unique", "Rare", "Epic", "Legendary"},
    PETS_TO_DELETE = {},
    RARITY_TO_DELETE = {"Common", "Unique", "Rare", "Epic",},
    DELETE_LEGENDARY_SHINY = false,
    DELETE_LEGENDARY_MYTHIC = false,
    -- Maximum legendary tier to delete. If set to 2, it will delete Tier 1 and Tier 2 legendaries.
    MAX_LEGENDARY_TIER_TO_DELETE = 1,
    CheckInterval = 5.0
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

-- This function determines a legendary pet's tier based on the lists you provided.
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

local function getPetCountsAndInstances()
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return {} end
    local petGroups = {}
    for _, petInstance in pairs(playerData.Pets) do
        if not petGroups[petInstance.Name] then
            petGroups[petInstance.Name] = {Count = 0, Instances = {}}
        end
        petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + 1
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
        local petGroups = getPetCountsAndInstances()
        local actionTaken = false

        -- Priority 1: Try to make a shiny pet
        for petName, groupData in pairs(petGroups) do
            local petBaseData = PetDatabase[petName]
            if petBaseData and petBaseData.Rarity then
                local rarity = petBaseData.Rarity
                local requiredAmount = shinyRequirements[rarity]
                if requiredAmount and table.find(getgenv().Config.RARITY_TO_SHINY, rarity) and groupData.Count >= requiredAmount then
                    print("Found " .. groupData.Count .. "/" .. requiredAmount .. " of '" .. petName .. "'. Crafting shiny...")
                    RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                    actionTaken = true
                    break
                end
            end
        end

        -- Priority 2: If no shiny was made, proceed to deletion
        if not actionTaken then
            print("No shinies could be crafted. Checking for pets to delete...")
            local playerData = LocalData:Get()
            local allPets = {}
            for _, p in pairs(playerData.Pets) do table.insert(allPets, p) end
            
            for i = #allPets, 1, -1 do
                local petInstance = allPets[i]
                local petBaseData = PetDatabase[petInstance.Name]
                if petInstance.Equipped then continue end
                
                if table.find(getgenv().Config.PETS_TO_DELETE, petInstance.Name) then
                    print("Deleting pet by name: " .. petInstance.Name)
                    RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                    actionTaken = true; break
                end

                if petBaseData and petBaseData.Rarity then
                    local rarity = petBaseData.Rarity
                    if rarity == "Legendary" then
                        if petInstance.Shiny and getgenv().Config.DELETE_LEGENDARY_SHINY then
                            print("Deleting Legendary Shiny: " .. petInstance.Name)
                            RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                            actionTaken = true; break
                        end
                        if petInstance.Mythic and getgenv().Config.DELETE_LEGENDARY_MYTHIC then
                            print("Deleting Legendary Mythic: " .. petInstance.Name)
                            RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                            actionTaken = true; break
                        end
                        
                        -- ## NEW TIER CHECK ##
                        local petTier = getPetTier(petInstance.Name)
                        if petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE then
                            print("Deleting Legendary Tier " .. petTier .. " pet: " .. petInstance.Name)
                            RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                            actionTaken = true; break
                        end

                    elseif table.find(getgenv().Config.RARITY_TO_DELETE, rarity) then
                        print("Deleting pet by rarity '" .. rarity .. "': " .. petInstance.Name)
                        RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                        actionTaken = true; break
                    end
                end
            end
        end

        if not actionTaken then
            warn("Inventory is full, but no action could be taken based on current rules.")
        end
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("Advanced Pet Manager has stopped.")
