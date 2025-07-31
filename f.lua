-- Standalone Upvalue Scanner (Auto-Search Version)

print("Starting upvalue scan...")

-- Get ReplicatedStorage service
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ## THIS PART IS NEW ##
-- Automatically search for the 'Chunker' module anywhere inside ReplicatedStorage
print("Searching for the 'Chunker' ModuleScript...")
local chunkerModuleInstance = ReplicatedStorage:FindFirstChild("Chunker", true) -- The 'true' makes it search all subfolders

if not chunkerModuleInstance then
    warn("ERROR: Could not find a ModuleScript named 'Chunker' anywhere in ReplicatedStorage.")
    return
end

print("Found 'Chunker' module at: " .. chunkerModuleInstance:GetFullName())

-- Load the found module
local chunkerModule = require(chunkerModuleInstance)
-------------------------------------------------------------

print("Target module 'Chunker' loaded successfully. Now searching for scripts that are using it.")

-- Get a list of all running scripts (threads)
local allScripts = getscripts()
local found = false

for _, scriptThread in ipairs(allScripts) do
    if scriptThread.ClassName == "LocalScript" then
        -- An upvalue is a variable that a function 'remembers'. 
        -- We'll check the first 64 upvalues of each script, which is usually more than enough.
        for i = 1, 64 do
            -- Get the name and value of the upvalue
            local name, value = debug.getupvalue(scriptThread, i)
            
            -- If the value doesn't exist, there are no more upvalues for this script.
            if not name then break end
            
            -- Check if the value is the Chunker module we loaded earlier
            if value == chunkerModule then
                print("---------------------------------")
                print("!!! HIT !!!")
                print("Found a script that required the Chunker module:")
                print(" -> SCRIPT PATH: " .. scriptThread:GetFullName())
                print("---------------------------------")
                found = true
                break -- Stop checking this script's upvalues
            end
        end
        if found then
            break -- Stop checking other scripts
        end
    end
end

if not found then
    print("Scan complete. No script was found holding a direct reference to the Chunker module via this method.")
end
