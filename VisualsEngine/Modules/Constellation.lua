--[[
    ========================================================================
    VISUALS ENGINE - CONSTELLATION NETWORK
    File: VisualsEngine/Modules/Constellation.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")
local ObjectPool = import("Core/ObjectPool")

local Constellation = {}
Constellation.__index = Constellation

function Constellation.new()
    local self = setmetatable({}, Constellation)
    self._enabled = false
    self._nodes = {}
    self._activeLines = {}

    self._linePool = ObjectPool.new(
        function()
            local p = Instance.new("Part")
            p.Name = "ConstellationLine"
            p.Material = Enum.Material.Neon
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            p.Transparency = 1
            return p
        end,
        function(p)
            if p:IsA("BasePart") then p.Transparency = 1; p.CFrame = CFrame.new(0, -9999, 0) end
        end,
        60,
        "ConstellationLines"
    )

    self._nodePool = ObjectPool.new(
        function()
            local p = Instance.new("Part")
            p.Name = "ConstellationNode"
            p.Shape = Enum.PartType.Ball
            p.Material = Enum.Material.Neon
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            local sz = Config.Constellation.NodeSize
            p.Size = Vector3.new(sz, sz, sz)
            return p
        end,
        function(p)
            if p:IsA("BasePart") then p.Transparency = 1; p.CFrame = CFrame.new(0, -9999, 0) end
        end,
        Config.Constellation.NodeCount + 5,
        "ConstellationNodes"
    )

    return self
end

function Constellation:Enable(centerPos)
    if self._enabled then return end
    self._enabled = true

    local count = Config.Constellation.NodeCount
    local radius = Config.Constellation.Radius
    local height = Config.Constellation.HeightOffset

    for _ = 1, count do
        local phi = math.acos(2 * math.random() - 1)
        local theta = 2 * math.pi * math.random()
        local r = radius * (0.3 + 0.7 * math.random())

        local offset = Vector3.new(
            r * math.sin(phi) * math.cos(theta),
            r * math.cos(phi) * 0.6 + height,
            r * math.sin(phi) * math.sin(theta)
        )

        local part = self._nodePool:Get()
        part.Transparency = 0.2
        part.CFrame = CFrame.new(centerPos + offset)

        table.insert(self._nodes, {
            Position = centerPos + offset,
            Velocity = Vector3.new(
                (math.random() - 0.5) * Config.Constellation.Speed,
                (math.random() - 0.5) * Config.Constellation.Speed * 0.5,
                (math.random() - 0.5) * Config.Constellation.Speed
            ),
            Part = part,
        })
    end
end

function Constellation:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._linePool:ReturnAll()
    self._nodePool:ReturnAll()
    table.clear(self._nodes)
    table.clear(self._activeLines)
end

function Constellation:Update(dt, centerPos, primaryColor, secondaryColor)
    if not self._enabled then return end

    local cfg = Config.Constellation
    local connectDistSq = cfg.ConnectDistance * cfg.ConnectDistance
    local lineThickness = cfg.LineThickness
    local centerWithHeight = centerPos + Vector3.new(0, cfg.HeightOffset, 0)

    self._linePool:ReturnAll()
    table.clear(self._activeLines)

    local nodeCount = #self._nodes
    for i = 1, nodeCount do
        local node = self._nodes[i]
        local newPos, newVel = MathUtils.brownianWander(
            node.Position,
            node.Velocity,
            centerWithHeight,
            cfg.Radius,
            cfg.Speed,
            dt
        )
        node.Position = newPos
        node.Velocity = newVel
        node.Part.CFrame = CFrame.new(newPos)
        node.Part.Color = primaryColor
        node.Part.Transparency = 0.15
    end

    local maxPerNode = cfg.MaxConnectionsPerNode
    local connectionCounts = table.create(nodeCount, 0)

    for i = 1, nodeCount - 1 do
        local p1 = self._nodes[i].Position
        if connectionCounts[i] >= maxPerNode then continue end

        for j = i + 1, nodeCount do
            if connectionCounts[i] >= maxPerNode then break end
            if connectionCounts[j] >= maxPerNode then continue end

            local p2 = self._nodes[j].Position
            local delta = p2 - p1
            local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z

            if distSq <= connectDistSq and distSq > 0.001 then
                local dist = math.sqrt(distSq)
                local line = self._linePool:Get()
                local alpha = dist / cfg.ConnectDistance
                local trans = 0.1 + (alpha * alpha) * 0.85

                line.Transparency = trans
                line.Color = MathUtils.lerpColor(primaryColor, secondaryColor, alpha)
                line.Size = Vector3.new(lineThickness, lineThickness, dist)
                line.CFrame = CFrame.lookAt((p1 + p2) * 0.5, p2)

                connectionCounts[i] = connectionCounts[i] + 1
                connectionCounts[j] = connectionCounts[j] + 1
                table.insert(self._activeLines, line)
            end
        end
    end
end

function Constellation:Destroy()
    self:Disable()
    self._linePool:Destroy()
    self._nodePool:Destroy()
end

return Constellation
