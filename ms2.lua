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
local function formatTaskDescription(task)
    local parts = {}
    table.insert(parts, task.Type)
    if task.Amount then table.insert(parts, task.Amount) end
    if task.Name then table.insert(parts, "'" .. task.Name .. "'") end
    if task.Difficulty then table.insert(parts, "on " .. task.Difficulty) end
    return table.concat(parts, " ")
end

local function playMinigame(name, difficulty)
    local targetDifficulty = difficulty or "Easy"
    print("-> Starting Minigame: '" .. name .. "' on '" .. targetDifficulty .. "' difficulty.")
    
    RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
    task.wait(3)

    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    task.wait(0.2)
    RemoteEvent:FireServer("StartMinigame", name, targetDifficulty)
    task.wait(3)
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
        local milestoneCounter = 0

        for tierName, tierData in pairs(minigameMilestones.Tiers) do
            for i, levelData in ipairs(tierData.Levels) do
                milestoneCounter = milestoneCounter + 1
                local milestoneId = "milestone-minigame-" .. tostring(milestoneCounter)
                
                if not questsCompleted[milestoneId] then
                    nextMilestoneId = milestoneId
                    nextMilestoneTask = levelData.Task
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
        print("  > Task: " .. formatTaskDescription(nextMilestoneTask))
        
        local minigameName = nextMilestoneTask.Name
        local minigameDifficulty = nextMilestoneTask.Difficulty

        if not minigameName and (minigameDifficulty == "Hard" or minigameDifficulty == "Insane") then
            minigameName = "Robot Claw"
            minigameDifficulty = "Insane" -- Fix: Default to insane
            print("-> Milestone requires specific difficulty. Defaulting to: " .. minigameName .. " on " .. minigameDifficulty)
        elseif nextMilestoneTask.Amount and nextMilestoneTask.Amount >= 500 then
            minigameName = "Robot Claw"
            minigameDifficulty = "Insane" -- Fix: Default to insane
            print("-> Milestone requires high completions. Defaulting to: " .. minigameName .. " on " .. minigameDifficulty)
        end
        
        if minigameName then
            playMinigame(minigameName, minigameDifficulty)
        else
            warn("-> Could not determine which minigame to play for milestone: " .. nextMilestoneId)
            task.wait(5)
        end
    end
    
    print("--- Auto Minigame Milestones script has stopped. ---")
end)
