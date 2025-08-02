-- Combined Transition Skipper & No Camera Move Patcher

print("--- Applying Game Patches ---")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
else
    warn(" > Could not find PlayTransition module.")
end


-- ## Part 2: Patch the Robot Claw Camera ##
print("Attempting to patch Robot Claw camera...")
local robotClawModule = ReplicatedStorage:FindFirstChild("Robot Claw", true)
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
else
    -- Fallback search for the nested module
    local minigamesFolder = ReplicatedStorage.Assets:FindFirstChild("Minigames")
    local robotClawFolder = minigamesFolder and minigamesFolder:FindFirstChild("Robot Claw")
    local nestedModule = robotClawFolder and robotClawFolder:FindFirstChildOfClass("ModuleScript")
    
    if nestedModule then
         local originalRunFunction = require(nestedModule)
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
        print(" > Successfully patched Robot Claw camera (found in Assets).")
    else
         warn(" > Could not find the Robot Claw module to patch.")
    end
end

print("--- All patches have been applied. ---")
