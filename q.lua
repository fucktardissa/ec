-- Final Upvalue Scanner (Deep Connection Scan)

print("Starting DEEP upvalue scan...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- Automatically search for the 'Chunker' module
print("Searching for the 'Chunker' ModuleScript...")
local chunkerModuleInstance = ReplicatedStorage:FindFirstChild("Chunker", true)

if not chunkerModuleInstance then
    warn("ERROR: Could not find a ModuleScript named 'Chunker' anywhere in ReplicatedStorage.")
    return
end

print("Found 'Chunker' module at: " .. chunkerModuleInstance:GetFullName())
local chunkerModule = require(chunkerModuleInstance)
print("Target module loaded. Now performing deep scan...")

local found = false

-- This is the core scanning function
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
            print("!!! DEEP SCAN HIT !!!")
            print("Found a function connected to '" .. signalName .. "' that uses the Chunker module:")
            print(" -> SCRIPT PATH: " .. scriptPath)
            print("---------------------------------")
            
            found = true
            break
        end
    end
end

-- Function to scan all connections on a given object
local function scanObjectConnections(object)
    if found then return end
    for _, signal in pairs(getconnections(object)) do
        scanFunction(signal.Function, object.Name .. "." .. signal.Name)
        if found then break end
    end
end

-- Scan all major services
local servicesToScan = {RunService, Players, Players.LocalPlayer, UserInputService, ContextActionService}
for _, service in ipairs(servicesToScan) do
    scanObjectConnections(service)
    if found then break end
end

-- Recursively scan all GUI elements
local function scanGui(guiObject)
    if found then return end
    pcall(scanObjectConnections, guiObject)
    for _, child in ipairs(guiObject:GetChildren()) do
        scanGui(child)
    end
end

if not found then
    print("Scanning PlayerGui...")
    scanGui(Players.LocalPlayer:WaitForChild("PlayerGui"))
end

if not found then
    print("Scan complete. No direct reference was found. The controller script is likely very well hidden.")
end
