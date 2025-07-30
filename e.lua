-- =================
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

-- Define paths to the remote function (reroll both) and remote event (reroll one)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local RerollEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- ================== PART 2: DATA, CONFIG, & STATE ==================
local isRerolling = false
local Options = Fluent.Options

-- A comprehensive list of all possible enchants
local AllEnchants = {
    "Bubbler I", "Bubbler II", "Bubbler III", "Bubbler IV", "Bubbler V", "Gleaming I", "Gleaming II", "Gleaming III",
    "Looter I", "Looter II", "Looter III", "Looter IV", "Looter V", "Team Up I", "Team Up II", "Team Up III", "Team Up IV", "Team Up V",
    "High Roller", "Infinity", "Magnetism", "Secret Hunter", "Ultra Roller", "Determination", "Shiny Seeker"
}
local enchantLookup = {}

-- ================== PART 3: HELPER FUNCTIONS & SETUP ==================
-- Parses an enchant's full name (e.g., "Looter V") into its ID ("looter") and level (5)
local function parseEnchantName(name)
    local romanMap = { I = 1, II = 2, III = 3, IV = 4, V = 5 }
    local baseName, roman = name:match("^(.*) (%S+)$")
    local level = romanMap[roman]
    if baseName and level then
        return { id = baseName:lower():gsub(" ", "-"), level = level }
    else
        return { id = name:lower():gsub(" ", "-"), level = 1 }
    end
end

-- Pre-populate the lookup table for quick access
for _, fullName in ipairs(AllEnchants) do
    local parsed = parseEnchantName(fullName)
    if not enchantLookup[parsed.id] then enchantLookup[parsed.id] = {} end
    enchantLookup[parsed.id][parsed.level] = fullName
end

-- Helper to find a specific pet's data table by its ID
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

-- Retrieves and formats the player's currently equipped pets for display
local function getEquippedPetsForDisplay()
    local petsForDisplay = {}
    local playerData = LocalData:Get()
    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then return {} end

    local equippedTeamId = playerData.TeamEquipped
    local teamInfo = playerData.Teams[equippedTeamId]
    if not (teamInfo and teamInfo.Pets) then return {} end
    
    for _, petId in ipairs(teamInfo.Pets) do
        local petInfo = getPetDataById(petId)
        if petInfo then
            local nameParts = {}
            if petInfo.Shiny then table.insert(nameParts, "Shiny") end
            if petInfo.Mythic then table.insert(nameParts, "Mythic") end
            table.insert(nameParts, petInfo.Name or "Unknown Pet")
            
            if petInfo.Enchants and next(petInfo.Enchants) then
                local enchantNames = {}
                for _, enchantData in pairs(petInfo.Enchants) do
                    local fullName = enchantLookup[enchantData.Id] and enchantLookup[enchantData.Id][enchantData.Level]
                    table.insert(enchantNames, fullName or enchantData.Id)
                end
                table.insert(nameParts, "(" .. table.concat(enchantNames, ", ") .. ")")
            end
            table.insert(petsForDisplay, { name = table.concat(nameParts, " "), id = petId })
        end
    end
    return petsForDisplay
end

-- ⭐ NEW: Checks if a pet has a desired enchant and returns its name and SLOT (1 or 2).
local function findEnchantSlot(petInfo, targetEnchants)
    if not petInfo or not petInfo.Enchants then return nil, nil end
    
    for slotKey, currentEnchant in pairs(petInfo.Enchants) do
        for _, targetEnchant in ipairs(targetEnchants) do
            if currentEnchant.Id == targetEnchant.id and currentEnchant.Level == targetEnchant.level then
                local fullName = enchantLookup[currentEnchant.Id][currentEnchant.Level]
                return fullName, tonumber(slotKey) -- Return the name and the slot number
            end
        end
    end
    return nil, nil -- No desired enchant was found
end

-- ================== PART 4: BUILD THE FLUENT UI ==================
local Window = Fluent:CreateWindow({
    Title = "Pet Helper", SubTitle = "Enchant Reroller", TabWidth = 160, Size = UDim2.fromOffset(540, 480),
    Acrylic = true, Theme = "Dark", MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Main = Window:AddTab({ Title = "Reroller", Icon = "rbxassetid://13103328828" }) } -- Custom Icon

local RerollToggle = Tabs.Main:AddToggle("RerollToggle", { Title = "Start / Stop Rerolling", Default = false })
local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Pets to Reroll", Description = "Select which equipped pets to include.",
    Values = (function() local n = {} for _,v in ipairs(getEquippedPetsForDisplay()) do table.insert(n, v.name) end return n end)(),
    Multi = true, Default = {}
})
local EnchantDropdown = Tabs.Main:AddDropdown("TargetEnchantsDropdown", {
    Title = "Primary Target Enchants", Description = "Will reroll BOTH slots to find one of these.",
    Values = AllEnchants, Multi = true, Default = {}
})

-- ⭐ NEW: Secondary Enchant Dropdown
local SecondaryEnchantDropdown = Tabs.Main:AddDropdown("SecondaryEnchantDropdown", {
    Title = "Secondary Target Enchants", Description = "After finding a primary, will reroll the OTHER slot for one of these.",
    Values = AllEnchants, Multi = true, Default = {}
})
--Tabs.Main:AddLabel("InfoLabel", {Title = "Secondary rerolling only works on Shiny pets."}):SetColor(Color3.fromRGB(255, 200, 0))

local SpeedSlider = Tabs.Main:AddSlider("RerollSpeedSlider", {
    Title = "Reroll Speed (Delay)", Description = "Delay in seconds between reroll attempts.",
    Default = 0.4, Min = 0.1, Max = 2.0, Rounding = 1
})

-- ================== PART 5: CORE REROLL & REFRESH LOGIC ==================
local equippedPetsForDisplay = getEquippedPetsForDisplay()

RerollToggle:OnChanged(function(value)
    isRerolling = value
    if not isRerolling then
        Fluent:Notify({ Title = "Stopped", Content = "Rerolling stopped by user.", Duration = 3 })
        return
    end

    task.spawn(function()
        -- 1. Get all targets from UI selections
        local selectedPetNames = Options.EquippedPetDropdown.Value
        local primaryEnchantNames = Options.TargetEnchantsDropdown.Value
        local secondaryEnchantNames = Options.SecondaryEnchantDropdown.Value

        local targetPetIds, primaryTargets, secondaryTargets = {}, {}, {}

        local currentPetList = getEquippedPetsForDisplay()
        for _, petData in ipairs(currentPetList) do
            if selectedPetNames[petData.name] then table.insert(targetPetIds, petData.id) end
        end
        for name, selected in pairs(primaryEnchantNames) do if selected then table.insert(primaryTargets, parseEnchantName(name)) end end
        for name, selected in pairs(secondaryEnchantNames) do if selected then table.insert(secondaryTargets, parseEnchantName(name)) end end

        if #targetPetIds == 0 or #primaryTargets == 0 then
            Fluent:Notify({ Title = "Error", Content = "Select at least one pet and one primary enchant.", Duration = 5 })
            RerollToggle:SetValue(false); isRerolling = false; return
        end

        -- 2. New Reroll Logic: Process one pet at a time
        for _, petId in ipairs(targetPetIds) do
            if not isRerolling then break end

            local petIsDone = false
            local petInfo = (function() for _,p in ipairs(currentPetList) do if p.id == petId then return p end end end)()
            Fluent:Notify({ Title = "Now Targeting", Content = "Focusing on: " .. (petInfo.name or "Unknown Pet"), Duration = 3 })

            while not petIsDone and isRerolling do
                local currentPetData = getPetDataById(petId)
                if not currentPetData then
                    warn("Could not find data for pet ID:", petId); break
                end

                local primaryName, primarySlot = findEnchantSlot(currentPetData, primaryTargets)

                if primaryName then
                    -- ✅ PHASE 2: PRIMARY FOUND. Now work on the secondary.
                    if #secondaryTargets == 0 then
                        Fluent:Notify({ Title = "Success!", Content = ("%s got primary enchant %s. No secondary selected."):format(petInfo.name, primaryName), Duration = 5 })
                        petIsDone = true; continue
                    end

                    if not currentPetData.Shiny then
                        Fluent:Notify({ Title = "Skipping", Content = "Secondary rerolling only works for Shiny pets.", Duration = 5 })
                        petIsDone = true; continue
                    end
                    
                    local secondarySlotToReroll = (primarySlot == 1) and 2 or 1
                    local otherSlotEnchant = currentPetData.Enchants[tostring(secondarySlotToReroll)]
                    
                    -- Check if the other slot already has the desired secondary enchant
                    local secondaryName, _ = findEnchantSlot({ Enchants = { [secondarySlotToReroll] = otherSlotEnchant } }, secondaryTargets)
                    if secondaryName then
                        Fluent:Notify({ Title = "Success!", Content = ("%s now has %s & %s!"):format(petInfo.name, primaryName, secondaryName), Duration = 5 })
                        petIsDone = true; continue
                    end

                    -- Reroll the other slot
                    RerollEvent:FireServer("RerollEnchant", currentPetData.Id, secondarySlotToReroll)

                else
                    -- ❌ PHASE 1: PRIMARY NOT FOUND. Reroll both slots.
                    RemoteFunction:InvokeServer("RerollEnchants", currentPetData.Id, "Gems")
                end
                
                task.wait(Options.RerollSpeedSlider.Value)
            end
        end

        -- 3. After the main loop finishes or is stopped
        if isRerolling then
            Fluent:Notify({ Title = "Complete!", Content = "All selected pets have been processed.", Duration = 5 })
            RerollToggle:SetValue(false)
        end
    end)
end)

-- Background task to keep the pet dropdown list updated
task.spawn(function()
    while task.wait(2) do
        if Fluent.Unloaded then break end
        local newList = getEquippedPetsForDisplay()
        local newNames = {}
        for _, v in ipairs(newList) do table.insert(newNames, v.name) end
        
        local oldNames = PetDropdown.Values
        if table.concat(newNames, ",") ~= table.concat(oldNames, ",") then
            equippedPetsForDisplay = newList
            PetDropdown:SetValues(newNames)
        end
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "Fluent Loaded", Content = "Pet Helper is now active.", Duration = 5, Icon = "rbxassetid://13103328828" })
