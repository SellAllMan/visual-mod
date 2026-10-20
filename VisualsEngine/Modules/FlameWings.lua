--[[
    ========================================================================
    VISUALS ENGINE - ETHEREAL FLAME WINGS
    File: VisualsEngine/Modules/FlameWings.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")

local FlameWings = {}
FlameWings.__index = FlameWings

function FlameWings.new()
    local self = setmetatable({}, FlameWings)
    self._enabled = false
    self._wings = {}
    self._holderPart = nil
    return self
end

local function getTorso(character)
    return character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

function FlameWings:Enable(character)
    if self._enabled then return end
    local torso = getTorso(character)
    if not torso then return end
    self._enabled = true

    local cfg = Config.FlameWings
    local cam = workspace.CurrentCamera or workspace

    local holder = Instance.new("Part")
    holder.Name = "MadiumFlameWingsHolder"
    holder.Transparency = 1
    holder.CanCollide = false
    holder.CanQuery = false
    holder.CastShadow = false
    holder.Anchored = true
    holder.Size = Vector3.new(0.1, 0.1, 0.1)
    holder.Parent = cam
    self._holderPart = holder

    for _, side in ipairs({-1, 1}) do
        local rootAtt = Instance.new("Attachment")
        rootAtt.Name = "FlameRoot_" .. side
        rootAtt.Parent = holder

        local tipAtt = Instance.new("Attachment")
        tipAtt.Name = "FlameTip_" .. side
        tipAtt.Parent = holder

        local beam = Instance.new("Beam")
        beam.Name = "FlameBeam_" .. side
        beam.Attachment0 = rootAtt
        beam.Attachment1 = tipAtt
        beam.Width0 = cfg.Width
        beam.Width1 = 0.2
        beam.LightEmission = cfg.LightEmission
        beam.LightInfluence = 0
        beam.FaceCamera = true
        beam.TextureSpeed = cfg.TextureSpeed
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(0.7, 0.25),
            NumberSequenceKeypoint.new(1, 1.0),
        })
        beam.Parent = holder

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "Sparks_" .. side
        emitter.Rate = 18
        emitter.Lifetime = NumberRange.new(0.4, 0.8)
        emitter.Speed = NumberRange.new(1.0, 3.0)
        emitter.SpreadAngle = Vector2.new(35, 35)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0.0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1.0),
        })
        emitter.LightEmission = 1.0
        emitter.LightInfluence = 0
        emitter.Parent = tipAtt

        table.insert(self._wings, {
            RootAtt = rootAtt,
            TipAtt = tipAtt,
            Beam = beam,
            Emitter = emitter,
            Side = side,
        })
    end
end

function FlameWings:Disable()
    if not self._enabled then return end
    self._enabled = false

    if self._holderPart then
        pcall(function() self._holderPart:Destroy() end)
        self._holderPart = nil
    end
    table.clear(self._wings)
end

function FlameWings:Update(dt, character, primaryColor, secondaryColor)
    if not self._enabled then return end
    local torso = getTorso(character)
    if not torso or not self._holderPart then return end

    self._holderPart.CFrame = torso.CFrame
    local cfg = Config.FlameWings

    local sineFlap = math.sin(tick() * 3.8)
    local turbulence = math.sin(tick() * cfg.WiggleSpeed) * cfg.WiggleAmount

    for _, wing in ipairs(self._wings) do
        local side = wing.Side
        wing.RootAtt.Position = Vector3.new(side * 0.5, 0.4, 0.4)

        local tipX = side * (3.8 + sineFlap * 0.8)
        local tipY = 1.6 + (sineFlap * 0.7) + turbulence * 0.3
        local tipZ = 1.8 - (sineFlap * 0.5)

        wing.TipAtt.Position = Vector3.new(tipX, tipY, tipZ)

        local colorSeq = ColorSequence.new({
            ColorSequenceKeypoint.new(0, primaryColor),
            ColorSequenceKeypoint.new(0.6, secondaryColor),
            ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
        })
        wing.Beam.Color = colorSeq
        wing.Emitter.Color = colorSeq
    end
end

function FlameWings:Destroy()
    self:Disable()
end

return FlameWings
