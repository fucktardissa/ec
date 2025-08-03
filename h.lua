-- Standalone Auto-Rift & Fallback Hatch Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Master toggle for the script.
    AutoRiftHatch = true,

    -- A list of priority rift egg names to search for.
    -- Example: RIFT_EGGS = {"festival-rift-3", "crystal-egg"}
    RIFT_EGGS = {},

    -- The script will only engage a rift if its multiplier is this value or higher.
    MIN_RIFT_MULTIPLIER = 5,

    -- If no valid rifts are found, the script will hatch one of these regular eggs as a fallback.
    -- The script will pick the first egg in this list.
    -- Example: HATCH_1X_EGG = {"Common Egg", "Spotted Egg"}
    HATCH_1X_EGG = {},
    
    -- How long (in seconds) to hatch the fallback egg before searching for rifts again.
    FallbackHatchDuration = 15.0
}
getgenv().Config = Config -- Make it accessible globally to stop it

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

-- ## Helper Functions from Provided Scripts ##

-- Egg positions for the fallback hatch
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

-- Checks if a rift exists in the workspace
local function isRiftValid(riftName)
    if not riftName or riftName == "" then return nil end
    local rift = workspace.Rendered.Rifts:FindFirstChild(riftName)
    if rift and rift:FindFirstChild("Display") and rift.Display:IsA("BasePart") then
        return rift
    end
    return nil
end

-- IMPORTANT: This function assumes the multiplier is in a TextLabel named "Multiplier".
-- You may need to edit "Multiplier" to the correct name if this doesn't work.
local function getRiftMultiplier(riftInstance)
    local display = riftInstance:FindFirstChild("Display")
    local gui = display and display:FindFirstChild("SurfaceGui")
    local multiplierLabel = gui and gui:FindFirstChild("Multiplier") -- Assumed name
    if multiplierLabel and multiplierLabel:IsA("TextLabel") then
        local num = tonumber(string.match(multiplierLabel.Text, "%d+"))
        return num or 0
    end
    return 0 -- Return 0 if not found
end

-- Teleports to the closest portal to the target rift
local function teleportToClosestPoint(targetHeight)
    local teleportPoints = {
        {name = "Zen", path = "Workspace.Worlds.The Overworld.Islands.Zen.Island.Portal.Spawn", height = 15970},
        {name = "The Void", path = "Workspace.Worlds.The Overworld.Islands.The Void.Island.Portal.Spawn", height = 10135},
        {name = "Twilight", path = "Workspace.Worlds.The Overworld.Islands.Twilight.Island.Portal.Spawn", height = 6855},
        {name = "Outer Space", path = "Workspace.Worlds.The Overworld.Islands.Outer Space.Island.Portal.Spawn", height = 2655}
    }
    local closestPoint = teleportPoints[#teleportPoints]
    local smallestDifference = math.huge
    for _, point in ipairs(teleportPoints) do
        local difference = math.abs(point.height - targetHeight)
        if difference < smallestDifference then
            smallestDifference = difference
            closestPoint = point
        end
    end
    print("Teleporting to closest portal: " .. closestPoint.name)
    RemoteEvent:FireServer("Teleport", closestPoint.path)
end

-- Tweens the character to the final rift position
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

-- Simulates pressing the 'R' key to hatch a rift
local function openRift()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

-- Tweens to a regular egg for the fallback
local function tweenToEgg(position)
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local dist = (rootPart.Position - position).Magnitude
    local time = dist / 150 -- Fast speed
    local tween = TweenService:Create(rootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) })
    tween:Play()
    tween.Completed:Wait()
end

-- Simulates pressing the 'E' key to hatch a regular egg
local function openRegularEgg()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait()
end


-- ## Main Automation Loop ##
print("Auto-Rift script started. To stop, run: getgenv().Config.AutoRiftHatch = false")

while getgenv().Config.AutoRiftHatch do
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        print("Waiting for character to load...")
        task.wait(2)
        continue
    end

    -- 1. Search for a valid priority rift
    local targetRift = nil
    print("Searching for priority rifts...")
    for _, riftName in ipairs(getgenv().Config.RIFT_EGGS) do
        local riftInstance = isRiftValid(riftName)
        if riftInstance then
            local multiplier = getRiftMultiplier(riftInstance)
            print("Found rift '" .. riftName .. "' with multiplier x" .. multiplier)
            if multiplier >= getgenv().Config.MIN_RIFT_MULTIPLIER then
                targetRift = riftInstance
                break -- Found a valid rift, stop searching
            end
        end
    end

    -- 2. Engage the rift if one was found
    if targetRift then
        print("Engaging target rift: " .. targetRift.Name)
        local targetPosition = targetRift.Display.Position + Vector3.new(0, 4, 0)
        teleportToClosestPoint(targetPosition.Y)
        task.wait(5) -- Wait for teleport to complete
        performMovement(targetPosition)
        task.wait(1)
        
        print("Hatching rift...")
        while isRiftValid(targetRift.Name) and getgenv().Config.AutoRiftHatch do
            openRift()
            task.wait(0.5)
        end
        print("Rift is gone. Restarting search cycle.")

    -- 3. If no rift was found, perform the fallback action
    else
        print("No valid rifts found.")
        local fallbackEggName = getgenv().Config.HATCH_1X_EGG[1]
        if fallbackEggName then
            local eggPos = eggPositions[fallbackEggName]
            if eggPos then
                print("Falling back to hatch: " .. fallbackEggName)
                RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
                task.wait(3)
                tweenToEgg(eggPos)
                
                print("Hatching for " .. getgenv().Config.FallbackHatchDuration .. " seconds...")
                local hatchEndTime = tick() + getgenv().Config.FallbackHatchDuration
                while tick() < hatchEndTime and getgenv().Config.AutoRiftHatch do
                    openRegularEgg()
                end
            else
                print("Could not find position for fallback egg: " .. fallbackEggName)
            end
        else
            print("No fallback egg configured. Waiting before next rift search.")
        end
    end

    task.wait(5) -- Cooldown before the next full search cycle
end

print("Auto-Rift script has stopped.")
