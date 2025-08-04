--[[
    ============================================================fartfartfartfart
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to false in your executor to stop the script
    AutoOpenAndClaimBoxes = true,

    -- List of box/gift types to check for and open from your inventory.
    BOXES_TO_OPEN = {
        "Mystery Box",
        "Light Box",
        "Festival Mystery Box"
    },

    -- The number of each box type to attempt to use (NOTE: This is no longer used for opening, but kept for other potential uses)
    USE_QUANTITY = 100,

    -- How long to wait (in seconds) before re-checking when you have no boxes.
    IdleCheckInterval = 15.0
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

-- ## Main Logic ##
task.spawn(function()
    print("--- Starting Auto Mystery Box script. ---")
    while getgenv().Config.AutoOpenAndClaimBoxes do
        -- ## PRE-CHECK: See if we have any boxes to open ##
        local playerData = LocalData:Get()
        local powerupsData = playerData and playerData.Powerups
        local hasBoxesToOpen = false

        if powerupsData then
            for _, boxName in ipairs(getgenv().Config.BOXES_TO_OPEN) do
                if powerupsData[boxName] and powerupsData[boxName] > 0 then
                    hasBoxesToOpen = true
                    break
                end
            end
        end

        if hasBoxesToOpen then
            print("--- Found boxes in inventory, starting open & claim cycle. ---")
            
            -- Phase 1: Use all specified boxes from inventory
            for _, boxName in ipairs(getgenv().Config.BOXES_TO_OPEN) do
                if powerupsData and powerupsData[boxName] and powerupsData[boxName] > 0 then
                    local ownedQuantity = powerupsData[boxName]
                    print("-> Attempting to use " .. ownedQuantity .. "x '" .. boxName .. "'")
                    local args = {"UseGift", boxName, ownedQuantity}
                    RemoteEvent:FireServer(unpack(args))
                    task.wait(1.0)
                end
            end

            -- Phase 2: Claim all spawned gifts in the workspace
            print("Waiting for gifts to spawn before claiming...")
            task.wait(3)

            local giftsFolder = workspace.Rendered:FindFirstChild("Gifts")
            if giftsFolder then
                local spawnedGifts = giftsFolder:GetChildren()
                if #spawnedGifts > 0 then
                    print("Found " .. #spawnedGifts .. " spawned gifts to claim.")
                    for i, gift in ipairs(spawnedGifts) do
                        local giftId = gift.Name
                        print("-> (" .. i .. "/" .. #spawnedGifts .. ") Claiming gift with ID: " .. giftId)
                        local args = {"ClaimGift", giftId}
                        RemoteEvent:FireServer(unpack(args))
                        task.wait(0.5)
                    end
                else
                    print("No spawned gifts found in the workspace.")
                end
            end
            
            -- Wait a moment before the next full check
            task.wait(5)
        else
            print("No boxes found in inventory. Checking again in " .. getgenv().Config.IdleCheckInterval .. " seconds...")
            task.wait(getgenv().Config.IdleCheckInterval)
        end
    end
    print("--- Auto Mystery Box script stopped. ---")
end)
