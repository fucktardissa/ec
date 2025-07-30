-- ================== PART 1: LOAD LIBRARIasdasdasdasdasdasdES (Safely) ==================
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
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction

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

-- Retrieves and formats the player's currently equipped pets for display
local function getEquippedPetsData()
    local petsData = {}
    local playerData = LocalData:Get()
    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then return {} end

    local equippedTeamId = playerData.TeamEquipped
    local teamInfo = playerData.Teams[equippedTeamId]
    if not (teamInfo and teamInfo.Pets) then return {} end

    local petDataMap = {}
    for _, petData in pairs(playerData.Pets) do petDataMap[petData.Id] = petData end

    for _, petId in ipairs(teamInfo.Pets) do
        local petInfo = petDataMap[petId]
        if petInfo then
            local nameParts = {}
            -- ⭐ Check for Shiny and Mythic status to build the name
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
            table.insert(petsData, { name = table.concat(nameParts, " "), id = petId })
        end
    end
    return petsData
end

-- Checks if a pet has any of the user-selected target enchants
local function hasDesiredEnchant(petInfo, targetEnchants)
    if not petInfo.Enchants then return nil end
    for _, currentEnchant in pairs(petInfo.Enchants) do
        for _, targetEnchant in ipairs(targetEnchants) do
            if currentEnchant.Id == targetEnchant.id and currentEnchant.Level == targetEnchant.level then
                return enchantLookup[currentEnchant.Id][currentEnchant.Level] -- Return the full name of the found enchant
            end
        end
    end
    return nil -- No desired enchant was found
end

-- ================== PART 4: BUILD THE FLUENT UI ==================
local Window = Fluent:CreateWindow({
    Title = "Pet Helper", SubTitle = "Enchant Reroller", TabWidth = 160, Size = UDim2.fromOffset(540, 400),
    Acrylic = true, Theme = "Dark", MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Main = Window:AddTab({ Title = "Reroller", Icon = "swords" }) }

local RerollToggle = Tabs.Main:AddToggle("RerollToggle", { Title = "Start / Stop Rerolling", Default = false })
local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Pets to Reroll", Description = "Select which equipped pets to include.",
    Values = (function() local n = {} for _,v in ipairs(getEquippedPetsData()) do table.insert(n, v.name) end return n end)(),
    Multi = true, Default = {}
})
local EnchantDropdown = Tabs.Main:AddDropdown("TargetEnchantsDropdown", {
    Title = "Target Enchants", Description = "Will stop on any selected enchant.",
    Values = AllEnchants, Multi = true, Default = {}
})
local SpeedSlider = Tabs.Main:AddSlider("RerollSpeedSlider", {
    Title = "Reroll Speed (Delay)", Description = "Delay in seconds between reroll attempts. Lower is faster.",
    Default = 0.4, Min = 0.1, Max = 2.0, Rounding = 1
})

-- ================== PART 5: CORE REROLL & REFRESH LOGIC ==================
local equippedPetsData = getEquippedPetsData()

RerollToggle:OnChanged(function(value)
    isRerolling = value
    if not isRerolling then
        Fluent:Notify({ Title = "Stopped", Content = "Rerolling stopped by user.", Duration = 3 })
        return
    end

    -- The entire reroll process is wrapped in a background task to prevent UI freezing
    task.spawn(function()
        -- 1. Get targets from UI selections
        local selectedPetNames = Options.EquippedPetDropdown.Value
        local selectedEnchantNames = Options.TargetEnchantsDropdown.Value
        local targetPetIds, targetEnchants = {}, {}

        for _, petData in ipairs(equippedPetsData) do
            if selectedPetNames[petData.name] then table.insert(targetPetIds, petData.id) end
        end
        for enchantName, isSelected in pairs(selectedEnchantNames) do
            if isSelected then table.insert(targetEnchants, parseEnchantName(enchantName)) end
        end

        if #targetPetIds == 0 or #targetEnchants == 0 then
            Fluent:Notify({ Title = "Error", Content = "Select at least one pet and one enchant.", Duration = 5 })
            RerollToggle:SetValue(false)
            isRerolling = false
            return
        end

        -- 2. New Reroll Logic: Process one pet at a time, sequentially.
        for _, petId in ipairs(targetPetIds) do
            if not isRerolling then break end -- Exit if user toggled off

            local petInfo = (function() for _, p in ipairs(equippedPetsData) do if p.id == petId then return p end end end)()
            if not petInfo then
                warn("Could not find info for pet ID:", petId)
                continue -- Skip to the next pet
            end
            
            -- PRE-REROLL CHECK: See if the pet already has a valid enchant.
            local initialPetData = (function() for _, p in pairs(LocalData:Get().Pets) do if p.Id == petId then return p end end end)()
            if initialPetData then
                local foundEnchantName = hasDesiredEnchant(initialPetData, targetEnchants)
                if foundEnchantName then
                    Fluent:Notify({ Title = "Skipped", Content = ("%s already has %s."):format(petInfo.name, foundEnchantName), Duration = 4 })
                    continue -- This pet is valid, so skip to the next one.
                end
            end

            -- If the check fails, the pet needs to be rerolled.
            Fluent:Notify({ Title = "Now Rerolling", Content = "Focusing on: " .. petInfo.name, Duration = 3 })
            
            local petIsDone = false
            while not petIsDone and isRerolling do
                -- Reroll the pet and wait for the specified delay
                RemoteFunction:InvokeServer("RerollEnchants", petId, "Gems")
                task.wait(Options.RerollSpeedSlider.Value)

                -- Get the pet's updated data to check the new enchants
                local currentPetData = (function() for _, p in pairs(LocalData:Get().Pets) do if p.Id == petId then return p end end end)()
                if currentPetData then
                    local foundEnchantName = hasDesiredEnchant(currentPetData, targetEnchants)
                    if foundEnchantName then
                        -- ✅ Success! Pet got a desired enchant.
                        Fluent:Notify({ Title = "Success!", Content = ("%s got %s!"):format(petInfo.name, foundEnchantName), Duration = 5 })
                        petIsDone = true -- Break the inner loop and move to the next pet
                    end
                else
                    -- ❌ Error state, can't find pet data.
                    Fluent:Notify({ Title = "Error", Content = "Could not find pet data for " .. petInfo.name, Duration = 5 })
                    petIsDone = true -- Stop trying for this pet
                end
            end
        end

        -- 3. After the main loop finishes or is stopped
        if isRerolling then
            Fluent:Notify({ Title = "Complete!", Content = "All selected pets have been processed.", Duration = 5 })
            RerollToggle:SetValue(false) -- Auto-turn off the toggle
        end
    end)
end)

-- Background task to keep the pet dropdown list updated if you equip/unequip pets
task.spawn(function()
    while task.wait(2) do
        if Fluent.Unloaded then break end
        local newList = getEquippedPetsData()
        local newNames = {}
        for _, v in ipairs(newList) do table.insert(newNames, v.name) end
        
        local oldNames = {}
        for _, v in ipairs(equippedPetsData) do table.insert(oldNames, v.name) end

        if table.concat(newNames, ",") ~= table.concat(oldNames, ",") then
            equippedPetsData = newList
            PetDropdown:SetValues(newNames)
        end
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "Fluent Loaded", Content = "Pet Helper is now active.", Duration = 5 })
