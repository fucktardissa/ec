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
    CycleDelay = 0
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

-- ## Anti-Transition Patcher ##
local function patchTransitions()
    pcall(function()
        print("Applying anti-transition patch...")
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
        if ScreenGui then
            local Transition = ScreenGui:FindFirstChild("Transition")
            if Transition then
                Transition.Enabled = false
                print("-> Transition screen disabled.")
            else
                warn("-> Could not find Transition screen to disable.")
            end
        end
    end)
end
patchTransitions() -- Run the patch at the start

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
    task.wait(3) -- Wait for minigame to load

    -- ## THE FIX: Apply extra delay BEFORE finishing specific minigames ##
    if name == "Pet Match" or name == "Cart Escape" then
        print("-> Applying special 5 second delay before finishing " .. name)
        task.wait(5)
    end
    
    RemoteEvent:FireServer("FinishMinigame")
    
    print("-> Minigame finished. Waiting for cooldown...")
    task.wait(getgenv().Config.CycleDelay)
end

-- ## Main Logic ##
task.spawn(function()
    print("--- Starting Auto Minigame Milestones script. ---")

    local milestoneTasks = {
        [1] = { name = "Robot Claw",   difficulty = "Easy" },
        [2] = { name = "Robot Claw",   difficulty = "Easy" },
        [3] = { name = "Robot Claw",   difficulty = "Easy" },
        [4] = { name = "Pet Match",    difficulty = "Insane" },
        [5] = { name = "Cart Escape",  difficulty = "Insane" },
        [6] = { name = "Robot Claw",   difficulty = "Insane" },
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
            playMinigame(taskToDo.name, taskToDo.difficulty)
        else
            warn("-> Could not find a hardcoded task for milestone number: " .. nextMilestoneNumber)
            task.wait(5)
        end
    end
    
    print("--- Auto Minigame Milestones script has stopped. ---")
end)
