-- Standalone Auto-Rift & Fallback Hatch Script (Optimized)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoRiftHatch = true,

    -- This list is now CASE-INSENSITIVE.
    RIFT_EGGS = {"mining-egg", "neon-egg", "Hyperwave Egg"},

    MIN_RIFT_MULTIPLIER = 5,

    -- This list remains CASE-SENSITIVE to match game data.
    HATCH_1X_EGG = {"Spikey-Egg"},
    
    -- How long to hatch the fallback egg BETWEEN rift checks.
    FallbackHatchDuration = 10.0
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

-- ## Data & Helpers ##
-- (eggPositions, world teleport points, etc. are unchanged)
local eggPositions = {
    ["Common Egg"] = Vector3.new(-83.86, 10.11, 1.57), ["Spotted Egg"] = Vector3.new(-93.96, 10.11, 7.41),
    ["Iceshard Egg"] = Vector3.new(-117.06, 10.11, 7.74), ["Spikey Egg"] = Vector3.new(-124.58, 10.11, 4.58),
    ["Magma Egg"] = Vector3.new(-133.02, 10.11, -1.55), ["Crystal Egg"] = Vector3.new(-140.20, 10.11, -8.36),
    ["Lunar Egg"] = Vector3.new(-143.85, 10.11, -15.93), ["Void Egg"] = Vector3.new(-145.91, 10.11, -26.13),
    ["Hell Egg"] = Vector3.new(-145.17, 10.11, -36.78), ["Nightmare Egg"] = Vector3.new(-142.35, 10.11, -45.15),
    ["Rainbow Egg"] = Vector3.new(-134.49, 10.11, -52.36), ["Mining Egg"] = Vector3.new(-120, 10, -64),
    ["Showman Egg"] = Vector3.new(-130, 10, -60), ["Cyber Egg"] = Vector3.new(-95, 10, -63),
    ["Infinity Egg"] = Vector3.new(-99, 9, -26), ["Neon Egg"] = Vector3.new(-83, 10, -57)
}
local world1TeleportPoints = {
    {name = "Zen", path = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn", height = 15970},
    {name = "The Void", path = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn", height = 10135},
    {name = "Twilight", path = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn", height = 6855},
    {name = "Outer Space", path = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn", height = 2655}
}
local world2TeleportPoints = {
    {name = "W2 Spawn", path = "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn", height = 0},
    {name = "Dice Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Dice Island.Island.Portal.Spawn", height = 2880},
    {name = "Minecart Forest", path = "Workspace.Worlds.Minigame Paradise.Islands.Minecart Forest.Island.Portal.Spawn", height = 7660},
    {name = "Robot Factory", path = "Workspace.Worlds.Minigame Paradise.Islands.Robot Factory.Island.Portal.Spawn", height = 13330},
    {name = "Hyperwave Island", path = "Workspace.Worlds.Minigame Paradise.Islands.Hyperwave Island.Island.Portal.Spawn", height = 20010}
}
local world2RiftKeywords = {"Neon", "Cyber", "Showman", "Mining"}

-- ## UPDATED: This function is now case-insensitive ##
local function isRiftValid(riftNameFromConfig)
    if not riftNameFromConfig or riftNameFromConfig == "" then return nil end
    local riftFolder = workspace.Rendered.Rifts
    local riftNameLower = string.lower(riftNameFromConfig)
    for _, riftInstance in ipairs(riftFolder:GetChildren()) do
        if string.lower(riftInstance.Name) == riftNameLower then
            if riftInstance:FindFirstChild("Display") and riftInstance.Display:IsA("BasePart") then
                return riftInstance
            end
        end
    end
    return nil
end

local function getRiftMultiplier(riftInstance)
    local display = riftInstance:FindFirstChild("Display")
    if not display then return 0 end
    local gui = display:FindFirstChild("SurfaceGui")
    if not gui then return 0 end
    local icon = gui:FindFirstChild("Icon")
    if not icon then return 0 end
    local luckLabel = icon:FindFirstChild("Luck") 
    if luckLabel and luckLabel:IsA("TextLabel") then
        local num = tonumber(string.match(luckLabel.Text, "%d+"))
        return num or 0
    end
    return 0
end

-- (Other helper functions like teleportToClosestPoint, performMovement, openRift, etc. are unchanged)
-- ...

local function searchForPriorityRift()
    print("Searching for priority rifts...")
    for _, riftName in ipairs(getgenv().Config.RIFT_EGGS) do
        local riftInstance = isRiftValid(riftName)
        if riftInstance then
            local multiplier = getRiftMultiplier(riftInstance)
            print("Found rift '" .. riftInstance.Name .. "' with multiplier x" .. multiplier)
            if multiplier >= getgenv().Config.MIN_RIFT_MULTIPLIER then
                return riftInstance, riftName -- Return the instance and the config name
            end
        end
    end
    return nil, nil -- No valid rift found
end

-- ## Main Automation Loop ##
print("Auto-Rift script started. To stop, run: getgenv().Config.AutoRiftHatch = false")

while getgenv().Config.AutoRiftHatch do
    local targetRift, targetRiftNameFromConfig = searchForPriorityRift()

    if targetRift then
        print("Engaging target rift: " .. targetRift.Name)
        local targetPosition = targetRift.Display.Position + Vector3.new(0, 4, 0)
        
        local isWorld2Rift = false
        for _, keyword in ipairs(world2RiftKeywords) do
            if targetRiftNameFromConfig:find(keyword) then
                isWorld2Rift = true
                break
            end
        end
        if isWorld2Rift then
            teleportToClosestPoint(targetPosition.Y, world2TeleportPoints, "World 2")
        else
            teleportToClosestPoint(targetPosition.Y, world1TeleportPoints, "World 1")
        end
        
        task.wait(5)
        performMovement(targetPosition)
        task.wait(1)
        
        print("Hatching rift...")
        while isRiftValid(targetRift.Name) and getgenv().Config.AutoRiftHatch do
            openRift()
            task.wait(0.5)
        end
        print("Rift is gone. Restarting search cycle.")

    else
        print("No valid rifts found. Entering fallback hatch mode.")
        local fallbackEggNameHyphenated = getgenv().Config.HATCH_1X_EGG[1]
        if fallbackEggNameHyphenated then
            local fallbackEggNameSpaced = fallbackEggNameHyphenated:gsub("-", " ")
            local eggPos = eggPositions[fallbackEggNameSpaced]
            
            if eggPos then
                -- ## SETUP: Get into position ONCE ##
                print("Falling back to hatch: " .. fallbackEggNameSpaced)
                RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
                task.wait(3)
                tweenToEgg(eggPos)
                
                -- ## NESTED LOOP: Stay here, hatch, and check for rifts ##
                print("Now in fallback mode. Will hatch and periodically search for rifts...")
                while getgenv().Config.AutoRiftHatch do
                    local riftFound, _ = searchForPriorityRift()
                    if riftFound then
                        print("Priority rift found! Exiting fallback mode.")
                        break -- Break this nested loop to let the main loop engage the rift
                    end

                    print("No rifts found, continuing to hatch fallback egg...")
                    local hatchEndTime = tick() + getgenv().Config.FallbackHatchDuration
                    while tick() < hatchEndTime and getgenv().Config.AutoRiftHatch do
                        openRegularEgg()
                    end
                end
            else
                print("Could not find position for fallback egg: " .. fallbackEggNameSpaced)
                task.wait(5) -- Wait before trying again
            end
        else
            print("No fallback egg configured. Waiting before next rift search.")
            task.wait(5)
        end
    end
end

print("Auto-Rift script has stopped.")
