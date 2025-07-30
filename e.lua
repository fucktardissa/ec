-- ================== PART 1: LOAD LIBRARIES & SERVICES (Sfffffffffffffffffffffffffffffffffffffffffffffffffffffafely) ==================
local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Fluent library failed to load. The script cannot continue.")
    return
end

-- Game Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientFramework = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Framework")
local SharedFramework = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework")

-- Core Systems
local LocalData = require(ClientFramework:WaitForChild("Services"):WaitForChild("LocalData"))
-- This is the original remote that rerolls BOTH slots on a shiny pet
local RerollBothRemote = SharedFramework.Network.Remote.RemoteFunction
-- This is the new remote that targets a SPECIFIC enchant slot (1 or 2)
local RerollSlotEvent = SharedFramework.Network.Remote.RemoteEvent

-- ================== PART 2: DATA, CONFIG, & STATE ==================
local isRerolling = false
local Options = Fluent.Options

local AllEnchants = {
    "Bubbler I", "Bubbler II", "Bubbler III", "Bubbler IV", "Bubbler V", "Gleaming I", "Gleaming II", "Gleaming III",
    "Looter I", "Looter II", "Looter III", "Looter IV", "Looter V", "Team Up I", "Team Up II", "Team Up III", "Team Up IV", "Team Up V",
    "High Roller", "Infinity", "Magnetism", "Secret Hunter", "Ultra Roller", "Determination", "Shiny Seeker"
}
local enchantLookup = {}

-- ================== PART 3: HELPER FUNCTIONS & SETUP ==================
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

for _, fullName in ipairs(AllEnchants) do
    local parsed = parseEnchantName(fullName)
    if not enchantLookup[parsed.id] then enchantLookup[parsed.id] = {} end
    enchantLookup[parsed.id][parsed.level] = fullName
end

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
            if petInfo.Shiny then table.insert(nameParts, "Shiny") end
            if petInfo.Mythic then table.insert(nameParts, "Mythic") end
            table.insert(nameParts, petInfo.Name or "Unknown Pet")
            if petInfo.Enchants and next(petInfo.Enchants) then
                local enchantNames = {}
                for slot, enchantData in pairs(petInfo.Enchants) do
                    local fullName = enchantLookup[enchantData.Id] and enchantLookup[enchantData.Id][enchantData.Level]
                    table.insert(enchantNames, fullName or enchantData.Id)
                end
                table.insert(nameParts, "(" .. table.concat(enchantNames, ", ") .. ")")
            end
            table.insert(petsData, { name = table.concat(nameParts, " "), id = petId, shiny = petInfo.Shiny })
        end
    end
    return petsData
end

-- MODIFIED: Now returns the enchant name AND the slot it was found in.
local function findDesiredEnchant(petData, targetEnchants)
    if not petData or not petData.Enchants then return nil, nil end
    for slot, currentEnchant in pairs(petData.Enchants) do
        for _, targetEnchant in ipairs(targetEnchants) do
            if currentEnchant.Id == targetEnchant.id and currentEnchant.Level == targetEnchant.level then
                local fullName = enchantLookup[currentEnchant.Id][currentEnchant.Level]
                return fullName, slot
            end
        end
    end
    return nil, nil -- No desired enchant was found
end

-- ================== PART 4: BUILD THE FLUENT UI ==================
local Window = Fluent:CreateWindow({
    Title = "Pet Helper", SubTitle = "Dual Enchant Reroller", TabWidth = 160, Size = UDim2.fromOffset(540, 480),
    Acrylic = true, Theme = "Dark", MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Main = Window:AddTab({ Title = "Reroller", Icon = "swords" }) }

local RerollToggle = Tabs.Main:AddToggle("RerollToggle", { Title = "Start / Stop Rerolling", Default = false })
local PetDropdown = Tabs.Main:AddDropdown("EquippedPetDropdown", {
    Title = "Pets to Reroll", Description = "Select which equipped pets to include.",
    Values = (function() local n = {} for _,v in ipairs(getEquippedPetsData()) do table.insert(n, v.name) end return n end)(),
    Multi = true, Default = {}
})
local PrimaryEnchantDropdown = Tabs.Main:AddDropdown("PrimaryEnchantsDropdown", {
    Title = "Primary Target Enchants", Description = "The first enchant to roll for.",
    Values = AllEnchants, Multi = true, Default = {}
})
-- ⭐ NEW: Dropdown for the secondary enchant
local SecondaryEnchantDropdown = Tabs.Main:AddDropdown("SecondaryEnchantsDropdown", {
    Title = "Secondary Target Enchants (Shiny Only)", Description = "After getting the primary, will roll the other slot for these.",
    Values = AllEnchants, Multi = true, Default = {}
})
local SpeedSlider = Tabs.Main:AddSlider("RerollSpeedSlider", {
    Title = "Reroll Speed (Delay)", Description = "Delay in seconds between reroll attempts.",
    Default = 0.4, Min = 0.1, Max = 2.0, Rounding = 1
})

-- ================== PART 5: CORE REROLL & REFRESH LOGIC (OVERHAULED) ==================
local equippedPetsData = getEquippedPetsData()

RerollToggle:OnChanged(function(value)
    isRerolling = value
    if not isRerolling then
        Fluent:Notify({ Title = "Stopped", Content = "Rerolling stopped by user.", Duration = 3 })
        return
    end

    task.spawn(function()
        -- 1. Get all targets from UI
        local selectedPetNames = Options.EquippedPetDropdown.Value
        local primaryEnchantNames = Options.PrimaryEnchantsDropdown.Value
        local secondaryEnchantNames = Options.SecondaryEnchantsDropdown.Value

        local targetPets, primaryTargets, secondaryTargets = {}, {}, {}
        
        for _, petData in ipairs(equippedPetsData) do
            if selectedPetNames[petData.name] then table.insert(targetPets, petData) end
        end
        for name, selected in pairs(primaryEnchantNames) do if selected then table.insert(primaryTargets, parseEnchantName(name)) end end
        for name, selected in pairs(secondaryEnchantNames) do if selected then table.insert(secondaryTargets, parseEnchantName(name)) end end

        if #targetPets == 0 or #primaryTargets == 0 then
            Fluent:Notify({ Title = "Error", Content = "Select at least one pet and one primary enchant.", Duration = 5 })
            RerollToggle:SetValue(false)
            return
        end

        -- 2. Process each selected pet one by one
        for _, petInfo in ipairs(targetPets) do
            if not isRerolling then break end
            
            local petId = petInfo.id
            local petName = petInfo.name
            local isShiny = petInfo.shiny
            local primarySlot, secondarySlot = nil, nil

            -- ================= PHASE 1: SECURE THE PRIMARY ENCHANT =================
            Fluent:Notify({ Title = "Phase 1: Primary", Content = "Seeking primary enchant for: " .. petName, Duration = 3 })
            local primaryDone = false
            while not primaryDone and isRerolling do
                local currentPetData = (function() for _, p in pairs(LocalData:Get().Pets) do if p.Id == petId then return p end end)()
                local foundName, foundSlot = findDesiredEnchant(currentPetData, primaryTargets)
                
                if foundName then
                    Fluent:Notify({ Title = "Primary Secured!", Content = ("%s has %s in slot %d."):format(petName, foundName, foundSlot), Duration = 4 })
                    primarySlot = foundSlot
                    primaryDone = true
                else
                    -- Reroll and wait
                    RerollBothRemote:InvokeServer("RerollEnchants", petId, "Gems")
                    task.wait(Options.RerollSpeedSlider.Value)
                end
            end
            
            if not isRerolling then break end

            -- ================= PHASE 2: SECURE THE SECONDARY ENCHANT (SHINY PETS ONLY) =================
            if isShiny and #secondaryTargets > 0 and primarySlot then
                secondarySlot = (primarySlot == 1) and 2 or 1 -- Determine the other slot
                
                Fluent:Notify({ Title = "Phase 2: Secondary", Content = ("Seeking secondary on slot %d for: %s"):format(secondarySlot, petName), Duration = 3 })
                
                local secondaryDone = false
                while not secondaryDone and isRerolling do
                    local currentPetData = (function() for _, p in pairs(LocalData:Get().Pets) do if p.Id == petId then return p end end)()
                    -- Check ONLY the secondary slot for a secondary enchant
                    local enchantInSecondarySlot = currentPetData and currentPetData.Enchants and currentPetData.Enchants[secondarySlot]
                    if enchantInSecondarySlot then
                        local foundName, _ = findDesiredEnchant({ Enchants = { [secondarySlot] = enchantInSecondarySlot } }, secondaryTargets)
                        if foundName then
                            Fluent:Notify({ Title = "Secondary Secured!", Content = ("%s got %s in slot %d!"):format(petName, foundName, secondarySlot), Duration = 5 })
                            secondaryDone = true
                        end
                    end

                    if not secondaryDone then
                        -- Reroll only the specific secondary slot
                        RerollSlotEvent:FireServer("RerollEnchant", petId, secondarySlot)
                        task.wait(Options.RerollSpeedSlider.Value)
                    end
                end
            end
        end

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
Fluent:Notify({ Title = "Fluent Loaded", Content = "Dual Enchant Reroller is active.", Duration = 5 })
