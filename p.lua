-- Standalone Auto-Craft Potions Script

--[[
    ============================================================
    -- ## CONFIGURATION ##
    -- Add the names of the potions you want to craft into the list below.
    ============================================================
]]
local Config = {
    -- Add any of the following potion names: "Coins", "Mythic", "Lucky", "Speed", "Tickets"
    PotionsToCraft = {
        "Coins",
        "Lucky",
        "Mythic",
        "Speed"
    },
    
    -- Delay in seconds between crafting each different type of potion.
    ActionDelay = 1.0 
}

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("RemoteEvent")

print("--- Starting Auto-Craft Potions script. ---")

if #Config.PotionsToCraft == 0 then
    print("No potions listed in the config to craft.")
else
    -- Loop through each potion name you listed in the config
    for _, potionName in ipairs(Config.PotionsToCraft) do
        print("Crafting all tiers of '" .. potionName .. "' potions...")
        
        -- Fires the remote event based on the structure you provided
        local args = { "CraftPotion", potionName, 2, true }
        RemoteEvent:FireServer(unpack(args))
        
        task.wait(Config.ActionDelay)
    end
end

print("--- Auto-Craft Potions script finished. ---")
