-- Standalone Auto Mastery Script (with Resource Checking & Auto-Farming)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Master toggle for the script. Set to false to stop.
    AutoMastery = true,
    
    -- If you can't afford an upgrade, should the script auto-farm the currency needed?
    FARM_CURRENCY_IF_CANT_UPGRADE = true,

    -- Set your desired target level for each mastery path.
    TargetLevels = {
        Pets = 15,
        Buffs = 15,
        Shops = 11,
        Minigames = 8,
        Rifts = 3
    },
    
    -- Delay in seconds between each successful upgrade call.
    ActionDelay = 0.5 
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
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MasteryData = require(ReplicatedStorage.Shared.Data.Mastery)
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

-- ## Helper Functions ##
local function getCurrency(currencyType)
    local playerData = LocalData:Get()
    return playerData and playerData[currencyType] or 0
end

local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    for _, child in ipairs(renderedFolder:GetChildren()) do
        if child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                collectRemote:FireServer(item.Name)
                item:Destroy()
                task.wait()
            end
        end
    end
    print("-> Collection cycle complete.")
end

local function farmCurrency(currencyType)
    print("Attempting to farm for: " .. currencyType)
    if currencyType == "Coins" or currencyType == "Gems" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
        task.wait(3)
        collectNearbyPickups()
    elseif currencyType == "Tickets" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn")
        task.wait(3)
        collectNearbyPickups()
    else
        warn("-> Don't know how to farm for '" .. currencyType .. "'. Waiting.")
        task.wait(10)
    end
end

-- ## Main Logic ##
task.spawn(function()
    print("--- Starting Auto Mastery script. ---")
    while getgenv().Config.AutoMastery do
        local playerData = LocalData:Get()
        local currentMasteryLevels = playerData.MasteryLevels or {}
        local masteryPaths = {"Buffs", "Pets", "Shops", "Minigames", "Rifts"}
        
        local upgradedSomething = false
        local canAffordAnUpgrade = false
        local firstNeededCurrency = nil
        local allGoalsMet = true

        for _, pathName in ipairs(masteryPaths) do
            local currentLevel = currentMasteryLevels[pathName] or 0
            local targetLevel = getgenv().Config.TargetLevels[pathName] or 0
            local maxLevel = #MasteryData.Upgrades[pathName].Levels
            local effectiveTarget = math.min(targetLevel, maxLevel)

            if currentLevel < effectiveTarget then
                allGoalsMet = false -- At least one goal is not met
                local nextLevelData = MasteryData.Upgrades[pathName].Levels[currentLevel + 1]
                if nextLevelData and nextLevelData.Cost then
                    local cost = nextLevelData.Cost.Amount
                    local currency = nextLevelData.Cost.Currency
                    if not firstNeededCurrency then firstNeededCurrency = currency end

                    if getCurrency(currency) >= cost then
                        canAffordAnUpgrade = true
                        print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. (currentLevel + 1))
                        RemoteEvent:FireServer("UpgradeMastery", pathName)
                        task.wait(getgenv().Config.ActionDelay)
                        upgradedSomething = true
                        break -- Exit loop to re-check levels from the top
                    end
                end
            end
        end

        if upgradedSomething then
            -- If we upgraded, loop again quickly to check for more affordable upgrades
            task.wait(2)
        elseif allGoalsMet then
            print("All mastery targets have been met! Stopping script.")
            getgenv().Config.AutoMastery = false
            break
        elseif getgenv().Config.FARM_CURRENCY_IF_CANT_UPGRADE and firstNeededCurrency then
            print("Cannot afford next upgrade. Farming for " .. firstNeededCurrency .. "...")
            farmCurrency(firstNeededCurrency)
            task.wait(5)
        else
            print("Cannot afford next upgrade and auto-farming is disabled. Waiting...")
            task.wait(15)
        end
    end
    print("--- Auto Mastery script has stopped. ---")
end)
