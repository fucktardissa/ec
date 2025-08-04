-- Standalone Auto Mastery Script (Target Level Version)

--[[
    ============================================================
    -- ## SETUP & CONFIGURATION ##
    ============================================================
]]

-- IMPORTANT: Update this path to point to the Mastery module you provided.
local pathToMasteryModule = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Mastery")

local Config = {
    -- Set your desired target level for each mastery path.
    TargetLevels = {
        Pets = 0,
        Buffs = 0,
        Shops = 11,
        Minigames = 0,
        Rifts = 0 -- This path is also in the Mastery module
    },
    
    -- Delay in seconds between each upgrade call.
    ActionDelay = 0.5 
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- Get essential services and modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local MasteryData = require(pathToMasteryModule)
local RemoteEvent = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

print("--- Starting Auto Mastery script. ---")

local playerData = LocalData:Get()
if not playerData then
    warn("Could not load player data. Stopping.")
    return
end

-- Get the player's current mastery levels, or an empty table if none exist.
local currentMasteryLevels = playerData.MasteryLevels or {}

-- The five mastery paths defined in the Mastery module
local masteryPaths = {"Buffs", "Pets", "Shops", "Minigames", "Rifts"}

-- Loop through each mastery path
for _, pathName in ipairs(masteryPaths) do
    -- Get the current level for this path. Defaults to 0 if not present in player data.
    local currentLevel = currentMasteryLevels[pathName] or 0
    
    -- Get the target level from the config.
    local targetLevel = Config.TargetLevels[pathName] or 0
    
    -- Get the maximum possible level from the Mastery data module.
    local maxLevel = #MasteryData.Upgrades[pathName].Levels
    
    -- Ensure the target level doesn't exceed the game's maximum level.
    local effectiveTarget = math.min(targetLevel, maxLevel)
    
    -- Calculate how many upgrades are needed.
    local upgradesNeeded = effectiveTarget - currentLevel

    if upgradesNeeded > 0 then
        print("Upgrading '" .. pathName .. "' from level " .. currentLevel .. " to " .. effectiveTarget .. " (" .. upgradesNeeded .. " times)...")
        for i = 1, upgradesNeeded do
            local args = { "UpgradeMastery", pathName }
            RemoteEvent:FireServer(unpack(args))
            task.wait(Config.ActionDelay)
        end
    else
        print("Path '" .. pathName .. "' is already at or above the target level. Skipping.")
    end
end

print("--- Auto Mastery script finished. ---")
