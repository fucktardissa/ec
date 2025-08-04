-- Standalone Island Unlocking Script (with Verification Loop)

-- Get essential services and modules
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

-- ## THIS IS THE NEW MASTER LIST OF ISLANDS TO UNLOCK ##
local allIslandNames = {
    -- World 1
    "Floating Island", "Outer Space", "Twilight", "The Void", "Zen",
    -- World 2
    "Dice Island", "Minecart Forest", "Robot Factory", "Hyperwave Island"
}

-- Wait for the player's character and HumanoidRootPart to exist
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

if not rootPart then
    warn("Player character could not be found. Stopping script.")
    return
end

-- Define a list of all island containers to scan.
local islandContainersToScan = {
    Workspace.Worlds["The Overworld"].Islands,
    Workspace.Worlds["Minigame Paradise"].Islands
}

-- ## NEW VERIFICATION FUNCTION ##
-- This function checks your player data to see if all islands are unlocked.
local function areAllIslandsUnlocked()
    local playerData = LocalData:Get()
    if not (playerData and playerData.AreasUnlocked) then
        return false -- Can't verify if data doesn't exist
    end
    
    for _, islandName in ipairs(allIslandNames) do
        if not playerData.AreasUnlocked[islandName] then
            print("Verification Check: Missing '" .. islandName .. "'")
            return false -- Found an island that is not unlocked
        end
    end
    
    print("Verification Check: All islands are unlocked!")
    return true -- All islands were found in the unlocked list
end

-- Script starts here
print("Starting to unlock islands with verification...")
local originalCFrame = rootPart.CFrame
local attempts = 0
local maxAttempts = 3 -- Failsafe to prevent an infinite loop

-- ## NEW MAIN LOOP ##
-- Keep trying until all islands are verified or we hit the attempt limit.
while not areAllIslandsUnlocked() and attempts < maxAttempts do
    attempts = attempts + 1
    print("--- Starting unlock attempt #" .. attempts .. " ---")
    
    -- Get a fresh copy of the currently unlocked areas for this attempt
    local unlockedAreas = LocalData:Get().AreasUnlocked or {}
    local unlockedThisAttempt = 0

    -- Loop through each main container in our list
    for _, islandsContainer in ipairs(islandContainersToScan) do
        if islandsContainer then
            for _, islandModel in ipairs(islandsContainer:GetChildren()) do
                -- OPTIMIZATION: Only try to unlock islands that are not already unlocked.
                if not unlockedAreas[islandModel.Name] then
                    local hitbox = islandModel:FindFirstChild("UnlockHitbox", true)
                    if hitbox then
                        print("Unlocking: " .. islandModel.Name)
                        rootPart.Anchored = true
                        rootPart.CFrame = hitbox.CFrame
                        rootPart.Anchored = false
                        task.wait(1.0)
                        
                        rootPart.Anchored = true
                        rootPart.CFrame = originalCFrame
                        rootPart.Anchored = false
                        task.wait(0.5)

                        unlockedThisAttempt = unlockedThisAttempt + 1
                    end
                end
            end
        end
    end
    
    if unlockedThisAttempt == 0 and attempts > 1 then
        print("No new islands were unlocked on this attempt. There might be an issue.")
    end
    
    print("Unlock attempt #" .. attempts .. " complete. Re-checking...")
    task.wait(2) -- Wait a couple of seconds for data to update before re-verifying
end

-- Final return to start position
rootPart.Anchored = true
rootPart.CFrame = originalCFrame
rootPart.Anchored = false

if areAllIslandsUnlocked() then
    print("Finished! All islands successfully unlocked and verified.")
else
    print("Finished! The script may have failed to unlock some islands after " .. maxAttempts .. " attempts.")
end
