-- Standalone Intelligent Auto-Dice Script (Corrected Target Scanning)

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

-- (The takeTurn function is unchanged and goes here)
local function takeTurn(diceType)
    print("Rolling with: " .. diceType)
    local success, rollResponse = pcall(function() return RemoteFunction:InvokeServer("RollDice", diceType) end)
    if success and rollResponse then
        print("  > Success! Rolled a:", rollResponse.Roll, ". Expected destination: Tile", rollResponse.Tile.Index)
        local expectedTile = rollResponse.Tile.Index
        local moveCompleted = false
        local startTime = tick()
        while tick() - startTime < 5 do
            task.wait(0.1)
            if LocalPlayer:GetAttribute("BoardIndex") == expectedTile then
                print("  > Landing confirmed at Tile " .. expectedTile)
                moveCompleted = true
                break
            end
        end
        if moveCompleted then
            local landedTileInfo = BoardUtil.Nodes[expectedTile]
            if landedTileInfo then print("  > VERIFICATION: Landed on Tile " .. expectedTile .. ", Type: '" .. landedTileInfo.Type .. "'") end
            print("  > Claiming tile reward...")
            RemoteEvent:FireServer("ClaimTile")
            task.wait(1)
            if getgenv().Config.DelayAfterRoll > 0 then
                print("  > Waiting for " .. getgenv().Config.DelayAfterRoll .. " seconds...")
                task.wait(getgenv().Config.DelayAfterRoll)
            end
            return rollResponse
        else
            print("  > Landing FAILED. Timed out.")
            return nil
        end
    else
        print("  > Roll failed or was rejected. Retrying...")
        task.wait(2.0)
        return nil
    end
end


print("Intelligent Auto-Dice script started. To stop, run: getgenv().Config.AutoBoardGame = false")

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
                -- This part was already correct, using getgenv()
                local isTarget = getgenv().Config.TILES_TO_TARGET[tileInfo.Type] and " (TARGET)" or ""
                print(string.format("  > +%d: Tile %d (%s)%s", i, nextTileIndex, tileInfo.Type, isTarget))
            end
        end
    end
    
    -- 1. Golden Dice Snipe Logic
    -- ## THE FIX: All instances of 'Config' are replaced with 'getgenv().Config' ##
    print("Scanning for Golden Dice targets (Range: " .. getgenv().Config.GOLDEN_DICE_DISTANCE .. " tiles)...")
    for i = 1, getgenv().Config.GOLDEN_DICE_DISTANCE do
        local nextTileIndex = currentTileNumber + i
        if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end
        
        local tileInfo = BoardUtil.Nodes[nextTileIndex]
        -- This check will now use the live, up-to-date config
        if tileInfo and getgenv().Config.TILES_TO_TARGET[tileInfo.Type] then
            print("Target '" .. tileInfo.Type .. "' found " .. i .. " tiles away! Using Golden Dice...")
            for j = 1, i do
                turnResponse = takeTurn("Golden Dice")
            end
            actionTaken = true
            break
        end
    end

    -- 2. Primary Dice Chance Logic (also fixed)
    if not actionTaken then
        local maxRoll = (getgenv().Config.DICE_TYPE == "Dice" and 6 or 10)
        print("Scanning for targets for a chance roll (Range: " .. maxRoll .. " tiles)...")
        for i = 1, maxRoll do
            local nextTileIndex = currentTileNumber + i
            if nextTileIndex > totalTiles then nextTileIndex = nextTileIndex - totalTiles end

            local tileInfo = BoardUtil.Nodes[nextTileIndex]
            if tileInfo and getgenv().Config.TILES_TO_TARGET[tileInfo.Type] then
                print("Target '" .. tileInfo.Type .. "' found in range! Using " .. getgenv().Config.DICE_TYPE .. " for a chance...")
                turnResponse = takeTurn(getgenv().Config.DICE_TYPE)
                actionTaken = true
                break
            end
        end
    end
    
    -- 3. Default Action (also fixed)
    if not actionTaken then
        print("No targets found in range. Performing default roll with " .. getgenv().Config.DICE_TYPE .. "...")
        turnResponse = takeTurn(getgenv().Config.DICE_TYPE)
    end

    if turnResponse then
        local landedTileIndex = turnResponse.Tile.Index
        local landedTileInfo = BoardUtil.Nodes[landedTileIndex]
        if landedTileInfo and landedTileInfo.Type == "chance" then
            print("Landed on a 'chance' tile. Waiting " .. getgenv().Config.DelayForChanceTile .. " seconds for the animation...")
            task.wait(getgenv().Config.DelayForChanceTile)
        end
    end
end

print("Intelligent Auto-Dice script has stopped.")
