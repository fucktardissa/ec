-- Master Auto-Farm & Hatching Script (v5 - Simplified)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoFarm = true,

    -- Set the minimum amount for each currency.
    MIN_FESTIVAL_COINS = "30m",
    MIN_TICKETS = "1b",
    MIN_GEMS = "1m",
    MIN_COINS = "10b",

    -- ## Optional Multitasking Actions ##
    HatchEggWhileFarmingFestivalCoins = true,
    HatchEggWhileFarmingGemsAndCoins = true,
    HatchEggWhileFarmingTickets = true,
    -- ## UPDATED ##: Simplified to a single toggle for Hyper Darts.
    PlayHyperDartsWhileFarmingTickets = true,
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Player Info ##
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

-- ## Helper Functions ##
local function parseCurrency(s)
    local num, suffix = tostring(s):match("([%d.]+)([mbk]?)")
    num = tonumber(num) or 0
    local mult = {b = 1e9, m = 1e6, k = 1e3}
    return num * (mult[suffix:lower()] or 1)
end

local function getCurrency(currencyType)
    local playerData = LocalData:Get()
    return playerData and playerData[currencyType] or 0
end

local function tweenTo(position)
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local dist = (rootPart.Position - position).Magnitude
    local time = dist / 150
    local tween = TweenService:Create(rootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) })
    tween:Play()
    tween.Completed:Wait()
end

local function openRegularEgg()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    for _, child in ipairs(renderedFolder:GetChildren()) do
        if child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                if string.find(item.Name, "-") then
                    collectRemote:FireServer(item.Name)
                    item:Destroy()
                    task.wait()
                end
            end
        end
    end
end

-- ## UPDATED ##: Simplified to one specific minigame function.
local function playHyperDarts()
    RemoteEvent:FireServer("SkipMinigameCooldown", "Hyper Darts")
    RemoteEvent:FireServer("StartMinigame", "Hyper Darts", "Insane")
    RemoteEvent:FireServer("FinishMinigame")
end


-- ## Main Automation Logic ##
print("Master Auto-Farm script started. To stop, run: getgenv().Config.AutoFarm = false")

while getgenv().Config.AutoFarm do
    local currentTask = "Idle"
    local minFestival = parseCurrency(getgenv().Config.MIN_FESTIVAL_COINS)
    local minTickets = parseCurrency(getgenv().Config.MIN_TICKETS)
    local minGems = parseCurrency(getgenv().Config.MIN_GEMS)
    local minCoins = parseCurrency(getgenv().Config.MIN_COINS)

    if getCurrency("FestivalCoins") < minFestival then
        currentTask = "Festival"
    elseif getCurrency("Tickets") < minTickets then
        currentTask = "Tickets"
    elseif getCurrency("Gems") < minGems then
        currentTask = "Gems"
    elseif getCurrency("Coins") < minCoins then
        currentTask = "Coins"
    end

    if currentTask == "Festival" then
        print("Task: Farming Festival Coins.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
        task.wait(3)
        tweenTo(workspace.Worlds["The Overworld"].Egg.Position)
        local mainCondition = function() return getgenv().Config.AutoFarm and getCurrency("FestivalCoins") < minFestival end
        task.spawn(function()
            while mainCondition() do collectNearbyPickups() task.wait(5) end
        end)
        if getgenv().Config.HatchEggWhileFarmingFestivalCoins then
            task.spawn(function()
                while mainCondition() do openRegularEgg() end
            end)
        end
        repeat task.wait(1) until not mainCondition()

    elseif currentTask == "Tickets" then
        print("Task: Farming Tickets.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn")
        task.wait(3)
        local mainCondition = function() return getgenv().Config.AutoFarm and getCurrency("Tickets") < minTickets end
        if getgenv().Config.HatchEggWhileFarmingTickets then
            tweenTo(workspace.Worlds["Minigame Paradise"].Islands["Hyperwave Island"].Island.Egg.Position)
            task.spawn(function()
                while mainCondition() do openRegularEgg() end
            end)
        end
        if getgenv().Config.PlayHyperDartsWhileFarmingTickets then
            task.spawn(function()
                while mainCondition() do playHyperDarts() task.wait(2) end
            end)
        end
        while mainCondition() do
            collectNearbyPickups()
            task.wait(5)
        end

    elseif currentTask == "Gems" or currentTask == "Coins" then
        print("Task: Farming Gems and Coins.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
        task.wait(3)
        local mainCondition = function() return getgenv().Config.AutoFarm and (getCurrency("Gems") < minGems or getCurrency("Coins") < minCoins) end
        if getgenv().Config.HatchEggWhileFarmingGemsAndCoins then
            tweenTo(workspace.Worlds["The Overworld"].Islands.Zen.Island.EggPlatformSpawn.Position)
            task.spawn(function()
                while mainCondition() do openRegularEgg() end
            end)
        end
        while mainCondition() do
            collectNearbyPickups()
            task.wait(5)
        end
        
    else
        print("All currency minimums met. Idling...")
        task.wait(10)
    end
end

print("Master Auto-Farm script has stopped.")
