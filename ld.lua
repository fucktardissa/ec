-- Advanced Auto-Delete & Shiny Script (v6 - Efficient Stack Deletion)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoManagePets = true,
    Debug = true, -- SET TO TRUE to see detailed deletion logic in the console
    MAKE_MYTHICS_SHINY = true,
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

-- ## Pre-processing Config for Case-Insensitivity ##
local RARITY_TO_DELETE_LOWER = {}
for _, rarity in ipairs(getgenv().Config.RARITY_TO_DELETE) do
    table.insert(RARITY_TO_DELETE_LOWER, string.lower(rarity))
end
local PETS_TO_DELETE_LOWER = {}
for _, petName in ipairs(getgenv().Config.PETS_TO_DELETE) do
    table.insert(PETS_TO_DELETE_LOWER, string.lower(petName))
end


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

local function getNormalPetCounts()
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return {} end
    local petGroups = {}
    for _, petInstance in pairs(playerData.Pets) do
        if not petInstance.Shiny and not petInstance.Mythic then
            if not petGroups[petInstance.Name] then
                petGroups[petInstance.Name] = {Count = 0, Instances = {}}
            end
            petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + (petInstance.Amount or 1)
            table.insert(petGroups[petInstance.Name].Instances, petInstance)
        end
    end
    return petGroups
end

local function getMythicPetCounts()
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return {} end
    local mythicGroups = {}
    for _, petInstance in pairs(playerData.Pets) do
        if petInstance.Mythic and not petInstance.Shiny then
            if not mythicGroups[petInstance.Name] then
                mythicGroups[petInstance.Name] = {Count = 0, Instances = {}}
            end
            mythicGroups[petInstance.Name].Count = mythicGroups[petInstance.Name].Count + (petInstance.Amount or 1)
            table.insert(mythicGroups[petInstance.Name].Instances, petInstance)
        end
    end
    return mythicGroups
end

local shinyRequirements = {["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10}

print("Advanced Pet Manager (v6) started. To stop, run: getgenv().Config.AutoManagePets = false")

while getgenv().Config.AutoManagePets do
    -- ACTION 1: SHINY CRAFTING
    local normalPetGroups = getNormalPetCounts()
    for petName, groupData in pairs(normalPetGroups) do
        local petBaseData = PetDatabase[petName]
        if petBaseData and petBaseData.Rarity then
            if groupData.Count >= (shinyRequirements[petBaseData.Rarity] or 999) then
                print("Found " .. groupData.Count .. "/" .. shinyRequirements[petBaseData.Rarity] .. " of normal '" .. petName .. "'. Crafting shiny...")
                RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                task.wait(1)
                break
            end
        end
    end
    if getgenv().Config.MAKE_MYTHICS_SHINY then
        local mythicPetGroups = getMythicPetCounts()
        for petName, groupData in pairs(mythicPetGroups) do
            if groupData.Count >= 10 then
                print("Found " .. groupData.Count .. "/10 of mythic '" .. petName .. "'. Crafting shiny mythic...")
                RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                task.wait(1)
                break
            end
        end
    end

    -- ACTION 2: DELETION (ONLY WHEN FULL)
    if isInventoryFull() then
        print("Inventory is full. Checking for pets to delete...")
        local playerData = LocalData:Get()
        if playerData and playerData.Pets then
            local petsToDelete = {}
            for _, petInstance in pairs(playerData.Pets) do
                if not petInstance.Equipped then
                    local petBaseData = PetDatabase[petInstance.Name]
                    local shouldDelete = false
                    
                    if petBaseData and petBaseData.Rarity then
                        local petNameLower = string.lower(petInstance.Name)
                        local rarityLower = string.lower(petBaseData.Rarity)

                        if getgenv().Config.Debug then print("Checking: "..petInstance.Name..", Rarity: "..petBaseData.Rarity..", Amount: "..tostring(petInstance.Amount or 1)) end
                        
                        if table.find(PETS_TO_DELETE_LOWER, petNameLower) then
                            shouldDelete = true
                        elseif petBaseData.Rarity == "Legendary" then
                            local petTier = getPetTier(petInstance.Name)
                            if petInstance.Shiny and getgenv().Config.DELETE_LEGENDARY_SHINY then shouldDelete = true
                            elseif petInstance.Mythic and getgenv().Config.DELETE_LEGENDARY_MYTHIC then shouldDelete = true
                            elseif petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE and not petInstance.Shiny and not petInstance.Mythic then shouldDelete = true end
                        elseif table.find(RARITY_TO_DELETE_LOWER, rarityLower) then
                            shouldDelete = true
                        end
                    end
                    
                    if shouldDelete then table.insert(petsToDelete, petInstance) end
                end
            end
            
            if #petsToDelete > 0 then
                print("Found " .. #petsToDelete .. " stacks of pets to delete.")
                for _, pet in pairs(petsToDelete) do
                    if not isInventoryFull() then print("Inventory has space. Stopping deletion cycle.") break end
                    
                    -- ## THE FIX: Delete the entire stack at once using pet.Amount ##
                    local amountToDelete = pet.Amount or 1
                    print("Deleting " .. amountToDelete .. "x '" .. pet.Name .. "'")
                    RemoteEvent:FireServer("DeletePet", pet.Id, amountToDelete, false)
                    
                    task.wait(0.3) -- Wait a moment for the server to process the deletion
                end
            else
                warn("Inventory is full, but no pets matched the deletion rules.")
            end
        end
    end
    task.wait(getgenv().Config.CheckInterval)
end

print("Advanced Pet Manager has stopped.")
