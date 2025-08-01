-- Master Auto-Farm & Hatching Script (Multitasking v2)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoFarm = true,

    -- Set the minimum amount for each currency.
    MIN_FESTIVAL_COINS = "30m",
    MIN_TICKETS = "100000b",
    MIN_GEMS = "1m",
    MIN_COINS = "10b",

    -- ## Optional Multitasking Actions ##
    -- Set these to true to perform a second action WHILE farming at a location.
    HatchEggWhileFarmingFestivalCoins = true, -- Hatches the Festival Egg while farming at Spawn
    HatchEggWhileFarmingGemsAndCoins = true, -- Hatches the Rainbow Egg while farming at Zen Island
    HatchEggWhileFarmingTickets = true,      -- Hatches the Neon Egg while farming at Hyperwave Island
    PlayMinigameWhileFarmingTickets = true,  -- Plays "Hyper Darts" while farming at Hyperwave Island
    
    HatchDuration = 15.0 -- Only used if a Hatch task is selected
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
                collectRemote:FireServer(item.Name)
                item:Destroy()
                task.wait()
            end
        end
    end
end

local function playMinigame(name)
    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    RemoteEvent:FireServer("StartMinigame", name, "Insane")
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

    -- 1. Decide which currency to prioritize
    if getCurrency("FestivalCoins") < minFestival then
        currentTask = "Festival"
    elseif getCurrency("Tickets") < minTickets then
        currentTask = "Tickets"
    elseif getCurrency("Gems") < minGems then
        currentTask = "Gems"
    elseif getCurrency("Coins") < minCoins then
        currentTask = "Coins"
    end

    -- 2. Execute the chosen task
    if currentTask == "Festival" then
        print("Task: Farming Festival Coins.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
        task.wait(3)
        -- The standing point will be the egg, as it's close enough to farm coins as well.
        tweenTo(workspace.Worlds["The Overworld"].Egg.Position)
        
        -- Start multitasking threads
        local farmingThread = task.spawn(function()
            while getgenv().Config.AutoFarm and getCurrency("FestivalCoins") < minFestival do
                collectNearbyPickups()
                task.wait(5)
            end
        end)
        
        if getgenv().Config.HatchEggWhileFarmingFestivalCoins then
            task.spawn(function()
                while getgenv().Config.AutoFarm and getCurrency("FestivalCoins") < minFestival do
                    openRegularEgg()
                end
            end)
        end
        
        -- Wait for the primary condition (currency goal) to be met
        repeat task.wait(1) until not (getgenv().Config.AutoFarm and getCurrency("FestivalCoins") < minFestival)


    elseif currentTask == "Tickets" then
        print("Task: Farming Tickets.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn")
        task.wait(3)
        
        -- Start multitasking threads
        local farmingThread = task.spawn(function()
            while getgenv().Config.AutoFarm and getCurrency("Tickets") < minTickets do
                collectNearbyPickups()
                task.wait(5)
            end
        end)
        
        if getgenv().Config.HatchEggWhileFarmingTickets then
            tweenTo(workspace.Worlds["Minigame Paradise"].Islands["Hyperwave Island"].Island.Egg.Position)
            task.spawn(function()
                while getgenv().Config.AutoFarm and getCurrency("Tickets") < minTickets do
                    openRegularEgg()
                end
            end)
        end
        
        if getgenv().Config.PlayMinigameWhileFarmingTickets then
            task.spawn(function()
                while getgenv().Config.AutoFarm and getCurrency("Tickets") < minTickets do
                    playMinigame("Hyper Darts")
                    task.wait(2) -- Cooldown for minigame
                end
            end)
        end
        
        repeat task.wait(1) until not (getgenv().Config.AutoFarm and getCurrency("Tickets") < minTickets)

    elseif currentTask == "Gems" or currentTask == "Coins" then
        print("Task: Farming Gems and Coins.")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
        task.wait(3)
        
        -- Start multitasking threads
        local farmingThread = task.spawn(function()
            while getgenv().Config.AutoFarm and (getCurrency("Gems") < minGems or getCurrency("Coins") < minCoins) do
                collectNearbyPickups()
                task.wait(5)
            end
        end)
        
        if getgenv().Config.HatchEggWhileFarmingGemsAndCoins then
            tweenTo(workspace.Worlds["The Overworld"].Islands.Zen.Island.EggPlatformSpawn.Position)
            task.spawn(function()
                while getgenv().Config.AutoFarm and (getCurrency("Gems") < minGems or getCurrency("Coins") < minCoins) do
                    openRegularEgg()
                end
            end)
        end
        
        repeat task.wait(1) until not (getgenv().Config.AutoFarm and (getCurrency("Gems") < minGems or getCurrency("Coins") < minCoins))
        
    else
        print("All currency minimums met. Idling...")
        task.wait(10) -- Long wait since nothing needs to be done
    end
end

print("Master Auto-Farm script has stopped.")
