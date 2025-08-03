-- ================== CONFIGURATION ==================
local Config = {
    -- Set to true for detailed console messages, false to hide them.
    Debug = true,

    -- Set to true to start rerolling. The script will set this to false when done.
    AutoReroll = true,
    
    -- Delay in seconds between each reroll attempt.
    RerollDelay = 0.1,

    -- ## Enchant Targets - METHOD 1 (PRIORITY) ##
    -- If this list is NOT empty, the script will ONLY look for these enchants.
    -- Names must be exact, including the tier (e.g., "Team Up V").
    TARGET_ENCHANTS = {
        -- Example: "Team Up V", "Secret Hunter"
    },

    -- ## Enchant Targets - METHOD 2 (FALLBACK) ##
    -- If the TARGET_ENCHANTS list above is empty, the script will use these settings.
    ENCHANT_TEAMUP = true,  
    ENCHANT_TEAMUP_TIER = 5, 
    ENCHANT_HIGH_ROLLER = false,
    ENCHANT_SECRET_HUNTER = false
}
getgenv().Config = Config

-- ================== CORE SCRIPT (No need to edit below) ==================

-- ## Services & Modules ##
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalData = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Framework"):WaitForChild("Services"):WaitForChild("LocalData"))
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local RerollEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- ## Enchant Data & Helpers ##
local AllEnchants = { "Bubbler I", "Bubbler II", "Bubbler III", "Bubbler IV", "Bubbler V", "Gleaming I", "Gleaming II", "Gleaming III", "Looter I", "Looter II", "Looter III", "Looter IV", "Looter V", "Team Up I", "Team Up II", "Team Up III", "Team Up IV", "Team Up V", "High Roller", "Infinity", "Magnetism", "Secret Hunter", "Ultra Roller", "Determination", "Shiny Seeker" }
local enchantLookup = {}

local function parseEnchantName(name)
    local romanMap = { I = 1, II = 2, III = 3, IV = 4, V = 5 }
    local baseName, roman = name:match("^(.*) (%S+)$")
    local level = romanMap[roman]
    if baseName and level then
        return { id = baseName:lower():gsub(" ", "-"), level = level, fullName = name }
    else
        return { id = name:lower():gsub(" ", "-"), level = 1, fullName = name }
    end
end

for _, fullName in ipairs(AllEnchants) do
    local parsed = parseEnchantName(fullName)
    if not enchantLookup[parsed.id] then enchantLookup[parsed.id] = {} end
    enchantLookup[parsed.id][parsed.level] = fullName
end

local function getPetDataById(petId)
    local playerData = LocalData:Get()
    if not (playerData and playerData.Pets) then return nil end
    for _, petData in pairs(playerData.Pets) do
        if petData.Id == petId then return petData end
    end
    return nil
end

local function getEquippedPets()
    local equippedPets = {}
    local playerData = LocalData:Get()
    if not (playerData and playerData.TeamEquipped and playerData.Teams and playerData.Pets) then return {} end

    local teamInfo = playerData.Teams[playerData.TeamEquipped]
    if not (teamInfo and teamInfo.Pets) then return {} end
    
    for _, petId in ipairs(teamInfo.Pets) do
        local petInfo = getPetDataById(petId)
        if petInfo then
            local nameParts = {}
            if petInfo.Shiny then table.insert(nameParts, "Shiny") end
            if petInfo.Mythic then table.insert(nameParts, "Mythic") end
            table.insert(nameParts, petInfo.Name or "Unknown Pet")
            petInfo.FullName = table.concat(nameParts, " ")
            table.insert(equippedPets, petInfo)
        end
    end
    return equippedPets
end

local function findEnchantSlot(petInfo, targetEnchants)
    if not (petInfo and petInfo.Enchants) then return nil end
    for _, currentEnchant in pairs(petInfo.Enchants) do
        for _, targetEnchant in ipairs(targetEnchants) do
            if currentEnchant.Id == targetEnchant.id and currentEnchant.Level == targetEnchant.level then
                return enchantLookup[currentEnchant.Id][currentEnchant.Level]
            end
        end
    end
    return nil
end

local function getPetRarity(petName)
    if PetDatabase[petName] and PetDatabase[petName].Rarity then
        return PetDatabase[petName].Rarity
    end
    return "Unknown"
end


-- ## Main Reroll Logic ##
task.spawn(function()
    local scriptConfig = getgenv().Config
    if not scriptConfig.AutoReroll then return end
    print("Starting auto-enchanter...")

    -- 1. Build the list of target enchants from the config using the priority rule
    local targetEnchants = {}
    if #scriptConfig.TARGET_ENCHANTS > 0 then
        if scriptConfig.Debug then print("Using TARGET_ENCHANTS list as priority.") end
        for _, enchantName in ipairs(scriptConfig.TARGET_ENCHANTS) do
            table.insert(targetEnchants, parseEnchantName(enchantName))
        end
    else
        if scriptConfig.Debug then print("TARGET_ENCHANTS is empty. Using individual toggles as fallback.") end
        if scriptConfig.ENCHANT_TEAMUP then table.insert(targetEnchants, parseEnchantName("Team Up " .. ({'I','II','III','IV','V'})[scriptConfig.ENCHANT_TEAMUP_TIER])) end
        if scriptConfig.ENCHANT_HIGH_ROLLER then table.insert(targetEnchants, parseEnchantName("High Roller")) end
        if scriptConfig.ENCHANT_SECRET_HUNTER then table.insert(targetEnchants, parseEnchantName("Secret Hunter")) end
    end
    
    if #targetEnchants == 0 then
        warn("No enchants selected in config. Stopping.")
        scriptConfig.AutoReroll = false
        return
    end

    if scriptConfig.Debug then
        local targetNames = {}
        for _, t in ipairs(targetEnchants) do table.insert(targetNames, t.fullName) end
        print("Final Targets: " .. table.concat(targetNames, ", "))
    end

    -- 2. Get all equipped pets to reroll
    local petsToReroll = getEquippedPets()
    if #petsToReroll == 0 then
        warn("Could not find any equipped pets. Stopping.")
        scriptConfig.AutoReroll = false
        return
    end
    
    print("Auto-targeting all " .. #petsToReroll .. " equipped pets.")

    -- 3. Loop through each target pet and reroll it until it's done
    for _, petData in ipairs(petsToReroll) do
        if not scriptConfig.AutoReroll then break end
        print("Now targeting: " .. petData.FullName)
        
        local validEnchantsForThisPet = {}
        local petRarity = getPetRarity(petData.Name)

        for _, enchant in ipairs(targetEnchants) do
            if enchant.id == "secret-hunter" then
                if petRarity == "Secret" then
                    table.insert(validEnchantsForThisPet, enchant)
                else
                    if scriptConfig.Debug then print("-> Skipping Secret Hunter for " .. petData.Name .. " (Rarity is " .. petRarity .. ", not Secret)") end
                end
            else
                table.insert(validEnchantsForThisPet, enchant)
            end
        end

        if #validEnchantsForThisPet == 0 then
            warn("No valid enchants to roll for on " .. petData.FullName .. ". Skipping this pet.")
            continue
        end
        
        while scriptConfig.AutoReroll do
            local currentPetData = getPetDataById(petData.Id)
            local foundEnchant = findEnchantSlot(currentPetData, validEnchantsForThisPet)

            if foundEnchant then
                print("SUCCESS! Found '" .. foundEnchant .. "' on " .. petData.FullName)
                break
            else
                RemoteFunction:InvokeServer("RerollEnchants", currentPetData.Id, "Gems")
            end
            task.wait(scriptConfig.RerollDelay)
        end
    end

    -- 4. Clean up
    if scriptConfig.AutoReroll then
        print("Finished processing all pets.")
    else
        print("Rerolling stopped by user.")
    end
    scriptConfig.AutoReroll = false
end)
