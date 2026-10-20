--[[
    ========================================================================
    VISUALS ENGINE - MASTER ENGINE & EXECUTOR LOADER
    File: VisualsEngine/init.lua
    Target: Madium Executor (loadstring / readfile)
    ========================================================================
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- -------------------------------------------------------------------------
-- 1. MODULAR READFILE / LOADSTRING IMPORT SYSTEM
-- -------------------------------------------------------------------------
local loadedModules = {}

local function import(modulePath)
    local path = modulePath
    if not string.find(path, "%.lua$") then
        path = path .. ".lua"
    end

    if loadedModules[path] then
        return loadedModules[path]
    end

    local fullPath = "VisualsEngine/" .. path
    local content = nil

    if isfile and isfile(fullPath) then
        content = readfile(fullPath)
    elseif readfile then
        local ok, res = pcall(readfile, fullPath)
        if ok and res then
            content = res
        end
    end

    if not content then
        error("[VisualsEngine] Failed to read module at: " .. fullPath)
    end

    local fn, err = loadstring(content, "=" .. fullPath)
    if not fn then
        error("[VisualsEngine] Syntax error in " .. fullPath .. ": " .. tostring(err))
    end

    local res = fn(import)
    loadedModules[path] = res
    return res
end

if getgenv then
    getgenv().VisualsEngine_Import = import
else
    _G.VisualsEngine_Import = import
end

-- -------------------------------------------------------------------------
-- 2. CLEANUP EXISTING ENGINE INSTANCE (Safe Hot-Reload)
-- -------------------------------------------------------------------------
local globalEnv = (getgenv and getgenv()) or _G
if globalEnv.VisualsEngineInstance then
    pcall(function()
        globalEnv.VisualsEngineInstance:Stop()
    end)
    globalEnv.VisualsEngineInstance = nil
end

-- -------------------------------------------------------------------------
-- 3. LOAD CORE & MODULES
-- -------------------------------------------------------------------------
local Config = import("Config")
local MathUtils = import("Core/MathUtils")

local Constellation = import("Modules/Constellation")
local BezierFlow = import("Modules/BezierFlow")
local AuraShockwave = import("Modules/AuraShockwave")
local DottedOrbit = import("Modules/DottedOrbit")
local GyroRings = import("Modules/GyroRings")
local PolygonWings = import("Modules/PolygonWings")
local FlameWings = import("Modules/FlameWings")
local TargetHUD = import("Modules/TargetHUD")
local ControlGUI = import("Modules/ControlGUI")
local InWorldMenu = import("Modules/InWorldMenu")
local AmbienceESP = import("Modules/AmbienceESP")

local Engine = {
    _running = false,
    _activeTheme = Config.Global.CurrentTheme,
    _globalAuraEnabled = true,
    _renderConn = nil,
    _inputConn = nil,
    _charAddedConn = nil,
}

-- Module instances
local constellationMod = Constellation.new()
local bezierMod = BezierFlow.new()
local shockwaveMod = AuraShockwave.new()
local orbitMod = DottedOrbit.new()
local gyroMod = GyroRings.new()
local polyWingsMod = PolygonWings.new()
local flameWingsMod = FlameWings.new()
local targetHudMod = TargetHUD.new()
local ambienceMod = AmbienceESP.new()

local moduleMap = {
    Constellation = constellationMod,
    BezierFlow = bezierMod,
    AuraShockwave = shockwaveMod,
    DottedOrbit = orbitMod,
    GyroRings = gyroMod,
    PolygonWings = polyWingsMod,
    FlameWings = flameWingsMod,
    TargetHUD = targetHudMod,
    Ambience = ambienceMod,
}

local function getActiveColors()
    local themeKey = Engine._activeTheme
    if themeKey == "Rainbow" then
        return {
            Primary = MathUtils.getRainbow(Config.Themes.Rainbow.Speed, 0),
            Secondary = MathUtils.getRainbow(Config.Themes.Rainbow.Speed, 0.33),
            Accent = MathUtils.getRainbow(Config.Themes.Rainbow.Speed, 0.66),
        }
    end

    local preset = Config.Themes[themeKey] or Config.Themes.Cyberpunk
    return {
        Primary = preset.Primary,
        Secondary = preset.Secondary,
        Accent = preset.Accent,
    }
end

-- GUI Callbacks
local function onToggleModule(modName, state)
    local mod = moduleMap[modName]
    if mod then
        if state then
            local char = LocalPlayer.Character
            if modName == "FlameWings" and char then
                mod:Enable(char)
            elseif modName == "Constellation" and char and char:FindFirstChild("HumanoidRootPart") then
                mod:Enable(char.HumanoidRootPart.Position)
            else
                mod:Enable()
            end
        else
            mod:Disable()
        end
    end
end

local function onThemeChange(themeName)
    Engine._activeTheme = themeName
end

-- Initialize UI Controllers
local controlGui = ControlGUI.new(onToggleModule, onThemeChange)
local inWorldMenu = InWorldMenu.new(onToggleModule, onThemeChange)
moduleMap["InWorldMenu"] = inWorldMenu

local function enableDefaultModules(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    local rootPos = if root then root.Position else Vector3.zero

    if Config.Constellation.Enabled then constellationMod:Enable(rootPos) end
    if Config.BezierFlow.Enabled then bezierMod:Enable() end
    if Config.AuraShockwave.Enabled then shockwaveMod:Enable() end
    if Config.DottedOrbit.Enabled then orbitMod:Enable() end
    if Config.GyroRings.Enabled then gyroMod:Enable() end
    if Config.PolygonWings.Enabled then polyWingsMod:Enable() end
    if Config.FlameWings.Enabled then flameWingsMod:Enable(char) end
    if Config.TargetHUD.Enabled then targetHudMod:Enable() end
    if Config.Ambience.BloomEnabled or Config.Ambience.ESPEnabled then ambienceMod:Enable() end
end

-- -------------------------------------------------------------------------
-- 4. SINGLE RENDER LOOP (RenderStepped)
-- -------------------------------------------------------------------------
local function onRenderStep(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local char = LocalPlayer.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rootPos = root.Position

    local colors = getActiveColors()

    -- 3D In-World Menu update if active
    if inWorldMenu and inWorldMenu.IsOpen and inWorldMenu:IsOpen() then
        inWorldMenu:Update(dt, camera)
    end

    -- Visual Effects Aura
    if Engine._globalAuraEnabled then
        constellationMod:Update(dt, rootPos, colors.Primary, colors.Secondary)
        bezierMod:Update(dt, rootPos, colors.Primary, colors.Secondary)
        shockwaveMod:Update(dt, rootPos, colors.Primary)
        orbitMod:Update(dt, rootPos, colors.Primary, colors.Secondary)
        gyroMod:Update(dt, rootPos, colors)
        polyWingsMod:Update(dt, char, colors.Primary, colors.Secondary)
        flameWingsMod:Update(dt, char, colors.Primary, colors.Secondary)
    end

    -- Target HUD
    targetHudMod:Update(dt, char, colors.Primary)

    -- Ambience & ESP
    ambienceMod:Update(dt, colors.Primary)
end

-- -------------------------------------------------------------------------
-- 5. KEYBINDS
-- -------------------------------------------------------------------------
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Config.Global.MenuKey or input.KeyCode == Enum.KeyCode.Insert then
        controlGui:Toggle()
    elseif input.KeyCode == Config.Global.QuickToggleKey then
        Engine._globalAuraEnabled = not Engine._globalAuraEnabled
        if not Engine._globalAuraEnabled then
            constellationMod:Disable()
            bezierMod:Disable()
            shockwaveMod:Disable()
            orbitMod:Disable()
            gyroMod:Disable()
            polyWingsMod:Disable()
            flameWingsMod:Disable()
        else
            local char = LocalPlayer.Character
            if char then
                enableDefaultModules(char)
            end
        end
    end
end

-- -------------------------------------------------------------------------
-- 6. ENGINE LIFECYCLE
-- -------------------------------------------------------------------------
function Engine:Start()
    if self._running then return end
    self._running = true

    self._renderConn = RunService.RenderStepped:Connect(onRenderStep)
    self._inputConn = UserInputService.InputBegan:Connect(onInputBegan)

    if LocalPlayer.Character then
        task.spawn(function()
            enableDefaultModules(LocalPlayer.Character)
        end)
    end

    self._charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.25)
        if self._running and self._globalAuraEnabled then
            enableDefaultModules(newChar)
        end
    end)
end

function Engine:Stop()
    if not self._running then return end
    self._running = false

    if self._renderConn then
        self._renderConn:Disconnect()
        self._renderConn = nil
    end
    if self._inputConn then
        self._inputConn:Disconnect()
        self._inputConn = nil
    end
    if self._charAddedConn then
        self._charAddedConn:Disconnect()
        self._charAddedConn = nil
    end

    for _, mod in pairs(moduleMap) do
        mod:Disable()
    end
    controlGui:Destroy()
    inWorldMenu:Destroy()
end

Engine:Start()
globalEnv.VisualsEngineInstance = Engine

print("-------------------------------------------------------------------")
print("[Madium Workspace] NEON PROTOCOL Visuals Engine Loaded Successfully!")
print("Press [RightShift] or [Insert] to toggle the Control GUI.")
print("Press [V] to quick-toggle all visual auras.")
print("-------------------------------------------------------------------")

return Engine
