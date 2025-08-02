-- Auto Claw Minigame Script (Ultimate Dual-Mode)asdasdfafsasfgfgsa
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Fluent UI Setup
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Auto Claw Ultimate",
    SubTitle = "Intelligent Dual-Mode System",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 520),
    Acrylic = true,
    Theme = "Dark"
})

-- Configuration
local Settings = {
    Cooldown = 65,
    Difficulty = "Insane",
    Enabled = false,
    UseItemMethod = false,
    GrabDelay = 0.5,
    AutoSwitchMode = true, -- New: Auto fallback to FinishMinigame if no items found
    DebugMode = false
}

-- Remote Setup
local remote = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

-- Enhanced Detection System
local function findClawItems()
    local startTime = os.clock()
    local playerGui = Players.LocalPlayer.PlayerGui
    local screenGui = playerGui:FindFirstChild("ScreenGui")
    local items = {}

    if not screenGui then
        if Settings.DebugMode then
            warn("ScreenGui not found! PlayerGui contents:")
            for _, child in ipairs(playerGui:GetChildren()) do
                print(" - "..child.Name)
            end
        end
        return items
    end

    -- Precise scanning with multiple pattern matches
    for _, child in ipairs(screenGui:GetDescendants()) do
        if child:IsA("RemoteEvent") then
            local idMatch = child.Name:match("^[Cc]law[Ii]tem([%-_%d%a]+)$") or child.Name:match("^ClawItem(.+)$")
            if idMatch then
                table.insert(items, {
                    Object = child,
                    ID = idMatch,
                    Path = child:GetFullName()
                })
            end
        end
    end

    if Settings.DebugMode then
        print(string.format("Scanned %d descendants in %.3f seconds", #screenGui:GetDescendants(), os.clock()-startTime))
    end
    
    return items
end

-- Dual-Mode Execution Logic
local function executeClawSequence()
    -- Phase 1: Skip Cooldown
    local skipArgs = {
        [1] = "SkipMinigameCooldown",
        [2] = "Robot Claw"
    }
    remote:FireServer(unpack(skipArgs))
    task.wait(0.5)

    -- Phase 2: Start Minigame
    local startArgs = {
        [1] = "StartMinigame",
        [2] = "Robot Claw",
        [3] = Settings.Difficulty
    }
    remote:FireServer(unpack(startArgs))
    task.wait(2) -- Allow GUI to initialize

    -- Phase 3: Execution Strategy
    if Settings.UseItemMethod then
        local items = findClawItems()
        if #items > 0 then
            for _, item in ipairs(items) do
                local grabArgs = {
                    [1] = "GrabMinigameItem",
                    [2] = item.ID
                }
                remote:FireServer(unpack(grabArgs))
                if Settings.DebugMode then
                    print("Grabbed:", item.ID, "| Path:", item.Path)
                end
                task.wait(Settings.GrabDelay)
            end
            return true
        else
            if Settings.AutoSwitchMode then
                Fluent:Notify({
                    Title = "Mode Switch",
                    Content = "No items found, using FinishMinigame",
                    Duration = 3
                })
                remote:FireServer("FinishMinigame")
                return false
            end
        end
    else
        remote:FireServer("FinishMinigame")
        return true
    end
end

-- UI Construction
local Tabs = {
    Main = Window:AddTab({ Title = "Automation", Icon = "play" }),
    Settings = Window:AddTab({ Title = "Configuration", Icon = "settings" }),
    Debug = Window:AddTab({ Title = "Debug Tools", Icon = "bug" })
}

-- Main Control Panel
Tabs.Main:AddToggle("AutoToggle", {
    Title = "Enable Automation",
    Description = "Starts the automated sequence",
    Default = Settings.Enabled,
    Callback = function(value)
        Settings.Enabled = value
        if value then
            coroutine.wrap(function()
                while Settings.Enabled do
                    local success, err = pcall(executeClawSequence)
                    if not success then
                        Fluent:Notify({
                            Title = "Execution Error",
                            Content = tostring(err),
                            Duration = 5
                        })
                    end
                    task.wait(Settings.Cooldown)
                end
            end)()
            Fluent:Notify({
                Title = "System Active",
                Content = string.format("%s mode engaged", Settings.UseItemMethod and "Precision" or "Instant"),
                Duration = 3
            })
        end
    end
}):AddTooltip("Automatically collects claw items")

-- Mode Configuration
Tabs.Main:AddToggle("MethodToggle", {
    Title = "Precision Mode",
    Description = "Grabs items individually when enabled",
    Default = Settings.UseItemMethod,
    Callback = function(value)
        Settings.UseItemMethod = value
        Fluent:Notify({
            Title = "Mode Changed",
            Content = value and "Precision: Grabbing items" or "Instant: Fast completion",
            Duration = 3
        })
    end
})

Tabs.Main:AddToggle("AutoSwitchToggle", {
    Title = "Auto Fallback",
    Description = "Switches to Instant mode if no items found",
    Default = Settings.AutoSwitchMode,
    Callback = function(value)
        Settings.AutoSwitchMode = value
    end
})

-- Performance Settings
Tabs.Settings:AddSlider("CooldownSlider", {
    Title = "Cycle Cooldown",
    Description = "Delay between attempts (seconds)",
    Default = Settings.Cooldown,
    Min = 5,
    Max = 120,
    Rounding = 0,
    Callback = function(value)
        Settings.Cooldown = value
    end
})

Tabs.Settings:AddDropdown("DifficultyDropdown", {
    Title = "Difficulty Preset",
    Default = Settings.Difficulty,
    Values = {"Easy", "Medium", "Hard", "Insane"},
    Callback = function(value)
        Settings.Difficulty = value
    end
})

-- Advanced Controls
Tabs.Settings:AddSlider("GrabDelaySlider", {
    Title = "Grab Interval",
    Description = "Delay between item grabs (seconds)",
    Default = Settings.GrabDelay,
    Min = 0.1,
    Max = 2,
    Rounding = 1,
    Callback = function(value)
        Settings.GrabDelay = value
    end
})

-- Debug Tools
Tabs.Debug:AddToggle("DebugToggle", {
    Title = "Debug Mode",
    Description = "Enables detailed logging",
    Default = Settings.DebugMode,
    Callback = function(value)
        Settings.DebugMode = value
    end
})

Tabs.Debug:AddButton({
    Title = "Scan Items Now",
    Description = "Force a detection scan",
    Callback = function()
        local items = findClawItems()
        if #items > 0 then
            local itemList = {}
            for _, item in ipairs(items) do
                table.insert(itemList, string.format("%s (ID: %s)", item.Path, item.ID))
            end
            Fluent:Notify({
                Title = "Scan Results",
                Content = string.format("%d items found", #items),
                SubContent = table.concat(itemList, "\n"),
                Duration = 8
            })
            print("ClawItems found:\n"..table.concat(itemList, "\n"))
        else
            Fluent:Notify({
                Title = "Scan Complete",
                Content = "No claw items detected",
                Duration = 5
            })
        end
    end
})

Tabs.Debug:AddButton({
    Title = "Test Finish",
    Description = "Manually trigger completion",
    Callback = function()
        remote:FireServer("FinishMinigame")
    end
})

-- System Finalization
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("AutoClawUltimate")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)

-- Initialization
Fluent:Notify({
    Title = "System Ready",
    Content = "Auto Claw Ultimate initialized",
    SubContent = "Configure settings before activation",
    Duration = 5
})
