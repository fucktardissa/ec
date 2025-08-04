-- Master Auto-Farm, Mastery & Equip Best Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Master toggle for the entire script.
    MasterScriptActive = true,

    -- ## Auto Mastery Settings ##
    AutoMastery = true,
    FARM_CURRENCY_IF_CANT_UPGRADE = true,
    TargetLevels = { Pets = 15, Buffs = 18, Shops = 10, Minigames = 0, Rifts = 0 },
    
    -- ## Auto Farm Settings ##
    MIN_FESTIVAL_COINS = "0",
    MIN_TICKETS = "0",
    MIN_GEMS = "50m",
    MIN_COINS = "10b",
    
    -- ## Auto Equip Best Pets Settings ##
    AutoEquipBest = true,
    EquipBestInterval = 5, -- Time in seconds between equipping best pets

    -- ## Multitasking Settings ##
    HatchWhileFarmingFestivalCoins = true,
    HatchWhileFarmingGemsAndCoins = true,
    HatchWhileFarmingTickets = false,
    PlayMinigameWhileFarmingTickets = true,
    HatchDuration = 15.0
    ContinuousCollectionInterval = 2.5 -- Time in seconds between collecting nearby items
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
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MasteryData = require(ReplicatedStorage.Shared.Data.Mastery)

-- ## Helper Functions ##
local function parseCurrency(s) local num, suffix = tostring(s):match("([%d.]+)([mbk]?)"); num = tonumber(num) or 0; local mult = {b=1e9, m=1e6, k=1e3}; return num * (mult[suffix:lower()] or 1) end
local function getCurrency(currencyType) local playerData = LocalData:Get(); return playerData and playerData[currencyType] or 0 end
local function tweenTo(position) local character = LocalPlayer.Character; local rootPart = character and character:FindFirstChild("HumanoidRootPart"); if not rootPart then return end; local dist = (rootPart.Position - position).Magnitude; local time = dist / 40; local tween = TweenService:Create(rootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) }); tween:Play(); tween.Completed:Wait() end
local function openRegularEgg() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game); task.wait() end

-- MODIFIED: Now checks for "egg" in the item name before destroying it.
local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    local collectedCount = 0
    for _, child in ipairs(renderedFolder:GetChildren()) do
        if child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                -- Check if the item name contains "egg" (case-insensitive)
                if not string.find(item.Name:lower(), "egg") then
                    collectRemote:FireServer(item.Name)
                    item:Destroy()
                    collectedCount = collectedCount + 1
                    task.wait()
                end
            end
        end
    end
    if collectedCount > 0 then
        print("Collected " .. collectedCount .. " nearby pickups.")
    end
end

local function playMinigame(name) print("-> Multitasking: Starting Minigame: " .. name); RemoteEvent:FireServer("SkipMinigameCooldown", name); RemoteEvent:FireServer("StartMinigame", name, "Insane"); RemoteEvent:FireServer("FinishMinigame"); print("-> Minigame Finished.") end

local function farmSpecificCurrency(currency)
    print("Farming for: " .. currency)
    if currency == "Coins" or currency == "Gems" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn"); task.wait(3)
        if getgenv().Config.HatchWhileFarmingGemsAndCoins then
            tweenTo(Vector3.new(-35, 15973, 45))
            local endTime = tick() + getgenv().Config.HatchDuration; while tick() < endTime do openRegularEgg() end
        end
        -- REMOVED collectNearbyPickups()
    elseif currency == "Tickets" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn"); task.wait(3)
        if getgenv().Config.HatchWhileFarmingTickets then
            tweenTo(workspace.Worlds["Minigame Paradise"].Islands["Hyperwave Island"].Island.Egg.Position)
            local endTime = tick() + getgenv().Config.HatchDuration; while tick() < endTime do openRegularEgg() end
        end
        if getgenv().Config.PlayMinigameWhileFarmingTickets then playMinigame("Hyper Darts") end
        -- REMOVED collectNearbyPickups()
    elseif currency == "FestivalCoins" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn"); task.wait(3)
        if getgenv().Config.HatchWhileFarmingFestivalCoins then tweenTo(Vector3.new(243, 13, 229)); local endTime = tick() + getgenv().Config.HatchDuration; while tick() < endTime do openRegularEgg() end
        else tweenTo(Vector3.new(206, 22, 183)) end
        -- REMOVED collectNearbyPickups()
    end
end

-- ## Main Automation Logic ##

-- NEW: Continuous background collection
task.spawn(function()
    while getgenv().Config.MasterScriptActive do
        collectNearbyPickups()
        task.wait(getgenv().Config.ContinuousCollectionInterval)
    end
end)

-- Main Automation Loop
task.spawn(function()
    print("Master Script started.")
    local lastEquipBestTime = 0

    while getgenv().Config.MasterScriptActive do
        local cfg = getgenv().Config
        local actionTaken = false
        
        -- ## PRIORITY 1: AUTO MASTERY ##
        if cfg.AutoMastery then
            local playerData = LocalData:Get()
            local currentMasteryLevels = playerData.MasteryLevels or {}
            local masteryPaths = {"Buffs", "Pets", "Shops", "Minigames", "Rifts"}
            local currencyNeeded = nil
            local allGoalsMet = true

            for _, pathName in ipairs(masteryPaths) do
                local currentLevel = currentMasteryLevels[pathName] or 0
                local targetLevel = cfg.TargetLevels[pathName] or 0
                if currentLevel < targetLevel then
                    allGoalsMet = false
                    local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                    if nextLevelData and nextLevelData.Cost then
                        if getCurrency(nextLevelData.Cost.Currency) >= nextLevelData.Cost.Amount then
                            print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. (currentLevel + 1))
                            RemoteEvent:FireServer("UpgradeMastery", pathName)
                            actionTaken = true
                            task.wait(1.5)
                            break
                        elseif not currencyNeeded then
                            currencyNeeded = nextLevelData.Cost.Currency
                        end
                    end
                end
            end
            if allGoalsMet then print("All mastery targets met. Disabling AutoMastery.") cfg.AutoMastery = false end
        end

        -- ## PRIORITY 2: FARM FOR MASTERY OR CURRENCY GOALS ##
        if not actionTaken and cfg.FARM_CURRENCY_IF_CANT_UPGRADE and currencyNeeded then
            farmSpecificCurrency(currencyNeeded)
            actionTaken = true
        else -- Fallback to general currency farming if no specific mastery need
            local minFestival = parseCurrency(cfg.MIN_FESTIVAL_COINS)
            local minTickets = parseCurrency(cfg.MIN_TICKETS)
            local minGems = parseCurrency(cfg.MIN_GEMS)
            local minCoins = parseCurrency(cfg.MIN_COINS)

            if getCurrency("FestivalCoins") < minFestival then farmSpecificCurrency("FestivalCoins"); actionTaken = true
            elseif getCurrency("Tickets") < minTickets then farmSpecific...
