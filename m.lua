-- Combined Minigame Automator & Transition Skipper

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
}
getgenv().Config = Config -- Make it accessible globally to stop it

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- Get necessary services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

-- ## Part 1: Setup Transition Skipper ##
print("Attempting to hook and disable screen transitions...")
-- We use a protected call (pcall) to prevent errors if the module isn't found
local success, errorMessage = pcall(function()
    local playTransitionModule = ReplicatedStorage:FindFirstChild("PlayTransition", true)
    if playTransitionModule then
        if hookfunction then
            local originalTransitionFunc = require(playTransitionModule)
            local function skipTransition(text, callback, icon)
                -- The callback is the important game logic we need to run instantly.
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

-- ## Part 2: Minigame Automation Logic ##
print("Starting Minigame Automator (Max Speed). To stop, run: getgenv().Config.AutoMinigame = false")
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
        end
        print("--- Insane Mode Unlock Sequence Complete! ---")
        getgenv().Config.UnlockInsaneMode = false
    end

    RemoteEvent:FireServer("SkipMinigameCooldown", getgenv().Config.MinigameToPlay)
    RemoteEvent:FireServer("StartMinigame", getgenv().Config.MinigameToPlay, getgenv().Config.TargetDifficulty)
    RemoteEvent:FireServer("FinishMinigame")
    
    -- Added a minimal wait to prevent the 'while' loop from crashing the client
    task.wait() 
end

print("Minigame Automator has stopped.")
