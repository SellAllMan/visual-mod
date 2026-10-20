--[[
    ========================================================================
    VISUALS ENGINE - AMBIENCE LIGHTING & RAINBOW ESP CHAMS
    File: VisualsEngine/Modules/AmbienceESP.lua
    ========================================================================
--]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")

local LocalPlayer = Players.LocalPlayer

local AmbienceESP = {}
AmbienceESP.__index = AmbienceESP

function AmbienceESP.new()
    local self = setmetatable({}, AmbienceESP)
    self._enabled = false
    self._bloom = nil
    self._colorCorrection = nil
    self._highlights = {}
    return self
end

function AmbienceESP:Enable()
    if self._enabled then return end
    self._enabled = true

    local cfg = Config.Ambience

    if cfg.BloomEnabled then
        local bloom = Lighting:FindFirstChild("__MadiumVisuals_Bloom")
        if not bloom then
            bloom = Instance.new("BloomEffect")
            bloom.Name = "__MadiumVisuals_Bloom"
            bloom.Parent = Lighting
        end
        bloom.Intensity = cfg.BloomIntensity
        bloom.Size = cfg.BloomSize
        bloom.Threshold = cfg.BloomThreshold
        bloom.Enabled = true
        self._bloom = bloom
    end

    if cfg.ColorCorrectionEnabled then
        local cc = Lighting:FindFirstChild("__MadiumVisuals_CC")
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "__MadiumVisuals_CC"
            cc.Parent = Lighting
        end
        cc.Contrast = cfg.Contrast
        cc.Saturation = cfg.Saturation
        cc.TintColor = cfg.TintColor
        cc.Enabled = true
        self._colorCorrection = cc
    end
end

function AmbienceESP:Disable()
    if not self._enabled then return end
    self._enabled = false

    if self._bloom then
        self._bloom.Enabled = false
    end
    if self._colorCorrection then
        self._colorCorrection.Enabled = false
    end

    for _, hl in pairs(self._highlights) do
        pcall(function() hl:Destroy() end)
    end
    table.clear(self._highlights)
end

function AmbienceESP:Update(dt, primaryColor)
    if not self._enabled then return end

    local cfg = Config.Ambience
    if not cfg.ESPEnabled then return end

    local espColor = if cfg.ESPRainbow then MathUtils.getRainbow(cfg.ESPRainbowSpeed) else primaryColor

    local activeModels = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                activeModels[char] = true

                local hl = self._highlights[char]
                if not hl or hl.Parent ~= char then
                    hl = Instance.new("Highlight")
                    hl.Name = "__MadiumVisuals_Highlight"
                    hl.FillTransparency = cfg.FillTransparency
                    hl.OutlineTransparency = cfg.OutlineTransparency
                    hl.Adornee = char
                    hl.Parent = char
                    self._highlights[char] = hl
                end

                hl.OutlineColor = espColor
                hl.FillColor = espColor
            end
        end
    end

    for model, hl in pairs(self._highlights) do
        if not activeModels[model] then
            pcall(function() hl:Destroy() end)
            self._highlights[model] = nil
        end
    end
end

function AmbienceESP:Destroy()
    self:Disable()
    if self._bloom then
        pcall(function() self._bloom:Destroy() end)
        self._bloom = nil
    end
    if self._colorCorrection then
        pcall(function() self._colorCorrection:Destroy() end)
        self._colorCorrection = nil
    end
end

return AmbienceESP
