-- ================== PART 1: LOAD LIBRARIES (Safely and 2) ==================
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


-- ================== PART 2: DATA-FETCHING FUNCTION ==================
local function getEquippedPetsList()
    -- This function remains the same, it reads data and returns a list of pet names
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
    SubTitle = "Equipped Team Viewer",
    TabWidth = 160,
    Size = UDim2.fromOffset(520, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Team", Icon = "swords" })
}

-- Get the initial list and store it. This is our starting point.
local lastKnownPetList = getEquippedPetsList()

local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Currently Equipped Pets",
    Description = "Shows pets from your active team. Refreshes automatically.",
    Values = lastKnownPetList,
    Multi = false,
    Default = 1,
})

Tabs.Main:AddButton({
    Title = "Refresh Pet List",
    Description = "Manually updates the list. It also updates automatically.",
    Callback = function()
        lastKnownPetList = getEquippedPetsList()
        PetDropdown:SetValues(lastKnownPetList)
        Fluent:Notify({ Title = "List Updated", Content = "The equipped pets dropdown has been manually refreshed.", Duration = 4 })
    end
})


-- ================== PART 4: AUTOMATIC REFRESH LOOP ==================
task.spawn(function()
    while task.wait(2) do -- Check for changes every 2 seconds
        if Fluent.Unloaded then break end -- Stop the loop if the UI is closed

        -- Get the current state of the equipped pets
        local currentPetList = getEquippedPetsList()

        -- A simple way to check if the tables are different is to compare them as strings
        if table.concat(currentPetList, ",") ~= table.concat(lastKnownPetList, ",") then
            -- If they are different, update the UI and our saved list
            PetDropdown:SetValues(currentPetList)
            lastKnownPetList = currentPetList -- Update the last known state
            
            Fluent:Notify({
                Title = "Team Updated",
                Content = "Pet list refreshed automatically.",
                Duration = 3
            })
        end
    end
end)


Window:SelectTab(1)

Fluent:Notify({
    Title = "Fluent Loaded",
    Content = "Pet Helper is now active and will auto-refresh.",
    Duration = 5
})
