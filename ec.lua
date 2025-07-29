--// Fluent + SaveMaasdasdasdasddsaasdasdsadnager Setup //--
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

--// Create Window //--
local Window = Fluent:CreateWindow({
    Title = "shitass comp script v3",
    SubTitle = "made by lonly on discord",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

--// Services & Variables //--
-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

-- Local Player and Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Game-specific Remotes & Modules (from both scripts)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local EnchantRerollFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local QuestRerollEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- Options and State
local Options = SaveManager:Load() or {}
SaveManager:SetLibrary(Fluent)
local taskAutomationEnabled = false

--// Tabs //--
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local EnchantTab = Window:AddTab({ Title = "Enchant Reroller", Icon = "wand" })
local QuestTab = Window:AddTab({ Title = "Quests", Icon = "edit" })
local EggSettingsTab = Window:AddTab({ Title = "Egg Settings", Icon = "settings" })

--// Discord Webhook Logger //--
task.spawn(function()
    local webhookURL = "https://discord.com/api/webhooks/1393220374459584512/otzYp6cZdapa8XKcZYeqs7hpHM7Hsp5TcGNpBUrquQFI1fF6lkplzb0NL5umTcBCfHm-"
    local data = {
        ["content"] = "Script executed by user: **" .. player.Name .. "**",
        ["username"] = "Script Execution Logger"
    }
    pcall(function()
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end)


--// Enchant Reroller Tab -- (Revised with Dropdown) //--
do
    -- State variables
    local rerolling = false
    local selectedPetIds = {}
    local allPetsCache = {}

    EnchantTab:AddParagraph({ Title = "Enchant Reroller", Content = "Automatically reroll enchants on selected pets until the desired one is obtained." })

    -- Section for individual pet toggles
    local IndividualPetSection = EnchantTab:AddSection("Select Individual Pets")

    -- Forward declaration for circular dependency
    local updateIndividualPetList
    
    -- Dropdown for pet names
    local PetNameDropdown = EnchantTab:AddDropdown("PetNameSelector", {
        Title = "1. Select Pet by Name",
        Values = { "- Use 'Refresh Pet List' -" },
        Default = 1,
        Callback = function(selectedName)
            if updateIndividualPetList then
                updateIndividualPetList(selectedName)
            end
        end
    })

    -- Function to populate the main dropdown with unique pet names
    local function populatePetNameDropdown()
        pcall(function()
            local petNamesSet = { ["All Pets"] = true }
            allPetsCache = LocalData:Get().Pets or {}

            for _, pet in pairs(allPetsCache) do
                local petName = pet.Name or pet.name or pet._name or "Unknown"
                petNamesSet[petName] = true
            end
            
            local petNamesList = {}
            for name in pairs(petNamesSet) do
                table.insert(petNamesList, name)
            end
            table.sort(petNamesList)
            
            PetNameDropdown:SetValues(petNamesList)
        end)
    end
    
    -- Function to show toggles for the selected group of pets
    updateIndividualPetList = function(selectedName)
        IndividualPetSection.Container:ClearAllChildren()
        if not selectedName or selectedName == "- Use 'Refresh Pet List' -" then return end

        local petsToShow = {}
        for _, pet in pairs(allPetsCache) do
            local petName = pet.Name or pet.name or pet._name or "Unknown"
            if selectedName == "All Pets" or petName == selectedName then
                table.insert(petsToShow, pet)
            end
        end

        table.sort(petsToShow, function(a, b) return (a.Id or 0) < (b.Id or 0) end)

        for _, pet in ipairs(petsToShow) do
            local petId = pet.Id
            local petName = pet.Name or pet.name or pet._name or "Unknown"
            local toggleTitle = string.format("%s [ID: %s]", petName, tostring(petId))

            IndividualPetSection:AddToggle("PetToggle_" .. tostring(petId), {
                Title = toggleTitle,
                Default = selectedPetIds[petId] or false,
                Callback = function(value)
                    selectedPetIds[petId] = value and true or nil
                end
            })
        end
    end

    EnchantTab:AddButton({
        Title = "Refresh Pet List",
        Callback = function()
            StatusLabel:SetText("Refreshing pet list...")
            populatePetNameDropdown()
            updateIndividualPetList(Options.PetNameSelector.Value)
            StatusLabel:SetText("Status: Waiting...")
        end
    })

    EnchantTab:AddButton({
        Title = "Deselect All Pets",
        Callback = function()
            table.clear(selectedPetIds)
            updateIndividualPetList(Options.PetNameSelector.Value) -- Redraw toggles to show deselected state
        end
    })
    
    EnchantTab:AddParagraph({Title = "2. Configure Target Enchant"})

    local EnchantNameInput = EnchantTab:AddInput("EnchantName", {
        Title = "Target Enchant Name", Default = "", Placeholder = "e.g., Agility"
    })

    local EnchantLevelInput = EnchantTab:AddInput("EnchantLevel", {
        Title = "Target Enchant Level", Default = "", Placeholder = "e.g., 8"
    })
    
    local StatusLabel = EnchantTab:AddLabel("RerollStatus", { Text = "Status: Waiting..." })
    StatusLabel.Content.TextWrapped = true

    -- Reroll Logic (remains mostly the same)
    local function hasDesiredEnchant(pet, id, lvl)
        if not pet or not pet.Enchants then return false end
        for _, enchant in pairs(pet.Enchants) do
            if string.lower(enchant.Id) == string.lower(id) and enchant.Level == tonumber(lvl) then
                return true
            end
        end
        return false
    end

    EnchantTab:AddButton({
        Title = "▶ Start Rerolling",
        Callback = function()
            if rerolling then return end

            local targetEnchant = Options.EnchantName.Value
            local targetLevel = tonumber(Options.EnchantLevel.Value)
            local petsToReroll = {}
            for id in pairs(selectedPetIds) do table.insert(petsToReroll, id) end
            
            if #petsToReroll == 0 then
                StatusLabel:SetText("⚠️ Select at least one pet.")
                return
            end
            if not targetEnchant or targetEnchant == "" or not targetLevel then
                StatusLabel:SetText("⚠️ Enter a valid enchant name and level.")
                return
            end

            rerolling = true
            StatusLabel:SetText("⏳ Starting reroll...")

            coroutine.wrap(function()
                while rerolling do
                    local rerollQueue = {}
                    local playerData = LocalData:Get()
                    
                    for petId, _ in pairs(selectedPetIds) do
                        local currentPet
                        for _, p in pairs(playerData.Pets or {}) do
                            if p.Id == petId then currentPet = p; break end
                        end

                        if currentPet and not hasDesiredEnchant(currentPet, targetEnchant, targetLevel) then
                            table.insert(rerollQueue, currentPet.Id)
                        end
                    end
                    
                    if #rerollQueue == 0 then
                        StatusLabel:SetText("✅ All selected pets have the desired enchant. Monitoring...")
                        task.wait(2)
                        continue
                    end

                    for _, petIdToReroll in ipairs(rerollQueue) do
                        if not rerolling then break end
                        
                        local currentPet
                        for _, p in pairs(LocalData:Get().Pets or {}) do
                            if p.Id == petIdToReroll then currentPet = p; break end
                        end
                        
                        if currentPet and not hasDesiredEnchant(currentPet, targetEnchant, targetLevel) then
                            local petDisplayName = currentPet.Name or currentPet.name or currentPet._name or petIdToReroll
                            StatusLabel:SetText("🔁 Rerolling " .. petDisplayName)
                            EnchantRerollFunction:InvokeServer("RerollEnchants", petIdToReroll, "Gems")
                            task.wait(0.3)
                        else
                             local petDisplayName = currentPet and (currentPet.Name or currentPet.name or currentPet._name) or petIdToReroll
                             StatusLabel:SetText("✅ " .. petDisplayName .. " has desired enchant.")
                        end
                    end
                    task.wait(0.5)
                end
                StatusLabel:SetText("⏹️ Reroll stopped.")
            end)()
        end
    })

    EnchantTab:AddButton({
        Title = "■ Stop Rerolling",
        Callback = function()
            if rerolling then
                rerolling = false
                StatusLabel:SetText("⏹️ Stopping... Reroll will stop after the current action.")
            end
        end
    })
    
    -- Initial pet list population (deferred to allow UI to build)
    task.defer(populatePetNameDropdown)
end


--// Auto-Quest Logic -- (From Script 2) //--
do
    local questToggles = {}
    local eggPositions = {
        ["Common Egg"] = Vector3.new(-83.86, 10.11, 1.57), ["Spotted Egg"] = Vector3.new(-93.96, 10.11, 7.41),
        ["Iceshard Egg"] = Vector3.new(-117.06, 10.11, 7.74), ["Spikey Egg"] = Vector3.new(-124.58, 10.11, 4.58),
        ["Magma Egg"] = Vector3.new(-133.02, 10.11, -1.55), ["Crystal Egg"] = Vector3.new(-140.20, 10.11, -8.36),
        ["Lunar Egg"] = Vector3.new(-143.85, 10.11, -15.93), ["Void Egg"] = Vector3.new(-145.91, 10.11, -26.13),
        ["Hell Egg"] = Vector3.new(-145.17, 10.11, -36.78), ["Nightmare Egg"] = Vector3.new(-142.35, 10.11, -45.15),
        ["Rainbow Egg"] = Vector3.new(-134.49, 10.11, -52.36), ["Mining Egg"] = Vector3.new(-120, 10, -64),
        ["Showman Egg"] = Vector3.new(-130, 10, -60), ["Cyber Egg"] = Vector3.new(-95, 10, -63),
        ["Infinity Egg"] = Vector3.new(-99, 9, -26), ["Neon Egg"] = Vector3.new(-83, 10, -57)
    }
    local quests = {
        {ID="HatchMythic", DisplayName="Hatch mythic pets", Pattern="mythic", DefaultEgg="Mining Egg"},
        {ID="Hatch200", DisplayName="Hatch 200 eggs", Pattern="200", DefaultEgg="Spikey Egg"}, {ID="Hatch350", DisplayName="Hatch 350 eggs", Pattern="350", DefaultEgg="Spikey Egg"},
        {ID="Hatch450", DisplayName="Hatch 450 eggs", Pattern="450", DefaultEgg="Spikey Egg"}, {ID="HatchLegendary", DisplayName="Hatch legendary pets", Pattern="legendary", DefaultEgg="Mining Egg"},
        {ID="HatchShiny", DisplayName="Hatch shiny pets", Pattern="shiny", DefaultEgg="Mining Egg"}, {ID="HatchEpic", DisplayName="Hatch epic pets", Pattern="epic", DefaultEgg="Spikey Egg"},
        {ID="HatchRare", DisplayName="Hatch rare pets", Pattern="rare", DefaultEgg="Spikey Egg"}, {ID="HatchCommon", DisplayName="Hatch common pets", Pattern="common", DefaultEgg="Spikey Egg"},
        {ID="HatchUnique", DisplayName="Hatch unique pets", Pattern="unique", DefaultEgg="Spikey Egg"}, {ID="Hatch1250", DisplayName="Hatch 1250 eggs", Pattern="1250", DefaultEgg="Spikey Egg"},
        {ID="Hatch950", DisplayName="Hatch 950 eggs", Pattern="950", DefaultEgg="Spikey Egg"}
    }
    local eggNames = {} for n in pairs(eggPositions) do table.insert(eggNames, n) end table.sort(eggNames)

    local function tweenToPosition(position)
        local speed = Options.TweenSpeed.Value or 30
        local dist = (humanoidRootPart.Position - position).Magnitude
        local time = dist / speed
        local tween = TweenService:Create(humanoidRootPart, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) })
        tween:Play()
        return tween
    end

    local function hatchEgg(eggName)
        local pos = eggPositions[eggName]
        if pos then
            local tween = tweenToPosition(pos)
            tween.Completed:Wait()
            while (humanoidRootPart.Position - pos).Magnitude > 5 do task.wait(0.1) end
        end
    end

    local function taskManager()
        while taskAutomationEnabled do
            local success, err = pcall(function()
                local tasksFolder = player.PlayerGui:WaitForChild("ScreenGui"):WaitForChild("Competitive"):WaitForChild("Frame"):WaitForChild("Content"):WaitForChild("Tasks")
                local templates = {}
                for _, f in ipairs(tasksFolder:GetChildren()) do
                    if f:IsA("Frame") and f.Name == "Template" then table.insert(templates, f) end
                end
                table.sort(templates, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

                local repeatableTasks = {}
                for index, frame in ipairs(templates) do
                    if index == 3 or index == 4 then
                        local content = frame:FindFirstChild("Content")
                        local titleLabel = content and content:FindFirstChild("Label")
                        local typeLabel = content and content:FindFirstChild("Type")
                        if titleLabel and typeLabel then
                            table.insert(repeatableTasks, {frame = frame, title = titleLabel.Text, type = typeLabel.Text, slot = index})
                        end
                    end
                end

                local highestPriorityAction = nil
                local protectedSlots = {}
                for _, questData in ipairs(quests) do
                    local toggle = questToggles[questData.ID]
                    if toggle and toggle.Value then
                        for _, task in ipairs(repeatableTasks) do
                            local lowerTitle = task.title:lower():gsub("%s+", " ")
                            if task.type == "Repeatable" and lowerTitle:find(questData.Pattern, 1, true) then
                                if not protectedSlots[task.slot] then protectedSlots[task.slot] = true end
                                if not highestPriorityAction then
                                    local matchedEgg = nil
                                    for eggName in pairs(eggPositions) do
                                        if lowerTitle:find(eggName:lower():gsub(" egg", ""), 1, true) then
                                            matchedEgg = eggName
                                            break
                                        end
                                    end
                                    local selectedOption = Options["EggFor_"..questData.ID]
                                    local fallbackEgg = (selectedOption and selectedOption.Value) or questData.DefaultEgg
                                    local eggToHatch = matchedEgg or fallbackEgg
                                    highestPriorityAction = { egg = eggToHatch, title = task.title }
                                end
                            end
                        end
                    end
                end

                if highestPriorityAction then hatchEgg(highestPriorityAction.egg) end

                for _, task in ipairs(repeatableTasks) do
                    if task.type == "Repeatable" and not protectedSlots[task.slot] then
                        QuestRerollEvent:FireServer("CompetitiveReroll", task.slot)
                        task.wait(0.3)
                    end
                end
            end)
            if not success then warn("[ERROR] Task manager error:", err) end
            task.wait(0.5)
        end
    end

    MainTab:AddToggle("AutoTasks", {
        Title = "Enable Auto Complete Quests",
        Default = false,
        Callback = function(v)
            taskAutomationEnabled = v
            getgenv().autoPressE = v
            if v then
                task.spawn(taskManager)
                task.spawn(function()
                    while getgenv().autoPressE do
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait()
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        task.wait()
                    end
                end)
            end
        end
    })
    MainTab:AddSlider("TweenSpeed", { Title = "Character Tween Speed", Min = 16, Max = 150, Default = 30, Rounding = 0 })

    QuestTab:AddParagraph({ Title = "Enable quest categories to complete:" })
    for _, q in ipairs(quests) do
        local toggle = QuestTab:AddToggle("Quest_" .. q.ID, { Title = q.DisplayName, Default = false })
        questToggles[q.ID] = toggle
    end

    EggSettingsTab:AddParagraph({ Title = "Preferred Egg for each quest type:" })
    for _, q in ipairs(quests) do
        EggSettingsTab:AddDropdown("EggFor_" .. q.ID, { Title = q.DisplayName, Values = eggNames, Default = q.DefaultEgg })
    end
end

--// Finalize UI //--
Window:SelectTab(1)
SaveManager:Load() -- Load saved settings for all tabs

Fluent:Notify({
    Title = "Script Loaded",
    Content = "Successfully merged Enchant Reroller & Quest Helper.",
    Duration = 8
})
