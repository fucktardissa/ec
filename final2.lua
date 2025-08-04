--[[
    ================================================================
    -- ## ONE-CLICK STARTER ROUTINE SCRIPT (V3.1 - POTION FIX) ##
    ================================================================
    --
    -- DESCRIPTION:
    -- This script automates the entire early-game progression.
    -- It is designed to be run once on a new account to quickly
    -- unlock content, use starting items, upgrade essential masteries,
    -- and prepare the player for World 2.
    --
    -- V3.1 FIXES:
    -- - Corrected the potion usage logic to fire the remote event
    --   with an amount of 1, matching the working test script.
    --   This prevents the server from rejecting the request to
    --   use an entire stack of potions at once.
    -- - Added more detailed print statements for clarity.
    --
]]

--[[
    ============================================================
    -- ## STARTER ROUTINE CONFIGURATION ##
    ============================================================
]]
local StarterRoutineConfig = {
    -- ## Potion Usage ##
    -- The script will use the BEST TIER of each potion type listed below at the start of the routine.
    USE_POTIONS_ON_START = {"Coins", "Lucky", "Speed"},

    -- ## Mastery Level Targets ##
    TargetLevels = {
        Pets = 15,
        Buffs = 18,
        Shops = 10,
        Minigames = 0,
        Rifts = 0
    },

    -- ## Currency & Unlock Requirements ##
    GEMS_FOR_EVENT_AREA = 150000,
    MIN_COINS_FOR_WORLD_2 = 10e9, -- 10 Billion coins needed to unlock the World 2 portal.
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Setup: Services, Modules, and Helper Functions ##
print("--- LOADING STARTER ROUTINE V3.1 SERVICES & MODULES ---")
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
    return (LocalData:Get() or {})[currencyType] or 0
end

-- Helper function to check if the player is near a specific location
local function isPlayerNear(targetPos, maxDistance)
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return rootPart and (rootPart.Position - targetPos).Magnitude <= maxDistance
end

-- Helper function for movement
local function performMovement(targetPosition)
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or isPlayerNear(targetPosition, 10) then return end
    print("Moving to new position...")
    local humanoid = rootPart.Parent:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.PlatformStand = true
    local moveTween = TweenService:Create(rootPart, TweenInfo.new(2, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)})
    moveTween:Play()
    moveTween.Completed:Wait()
    humanoid.PlatformStand = false
end

-- Helper function to use the best tier of specified potion types
local function useBestPotionsFromList(potionTypes)
    print("Attempting to use best available potions from list: " .. table.concat(potionTypes, ", "))
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then
        warn("Could not access player potion data at this time.")
        return
    end

    for _, potionNameToFind in ipairs(potionTypes) do
        task.wait(0.2) -- Small delay before searching for the next potion
        print("Searching for best '"..potionNameToFind.."' potion...")
        local bestPotionFound = nil
        
        -- Find the best version of the current potion type
        for _, potionInstance in pairs(playerData.Potions) do
            if string.match(potionInstance.Name, potionNameToFind) then
                if not bestPotionFound or potionInstance.Level > bestPotionFound.Level then
                    bestPotionFound = potionInstance
                end
            end
        end

        -- If we found a potion and have at least one, use it.
        if bestPotionFound and bestPotionFound.Amount > 0 then
            print("-> Best found: '" .. bestPotionFound.Name .. "' (Level " .. bestPotionFound.Level .. "). You have " .. bestPotionFound.Amount .. ".")
            print("--> Attempting to use 1...")
            
            -- ## THE FIX IS HERE ##
            -- We are now sending '1' as the amount to use, not 'bestPotionFound.Amount'.
            -- This prevents the server from rejecting the request.
            local success, err = pcall(function()
                RemoteEvent:FireServer("UsePotion", bestPotionFound.Name, bestPotionFound.Level, 1)
            end)

            if success then
                print("--> SUCCESS: Fired 'UsePotion' event successfully.")
            else
                warn("--> ERROR: Firing 'UsePotion' event failed: " .. tostring(err))
            end
            task.wait(0.5) -- Wait for the server to process before trying the next potion
        else
            print("-> No potions of type '"..potionNameToFind.."' found in your inventory.")
        end
    end
end


-- Helper function to use all Golden Orbs
local function useAllGoldenOrbs()
    print("Attempting to use all Golden Orbs...")
    local orbCount = (LocalData:Get().Powerups or {})["Golden Orb"] or 0
    if orbCount > 0 then
        print("-> Found " .. orbCount .. " Golden Orbs. Using all...")
        for i = 1, orbCount do
            RemoteEvent:FireServer("UseGoldenOrb")
            task.wait(0.2)
        end
    end
end

-- Helper function to collect nearby resources
local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    local collectedCount = 0
    for _, child in ipairs(renderedFolder:GetChildren()) do
        -- Ignore models that contain "Egg" in their name
        if child:IsA("Model") and not string.match(child.Name, "Egg") and child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                pcall(function()
                    collectRemote:FireServer(item.Name)
                    item:Destroy()
                    collectedCount = collectedCount + 1
                end)
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
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local originalCFrame = rootPart.CFrame
        for _, islandModel in ipairs(Workspace.Worlds["The Overworld"].Islands:GetChildren()) do
            local hitbox = islandModel:FindFirstChild("UnlockHitbox", true)
            if hitbox then rootPart.CFrame = hitbox.CFrame; task.wait(1.0) end
        end
        rootPart.CFrame = originalCFrame
    end
    print("[STEP 0] Island unlocking complete.")
    task.wait(2)

    -- STEP 1: REDEEM ALL CODES
    print("[STEP 1] Redeeming all available codes...")
    for codeName, _ in pairs(CodesModule) do
        pcall(function() RemoteFunction:InvokeServer("RedeemCode", codeName) end)
        task.wait(0.2)
    end
    print("[STEP 1] Code redemption complete.")
    task.wait(2)

    -- STEP 2 & 3: CONSTANT BUBBLE & SELL (BACKGROUND TASKS)
    print("[STEP 2 & 3] Starting background bubble/sell process...")
    task.spawn(function() while true do pcall(function() RemoteEvent:FireServer("BlowBubble") end); task.wait(0.1) end end)
    task.spawn(function() while true do pcall(function() RemoteEvent:FireServer("SellBubble") end); task.wait(0.1) end end)

    -- STEP 4: USE POTIONS & ORBS, THEN HATCH STARTER PETS
    print("[STEP 4] Using starting items...")
    useBestPotionsFromList(StarterRoutineConfig.USE_POTIONS_ON_START)
    useAllGoldenOrbs()

    print("Moving to Iceshard Egg to hatch starter pets...")
    performMovement(Vector3.new(-11, 9, -51))
    
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
            
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.05);
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait(0.05);
            
            collectNearbyPickups()
            task.wait(0.5)
        end
    end)

    -- STEP 6: WAIT FOR RESOURCES TO BUILD
    print("[STEP 6] Farming has started. Waiting 3 minutes to build resources before upgrading mastery...")
    task.wait(180)

    -- STEP 7: MASTERY UPGRADE LOOP
    print("[STEP 7] Starting mastery upgrade loop.")
    local masteryGoalsMet = false
    while not masteryGoalsMet do
        masteryGoalsMet = true
        local canAffordAnyUpgrade = false

        for pathName, targetLevel in pairs(StarterRoutineConfig.TargetLevels) do
            local currentLevel = (LocalData:Get().MasteryLevels or {})[pathName] or 0
            if currentLevel < targetLevel then
                masteryGoalsMet = false
                local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                if nextLevelData and getCurrency(nextLevelData.Cost.Currency) >= nextLevelData.Cost.Amount then
                    print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. (currentLevel + 1))
                    RemoteEvent:FireServer("UpgradeMastery", pathName)
                    canAffordAnyUpgrade = true
                    task.wait(1.5)
                    break
                end
            end
        end

        if not canAffordAnyUpgrade and not masteryGoalsMet then
            print("Cannot afford next mastery upgrade. Farming continues in background...")
            task.wait(10)
        end
    end

    print("[STEP 8] All mastery goals have been met!")

    -- [RESTORED] STEP 9: FINAL CHECK FOR WORLD 2
    print("[STEP 9] Final check for World 2 requirements...")
    while getCurrency("Coins") < StarterRoutineConfig.MIN_COINS_FOR_WORLD_2 do
        print("Coins still below 10 Billion. Farming continues in background...")
        task.wait(20) -- Wait 20 seconds before checking coin amount again
    end

    farmingActive = false
    print("--- STARTER ROUTINE COMPLETE! You have reached 10B coins and are ready for World 2. ---")
end)
