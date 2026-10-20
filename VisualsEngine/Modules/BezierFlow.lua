--[[
    ========================================================================
    VISUALS ENGINE - BEZIER VECTOR FLOW STREAMS
    File: VisualsEngine/Modules/BezierFlow.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")
local ObjectPool = import("Core/ObjectPool")

local BezierFlow = {}
BezierFlow.__index = BezierFlow

function BezierFlow.new()
    local self = setmetatable({}, BezierFlow)
    self._enabled = false
    self._streams = {}
    self._time = 0

    self._segmentPool = ObjectPool.new(
        function()
            local p = Instance.new("Part")
            p.Name = "BezierSegment"
            p.Material = Enum.Material.Neon
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            p.Transparency = 1
            p.Size = Vector3.new(0.08, 0.08, 1)
            return p
        end,
        function(p)
            if p:IsA("BasePart") then p.Transparency = 1; p.CFrame = CFrame.new(0, -9999, 0) end
        end,
        Config.BezierFlow.StreamCount * Config.BezierFlow.SegmentsPerStream + 10,
        "BezierSegments"
    )

    return self
end

function BezierFlow:Enable()
    if self._enabled then return end
    self._enabled = true
    self._time = 0

    local streamCount = Config.BezierFlow.StreamCount
    for i = 1, streamCount do
        table.insert(self._streams, {
            PhaseOffset = (i / streamCount) * (math.pi * 2),
            RadiusOffset = (math.random() - 0.5) * 3.0,
            HeightOffset = (math.random() - 0.5) * 2.5,
            SpeedMultiplier = 0.85 + (math.random() * 0.35),
        })
    end
end

function BezierFlow:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._segmentPool:ReturnAll()
    table.clear(self._streams)
end

function BezierFlow:Update(dt, centerPos, primaryColor, secondaryColor)
    if not self._enabled then return end

    self._time = self._time + dt * Config.BezierFlow.Speed
    local tGlobal = self._time
    local cfg = Config.BezierFlow
    local segmentsCount = cfg.SegmentsPerStream

    self._segmentPool:ReturnAll()

    for _, stream in ipairs(self._streams) do
        local theta = tGlobal * stream.SpeedMultiplier + stream.PhaseOffset
        local baseRadius = cfg.Radius + stream.RadiusOffset

        local theta0 = theta - 0.85
        local p0 = centerPos + Vector3.new(
            math.cos(theta0) * baseRadius,
            math.sin(theta0 * 2.0) * (cfg.HeightRange * 0.4) + stream.HeightOffset,
            math.sin(theta0) * baseRadius
        )

        local theta1 = theta - 0.4
        local p1 = centerPos + Vector3.new(
            math.cos(theta1) * (baseRadius * 1.35),
            math.cos(theta1 * 1.5) * (cfg.HeightRange * 0.9) + stream.HeightOffset + 2.5,
            math.sin(theta1) * (baseRadius * 1.35)
        )

        local theta2 = theta
        local p2 = centerPos + Vector3.new(
            math.cos(theta2) * (baseRadius * 0.85),
            math.sin(theta2 * 2.0) * (cfg.HeightRange * 0.4) + stream.HeightOffset,
            math.sin(theta2) * (baseRadius * 0.85)
        )

        local prevPoint = MathUtils.quadraticBezier(p0, p1, p2, 0)

        for s = 1, segmentsCount do
            local t = s / segmentsCount
            local currentPoint = MathUtils.quadraticBezier(p0, p1, p2, t)

            local segPart = self._segmentPool:Get()
            local delta = currentPoint - prevPoint
            local dist = delta.Magnitude

            if dist > 0.001 then
                segPart.Color = MathUtils.lerpColor(secondaryColor, primaryColor, t)
                local width = cfg.LineWidth * (0.4 + 0.6 * math.sin(t * math.pi))
                segPart.Size = Vector3.new(width, width, dist)
                segPart.CFrame = CFrame.lookAt((prevPoint + currentPoint) * 0.5, currentPoint)
                segPart.Transparency = 0.05 + (1 - math.sin(t * math.pi)) * 0.35
            end

            prevPoint = currentPoint
        end
    end
end

function BezierFlow:Destroy()
    self:Disable()
    self._segmentPool:Destroy()
end

return BezierFlow
