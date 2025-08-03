--[[
    ============================================================
    -- ## AUTO-COMPLETE INDEX SCRIPT (Full Version) ##
    --
    -- This script is designed to automatically complete your pet indexes
    -- by targeting and hatching eggs that contain pets you haven't
    -- discovered yet. It combines auto-hatching, rift hatching,
    -- and auto-crafting for maximum efficiency.
    ============================================================

    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- ## MASTER TOGGLES ##
    -- Set these to true to enable the specific index you want to complete.
    -- The script will work on them in the order listed below.
    AUTO_COMPLETE_OVERWORLD_INDEX = true,
    AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false,
    AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false,
    AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false,

    -- ## HATCHING & CRAFTING SETTINGS ##
    MIN_RIFT_MULTIPLIER = 5,       -- Minimum multiplier to consider a rift worth hatching.
    FallbackHatchDuration = 5.0,   -- How long to hatch a normal egg if no rift is found.
    CheckInterval = 2.0,           -- How often the main loop runs.

    -- ## POTION SETTINGS (FROM AUTO-RIFT SCRIPT) ##
    POTIONS_WHEN_RIFT = {"Lucky", "Coins", "Speed", "Mythic"},
    POTIONS_WHEN_25X_RIFT = {"Lucky", "Coins", "Speed", "Mythic", "Infinity Elixir"}
}
getgenv().Config = Config

--[[
    ============================================================
    -- PET & EGG DATABASE (DO NOT EDIT)
    ============================================================
]]
local PetIndexDatabase = {
    Overworld = {
        ["Common Egg"] = {"Doggy", "Kitty", "Bunny", "Bear"},
        ["Spotted Egg"] = {"Mouse", "Wolf", "Fox", "Polar Bear", "Panda"},
        ["Iceshard Egg"] = {"Ice Kitty", "Deer", "Ice Wolf", "Piggy", "Ice Deer", "Ice Dragon"},
        ["Spikey Egg"] = {"Golem", "Dinosaur", "Ruby Golem", "Dragon", "Dark Dragon", "Emerald Golem"},
        ["Magma Egg"] = {"Magma Doggy", "Magma Deer", "Magma Fox", "Magma Bear", "Demon", "Inferno Dragon"},
        ["Crystal Egg"] = {"Cave Bat", "Dark Bat", "Angel", "Emerald Bat", "Unicorn", "Flying Pig"},
        ["Lunar Egg"] = {"Space Mouse", "Space Bull", "Lunar Fox", "Lunarcorn", "Lunar Serpent", "Electra"},
        ["Void Egg"] = {"Void Kitty", "Void Bat", "Void Demon", "Dark Phoenix", "Neon Elemental", "NULLVoid"},
        ["Hell Egg"] = {"Hell Piggy", "Hell Dragon", "Hell Crawler", "Inferno Demon", "Inferno Cube", "Virus"},
        ["Nightmare Egg"] = {"Demon Doggy", "Skeletal Deer", "Night Crawler", "Hell Bat", "Green Hydra", "Demonic Hydra"},
        ["Rainbow Egg"] = {"Red Golem", "Orange Deer", "Yellow Fox", "Green Angel", "Hexarium", "Rainbow Shock"}
    },
    MinigameParadise = {
        ["Showman Egg"] = {"Game Doggy", "Gamer Boi", "Queen Of Hearts"},
        ["Mining Egg"] = {"Mining Doggy", "Mining Bat", "Cave Mole", "Ore Golem", "Crystal Unicorn", "Stone Gargoyle"},
        ["Cyber Egg"] = {"Robo Kitty", "Martian Kitty", "Cyber Wolf", "Cyborg Phoenix", "Space Invader", "Bionic Shard"},
        ["Neon Egg"] = {"Neon Doggy", "Hologram Dragon", "Disco Ball", "Neon Wyvern", "Neon Wire Eye", "Equalizer"}
    }
}

local RiftEggs = {
    "Iceshard Egg", "Spikey Egg", "Magma Egg", "Crystal Egg", "Lunar Egg",
    "Void Egg", "Hell Egg", "Nightmare Egg", "Rainbow Egg", "Showman Egg",
    "Mining Egg", "Cyber Egg", "Neon Egg"
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- ## Helper Functions ##

function getDiscoveredPets()
    local playerData = LocalData:Get()
    return playerData and playerData.Discovered or {}
end

function findMissingPet(world, isShiny)
    local discoveredPets = getDiscoveredPets()
    local worldIndex = PetIndexDatabase[world]
    for eggName, petsInEgg in pairs(worldIndex) do
        for _, petName in ipairs(petsInEgg) do
            local targetPetName = isShiny and "Shiny " .. petName or petName
            if not discoveredPets[targetPetName] or discoveredPets[targetPetName] < 1 then
                print("INDEX GOAL: Missing '" .. targetPetName .. "' from '" .. eggName .. "'")
                return petName, eggName
            end
        end
    end
    return nil, nil
end

function getNormalPetCount(petName)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return 0 end
    local count = 0
    for _, petInstance in pairs(playerData.Pets) do
        if petInstance.Name == petName and not petInstance.Shiny and not petInstance.Mythic then
            count = count + (petInstance.Amount or 1)
        end
    end
    return count
end

function makePetShiny(petNameToCraft)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return end
    for _, petInstance in pairs(playerData.Pets) do
        if petInstance.Name == petNameToCraft and not petInstance.Shiny and not petInstance.Mythic then
            print("Attempting to craft Shiny '" .. petNameToCraft .. "'...")
            RemoteEvent:FireServer("MakePetShiny", petInstance.Id)
            task.wait(1.5)
            return
        end
    end
end

function findBestPotionsFromList(potionNames)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return {} end
    local bestPotions = {}
    local wantedPotions = {}
    for _, name in ipairs(potionNames) do
        wantedPotions[name] = true
    end
    for _, potionData in pairs(playerData.Potions) do
        if wantedPotions[potionData.Name] then
            if not bestPotions[potionData.Name] or potionData.Level > bestPotions[potionData.Name].Level then
                bestPotions[potionData.Name] = {Level = potionData.Level, Name = potionData.Name, Amount = potionData.Amount}
            end
        end
    end
    return bestPotions
end

function usePotions(potionList)
    if #potionList == 0 then return end
    print("Finding and using the best potions from the list...")
    local bestPotionsFound = findBestPotionsFromList(potionList)
    if not next(bestPotionsFound) then
        print("-> You do not own any of the required potions.")
        return
    end
    for _, potionData in pairs(bestPotionsFound) do
        local quantityToUse = math.min(potionData.Amount, 10)
        if quantityToUse > 0 then
            print("-> Using " .. quantityToUse .. "x '" .. potionData.Name .. "' (Level " .. potionData.Level .. ")")
            RemoteEvent:FireServer("UsePotion", potionData.Name, potionData.Level, quantityToUse)
            task.wait(0.5)
        end
    end
end

function getRiftMultiplier(rift)
    local multiplier = 1
    pcall(function()
        local label = rift.GUI.Holder.Multiplier
        multiplier = tonumber(string.match(label.Text, "%d+")) or 1
    end)
    return multiplier
end

function searchForRift(targetEggName)
    local riftContainer = Workspace:FindFirstChild("Rifts")
    if not riftContainer then return nil end

    local expectedRiftName = targetEggName:gsub(" ", "-") .. "-Rift"
    for _, rift in ipairs(riftContainer:GetChildren()) do
        if rift.Name == expectedRiftName then
            local multiplier = getRiftMultiplier(rift)
            if multiplier >= Config.MIN_RIFT_MULTIPLIER then
                 print("Found valid rift: " .. rift.Name .. " (" .. multiplier .. "x)")
                return rift, multiplier
            end
        end
    end
    return nil
end

function hatchFromRift(rift, multiplier)
    print("Engaging target rift: " .. rift.Name)
    if multiplier >= 25 and #Config.POTIONS_WHEN_25X_RIFT > 0 then
        print("Applying special potions for 25x+ rift...")
        usePotions(Config.POTIONS_WHEN_25X_RIFT)
    elseif #Config.POTIONS_WHEN_RIFT > 0 then
        print("Applying standard rift potions...")
        usePotions(Config.POTIONS_WHEN_RIFT)
    end
    
    -- Teleport and hatch from the rift
    local eggName = rift.Name:gsub("-Rift", "")
    print("Hatching from rift: " .. eggName)
    RemoteEvent:FireServer("HatchEgg", eggName, 99, true) -- Hatch max
    task.wait(1.0) -- Cooldown after rift hatch
end

function hatchFromNormalEgg(eggName)
    print("Hatching from normal egg: " .. eggName)
    RemoteEvent:FireServer("HatchEgg", eggName, 1, false) -- Hatch 1
    task.wait(Config.FallbackHatchDuration)
end


-- ## Main Automation Loop ##
print("--- Auto-Complete Index Script (Full Version) Initialized ---")

while task.wait(Config.CheckInterval) do
    local currentTask = "Idle"
    local targetPet, targetEgg

    -- Determine Current Goal
    if Config.AUTO_COMPLETE_OVERWORLD_INDEX then
        currentTask = "Overworld Normal"; targetPet, targetEgg = findMissingPet("Overworld", false)
    end
    if not targetPet and Config.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX then
        currentTask = "Overworld Shiny"; targetPet, targetEgg = findMissingPet("Overworld", true)
    end
    if not targetPet and Config.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX then
        currentTask = "Minigame Paradise Normal"; targetPet, targetEgg = findMissingPet("MinigameParadise", false)
    end
    if not targetPet and Config.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX then
        currentTask = "Minigame Paradise Shiny"; targetPet, targetEgg = findMissingPet("MinigameParadise", true)
    end

    -- Execute Action Based on Goal
    if targetPet and targetEgg then
        print("Current Task: Completing " .. currentTask .. " Index.")
        
        if string.find(currentTask, "Shiny") then
            local basePetName = targetPet
            local petBaseData = PetDatabase[basePetName]
            local shinyReqs = {["Common"]=16,["Unique"]=16,["Rare"]=12,["Epic"]=12,["Legendary"]=10}
            local requiredCount = petBaseData and shinyReqs[petBaseData.Rarity] or 10
            
            if getNormalPetCount(basePetName) >= requiredCount then
                makePetShiny(basePetName)
                continue
            else
                 print("Need more '".. basePetName .."' to craft shiny. Required: "..requiredCount..", Have: "..getNormalPetCount(basePetName))
            end
        end

        local canUseRift = table.find(RiftEggs, targetEgg)
        local foundRift, riftMultiplier = nil, nil
        
        if canUseRift then
            foundRift, riftMultiplier = searchForRift(targetEgg)
        end

        if foundRift then
            hatchFromRift(foundRift, riftMultiplier)
        else
            hatchFromNormalEgg(targetEgg)
        end
    else
        print("All configured indexes are complete! Script is now idle.")
        task.wait(30)
    end
end
