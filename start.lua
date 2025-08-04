--[[
    ================================================================================
    -- ## World 1 Full Automation Script ##
    -- This script automates the entire progression through the first world,
    -- following a specific, efficient guide to prepare for World 2.
    -- NOTE: As requested, this version has automatic pet deletion REMOVED
    -- to allow new players to build their initial collection.
    ================================================================================
]]

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local World1_Routine_Config = {
    -- ## Primary Goals ##
    -- The script will run until both of these goals are met.
    World2_Coin_Requirement = 10e9, -- 10 Billion Coins
    EventArea_Gem_Requirement = 150000, -- 150k Gems

    -- ## Starter Mastery Targets ##
    -- The script will upgrade masteries until these levels are reached.
    MasteryTargets = {
        Pets = 15,
        Buffs = 18,
        Shops = 10,
        Minigames = 0, -- Set to 0 to ignore
        Rifts = 0      -- Set to 0 to ignore
    },

    -- ## One-Time Boost Settings ##
    InitialHatchDuration = 30, -- Seconds to hatch Iceshard eggs at the start
    USE_POTIONS_FOR_RAINBOW_EGG = true, -- Use best coin potions before hatching the first Rainbow Egg
    RainbowEggCost = 1.5e6, -- 1.5 Million Coins

    -- ## General Settings ##
    -- A 3-minute (180s) delay before starting mastery upgrades to allow for initial hatching.
    InitialMasteryDelay = 180,
}
getgenv().World1_Routine_Config = World1_Routine_Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MasteryData = require(ReplicatedStorage.Shared.Data.Mastery)

-- ## State Variables ##
local eventAreaUnlocked = false
local usedRainbowPotions = false
local world2Unlocked = false

-- ## Helper Functions (Combined from all scripts) ##
local function parseCurrency(s) local num, suffix = tostring(s):match("([%d.]+)([mbk]?)"); num = tonumber(num) or 0; local mult = {b=1e9, m=1e6, k=1e3}; return num * (mult[suffix:lower()] or 1) end
local function getCurrency(currencyType) local playerData = LocalData:Get(); return playerData and playerData[currencyType] or 0 end
local function tweenTo(position) local character = LocalPlayer.Character; local rootPart = character and character:FindFirstChild("HumanoidRootPart"); if not rootPart then return end; local dist = (rootPart.Position - position).Magnitude; local time = dist / 40; local tween = TweenService:Create(rootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) }); tween:Play(); tween.Completed:Wait() end
local function openKey(key) VirtualInputManager:SendKeyEvent(true, key, false, game); task.wait(); VirtualInputManager:SendKeyEvent(false, key, false, game); task.wait() end

local function useBestCoinPotions()
    print("Using best available Coin potions...")
    local playerData, bestCoinPotion = LocalData:Get(), nil
    if not (playerData and playerData.Potions) then return end
    for _, potionData in pairs(playerData.Potions) do
        if potionData.Name == "Coins" then
            if not bestCoinPotion or potionData.Level > bestCoinPotion.Level then
                bestCoinPotion = potionData
            end
        end
    end
    if bestCoinPotion then
        print("-> Using " .. bestCoinPotion.Amount .. "x 'Coins' (Level " .. bestCoinPotion.Level .. ")")
        RemoteEvent:FireServer("UsePotion", bestCoinPotion.Name, bestCoinPotion.Level, bestCoinPotion.Amount)
        task.wait(1)
    end
end

local function useGoldenOrbs()
    local orbCount = LocalData:Get().GoldenOrbs or 0
    if orbCount > 0 then
        print("Using " .. orbCount .. " Golden Orbs...")
        for i = 1, orbCount do RemoteEvent:FireServer("UseGoldenOrb"); task.wait(0.2) end
    end
end

local function isRiftValid(riftName)
    local riftFolder = workspace.Rendered:FindFirstChild("Rifts")
    if not riftFolder then return nil end
    for _, riftInstance in ipairs(riftFolder:GetChildren()) do
        if string.lower(riftInstance.Name) == string.lower(riftName) then
            return riftInstance
        end
    end
    return nil
end

local function getRiftMultiplier(riftInstance)
    local display = riftInstance:FindFirstChild("Display")
    if not display then return 0 end
    local gui = display:FindFirstChildOfClass("SurfaceGui")
    if not gui then return 0 end
    local luckLabel = gui:FindFirstChild("Icon", true) and gui.Icon:FindFirstChild("Luck")
    if luckLabel and luckLabel:IsA("TextLabel") then return tonumber(string.match(luckLabel.Text, "%d+")) or 0 end
    return 0
end

local function EngageRift(riftInstance)
    print("Engaging target rift: " .. riftInstance.Name)
    local targetPosition = riftInstance.Display.Position + Vector3.new(0, 4, 0)
    -- Simplified teleport logic for World 1
    RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
    task.wait(5)
    tweenTo(targetPosition)
    task.wait(1)
    print("Hatching rift...")
    while isRiftValid(riftInstance.Name) do openKey(Enum.KeyCode.R); task.wait(0.5) end
    print("Rift is gone.")
end

local function farmSpecificCurrency(currency)
    local farmLocation = "Zen" -- Default to Zen for Coins/Gems
    local hatchPos = Vector3.new(-35, 15973, 45)
    
    if currency == "FestivalCoins" then
        farmLocation = "Festival"
        hatchPos = Vector3.new(243, 13, 229)
    end
    
    print("Farming for: " .. currency .. " in zone: " .. farmLocation)
    -- Simplified teleport logic for World 1
    if farmLocation == "Zen" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn"); task.wait(3)
    else
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn"); task.wait(3)
    end
    
    -- In World 1, farming is mostly passive or from rifts, so we focus on hatching.
    tweenTo(hatchPos)
    local hatchEndTime = tick() + 15
    while tick() < hatchEndTime do openKey(Enum.KeyCode.E) end
end


-- ## Main Execution Thread ##
task.spawn(function()
    local cfg = getgenv().World1_Routine_Config
    print("--- World 1 Automation Sequence Started ---")

    -- ===== PHASE 1: INITIAL SETUP & BACKGROUND TASKS =====
    -- Step 1 & 2 & 3: Redeem Codes, Start Bubbling/Selling
    pcall(function() -- Wrap in pcall in case modules are missing
        -- Redeem all codes
        local CodesModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Codes"))
        for codeName, _ in pairs(CodesModule) do RemoteFunction:InvokeServer("RedeemCode", codeName); task.wait(0.2) end
        print("Step 1: Code redemption complete.")
        
        -- Start continuous bubbling & selling
        task.spawn(function() while true do RemoteEvent:FireServer("BlowBubble"); task.wait(1) end end)
        task.spawn(function() while true do RemoteEvent:FireServer("SellBubble"); task.wait(1) end end)
        print("Steps 2 & 3: Background bubbling/selling started.")
        -- NOTE: Advanced pet deletion is intentionally excluded from this starter routine.
    end)


    -- ===== PHASE 2: IMMEDIATE BOOST =====
    -- Step 4: Hatch initial pets
    print("Step 4: Hatching initial Iceshard Eggs for " .. cfg.InitialHatchDuration .. "s...")
    tweenTo(Vector3.new(-11, 9, -51))
    local hatchEndTime = tick() + cfg.InitialHatchDuration
    while tick() < hatchEndTime do openKey(Enum.KeyCode.E) end
    RemoteEvent:FireServer("EquipBestPets")
    print("Initial pets hatched and equipped.")

    -- Step 6: Use starting potions and orbs
    print("Step 6: Using initial Coin Potions and Golden Orbs.")
    useBestCoinPotions()
    useGoldenOrbs()
    task.wait(2)
    
    -- Wait before starting mastery
    print("Waiting " .. cfg.InitialMasteryDelay .. " seconds before starting mastery upgrades...")
    task.wait(cfg.InitialMasteryDelay)

    -- ===== PHASE 3: MAIN PROGRESSION LOOP =====
    while not world2Unlocked do
        local playerData = LocalData:Get()
        local currentCoins = playerData.Coins or 0
        local currentGems = playerData.Gems or 0
        local actionTaken = false

        -- Check for final goal completion
        if currentCoins >= cfg.World2_Coin_Requirement then
            print("SUCCESS! Reached " .. cfg.World2_Coin_Requirement .. " coins. Ready for World 2!")
            world2Unlocked = true
            break
        end

        -- Step 9: Check for Event Area unlock
        if not eventAreaUnlocked and currentGems >= cfg.EventArea_Gem_Requirement then
            print("Step 9: Reached 150k gems! Unlocking event area...")
            -- RemoteEvent:FireServer("UnlockSpecialEventArea") -- << PLACEHOLDER for the actual event remote
            print("EVENT AREA UNLOCKED (Placeholder). You can now farm Festival Coins.")
            eventAreaUnlocked = true
            actionTaken = true
        end

        -- Step 8.5: Look for Rainbow Egg Rifts
        if not actionTaken then
            local rainbowRift = isRiftValid("rainbow-egg-egg")
            if rainbowRift and getRiftMultiplier(rainbowRift) > 1 then
                print("Step 8.5: High-value Rainbow Rift found! Engaging...")
                EngageRift(rainbowRift)
                actionTaken = true
            end
        end
        
        -- Step 8 (Part 1): Check for one-time Rainbow Egg potion boost
        if not actionTaken and not usedRainbowPotions and cfg.USE_POTIONS_FOR_RAINBOW_EGG and currentCoins >= cfg.RainbowEggCost then
            print("Step 8: Reached 1.5M coins. Using potions for Rainbow Egg...")
            useBestCoinPotions()
            usedRainbowPotions = true
            -- The farming logic below will handle the hatching
        end

        -- Step 5 & 8: Main Mastery & Farming Logic
        if not actionTaken then
            local currencyNeeded = nil
            local allMasteryGoalsMet = true
            -- Upgrade Mastery if possible
            for pathName, targetLevel in pairs(cfg.MasteryTargets) do
                local currentLevel = playerData.MasteryLevels[pathName] or 0
                if currentLevel < targetLevel then
                    allMasteryGoalsMet = false
                    local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                    if nextLevelData and nextLevelData.Cost then
                        if getCurrency(nextLevelData.Cost.Currency) >= nextLevelData.Cost.Amount then
                            print("Upgrading '" .. pathName .. "' to level " .. (currentLevel + 1))
                            RemoteEvent:FireServer("UpgradeMastery", pathName)
                            actionTaken = true
                            task.wait(1.5)
                            break -- Exit after one upgrade to re-evaluate
                        elseif not currencyNeeded then
                            currencyNeeded = nextLevelData.Cost.Currency
                        end
                    end
                end
            end

            -- Farm for needed currency if no upgrade was made
            if not actionTaken and currencyNeeded then
                farmSpecificCurrency(currencyNeeded)
                actionTaken = true
            elseif not actionTaken and allMasteryGoalsMet then
                print("All mastery goals met. Farming Coins for World 2 unlock...")
                farmSpecificCurrency("Coins") -- Default to coin farming
                actionTaken = true
            end
        end

        task.wait(5) -- A small delay between each loop iteration
    end

    print("--- World 1 Automation Sequence Finished! ---")
end)
