-- Master Auto-Index, Rift & Potion Script (Normal Rift Priority)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- ## PRIMARY GOAL: STANDARD RIFT HUNTING ##
    RIFT_EGGS = {"bee-egg"},
    MIN_RIFT_MULTIPLIER = 5,

    -- ## SECONDARY GOAL: INDEX COMPLETION ##
    INDEX_AS_FALLBACK = false,
    AUTO_COMPLETE_OVERWORLD_INDEX = true,
    AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false,
    AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false,
    AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false,

    -- ## FINAL FALLBACK: EGG HATCHING ##
    HATCH_1X_EGG_AS_INDEX = true,
    HATCH_1X_EGG = {"Spikey-Egg"},
    FallbackHatchDuration = 10.0,
    
    -- ## POTION SETTINGS ##
    POTIONS_WHEN_RIFT = {"Lucky", "Coins", "Speed", "Mythic"},
    POTIONS_WHEN_25X_RIFT = {"Lucky", "Coins", "Speed", "Mythic", "Infinity Elixir"}
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)

-- ## Data & Mappings ##
local IndexData = {
    Overworld = { ["Common Egg"] = {"Doggy", "Kitty", "Bunny", "Bear"}, ["Spotted Egg"] = {"Mouse", "Wolf", "Fox", "Polar Bear", "Panda"}, ["Iceshard Egg"] = {"Ice Kitty", "Deer", "Ice Wolf", "Piggy", "Ice Deer", "Ice Dragon"}, ["Spikey Egg"] = {"Golem", "Dinosaur", "Ruby Golem", "Dragon", "Dark Dragon", "Emerald Golem"}, ["Magma Egg"] = {"Magma Doggy", "Magma Deer", "Magma Fox", "Magma Bear", "Demon", "Inferno Dragon"}, ["Crystal Egg"] = {"Cave Bat", "Dark Bat", "Angel", "Emerald Bat", "Unicorn", "Flying Pig"}, ["Lunar Egg"] = {"Space Mouse", "Space Bull", "Lunar Fox", "Lunarcorn", "Lunar Serpent", "Electra"}, ["Void Egg"] = {"Void Kitty", "Void Bat", "Void Demon", "Dark Phoenix", "Neon Elemental", "NULLVoid"}, ["Hell Egg"] = {"Hell Piggy", "Hell Dragon", "Hell Crawler", "Inferno Demon", "Inferno Cube", "Virus"}, ["Nightmare Egg"] = {"Demon Doggy", "Skeletal Deer", "Night Crawler", "Hell Bat", "Green Hydra", "Demonic Hydra"}, ["Rainbow Egg"] = {"Red Golem", "Orange Deer", "Yellow Fox", "Green Angel", "Hexarium", "Rainbow Shock"} },
    MinigameParadise = { ["Showman Egg"] = {"Game Doggy", "Gamer Boi", "Queen Of Hearts"}, ["Mining Egg"] = {"Mining Doggy", "Mining Bat", "Cave Mole", "Ore Golem", "Crystal Unicorn", "Stone Gargoyle"}, ["Cyber Egg"] = {"Robo Kitty", "Martian Kitty", "Cyber Wolf", "Cyborg Phoenix", "Space Invader", "Bionic Shard"}, ["Neon Egg"] = {"Neon Doggy", "Hologram Dragon", "Disco Ball", "Neon Wyvern", "Neon Wire Eye", "Equalizer"} }
}
local PetToEggMap, EggToRiftMap, PetToWorldMap = {}, {}, {}
for worldName, eggs in pairs(IndexData) do
    for eggName, pets in pairs(eggs) do
        local riftName = eggName:gsub(" ", "-"):lower() .. "-egg"
        EggToRiftMap[eggName] = riftName
        for _, petName in ipairs(pets) do PetToEggMap[petName] = eggName; PetToWorldMap[petName] = worldName; end
    end
end
local eggPositions = { ["Common Egg"] = Vector3.new(-83.86, 10.11, 1.57), ["Spotted Egg"] = Vector3.new(-93.96, 10.11, 7.41), ["Iceshard Egg"] = Vector3.new(-117.06, 10.11, 7.74), ["Spikey Egg"] = Vector3.new(-124.58, 10.11, 4.58), ["Magma Egg"] = Vector3.new(-133.02, 10.11, -1.55), ["Crystal Egg"] = Vector3.new(-140.20, 10.11, -8.36), ["Lunar Egg"] = Vector3.new(-143.85, 10.11, -15.93), ["Void Egg"] = Vector3.new(-145.91, 10.11, -26.13), ["Hell Egg"] = Vector3.new(-145.17, 10.11, -36.78), ["Nightmare Egg"] = Vector3.new(-142.35, 10.11, -45.15), ["Rainbow Egg"] = Vector3.new(-134.49, 10.11, -52.36), ["Mining Egg"] = Vector3.new(-120, 10, -64), ["Showman Egg"] = Vector3.new(-130, 10, -60), ["Cyber Egg"] = Vector3.new(-95, 10, -63), ["Infinity Egg"] = Vector3.new(-99, 9, -26), ["Neon Egg"] = Vector3.new(-83, 10, -57) }
local EggsWithoutRifts = {["Common Egg"]=true, ["Spotted Egg"]=true, ["Iceshard Egg"]=true, ["Showman Egg"]=true}
local shinyRequirements = {["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10}
local world1TeleportPoints = {{name = "Zen", path = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn", height = 15970}, {name = "The Void", path = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn", height = 10135}, {name = "Twilight", path = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn", height = 6855}, {name = "Outer Space", path = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn", height = 2655}}
local world2TeleportPoints = {{name = "W2 Spawn", path = "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn", height = 0}, {name = "Dice Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Dice Island.Island.Portal.Spawn", height = 2880}, {name = "Minecart Forest", path = "Workspace.Worlds.Minigame Paradise.Islands.Minecart Forest.Island.Portal.Spawn", height = 7660}, {name = "Robot Factory", path = "Workspace.Worlds.Minigame Paradise.Islands.Robot Factory.Island.Portal.Spawn", height = 13330}, {name = "Hyperwave Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn", height = 20010}}
local world2RiftKeywords = {"Neon", "Cyber", "Showman", "Mining"}
local VERTICAL_SPEED, HORIZONTAL_SPEED = 300, 30 

-- ## Helper Functions ##

local function isPlayerNearEgg(eggName, distance)
    local eggPos = eggPositions[eggName]
    if not eggPos then return false end
    
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    return (rootPart.Position - eggPos).Magnitude < distance
end

local function findBestPotionsFromList(potionNames)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return {} end
    local bestPotions, wantedPotions = {}, {}
    for _, name in ipairs(potionNames) do wantedPotions[name] = true end
    for _, potionData in pairs(playerData.Potions) do
        if wantedPotions[potionData.Name] then
            if not bestPotions[potionData.Name] or potionData.Level > bestPotions[potionData.Name].Level then
                bestPotions[potionData.Name] = {Level = potionData.Level, Name = potionData.Name, Amount = potionData.Amount}
            end
        end
    end
    return bestPotions
end

local function usePotions(potionList)
    if #potionList == 0 then return end
    print("Finding and using the best potions...")
    local bestPotionsFound = findBestPotionsFromList(potionList)
    if not next(bestPotionsFound) then print("-> You do not own any of the required potions.") return end
    for _, potionData in pairs(bestPotionsFound) do
        local quantityToUse = 1
        if potionData.Amount >= quantityToUse then
            print("-> Using " .. quantityToUse .. "x '" .. potionData.Name .. "' (Level " .. potionData.Level .. ")")
            RemoteEvent:FireServer("UsePotion", potionData.Name, potionData.Level, quantityToUse)
            task.wait(0.5)
        end
    end
end

local function isRiftValid(riftNameFromConfig)
    if not riftNameFromConfig or riftNameFromConfig == "" then return nil end
    local riftFolder = workspace.Rendered.Rifts
    local riftNameLower = string.lower(riftNameFromConfig)
    for _, riftInstance in ipairs(riftFolder:GetChildren()) do
        if string.lower(riftInstance.Name) == riftNameLower then
            if riftInstance:FindFirstChild("Display") and riftInstance.Display:IsA("BasePart") then return riftInstance end
        end
    end
    return nil
end

local function getRiftMultiplier(riftInstance)
    local display = riftInstance:FindFirstChild("Display")
    if not display then return 0 end
    local gui = display:FindFirstChild("SurfaceGui")
    if not gui then return 0 end
    local icon = gui:FindFirstChild("Icon")
    if not icon then return 0 end
    local luckLabel = icon:FindFirstChild("Luck") 
    if luckLabel and luckLabel:IsA("TextLabel") then return tonumber(string.match(luckLabel.Text, "%d+")) or 0 end
    return 0
end

local function teleportToClosestPoint(targetHeight, teleportPoints, worldName)
    local closestPoint = teleportPoints[#teleportPoints]
    local smallestDifference = math.huge
    for _, point in ipairs(teleportPoints) do
        local difference = math.abs(point.height - targetHeight)
        if difference < smallestDifference then smallestDifference = difference; closestPoint = point; end
    end
    print("Teleporting to closest portal in " .. worldName .. ": " .. closestPoint.name)
    RemoteEvent:FireServer("Teleport", closestPoint.path)
end

local function performMovement(targetPosition) 
    local character = LocalPlayer.Character 
    local humanoid = character and character:FindFirstChildOfClass("Humanoid") 
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart") 
    if not (humanoid and humanoidRootPart) then 
        warn("Movement failed: Character parts not found.")
        return 
    end 
    local originalCollisions = {} 
    for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then originalCollisions[part] = part.CanCollide; part.CanCollide = false; end end 
    local originalPlatformStand = humanoid.PlatformStand 
    humanoid.PlatformStand = true 
    local startPos = humanoidRootPart.Position 
    local intermediatePos = CFrame.new(startPos.X, targetPosition.Y, startPos.Z) 
    local verticalTime = (startPos - intermediatePos.Position).Magnitude / VERTICAL_SPEED 
    local verticalTween = TweenService:Create(humanoidRootPart, TweenInfo.new(verticalTime, Enum.EasingStyle.Linear), {CFrame = intermediatePos}) 
    verticalTween:Play(); verticalTween.Completed:Wait() 
    local horizontalTime = (humanoidRootPart.Position - targetPosition).Magnitude / HORIZONTAL_SPEED 
    local horizontalTween = TweenService:Create(humanoidRootPart, TweenInfo.new(horizontalTime, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)}) 
    horizontalTween:Play(); horizontalTween.Completed:Wait() 
    humanoidRootPart.Velocity = Vector3.new(0, 0, 0) 
    humanoid.PlatformStand = originalPlatformStand 
    for part, canCollide in pairs(originalCollisions) do if part and part.Parent then part.CanCollide = canCollide; end end 
end

local function openRift()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

local function openRegularEgg()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait()
end

local function getMissingPets(mode)
    local discoveredPets = LocalData:Get().Discovered or {}
    local requiredPets, isShiny = {}, mode:find("Shiny")
    local world = mode:find("Overworld") and "Overworld" or "MinigameParadise"
    for _, petList in pairs(IndexData[world]) do
        for _, petName in ipairs(petList) do table.insert(requiredPets, petName) end
    end
    for _, petName in ipairs(requiredPets) do
        local targetName = isShiny and "Shiny " .. petName or petName
        if not discoveredPets[targetName] then return targetName end
    end
    return nil
end

local function getNormalPetCount(petName)
    local count = 0
    for _, petInstance in pairs(LocalData:Get().Pets) do
        if petInstance.Name == petName and not petInstance.Shiny and not petInstance.Mythic then count = count + (petInstance.Amount or 1) end
    end
    return count
end

local function findPetInstanceForCrafting(petName)
    for _, petInstance in pairs(LocalData:Get().Pets) do
        if petInstance.Name == petName and not petInstance.Shiny and not petInstance.Mythic then return petInstance.Id end
    end
    return nil
end

local function EngageRift(riftInstance, riftNameFromConfig)
    print("Engaging target rift: " .. riftInstance.Name)
    local multiplier = getRiftMultiplier(riftInstance)
    if multiplier >= 25 and #getgenv().Config.POTIONS_WHEN_25X_RIFT > 0 then usePotions(getgenv().Config.POTIONS_WHEN_25X_RIFT)
    elseif #getgenv().Config.POTIONS_WHEN_RIFT > 0 then usePotions(getgenv().Config.POTIONS_WHEN_RIFT) end
    
    local targetPosition = riftInstance.Display.Position + Vector3.new(0, 4, 0)
    local isWorld2Rift = false
    for _, keyword in ipairs(world2RiftKeywords) do
        if string.lower(riftNameFromConfig):find(string.lower(keyword)) then isWorld2Rift = true; break end
    end
    if isWorld2Rift then teleportToClosestPoint(targetPosition.Y, world2TeleportPoints, "World 2")
    else teleportToClosestPoint(targetPosition.Y, world1TeleportPoints, "World 1") end
    
    task.wait(5)
    performMovement(targetPosition)
    task.wait(1)
    
    print("Hatching rift...")
    while isRiftValid(riftInstance.Name) do openRift(); task.wait(0.5) end
    print("Rift is gone.")
end

local function PerformFallbackHatch()
    print("No standard or index rifts available. Proceeding to final fallback hatch.")
    local eggToHatchName, cfg = "", getgenv().Config
    if cfg.HATCH_1X_EGG_AS_INDEX then
        print("Fallback Mode: Hatching a needed index egg.")
        local missingForIndex = getMissingPets("Overworld") or getMissingPets("MinigameParadise") or getMissingPets("OverworldShiny") or getMissingPets("MinigameParadiseShiny")
        if missingForIndex then eggToHatchName = PetToEggMap[missingForIndex:gsub("Shiny ", "")] end
    else
        print("Fallback Mode: Hatching HATCH_1X_EGG.")
        if cfg.HATCH_1X_EGG[1] then eggToHatchName = cfg.HATCH_1X_EGG[1]:gsub("-", " ") end
    end

    if eggToHatchName and eggToHatchName ~= "" then
        local eggPos = eggPositions[eggToHatchName]
        if eggPos then
            -- ## THE FIX: Only teleport and move if not already near the egg ##
            if not isPlayerNearEgg(eggToHatchName, 20) then
                print("Not in position for fallback egg. Moving to: " .. eggToHatchName)
                local world = PetToWorldMap[eggToHatchName] or "Overworld"
                if world == "MinigameParadise" then RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
                else RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn") end
                task.wait(3)
                performMovement(eggPos)
            else
                print("Already in position at fallback egg. Continuing to hatch.")
            end

            local hatchEndTime = tick() + cfg.FallbackHatchDuration
            while tick() < hatchEndTime do openRegularEgg() end
        else
            print("Could not find position for fallback egg: " .. eggToHatchName)
        end
    else
        print("No fallback egg could be determined. Waiting.")
    end
end

-- ## Main Automation Loop ##
print("Master Script Started.")
task.spawn(function()
    while true do
        local cfg = getgenv().Config
        local actionTaken = false

        -- ## PRIORITY 1: STANDARD RIFT HUNTING ##
        print("Searching for standard rifts from config...")
        for _, riftName in ipairs(cfg.RIFT_EGGS) do
            local riftInstance = isRiftValid(riftName)
            if riftInstance and getRiftMultiplier(riftInstance) >= cfg.MIN_RIFT_MULTIPLIER then
                EngageRift(riftInstance, riftName)
                actionTaken = true
                break
            end
        end

        -- ## PRIORITY 2: INDEX AS FALLBACK ##
        if not actionTaken and cfg.INDEX_AS_FALLBACK then
            local isIndexModeActive = cfg.AUTO_COMPLETE_OVERWORLD_INDEX or cfg.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX or cfg.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX or cfg.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX
            if isIndexModeActive then
                local currentMode = ""
                if cfg.AUTO_COMPLETE_OVERWORLD_INDEX then currentMode = "Overworld"
                elseif cfg.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX then currentMode = "OverworldShiny"
                elseif cfg.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX then currentMode = "MinigameParadise"
                elseif cfg.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX then currentMode = "MinigameParadiseShiny" end
                
                print("Standard rifts not found. Checking for index tasks. Objective: " .. currentMode)
                local missingPet = getMissingPets(currentMode)

                if not missingPet then
                    print("SUCCESS: " .. currentMode .. " Index is complete!")
                    if currentMode == "Overworld" then cfg.AUTO_COMPLETE_OVERWORLD_INDEX = false
                    elseif currentMode == "OverworldShiny" then cfg.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false
                    elseif currentMode == "MinigameParadise" then cfg.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false
                    elseif currentMode == "MinigameParadiseShiny" then cfg.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false end
                    actionTaken = true
                else
                    print("Next index target: '" .. missingPet .. "'")
                    local basePetName = missingPet:gsub("Shiny ", "")
                    local eggName = PetToEggMap[basePetName]

                    if missingPet:find("Shiny ") then
                        local petDBInfo = PetDatabase[basePetName]
                        local requiredAmount = shinyRequirements[petDBInfo.Rarity] or 10
                        if getNormalPetCount(basePetName) >= requiredAmount then
                            print("Have enough to craft '"..missingPet.."'. Crafting...")
                            local instanceId = findPetInstanceForCrafting(basePetName)
                            if instanceId then RemoteEvent:FireServer("MakePetShiny", instanceId); task.wait(2) else warn("Could not find an instance of '"..basePetName.."' to craft with.") end
                            actionTaken = true
                        end
                    end
                    
                    if not actionTaken and not EggsWithoutRifts[eggName] then
                        local indexRiftName = EggToRiftMap[eggName]
                        local riftInstance = isRiftValid(indexRiftName)
                        if riftInstance and getRiftMultiplier(riftInstance) >= cfg.MIN_RIFT_MULTIPLIER then
                            print("Found active index rift: " .. riftInstance.Name)
                            EngageRift(riftInstance, indexRiftName)
                            actionTaken = true
                        end
                    end
                end
            end
        end

        -- ## PRIORITY 3: FINAL FALLBACK HATCHING ##
        if not actionTaken then
            PerformFallbackHatch()
        end
        
        task.wait(5)
    end
end)
