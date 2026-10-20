--[[
    ========================================================================
    VISUALS ENGINE - MATHEMATICAL & SPRING UTILITIES
    File: VisualsEngine/Core/MathUtils.lua
    ========================================================================
--]]

local MathUtils = {}

function MathUtils.polarToCartesian(radius, theta)
    return math.cos(theta) * radius, math.sin(theta) * radius
end

function MathUtils.cylindricalToVector3(radius, theta, y)
    return Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
end

function MathUtils.quadraticBezier(p0, p1, p2, t)
    local u = 1 - t
    return ((u * u) * p0) + (2 * u * t * p1) + ((t * t) * p2)
end

function MathUtils.cubicBezier(p0, p1, p2, p3, t)
    local u = 1 - t
    local uu = u * u
    local uuu = uu * u
    local tt = t * t
    local ttt = tt * t
    return (uuu * p0) + (3 * uu * t * p1) + (3 * u * tt * p2) + (ttt * p3)
end

function MathUtils.hslToRgb(h, s, l)
    h = h % 1
    if s == 0 then return Color3.new(l, l, l) end
    local function hueToRgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local q = if l < 0.5 then l * (1 + s) else l + s - l * s
    local p = 2 * l - q
    return Color3.new(hueToRgb(p, q, h + 1/3), hueToRgb(p, q, h), hueToRgb(p, q, h - 1/3))
end

function MathUtils.getRainbow(speed, offset)
    local t = tick() * (speed or 0.5) + (offset or 0)
    return MathUtils.hslToRgb(t % 1, 1, 0.55)
end

function MathUtils.lerpColor(c1, c2, alpha)
    return Color3.new(
        c1.R + (c2.R - c1.R) * alpha,
        c1.G + (c2.G - c1.G) * alpha,
        c1.B + (c2.B - c1.B) * alpha
    )
end

function MathUtils.brownianWander(pos, vel, center, maxR, spd, dt)
    local impulse = Vector3.new(
        (math.random() - 0.5) * 2,
        (math.random() - 0.5) * 2,
        (math.random() - 0.5) * 2
    ).Unit * (spd * 1.5)

    local nVel = (vel * 0.92) + (impulse * dt * 4.0)
    local offset = pos - center
    if offset.Magnitude > maxR then
        nVel = nVel - offset.Unit * (spd * 2.0 * dt)
    end
    return pos + nVel * dt, nVel
end

-- Spring Physics
local Spring = {}
Spring.__index = Spring

function Spring.new(k, d, initPos)
    local self = setmetatable({}, Spring)
    self.Stiffness = k or 180
    self.Damping = d or 18
    self.Position = initPos or Vector3.zero
    self.Velocity = Vector3.zero
    self.Target = initPos or Vector3.zero
    return self
end

function Spring:SetTarget(target)
    self.Target = target
end

function Spring:Update(dt)
    local clampedDt = math.min(dt, 0.05)
    local disp = self.Position - self.Target
    local force = -self.Stiffness * disp - self.Damping * self.Velocity
    self.Velocity = self.Velocity + force * clampedDt
    self.Position = self.Position + self.Velocity * clampedDt
    return self.Position
end

MathUtils.Spring = Spring

return MathUtils
