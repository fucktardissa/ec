-- Combined Transition Skipper & No Camera Move Patcher (Corrected)213132213123123132213231

print("--- Applying Game Patches ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local transitionPatched = false
local cameraPatched = false

-- Check for hookfunction support first
if not hookfunction then
    warn("ERROR: Your executor does not support hookfunction(). Patches cannot be applied.")
    return
end

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


-- ## Part 2: Patch the Robot Claw Camera ##
print("Attempting to patch Robot Claw camera...")
-- Use the exact path you discovered to find the module.
local robotClawModule = ReplicatedStorage:FindFirstChild("Client"):FindFirstChild("Gui"):FindFirstChild("Frames"):FindFirstChild("Minigames"):FindFirstChild("Robot Claw")

if robotClawModule and robotClawModule:IsA("ModuleScript") then
    local originalRunFunction = require(robotClawModule)
    local function runWithoutCameraMove(...)
        local cleanupFunc, stateChangedFunc = originalRunFunction(...)
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        return cleanupFunc, stateChangedFunc
    end
    hookfunction(originalRunFunction, runWithoutCameraMove)
    print(" > Successfully patched Robot Claw camera.")
    cameraPatched = true
else
    warn(" > Could not find the Robot Claw module to patch at the expected path.")
end


-- ## Final Status Report ##
print("--- Patching process finished. ---")
if transitionPatched and cameraPatched then
    print("Status: All patches were applied successfully.")
else
    print("Status: One or more patches FAILED. Check warnings above.")
end
