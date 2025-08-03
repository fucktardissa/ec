--[[
    ============================================================
    -- ## AUTO-COMPLETE INDEX SCRIPT (v3 - Full Movement & Teleport) ##
    --
    -- This script automatically completes your pet indexes by
    -- finding missing pets, teleporting to the correct world/island,
    -- flying to the egg/rift, and hatching until the index is complete.
    ============================================================

    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- ## MASTER TOGGLES ##
    AUTO_COMPLETE_OVERWORLD_INDEX = true,
    AUTO_COMPLETE_OVERWORLD_SHINY_INDEX = false,
    AUTO_COMPLETE_MINIGAME_PARADISE_INDEX = false,
    AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX = false,

    -- ## HATCHING & CRAFTING SETTINGS ##
    MIN_RIFT_MULTIPLIER = 5,
    FallbackHatchDuration = 10.0, -- How long to hatch a normal egg before re-checking for rifts
    CheckInterval = 2.0,

    -- ## POTION SETTINGS ##
    POTIONS_WHEN_RIFT = {"Lucky", "Coins", "Speed", "Mythic"},
    POTIONS_WHEN_25X_RIFT = {"Lucky", "Coins", "Speed", "Mythic", "Infinity Elixir"}
}
getgenv().Config = Config

--[[
    ============================================================
    -- DATA (DO NOT EDIT)
    ============================================================
]]
local PetIndexDatabase = {
    Overworld = {
        ["Common Egg"] = {"Doggy", "Kitty", "Bunny", "Bear"}, ["Spotted Egg"] = {"Mouse", "Wolf", "Fox", "Polar Bear", "Panda"},
        ["Iceshard Egg"] = {"Ice Kitty", "Deer", "Ice Wolf", "Piggy", "Ice Deer", "Ice Dragon"}, ["Spikey Egg"] = {"Golem", "Dinosaur", "Ruby Golem", "Dragon", "Dark Dragon", "Emerald Golem"},
        ["Magma Egg"] = {"Magma Doggy", "Magma Deer", "Magma Fox", "Magma Bear", "Demon", "Inferno Dragon"}, ["Crystal Egg"] = {"Cave Bat", "Dark Bat", "Angel", "Emerald Bat", "Unicorn", "Flying Pig"},
        ["Lunar Egg"] = {"Space Mouse", "Space Bull", "Lunar Fox", "Lunarcorn", "Lunar Serpent", "Electra"}, ["Void Egg"] = {"Void Kitty", "Void Bat", "Void Demon", "Dark Phoenix", "Neon Elemental", "NULLVoid"},
        ["Hell Egg"] = {"Hell Piggy", "Hell Dragon", "Hell Crawler", "Inferno Demon", "Inferno Cube", "Virus"}, ["Nightmare Egg"] = {"Demon Doggy", "Skeletal Deer", "Night Crawler", "Hell Bat", "Green Hydra", "Demonic Hydra"},
        ["Rainbow Egg"] = {"Red Golem", "Orange Deer", "Yellow Fox", "Green Angel", "Hexarium", "Rainbow Shock"}
    },
    MinigameParadise = {
        ["Showman Egg"] = {"Game Doggy", "Gamer Boi", "Queen Of Hearts"}, ["Mining Egg"] = {"Mining Doggy", "Mining Bat", "Cave Mole", "Ore Golem", "Crystal Unicorn", "Stone Gargoyle"},
        ["Cyber Egg"] = {"Robo Kitty", "Martian Kitty", "Cyber Wolf", "Cyborg Phoenix", "Space Invader", "Bionic Shard"}, ["Neon Egg"] = {"Neon Doggy", "Hologram Dragon", "Disco Ball", "Neon Wyvern", "Neon Wire Eye", "Equalizer"}
    }
}
local RiftEggs = { "Iceshard Egg", "Spikey Egg", "Magma Egg", "Crystal Egg", "Lunar Egg", "Void Egg", "Hell Egg", "Nightmare Egg", "Rainbow Egg", "Showman Egg", "Mining Egg", "Cyber Egg", "Neon Egg" }
local eggPositions = {
    ["Common Egg"] = Vector3.new(-83.86, 10.11, 1.57), ["Spotted Egg"] = Vector3.new(-93.96, 10.11, 7.41), ["Iceshard Egg"] = Vector3.new(-117.06, 10.11, 7.74), ["Spikey Egg"] = Vector3.new(-124.58, 10.11, 4.58),
    ["Magma Egg"] = Vector3.new(-133.02, 10.11, -1.55), ["Crystal Egg"] = Vector3.new(-140.20, 10.11, -8.36), ["Lunar Egg"] = Vector3.new(-143.85, 10.11, -15.93), ["Void Egg"] = Vector3.new(-145.91, 10.11, -26.13),
    ["Hell Egg"] = Vector3.new(-145.17, 10.11, -36.78), ["Nightmare Egg"] = Vector3.new(-142.35, 10.11, -45.15), ["Rainbow Egg"] = Vector3.new(-134.49, 10.11, -52.36), ["Mining Egg"] = Vector3.new(-120, 10, -64),
    ["Showman Egg"] = Vector3.new(-130, 10, -60), ["Cyber Egg"] = Vector3.new(-95, 10, -63), ["Infinity Egg"] = Vector3.new(-99, 9, -26), ["Neon Egg"] = Vector3.new(-83, 10, -57)
}
local world1TeleportPoints = { {name = "Zen", path = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn", height = 15970}, {name = "The Void", path = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn", height = 10135}, {name = "Twilight", path = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn", height = 6855}, {name = "Outer Space", path = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn", height = 2655} }
local world2TeleportPoints = { {name = "W2 Spawn", path = "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn", height = 0}, {name = "Dice Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Dice Island.Island.Portal.Spawn", height = 2880}, {name = "Minecart Forest", path = "Workspace.Worlds.Minigame Paradise.Islands.Minecart Forest.Island.Portal.Spawn", height = 7660}, {name = "Robot Factory", path = "Workspace.Worlds.Minigame Paradise.Islands.Robot Factory.Island.Portal.Spawn", height = 13330}, {name = "Hyperwave Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn", height = 20010} }
local VERTICAL_SPEED, HORIZONTAL_SPEED = 300, 30

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local TweenService, Players, ReplicatedStorage, VirtualInputManager, RunService, Workspace = game:GetService("TweenService"), game:GetService("Players"), game:GetService("ReplicatedStorage"), game:GetService("VirtualInputManager"), game:GetService("RunService"), game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)

-- ## Helper Functions ##
function getDiscoveredPets() return (LocalData:Get() or {}).Discovered or {} end
function findMissingPet(world, isShiny)
    local discovered = getDiscoveredPets()
    for egg, pets in pairs(PetIndexDatabase[world]) do
        for _, pet in ipairs(pets) do
            local name = isShiny and "Shiny " .. pet or pet
            if not discovered[name] or discovered[name] < 1 then return pet, egg end
        end
    end
    return nil, nil
end
function getNormalPetCount(petName)
    local c = 0; for _,p in pairs((LocalData:Get() or {}).Pets or {}) do if p.Name == petName and not p.Shiny and not p.Mythic then c=c+(p.Amount or 1) end end; return c
end
function makePetShiny(petName)
    for _,p in pairs((LocalData:Get() or {}).Pets or {}) do if p.Name == petName and not p.Shiny and not p.Mythic then RemoteEvent:FireServer("MakePetShiny", p.Id); task.wait(1.5); return true end end
end
function findBestPotionsFromList(names)
    local best, wanted = {}, {}; for _,n in ipairs(names) do wanted[n]=true end
    for _,p in pairs((LocalData:Get() or {}).Potions or {}) do if wanted[p.Name] and (not best[p.Name] or p.Level > best[p.Name].Level) then best[p.Name]=p end end
    return best
end
function usePotions(list)
    local pots = findBestPotionsFromList(list); if not next(pots) then print("-> No required potions found."); return end
    for _,p in pairs(pots) do local num = math.min(p.Amount,10); if num>0 then print("-> Using "..num.."x '"..p.Name.."'"); RemoteEvent:FireServer("UsePotion",p.Name,p.Level,num); task.wait(0.5) end end
end
function getRiftMultiplier(riftInstance)
    local gui = riftInstance and riftInstance:FindFirstChild("Display") and riftInstance.Display:FindFirstChild("SurfaceGui")
    if not gui then return 0 end
    local luckLabel = gui:FindFirstChild("Icon") and gui.Icon:FindFirstChild("Luck")
    if luckLabel then return tonumber(string.match(luckLabel.Text, "%d+")) or 0 end
    return 0
end
function searchForRift(targetEgg)
    local riftFolder = Workspace:FindFirstChild("Rifts"); if not riftFolder then return nil end
    local name = targetEgg:gsub(" ", "-").."-Rift"; for _,r in ipairs(riftFolder:GetChildren()) do if r.Name==name then local m=getRiftMultiplier(r); if m>=Config.MIN_RIFT_MULTIPLIER then return r,m end end end
    return nil
end
function teleportToClosestPoint(targetHeight, teleportPoints, worldName)
    local closestPoint, smallestDifference = teleportPoints[#teleportPoints], math.huge
    for _, point in ipairs(teleportPoints) do
        local diff = math.abs(point.height - targetHeight)
        if diff < smallestDifference then smallestDifference, closestPoint = diff, point end
    end
    print("Teleporting to closest portal in " .. worldName .. ": " .. closestPoint.name)
    RemoteEvent:FireServer("Teleport", closestPoint.path)
end
function performMovement(targetPosition)
    local character, humanoid, hrp, camera = LocalPlayer.Character, LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"), LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"), Workspace.CurrentCamera
    if not (humanoid and hrp and camera) then warn("Movement failed: Character/Camera not found."); return end
    local originalCollisions = {}; for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then originalCollisions[part] = part.CanCollide; part.CanCollide = false; end end
    local originalPlatformStand = humanoid.PlatformStand; humanoid.PlatformStand = true
    local intermediatePos = CFrame.new(hrp.Position.X, targetPosition.Y, hrp.Position.Z)
    local verticalTime = math.clamp((hrp.Position - intermediatePos.Position).Magnitude / VERTICAL_SPEED, 0.5, 5)
    TweenService:Create(hrp, TweenInfo.new(verticalTime, Enum.EasingStyle.Sine), {CFrame = intermediatePos}):Play().Completed:Wait()
    local horizontalTime = math.clamp((hrp.Position - targetPosition).Magnitude / HORIZONTAL_SPEED, 0.5, 10)
    TweenService:Create(hrp, TweenInfo.new(horizontalTime, Enum.EasingStyle.Sine), {CFrame = CFrame.new(targetPosition)}):Play().Completed:Wait()
    humanoid.PlatformStand = originalPlatformStand; for part, canCollide in pairs(originalCollisions) do if part and part.Parent then part.CanCollide = canCollide; end end
end
function hatchInteraction(isRift)
    local key = isRift and Enum.KeyCode.R or Enum.KeyCode.E
    VirtualInputManager:SendKeyEvent(true, key, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, key, false, game)
end

-- ## Main Automation Loop ##
print("--- Auto-Complete Index Script (v3 - Full Movement) Initialized ---")
while task.wait(Config.CheckInterval) do
    local currentTask, targetPet, targetEgg = "Idle", nil, nil

    if Config.AUTO_COMPLETE_OVERWORLD_INDEX then currentTask, targetPet, targetEgg = "Overworld Normal", findMissingPet("Overworld", false) end
    if not targetPet and Config.AUTO_COMPLETE_OVERWORLD_SHINY_INDEX then currentTask, targetPet, targetEgg = "Overworld Shiny", findMissingPet("Overworld", true) end
    if not targetPet and Config.AUTO_COMPLETE_MINIGAME_PARADISE_INDEX then currentTask, targetPet, targetEgg = "Minigame Paradise Normal", findMissingPet("MinigameParadise", false) end
    if not targetPet and Config.AUTO_COMPLETE_SHINY_MINIGAME_PARADISE_INDEX then currentTask, targetPet, targetEgg = "Minigame Paradise Shiny", findMissingPet("MinigameParadise", true) end

    if targetPet and targetEgg then
        print("Current Task: Completing " .. currentTask .. ". Goal: '" .. (string.find(currentTask, "Shiny") and "Shiny " or "") .. targetPet .. "' from '" .. targetEgg .. "'")
        
        if string.find(currentTask, "Shiny") then
            local petData = PetDatabase[targetPet]; local reqs = {["Common"]=16,["Unique"]=16,["Rare"]=12,["Epic"]=12,["Legendary"]=10}
            local req = petData and reqs[petData.Rarity] or 10
            if getNormalPetCount(targetPet) >= req then print("Have enough to craft shiny. Crafting..."); makePetShiny(targetPet); continue end
        end

        local canUseRift = table.find(RiftEggs, targetEgg)
        local foundRift, riftMultiplier = nil, nil
        if canUseRift then foundRift, riftMultiplier = searchForRift(targetEgg) end

        local targetPos = foundRift and (foundRift.Display.Position + Vector3.new(0, 4, 0)) or eggPositions[targetEgg]
        if not targetPos then print("Error: Could not find position for egg: " .. targetEgg); continue end

        -- Determine world and teleport
        local isMinigameWorld = PetIndexDatabase.MinigameParadise[targetEgg]
        if isMinigameWorld then teleportToClosestPoint(targetPos.Y, world2TeleportPoints, "Minigame Paradise") else teleportToClosestPoint(targetPos.Y, world1TeleportPoints, "Overworld") end
        task.wait(3) -- Wait for teleport

        performMovement(targetPos)
        task.wait(1)

        if foundRift then
            print("Engaging rift: " .. foundRift.Name .. " (" .. riftMultiplier .. "x)")
            if riftMultiplier >= 25 and #Config.POTIONS_WHEN_25X_RIFT > 0 then usePotions(Config.POTIONS_WHEN_25X_RIFT) elseif #Config.POTIONS_WHEN_RIFT > 0 then usePotions(Config.POTIONS_WHEN_RIFT) end
            while Workspace:FindFirstChild("Rifts") and Workspace.Rifts:FindFirstChild(foundRift.Name) and getRiftMultiplier(foundRift) > 0 do hatchInteraction(true); task.wait(0.5) end
            print("Rift is gone or depleted.")
        else
            print("Moving to normal egg: " .. targetEgg)
            local endTime = tick() + Config.FallbackHatchDuration
            while tick() < endTime do
                if canUseRift and searchForRift(targetEgg) then print("Rift appeared! Breaking from normal hatch."); break end
                hatchInteraction(false); task.wait(0.2)
            end
        end
    else
        print("All configured indexes are complete! Script is now idle."); task.wait(30)
    end
end
