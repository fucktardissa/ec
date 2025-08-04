-- Standalone Auto Minigame Milestones Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to false in your executor to stop the script
    AutoMilestones = true
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
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

-- This is the new "fast" function with cooldowns removed
local function playMinigameFast(name, difficulty)
    local targetDifficulty = difficulty or "Easy"
    print("-> Spam-starting Minigame: '" .. name .. "' on '" .. targetDifficulty .. "' difficulty.")
    
    RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
    task.wait(1.5) -- Wait for teleport

    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    RemoteEvent:FireServer("StartMinigame", name, targetDifficulty)
    task.wait(0.5) -- Minimal wait for server to process
    RemoteEvent:FireServer("FinishMinigame")
    
    print("-> Minigame cycle finished.")
end

-- ## Main Logic ##
task.spawn(function()
    print("--- Starting Auto Minigame Milestones script. ---")

    local milestoneTasks = {
        [1] = { name = "Robot Claw",   difficulty = "Easy" },
        [2] = { name = "Robot Claw",   difficulty = "Easy" },
        [3] = { name = "Robot Claw",   difficulty = "Easy" },
        [4] = { name = "Pet Match",    difficulty = nil },
        [5] = { name = "Cart Escape",  difficulty = nil },
        [6] = { name = "Robot Claw",   difficulty = nil },
        [7] = { name = "Robot Claw",   difficulty = "Hard" },
        [8] = { name = "Robot Claw",   difficulty = "Insane" },
        [9] = { name = "Robot Claw",   difficulty = "Insane" }
    }
    
    while getgenv().Config.AutoMilestones do
        local playerData = LocalData:Get()
        local questsCompleted = playerData.QuestsCompleted or {}
        local minigameMilestones = MilestonesModule.Minigames
        
        local nextMilestoneNumber = 0
        local milestoneCounter = 0

        for tierName, tierData in pairs(minigameMilestones.Tiers) do
            for i, levelData in ipairs(tierData.Levels) do
                milestoneCounter = milestoneCounter + 1
                local milestoneId = "milestone-minigame-" .. tostring(milestoneCounter)
                if not questsCompleted[milestoneId] then
                    nextMilestoneNumber = milestoneCounter
                    break
                end
            end
            if nextMilestoneNumber > 0 then break end
        end

        if nextMilestoneNumber == 0 then
            print("All minigame milestones are complete! Stopping script.")
            getgenv().Config.AutoMilestones = false
            break
        end

        print("Next milestone to complete: milestone-minigame-" .. nextMilestoneNumber)
        
        local taskToDo = milestoneTasks[nextMilestoneNumber]
        
        if taskToDo then
            -- ## NEW LOGIC: Check if we should use the external script ##
            if nextMilestoneNumber == 8 or nextMilestoneNumber == 9 then
                print("-> Milestone 8 or 9 detected. Handing over to external AutoClaw script.")
                getgenv().reportTime = 60
                getgenv().tryCollectMultipleTimes = false
                loadstring(game:HttpGet("https://raw.githubusercontent.com/IdiotHub/Scripts/refs/heads/main/BGSI/AutoClaw.lua"))()
                print("-> External script has been executed. Pausing for 60 seconds before re-checking milestones.")
                task.wait(60)
            else
                -- Otherwise, use the fast internal function
                playMinigameFast(taskToDo.name, taskToDo.difficulty)
            end
        else
            warn("-> Could not find a hardcoded task for milestone number: " .. nextMilestoneNumber)
            task.wait(5)
        end
        task.wait(1) -- A small delay between each check to prevent lag
    end
    
    print("--- Auto Minigame Milestones script has stopped. ---")
end)
