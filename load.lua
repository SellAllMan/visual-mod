--[[
    ========================================================================
    VISUALS ENGINE - ONE-LINE QUICK LOADER
    File: load.lua (Placed in Madium/Workspace/)
    ========================================================================
    Usage in Madium / Executor:
        loadstring(readfile("load.lua"))()
        -- OR
        loadstring(readfile("VisualsEngine/init.lua"))()
    ========================================================================
--]]

if not readfile then
    error("[VisualsEngine] readfile() function was not detected in this executor environment.")
end

local entryPath = "VisualsEngine/init.lua"
local success, content = pcall(readfile, entryPath)

if not success or not content then
    error("[VisualsEngine] Unable to load '" .. entryPath .. "'. Please ensure the VisualsEngine folder is in Madium/Workspace.")
end

local runFunc, compileErr = loadstring(content, "=VisualsEngine/init.lua")
if not runFunc then
    error("[VisualsEngine] Compilation error in " .. entryPath .. ": " .. tostring(compileErr))
end

return runFunc()
