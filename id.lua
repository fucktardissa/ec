-- Master Auto-Complete Index Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set one or more of these to true to begin.
    -- The script will work on them in the order listed below.
    AUTO_COMPLETE_OVERWORLD_INDEX = true,
    AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false,
    AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false,
    AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false,

    -- Rift settings used by the index script
    MIN_RIFT_MULTIPLIER = 5,
    
    -- Potion settings used by the index script
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
local PetToEggMap, EggToRiftMap = {}, {}
for worldName, eggs in pairs(IndexData) do
    for eggName, pets in pairs(eggs) do
        local riftName = eggName:gsub(" ", "-"):lower()
        EggToRiftMap[eggName] = riftName .. "-egg" -- More accurate rift naming
        for _, petName in ipairs(pets) do
            PetToEggMap[petName] = eggName
        end
    end
end

local EggsWithoutRifts = {["Common Egg"]=true, ["Spotted Egg"]=true, ["Iceshard Egg"]=true, ["Showman Egg"]=true}
local shinyRequirements = {["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10}
local world1TeleportPoints = {{name = "Zen", path = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn", height = 15970}, {name = "The Void", path = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn", height = 10135}, {name = "Twilight", path = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn", height = 6855}, {name = "Outer Space", path = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn", height = 2655}}
local world2TeleportPoints = {{name = "W2 Spawn", path = "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn", height = 0}, {name = "Dice Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Dice Island.Island.Portal.Spawn", height = 2880}, {name = "Minecart Forest", path = "Workspace.Worlds.Minigame Paradise.Islands.Minecart Forest.Island.Portal.Spawn", height = 7660}, {name = "Robot Factory", path = "Workspace.Worlds.Minigame Paradise.Islands.Robot Factory.Island.Portal.Spawn", height = 13330}, {name = "Hyperwave Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn", height = 20010}}
local world2RiftKeywords = {"Neon", "Cyber", "Showman", "Mining"}
local VERTICAL_SPEED, HORIZONTAL_SPEED = 300, 30

-- ## Helper Functions ##
local function findBestPotionsFromList(potionNames)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return {} end
    local bestPotions = {}
    local wantedPotions = {}
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
    print("Finding and using the best potions from the list...")
    local bestPotionsFound = findBestPotionsFromList(potionList)
    if not next(bestPotionsFound) then print("-> You do not own any of the required potions.") return end
    for _, potionData in pairs(bestPotionsFound) do
        local quantityToUse = math.min(potionData.Amount, 10)
        if quantityToUse > 0 then
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

local function isCorrectRiftStillValid(riftInstance)
    return riftInstance and riftInstance.Parent == workspace.Rendered.Rifts
end

local function isPlayerNearRift(riftInstance, distance)
    local character = LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not isCorrectRiftStillValid(riftInstance) then return false end
    return (humanoidRootPart.Position - riftInstance.Display.Position).Magnitude < distance
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
        if difference < smallestDifference then
            smallestDifference = difference
            closestPoint = point
        end
    end
    print("Teleporting to closest portal in " .. worldName .. ": " .. closestPoint.name)
    RemoteEvent:FireServer("Teleport", closestPoint.path)
end

local function performMovement(targetPosition)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    if not (humanoid and humanoidRootPart and camera) then warn("Movement failed: Character or Camera not found.") return end
    local originalCameraType, originalCameraSubject = camera.CameraType, camera.CameraSubject
    camera.CameraType = Enum.CameraType.Scriptable
    local cameraConnection = RunService.RenderStepped:Connect(function()
        local lookVector = humanoidRootPart.CFrame.LookVector
        local cameraOffset = Vector3.new(0, 10, 25)
        local cameraPosition = humanoidRootPart.Position - (lookVector * 15) + cameraOffset
        camera.CFrame = CFrame.lookAt(cameraPosition, humanoidRootPart.Position)
    end)
    local originalCollisions = {}
    for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then originalCollisions[part] = part.CanCollide; part.CanCollide = false; end end
    local originalPlatformStand = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local startPos = humanoidRootPart.Position
    local intermediatePos = CFrame.new(startPos.X, targetPosition.Y, startPos.Z)
    local verticalTime = math.clamp((startPos - intermediatePos.Position).Magnitude / VERTICAL_SPEED, 0.5, 5)
    TweenService:Create(humanoidRootPart, TweenInfo.new(verticalTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = intermediatePos}):Play().Completed:Wait()
    local horizontalTime = math.clamp((humanoidRootPart.Position - targetPosition).Magnitude / HORIZONTAL_SPEED, 0.5, 10)
    TweenService:Create(humanoidRootPart, TweenInfo.new(horizontalTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = CFrame.new(targetPosition)}):Play().Completed:Wait()
    cameraConnection:Disconnect()
    camera.CameraType, camera.CameraSubject = originalCameraType, originalCameraSubject
    humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
    humanoid.PlatformStand = originalPlatformStand
    for part, canCollide in pairs(originalCollisions) do if part and part.Parent then part.CanCollide = canCollide; end end
end

local function openRift()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

local function getMissingPets(mode)
    local discoveredPets = LocalData:Get().Discovered or {}
    local requiredPets = {}
    local isShiny = mode:find("Shiny")
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
        if petInstance.Name == petName and not petInstance.Shiny and not petInstance.Mythic then
            count = count + (petInstance.Amount or 1)
        end
    end
    return count
end

local function findPetInstanceForCrafting(petName)
    for _, petInstance in pairs(LocalData:Get().Pets) do
        if petInstance.Name == petName and not petInstance.Shiny and not petInstance.Mythic then
            return petInstance.Id
        end
    end
    return nil
end

local function EngageRift(riftNameToFind)
    print("Now hunting specifically for rift: " .. riftNameToFind)
    while getgenv().Config.AUTO_COMPLETE_OVERWORLD_INDEX do
        local targetRift = isRiftValid(riftNameToFind)
        if targetRift and getRiftMultiplier(targetRift) >= (getgenv().Config.MIN_RIFT_MULTIPLIER or 0) then
            -- Found it, now engage
            local multiplier = getRiftMultiplier(targetRift)
            if multiplier >= 25 and #getgenv().Config.POTIONS_WHEN_25X_RIFT > 0 then
                usePotions(getgenv().Config.POTIONS_WHEN_25X_RIFT)
            elseif #getgenv().Config.POTIONS_WHEN_RIFT > 0 then
                usePotions(getgenv().Config.POTIONS_WHEN_RIFT)
            end

            local movementAttempts, maxAttempts, inPosition = 0, 3, false
            while isCorrectRiftStillValid(targetRift) and movementAttempts < maxAttempts and not inPosition do
                movementAttempts = movementAttempts + 1
                local targetPosition = targetRift.Display.Position + Vector3.new(0, 4, 0)
                local isWorld2Rift = false
                for _, keyword in ipairs(world2RiftKeywords) do
                    if riftNameToFind:find(string.lower(keyword)) then isWorld2Rift = true; break end
                end
                if isWorld2Rift then teleportToClosestPoint(targetPosition.Y, world2TeleportPoints, "World 2")
                else teleportToClosestPoint(targetPosition.Y, world1TeleportPoints, "World 1") end
                task.wait(5)
                performMovement(targetPosition)
                task.wait(1)
                if isPlayerNearRift(targetRift, 15) then inPosition = true
                else warn("Proximity check failed. Retrying...") end
            end

            if inPosition then
                print("Hatching rift...")
                while isCorrectRiftStillValid(targetRift) do openRift(); task.wait(0.5) end
                print("Rift is gone.")
            else
                warn("Failed to get near the rift. Moving on.")
            end
            return -- Exit the EngageRift function
        end
        print("Rift not found. Waiting...")
        task.wait(10)
    end
end

-- ## Main Automation Loop ##
print("Master Auto-Index script started.")
task.spawn(function()
    while true do
        local cfg = getgenv().Config
        local currentMode = ""
        
        if cfg.AUTO_COMPLETE_OVERWORLD_INDEX then currentMode = "Overworld"
        elseif cfg.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX then currentMode = "OverworldShiny"
        elseif cfg.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX then currentMode = "MinigameParadise"
        elseif cfg.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX then currentMode = "MinigameParadiseShiny"
        else print("All index modes are disabled or complete. Script finished."); break end
        
        print("Current objective: " .. currentMode .. " Index")
        local missingPet = getMissingPets(currentMode)

        if not missingPet then
            print("SUCCESS: " .. currentMode .. " Index is complete!")
            if currentMode == "Overworld" then cfg.AUTO_COMPLETE_OVERWORLD_INDEX = false
            elseif currentMode == "OverworldShiny" then cfg.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false
            elseif currentMode == "MinigameParadise" then cfg.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false
            elseif currentMode == "MinigameParadiseShiny" then cfg.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false end
            task.wait(3)
            continue
        end

        print("Next target for index: '" .. missingPet .. "'")
        
        if missingPet:find("Shiny ") then
            local basePetName = missingPet:gsub("Shiny ", "")
            local petDBInfo = PetDatabase[basePetName]
            local requiredAmount = shinyRequirements[petDBInfo.Rarity] or 10
            
            if getNormalPetCount(basePetName) >= requiredAmount then
                print("Have enough '" .. basePetName .. "' to craft. Crafting shiny...")
                local instanceId = findPetInstanceForCrafting(basePetName)
                if instanceId then RemoteEvent:FireServer("MakePetShiny", instanceId); task.wait(2)
                else warn("Could not find an instance of '"..basePetName.."' to craft with."); task.wait(5) end
            else
                print("Not enough '" .. basePetName .. "' to craft. Hunting for rift...")
                local eggName = PetToEggMap[basePetName]
                if EggsWithoutRifts[eggName] then
                    print("Warning: '"..basePetName.."' is from an egg with no rift. Cannot auto-hatch."); task.wait(10)
                else
                    EngageRift(EggToRiftMap[eggName])
                end
            end
        else
            local eggName = PetToEggMap[missingPet]
            if EggsWithoutRifts[eggName] then
                print("Warning: '"..missingPet.."' is from an egg with no rift. Cannot auto-hatch."); task.wait(10)
            else
                EngageRift(EggToRiftMap[eggName])
            end
        end
    end
end)
