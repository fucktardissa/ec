-- Master Auto-Farm & Multitasking Scriptdhshsdgsdhsdh

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Master toggle for the script.
    AutoFarm = true,

    -- Set the minimum amount for each currency. The script will farm until these goals are met.
    MIN_FESTIVAL_COINS = "30m",
    MIN_TICKETS = "0",
    MIN_GEMS = "0",
    MIN_COINS = "0",

    -- ## Optional Multitasking Actions ##
    -- Set these to true to perform a second action WHILE farming at a location.
    HatchWhileFarmingFestivalCoins = true, -- Hatches the Festival Egg while farming at Spawn
    HatchWhileFarmingGemsAndCoins = true, -- Hatches the Rainbow Egg while farming at Zen Island
    HatchWhileFarmingTickets = false,      -- Hatches the Neon Egg while farming at Hyperwave Island
    PlayMinigameWhileFarmingTickets = true,  -- Plays "Hyper Darts" while farming at Hyperwave Island
    
    -- How long (in seconds) to perform the hatching action during a cycle.
    HatchDuration = 15.0
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
    local time = dist / 40
    local tween = TweenService:Create(rootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) })
    tween:Play()
    tween.Completed:Wait()
end

local function openRegularEgg()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait()
end

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
    print("Collected " .. collectedCount .. " nearby pickups.")
end

local function playMinigame(name)
    print("-> Multitasking: Starting Minigame: " .. name)
    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    RemoteEvent:FireServer("StartMinigame", name, "Insane")
    RemoteEvent:FireServer("FinishMinigame")
    print("-> Minigame Finished.")
end


-- ## Main Automation Loop ##
print("Master Auto-Farm script started. To stop, run: getgenv().Config.AutoFarm = false")

while getgenv().Config.AutoFarm do
    local minFestival = parseCurrency(getgenv().Config.MIN_FESTIVAL_COINS)
    local minTickets = parseCurrency(getgenv().Config.MIN_TICKETS)
    local minGems = parseCurrency(getgenv().Config.MIN_GEMS)
    local minCoins = parseCurrency(getgenv().Config.MIN_COINS)

    if getCurrency("FestivalCoins") < minFestival then
        print("Farming Festival Coins...")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
        task.wait(3)
        
        if getgenv().Config.HatchWhileFarmingFestivalCoins then
            print("-> Multitasking: Moving to hatching spot.")
            tweenTo(Vector3.new(243, 13, 229))
            local endTime = tick() + getgenv().Config.HatchDuration
            while tick() < endTime and getgenv().Config.AutoFarm do openRegularEgg() end
        else
            print("-> Moving to standard farm spot.")
            tweenTo(Vector3.new(206, 22, 183))
        end
        collectNearbyPickups()

    elseif getCurrency("Tickets") < minTickets then
        print("Farming Tickets...")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn")
        task.wait(3)
        
        if getgenv().Config.HatchEggWhileFarmingTickets then
            print("-> Multitasking: Hatching Neon Egg.")
            tweenTo(workspace.Worlds["Minigame Paradise"].Islands["Hyperwave Island"].Island.Egg.Position)
            local endTime = tick() + getgenv().Config.HatchDuration
            while tick() < endTime and getgenv().Config.AutoFarm do openRegularEgg() end
        end
        
        if getgenv().Config.PlayMinigameWhileFarmingTickets then
            playMinigame("Hyper Darts")
        end
        
        collectNearbyPickups()

    elseif getCurrency("Gems") < minGems then
        print("Farming Gems...")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
        task.wait(3)

        if getgenv().Config.HatchEggWhileFarmingGemsAndCoins then
            print("-> Multitasking: Moving to hatching spot.")
            tweenTo(Vector3.new(-35, 15973, 45))
            local endTime = tick() + getgenv().Config.HatchDuration
            while tick() < endTime and getgenv().Config.AutoFarm do openRegularEgg() end
        end
        collectNearbyPickups()

    elseif getCurrency("Coins") < minCoins then
        print("Farming Coins...")
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
        task.wait(3)
        
        if getgenv().Config.HatchEggWhileFarmingGemsAndCoins then
            print("-> Multitasking: Moving to hatching spot.")
            tweenTo(Vector3.new(-35, 15973, 45))
            local endTime = tick() + getgenv().Config.HatchDuration
            while tick() < endTime and getgenv().Config.AutoFarm do openRegularEgg() end
        end
        collectNearbyPickups()
        
    else
        print("All currency minimums met. Idling...")
    end

    task.wait(5)
end

print("Master Auto-Farm script has stopped.")
