--[[
    ========================================================================
    VISUALS ENGINE - DOTTED POLAR ORBIT
    File: VisualsEngine/Modules/DottedOrbit.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")
local ObjectPool = import("Core/ObjectPool")

local DottedOrbit = {}
DottedOrbit.__index = DottedOrbit

function DottedOrbit.new()
    local self = setmetatable({}, DottedOrbit)
    self._enabled = false
    self._angle = 0
    self._activeDots = {}

    self._dotPool = ObjectPool.new(
        function()
            local dot = Instance.new("Part")
            dot.Name = "OrbitDot"
            dot.Shape = Enum.PartType.Ball
            dot.Material = Enum.Material.Neon
            dot.Anchored = true
            dot.CanCollide = false
            dot.CanQuery = false
            dot.CastShadow = false
            dot.Transparency = 1
            local sz = Config.DottedOrbit.DotSize
            dot.Size = Vector3.new(sz, sz, sz)
            return dot
        end,
        function(part)
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.CFrame = CFrame.new(0, -9999, 0)
            end
        end,
        Config.DottedOrbit.DotCount + 5,
        "OrbitDots"
    )

    return self
end

function DottedOrbit:Enable()
    if self._enabled then return end
    self._enabled = true
    self._angle = 0

    local count = Config.DottedOrbit.DotCount
    for _ = 1, count do
        local dot = self._dotPool:Get()
        dot.Transparency = 0.15
        table.insert(self._activeDots, dot)
    end
end

function DottedOrbit:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._dotPool:ReturnAll()
    table.clear(self._activeDots)
end

function DottedOrbit:Update(dt, rootPos, primaryColor, secondaryColor)
    if not self._enabled then return end

    local cfg = Config.DottedOrbit
    self._angle = (self._angle + dt * cfg.Speed) % (math.pi * 2)

    local count = #self._activeDots
    local baseRadius = cfg.Radius
    local waveAmp = cfg.WaveAmplitude
    local waveFreq = cfg.WaveFrequency
    local heightOffset = cfg.HeightOffset

    for i = 1, count do
        local frac = (i - 1) / count
        local theta = self._angle + (frac * math.pi * 2)

        local x = math.cos(theta) * baseRadius
        local z = math.sin(theta) * baseRadius
        local y = heightOffset + math.sin(theta * waveFreq + self._angle * 2.0) * waveAmp

        local dot = self._activeDots[i]
        dot.CFrame = CFrame.new(rootPos + Vector3.new(x, y, z))
        dot.Color = MathUtils.lerpColor(primaryColor, secondaryColor, (math.sin(theta) + 1) * 0.5)
        dot.Transparency = 0.15
    end
end

function DottedOrbit:Destroy()
    self:Disable()
    self._dotPool:Destroy()
end

return DottedOrbit
