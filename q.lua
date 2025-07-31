-- Standalone Upvalue Scanner (Connection Scanning Version)

print("Starting upvalue scan...")

-- Get ReplicatedStorage service
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Automatically search for the 'Chunker' module
print("Searching for the 'Chunker' ModuleScript...")
local chunkerModuleInstance = ReplicatedStorage:FindFirstChild("Chunker", true) -- The 'true' makes it search all subfolders

if not chunkerModuleInstance then
    warn("ERROR: Could not find a ModuleScript named 'Chunker' anywhere in ReplicatedStorage.")
    return
end

print("Found 'Chunker' module at: " .. chunkerModuleInstance:GetFullName())

-- Load the found module
local chunkerModule = require(chunkerModuleInstance)

print("Target module 'Chunker' loaded successfully. Now searching connections for scripts that are using it.")

-- List of common game events to check
local signalsToCheck = {
    game:GetService("RunService").Heartbeat,
    game:GetService("RunService").RenderStepped,
    game:GetService("Players").LocalPlayer.CharacterAdded
}

local found = false

-- Loop through each major game event signal
for _, signal in ipairs(signalsToCheck) do
    -- Get all functions connected to this signal
    local connections = getconnections(signal)
    for _, connection in ipairs(connections) do
        local func = connection.Function
        -- Scan the upvalues of each connected function
        for i = 1, 64 do
            local name, value = debug.getupvalue(func, i)
            if not name then break end
            
            -- Check if the upvalue is the Chunker module
            if value == chunkerModule then
                -- If it is, get the source script of that function
                local funcInfo = debug.info(func, "S")
                local scriptPath = funcInfo and funcInfo.source or "Unknown"
                if scriptPath:sub(1,1) == "@" then scriptPath = scriptPath:sub(2) end

                print("---------------------------------")
                print("!!! HIT !!!")
                print("Found a function connected to '" .. signal.Name .. "' that uses the Chunker module:")
                print(" -> SCRIPT PATH: " .. scriptPath)
                print("---------------------------------")
                
                found = true
                break
            end
        end
        if found then break end
    end
    if found then break end
end

if not found then
    print("Scan complete. No script was found holding a direct reference to the Chunker module via this method.")
end
