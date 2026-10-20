--[[
    ========================================================================
    VISUALS ENGINE - POLYGON CRYSTAL WINGS
    File: VisualsEngine/Modules/PolygonWings.lua
    ========================================================================
--]]

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")

local PolygonWings = {}
PolygonWings.__index = PolygonWings

function PolygonWings.new()
    local self = setmetatable({}, PolygonWings)
    self._enabled = false
    self._facets = {}
    self._container = nil
    return self
end

local function getTorso(character)
    return character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

function PolygonWings:Enable()
    if self._enabled then return end
    self._enabled = true

    local cam = workspace.CurrentCamera or workspace
    local container = Instance.new("Folder")
    container.Name = "MadiumPolygonWings"
    container.Parent = cam
    self._container = container

    local cfg = Config.PolygonWings
    local facetCount = cfg.FacetCount

    for _, side in ipairs({-1, 1}) do
        for f = 1, facetCount do
            local progress = f / facetCount
            local length = (1.2 + (1 - progress * 0.4) * 2.8)
            local width = 0.25 * (1 - progress * 0.3)
            local thickness = cfg.FacetThickness

            local part = Instance.new("WedgePart")
            part.Name = (side == -1 and "WingL_" or "WingR_") .. f
            part.Material = Enum.Material.Neon
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CastShadow = false
            part.Size = Vector3.new(thickness, width, length)
            part.Parent = container

            local spread = (f - 1) * 14
            table.insert(self._facets, {
                Part = part,
                LocalOffset = Vector3.new(
                    side * (0.4 + (f - 1) * 0.3),
                    0.4 - (f - 1) * 0.35,
                    0.5 + (f - 1) * 0.15
                ),
                BaseRotation = Vector3.new(
                    -10 - spread * 0.6,
                    side * (30 + spread * 0.8),
                    side * (-20 - spread * 0.5)
                ),
                Side = side,
                FacetIndex = f,
            })
        end
    end
end

function PolygonWings:Disable()
    if not self._enabled then return end
    self._enabled = false

    if self._container then
        pcall(function() self._container:Destroy() end)
        self._container = nil
    end
    table.clear(self._facets)
end

function PolygonWings:Update(dt, character, primaryColor, secondaryColor)
    if not self._enabled then return end
    local torso = getTorso(character)
    if not torso then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local isMoving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
    local isJumping = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall

    local cfg = Config.PolygonWings
    local flapSpeed = cfg.FlapSpeed * (if isMoving then 1.5 else 1.0)
    local sineVal = math.sin(tick() * flapSpeed)

    local flapAngle = math.rad(
        cfg.IdleSpread
        + (if isMoving or isJumping then cfg.MoveSpreadBoost else 0)
        + sineVal * cfg.FlapAmplitude
    )

    local torsoCFrame = torso.CFrame

    for _, facet in ipairs(self._facets) do
        local side = facet.Side
        local fIdx = facet.FacetIndex
        local featherPhase = math.sin(tick() * flapSpeed - (fIdx * 0.2)) * math.rad(cfg.FlapAmplitude)

        local rotAngles = CFrame.Angles(
            math.rad(facet.BaseRotation.X),
            math.rad(facet.BaseRotation.Y) + (side * (flapAngle + featherPhase)),
            math.rad(facet.BaseRotation.Z) + (side * sineVal * 0.15)
        )

        facet.Part.CFrame = torsoCFrame * CFrame.new(facet.LocalOffset) * rotAngles
        facet.Part.Color = MathUtils.lerpColor(primaryColor, secondaryColor, (fIdx - 1) / (cfg.FacetCount - 1))
        facet.Part.Transparency = 0.05
    end
end

function PolygonWings:Destroy()
    self:Disable()
end

return PolygonWings
