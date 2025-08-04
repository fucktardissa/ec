--[[
    ================================================================
    -- ## ONE-CLICK STARTER ROUTINE SCRIPT ##
    ================================================================
    --
    -- DESCRIPTION:
    -- This script automates the entire early-game progression.
    -- It is designed to be run once on a new account to quickly
    -- unlock islands, redeem codes, upgrade essential masteries,
    -- and prepare the player for World 2.
    --
    -- HOW IT WORKS:
    -- 1. Unlocks all islands and redeems all codes.
    -- 2. Starts bubbling and selling in the background continuously.
    -- 3. Hatches Iceshard Eggs for 30 seconds to get starter pets.
    -- 4. Enters a primary loop to farm currency (Coins/Gems) and
    --    upgrade masteries to the levels defined in the config.
    -- 5. Once mastery goals are met, it will begin farming the
    --    event area for Festival Coins.
    -- 6. The script completes when all goals are met.
    --
    -- FAST ROUTINE CONCEPT:
    -- A future "Fast Routine" could be implemented by creating a
    -- separate config that ONLY sets a target for Pet Mastery
    -- (e.g., level 20) and sets all other masteries to 0. The
    -- script would then only focus on that single goal for a
    -- quicker, more focused progression boost.
    --
]]

--[[
    ============================================================
    -- ## STARTER ROUTINE CONFIGURATION ##
    -- Modify these values to change the goals of the routine.
    ============================================================
]]
local StarterRoutineConfig = {
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

    -- ## Advanced Settings ##
    -- If true, the script will use your best potions right before it thinks
    -- you can afford your first Rainbow Egg to maximize pet chances. This only
    -- happens ONCE.
    USE_POTIONS_ON_FIRST_RAINBOW_EGG = true,
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Setup: Services, Modules, and Helper Functions ##
-- (These are consolidated from the master script for this routine)
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

-- Helper function for movement
local function performMovement(targetPosition)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    if not (humanoid and humanoidRootPart) then return end
    local originalPlatformStand = humanoid.PlatformStand
    humanoid.PlatformStand = true
    local moveTween = TweenService:Create(humanoidRootPart, TweenInfo.new(2, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)})
    moveTween:Play()
    moveTween.Completed:Wait()
    humanoid.PlatformStand = originalPlatformStand
end

-- Helper function to use best COIN potions
local function useBestCoinPotions()
    print("Attempting to use all best COIN potions...")
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return end
    local bestCoinPotion = nil
    for _, potionData in pairs(playerData.Potions) do
        if potionData.Name == "Coins" then
            if not bestCoinPotion or potionData.Level > bestCoinPotion.Level then
                bestCoinPotion = potionData
            end
        end
    end
    if bestCoinPotion and bestCoinPotion.Amount > 0 then
        print("-> Using " .. bestCoinPotion.Amount .. "x '" .. bestCoinPotion.Name .. "' (Level " .. bestCoinPotion.Level .. ")")
        RemoteEvent:FireServer("UsePotion", bestCoinPotion.Name, bestCoinPotion.Level, bestCoinPotion.Amount)
        task.wait(1)
    else
        print("-> No coin potions found.")
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
    local allIslandNames = { "Floating Island", "Outer Space", "Twilight", "The Void", "Zen" }
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local originalCFrame = rootPart.CFrame
    for _, islandModel in ipairs(Workspace.Worlds["The Overworld"].Islands:GetChildren()) do
        local hitbox = islandModel:FindFirstChild("UnlockHitbox", true)
        if hitbox and table.find(allIslandNames, islandModel.Name) then
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
    task.spawn(function() -- Bubbler
        while true do
            pcall(function() RemoteEvent:FireServer("BlowBubble") end)
            task.wait(0.1)
        end
    end)
    task.spawn(function() -- Seller
        while true do
            pcall(function() RemoteEvent:FireServer("SellBubble") end)
            task.wait(0.1)
        end
    end)

    -- STEP 4: HATCH STARTER PETS (ICESHARD EGG)
    print("[STEP 4] Moving to Iceshard Egg to hatch starter pets...")
    local iceshardEggPosition = Vector3.new(-117.06, 10.11, 7.74)
    performMovement(iceshardEggPosition)
    
    print("Hatching for 30 seconds...")
    local hatchEndTime = tick() + 30
    while tick() < hatchEndTime do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait();
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait();
    end
    
    print("Equipping best pets...")
    RemoteEvent:FireServer("EquipBestPets")
    print("[STEP 4] Initial hatching complete.")
    task.wait(2)

    -- STEP 5, 6, 8: CORE FARMING & MASTERY LOOP
    print("[STEP 5] Starting core mastery and farming loop.")
    print("Using all available Golden Orbs...")
    pcall(function() RemoteEvent:FireServer("UseGoldenOrb") end) -- This will likely need to be looped based on orb count
    
    useBestCoinPotions()
    
    print("Waiting 3 minutes before starting mastery upgrades to build resources...")
    task.wait(180)

    local masteryGoalsMet = false
    local eventAreaUnlocked = false
    local rainbowEggPosition = Vector3.new(-134.49, 10.11, -52.36)

    while not masteryGoalsMet do
        -- Check and Engage Rainbow Rift
        local riftInstance = isRiftValid("rainbow-egg-rift")
        if riftInstance then
            print("Rainbow Egg Rift detected! Engaging.")
            engageRift(riftInstance)
            performMovement(rainbowEggPosition) -- Return to egg after rift
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
            print("Cannot afford next mastery upgrade. Farming at Zen...")
            local zenFarmingPosition = Vector3.new(-35, 15973, 45) -- Near Zen chests
            performMovement(zenFarmingPosition)

            -- Move to Rainbow Egg to hatch while farming
            print("Moving to Rainbow Egg to hatch while farming coins/gems...")
            performMovement(rainbowEggPosition)

            -- Check for one-time potion use before hatching
            if StarterRoutineConfig.USE_POTIONS_ON_FIRST_RAINBOW_EGG and getCurrency("Coins") >= 1500000 then
                print("Coin threshold for Rainbow Egg met. Using best potions ONCE.")
                -- This should be expanded to use Lucky, Mythic, etc.
                useBestCoinPotions() -- Re-using coin potions as an example
                StarterRoutineConfig.USE_POTIONS_ON_FIRST_RAINBOW_EGG = false -- IMPORTANT: Prevents re-use
            end
            
            -- Hatch one egg
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait();
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait();
        end
        task.wait(1) -- General delay for the loop
    end

    print("[STEP 8] All mastery goals have been met!")

    -- STEP 10: FARM FESTIVAL COINS
    if eventAreaUnlocked then
        print("[STEP 10] Moving to farm Festival Coins...")
        local festivalFarmingPosition = Vector3.new(206, 22, 183) -- Position in event area
        performMovement(festivalFarmingPosition)
        -- Add a loop here to farm for a specific duration or until a coin goal
        print("Now in position to farm Festival Coins. Routine will end here for now.")
    end

    -- STEP 11: FINAL CHECK FOR WORLD 2
    print("[STEP 11] Final check for World 2 requirements...")
    while getCurrency("Coins") < StarterRoutineConfig.MIN_COINS_FOR_WORLD_2 do
        print("Coins still below 10 Billion. Returning to Zen to farm...")
        local zenFarmingPosition = Vector3.new(-35, 15973, 45)
        performMovement(zenFarmingPosition)
        task.wait(60) -- Farm for 1 minute before re-checking
    end

    print("--- STARTER ROUTINE COMPLETE! You are ready for World 2. ---")
end)
