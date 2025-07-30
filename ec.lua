-- ================== PART 1: LOAD LIBRARIES (Safely) ==================
local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Fluent library failed to load. The script cannot continue.")
    -- You could add a fallback notification for the user here if you wanted.
    return -- Stop the script if the library is missing
end

-- Now we can safely get the other services and modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Framework"):WaitForChild("Services"):WaitForChild("LocalData"))


-- ================== PART 2: DATA-FETCHING FUNCTION ==================
-- This function reads player data and returns a list of formatted pet names.
local function getEquippedPetsList()
    local formattedPetNames = {}
    local playerData = LocalData:Get()

    -- More robust checks to prevent errors
    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then
        return {"Error: Could not read player data."}
    end

    local equippedTeamId = playerData.TeamEquipped
    local teamInfo = playerData.Teams[equippedTeamId]
    if not (teamInfo and teamInfo.Pets) then
        return {"Error: Could not find equipped team info."}
    end

    -- Create a map for quick pet lookups
    local petDataMap = {}
    for _, petData in pairs(playerData.Pets) do
        if petData.Id then
            petDataMap[petData.Id] = petData
        end
    end

    -- Build the formatted names
    for _, petId in ipairs(teamInfo.Pets) do
        local petInfo = petDataMap[petId]
        if petInfo then
            local nameParts = {}
            if petInfo.Mythic then table.insert(nameParts, "Mythic") end
            table.insert(nameParts, petInfo.Name or "Unknown Pet")

            if petInfo.Enchants and next(petInfo.Enchants) then
                local enchantNames = {}
                for _, enchantData in pairs(petInfo.Enchants) do
                    table.insert(enchantNames, enchantData.Id)
                end
                table.insert(nameParts, "(" .. table.concat(enchantNames, ", ") .. ")")
            end
            table.insert(formattedPetNames, table.concat(nameParts, " "))
        else
            table.insert(formattedPetNames, "Unknown Pet (ID: "..tostring(petId)..")")
        end
    end

    if #formattedPetNames == 0 then return {"No pets equipped"} end
    return formattedPetNames
end


-- ================== PART 3: BUILD THE FLUENT UI ==================
-- Use the structure from the example
local Window = Fluent:CreateWindow({
    Title = "Pet Helper",
    SubTitle = "Equipped Team Viewer",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Team", Icon = "swords" }) -- Using a Lucide icon
}

-- Add the dropdown, using the 'Values' key as seen in the example
local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Currently Equipped Pets",
    Description = "Shows pets from your active team.",
    Values = getEquippedPetsList(), -- Use 'Values' instead of 'List'
    Multi = false,
    Default = 1,
})

-- Add a refresh button, following the example's structure
Tabs.Main:AddButton({
    Title = "Refresh Pet List",
    Description = "Click this if you change your equipped team or pet enchants.",
    Callback = function()
        local newList = getEquippedPetsList()
        PetDropdown:SetValues(newList) -- Use SetValues to update the dropdown
        Fluent:Notify({
            Title = "List Updated",
            Content = "The equipped pets dropdown has been refreshed.",
            Duration = 4
        })
    end
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent Loaded",
    Content = "Pet Helper script is now active.",
    Duration = 5
})
