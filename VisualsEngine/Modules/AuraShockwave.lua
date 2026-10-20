--[[
    ========================================================================
    VISUALS ENGINE - SHOCKWAVE RIPPLES
    File: VisualsEngine/Modules/AuraShockwave.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local ObjectPool = import("Core/ObjectPool")

local AuraShockwave = {}
AuraShockwave.__index = AuraShockwave

function AuraShockwave.new()
    local self = setmetatable({}, AuraShockwave)
    self._enabled = false
    self._spawnTimer = 0
    self._ripples = {}

    self._ripplePool = ObjectPool.new(
        function()
            local p = Instance.new("Part")
            p.Name = "ShockwaveRipple"
            p.Shape = Enum.PartType.Cylinder
            p.Material = Enum.Material.Neon
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CastShadow = false
            p.Transparency = 1
            p.Size = Vector3.new(0.06, 1, 1)
            return p
        end,
        function(p)
            if p:IsA("BasePart") then p.Transparency = 1; p.CFrame = CFrame.new(0, -9999, 0) end
        end,
        15,
        "ShockwaveRipples"
    )

    return self
end

function AuraShockwave:Enable()
    if self._enabled then return end
    self._enabled = true
    self._spawnTimer = 0
end

function AuraShockwave:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._ripplePool:ReturnAll()
    table.clear(self._ripples)
end

function AuraShockwave:SpawnRipple(rootPos)
    local cfg = Config.AuraShockwave
    local rayOrigin = rootPos + Vector3.new(0, 1.5, 0)
    local rayDirection = Vector3.new(0, -cfg.GroundRaycastDistance, 0)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local cam = workspace.CurrentCamera
    if cam then
        local poolFolder = cam:FindFirstChild("__VisualEngine_MadiumPool")
        if poolFolder then
            rayParams.FilterDescendantsInstances = {poolFolder}
        end
    end

    local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    local groundPos = if rayResult then rayResult.Position + Vector3.new(0, 0.04, 0) else rootPos - Vector3.new(0, 2.5, 0)
    local normal = if rayResult then rayResult.Normal else Vector3.new(0, 1, 0)

    local part = self._ripplePool:Get()
    part.Transparency = 0.2
    part.Size = Vector3.new(cfg.Thickness, 0.5, 0.5)

    table.insert(self._ripples, {
        Position = groundPos,
        Normal = normal,
        Age = 0,
        Part = part,
    })
end

function AuraShockwave:Update(dt, rootPos, primaryColor)
    if not self._enabled then return end

    local cfg = Config.AuraShockwave
    self._spawnTimer = self._spawnTimer + dt
    if self._spawnTimer >= cfg.Interval then
        self._spawnTimer = 0
        self:SpawnRipple(rootPos)
    end

    local i = 1
    while i <= #self._ripples do
        local ripple = self._ripples[i]
        ripple.Age = ripple.Age + dt

        if ripple.Age >= cfg.Lifetime then
            self._ripplePool:Return(ripple.Part)
            table.remove(self._ripples, i)
        else
            local progress = ripple.Age / cfg.Lifetime
            local radiusEase = math.sin(progress * (math.pi * 0.5))
            local currentRadius = cfg.MaxRadius * radiusEase
            local diameter = math.max(0.1, currentRadius * 2)

            local alphaFade = 0.15 + (progress ^ 1.8) * 0.85

            local part = ripple.Part
            part.Color = primaryColor
            part.Transparency = alphaFade
            part.Size = Vector3.new(cfg.Thickness, diameter, diameter)

            local lookRotation = CFrame.lookAt(ripple.Position, ripple.Position + ripple.Normal)
            part.CFrame = lookRotation * CFrame.Angles(0, 0, math.pi * 0.5)

            i = i + 1
        end
    end
end

function AuraShockwave:Destroy()
    self:Disable()
    self._ripplePool:Destroy()
end

return AuraShockwave
