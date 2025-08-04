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

    -- This table now defines the exact task for each of the 9 minigame milestones.
    local milestoneTasks = {
        [1] = { name = "Robot Claw",   difficulty = "Easy" },   -- Task: CompleteMinigame(1)
        [2] = { name = "Robot Claw",   difficulty = "Easy" },   -- Task: CompleteMinigame(5)
        [3] = { name = "Robot Claw",   difficulty = "Easy" },   -- Task: CompleteMinigame(15)
        [4] = { name = "Pet Match",    difficulty = "Insane" },      -- Task: CompleteMinigame(15, "Pet Match")
        [5] = { name = "Cart Escape",  difficulty = "Insane" },      -- Task: CompleteMinigame(15, "Cart Escape")
        [6] = { name = "Robot Claw",   difficulty = "Insane" },      -- Task: CompleteMinigame(15, "Robot Claw")
        [7] = { name = "Robot Claw",   difficulty = "Hard" },   -- Task: CompleteMinigame(75, nil, "Hard")
        [8] = { name = "Robot Claw",   difficulty = "Insane" }, -- Task: CompleteMinigame(125, nil, "Insane")
        [9] = { name = "Robot Claw",   difficulty = "Insane" }  -- Task: CompleteMinigame(500)
    }
    
    while getgenv().Config.AutoMilestones do
        local playerData = LocalData:Get()
        local questsCompleted = playerData.QuestsCompleted or {}
        local minigameMilestones = MilestonesModule.Minigames
        
        local nextMilestoneNumber = 0

        -- Find the first uncompleted minigame milestone number
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
        
        -- Get the task from our hardcoded list
        local taskToDo = milestoneTasks[nextMilestoneNumber]
        
        if taskToDo then
            playMinigame(taskToDo.name, taskToDo.difficulty)
        else
            warn("-> Could not find a hardcoded task for milestone number: " .. nextMilestoneNumber)
            task.wait(5)
        end
    end
    
    print("--- Auto Minigame Milestones script has stopped. ---")
end)
