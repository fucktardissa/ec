-- Combined Patcher to Skip Transitions and Ignore Robot Claw Logic

print("--- Applying Game Patches ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Check for hookfunction support first
if not hookfunction then
    warn("ERROR: Your executor does not support hookfunction(). Patches cannot be applied.")
    return
end

local transitionPatched = false
local cameraPatched = false

-- ## Part 1: Patch the Transition ##
print("Attempting to patch PlayTransition...")
local playTransitionModule = ReplicatedStorage:FindFirstChild("PlayTransition", true)
if playTransitionModule then
    local originalTransitionFunc = require(playTransitionModule)
    local function skipTransition(text, callback, icon)
        if typeof(callback) == "function" then
            task.spawn(callback)
        end
    end
    hookfunction(originalTransitionFunc, skipTransition)
    print(" > Successfully patched PlayTransition.")
    transitionPatched = true
else
    warn(" > Could not find PlayTransition module.")
end


-- ## Part 2: Patch the Robot Claw to do nothing ##
print("Attempting to patch Robot Claw logic...")
-- Use the exact path you discovered to find the module.
local robotClawModule = ReplicatedStorage:FindFirstChild("Client"):FindFirstChild("Gui"):FindFirstChild("Frames"):FindFirstChild("Minigames"):FindFirstChild("Robot Claw")

if robotClawModule and robotClawModule:IsA("ModuleScript") then
    local originalRunFunction = require(robotClawModule)
    
    -- ## THIS IS THE NEW LOGIC ##
    -- This function will run instead of the minigame's code.
    local function ignoreMinigameLogic(...)
        print("Hooked Robot Claw: Ignoring all client-side minigame logic.")
        
        -- The original function returned two functions, so we must also return two
        -- empty functions to prevent the game from breaking.
        local function emptyFunc() end
        return emptyFunc, emptyFunc
    end

    hookfunction(originalRunFunction, ignoreMinigameLogic)
    print(" > Successfully patched Robot Claw to ignore all logic.")
    cameraPatched = true
else
    warn(" > Could not find the Robot Claw module to patch.")
end


-- ## Final Status Report ##
print("--- Patching process finished. ---")
if transitionPatched and cameraPatched then
    print("Status: All patches were applied successfully.")
else
    print("Status: One or more patches FAILED. Check warnings above.")
end
