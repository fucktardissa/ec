--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoManagePets = true,
    RARITY_TO_SHINY = {"Common", "Unique", "Rare", "Epic", "Legendary"},
    PETS_TO_DELETE = {},
    RARITY_TO_DELETE = {"Common", "Unique", "Rare"},
    DELETE_LEGENDARY_SHINY = false,
    DELETE_LEGENDARY_MYTHIC = false,
    MAX_LEGENDARY_TIER_TO_DELETE = 2,
    CheckInterval = 2.0
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (WITH DEBUGGING)
    ============================================================
]]

-- ## Services & Modules ##
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetDatabase = require(ReplicatedStorage.Shared.Data.Pets)

-- ## Helper Functions ##
local function getPetTier(petName)
    local T1 = {["Emerald Golem"]=true, ["Inferno Dragon"]=true, ["Unicorn"]=true, ["Flying Pig"]=true, ["Lunar Serpent"]=true, ["Electra"]=true, ["Dark Serpent"]=true, ["Inferno Cube"]=true, ["Crystal Unicorn"]=true, ["Cyborg Phoenix"]=true, ["Neon Wyvern"]=true}
    local T2 = {["Neon Elemental"]=true, ["Green Hydra"]=true, ["Stone Gargoyle"]=true, ["Gummy Dragon"]=true}
    local T3 = {["NULLVoid"]=true, ["Virus"]=true, ["Demonic Hydra"]=true, ["Hexarium"]=true, ["Rainbow Shock"]=true, ["Space Invader"]=true, ["Bionic Shard"]=true, ["Neon Wire Eye"]=true, ["Equalizer"]=true, ["Candy Winged Hydra"]=true, ["Rock Candy Golem"]=true}
    if T1[petName] then return 1 end
    if T2[petName] then return 2 end
    if T3[petName] then return 3 end
    return 0
end

local function isInventoryFull()
    local storageLabel = PlayerGui.ScreenGui.Inventory.Frame.Top.StorageHolder.Storage
    local text = storageLabel.Text
    local current, max = text:match("(%d+)/(%d+)")
    if not (current and max) then return false end
    current, max = tonumber(current), tonumber(max)
    local isFull = current and max and current >= max
    print("DEBUG: Inventory check: " .. tostring(current) .. "/" .. tostring(max) .. ". Is full? " .. tostring(isFull))
    return isFull
end

-- ## Main Automation Loop ##
print("IMPROVED Pet Manager with DEBUGGING started. To stop, run: getgenv().Config.AutoManagePets = false")

while getgenv().Config.AutoManagePets do
    if isInventoryFull() then
        print("DEBUG: Inventory is full. Starting batch pet management...")
        local playerData = LocalData:Get()
        if not (playerData and playerData.Pets) then
            warn("DEBUG: Player data or pets not found. Retrying...")
            task.wait(getgenv().Config.CheckInterval)
            continue
        end

        -- Priority 1: Craft ALL possible shiny pets first.
        print("DEBUG: Starting shiny crafting phase.")
        local shiniesCraftedInPass
        repeat
            shiniesCraftedInPass = false
            local petGroups = {}
            for _, petInstance in pairs(playerData.Pets) do
                if not petGroups[petInstance.Name] then
                    petGroups[petInstance.Name] = {Count = 0, Instances = {}}
                end
                petGroups[petInstance.Name].Count = petGroups[petInstance.Name].Count + 1
                table.insert(petGroups[petInstance.Name].Instances, petInstance)
            end

            for petName, groupData in pairs(petGroups) do
                local petBaseData = PetDatabase[petName]
                if petBaseData and petBaseData.Rarity then
                    local rarity = petBaseData.Rarity
                    local requiredAmount = {["Common"] = 16, ["Unique"] = 16, ["Rare"] = 12, ["Epic"] = 12, ["Legendary"] = 10}[rarity]
                    print("DEBUG: Checking shiny for '" .. petName .. "' (Rarity: " .. rarity .. "). Have: " .. groupData.Count .. ", Need: " .. (requiredAmount or "N/A"))
                    if requiredAmount and table.find(getgenv().Config.RARITY_TO_SHINY, rarity) and groupData.Count >= requiredAmount then
                        print("DEBUG: CONDITION MET! Crafting shiny '" .. petName .. "'...")
                        RemoteEvent:FireServer("MakePetShiny", groupData.Instances[1].Id)
                        shiniesCraftedInPass = true
                        task.wait(0.2)
                    end
                end
            end
            if shiniesCraftedInPass then
                print("DEBUG: Completed a shiny crafting pass. Waiting for inventory to update...")
                task.wait(1)
                playerData = LocalData:Get()
            end
        until not shiniesCraftedInPass
        print("DEBUG: Shiny crafting phase complete.")

        -- Priority 2: If inventory is STILL full, proceed with batch deletion.
        print("DEBUG: Re-checking inventory before deletion phase.")
        while isInventoryFull() do
            print("DEBUG: Inventory still full. Starting a deletion pass.")
            local petDeletedInPass = false
            local allPets = {}
            for _, p in pairs(playerData.Pets) do table.insert(allPets, p) end

            if #allPets == 0 then
                print("DEBUG: No pets left to delete.")
                break
            end

            for i = #allPets, 1, -1 do
                local petInstance = allPets[i]
                local petBaseData = PetDatabase[petInstance.Name]
                print("DEBUG: Evaluating pet for deletion: '" .. petInstance.Name .. "' (Equipped: " .. tostring(petInstance.Equipped) .. ")")
                if petInstance.Equipped then continue end
                
                local shouldDelete = false
                local deleteReason = ""

                if table.find(getgenv().Config.PETS_TO_DELETE, petInstance.Name) then
                    shouldDelete = true
                    deleteReason = "it is in PETS_TO_DELETE list"
                elseif petBaseData and petBaseData.Rarity then
                    local rarity = petBaseData.Rarity
                    if rarity == "Legendary" then
                        if petInstance.Shiny and getgenv().Config.DELETE_LEGENDARY_SHINY then
                            shouldDelete = true
                            deleteReason = "it is a Legendary Shiny"
                        elseif petInstance.Mythic and getgenv().Config.DELETE_LEGENDARY_MYTHIC then
                            shouldDelete = true
                            deleteReason = "it is a Legendary Mythic"
                        else
                            local petTier = getPetTier(petInstance.Name)
                            if petTier > 0 and petTier <= getgenv().Config.MAX_LEGENDARY_TIER_TO_DELETE then
                                shouldDelete = true
                                deleteReason = "it is a Tier " .. petTier .. " Legendary"
                            end
                        end
                    elseif table.find(getgenv().Config.RARITY_TO_DELETE, rarity) then
                        shouldDelete = true
                        deleteReason = "its rarity (" .. rarity .. ") is in RARITY_TO_DELETE"
                    end
                end
                
                if shouldDelete then
                    print("DEBUG: CONDITION MET! Deleting '" .. petInstance.Name .. "' because " .. deleteReason)
                    RemoteEvent:FireServer("DeletePet", petInstance.Id, 1, false)
                    petDeletedInPass = true
                    table.remove(allPets, i)
                    task.wait(0.2)
                    break 
                end
            end
            
            if not petDeletedInPass then
                warn("DEBUG: Could not find any pets to delete in this pass. Breaking deletion loop to prevent getting stuck.")
                break
            end
            
            print("DEBUG: Deletion pass complete. Waiting for inventory to update.")
            task.wait(0.5)
            playerData = LocalData:Get()
        end
        print("DEBUG: Pet management cycle complete.")
    end
    
    task.wait(getgenv().Config.CheckInterval)
end

print("IMPROVED Pet Manager with DEBUGGING has stopped.")
