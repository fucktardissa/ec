local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.lua"))()

--// Services & Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Framework components
local LocalPlayer = Players.LocalPlayer
-- NOTE: Adjust these paths if your framework structure is different.
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction

--// Core Logic State
local rerolling = false
local rerollQueue = {}
local selectedPetIds = {}

--// UI Element References
local StatusLabel, PetDropdown, EnchantNameBox, EnchantLevelBox

--============================================================================--
--[[                                  LOGIC                                 ]]--
--============================================================================--

-- Helper function to check if a pet has the desired enchant
local function hasDesiredEnchant(pet, enchantId, enchantLevel)
    if not pet or not pet.Enchants then return false end
    for _, enchant in pairs(pet.Enchants) do
        -- Ensure case-insensitivity for enchant ID and strict number comparison for level
        if enchant.Id:lower() == enchantId:lower() and enchant.Level == enchantLevel then
            return true
        end
    end
    return false
end

-- Main function to handle the rerolling process
local function startRerolling()
    local targetEnchant = EnchantNameBox:GetText()
    local targetLevel = tonumber(EnchantLevelBox:GetText())
    local selectedPetStrings = PetDropdown:GetValues()

    -- Validate inputs
    if #selectedPetStrings == 0 then
        StatusLabel:SetText("⚠️ Please select at least one pet.")
        return
    end
    if not targetEnchant or targetEnchant == "" or not targetLevel then
        StatusLabel:SetText("⚠️ Enter a valid enchant name and level.")
        return
    end

    -- The MultiDropdown returns display names; we need to look up the actual pet IDs
    local petIdLookup = PetDropdown.petIdLookup -- Retrieve the lookup table from the dropdown object
    table.clear(selectedPetIds)
    for _, petString in ipairs(selectedPetStrings) do
        local id = petIdLookup[petString]
        if id then
            selectedPetIds[id] = true
        end
    end

    rerolling = true
    table.clear(rerollQueue)
    StatusLabel:SetText("⏳ Initializing reroll sequence...")

    -- Populate the initial reroll queue
    local playerData = LocalData:Get()
    for petId, _ in pairs(selectedPetIds) do
        local currentPet
        for _, p in pairs(playerData.Pets or {}) do
            if p.Id == petId then
                currentPet = p
                break
            end
        end

        if currentPet and not hasDesiredEnchant(currentPet, targetEnchant, targetLevel) then
            table.insert(rerollQueue, currentPet.Id)
        end
    end

    StatusLabel:SetText(string.format(" Queued %d pets for rerolling.", #rerollQueue))

    -- Run the main loop in a separate thread to prevent UI freezing
    task.spawn(function()
        while rerolling do
            -- Process all pets currently in the queue
            while rerolling and #rerollQueue > 0 do
                local petId = table.remove(rerollQueue, 1)
                local currentPet
                
                -- Continuously reroll a single pet until it gets the desired enchant
                while rerolling do
                    -- Refresh pet data on each attempt
                    local latestData = LocalData:Get()
                    for _, p in pairs(latestData.Pets or {}) do if p.Id == petId then currentPet = p break end end

                    if not currentPet or hasDesiredEnchant(currentPet, targetEnchant, targetLevel) then
                        break -- Exit loop if pet is gone or has the enchant
                    end
                    
                    StatusLabel:SetText(string.format("🔁 Rerolling %s...", currentPet.Name or petId))
                    RemoteFunction:InvokeServer("RerollEnchants", currentPet.Id, "Gems")
                    task.wait(0.3) -- Delay between reroll attempts
                end

                if rerolling then
                    StatusLabel:SetText(string.format("✅ %s has the enchant!", (currentPet and currentPet.Name) or petId))
                end
            end

            if not rerolling then break end

            StatusLabel:SetText(" Monitoring for changes...")

            -- After clearing the queue, monitor pets and re-queue any that lose the enchant
            local latestData = LocalData:Get()
            for petId, _ in pairs(selectedPetIds) do
                 local pet
                 for _, p in pairs(latestData.Pets or {}) do if p.Id == petId then pet = p break end end

                 if pet and not hasDesiredEnchant(pet, targetEnchant, targetLevel) then
                     table.insert(rerollQueue, pet.Id)
                     StatusLabel:SetText(string.format("⚠️ %s lost enchant! Re-queuing.", pet.Name or pet.Id))
                 end
            end

            task.wait(2.0) -- Wait before the next monitoring cycle
        end

        StatusLabel:SetText("⏹️ Reroll stopped.")
    end)
end

-- Function to stop the rerolling process
local function stopRerolling()
    rerolling = false
    StatusLabel:SetText("⏹️ Reroll stopped by user.")
end


--============================================================================--
--[[                                  GUI                                   ]]--
--============================================================================--

-- Create the main window
local Window = Fluent:CreateWindow({
    Title = "🔁 Enchant Reroller",
    SubTitle = "Fluent Edition",
    Size = UDim2.fromOffset(440, 430),
    Theme = "Dark",
    Accent = Color3.fromRGB(80, 165, 255), -- A modern blue accent
})

local MainTab = Window:AddTab("Main")

-- Section for core configuration
local SettingsSection = MainTab:AddSection("Configuration")

-- Prepare data for the pet selection dropdown
local petOptions, petIdLookup = {}, {}
local playerData = LocalData:Get()
if playerData and playerData.Pets then
    for _, pet in ipairs(playerData.Pets) do
        local displayName = string.format("%s [%s]", pet.Name or "Unknown", pet.Id)
        table.insert(petOptions, displayName)
        petIdLookup[displayName] = pet.Id
    end
end

PetDropdown = SettingsSection:AddMultiDropdown("PetSelector", {
    Title = "Select Pets",
    Values = petOptions,
    Search = true, -- Enable built-in search functionality
})
PetDropdown.petIdLookup = petIdLookup -- Attach the lookup table for later access

EnchantNameBox = SettingsSection:AddTextBox("EnchantName", {
    Title = "Target Enchant Name",
    Placeholder = "e.g., royalty",
    Default = "",
})

EnchantLevelBox = SettingsSection:AddTextBox("EnchantLevel", {
    Title = "Target Enchant Level",
    Placeholder = "e.g., 10",
    Default = "",
    NumbersOnly = true, -- Restrict input to numbers
})

-- Section for status updates and actions
local ControlSection = MainTab:AddSection("Controls & Status")

StatusLabel = ControlSection:AddLabel("StatusDisplay", {
    Text = "Status: Waiting for instructions...",
})

ControlSection:AddButton("StartButton", {
    Title = "▶ Start Rerolling",
    Callback = startRerolling,
})

ControlSection:AddButton("StopButton", {
    Title = "■ Stop Rerolling",
    Callback = stopRerolling,
})

-- Make the UI visible
Window:Toggle()
