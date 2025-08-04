-- Standalone Auto Minigame Milestones Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to false in your executor to stop the script
    AutoMilestones = true,
    
    -- Delay in seconds between finishing one minigame and starting the next
    CycleDelay = 1.0
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MilestonesModule = require(ReplicatedStorage.Shared.Data.Milestones)

-- ## Helper Functions ##

-- This function plays a minigame from start to finish
local function playMinigame(name, difficulty)
    -- Default to "Easy" if no difficulty is specified by the milestone
    local targetDifficulty = difficulty or "Easy"
    
    print("-> Starting Minigame: '" .. name .. "' on '" .. targetDifficulty .. "' difficulty.")
    
    -- Teleport to the minigame world to ensure we can start it
    RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
    task.wait(3)

    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    task.wait(0.2)
    RemoteEvent:FireServer("StartMinigame", name, targetDifficulty)
    task.wait(3) -- Wait for the minigame to load
    RemoteEvent:FireServer("FinishMinigame")
    
    print("-> Minigame finished. Waiting for cooldown...")
    task.wait(getgenv().Config.CycleDelay)
end

-- ## Main Logic ##
task.spawn(function()
    print("--- Starting Auto Minigame Milestones script. ---")
    
    while getgenv().Config.AutoMilestones do
        local playerData = LocalData:Get()
        local questsCompleted = playerData.QuestsCompleted or {}
        local minigameMilestones = MilestonesModule.Minigames
        
        local nextMilestoneId, nextMilestoneTask = nil, nil

        -- Find the first uncompleted minigame milestone
        for tierName, tierData in pairs(minigameMilestones.Tiers) do
            for i, levelData in ipairs(tierData.Levels) do
                local milestoneId = "milestone-minigame-" .. tostring(levelData.Id)
                if not questsCompleted[milestoneId] then
                    nextMilestoneId = milestoneId
                    nextMilestoneTask = levelData.Tasks[1] -- Assuming one task per milestone level
                    break
                end
            end
            if nextMilestoneId then break end
        end

        if not nextMilestoneId then
            print("All minigame milestones are complete! Stopping script.")
            getgenv().Config.AutoMilestones = false
            break
        end

        print("Next milestone to complete: " .. nextMilestoneId)
        
        -- Determine which minigame to play based on the task
        local minigameName = nextMilestoneTask.Name
        local minigameDifficulty = nextMilestoneTask.Difficulty

        -- Handle special cases as requested
        if not minigameName and (minigameDifficulty == "Hard" or minigameDifficulty == "Insane") then
            minigameName = "Robot Claw"
            print("-> Milestone requires a specific difficulty. Defaulting to: " .. minigameName)
        elseif nextMilestoneTask.Amount >= 500 then
            minigameName = "Robot Claw"
            print("-> Milestone requires a high number of completions. Defaulting to: " .. minigameName)
        end
        
        if minigameName then
            playMinigame(minigameName, minigameDifficulty)
        else
            warn("-> Could not determine which minigame to play for milestone: " .. nextMilestoneId)
            -- Failsafe to prevent getting stuck
            task.wait(5)
        end
    end
    
    print("--- Auto Minigame Milestones script has stopped. ---")
end)
