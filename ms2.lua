local Config = {
    AutoMilestones = true
}
getgenv().Config = Config

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MilestonesModule = require(ReplicatedStorage.Shared.Data.Milestones)

local function patchTransitions()
    pcall(function()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
        if ScreenGui then
            local Transition = ScreenGui:FindFirstChild("Transition")
            if Transition then
                Transition.Enabled = false
            end
        end
    end)
end
patchTransitions()

local function formatTaskDescription(task)
    local parts = {}
    table.insert(parts, task.Type)
    if task.Amount then table.insert(parts, task.Amount) end
    if task.Name then table.insert(parts, "'" .. task.Name .. "'") end
    if task.Difficulty then table.insert(parts, "on " .. task.Difficulty) end
    return table.concat(parts, " ")
end

local function playMinigameFast(name, difficulty)
    local targetDifficulty = difficulty or "Easy"
    
    RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
    task.wait(1.5)
    RemoteEvent:FireServer("SkipMinigameCooldown", name)
    RemoteEvent:FireServer("StartMinigame", name, targetDifficulty)
    task.wait(0.5)
    RemoteEvent:FireServer("FinishMinigame")
end

task.spawn(function()
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

        for _, tierData in pairs(minigameMilestones.Tiers) do
            for _, _ in ipairs(tierData.Levels) do
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
            getgenv().Config.AutoMilestones = false
            break
        end
        
        local taskToDo = milestoneTasks[nextMilestoneNumber]
        
        if taskToDo then
            if nextMilestoneNumber == 8 or nextMilestoneNumber == 9 then
                getgenv().reportTime = 60
                getgenv().tryCollectMultipleTimes = false
                getgenv().Config.AutoMilestones = false
                loadstring(game:HttpGet("https://raw.githubusercontent.com/IdiotHub/Scripts/refs/heads/main/BGSI/AutoClaw.lua"))()
            else
                playMinigameFast(taskToDo.name, taskToDo.difficulty)
            end
        else
            task.wait(5)
        end
        task.wait(1)
    end
end)
