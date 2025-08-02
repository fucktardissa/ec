local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "shitass comp script",
    SubTitle = "🙏🙏🙏",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Create tabs
local ChangelogTab = Window:AddTab({ Title = "Changelog", Icon = "menu" })
local AutoFarmingTab = Window:AddTab({ Title = "Auto Farming", Icon = "dollar-sign" })
local HatchingTab = Window:AddTab({ Title = "Hatching", Icon = "egg" })
local RiftsTab = Window:AddTab({ Title = "Rifts", Icon = "cloud" })
local CompetitiveTab = Window:AddTab({ Title = "Competitive", Icon = "sword" })
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "plus" })
local WebhooksTab = Window:AddTab({ Title = "Webhooks", Icon = "link" })
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
local riftLoopRunning = true

-- Move everything existing into CompetitiveTab
local MainTab = CompetitiveTab

local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local remote = replicatedStorage.Shared.Framework.Network.Remote.Event
local worldMapRemote = replicatedStorage.Client.Gui.Frames.WorldMap

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Tween control
local tweenActive = false
local tweenSpeed = 100

-- Add speed slider to Rifts tab
local SettingsSection = RiftsTab:AddSection("Tween Speed")
local SpeedSlider = SettingsSection:AddSlider("TweenSpeed", {
    Title = "Tween Speed (studs/sec)",
    Description = "How fast you move to rifts",
    Default = 100,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value)
        tweenSpeed = value
    end
})

-- Utility functions
local function cleanName(str)
    if not str then return "Unknown" end
    local cleaned = str:gsub("[-_]", " ")
    cleaned = cleaned:gsub("(%a)([%w]*)", function(first, rest) 
        return first:upper()..rest:lower() 
    end)
    return cleaned
end

-- Enhanced teleport function with WorldMap integration
local function teleportToRift(riftPosition)
    if tweenActive then return end
    tweenActive = true
    
    -- Fire teleport remote first
    local arguments = {
        [1] = "Teleport",
        [2] = "Workspace.Worlds.The OverWorld.Islands.Zen.Island.Portal.Spawn"
    }
    remote:FireServer(unpack(arguments))
    
    -- Wait for teleport to complete (2 second timeout)
    local loadStart = os.time()
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        if os.time() - loadStart > 2 then
            warn("Teleport timeout reached")
            tweenActive = false
            return
        end
        task.wait(0.1)
    end
    
    -- Get fresh references after teleport
    character = player.Character
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    
    -- Tween implementation
    local startPos = humanoidRootPart.Position
    local distance = (startPos - riftPosition).Magnitude
    local time = distance / tweenSpeed
    
    -- Save original state
    local originalWalkSpeed = humanoid.WalkSpeed
    local originalAutoRotate = humanoid.AutoRotate
    
    -- Configure for tween
    humanoid.WalkSpeed = 0
    humanoid.AutoRotate = false
    
    -- Create path waypoints
    local waypoints = {}
    local direction = (riftPosition - startPos).Unit
    local maxStep = 50
    
    for d = 0, distance, maxStep do
        local waypointPos = startPos + (direction * math.min(d, distance))
        table.insert(waypoints, waypointPos)
    end
    
    -- Tween through waypoints
    local currentTween
    local jumpConnection
    local completed = false
    
    local function cleanup()
        if jumpConnection then jumpConnection:Disconnect() end
        humanoid.WalkSpeed = originalWalkSpeed
        humanoid.AutoRotate = originalAutoRotate
        tweenActive = false
    end
    
    jumpConnection = humanoid.Jumping:Connect(function()
        if currentTween then currentTween:Cancel() end
        completed = true
        cleanup()
    end)
    
    for _, waypoint in ipairs(waypoints) do
        if completed then break end
        
        local segmentTime = (waypoint - humanoidRootPart.Position).Magnitude / tweenSpeed
        currentTween = tweenService:Create(
            humanoidRootPart,
            TweenInfo.new(segmentTime, Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(waypoint)}
        )
        currentTween:Play()
        currentTween.Completed:Wait()
    end
    
    cleanup()
end

-- Create Rifts UI
local RiftListSection = RiftsTab:AddSection("Available Rifts")
local riftButtons = {}

task.spawn(function()
    while riftLoopRunning do
        pcall(function()
            local rifts = workspace:WaitForChild("Rendered"):WaitForChild("Rifts")
            
            for _, rift in ipairs(rifts:GetChildren()) do
                local name = cleanName(rift.Name)
                local display = rift:FindFirstChild("Display")
                local timerText = "?"
                local luckText = "N/A"

                if display then
                    local gui = display:FindFirstChild("SurfaceGui")
                    if gui then
                        local timer = gui:FindFirstChild("Timer")
                        if timer then timerText = timer.Text end
                        local icon = gui:FindFirstChild("Icon")
                        if icon then
                            local luck = icon:FindFirstChild("Luck")
                            if luck then luckText = luck.Text end
                        end
                    end
                end

                if not riftButtons[name] then
                    riftButtons[name] = RiftListSection:AddButton({
                        Title = name,
                        Description = string.format("Timer: %s | Luck: %s", timerText, luckText),
                        Callback = function()
                            teleportToRift(rift:GetPivot().Position + Vector3.new(0, 3, -10))
                        end
                    })
                else
                    riftButtons[name]:SetDesc(string.format("Timer: %s | Luck: %s", timerText, luckText))
                end
            end

            for btnName, btn in pairs(riftButtons) do
                local exists = false
                for _, rift in ipairs(rifts:GetChildren()) do
                    if cleanName(rift.Name) == btnName then
                        exists = true
                        break
                    end
                end
                if not exists then
                    btn:Destroy()
                    riftButtons[btnName] = nil
                end
            end
        end)
        task.wait(1.5)
    end
end)

-- Competitive Tab Elements
local totalPointsEarned = 0
local PointsParagraph = MainTab:AddParagraph({
    Title = "Session Points",
    Content = "0"
})

local eggPositions = {
    ["Common Egg"] = Vector3.new(-83.86031341552734, 10.116671562194824, 1.5749061107635498),
    ["Spotted Egg"] = Vector3.new(-93.96259307861328, 10.116673469543457, 7.4115400314331055),
    ["Iceshard Egg"] = Vector3.new(-117.0664291381836, 10.116671562194824, 7.745338916778564),
    ["Spikey Egg"] = Vector3.new(-124.588134765625, 10.116671562194824, 4.580596446990967),
    ["Magma Egg"] = Vector3.new(-133.02085876464844, 10.116593360900879, -1.5519139766693115),
    ["Crystal Egg"] = Vector3.new(-140.2029571533203, 10.116671562194824, -8.3678560256958),
    ["Lunar Egg"] = Vector3.new(-143.85606384277344, 10.116650581359863, -15.931164741516113),
    ["Void Egg"] = Vector3.new(-145.9164276123047, 10.116620063781738, -26.1324405670166),
    ["Hell Egg"] = Vector3.new(-145.17674255371094, 10.116671562194824, -36.78310775756836),
    ["Nightmare Egg"] = Vector3.new(-142.350341796875, 10.116673469543457, -45.15552520751953),
    ["Rainbow Egg"] = Vector3.new(-134.49424743652344, 10.116379737854004, -52.360511779785156),
}

local taskAutomationEnabled = false

local function tweenToPosition(position)
    local distance = (humanoidRootPart.Position - position).Magnitude
    local speed = 25
    local time = distance / speed
    local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local goal = {CFrame = CFrame.new(position)}
    local tween = tweenService:Create(humanoidRootPart, tweenInfo, goal)
    tween:Play()
    return tween
end

local function hatchEgg(eggName)
    local eggPosition = eggPositions[eggName]
    if eggPosition then
        local tween = tweenToPosition(eggPosition)
        tween.Completed:Wait()

        local maxAttempts = 50
        local threshold = 3
        local attempts = 0
        while (humanoidRootPart.Position - eggPosition).Magnitude > threshold and attempts < maxAttempts do
            task.wait(0.1)
            attempts += 1
        end

        if attempts < maxAttempts then
            task.wait(0.2)
            remote:FireServer("HatchEgg", eggName, 6)
        else
            warn("[❌] Could not reach egg:", eggName)
        end
    else
        warn("[❌] Invalid egg name:", eggName)
    end
end

local function rerollTask()
    remote:FireServer("CompetitiveReroll", 3)
end

local function extractEggName(fullText)
    local text = fullText:gsub("Hatch", "")
    text = text:gsub("^%s*%d+%s*", "")
    text = text:gsub("%s*Eggs?$", "")
    text = text:match("^%s*(.-)%s*$")
    return text
end

local function deepFindHatchLabel(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") and child.Text:lower():find("hatch") then
            return child
        elseif child:IsA("Frame") then
            local found = deepFindHatchLabel(child)
            if found then return found end
        end
    end
end

local function completeTask(taskFrame)
    local hatchLabel = deepFindHatchLabel(taskFrame)
    if not hatchLabel then return false end

    local fullTitle = hatchLabel.Text
    local selectedSkipTypes = SkipPetTypesDropdown.Value

    for _, skipType in ipairs(selectedSkipTypes) do
        if fullTitle:lower():find(skipType:lower()) then
            rerollTask()
            return true
        end
    end

    if fullTitle:lower():find("play for 15 minutes") or fullTitle:lower():find("play for 10 minutes") then
        if SkipPlaytimeToggle.Value then
            rerollTask()
            return true
        end
    end

    if fullTitle:lower():find("mythic") and SkipMythicToggle.Value then
        rerollTask()
        return true
    end

    if fullTitle:lower():find("shiny") and SkipShinyToggle.Value then
        rerollTask()
        return true
    end

    if fullTitle:lower():find("legendary") then
        hatchEgg("Spikey Egg")
    elseif fullTitle:lower():find("common") or fullTitle:lower():find("epic") then
        return false
    else
        local extractedEggName = extractEggName(fullTitle)
        for eggName, _ in pairs(eggPositions) do
            if extractedEggName:lower():find(eggName:lower():gsub(" egg", "")) then
                hatchEgg(eggName)
                break
            end
        end
    end

    local points = tonumber(fullTitle:match("(%d+)%s*[Pp][Oo][Ii][Nn][Tt][Ss]"))
    if points then
        totalPointsEarned += points
        PointsParagraph:SetValue(tostring(totalPointsEarned))
    end

    return true
end

local function taskManager()
    while taskAutomationEnabled do
        local success = pcall(function()
            local tasksFolder = player.PlayerGui
                :WaitForChild("ScreenGui")
                :WaitForChild("Competitive")
                :WaitForChild("Frame")
                :WaitForChild("Content")
                :WaitForChild("Tasks")

            local frames = {}
            for _, taskFrame in ipairs(tasksFolder:GetChildren()) do
                if taskFrame:IsA("Frame") then
                    table.insert(frames, taskFrame)
                end
            end

            for i, taskFrame in ipairs(frames) do
                local hatchLabel = deepFindHatchLabel(taskFrame)
                local text = hatchLabel and hatchLabel.Text:lower()
                if text then
                    if SkipMythicToggle.Value and text:find("mythic") then
                        remote:FireServer("CompetitiveReroll", i)
                        return
                    end
                    if SkipShinyToggle.Value and text:find("shiny") then
                        remote:FireServer("CompetitiveReroll", i)
                        return
                    end
                end
            end

            local taskHandled = false
            for _, taskFrame in ipairs(frames) do
                if completeTask(taskFrame) then
                    taskHandled = true
                    break
                end
            end

            if not taskHandled then
                hatchEgg("Common Egg")
            end
        end)

        if not success then
            warn("Task manager cycle error")
        end

        task.wait(1)
    end
end

-- Create Task Automation UI in Competitive tab
local TaskSection = MainTab:AddSection("Task Automation")

local AutoTasksToggle = TaskSection:AddToggle("AutoTasks", {
    Title = "Auto Complete Tasks",
    Default = false
})

local SkipMythicToggle = TaskSection:AddToggle("SkipMythic", {
    Title = "Skip Mythic Tasks",
    Default = false
})

local SkipShinyToggle = TaskSection:AddToggle("SkipShiny", {
    Title = "Skip Shiny Tasks",
    Default = true
})

local SkipPlaytimeToggle = TaskSection:AddToggle("SkipPlaytime", {
    Title = "Skip Playtime Tasks",
    Default = true
})

local SkipPetTypesDropdown = TaskSection:AddDropdown("SkipPetTypes", {
    Title = "Pet Types to Skip",
    Values = { "Common", "Unique", "Epic", "Legendary" },
    Multi = true,
    Default = {}
})

AutoTasksToggle:OnChanged(function()
    taskAutomationEnabled = AutoTasksToggle.Value
    if taskAutomationEnabled then
        Fluent:Notify({
            Title = "Auto Manager",
            Content = "✅ Auto Tasking Enabled!",
            Duration = 5
        })
        task.spawn(taskManager)
    else
        Fluent:Notify({
            Title = "Auto Manager",
            Content = "🛑 Auto Tasking Disabled!",
            Duration = 5
        })
    end
end)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Auto Task Manager",
    Content = "✅ Script loaded successfully.",
    Duration = 5
})
