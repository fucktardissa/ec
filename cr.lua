-- Standalone Auto Code Redemption Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Set to true to run the script. It will turn itself off when finished.
    AutoRedeemCodes = true,
    
    -- Delay in seconds between redeeming each code to prevent network spam.
    RedeemDelay = 1.0
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteFunction")
local CodesModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Codes"))

-- ## Main Logic ##
task.spawn(function()
    if not getgenv().Config.AutoRedeemCodes then return end
    
    print("--- Starting Auto Code Redemption script. ---")

    if not CodesModule then
        warn("Could not load the Codes module. Stopping.")
        return
    end

    local codesToRedeem = {}
    -- Get all code names from the keys of the CodesModule table
    for codeName, _ in pairs(CodesModule) do
        table.insert(codesToRedeem, codeName)
    end

    if #codesToRedeem == 0 then
        print("No codes found in the game's code list.")
    else
        print("Found " .. #codesToRedeem .. " total codes in the game. Attempting to redeem all...")
        for i, codeName in ipairs(codesToRedeem) do
            print("-> (" .. i .. "/" .. #codesToRedeem .. ") Attempting to redeem code: '" .. codeName .. "'")
            
            -- Use a pcall to safely call the remote function. This prevents errors if a code is expired or already redeemed.
            local success, result = pcall(function()
                return RemoteFunction:InvokeServer("RedeemCode", codeName)
            end)

            if not success then
                warn("   Error while redeeming code '" .. codeName .. "': " .. tostring(result))
            end
            
            task.wait(getgenv().Config.RedeemDelay)
        end
    end

    print("--- Auto Code Redemption script finished. ---")
    getgenv().Config.AutoRedeemCodes = false
end)
