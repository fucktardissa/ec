-- ================== PART 1: LOAD L23232323IBRARIES (Safely) ==================
local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Fluent library failed to load. The script cannot continue.")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Framework"):WaitForChild("Services"):WaitForChild("LocalData"))


-- ================== PART 2: DATA & CONFIG ==================
-- List of all possible enchants for the dropdown
local AllEnchants = {
    "Bubbler I", "Bubbler II", "Bubbler III", "Bubbler IV", "Bubbler V",
    "Gleaming I", "Gleaming II", "Gleaming III",
    "Looter I", "Looter II", "Looter III", "Looter IV", "Looter V",
    "Team Up I", "Team Up II", "Team Up III", "Team Up IV", "Team Up V",
    "High Roller", "Infinity", "Magnetism", "Secret Hunter", "Ultra Roller",
    "Determination", "Shiny Seeker"
}

-- This function reads player data and returns a list of formatted pet names.
local function getEquippedPetsList()
    local formattedPetNames = {}
    local playerData = LocalData:Get()

    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then
        return {"Error: Could not read player data."}
    end

    local equippedTeamId = playerData.TeamEquipped
    local teamInfo = playerData.Teams[equippedTeamId]
    if not (teamInfo and teamInfo.Pets) then
        return {"Error: Could not find equipped team info."}
    end

    local petDataMap = {}
    for _, petData in pairs(playerData.Pets) do
        if petData.Id then
            petDataMap[petData.Id] = petData
        end
    end

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
local Window = Fluent:CreateWindow({
    Title = "Pet Helper",
    SubTitle = "Enchant Reroller",
    TabWidth = 160,
    Size = UDim2.fromOffset(540, 450),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Reroller", Icon = "swords" })
}

-- Section for selecting pets
Tabs.Main:AddParagraph({Title = "Pet Selection"})

local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Equipped Pets",
    Description = "Select which equipped pets to reroll.",
    Values = getEquippedPetsList(),
    Multi = true, -- Changed to true to allow multiple selections
    Default = {}, -- Changed to an empty table for multi-select
})

-- Section for selecting target enchants
Tabs.Main:AddParagraph({Title = "Enchant Targeting"})

local EnchantDropdown = Tabs.Main:AddDropdown("TargetEnchantsDropdown", {
    Title = "Target Enchants",
    Description = "Select one or more enchants to stop at.",
    Values = AllEnchants,
    Multi = true,
    Default = {},
})

-- ================== PART 4: REFRESH LOGIC ==================
local lastKnownPetList = getEquippedPetsList()

Tabs.Main:AddButton({
    Title = "Refresh Pet List",
    Description = "Manually updates the list of available pets.",
    Callback = function()
        lastKnownPetList = getEquippedPetsList()
        PetDropdown:SetValues(lastKnownPetList)
        Fluent:Notify({ Title = "List Updated", Content = "The equipped pets dropdown has been manually refreshed.", Duration = 4 })
    end
})

task.spawn(function()
    while task.wait(2) do
        if Fluent.Unloaded then break end

        local currentPetList = getEquippedPetsList()
        if table.concat(currentPetList, ",") ~= table.concat(lastKnownPetList, ",") then
            PetDropdown:SetValues(currentPetList)
            lastKnownPetList = currentPetList
            Fluent:Notify({ Title = "Team Updated", Content = "Pet list refreshed automatically.", Duration = 3 })
        end
    end
end)


Window:SelectTab(1)
Fluent:Notify({ Title = "Fluent Loaded", Content = "Pet Helper is now active.", Duration = 5 })
