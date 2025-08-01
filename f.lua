-- Standalone Upvalue Scanner (Final Comprehensive Version)

print("Starting FINAL upvalue scan...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Automatically search for the 'Chunker' module
print("Searching for the 'Chunker' ModuleScript...")
local chunkerModuleInstance = ReplicatedStorage:FindFirstChild("Chunker", true)

if not chunkerModuleInstance then
    warn("ERROR: Could not find a ModuleScript named 'Chunker' anywhere in ReplicatedStorage.")
    return
end

print("Found 'Chunker' module at: " .. chunkerModuleInstance:GetFullName())
local chunkerModule = require(chunkerModuleInstance)
print("Target module loaded. Now performing comprehensive scan...")

local found = false

-- The core function that scans a function's upvalues
local function scanFunction(func, signalName)
    if found or typeof(func) ~= "function" then return end

    local success, funcInfo = pcall(debug.info, func, "u")
    local numUpvalues = (success and funcInfo and funcInfo.nups) or 0

    for i = 1, numUpvalues do
        local name, value = debug.getupvalue(func, i)
        if value == chunkerModule then
            local sourceInfo = debug.info(func, "S")
            local scriptPath = sourceInfo and sourceInfo.source or "Unknown"
            if scriptPath:sub(1,1) == "@" then scriptPath = scriptPath:sub(2) end

            print("---------------------------------")
            print("!!! HIT !!!")
            print("Found a function connected to '" .. signalName .. "' that uses the Chunker module:")
            print(" -> SCRIPT PATH: " .. scriptPath)
            print("---------------------------------")
            
            found = true
            break
        end
    end
end

-- A list of many common signals to check
local signalsToScan = {
    RunService.Heartbeat,
    RunService.RenderStepped,
    RunService.Stepped,
    Players.LocalPlayer.CharacterAdded,
    Players.PlayerAdded,
    Players.PlayerRemoving
}

-- Add all RemoteEvent signals to our scan list
for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
    if remote:IsA("RemoteEvent") then
        table.insert(signalsToScan, remote.OnClientEvent)
    end
end

print("Scanning " .. #signalsToScan .. " different game signals...")

-- Loop through the comprehensive list of signals
for _, signal in ipairs(signalsToScan) do
    if found then break end
    local connections = getconnections(signal)
    for _, connection in ipairs(connections) do
        if found then break end
        -- Pass the signal's name for better logging
        scanFunction(connection.Function, signal:GetFullName())
    end
end

if not found then
    print("Scan complete. No direct reference was found. The controller script is exceptionally well hidden.")
end
