--[[
    ========================================================================
    VISUALS ENGINE - 3-AXIS GYROSCOPE RINGS
    File: VisualsEngine/Modules/GyroRings.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local ObjectPool = import("Core/ObjectPool")

local GyroRings = {}
GyroRings.__index = GyroRings

function GyroRings.new()
    local self = setmetatable({}, GyroRings)
    self._enabled = false
    self._rings = {}

    local cfg = Config.GyroRings
    local totalSegments = #cfg.RingAngles * cfg.Segments

    self._segmentPool = ObjectPool.new(
        function()
            local p = Instance.new("Part")
            p.Name = "GyroSegment"
            p.Material = Enum.Material.Neon
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            p.Transparency = 1
            p.Size = Vector3.new(cfg.Thickness, cfg.Thickness, 1)
            return p
        end,
        function(p)
            if p:IsA("BasePart") then
                p.Transparency = 1
                p.CFrame = CFrame.new(0, -9999, 0)
            end
        end,
        totalSegments + 5,
        "GyroSegments"
    )

    return self
end

function GyroRings:Enable()
    if self._enabled then return end
    self._enabled = true

    local cfg = Config.GyroRings
    for i, baseAngle in ipairs(cfg.RingAngles) do
        local rotCFrame = CFrame.Angles(
            math.rad(baseAngle.X),
            math.rad(baseAngle.Y),
            math.rad(baseAngle.Z)
        )
        local segments = {}
        for _ = 1, cfg.Segments do
            table.insert(segments, self._segmentPool:Get())
        end
        table.insert(self._rings, {
            CurrentRotation = rotCFrame,
            Speed = cfg.RotationSpeeds[i] or Vector3.new(1, 1, 1),
            Segments = segments,
        })
    end
end

function GyroRings:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._segmentPool:ReturnAll()
    table.clear(self._rings)
end

function GyroRings:Update(dt, rootPos, colors)
    if not self._enabled then return end

    local cfg = Config.GyroRings
    local radius = cfg.Radius
    local thickness = cfg.Thickness
    local segmentCount = cfg.Segments
    local center = rootPos + Vector3.new(0, 0.5, 0)

    local colorPalette = {colors.Primary, colors.Secondary, colors.Accent}

    for rIndex, ring in ipairs(self._rings) do
        local deltaRot = CFrame.Angles(
            ring.Speed.X * dt,
            ring.Speed.Y * dt,
            ring.Speed.Z * dt
        )
        ring.CurrentRotation = ring.CurrentRotation * deltaRot

        local ringCFrame = CFrame.new(center) * ring.CurrentRotation
        local ringColor = colorPalette[((rIndex - 1) % #colorPalette) + 1]

        for s = 1, segmentCount do
            local theta1 = ((s - 1) / segmentCount) * (math.pi * 2)
            local theta2 = (s / segmentCount) * (math.pi * 2)

            local localP1 = Vector3.new(math.cos(theta1) * radius, 0, math.sin(theta1) * radius)
            local localP2 = Vector3.new(math.cos(theta2) * radius, 0, math.sin(theta2) * radius)

            local worldP1 = ringCFrame:PointToWorldSpace(localP1)
            local worldP2 = ringCFrame:PointToWorldSpace(localP2)

            local seg = ring.Segments[s]
            if seg then
                local dist = (worldP2 - worldP1).Magnitude
                seg.Size = Vector3.new(thickness, thickness, dist)
                seg.CFrame = CFrame.lookAt((worldP1 + worldP2) * 0.5, worldP2)
                seg.Color = ringColor
                seg.Transparency = 0.1
            end
        end
    end
end

function GyroRings:Destroy()
    self:Disable()
    self._segmentPool:Destroy()
end

return GyroRings
