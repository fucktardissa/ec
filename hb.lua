-- Standalone Auto-Rift & Fallback Hatch Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoRiftHatch = true,
    RIFT_EGGS = {"Neon-Egg", "Spikey-Egg", "mining-egg"},
    MIN_RIFT_MULTIPLIER = 5,
    HATCH_1X_EGG = {"Spikey-Egg"},
    FallbackHatchDuration = 15.0
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

-- ## Data for Teleporting & Locations ##
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

-- ## Helper Functions ##
local function isRiftValid(riftName)
    if not riftName or riftName == "" then return nil end
    local rift = workspace.Rendered.Rifts:FindFirstChild(riftName)
    if rift and rift:FindFirstChild("Display") and rift.Display:IsA("BasePart") then
        return rift
    end
    return nil
end

-- ## THE FIX IS IN THIS FUNCTION ##
local function getRiftMultiplier(riftInstance)
    local display = riftInstance:FindFirstChild("Display")
    if not display then return 0 end
    
    local gui = display:FindFirstChild("SurfaceGui")
    if not gui then return 0 end
    
    local icon = gui:FindFirstChild("Icon")
    if not icon then return 0 end

    -- Uses the correct path you provided
    local luckLabel = icon:FindFirstChild("Luck") 
    if luckLabel and luckLabel:IsA("TextLabel") then
        local num = tonumber(string.match(luckLabel.Text, "%d+"))
        return num or 0
    end
    return 0
end

local function teleportToClosestPoint(targetHeight, teleportPoints, worldName)
    local closestPoint = teleportPoints[#teleportPoints]
    local smallestDifference = math.huge
    for _, point in ipairs(teleportPoints) do
        local difference = math.abs(point.height - targetHeight)
        if difference < smallestDifference then
            smallestDifference = difference
            closestPoint = point
        end
    end
    print("Teleporting to closest portal in " .. worldName .. ": " .. closestPoint.name)
    RemoteEvent:FireServer("Teleport", closestPoint.path)
end

local function performMovement(targetPosition)
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local originalCollisions = {}
    for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then originalCollisions[part] = part.CanCollide; part.CanCollide = false; end end
    local startPos = rootPart.Position
    local intermediatePos = CFrame.new(startPos.X, targetPosition.Y, startPos.Z)
    local verticalTime = (startPos - intermediatePos.Position).Magnitude / 300
    local verticalTween = TweenService:Create(rootPart, TweenInfo.new(verticalTime, Enum.EasingStyle.Linear), {CFrame = intermediatePos})
    verticalTween:Play()
    verticalTween.Completed:Wait()
    local horizontalTime = (rootPart.Position - targetPosition).Magnitude / 30
    local horizontalTween = TweenService:Create(rootPart, TweenInfo.new(horizontalTime, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPosition)})
    horizontalTween:Play()
    horizontalTween.Completed:Wait()
    for part, canCollide in pairs(originalCollisions) do if part and part.Parent then part.CanCollide = canCollide; end end
end

local function openRift()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

local function tweenToEgg(position)
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


-- ## Main Automation Loop ##
print("Auto-Rift script started. To stop, run: getgenv().Config.AutoRiftHatch = false")

while getgenv().Config.AutoRiftHatch do
    local targetRift, targetRiftNameFromConfig = nil, nil
    print("Searching for priority rifts...")
    for _, riftName in ipairs(getgenv().Config.RIFT_EGGS) do
        local riftInstance = isRiftValid(riftName)
        if riftInstance then
            local multiplier = getRiftMultiplier(riftInstance)
            print("Found rift '" .. riftName .. "' with multiplier x" .. multiplier)
            if multiplier >= getgenv().Config.MIN_RIFT_MULTIPLIER then
                targetRift = riftInstance
                targetRiftNameFromConfig = riftName
                break
            end
        end
    end

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
        print("No valid rifts found.")
        local fallbackEggNameHyphenated = getgenv().Config.HATCH_1X_EGG[1]
        if fallbackEggNameHyphenated then
            local fallbackEggNameSpaced = fallbackEggNameHyphenated:gsub("-", " ")
            local eggPos = eggPositions[fallbackEggNameSpaced]
            
            if eggPos then
                print("Falling back to hatch: " .. fallbackEggNameSpaced)
                RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
                task.wait(3)
                tweenToEgg(eggPos)
                
                print("Hatching for " .. getgenv().Config.FallbackHatchDuration .. " seconds...")
                local hatchEndTime = tick() + getgenv().Config.FallbackHatchDuration
                while tick() < hatchEndTime and getgenv().Config.AutoRiftHatch do
                    openRegularEgg()
                end
            else
                print("Could not find position for fallback egg: " .. fallbackEggNameSpaced)
            end
        else
            print("No fallback egg configured. Waiting before next rift search.")
        end
    end

    task.wait(5)
end

print("Auto-Rift script has stopped.")
