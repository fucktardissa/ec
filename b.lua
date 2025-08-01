-- Standalone Intelligent Auto-Dice Script (with Extra Debug)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    -- Master toggle for the script. Set to false in your executor to stop.
    AutoBoardGame = true,

    -- A list of tile types the script should try to land on.
    -- Common types: "special-egg", "infinity", "super-ticket", "dice-key", "rift", "chance"
    TILES_TO_TARGET = {
        ["special-egg"] = true,
        ["infinity"] = true,
    },

    -- The dice to use for general rolls when not sniping with Golden Dice.
    -- Options: "Dice" (rolls 1-6), "Giant Dice" (rolls 1-10)
    DICE_TYPE = "Dice",

    -- The maximum distance (number of tiles) you are willing to use Golden Dice to reach a target.
    -- Golden Dice move exactly 1 tile per roll.
    GOLDEN_DICE_DISTANCE = 4,

    -- Time in seconds to wait after a roll for the animation to finish.
    DelayAfterRoll = 1.0
}
getgenv().Config = Config -- Make it accessible globally

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

-- Get services and modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local BoardUtil = require(ReplicatedStorage.Shared.Utils.BoardUtil)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- Helper function to perform one full turn (roll + claim)
local function takeTurn(diceType)
    print("Rolling with: " .. diceType)
    local success, rollResponse = pcall(function()
        return RemoteFunction:InvokeServer("RollDice", diceType)
    end)

    if success and rollResponse then
        print("  > Success! Rolled a:", rollResponse.Roll)
        print("  > Waiting for turn to complete...")
        task.wait(Config.DelayAfterRoll)
        RemoteEvent:FireServer("ClaimTile")
        task.wait(1.5) -- Extra delay for safety
        return true
    else
        print("  > Roll failed or was rejected. Retrying...")
        task.wait(2.0)
        return false
    end
end

print("Intelligent Auto-Dice script started. To stop, run: getgenv().Config.AutoBoardGame = false")

-- Main decision-making loop
while getgenv().Config.AutoBoardGame do
    local currentTileNumber = LocalPlayer:GetAttribute("BoardIndex")
    if not currentTileNumber then
        print("Waiting for player to be on the board...")
        task.wait(2)
    else
        local totalTiles = #BoardUtil.Nodes
        local actionTaken = false

        print("---") -- Separator for clarity
        print("Current Tile: " .. currentTileNumber)
        
        -- 1. Golden Dice Snipe Logic
        print("Scanning for Golden Dice targets (Range: " .. Config.GOLDEN_DICE_DISTANCE .. " tiles)...")
        for i = 1, Config.GOLDEN_DICE_DISTANCE do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end
            
            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo then
                -- ## NEW DEBUG MESSAGE ##
                print("  -> Upcoming #" .. i .. " (Tile " .. nextTileIndex .. "): " .. tileInfo.Type)
                if Config.TILES_TO_TARGET[tileInfo.Type] then
                    print("   - TARGET FOUND! Using Golden Dice...")
                    for j = 1, i do
                        takeTurn("Golden Dice")
                    end
                    actionTaken = true
                    break
                end
            end
        end

        if actionTaken then continue end

        -- 2. Primary Dice Chance Logic
        local maxRoll = (Config.DICE_TYPE == "Dice" and 6 or 10)
        print("Scanning for targets for a chance roll (Range: " .. maxRoll .. " tiles)...")
        for i = 1, maxRoll do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end

            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo then
                -- ## NEW DEBUG MESSAGE ##
                print("  -> Upcoming #" .. i .. " (Tile " .. nextTileIndex .. "): " .. tileInfo.Type)
                if Config.TILES_TO_TARGET[tileInfo.Type] then
                    print("   - TARGET FOUND! Using " .. Config.DICE_TYPE .. " for a chance...")
                    takeTurn(Config.DICE_TYPE)
                    actionTaken = true
                    break
                end
            end
        end
        
        if actionTaken then continue end

        -- 3. Default Action (No targets in range)
        print("No targets found in range. Performing default roll with " .. Config.DICE_TYPE .. "...")
        takeTurn(Config.DICE_TYPE)
    end
end

print("Intelligent Auto-Dice script has stopped.")
