--[[
    Fluent Enchant Reroller - Dawid's Version

    This script is designed for an executor. It will automatically fetch the
    Fluent UI library from the source you provided.
]]

-- Load the Fluent library from Dawid's repository
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Prevent the UI from being destroyed on respawn if injected into PlayerGui
-- game.CoreGui is the preferred parent for executor scripts
if not game:IsLoaded() then game.Loaded:Wait() end
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Services and Game Data
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction

-- =================================================================
--                          CORE LOGIC
-- =================================================================

-- State variables to manage the rerolling process
local selectedPetIds = {}
local isRerolling = false
local rerollLoopConnection = nil

-- The main window instance
local Window = Fluent.new({
    Title = "🔁 Enchant Reroller",
    SubTitle = "by Gemini",
    Size = UDim2.fromOffset(420, 550),
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

-- =================================================================
--                            UI SETUP
-- =================================================================

-- References to UI components that need to be updated
local Components = {
    PetTogglesSection = nil,
    EnchantNameBox = nil,
    EnchantLevelBox = nil,
    StatusLabel = nil
}

-- Function to check if a pet has the desired enchant
local function hasDesiredEnchant(pet, id, lvl)
    if not pet or not pet.Enchants then return false end
    for _, enchant in pairs(pet.Enchants) do
        if enchant.Id:lower() == id:lower() and enchant.Level == tonumber(lvl) then
            return true
        end
    end
    return false
end

-- Function to start the reroll loop
local function startReroll()
    if isRerolling then return end

    local enchantName = Components.EnchantNameBox:GetValue()
    local enchantLevel = tonumber(Components.EnchantLevelBox:GetValue())

    if not next(selectedPetIds) then
        Components.StatusLabel:SetText("⚠️ Status: Select at least one pet.")
        return
    end
    if not (enchantName and enchantName ~= "" and enchantLevel) then
        Components.StatusLabel:SetText("⚠️ Status: Enter a valid enchant name and level.")
        return
    end

    isRerolling = true
    Components.StatusLabel:SetText("⏳ Status: Starting reroll process...")

    -- Use task.spawn to run the loop in a new thread
    task.spawn(function()
        local rerollQueue = {}
        for id in pairs(selectedPetIds) do table.insert(rerollQueue, id) end

        while isRerolling and next(rerollQueue) do
            local currentPetId = table.remove(rerollQueue, 1)
            local currentPet = LocalData:GetPet(currentPetId)

            if not currentPet then goto continue end

            local petHasEnchant = hasDesiredEnchant(currentPet, enchantName, enchantLevel)

            if not petHasEnchant then
                Components.StatusLabel:SetText("🔁 Status: Rerolling " .. (currentPet.Name or currentPetId))
                RemoteFunction:InvokeServer("RerollEnchants", currentPetId, "Gems")
                table.insert(rerollQueue, currentPetId) -- Add it back to the end of the queue
                task.wait(0.4) -- Wait before next reroll to avoid spam
            else
                Components.StatusLabel:SetText("✅ Status: " .. (currentPet.Name or currentPetId) .. " has the enchant.")
                task.wait(0.2) -- Small delay before checking the next pet
            end

            ::continue::
        end

        if isRerolling then
            isRerolling = false
            Components.StatusLabel:SetText("✅ Status: All selected pets have the desired enchant. Process finished.")
        end
    end)
end

-- Function to stop the reroll loop
local function stopReroll()
    if not isRerolling then return end
    isRerolling = false
    if rerollLoopConnection then rerollLoopConnection:Disconnect() end
    Components.StatusLabel:SetText("⏹️ Status: Reroll stopped by user.")
end

-- Create a tab for the main functions
local MainTab = Window:AddTab({ Title = "Reroller" })

-- ## Section for Pet Selection
local PetSelectionSection = MainTab:AddSection({ Title = "Pet Selection" })

-- Search box to filter pets
PetSelectionSection:AddTextbox("SearchBox", {
    Title = "Search",
    Placeholder = "Filter by pet name...",
    Callback = function(text)
        local filter = text:lower()
        -- Clear existing toggles before adding filtered ones
        Components.PetTogglesSection:Clear()

        local data = LocalData:Get()
        for _, pet in pairs(data.Pets or {}) do
            local petName = pet.Name or pet.name or pet._name or "Unknown"
            if filter == "" or petName:lower():find(filter, 1, true) then
                -- Add a toggle for each matching pet
                Components.PetTogglesSection:AddToggle(pet.Id, {
                    Title = petName,
                    Default = selectedPetIds[pet.Id] or false, -- Keep it checked if it was already selected
                    Callback = function(value)
                        selectedPetIds[pet.Id] = value and true or nil
                    end
                })
            end
        end
        Fluent:Notify({
            Title = "Pet List Updated",
            Content = "Showing pets matching your search.",
            Duration = 2
        })
    end
})

-- This section will be dynamically filled with pet toggles
Components.PetTogglesSection = MainTab:AddSection({ Title = "Pets", Scrollable = true, Size = UDim2.fromOffset(0, 150) })

-- ## Section for Enchant Configuration
local ConfigSection = MainTab:AddSection({ Title = "Configuration" })

Components.EnchantNameBox = ConfigSection:AddTextbox("EnchantName", {
    Title = "Enchant Name",
    Placeholder = "e.g., Criticals"
})

Components.EnchantLevelBox = ConfigSection:AddTextbox("EnchantLevel", {
    Title = "Enchant Level",
    Placeholder = "e.g., 9",
    NumbersOnly = true
})

-- ## Section for Controls and Status
local ControlSection = MainTab:AddSection({ Title = "Controls" })

ControlSection:AddButton({
    Title = "▶ Start Rerolling",
    Callback = startReroll
})

ControlSection:AddButton({
    Title = "■ Stop Rerolling",
    Callback = stopReroll
})

Components.StatusLabel = ControlSection:AddLabel({
    Title = "Status: Waiting for input..."
})

-- Initial population of the pet list
pcall(function()
    local data = LocalData:Get()
    for _, pet in pairs(data.Pets or {}) do
        local petName = pet.Name or pet.name or pet._name or "Unknown"
        Components.PetTogglesSection:AddToggle(pet.Id, {
            Title = petName,
            Default = false,
            Callback = function(value)
                selectedPetIds[pet.Id] = value and true or nil
            end
        })
    end
end)

-- Add a credit, it's good practice
Window:AddTab({ Title = "About" }):AddLabel({ Title = "UI by Fluent, Script by Gemini" })

-- Finalize the UI
Window:SelectTab(1)
Fluent:Notify({
    Title = "Enchant Reroller Loaded",
    Content = "Configure your enchants and select pets to begin.",
    Duration = 5
})
