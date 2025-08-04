--[[
    ================================================================
    -- ## ULTIMATE STARTER & AUTO-FARM SCRIPT ##
    ================================================================
    --
    -- DESCRIPTION:
    -- This script combines the best of both worlds. It begins with a
    -- one-time starter routine to unlock islands, redeem codes, and
    -- use initial items. Afterwards, it seamlessly transitions into
    -- a powerful, continuous auto-farming loop that farms currencies,
    -- multitasks by hatching eggs, and collects resources 24/7 in
    -- the background.
    --
]]

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoFarm = true,

    MIN_FESTIVAL_COINS = "0",
    MIN_TICKETS = "0",
    MIN_GEMS = "1m",
    MIN_COINS = "10b",

    HatchWhileFarmingFestivalCoins = true,
    HatchWhileFarmingGemsAndCoins = true,
    HatchWhileFarmingTickets = false,
    PlayMinigameWhileFarmingTickets = true,

    HatchDuration = 15.0,

    USE_POTIONS_ON_START = {"Coins", "Lucky", "Speed"},
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

print("--- LOADING ULTIMATE SCRIPT SERVICES & MODULES ---")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local RemoteFunction = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local CodesModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Codes"))

local FarmLocations = {
    FestivalCoins = Vector3.new(206, 22, 183),
    FestivalHatch = Vector3.new(243, 13, 229),
    GemsAndCoins = Vector3.new(-36, 15973, 47),
    GemsAndCoinsHatch = Vector3.new(-35, 15973, 45),
    TicketsHatch = Vector3.new(9880, 20089, 256)
}

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

local function performFarmingAction()
    print("-> Performing farming action (E key press)...")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait(0.05)
end

local function collectNearbyPickups()
    local collectRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Pickups"):WaitForChild("CollectPickup")
    local renderedFolder = workspace:WaitForChild("Rendered")
    local collectedCount = 0
    for _, child in ipairs(renderedFolder:GetChildren()) do
        if child.Name == "Chunker" then
            for _, item in ipairs(child:GetChildren()) do
                if not string.match(item.Name, "Egg") then
                    pcall(function()
                        collectRemote:FireServer(item.Name)
                        collectedCount = collectedCount + 1
                        task.wait()
                        item:Destroy()
                    end)
                end
            end
        end
    end
    if collectedCount > 0 then
        print("--> Background Collection: Picked up " .. collectedCount .. " items.")
    end
end

local function playMinigame(name)
    print("-> Multitasking: Starting Minigame: " .. name)
    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    RemoteEvent:FireServer("StartMinigame", name, "Insane")
    RemoteEvent:FireServer("FinishMinigame")
    print("-> Minigame Finished.")
end

local function useBestPotionsFromList(potionTypes)
    print("Attempting to use best available potions from list: " .. table.concat(potionTypes, ", "))
    local playerData = LocalData:Get()
    if not (playerData and playerData.Potions) then return end
    for _, potionNameToFind in ipairs(potionTypes) do
        local bestPotionFound = nil
        for _, potionInstance in pairs(playerData.Potions) do
            if string.match(potionInstance.Name, potionNameToFind) then
                if not bestPotionFound or potionInstance.Level > bestPotionFound.Level then
                    bestPotionFound = potionInstance
                end
            end
        end
        if bestPotionFound and bestPotionFound.Amount > 0 then
            print("-> Using best '"..potionNameToFind.."' potion: '" .. bestPotionFound.Name .. "'")
            RemoteEvent:FireServer("UsePotion", bestPotionFound.Name, bestPotionFound.Level, 1)
            task.wait(1)
        end
    end
end

task.spawn(function()
    print("--- ULTIMATE SCRIPT INITIATED ---")

    print("[STEP 1] Waiting for player data to synchronize...")
    while not (LocalData:Get() and LocalData:Get().Potions) do task.wait(1) end
    print("Player data loaded!")

    print("[STEP 2] Unlocking all available islands...")
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local originalCFrame = rootPart.CFrame
        for _, islandModel in ipairs(workspace.Worlds["The Overworld"].Islands:GetChildren()) do
            local hitbox = islandModel:FindFirstChild("UnlockHitbox", true)
            if hitbox then rootPart.CFrame = hitbox.CFrame; task.wait(1.0) end
        end
        rootPart.CFrame = originalCFrame
    end
    print("Islands unlocked.")

    print("[STEP 3] Redeeming all available codes...")
    for codeName, _ in pairs(CodesModule) do
        pcall(function() RemoteFunction:InvokeServer("RedeemCode", codeName) end)
        task.wait(0.2)
    end
    print("Codes redeemed.")

    print("[STEP 4] Using starting potions...")
    useBestPotionsFromList(getgenv().Config.USE_POTIONS_ON_START)

    print("[STEP 5] Moving to Iceshard Egg to hatch starter pets...")
    tweenTo(Vector3.new(-11, 9, -51))
    print("Hatching for 30 seconds...")
    local hatchEndTime = tick() + 30
    while tick() < hatchEndTime do openRegularEgg() end
    print("Equipping best pets...")
    RemoteEvent:FireServer("EquipBestPets")
    print("--- INITIAL SETUP COMPLETE ---")

    print("--- STARTING CONTINUOUS AUTO-FARM & COLLECTION ---")

    task.spawn(function()
        print("-> Starting 24/7 background collection process.")
        while getgenv().Config.AutoFarm do
            collectNearbyPickups()
            task.wait(1)
        end
        print("-> Background collection has stopped.")
    end)

    while getgenv().Config.AutoFarm do
        local cfg = getgenv().Config
        local minFestival = parseCurrency(cfg.MIN_FESTIVAL_COINS)
        local minTickets = parseCurrency(cfg.MIN_TICKETS)
        local minGems = parseCurrency(cfg.MIN_GEMS)
        local minCoins = parseCurrency(cfg.MIN_COINS)

        if getCurrency("FestivalCoins") < minFestival then
            print("Farming Festival Coins...")
            RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
            task.wait(3)
            if cfg.HatchWhileFarmingFestivalCoins then
                print("-> Multitasking: Moving to hatching spot.")
                tweenTo(FarmLocations.FestivalHatch)
                local endTime = tick() + cfg.HatchDuration
                while tick() < endTime and cfg.AutoFarm do openRegularEgg() end
            end
            print("-> Moving to farming spot.")
            tweenTo(FarmLocations.FestivalCoins)
            performFarmingAction()

        elseif getCurrency("Tickets") < minTickets then
            print("Farming Tickets...")
            RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn")
            task.wait(3)
            if cfg.HatchWhileFarmingTickets then
                print("-> Multitasking: Hatching Neon Egg.")
                tweenTo(FarmLocations.TicketsHatch)
                local endTime = tick() + cfg.HatchDuration
                while tick() < endTime and cfg.AutoFarm do openRegularEgg() end
            end
            if cfg.PlayMinigameWhileFarmingTickets then playMinigame("Hyper Darts") end

        elseif getCurrency("Gems") < minGems then
            print("Farming Gems...")
            RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
            task.wait(3)
            if cfg.HatchWhileFarmingGemsAndCoins then
                print("-> Multitasking: Moving to hatching spot.")
                tweenTo(FarmLocations.GemsAndCoinsHatch)
                local endTime = tick() + cfg.HatchDuration
                while tick() < endTime and cfg.AutoFarm do openRegularEgg() end
            end
            print("-> Moving to farming spot.")
            tweenTo(FarmLocations.GemsAndCoins)
            performFarmingAction()

        elseif getCurrency("Coins") < minCoins then
            print("Farming Coins...")
            RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn")
            task.wait(3)
            if cfg.HatchWhileFarmingGemsAndCoins then
                print("-> Multitasking: Moving to hatching spot.")
                tweenTo(FarmLocations.GemsAndCoinsHatch)
                local endTime = tick() + cfg.HatchDuration
                while tick() < endTime and cfg.AutoFarm do openRegularEgg() end
            end
            print("-> Moving to farming spot.")
            tweenTo(FarmLocations.GemsAndCoins)
            performFarmingAction()

        else
            print("All currency minimums met. Idling...")
        end
        task.wait(5)
    end
    print("Master Auto-Farm script has stopped.")
end)
