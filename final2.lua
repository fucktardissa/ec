--[[
    ================================================================
    -- ## ONE-CLICK STARTER ROUTINE SCRIPT (V2) ##
    ================================================================
    --
    -- DESCRIPTION:
    -- This script automates the entire early-game progression.
    -- It is designed to be run once on a new account to quickly
    -- unlock content, use starting items, upgrade essential masteries,
    -- and prepare the player for World 2.
    --
]]

--[[
    ============================================================
    -- ## STARTER ROUTINE CONFIGURATION ##
    -- Modify these values to change the goals of the routine.
    ============================================================
]]
local StarterRoutineConfig = {
    -- ## Potion Usage ##
    -- The script will use the BEST TIER of each potion type listed below at the start of the routine.
    USE_POTIONS_ON_START = {"Coins", "Lucky", "Speed", "Infinity Potion"},

    -- ## Mastery Level Targets ##
    -- The script will farm currency until these levels are reached.
    TargetLevels = {
        Pets = 15,
        Buffs = 18,
        Shops = 10,
        Minigames = 0, -- Set to 0 to ignore
        Rifts = 0      -- Set to 0 to ignore
    },

    -- ## Currency & Unlock Requirements ##
    MIN_COINS_FOR_WORLD_2 = 10e9, -- 10 Billion coins needed to unlock the World 2 portal.
    GEMS_FOR_EVENT_AREA = 150000, -- Gems needed to trigger the event area unlock.
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Setup: Services, Modules, and Helper Functions ##
print("--- LOADING STARTER ROUTINE SERVICES & MODULES ---")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local RemoteFunction = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MasteryData = require(ReplicatedStorage.Shared.Data.Mastery)
local CodesModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Codes"))

-- Helper function to get player currency
local function getCurrency(currencyType)
    local playerData = LocalData:Get()
    return playerData and playerData[currencyType] or 0
end

-- Helper function to check if the player is near a specific location
local function isPlayerNear(targetPos, maxDistance)
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    return (rootPart.Position - targetPos).Magnitude <= maxDistance
end

-- Helper function for movement
local function performMovement(targetPosition)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    if not (humanoid and humanoidRootPart) or isPlayerNear(targetPosition, 10) then return end
    print("Moving to new position...")
    local originalPlatformStand = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local moveTween = TweenService:Create(humanoidRootPart, TweenInfo.new(2, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)})
    moveTween:Play()
    moveTween.Completed:Wait()
    humanoid.PlatformStand = originalPlatformStand
end

-- Helper function to use the best tier of specified potion types
local function useBestPotionsFromList(potionTypes)
    print("Attempting to use best available potions from list...")
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return end
    
    local bestPotions = {}
    for _, potionData in pairs(playerData.Potions) do
        if table.find(potionTypes, potionData.Name) then
            if not bestPotions[potionData.Name] or potionData.Level > bestPotions[potionData.Name].Level then
                bestPotions[potionData.Name] = potionData
            end
        end
    end
    
    for name, potion in pairs(bestPotions) do
        if potion.Amount > 0 then
            print("-> Using " .. potion.Amount .. "x '" .. potion.Name .. "' (Level " .. potion.Level .. ")")
            -- The remote takes Name, Level, and Amount as separate arguments.
            RemoteEvent:FireServer("UsePotion", potion.Name, potion.Level, potion.Amount)
            task.wait(0.5)
        end
    end
end

-- Helper function to use all Golden Orbs
local function useAllGoldenOrbs()
    print("Attempting to use all Golden Orbs...")
    local playerData = LocalData:Get()
    if not (playerData and playerData.Powerups and playerData.Powerups["Golden Orb"]) then
        print("-> No Golden Orbs found.")
        return
    end
    local orbCount = playerData.Powerups["Golden Orb"]
    if orbCount > 0 then
        print("-> Found " .. orbCount .. " Golden Orbs. Using all...")
        for i = 1, orbCount do
            RemoteEvent:FireServer("UseGoldenOrb")
            task.wait(0.2)
        end
    end
end

-- Helper function to collect nearby resources (from user-provided script)
local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    local collectedCount = 0
    for _, child in ipairs(renderedFolder:GetChildren()) do
        if child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                collectRemote:FireServer(item.Name)
                item:Destroy()
                collectedCount = collectedCount + 1
                task.wait()
            end
        end
    end
    if collectedCount > 0 then
        print("Collected " .. collectedCount .. " nearby pickups.")
    end
end

print("--- ALL SERVICES & MODULES LOADED SUCCESSFULLY ---")

-- ============================
-- ## START OF ROUTINE LOGIC ##
-- ============================
task.spawn(function()
    print("--- STARTER ROUTINE INITIATED ---")

    -- STEP 0: UNLOCK ALL ISLANDS
    print("[STEP 0] Unlocking all available islands...")
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local originalCFrame = rootPart.CFrame
    for _, islandModel in ipairs(Workspace.Worlds["The Overworld"].Islands:GetChildren()) do
        local hitbox = islandModel:FindFirstChild("UnlockHitbox", true)
        if hitbox then
            rootPart.CFrame = hitbox.CFrame; task.wait(1.0)
        end
    end
    rootPart.CFrame = originalCFrame
    print("[STEP 0] Island unlocking complete.")
    task.wait(2)

    -- STEP 1: REDEEM ALL CODES
    print("[STEP 1] Redeeming all available codes...")
    local codesToRedeem = {}
    for codeName, _ in pairs(CodesModule) do table.insert(codesToRedeem, codeName) end
    for i, codeName in ipairs(codesToRedeem) do
        pcall(function() RemoteFunction:InvokeServer("RedeemCode", codeName) end)
        task.wait(0.2)
    end
    print("[STEP 1] Code redemption complete.")
    task.wait(2)

    -- STEP 2 & 3: CONSTANT BUBBLE & SELL (BACKGROUND TASKS)
    print("[STEP 2 & 3] Starting background bubble/sell process...")
    task.spawn(function()
        while true do pcall(function() RemoteEvent:FireServer("BlowBubble") end); task.wait(0.1) end
    end)
    task.spawn(function()
        while true do pcall(function() RemoteEvent:FireServer("SellBubble") end); task.wait(0.1) end
    end)

    -- STEP 4: USE POTIONS & ORBS, THEN HATCH STARTER PETS
    print("[STEP 4] Using starting items...")
    useBestPotionsFromList(StarterRoutineConfig.USE_POTIONS_ON_START)
    useAllGoldenOrbs()

    print("Moving to Iceshard Egg to hatch starter pets...")
    local iceshardEggPosition = Vector3.new(-11, 9, -51)
    performMovement(iceshardEggPosition)
    
    print("Hatching for 30 seconds...")
    local hatchEndTime = tick() + 30
    while tick() < hatchEndTime do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.05);
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait(0.05);
    end
    
    print("Equipping best pets...")
    RemoteEvent:FireServer("EquipBestPets")
    print("[STEP 4] Initial hatching complete.")
    task.wait(2)

    -- STEP 5: START THE FARMING LOOP (RUNS IN THE BACKGROUND)
    local farmingActive = true
    task.spawn(function()
        print("[STEP 5] Starting background farming and collection loop.")
        local zenTeleportPath = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn"
        local zenFarmingPosition = Vector3.new(-36, 15973, 47)

        while farmingActive do
            if not isPlayerNear(zenFarmingPosition, 500) then
                print("Not near Zen. Teleporting to farm...")
                RemoteEvent:FireServer("Teleport", zenTeleportPath)
                task.wait(3)
            end
            performMovement(zenFarmingPosition)
            
            -- Hatch one egg while farming
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.05);
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait(0.05);
            
            -- Collect any resources that have spawned
            collectNearbyPickups()
            
            task.wait(0.5) -- Short delay to prevent spamming
        end
    end)

    -- STEP 6: WAIT FOR RESOURCES TO BUILD
    print("[STEP 6] Farming has started. Waiting 3 minutes to build resources before upgrading mastery...")
    task.wait(180)

    -- STEP 7: MASTERY UPGRADE LOOP
    print("[STEP 7] Starting mastery upgrade loop.")
    local masteryGoalsMet = false
    while not masteryGoalsMet do
        masteryGoalsMet = true -- Assume goals are met until a check fails
        local canAffordAnyUpgrade = false

        for pathName, targetLevel in pairs(StarterRoutineConfig.TargetLevels) do
            local currentLevel = (LocalData:Get().MasteryLevels or {})[pathName] or 0
            if currentLevel < targetLevel then
                masteryGoalsMet = false -- A goal is not met
                local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                if nextLevelData and getCurrency(nextLevelData.Cost.Currency) >= nextLevelData.Cost.Amount then
                    print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. (currentLevel + 1))
                    RemoteEvent:FireServer("UpgradeMastery", pathName)
                    canAffordAnyUpgrade = true
                    task.wait(1.5)
                    break -- Re-check all masteries after one upgrade
                end
            end
        end

        if not canAffordAnyUpgrade and not masteryGoalsMet then
            print("Cannot afford next mastery upgrade. Farming continues in background...")
            task.wait(10) -- Wait before checking again
        end
    end

    farmingActive = false -- Stop the background farming loop
    print("[STEP 8] All mastery goals have been met!")

    -- Final Steps (Event Area, World 2) would continue here...
    print("--- STARTER ROUTINE COMPLETE! ---")
end)
