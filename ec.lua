-- ================== PART 1: LOAD LIBRARIES ==================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get the LocalData module, waiting for it if necessary
local LocalData = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Framework"):WaitForChild("Services"):WaitForChild("LocalData"))


-- ================== PART 2: HELPER FUNCTION TO GET PETS ==================
-- This function reads the player data and returns a table of formatted pet names
local function getEquippedPetsList()
    local formattedPetNames = {}
    local playerData = LocalData:Get()

    -- Ensure all required data exists before proceeding
    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then
        return {"Error: Could not load player data."}
    end

    -- Find the active team and its list of pet IDs
    [cite_start]local equippedTeamId = playerData.TeamEquipped -- e.g., 1 [cite: 129]
    local teamInfo = playerData.Teams[equippedTeamId]
    if not (teamInfo and teamInfo.Pets) then
        return {"Error: Could not find equipped team data."}
    end

    -- Create a fast lookup map of all pets by their ID
    local petDataMap = {}
    for _, petData in pairs(playerData.Pets) do
        if petData.Id then
            petDataMap[petData.Id] = petData
        end
    end

    -- Loop through the equipped pet IDs and build the formatted names
    for _, petId in ipairs(teamInfo.Pets) do
        local petInfo = petDataMap[petId]
        if petInfo then
            local nameParts = {}

            [cite_start]-- Add "Mythic" prefix if the pet has the Mythic property [cite: 56]
            if petInfo.Mythic then
                table.insert(nameParts, "Mythic")
            end
            
            table.insert(nameParts, petInfo.Name or "Unknown Pet")

            [cite_start]-- Add enchants if they exist [cite: 60, 62]
            if petInfo.Enchants and next(petInfo.Enchants) then
                local enchantNames = {}
                for _, enchantData in pairs(petInfo.Enchants) do
                    table.insert(enchantNames, enchantData.Id) -- e.g., "looter"
                end
                table.insert(nameParts, "(" .. table.concat(enchantNames, ", ") .. ")")
            end

            table.insert(formattedPetNames, table.concat(nameParts, " "))
        else
            table.insert(formattedPetNames, "Unknown Pet (ID: "..tostring(petId)..")")
        end
    end

    if #formattedPetNames == 0 then
        return {"No pets equipped"}
    end
    
    return formattedPetNames
end


-- ================== PART 3: BUILD THE FLUENT UI ==================
-- Create the main window
local Window = Fluent:CreateWindow({
    Title = "Pet Helper",
    SubTitle = "by you!",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Add a tab for our main functions
local MainTab = Window:AddTab({ Title = "Team", Icon = "rbxassetid://72488281780856" })

-- Add the dropdown, populated by our helper function
local PetDropdown = MainTab:AddDropdown("EquippedPetDropdown", {
    Title = "Equipped Pets",
    List = getEquippedPetsList(), -- Get the initial list of pets
    Multi = false,
    Default = 1,
})

-- Add a button to refresh the list
MainTab:AddButton({
    Title = "Refresh List",
    Description = "Update the dropdown if you change your team.",
    Callback = function()
        -- When clicked, get the new list and update the dropdown options
        local newList = getEquippedPetsList()
        PetDropdown:SetOptions(newList)
        Fluent:Notify({
            Title = "Refreshed",
            Content = "Pet list has been updated.",
            Duration = 3
        })
    end
})
