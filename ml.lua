-- Standalone Auto Power Orb ScriptasdsdADSA

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoUsePowerOrbs = true,
    UseDelay = 0.25
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

-- ## Helper Functions ##

-- This now simply checks if the pet's XP is at the max level threshold.
local function isPetMaxLevel(xp)
    return xp >= 400000
end

local function getPetDataById(petId)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return nil end
    for _, petData in pairs(playerData.Pets) do
        if petData.Id == petId then
            return petData
        end
    end
    return nil
end

-- ## Main Logic ##
print("Auto Power Orb script started. Will process the equipped team once.")

task.spawn(function()
    local playerData = LocalData:Get()
    if not (playerData and playerData.TeamEquipped and playerData.Teams) then
        warn("Could not find player team data. Stopping.")
        return
    end

    local teamInfo = playerData.Teams[playerData.TeamEquipped]
    if teamInfo and teamInfo.Pets then
        print("Checking equipped team for pets to level up...")
        
        for _, petId in ipairs(teamInfo.Pets) do
            if not getgenv().Config.AutoUsePowerOrbs then
                print("Script stopped by user.")
                break 
            end

            local petInfo = getPetDataById(petId)
            if petInfo then
                -- Use the new, simpler check
                if not isPetMaxLevel(petInfo.XP or 0) then
                    print("Found pet '" .. petInfo.Name .. "' (Not Max Level). Attempting to use Power Orb...")
                    
                    local args = { "UsePowerOrb", petInfo.Id }
                    RemoteEvent:FireServer(unpack(args))
                    
                    task.wait(getgenv().Config.UseDelay)
                end
            end
        end
        
        print("Finished processing all equipped pets.")
    end

    getgenv().Config.AutoUsePowerOrbs = false 
    print("Auto Power Orb script has finished its run.")
end)
