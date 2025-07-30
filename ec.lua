-- ================== PART 1: LOAD LIBRARIES (Safasfdsaasytgwaseyewqywer4y2w34yt234yt23ytely) ==================
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

local function hasDesiredEnchant(petInfo, targetEnchants)
    if not petInfo.Enchants then return nil end
    for _, currentEnchant in pairs(petInfo.Enchants) do
        for _, targetEnchant in ipairs(targetEnchants) do
            if currentEnchant.Id == targetEnchant.id and currentEnchant.Level == targetEnchant.level then
                return enchantLookup[currentEnchant.Id][currentEnchant.Level]
            end
        end
    end
    return nil
end

-- ================== PART 4: BUILD THE FLUENT UI ==================
local Window = Fluent:CreateWindow({
    Title = "Pet Helper", SubTitle = "Enchant Reroller", TabWidth = 160, Size = UDim2.fromOffset(540, 620),
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

local StatusParagraph, CompletedPetsParagraph

local function updateStatus(newContent)
    if StatusParagraph then StatusParagraph:Destroy() end
    StatusParagraph = Tabs.Main:AddParagraph({ Title = "Action Log", Content = newContent })
end
local function updateCompletedStatus(completedList)
    if CompletedPetsParagraph then CompletedPetsParagraph:Destroy() end
    CompletedPetsParagraph = Tabs.Main:AddParagraph({ Title = "Completed Pets", Content = table.concat(completedList, "\n") })
end

updateStatus("Waiting to start...")
updateCompletedStatus({"None"})

-- ================== PART 5: CORE REROLL & REFRESH LOGIC ==================
local equippedPetsData = getEquippedPetsData()
local completedPets = {}

RerollToggle:OnChanged(function(value)
    isRerolling = value
    if not isRerolling then
        updateStatus("⏹️ Stopped by user.")
        return
    end

    task.spawn(function()
        updateStatus("⏳ Starting...")
        completedPets = {}
        updateCompletedStatus({"None"})

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
            updateStatus("⚠️ Error: Select at least one pet and one enchant.")
            RerollToggle:SetValue(false)
            isRerolling = false
            return
        end

        while isRerolling do
            local playerData = LocalData:Get()
            local petDataMap = {}
            for _, petData in pairs(playerData.Pets) do petDataMap[petData.Id] = petData end
            
            local completedCount = 0

            for _, petId in ipairs(targetPetIds) do
                if not isRerolling then break end
                local petInfo = petDataMap[petId]
                if petInfo then
                    local foundEnchantName = hasDesiredEnchant(petInfo, targetEnchants)
                    if foundEnchantName then
                        completedCount = completedCount + 1
                        if not completedPets[petId] then
                            local successString = "✅ " .. (petInfo.Name or petId) .. " (" .. foundEnchantName .. ")"
                            updateStatus(successString)
                            
                            -- FIXED: Store the full success string, including the enchant name.
                            completedPets[petId] = successString
                            
                            local completedDisplayList = {}
                            for _, text in pairs(completedPets) do table.insert(completedDisplayList, text) end
                            updateCompletedStatus(completedDisplayList)
                            task.wait(0.5)
                        end
                    else
                        updateStatus("🔁 Rerolling: " .. (petInfo.Name or petId))
                        RemoteFunction:InvokeServer("RerollEnchants", petId, "Gems")
                        if completedPets[petId] then
                           completedPets[petId] = nil
                           local completedDisplayList = {}
                           for _, text in pairs(completedPets) do table.insert(completedDisplayList, text) end
                           updateCompletedStatus(completedDisplayList)
                        end
                        task.wait(Options.RerollSpeedSlider.Value)
                    end
                end
            end
            
            if #targetPetIds > 0 and completedCount == #targetPetIds then
                updateStatus("🎉 All selected pets have a target enchant!")
                RerollToggle:SetValue(false)
                isRerolling = false
            end
            
            task.wait(0.1)
        end
    end)
end)

task.spawn(function()
    while task.wait(2) do
        if Fluent.Unloaded then break end
        local newList = getEquippedPetsData()
        if table.concat( (function() local n = {} for _,v in ipairs(newList) do table.insert(n, v.name) end return n end)(), ",") ~= table.concat( (function() local n = {} for _,v in ipairs(equippedPetsData) do table.insert(n, v.name) end return n end)(), ",") then
            equippedPetsData = newList
            local namesOnly = {}
            for _,v in ipairs(equippedPetsData) do table.insert(namesOnly, v.name) end
            PetDropdown:SetValues(namesOnly)
        end
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "Fluent Loaded", Content = "Pet Helper is now active.", Duration = 5 })
