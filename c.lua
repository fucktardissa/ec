-- Combined Minigame Automator & Transition Skipper (v3 - Persistent Grab)

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
local GRAB_DELAY = 0.5 -- A slightly longer delay to respect server cooldowns
local CYCLE_DELAY = 5.0 -- A longer delay to let the game fully reset

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
                if typeof(callback) == "function" then
                    task.spawn(callback)
                end
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

-- ## UPDATED HELPER FUNCTION ##
-- This function now loops until all items are gone.
local function grabAllClawItems()
    print("Scanning for claw items...")
    
    local itemsStillExist = true
    while itemsStillExist do
        local itemsFoundThisPass = 0
        
        for _, child in ipairs(ScreenGui:GetChildren()) do
            local itemId = child.Name:match("^ClawItem(.+)")
            if itemId then
                itemsFoundThisPass = itemsFoundThisPass + 1
                print("  > Found item, attempting to grab ID: " .. itemId)
                RemoteEvent:FireServer("GrabMinigameItem", itemId)
                task.wait(GRAB_DELAY) -- Wait for the cooldown
            end
        end
        
        -- If we scan the entire GUI and find no items, the minigame is over.
        if itemsFoundThisPass == 0 then
            itemsStillExist = false
        end
    end
    
    print("All items grabbed. Minigame should end automatically.")
end

-- ## Part 2: Minigame Automation Logic ##
print("Starting Minigame Automator (Dual Mode). To stop, run: getgenv().Config.AutoMinigame = false")
while getgenv().Config.AutoMinigame do
    if getgenv().Config.UnlockInsaneMode then
        print("--- Starting Insane Mode Unlock Sequence for: " .. getgenv().Config.MinigameToPlay .. " ---")
        local difficultiesToUnlock = {"Easy", "Medium", "Hard"}
        for _, difficulty in ipairs(difficultiesToUnlock) do
            if not getgenv().Config.AutoMinigame then break end
            print("Unlocking on difficulty: " .. difficulty)
            RemoteEvent:FireServer("SkipMinigameCooldown", getgenv().Config.MinigameToPlay)
            RemoteEvent:FireServer("StartMinigame", getgenv().Config.MinigameToPlay, difficulty)
            RemoteEvent:FireServer("FinishMinigame")
            task.wait(CYCLE_DELAY)
        end
        print("--- Insane Mode Unlock Sequence Complete! ---")
        getgenv().Config.UnlockInsaneMode = false
    end

    print("--- Starting new cycle on " .. getgenv().Config.TargetDifficulty .. " ---")
    RemoteEvent:FireServer("SkipMinigameCooldown", getgenv().Config.MinigameToPlay)
    task.wait(0.1)
    RemoteEvent:FireServer("StartMinigame", getgenv().Config.MinigameToPlay, getgenv().Config.TargetDifficulty)
    
    if getgenv().Config.QUICK_MINIGAME_FINISH then
        print("Quick Finish mode enabled.")
        task.wait(0.5)
        RemoteEvent:FireServer("FinishMinigame")
    else
        print("Precision Grab mode enabled.")
        task.wait(ITEM_LOAD_DELAY)
        grabAllClawItems()
    end
    
    print("Cycle complete. Waiting " .. CYCLE_DELAY .. "s...")
    task.wait(CYCLE_DELAY)
end

print("Minigame Automator has stopped.")
