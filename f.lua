-- Diagnostic finder for the live Chunker instance
local islandsFolder = workspace.Worlds["The Overworld"].Islands
local samplePos
for _, island in ipairs(islandsFolder:GetChildren()) do
    if island:IsA("Model") and island:FindFirstChild("UnlockHitbox") then
        samplePos = island.UnlockHitbox.Position
        break
    end
end
if not samplePos then
    warn("No island UnlockHitbox found; aborting diagnostic.")
    return
end

local candidates = {}
for _, obj in ipairs(getgc(true)) do
    if typeof(obj) == "table" then
        -- Heuristic: has Update function and chunk-related fields
        local hasUpdate = type(rawget(obj, "Update")) == "function"
        local hasChunkSize = rawget(obj, "_chunkSize") ~= nil
        local hasRenderDistance = rawget(obj, "RenderDistance") ~= nil
        local hasLoadedTable = type(rawget(obj, "_loaded")) == "table"
        if hasUpdate and hasChunkSize and hasRenderDistance and hasLoadedTable then
            table.insert(candidates, obj)
        end
    end
end

if #candidates == 0 then
    warn("❌ No candidate Chunker instances found with the basic heuristics.")
else
    print(("Found %d candidate(s):"):format(#candidates))
    for idx, chunker in ipairs(candidates) do
        local ok, info = pcall(function()
            return {
                chunkSize = chunker._chunkSize,
                renderDistance = chunker.RenderDistance,
                loadedCount = (function()
                    local c = 0
                    for k in pairs(chunker._loaded) do c = c + 1 end
                    return c
                end)()
            }
        end)
        if ok then
            print(("\n[%d] chunkSize=%s, RenderDistance=%s, loadedChunks=%s"):format(
                idx,
                tostring(info.chunkSize),
                tostring(info.renderDistance),
                tostring(info.loadedCount)
            ))
        else
            print(("\n[%d] failed to read metadata from candidate"):format(idx))
        end

        -- Try forcing an update on sample island and see if it errors
        local success, err = pcall(function()
            chunker:Update(samplePos)
        end)
        if success then
            print(("  ➜ .Update(sampleIsland) succeeded on candidate %d"):format(idx))
        else
            print(("  ➜ .Update(sampleIsland) error on candidate %d: %s"):format(idx, tostring(err)))
        end
    end
end

-- If nothing works, fallback: search upvalues of functions for a Chunker-like table
print("\n--- Scanning upvalues of functions for embedded Chunker instance ---")
local foundViaUpvalues = false
for _, fn in ipairs(getgc(true)) do
    if type(fn) == "function" then
        for i = 1, 50 do
            local name, val = pcall(function() return debug.getupvalue(fn, i) end)
            if name and type(val) == "table" then
                if rawget(val, "_chunkSize") and type(rawget(val, "Update")) == "function" and rawget(val, "RenderDistance") ~= nil then
                    print("✅ Found embedded Chunker via upvalue in function:", fn)
                    print("   chunkSize=", val._chunkSize, "RenderDistance=", val.RenderDistance)
                    foundViaUpvalues = true
                    break
                end
            end
        end
    end
end
if not foundViaUpvalues then
    print("No embedded Chunker found in upvalues scan.")
end
