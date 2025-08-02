-- Combined Minigame Automator & Transition Skipper (v5 - Final Fix)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoMinigame = true,
    MinigameToPlay = "Robot Claw",
    UnlockInsaneMode = true,
    TargetDifficulty = "Insane",
    QUICK_MINIGAME_FINISH = false
}
getgenv().Config = Config -- Make it accessible globally to stop it

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- Hardcoded Settings
local ITEM_LOAD_DELAY = 2.0
local GRAB_DELAY = 0.5
local CYCLE_DELAY = 1.0 -- Changed to 7 seconds as requested

-- Get necessary services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

-- ## Part 1: Setup Transition Skipper ##
print("Attempting to hook and disable screen transitions...")
local success, errorMessage = pcall(function()
    local playTransitionModule = ReplicatedStorage:FindFirstChild("PlayTransition", true)
    if playTransitionModule then
        if hookfunction then
            local originalTransitionFunc = require(playTransitionModule)
            local function skipTransition(text, callback, icon)
                if typeof(callback) == "function" then task.spawn(callback) end
            end
            hookfunction(originalTransitionFunc, skipTransition)
            print("Successfully hooked PlayTransition. Transitions will be skipped.")
        else
            warn("hookfunction not supported; transitions will not be skipped.")
        end
    else
        warn("Could not find 'PlayTransition' module; transitions will not be skipped.")
    end
end)
if not success then
    warn("An error occurred while setting up the transition skipper:", errorMessage)
end

-- ## CORRECTED HELPER FUNCTION ##
-- This function now loops until all items are gone to handle server cooldowns.
local function grabAllClawItems()
    print("  [Debug] Now scanning for claw items...")
    local itemsStillExist = true
    while itemsStillExist and getgenv().Config.AutoMinigame do
        local itemsFoundThisPass = 0
        for _, child in ipairs(ScreenGui:GetChildren()) do
            local itemId = child.Name:match("^ClawItem(.+)")
            if itemId then
                itemsFoundThisPass = itemsFoundThisPass + 1
                print("    > Found and grabbing item ID: " .. itemId)
                RemoteEvent:FireServer("GrabMinigameItem", itemId)
                task.wait(GRAB_DELAY)
            end
        end
        
        if itemsFoundThisPass == 0 then
            itemsStillExist = false
        end
    end
    print("  [Debug] All items grabbed. Game should end automatically.")
end

-- ## Part 2: Minigame Automation Logic ##
print("Starting Minigame Automator. To stop, run: getgenv().Config.AutoMinigame = false")
while getgenv().Config.AutoMinigame do
    if getgenv().Config.UnlockInsaneMode then
        print("--- Starting Insane Mode Unlock Sequence for: " .. getgenv().Config.MinigameToPlay .. " ---")
        local difficultiesToUnlock = {"Easy", "Medium", "Hard"}
        for _, difficulty in ipairs(difficultiesToUnlock) do
            if not getgenv().Config.AutoMinigame then break end
            print("  [Debug] Unlocking on difficulty: " .. difficulty)
            RemoteEvent:FireServer("SkipMinigameCooldown", getgenv().Config.MinigameToPlay)
            RemoteEvent:FireServer("StartMinigame", getgenv().Config.MinigameToPlay, difficulty)
            
            print("    > Waiting 3 seconds for minigame to load...")
            task.wait(3)
            
            RemoteEvent:FireServer("FinishMinigame")
            
            print("    > Waiting for cycle cooldown (" .. CYCLE_DELAY .. " seconds)...")
            task.wait(CYCLE_DELAY)
        end
        print("--- Insane Mode Unlock Sequence Complete! ---")
        getgenv().Config.UnlockInsaneMode = false
    end

    print("--- Starting new farm cycle on " .. getgenv().Config.TargetDifficulty .. " ---")
    RemoteEvent:FireServer("SkipMinigameCooldown", getgenv().Config.MinigameToPlay)
    task.wait(0.1)
    RemoteEvent:FireServer("StartMinigame", getgenv().Config.MinigameToPlay, getgenv().Config.TargetDifficulty)
    
    if getgenv().Config.QUICK_MINIGAME_FINISH then
        print("  [Debug] Quick Finish mode enabled.")
        task.wait(0.5)
        RemoteEvent:FireServer("FinishMinigame")
    else
        print("  [Debug] Precision Grab mode enabled.")
        task.wait(ITEM_LOAD_DELAY)
        grabAllClawItems()
    end
    
    print("  [Debug] Cycle complete. Waiting for server cooldown (" .. CYCLE_DELAY .. "s)...")
    task.wait(CYCLE_DELAY)
end

print("Minigame Automator has stopped.")
