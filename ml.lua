-- Standalone Auto Power Orb Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to false to stop the script
    AutoUsePowerOrbs = true,
    -- Delay in seconds between using each orb
    UseDelay = 1.5 
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

-- Gets a specific pet's data table by its ID
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

-- Checks a pet's level from its XP value
local function getPetLevel(xp)
    -- This is a placeholder conversion. If the XP-to-level formula is different,
    -- this function will need to be adjusted. This assumes a simple scale.
    -- For now, we only need to know if it's maxed or not. A high XP value implies level 25.
    if xp >= 400000 then -- Based on your example for a high-level pet
        return 25
    end
    return 1 -- Assume not max level otherwise
end


-- ## Main Automation Loop ##
print("Auto Power Orb script started. To stop, run: getgenv().Config.AutoUsePowerOrbs = false")

task.spawn(function()
    while getgenv().Config.AutoUsePowerOrbs do
        local playerData = LocalData:Get()
        
        -- Make sure we can access the player's team data
        if not (playerData and playerData.TeamEquipped and playerData.Teams) then
            print("Waiting for player data to load...")
            task.wait(5)
            continue -- Skip this iteration and try again
        end

        local equippedTeamId = playerData.TeamEquipped
        local teamInfo = playerData.Teams[equippedTeamId]

        if teamInfo and teamInfo.Pets then
            print("Checking equipped team for pets to level up...")
            local foundPetToLevel = false
            
            -- Loop through all pets on the equipped team
            for _, petId in ipairs(teamInfo.Pets) do
                local petInfo = getPetDataById(petId)
                
                if petInfo then
                    local petLevel = getPetLevel(petInfo.XP or 0)
                    
                    -- If the pet is not level 25, use a Power Orb on it
                    if petLevel < 25 then
                        print("Found pet '" .. petInfo.Name .. "' (Level < 25). Using Power Orb...")
                        
                        -- Fires the remote event to use the orb on this pet [cite: 1, 2]
                        local args = { "UsePowerOrb", petInfo.Id }
                        RemoteEvent:FireServer(unpack(args))
                        
                        foundPetToLevel = true
                        task.wait(getgenv().Config.UseDelay) -- Wait before using the next orb
                        break -- Break to re-check the list from the top
                    end
                end
            end
            
            if not foundPetToLevel then
                print("All equipped pets are level 25. Script will idle.")
                -- Set to false to prevent the script from running again
                getgenv().Config.AutoUsePowerOrbs = false 
            end
        end
        
        -- If we didn't find a pet, wait longer before checking again
        if not getgenv().Config.AutoUsePowerOrbs then
            break
        else
            task.wait(2)
        end
    end
    print("Auto Power Orb script finished or was stopped.")
end)
