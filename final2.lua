--[[
    ================================================================
    -- ## ONE-CLICK STARTER ROUTINE SCRIPT (REVISED) ##
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
    USE_POTIONS_ON_START = {"Coins", "Lucky", "Speed", "Infinity-Elixir"},

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
    
    local potionsToUse = {}
    -- First, find the highest level for each wanted potion type
    for _, potionData in pairs(playerData.Potions) do
        if table.find(potionTypes, potionData.Name) then
            if not potionsToUse[potionData.Name] or potionData.Level > potionsToUse[potionData.Name].Level then
                potionsToUse[potionData.Name] = potionData
            end
        end
    end
    -- Now, use the potions we found
    for name, potion in pairs(potionsToUse) do
        if potion.Amount > 0 then
            print("-> Using " .. potion.Amount .. "x '" .. potion.Name .. "' (Level " .. potion.Level .. ")")
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

-- Helper function to check if a rift is active
local function isRiftValid(riftName)
    local riftFolder = workspace.Rendered:FindFirstChild("Rifts")
    if not riftFolder then return nil end
    return riftFolder:FindFirstChild(riftName)
end

-- Helper function to engage a rift
local function engageRift(riftInstance)
    print("Engaging target rift: " .. riftInstance.Name)
    local targetPosition = riftInstance.Display.Position + Vector3.new(0, 4, 0)
    performMovement(targetPosition)
    task.wait(1)
    print("Hatching rift...")
    while riftInstance and riftInstance.Parent do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game); task.wait(0.1); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        task.wait(0.5)
    end
    print("Rift is gone.")
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
            print("Unlocking: " .. islandModel.Name)
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
    local iceshardEggPosition = Vector3.new(-11, 9, -51) -- Corrected coordinate
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

    -- STEP 5, 6, 8: CORE FARMING & MASTERY LOOP
    print("[STEP 5] Starting core mastery and farming loop.")
    print("Waiting 3 minutes before starting mastery upgrades to build resources...")
    task.wait(180)

    local masteryGoalsMet = false
    local eventAreaUnlocked = false
    local zenTeleportPath = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn"
    local zenFarmingPosition = Vector3.new(-36, 15973, 47) -- Corrected Rainbow Egg hatch spot in Zen

    while not masteryGoalsMet do
        -- Check and Engage Rainbow Rift
        local riftInstance = isRiftValid("rainbow-egg-rift")
        if riftInstance then
            print("Rainbow Egg Rift detected! Engaging.")
            engageRift(riftInstance)
        end

        -- Check if we can unlock the event area
        if not eventAreaUnlocked and getCurrency("Gems") >= StarterRoutineConfig.GEMS_FOR_EVENT_AREA then
            print("[STEP 9] Reached 150,000 gems! Unlocking event area...")
            -- !! USER ACTION REQUIRED !!
            -- The remote event to unlock the event area needs to be added below.
            -- Example: RemoteEvent:FireServer("UnlockSpecialEvent")
            print("Placeholder for Event Unlock Remote. Please replace.")
            eventAreaUnlocked = true
        end

        -- Mastery Upgrade Logic
        local playerData = LocalData:Get()
        local currentMasteryLevels = playerData.MasteryLevels or {}
        local canAffordUpgrade = false
        masteryGoalsMet = true -- Assume goals are met until a check fails

        for pathName, targetLevel in pairs(StarterRoutineConfig.TargetLevels) do
            local currentLevel = currentMasteryLevels[pathName] or 0
            if currentLevel < targetLevel then
                masteryGoalsMet = false -- A goal is not met
                local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                if nextLevelData and getCurrency(nextLevelData.Cost.Currency) >= nextLevelData.Cost.Amount then
                    print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. (currentLevel + 1))
                    RemoteEvent:FireServer("UpgradeMastery", pathName)
                    canAffordUpgrade = true
                    task.wait(1.5)
                    break -- Break to re-check priorities after an upgrade
                end
            end
        end

        -- Farming Logic
        if not canAffordUpgrade then
            -- Teleport to Zen if not already there
            if not isPlayerNear(zenFarmingPosition, 500) then
                print("Not near Zen. Teleporting to farm...")
                RemoteEvent:FireServer("Teleport", zenTeleportPath)
                task.wait(3) -- Wait for teleport to complete
            end
            
            -- Move to Rainbow Egg spot to hatch while farming
            performMovement(zenFarmingPosition)

            -- Hatch one egg
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.05);
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait(0.05);
        end
        task.wait(1) -- General delay for the loop
    end

    print("[STEP 8] All mastery goals have been met!")

    -- STEP 10: FARM FESTIVAL COINS
    if eventAreaUnlocked then
        print("[STEP 10] Moving to farm Festival Coins...")
        local festivalFarmingPosition = Vector3.new(206, 22, 183)
        performMovement(festivalFarmingPosition)
        print("Now in position to farm Festival Coins. Routine will end here for now.")
    end

    -- STEP 11: FINAL CHECK FOR WORLD 2
    print("[STEP 11] Final check for World 2 requirements...")
    if getCurrency("Coins") < StarterRoutineConfig.MIN_COINS_FOR_WORLD_2 then
        print("Coins still below 10 Billion. Returning to Zen to farm...")
        if not isPlayerNear(zenFarmingPosition, 500) then
            RemoteEvent:FireServer("Teleport", zenTeleportPath)
            task.wait(3)
        end
        performMovement(Vector3.new(-35, 15973, 45)) -- A spot near Zen chests
        print("Manual farming may be required to reach 10B coins.")
    end

    print("--- STARTER ROUTINE COMPLETE! You are ready for World 2. ---")
end)
