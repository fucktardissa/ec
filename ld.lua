-- Advanced Auto-Delete & Shiny Script (v9 - In-Game Auto-Delete Sync)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoManagePets = true,
    TOGGLE_GAME_AUTODELETE = false, -- Syncs RARITY_TO_DELETE with the in-game feature.
    MAKE_MYTHICS_SHINY = true,     -- Automatically crafts shiny mythics.
    RARITY_TO_DELETE = {},
    PETS_TO_DELETE = {"Doggy"},
    DELETE_LEGENDARY_SHINY = false,
    DELETE_LEGENDARY_MYTHIC = false,
    MAX_LEGENDARY_TIER_TO_DELETE = 2,
    CheckInterval = 2.0 -- How often the main loop runs
}
getgenv().Config = Config

--[[
    ============================================================
    -- DIAGNOSTICS & CORE SCRIPT
    ============================================================
]]
print("--- Pet Manager v9: Running Diagnostics ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ## Check 1: Core Modules ##
local LocalData_path = ReplicatedStorage:FindFirstChild("Client", true) and ReplicatedStorage.Client.Framework.Services.LocalData
local PetDatabase_path = ReplicatedStorage:FindFirstChild("Shared", true) and ReplicatedStorage.Shared.Data.Pets
local RemoteEvent_path = ReplicatedStorage:FindFirstChild("Shared", true) and ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

local LocalData = LocalData_path and require(LocalData_path)
local PetDatabase = PetDatabase_path and require(PetDatabase_path)
local RemoteEvent = RemoteEvent_path

if not LocalData then
    error("SCRIPT ERROR: Could not find the 'LocalData' module. The game has likely updated. Script stopped.")
    return
end
if not PetDatabase then
    error("SCRIPT ERROR: Could not find the 'PetDatabase' module. The game has likely updated. Script stopped.")
    return
end
if not RemoteEvent then
    error("SCRIPT ERROR: Could not find the 'RemoteEvent'. The game has likely updated. Script stopped.")
    return
end

print("SUCCESS: All modules and remotes found.")
print("-----------------------------------------")

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

-- ## ONE-TIME SYNC WITH IN-GAME AUTO-DELETE ##
local function SyncGameAutoDelete()
    if not getgenv().Config.TOGGLE_GAME_AUTODELETE then return end
    
    print("Syncing RARITY_TO_DELETE with in-game auto-delete settings...")
    local gameAutoDeleteSettings = LocalData:Get().AutoDelete or {}
    local petsToggled = 0

    for petName, petData in pairs(PetDatabase) do
        if petData.Rarity then
            local rarityLower = string.lower(petData.Rarity)
            if table.find(RARITY_TO_DELETE_LOWER, rarityLower) then
                if not gameAutoDeleteSettings[petName] then
                    print("Enabling in-game auto-delete for '" .. petName .. "'")
                    RemoteEvent:FireServer("ToggleAutoDelete", petName)
                    petsToggled = petsToggled + 1
                    task.wait(0.25)
                end
            end
        end
    end
    print("In-game auto-delete sync complete. Toggled " .. petsToggled .. " new pets.")
end

-- Run the sync once at the start
SyncGameAutoDelete()

print("Advanced Pet Manager (v9) started. Manual deletion is active.")

-- ## Main Automation Loop ##
while getgenv().Config.AutoManagePets do
    -- ## ACTION 1: SHINY CRAFTING ##
    local normalPetGroups = getNormalPetCounts()
    for petName, groupData in pairs(normalPetGroups) do
        local petBaseData = PetDatabase[petName]
        if petBaseData and petBaseData.Rarity then
            if groupData.Count >= (shinyRequirements[petBaseData.Rarity] or 999) then
                print("Found enough normal '" .. petName .. "' to craft shiny. Crafting...")
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
                print("Found enough mythic '" .. petName .. "' to craft shiny. Crafting...")
                RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                task.wait(1)
                break
            end
        end
    end

    -- ## ACTION 2: MANUAL PET DELETION (ALWAYS ACTIVE) ##
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

                    if table.find(PETS_TO_DELETE_LOWER, petNameLower) then shouldDelete = true
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
            print("Manual Deletion: Found " .. #petsToDelete .. " stacks of pets to clear from inventory.")
            for _, pet in pairs(petsToDelete) do
                local amountToDelete = pet.Amount or 1
                print("Deleting " .. amountToDelete .. "x '" .. pet.Name .. "'")
                RemoteEvent:FireServer("DeletePet", pet.Id, amountToDelete, false)
                task.wait(0.3)
            end
        end
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("Advanced Pet Manager has stopped.")
