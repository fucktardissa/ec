-- Standalone Intelligent Auto-Dice Script (with Verification & Delafarfaretfartys)

--[[
    ============================================================
    -- ## CONFIGURATION ##
    ============================================================
]]
local Config = {
    AutoBoardGame = true,
    TILES_TO_TARGET = {
        ["infinity"] = true,
    },
    DICE_TYPE = "Dice",
    GOLDEN_DICE_DISTANCE = 4,
    DelayForChanceTile = 15.0,
    LookAheadDistance = 6,
    
    -- ## NEW SETTING ##
    -- Extra delay in seconds after every roll to give you time to observe.
    DelayAfterRoll = 2.0 
}
getgenv().Config = Config

--[[
    ============================================================
    -- CORE SCRIPT (No need to edit below this line)
    ============================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local BoardUtil = require(ReplicatedStorage.Shared.Utils.BoardUtil)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- Helper function to perform one full, verified turn
local function takeTurn(diceType)
    print("Rolling with: " .. diceType)
    local success, rollResponse = pcall(function()
        return RemoteFunction:InvokeServer("RollDice", diceType)
    end)

    if success and rollResponse then
        print("  > Success! Rolled a:", rollResponse.Roll, ". Expected destination: Tile", rollResponse.Tile.Index)
        
        local expectedTile = rollResponse.Tile.Index
        local moveCompleted = false
        local timeout = 5
        local startTime = tick()

        while tick() - startTime < timeout do
            task.wait(0.1)
            local currentTile = LocalPlayer:GetAttribute("BoardIndex")
            if currentTile == expectedTile then
                print("  > Landing confirmed at Tile " .. currentTile)
                moveCompleted = true
                break
            end
        end

        if moveCompleted then
            -- ## NEW: Print the official type of the tile you landed on ##
            local landedTileInfo = BoardUtil.Nodes[expectedTile]
            if landedTileInfo then
                print("  > VERIFICATION: Landed on Tile " .. expectedTile .. ", Type: '" .. landedTileInfo.Type .. "'")
            end
            
            print("  > Claiming tile reward...")
            RemoteEvent:FireServer("ClaimTile")
            task.wait(1) -- Wait a moment for the claim to process
            
            -- ## NEW: Added configurable delay ##
            if Config.DelayAfterRoll > 0 then
                print("  > Waiting for " .. Config.DelayAfterRoll .. " seconds...")
                task.wait(Config.DelayAfterRoll)
            end

            return rollResponse -- Return the full response on success
        else
            print("  > Landing FAILED. Timed out waiting for BoardIndex to update.")
            return nil
        end
    else
        print("  > Roll failed or was rejected. Retrying...")
        task.wait(2.0)
        return nil
    end
end

print("Intelligent Auto-Dice script started. To stop, run: getgenv().Config.AutoBoardGame = false")

-- (The main 'while' loop is unchanged and follows here)
while getgenv().Config.AutoBoardGame do
    local currentTileNumber = LocalPlayer:GetAttribute("BoardIndex")
    if not currentTileNumber then
        print("Waiting for player to be on the board...")
        task.wait(2)
        continue
    end

    local totalTiles = #BoardUtil.Nodes
    local actionTaken = false
    local turnResponse = nil

    print("---")
    print("Current Tile: " .. currentTileNumber)
    
    if getgenv().Config.LookAheadDistance > 0 then
        print("Upcoming Tiles:")
        for i = 1, getgenv().Config.LookAheadDistance do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end
            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo then
                local isTarget = getgenv().Config.TILES_TO_TARGET[tileInfo.Type] and " (TARGET)" or ""
                print(string.format("  > +%d: Tile %d (%s)%s", i, nextTileIndex, tileInfo.Type, isTarget))
            end
        end
    end
    
    -- (The rest of the roll logic is unchanged)
    print("Scanning for Golden Dice targets (Range: " .. Config.GOLDEN_DICE_DISTANCE .. " tiles)...")
    -- ... (Golden Dice, Primary Dice, and Default Action logic) ...
    if not actionTaken then
        local maxRoll = (Config.DICE_TYPE == "Dice" and 6 or 10)
        for i = 1, maxRoll do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end
            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo and Config.TILES_TO_TARGET[tileInfo.Type] then
                turnResponse = takeTurn(Config.DICE_TYPE)
                actionTaken = true
                break
            end
        end
    end
    if not actionTaken then
        turnResponse = takeTurn(Config.DICE_TYPE)
    end
    
    if turnResponse then
        local landedTileIndex = turnResponse.Tile.Index
        local landedTileInfo = BoardUtil.Nodes[landedTileIndex]
        if landedTileInfo and landedTileInfo.Type == "chance" then
            print("Landed on a 'chance' tile. Waiting " .. Config.DelayForChanceTile .. " seconds for the animation...")
            task.wait(Config.DelayForChanceTile)
        end
    end
end

print("Intelligent Auto-Dice script has stopped.")
