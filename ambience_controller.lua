-- ========================================================
-- Advanced Horizon Ambience, Fog & Modular FX Controller
-- บันทึกใน Madium Workspace
-- อัปเดต:
-- 1. ปรับลดความรัวของจุดหางลงอีกนิด (StepRatio = 0.58 ซ้อนทับ 42% ไร้รอยต่อ นุ่มนวล ไม่สแปมจุดเกินไป)
-- 2. ป้องกันไม่ให้อนุภาคและจุดหางเกิดใกล้หรือทับตัวละคร (Safe Distance >= 18 studs จาก Character + เบี่ยงทิศทางหลบตัวละคร)
-- 3. เพิ่มปุ่มสลับความถี่จุดหาง (Dot Rate) ในเมนู GUI
-- 4. เพิ่มระบบ Tesseract (4D Hypercube Simulation แท้ 100%):
--    - หมุนมิติ 4D ในระนาบ XW, ZW, YW ทำให้กล่องในกลืนขยายเป็นกล่องนอก และกล่องนอกพับหดกลับเข้าไปข้างในแบบ Hypnotic Folding
--    - คำนวณ Perspective Projection จาก 4 มิติลง 3 มิติแบบ Real-time ทุกเฟรม (ลื่นไหล 60 FPS)
--    - เส้นขอบ 32 เส้น เป็นสีทึบปกติ (Solid Neon 32 Edges)
--    - หน้าของมัน 24 หน้า เป็นสีโปร่งใสเห็นจางๆ ยืดหดบิดตามมิติอย่างสมบูรณ์ (Translucent 24 Dynamic Faces)
--    - ปรับจำนวนเริ่มต้นเพิ่มขึ้นเป็น 6 ชิ้น (สลับเกิดได้เยอะขึ้น)
--    - เกิดและลอยอยู่สูงกว่าตัวเราเสมอ (MinHeightAbove >= 16 studs ปรับระดับตามผู้เล่นอัตโนมัติ)
--    - ลอยขึ้นลงแบบคงที่รอบระดับความสูงที่เกิด (Bobbing Oscillation)
-- ========================================================

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- เคลียร์การเชื่อมต่อและออบเจ็กต์เก่าป้องกันลูปซ้อนทับกัน
if _G.AmbienceControllerCleanup then
    pcall(_G.AmbienceControllerCleanup)
    _G.AmbienceControllerCleanup = nil
end
if CoreGui:FindFirstChild("AmbienceControllerUI") then
    CoreGui.AmbienceControllerUI:Destroy()
end
if workspace:FindFirstChild("CustomAmbienceParticles") then
    workspace.CustomAmbienceParticles:Destroy()
end

-- ========================================================
-- Settings & State
-- ========================================================
local CurrentState = {
    ClockTime = 0, -- กลางคืน
    Color = Color3.fromRGB(160, 160, 255),
    FogDensity = 0.5,
    FogHaze = 3,
    FogEnd = 300,
    FogStart = 0,
    ForceLock = true,
    GlowStrength = 1.2
}

-- การตั้งค่าแยกอิสระของแต่ละระบบ
local Config = {
    GlobalSpawnDistance = 1.0,         -- ตัวคูณระยะการเกิดของทุกระบบ (1.0 = เริ่มต้นและเป็นระยะต่ำสุด)
    OuterDistanceSpawnBoost = 1.0,     -- ตัวคูณปรับการเกิดของระยะอื่น (1.0 = เท่าที่คำนวณออกมาเดิม, ปรับเพิ่ม = เพิ่มการเกิดในระยะอื่นโดยไม่กระทบระยะปกติ)
    -- 1. เส้นหักมุม 90°
    Snap = {
        Enabled = true,
        MaxCount = 20,
        Speed = 13,
        LifeTime = 20,
        TrailLifetime = 3.5,
        MaxDistance = 85
    },
    -- 2. ละอองหมอกเลี้ยวโค้ง (Droplet Mist: ช้าลงนุ่มนวล + หางเชื่อมสนิท 100%)
    CurveDroplet = {
        Enabled = true,
        MaxCount = 20,
        Speed = 5.2,           -- ปรับความเร็วเริ่มต้นให้ช้าลงตามที่ขอ (5.2 ลอยเอื่อยๆ สบายตา)
        HeadSize = 0.28,       -- ขนาดเริ่มต้นกะทัดรัด
        LifeTime = 6.0,        -- อายุหมุนเวียนเกิดใหม่ต่อเนื่อง
        DotFadeTime = 1.5,     -- จุดละอองอยู่นาน 1.5 วิ
        StepRatio = 0.58,      -- ระยะห่างระหว่างจุดหาง (ปรับลดความรัวลงอีกนิดตามที่ขอ ซ้อนทับ 42% ไร้รอยต่อ)
        MinCharDist = 18,      -- ระยะห่างขั้นต่ำจากตัวละคร (ไม่เกิดใกล้ตัว char เกินไป)
        MaxDistance = 70
    },
    -- 3. กระสุนเลี้ยวโค้งหางแสงปกติ (Ribbon Trail)
    CurveRibbon = {
        Enabled = true,
        MaxCount = 18,
        Speed = 7.5,
        HeadSize = 0.28,
        LifeTime = 6.0,
        TrailLifetime = 0.9,
        MaxDistance = 75
    },
    -- 4. ละอองลอยปกติ
    Classic = {
        Enabled = true,
        MaxCount = 25,
        Speed = 1.0,
        Size = 0.4,
        LifeTime = 8,
        MaxDistance = 70
    },
    -- 5. เทสเซอแรคต์ มิติที่ 4 (Tesseract 4D Hypercube: หมุนมิติ 4D พลิกกลับในออกนอกแท้ๆ)
    Tesseract = {
        Enabled = true,
        MaxCount = 6,              -- ปรับเพิ่มจำนวนเริ่มต้นเป็น 6 ชิ้นตามที่ขอ (เกิดได้เยอะขึ้น)
        Size = 2.2,                -- ขนาดสเกล 4D (ปรับให้เล็กลงกะทัดรัดตามที่ขอ)
        EdgeThickness = 0.055,     -- ความหนาเส้นทึบ (เพรียวบางคมชัดรับกับขนาดใหม่)
        FaceTransparency = 0.82,   -- ความโปร่งใสของหน้า (ใสเห็นจางๆ)
        BobAmplitude = 1.4,        -- ระยะลอยขึ้นลงแบบคงที่
        BobSpeed = 1.3,            -- ความเร็วลอยขึ้นลง
        Speed4D = 0.55,            -- ความเร็วในการหมุน 4D พลิกมิติม้วนจากในออกนอก
        MinHeightAbove = 15,       -- ต้องอยู่สูงกว่าตัวเราเสมอ (ขั้นต่ำ 15 studs)
        MinSeparation = 13,        -- ระยะห่างขั้นต่ำระหว่าง Tesseract แต่ละชิ้น (ไม่อยู่ชิดกันและไม่ห่างเกินไป)
        MaxDistance = 95,          -- ระยะขอบเขตปลอดภัย ไม่ชนระยะบังคับตาย
        LifeTime = 45              -- อายุหมุนเวียนเกิดใหม่
    }
}

local ParticleFolder = Instance.new("Folder")
ParticleFolder.Name = "CustomAmbienceParticles"
ParticleFolder.Parent = workspace

local activeSnap = {}
local activeCurveDroplet = {}
local activeCurveDots = {}
local activeCurveRibbon = {}
local activeClassic = {}
local activeTesseract = {}

-- Atmosphere & ColorCorrection
local function getOrCreateAtmosphere()
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmo then
        atmo = Instance.new("Atmosphere")
        atmo.Name = "CustomHorizonAtmosphere"
        atmo.Parent = Lighting
    end
    return atmo
end

local customColorCorrection = Lighting:FindFirstChild("CustomAmbienceCC")
if not customColorCorrection then
    customColorCorrection = Instance.new("ColorCorrectionEffect")
    customColorCorrection.Name = "CustomAmbienceCC"
    customColorCorrection.Parent = Lighting
end

-- Selective HDR Bloom
local customBloom = Lighting:FindFirstChild("CustomAmbienceBloom")
if not customBloom then
    customBloom = Instance.new("BloomEffect")
    customBloom.Name = "CustomAmbienceBloom"
    customBloom.Parent = Lighting
end

local function applyLightingSettings()
    Lighting.ClockTime = CurrentState.ClockTime
    Lighting.GlobalShadows = true
    Lighting.Ambient = CurrentState.Color
    Lighting.OutdoorAmbient = CurrentState.Color
    Lighting.ColorShift_Top = CurrentState.Color
    Lighting.ColorShift_Bottom = Color3.new(
        CurrentState.Color.R * 0.35,
        CurrentState.Color.G * 0.35,
        CurrentState.Color.B * 0.35
    )

    Lighting.FogColor = CurrentState.Color
    Lighting.FogStart = CurrentState.FogStart
    Lighting.FogEnd = CurrentState.FogEnd

    local atmosphere = getOrCreateAtmosphere()
    if atmosphere then
        atmosphere.Color = CurrentState.Color
        atmosphere.Decay = CurrentState.Color
        atmosphere.Density = CurrentState.FogDensity
        atmosphere.Offset = 0
        atmosphere.Haze = CurrentState.FogHaze
        atmosphere.Glare = 0
    end

    if customColorCorrection then
        customColorCorrection.TintColor = Color3.new(
            0.7 + (CurrentState.Color.R * 0.3),
            0.7 + (CurrentState.Color.G * 0.3),
            0.7 + (CurrentState.Color.B * 0.3)
        )
    end

    if customBloom then
        customBloom.Threshold = 1.05
        customBloom.Intensity = CurrentState.GlowStrength
        customBloom.Size = 26
    end
end
applyLightingSettings()

-- Anti-Reset
local lockConnection
local function updateLockState()
    if CurrentState.ForceLock then
        if not lockConnection then
            lockConnection = RunService.RenderStepped:Connect(function()
                if CurrentState.ForceLock then applyLightingSettings() end
            end)
        end
    else
        if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
    end
end
updateLockState()

-- Helper สำหรับแกน 90 องศา
local AXIS = {
    Vector3.new(1,0,0), Vector3.new(-1,0,0),
    Vector3.new(0,1,0), Vector3.new(0,-1,0),
    Vector3.new(0,0,1), Vector3.new(0,0,-1)
}

local function getPerpendicular(cur)
    local c = {}
    for _, a in ipairs(AXIS) do
        if math.abs(cur:Dot(a)) < 0.1 then table.insert(c, a) end
    end
    return c[math.random(1, #c)] or AXIS[math.random(1, #AXIS)]
end

local function cleanList(list)
    for i = #list, 1, -1 do
        if list[i].Instance and list[i].Instance.Parent then
            list[i].Instance:Destroy()
        end
        table.remove(list, i)
    end
end

-- ========================================================
-- SPAWNERS & SAFETY HELPERS (ป้องกันไม่ให้เกิดใกล้ตัวละคร)
-- ========================================================
local function getCharacterPosition()
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if root then
            return root.Position
        end
    end
    return Camera and Camera.CFrame.Position or Vector3.new(0, 10, 0)
end

-- คำนวณระยะการเกิดตามตัวคูณ GlobalSpawnDistance และ OuterDistanceSpawnBoost:
-- ถ้าเท่ากับ 1.0 (ค่าเริ่มต้น): สุ่มสม่ำเสมอปกติในระยะเดิม (ไม่เยอะหรือน้อยตรงไหน)
-- ถ้าปรับเพิ่ม GlobalSpawnDistance: ขยายระยะไปสู่ระยะอื่นได้ โดยระยะปกติเกิดเท่าเดิม
-- ถ้าปรับเพิ่ม OuterDistanceSpawnBoost: เพิ่มจำนวนและการเกิดในระยะอื่นตามที่ตั้งค่า โดยไม่ส่งผลกระทบต่อระยะปกติ
local function sampleSpawnDistance(minD, baseMaxD)
    local distMult = math.max(1.0, Config.GlobalSpawnDistance or 1.0)
    if distMult <= 1.001 then
        -- ระยะปกติ 100% สม่ำเสมอ ไม่กระทบอะไรเลย
        return minD + (math.random() * (baseMaxD - minD))
    end

    local maxD = baseMaxD * distMult
    local outerBoost = math.max(1.0, Config.OuterDistanceSpawnBoost or 1.0)

    -- โอกาสที่อนุภาคจะเกิดใน "ระยะอื่น" (Extended Range: นอกขอบเขตระยะปกติเดิม)
    local baseOuterChance = (distMult - 1.0) / (distMult + 0.8)
    local finalOuterChance = math.clamp(baseOuterChance * outerBoost, 0, 0.85)

    if math.random() < finalOuterChance then
        -- เกิดใน "ระยะอื่น" (นอกระยะปกติ: baseMaxD ถึง maxD)
        -- ยิ่งไกลยิ่งเกิดน้อยลงภายในโซนนี้
        local t = math.random() ^ 1.35
        return baseMaxD + (t * (maxD - baseMaxD))
    else
        -- เกิดใน "ระยะปกติ" (minD ถึง baseMaxD): สม่ำเสมอตามเดิม ไม่ส่งผลกระทบใดๆ
        return minD + (math.random() * (baseMaxD - minD))
    end
end

-- คำนวณขีดจำกัดจำนวนอนุภาคสูงสุด (MaxCount) แบบไดนามิก:
-- เมื่อขยายระยะและเปิดบูสต์ระยะอื่น ระบบจะเพิ่มโควตาจำนวนอนุภาคสำหรับระยะอื่นโดยเฉพาะ
-- ทำให้เกิดในระยะอื่นได้หนาแน่นตามต้องการ โดยระยะปกติยังคงมีจำนวนเต็มเปี่ยมเท่าเดิม ไม่ถูกแย่งโควตา
local function getEffectiveMaxCount(baseMaxCount)
    local distMult = math.max(1.0, Config.GlobalSpawnDistance or 1.0)
    if distMult <= 1.001 then
        return baseMaxCount
    end
    local outerBoost = math.max(1.0, Config.OuterDistanceSpawnBoost or 1.0)
    local extraForOuter = math.floor(baseMaxCount * (distMult - 1.0) * 0.35 * outerBoost)
    return baseMaxCount + extraForOuter
end

-- สุ่มตำแหน่งเกิดที่ปลอดภัยรอบตัว โดยไม่เกิดใกล้หรือทับตัวละครเด็ดขาด
local function getSafeSpawnPos(minCharDist, maxDist, minCamDist)
    local charPos = getCharacterPosition()
    local camCFrame = Camera and Camera.CFrame or CFrame.new(charPos + Vector3.new(0, 5, 12))
    local camPos = camCFrame.Position
    local camLook = camCFrame.LookVector

    minCharDist = minCharDist or 18
    maxDist = maxDist or 45
    minCamDist = minCamDist or 10

    for _ = 1, 15 do
        local angle = math.random() * math.pi * 2
        local dist = sampleSpawnDistance(minCharDist, maxDist)
        local distRatio = dist / maxDist
        local height = math.random(-3, 14) + math.max(0, (distRatio - 1.0) * 8)
        local forwardPush = camLook * (math.random(4, 16) * math.min(distRatio, 1.5))

        local candidate = charPos + forwardPush + Vector3.new(math.cos(angle) * dist, height, math.sin(angle) * dist)

        local distToChar = (candidate - charPos).Magnitude
        local distToCam = (candidate - camPos).Magnitude

        if distToChar >= minCharDist and distToCam >= minCamDist then
            return candidate
        end
    end

    -- Fallback ปลอดภัยเสมอ
    local fallbackAngle = math.random() * math.pi * 2
    return charPos + (camLook * 14) + Vector3.new(math.cos(fallbackAngle) * minCharDist, 4, math.sin(fallbackAngle) * minCharDist)
end

-- 1. เส้นหักมุม 90°
local function spawnSnapLine()
    local spawnPos = getSafeSpawnPos(16, 50, 10)

    local p = Instance.new("Part")
    p.Name = "SnapNode"
    p.Size = Vector3.new(0.05, 0.05, 0.05)
    p.CFrame = CFrame.new(spawnPos)
    p.Transparency = 1
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Anchored = true
    p.Parent = ParticleFolder

    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 0.035, 0)
    a0.Parent = p

    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -0.035, 0)
    a1.Parent = p

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.FaceCamera = true
    trail.LightEmission = 1
    trail.Lifetime = Config.Snap.TrailLifetime
    trail.Color = ColorSequence.new(CurrentState.Color)
    trail.WidthScale = NumberSequence.new(1)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.85, 0.2),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Parent = p

    table.insert(activeSnap, {
        Instance = p,
        Trail = trail,
        Position = spawnPos,
        Direction = AXIS[math.random(1, #AXIS)],
        Speed = Config.Snap.Speed,
        Age = 0,
        MaxLife = Config.Snap.LifeTime,
        TurnTimer = math.random(4, 9) / 10,
        Dying = false,
        FadeAge = 0,
        FadeDuration = math.max(Config.Snap.TrailLifetime, 2.0)
    })
end

-- 2.1 จุดละอองหมอกที่ทิ้งไว้ด้านหลัง
local function dropMistDot(position, baseSize)
    local dotSize = baseSize * (math.random(88, 112) / 100)

    local p = Instance.new("Part")
    p.Name = "MistDroplet"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(dotSize, dotSize, dotSize)
    p.CFrame = CFrame.new(position)
    p.Material = Enum.Material.Neon
    p.Color = CurrentState.Color
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Anchored = true
    p.Transparency = 0.3
    p.Parent = ParticleFolder

    table.insert(activeCurveDots, {
        Instance = p,
        InitialSize = dotSize,
        Age = 0,
        MaxLife = Config.CurveDroplet.DotFadeTime
    })
end

-- 2.2 หัวกระสุนเลี้ยวโค้ง - หางละอองหมอก (ไม่เกิดใกล้ตัวละคร)
local function spawnCurveDroplet()
    local charPos = getCharacterPosition()
    local spawnPos = getSafeSpawnPos(Config.CurveDroplet.MinCharDist or 18, 42, 10)
    local headSize = Config.CurveDroplet.HeadSize

    local p = Instance.new("Part")
    p.Name = "CurveDropletHead"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(headSize, headSize, headSize)
    p.CFrame = CFrame.new(spawnPos)
    p.Material = Enum.Material.Neon
    p.Color = CurrentState.Color
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Anchored = true
    p.Transparency = 0.15
    p.Parent = ParticleFolder

    local light = Instance.new("PointLight")
    light.Color = CurrentState.Color
    light.Brightness = 0.9
    light.Range = 4.5
    light.Shadows = false
    light.Parent = p

    local startDir = (Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 0.5, math.random() - 0.5)).Unit
    -- ถ้าทิศทางพุ่งตรงเข้าหาตัวละคร ให้เบี่ยงหลบออกจากตัวละคร
    local toChar = (charPos - spawnPos).Unit
    if startDir:Dot(toChar) > 0.5 then
        startDir = (startDir - (toChar * 1.2)).Unit
    end

    table.insert(activeCurveDroplet, {
        Instance = p,
        Light = light,
        Position = spawnPos,
        LastDropPos = spawnPos,
        Direction = startDir,
        Speed = Config.CurveDroplet.Speed,
        HeadSize = headSize,
        Age = 0,
        MaxLife = Config.CurveDroplet.LifeTime + (math.random(-10, 10) / 10),
        PitchSpeed = math.rad(math.random(30, 60) * (math.random() > 0.5 and 1 or -1)),
        YawSpeed = math.rad(math.random(50, 95) * (math.random() > 0.5 and 1 or -1)),
        Dying = false,
        FadeAge = 0,
        FadeDuration = 0.8
    })
end

-- 3. กระสุนเลี้ยวโค้ง - หางแสงปกติ (Curve Ribbon Trail)
local function spawnCurveRibbon()
    local charPos = getCharacterPosition()
    local spawnPos = getSafeSpawnPos(16, 42, 10)
    local headSize = Config.CurveRibbon.HeadSize

    local p = Instance.new("Part")
    p.Name = "CurveRibbonHead"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(headSize, headSize, headSize)
    p.CFrame = CFrame.new(spawnPos)
    p.Material = Enum.Material.Neon
    p.Color = CurrentState.Color
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Anchored = true
    p.Transparency = 0.15
    p.Parent = ParticleFolder

    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, headSize * 0.45, 0)
    a0.Parent = p

    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -headSize * 0.45, 0)
    a1.Parent = p

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.FaceCamera = true
    trail.LightEmission = 1
    trail.Lifetime = Config.CurveRibbon.TrailLifetime
    trail.Color = ColorSequence.new(CurrentState.Color)
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.0),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1.0, 0.0)
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1.0, 1.0)
    })
    trail.Parent = p

    local light = Instance.new("PointLight")
    light.Color = CurrentState.Color
    light.Brightness = 0.9
    light.Range = 4.5
    light.Shadows = false
    light.Parent = p

    local startDir = (Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 0.5, math.random() - 0.5)).Unit
    local toChar = (charPos - spawnPos).Unit
    if startDir:Dot(toChar) > 0.5 then
        startDir = (startDir - (toChar * 1.2)).Unit
    end

    table.insert(activeCurveRibbon, {
        Instance = p,
        Trail = trail,
        Light = light,
        Position = spawnPos,
        Direction = startDir,
        Speed = Config.CurveRibbon.Speed,
        HeadSize = headSize,
        Age = 0,
        MaxLife = Config.CurveRibbon.LifeTime + (math.random(-10, 10) / 10),
        PitchSpeed = math.rad(math.random(30, 60) * (math.random() > 0.5 and 1 or -1)),
        YawSpeed = math.rad(math.random(50, 95) * (math.random() > 0.5 and 1 or -1)),
        Dying = false,
        FadeAge = 0,
        FadeDuration = 0.8
    })
end

-- 4. ละอองลอยปกติ (Classic)
local function spawnClassicParticle()
    local spawnPos = getSafeSpawnPos(14, 52, 8)

    local size = Config.Classic.Size
    local p = Instance.new("Part")
    p.Name = "ClassicOrb"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(size, size, size)
    p.CFrame = CFrame.new(spawnPos)
    p.Material = Enum.Material.Neon
    p.Color = CurrentState.Color
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Anchored = true
    p.Transparency = 1
    p.Parent = ParticleFolder

    local vel = Vector3.new((math.random() - 0.5) * 2, math.random() * 1.5 + 0.3, (math.random() - 0.5) * 2) * Config.Classic.Speed

    table.insert(activeClassic, {
        Instance = p,
        Position = spawnPos,
        Velocity = vel,
        Age = 0,
        MaxLife = Config.Classic.LifeTime,
        Noise = math.random(1, 1000)
    })
end

-- ========================================================
-- AUTHENTIC 4D TESSERACT (HYPERCUBE) MATHEMATICS
-- 16 Vertices (4D), 32 Edges (1D), 24 Faces (2D), 8 Cubes (3D)
-- ========================================================
local VERTICES_4D = {}
for i = 0, 15 do
    local x = (bit32.band(i, 1) > 0) and 1 or -1
    local y = (bit32.band(i, 2) > 0) and 1 or -1
    local z = (bit32.band(i, 4) > 0) and 1 or -1
    local w = (bit32.band(i, 8) > 0) and 1 or -1
    table.insert(VERTICES_4D, {x = x, y = y, z = z, w = w})
end

-- 32 เส้นขอบ (เชื่อมคู่จุดที่ห่างกัน 1 บิตในมิติที่ 4)
local EDGES_4D = {}
for i = 0, 15 do
    for _, bit in ipairs({1, 2, 4, 8}) do
        local j = bit32.bxor(i, bit)
        if j > i then
            table.insert(EDGES_4D, {i + 1, j + 1})
        end
    end
end

-- 24 หน้าสี่เหลี่ยมระนาบในมิติที่ 4 (6 คู่มิติที่แปรผัน x 4 สถานะคงที่)
local FACES_4D = {}
local bitPairs = {
    {1, 2}, {1, 4}, {1, 8},
    {2, 4}, {2, 8}, {4, 8}
}
local allBits = {1, 2, 4, 8}

for _, pair in ipairs(bitPairs) do
    local b1, b2 = pair[1], pair[2]
    local otherBits = {}
    for _, b in ipairs(allBits) do
        if b ~= b1 and b ~= b2 then
            table.insert(otherBits, b)
        end
    end
    local ob1, ob2 = otherBits[1], otherBits[2]

    for _, v1 in ipairs({0, ob1}) do
        for _, v2 in ipairs({0, ob2}) do
            local base = v1 + v2
            -- วนตามลำดับ 4 มุมรอบสี่เหลี่ยม: (0,0) -> (b1,0) -> (b1,b2) -> (0,b2)
            table.insert(FACES_4D, {
                base + 1,
                base + b1 + 1,
                base + b1 + b2 + 1,
                base + b2 + 1
            })
        end
    end
end

-- ระบบสุ่มเวลาแบบกระจายตัวความละเอียดสูงสำหรับ Tesseract
local tesseractRng = Random.new()
local function getRandomPause()
    return tesseractRng:NextNumber(0.3, 0.7)
end

-- 5. เทสเซอแรคต์ มิติที่ 4 แท้ (True 4D Hypercube Spawn)
local function spawnTesseract()
    local charPos = getCharacterPosition()
    local camCFrame = Camera and Camera.CFrame or CFrame.new(charPos + Vector3.new(0, 5, 12))
    local camLook = camCFrame.LookVector
    -- ตัวคูณระยะการเกิดของทุกระบบ (เริ่มต้น 1.0x และเป็นระยะต่ำสุด)
    local distMult = math.max(1.0, Config.GlobalSpawnDistance or 1.0)
    local minSeparation = (Config.Tesseract.MinSeparation or 13) * math.min(distMult, 1.4)

    -- ค้นหาตำแหน่งเกิดที่กระจายตัวสวยงาม ไม่ซ้อนทับ และไม่อยู่ไกลเกินไป (Best-Candidate Rejection Sampling)
    local bestPos = nil
    local maxDistToOthers = -1

    for attempt = 1, 35 do
        local dist = sampleSpawnDistance(14, 38)
        local distRatio = dist / 38
        local heightAbove = math.random(15, 26) + math.max(0, (distRatio - 1.0) * 8)
        local spawnY = charPos.Y + heightAbove
        local angle = math.random() * math.pi * 2
        local forwardPush = camLook * (math.random(4, 12) * math.min(distRatio, 1.5))

        local candidatePos = Vector3.new(
            charPos.X + forwardPush.X + (math.cos(angle) * dist),
            spawnY,
            charPos.Z + forwardPush.Z + (math.sin(angle) * dist)
        )

        -- ตรวจสอบระยะห่างไปยัง Tesseract ชิ้นอื่นๆ ทั้งหมดในฉาก
        local minDist = 99999
        for _, other in ipairs(activeTesseract) do
            if other.Position then
                local d = (candidatePos - other.Position).Magnitude
                if d < minDist then
                    minDist = d
                end
            end
        end

        -- ถ้าไม่มีตัวอื่น หรือระยะห่างเกินระยะปลอดภัยขั้นต่ำ ให้เลือกตำแหน่งนี้ทันที
        if #activeTesseract == 0 or minDist >= minSeparation then
            bestPos = candidatePos
            break
        elseif minDist > maxDistToOthers then
            maxDistToOthers = minDist
            bestPos = candidatePos
        end
    end

    local spawnPos = bestPos or Vector3.new(charPos.X + 16, charPos.Y + 18, charPos.Z + 16)
    local spawnY = spawnPos.Y

    local size = Config.Tesseract.Size or 2.2
    local thickness = Config.Tesseract.EdgeThickness or 0.055
    local faceTransparency = Config.Tesseract.FaceTransparency or 0.82

    local model = Instance.new("Model")
    model.Name = "TrueTesseract4D"
    model.Parent = ParticleFolder

    local root = Instance.new("Part")
    root.Name = "TesseractRoot"
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.Anchored = true
    root.Position = spawnPos
    root.Parent = model
    model.PrimaryPart = root

    -- สร้าง 32 เส้นขอบทึบ (Solid Neon Edges: 32 เส้นเชื่อม 16 จุดยอด 4D)
    local edgesList = {}
    for i = 1, 32 do
        local e = Instance.new("Part")
        e.Name = "TesseractEdge"
        e.Size = Vector3.new(thickness, thickness, 1)
        e.CFrame = CFrame.new(spawnPos)
        e.Material = Enum.Material.Neon
        e.Color = CurrentState.Color
        e.Transparency = 0 -- เส้นสีทึบปกติ
        e.CanCollide = false
        e.CanTouch = false
        e.CanQuery = false
        e.CastShadow = false
        e.Anchored = true
        e.Parent = model
        table.insert(edgesList, e)
    end

    -- สร้าง 24 หน้าสี่เหลี่ยมโปร่งใส (Translucent Faces: 24 หน้าของ 8 ลูกบาศก์ 4D)
    local facesList = {}
    for i = 1, 24 do
        local f = Instance.new("Part")
        f.Name = "TesseractFace"
        f.Size = Vector3.new(1, 1, 0.02)
        f.CFrame = CFrame.new(spawnPos)
        f.Material = Enum.Material.SmoothPlastic
        f.Color = CurrentState.Color
        f.Transparency = faceTransparency -- หน้าใสเห็นจางๆ
        f.CanCollide = false
        f.CanTouch = false
        f.CanQuery = false
        f.CastShadow = false
        f.Anchored = true
        f.Parent = model
        table.insert(facesList, f)
    end

    -- แสงเรืองตรงแกนกลาง
    local light = Instance.new("PointLight")
    light.Color = CurrentState.Color
    light.Brightness = 0.85
    light.Range = size * 2.5
    light.Shadows = false
    light.Parent = root

    local initStep = math.random(0, 3)
    local initAngle = initStep * (math.pi * 0.5)

    table.insert(activeTesseract, {
        Model = model,
        RootPart = root,
        Edges = edgesList,
        Faces = facesList,
        Light = light,
        BaseY = spawnY,
        Position = spawnPos,
        BobTime = math.random() * math.pi * 2,
        BobSpeed = (Config.Tesseract.BobSpeed or 1.3) * (0.85 + math.random() * 0.3),
        BobAmplitude = (Config.Tesseract.BobAmplitude or 1.4) * (0.85 + math.random() * 0.3),
        -- ควบคุมจังหวะการหมุน 4 มิติ และสุ่มเวลาหยุดพัก 0.3 - 0.7 วิ ทุกครั้งทุกชิ้นก่อนพลิก
        Angle4D = initAngle,
        StartAngle4D = initAngle,
        TargetAngle4D = initAngle + (math.pi * 0.5),
        StepPhase = "pausing",
        StepTimer = 0,
        RotateDuration = 2.0 + tesseractRng:NextNumber(-0.25, 0.35),
        PauseDuration = getRandomPause(), -- สุ่มเวลาก่อนพลิก 0.3 ถึง 0.7 วินาทีสำหรับชิ้นนี้
        Speed4D = (Config.Tesseract.Speed4D or 0.65) * (0.9 + math.random() * 0.2),
        -- มุมการเอียงและหมุน 3 มิติในอวกาศ (3D Ambient Tumble)
        Rot3D = Vector3.new(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi),
        Rot3DSpeed = Vector3.new(
            math.rad(math.random(6, 14) * (math.random() > 0.5 and 1 or -1)),
            math.rad(math.random(8, 16) * (math.random() > 0.5 and 1 or -1)),
            math.rad(math.random(4, 12) * (math.random() > 0.5 and 1 or -1))
        ),
        Age = 0,
        MaxLife = (Config.Tesseract.LifeTime or 45) + math.random(-8, 10),
        Dying = false,
        FadeAge = 0,
        FadeDuration = 0.6 -- เฟดหายไปอย่างรวดเร็ว (0.6 วินาที) เร็วกว่าเอฟเฟกต์อื่น
    })
end

-- ========================================================
-- UPDATE LOOP
-- ========================================================
local mainFXConnection = RunService.Heartbeat:Connect(function(dt)
    local camPos = Camera and Camera.CFrame.Position or Vector3.new(0, 0, 0)
    local distMult = math.max(1.0, Config.GlobalSpawnDistance or 1.0)

    -- 1. อัปเดต เส้นหักมุม (Snap)
    if Config.Snap.Enabled then
        local aliveSnapCount = 0
        local maxDistSnap = Config.Snap.MaxDistance * distMult
        for i = #activeSnap, 1, -1 do
            local item = activeSnap[i]
            local dist = (item.Position - camPos).Magnitude

            if not item.Dying then
                item.Age = item.Age + dt
                if item.Age >= item.MaxLife or dist > maxDistSnap then
                    item.Dying = true
                    if item.Trail then item.Trail.Enabled = false end
                else
                    aliveSnapCount = aliveSnapCount + 1
                    item.TurnTimer = item.TurnTimer - dt
                    if item.TurnTimer <= 0 then
                        item.Direction = getPerpendicular(item.Direction)
                        item.TurnTimer = math.random(4, 9) / 10
                    end
                    item.Position = item.Position + (item.Direction * item.Speed * dt)
                    item.Instance.CFrame = CFrame.new(item.Position, item.Position + item.Direction)
                    if item.Trail then item.Trail.Color = ColorSequence.new(CurrentState.Color) end
                end
            else
                item.FadeAge = item.FadeAge + dt
                local fadeRatio = math.clamp(item.FadeAge / item.FadeDuration, 0, 1)

                if item.Trail then
                    item.Trail.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, math.clamp(fadeRatio, 0, 1)),
                        NumberSequenceKeypoint.new(0.85, math.clamp(0.2 + (fadeRatio * 0.8), 0, 1)),
                        NumberSequenceKeypoint.new(1, 1)
                    })
                end

                if item.FadeAge >= item.FadeDuration then
                    if item.Instance and item.Instance.Parent then item.Instance:Destroy() end
                    table.remove(activeSnap, i)
                end
            end
        end

        local needSnap = getEffectiveMaxCount(Config.Snap.MaxCount) - aliveSnapCount
        if needSnap > 0 then
            for _ = 1, math.min(needSnap, 4) do spawnSnapLine() end
        end
    else
        cleanList(activeSnap)
    end

    -- 2. อัปเดต หางละอองหมอก (Curve Droplet: คำนวณระยะทางแบบ Remainder Accumulator ไม่ขาดช่วง 100%)
    if Config.CurveDroplet.Enabled then
        local aliveDropletCount = 0
        local maxDistDroplet = Config.CurveDroplet.MaxDistance * distMult
        for i = #activeCurveDroplet, 1, -1 do
            local item = activeCurveDroplet[i]
            local dist = (item.Position - camPos).Magnitude

            if not item.Dying then
                item.Age = item.Age + dt
                if item.Age >= item.MaxLife or dist > maxDistDroplet then
                    item.Dying = true
                else
                    aliveDropletCount = aliveDropletCount + 1

                    local oldPos = item.Position
                    local rot = CFrame.Angles(item.PitchSpeed * dt, item.YawSpeed * dt, 0)
                    item.Direction = (rot * item.Direction).Unit
                    item.Position = oldPos + (item.Direction * item.Speed * dt)

                    item.Instance.CFrame = CFrame.new(item.Position)
                    item.Instance.Color = CurrentState.Color
                    if item.Light then item.Light.Color = CurrentState.Color end

                    -- ========================================================
                    -- CONTINUOUS SUB-STEPPING WITH REMAINDER ACCUMULATION
                    -- คำนวณระยะก้าว (stepDist) ให้สัมพันธ์กับขนาดหัวเสมอ (ซ้อนทับกันอย่างลงตัว)
                    -- ========================================================
                    local lastPos = item.LastDropPos or oldPos
                    local distMoved = (item.Position - lastPos).Magnitude
                    -- กำหนดระยะห่างระหว่างจุด = 58% ของขนาดหัว (ปรับลดความรัวลงอีกนิดตามที่ขอ ซ้อนทับ 42% ไร้รอยต่อ)
                    local stepRatio = Config.CurveDroplet.StepRatio or 0.58
                    local stepDist = math.clamp(item.HeadSize * stepRatio, 0.14, 0.28)

                    if distMoved >= stepDist then
                        local numDots = math.min(math.floor(distMoved / stepDist), 10)
                        for s = 1, numDots do
                            local alpha = s / numDots
                            local dropPos = lastPos:Lerp(item.Position, alpha)
                            dropMistDot(dropPos, item.HeadSize)
                        end
                        -- เคลื่อน LastDropPos ไปข้างหน้าตามระยะที่หยดจริง เพื่อเก็บเศษระยะทางที่เหลือ ไม่ให้สะดุด
                        item.LastDropPos = lastPos:Lerp(item.Position, (numDots * stepDist) / distMoved)
                    end

                    -- Fade In
                    local prog = item.Age / item.MaxLife
                    if prog < 0.1 then
                        item.Instance.Transparency = 0.15 + (0.85 * (1 - (prog / 0.1)))
                    else
                        item.Instance.Transparency = 0.15
                    end
                end
            else
                item.FadeAge = item.FadeAge + dt
                local fadeRatio = math.clamp(item.FadeAge / item.FadeDuration, 0, 1)
                item.Instance.Transparency = 0.15 + (0.85 * fadeRatio)
                if item.Light then
                    item.Light.Brightness = 0.9 * (1 - fadeRatio)
                end

                if item.FadeAge >= item.FadeDuration then
                    if item.Instance and item.Instance.Parent then item.Instance:Destroy() end
                    table.remove(activeCurveDroplet, i)
                end
            end
        end

        local needDroplet = getEffectiveMaxCount(Config.CurveDroplet.MaxCount) - aliveDropletCount
        if needDroplet > 0 then
            for _ = 1, math.min(needDroplet, 4) do spawnCurveDroplet() end
        end
    else
        cleanList(activeCurveDroplet)
    end

    -- 2.1 อัปเดตจุดละอองหมอกที่ทิ้งไว้
    for i = #activeCurveDots, 1, -1 do
        local dot = activeCurveDots[i]
        dot.Age = dot.Age + dt
        local prog = dot.Age / dot.MaxLife

        if prog >= 1.0 or not Config.CurveDroplet.Enabled then
            if dot.Instance and dot.Instance.Parent then dot.Instance:Destroy() end
            table.remove(activeCurveDots, i)
        else
            local currentScale = math.max(0.02, (1 - prog))
            local currentSize = dot.InitialSize * currentScale
            dot.Instance.Size = Vector3.new(currentSize, currentSize, currentSize)
            dot.Instance.Transparency = 0.3 + (0.7 * prog)
            dot.Instance.Color = CurrentState.Color
        end
    end

    -- 3. อัปเดต หางแสงปกติ (Curve Ribbon Trail)
    if Config.CurveRibbon.Enabled then
        local aliveRibbonCount = 0
        local maxDistRibbon = Config.CurveRibbon.MaxDistance * distMult
        for i = #activeCurveRibbon, 1, -1 do
            local item = activeCurveRibbon[i]
            local dist = (item.Position - camPos).Magnitude

            if not item.Dying then
                item.Age = item.Age + dt
                if item.Age >= item.MaxLife or dist > maxDistRibbon then
                    item.Dying = true
                    if item.Trail then item.Trail.Enabled = false end
                else
                    aliveRibbonCount = aliveRibbonCount + 1

                    local rot = CFrame.Angles(item.PitchSpeed * dt, item.YawSpeed * dt, 0)
                    item.Direction = (rot * item.Direction).Unit
                    item.Position = item.Position + (item.Direction * item.Speed * dt)

                    item.Instance.CFrame = CFrame.new(item.Position, item.Position + item.Direction)
                    item.Instance.Color = CurrentState.Color
                    if item.Light then item.Light.Color = CurrentState.Color end
                    if item.Trail then item.Trail.Color = ColorSequence.new(CurrentState.Color) end

                    local prog = item.Age / item.MaxLife
                    if prog < 0.1 then
                        item.Instance.Transparency = 0.15 + (0.85 * (1 - (prog / 0.1)))
                    else
                        item.Instance.Transparency = 0.15
                    end
                end
            else
                item.FadeAge = item.FadeAge + dt
                local fadeRatio = math.clamp(item.FadeAge / item.FadeDuration, 0, 1)
                item.Instance.Transparency = 0.15 + (0.85 * fadeRatio)
                if item.Light then
                    item.Light.Brightness = 0.9 * (1 - fadeRatio)
                end

                if item.Trail then
                    item.Trail.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, math.clamp(0.05 + (fadeRatio * 0.95), 0, 1)),
                        NumberSequenceKeypoint.new(0.7, math.clamp(0.3 + (fadeRatio * 0.7), 0, 1)),
                        NumberSequenceKeypoint.new(1.0, 1.0)
                    })
                end

                if item.FadeAge >= item.FadeDuration then
                    if item.Instance and item.Instance.Parent then item.Instance:Destroy() end
                    table.remove(activeCurveRibbon, i)
                end
            end
        end

        local needRibbon = getEffectiveMaxCount(Config.CurveRibbon.MaxCount) - aliveRibbonCount
        if needRibbon > 0 then
            for _ = 1, math.min(needRibbon, 4) do spawnCurveRibbon() end
        end
    else
        cleanList(activeCurveRibbon)
    end

    -- 4. อัปเดต ละอองปกติ (Classic)
    if Config.Classic.Enabled then
        local maxDistClassic = Config.Classic.MaxDistance * distMult
        for i = #activeClassic, 1, -1 do
            local item = activeClassic[i]
            item.Age = item.Age + dt
            local dist = (item.Position - camPos).Magnitude

            if item.Age >= item.MaxLife or dist > maxDistClassic then
                if item.Instance and item.Instance.Parent then item.Instance:Destroy() end
                table.remove(activeClassic, i)
            else
                local t = tick() + item.Noise
                local wobble = Vector3.new(math.sin(t * 1.5) * 0.4, math.cos(t * 1.2) * 0.3, math.sin(t * 1.8) * 0.4)
                item.Position = item.Position + (item.Velocity + wobble) * dt
                item.Instance.Position = item.Position
                item.Instance.Color = CurrentState.Color

                local prog = item.Age / item.MaxLife
                if prog < 0.2 then item.Instance.Transparency = 1 - (prog / 0.2)
                elseif prog > 0.8 then item.Instance.Transparency = (prog - 0.8) / 0.2
                else item.Instance.Transparency = 0 end
            end
        end
        local needClassic = getEffectiveMaxCount(Config.Classic.MaxCount) - #activeClassic
        if needClassic > 0 then
            for _ = 1, math.min(needClassic, 4) do spawnClassicParticle() end
        end
    else
        cleanList(activeClassic)
    end

    -- 5. อัปเดต Tesseract มิติที่ 4 แท้ (True 4D Hypercube: 16 จุดยอด, 32 ขอบ, 24 หน้า, หมุนแบบ Isoclinic พลิกในออกนอกสมมาตร 100%)
    if Config.Tesseract.Enabled then
        local aliveTesseractCount = 0
        local charPos = getCharacterPosition()
        local minAllowedY = charPos.Y + (Config.Tesseract.MinHeightAbove or 16)
        local maxDistTesseract = (Config.Tesseract.MaxDistance or 95) * distMult

        for i = #activeTesseract, 1, -1 do
            local item = activeTesseract[i]
            local dist = (item.Position - camPos).Magnitude

            -- ตรวจสอบอายุขัยหรือระยะห่าง
            if not item.Dying then
                item.Age = item.Age + dt
                if item.Age >= item.MaxLife or dist > maxDistTesseract then
                    item.Dying = true
                else
                    aliveTesseractCount = aliveTesseractCount + 1
                end
            end

            -- ========================================================
            -- การเคลื่อนไหวและหมุน 4D ทำงานต่อเนื่องตลอดเวลา แม้กำลังจะหายไป (Dying)
            -- ========================================================
            -- 1. บังคับให้อยู่สูงกว่าตัวละครเสมอ
            if item.BaseY < minAllowedY then
                item.BaseY = item.BaseY + (minAllowedY - item.BaseY) * math.min(dt * 3.0, 1.0)
            end

            -- 2. ลอยขึ้นลงแบบคงที่ ไม่ห่างจากความสูงที่เกิดมากนัก
            item.BobTime = item.BobTime + (dt * item.BobSpeed)
            local bobOffset = math.sin(item.BobTime) * item.BobAmplitude
            local currentPos = Vector3.new(item.Position.X, item.BaseY + bobOffset, item.Position.Z)
            if item.RootPart then
                item.RootPart.Position = currentPos
            end

            -- 3. อัปเดตจังหวะการหมุน 4D และสุ่มเวลาหยุดพัก 0.3 - 0.7 วิ ทุกครั้งทุกชิ้นก่อนพลิก
            item.StepTimer = item.StepTimer + dt

            if item.StepPhase == "pausing" then
                -- อยู่ในช่วงหยุดพักก่อนพลิก: ล็อคมุม 4D ไว้ที่ตำแหน่งเดิม เพื่อโชว์โครงสร้าง 4D นิ่งสวยงาม
                item.Angle4D = item.StartAngle4D

                if item.StepTimer >= item.PauseDuration then
                    -- หมดเวลาหยุดพักที่สุ่มไว้สำหรับก้อนนี้ -> เริ่มพลิกมิติรอบถัดไป
                    item.StepPhase = "rotating"
                    item.StepTimer = 0
                end
            else
                -- อยู่ในช่วงกำลังพลิกมิติ: ใช้ Smooth Sine Easing ให้การพลิกนุ่มนวล
                local progress = math.clamp(item.StepTimer / item.RotateDuration, 0, 1)
                local ease = (1 - math.cos(progress * math.pi)) * 0.5
                item.Angle4D = item.StartAngle4D + ((item.TargetAngle4D - item.StartAngle4D) * ease)

                if progress >= 1 then
                    -- พลิกมิติครบ 1 สเต็ป (90 องศา) -> สลับไปหยุดพัก
                    item.Angle4D = item.TargetAngle4D
                    item.StartAngle4D = item.TargetAngle4D
                    item.TargetAngle4D = item.StartAngle4D + (math.pi * 0.5)
                    item.StepPhase = "pausing"
                    item.StepTimer = 0
                    -- *** สุ่มเวลาก่อนพลิกครั้งถัดไปใหม่ทันที (0.3 ถึง 0.7 วินาที) สุ่มทุกครั้งทุกชิ้น ***
                    item.PauseDuration = getRandomPause()
                    item.RotateDuration = 2.0 + tesseractRng:NextNumber(-0.25, 0.35)
                end
            end

            local cos4D = math.cos(item.Angle4D)
            local sin4D = math.sin(item.Angle4D)
            local cosYaw = math.cos(item.Angle4D * 0.75)
            local sinYaw = math.sin(item.Angle4D * 0.75)

            -- 4. อัปเดตมุมเอียง 3 มิติภายนอกในอวกาศ
            item.Rot3D = item.Rot3D + (item.Rot3DSpeed * dt)
            local rot3DCFrame = CFrame.Angles(item.Rot3D.X, item.Rot3D.Y, item.Rot3D.Z)

            local scale = (Config.Tesseract.Size or 2.2) * 1.15
            local thickness = Config.Tesseract.EdgeThickness or 0.055
            local D = 2.8 -- 4D Camera Projection Distance (ปลอดภัย ไม่เกิด 0/0)

            -- 5. ฉายภาพ 16 จุดยอดจาก 4 มิติลงสู่ 3 มิติ (4D -> 3D Perspective Projection)
            local worldPoints = {}
            for vIdx = 1, 16 do
                local v = VERTICES_4D[vIdx]
                -- หมุนใน 4 มิติแบบ Isoclinic (ระนาบ ZW พลิกในออกนอก + ระนาบ XY หมุนวน)
                local z1 = v.z * cos4D - v.w * sin4D
                local w1 = v.z * sin4D + v.w * cos4D

                local x1 = v.x * cosYaw - v.y * sinYaw
                local y1 = v.x * sinYaw + v.y * cosYaw

                -- Perspective Projection ตามระยะห่างในแกน w
                local factor = 1 / (D - w1)
                local p3D = Vector3.new(x1 * factor, y1 * factor, z1 * factor) * scale

                -- วางลงในพิกัด 3D ของโลกโดยหมุนตาม rot3DCFrame
                worldPoints[vIdx] = currentPos + (rot3DCFrame * p3D)
            end

            -- 6. อัปเดต 32 เส้นขอบ (Solid Neon Edges: สีทึบปกติ)
            for e = 1, 32 do
                local edgePart = item.Edges[e]
                if edgePart and edgePart.Parent then
                    local pair = EDGES_4D[e]
                    local pA = worldPoints[pair[1]]
                    local pB = worldPoints[pair[2]]
                    local diff = pB - pA
                    local len = diff.Magnitude
                    if len > 0.02 then
                        edgePart.Size = Vector3.new(thickness, thickness, len)
                        local mid = (pA + pB) * 0.5
                        if CFrame.lookAt then
                            edgePart.CFrame = CFrame.lookAt(mid, pB)
                        else
                            edgePart.CFrame = CFrame.new(mid, pB)
                        end
                        edgePart.Color = CurrentState.Color
                    end
                end
            end

            -- 7. อัปเดต 24 หน้าสี่เหลี่ยม (Translucent Planar Faces: หน้าใสเห็นจางๆ ครบทั้ง 8 ลูกบาศก์ใน 4 มิติ)
            for f = 1, 24 do
                local facePart = item.Faces[f]
                if facePart and facePart.Parent then
                    local idxs = FACES_4D[f]
                    local p1 = worldPoints[idxs[1]]
                    local p2 = worldPoints[idxs[2]]
                    local p3 = worldPoints[idxs[3]]
                    local p4 = worldPoints[idxs[4]]

                    local center = (p1 + p2 + p3 + p4) * 0.25
                    local u = (p2 - p1 + p3 - p4) * 0.5
                    local v = (p4 - p1 + p3 - p2) * 0.5
                    local uLen = u.Magnitude
                    local vLen = v.Magnitude

                    if uLen > 0.02 and vLen > 0.02 then
                        local uUnit = u / uLen
                        local vUnit = v / vLen
                        local norm = uUnit:Cross(vUnit)
                        local nLen = norm.Magnitude
                        if nLen > 0.001 then
                            local nUnit = norm / nLen
                            local orthoV = nUnit:Cross(uUnit).Unit
                            facePart.Size = Vector3.new(uLen, vLen, 0.02)
                            facePart.CFrame = CFrame.fromMatrix(center, uUnit, orthoV, nUnit)
                            facePart.Color = CurrentState.Color
                        end
                    end
                end
            end

            if item.Light then
                item.Light.Color = CurrentState.Color
            end

            -- 8. อัปเดตความโปร่งใส (Fade In / Fade Out)
            local baseFaceTrans = Config.Tesseract.FaceTransparency or 0.82
            if not item.Dying then
                -- ตอนเกิดใหม่ (Fade In 1.2 วินาที)
                if item.Age < 1.2 then
                    local inAlpha = item.Age / 1.2
                    local edgeTrans = 1 - inAlpha
                    local faceTrans = 1 - (inAlpha * (1 - baseFaceTrans))
                    for _, e in ipairs(item.Edges) do e.Transparency = edgeTrans end
                    for _, f in ipairs(item.Faces) do f.Transparency = faceTrans end
                    if item.Light then item.Light.Brightness = 0.85 * inAlpha end
                else
                    for _, e in ipairs(item.Edges) do e.Transparency = 0 end
                    for _, f in ipairs(item.Faces) do f.Transparency = baseFaceTrans end
                    if item.Light then item.Light.Brightness = 0.85 end
                end
            else
                -- ตอนใกล้หมดอายุ (Dying): ขยับและหมุนอย่างต่อเนื่องจนหายไป ไม่หยุดนิ่ง
                -- และเฟดหายไปอย่างรวดเร็ว (0.6 วินาที เร็วกว่าเอฟเฟกต์อื่นๆ)
                item.FadeAge = item.FadeAge + dt
                local fadeRatio = math.clamp(item.FadeAge / item.FadeDuration, 0, 1)

                local edgeTrans = fadeRatio
                local faceTrans = baseFaceTrans + (fadeRatio * (1 - baseFaceTrans))

                for _, e in ipairs(item.Edges) do e.Transparency = edgeTrans end
                for _, f in ipairs(item.Faces) do f.Transparency = faceTrans end
                if item.Light then item.Light.Brightness = 0.85 * (1 - fadeRatio) end

                -- เมื่อเฟดจางหายไปจนมองไม่เห็นสนิท ค่อยทำลาย Model ออกจากฉาก
                if item.FadeAge >= item.FadeDuration then
                    if item.Model and item.Model.Parent then item.Model:Destroy() end
                    table.remove(activeTesseract, i)
                end
            end
        end

        local needTesseract = getEffectiveMaxCount(Config.Tesseract.MaxCount or 6) - aliveTesseractCount
        if needTesseract > 0 then
            for _ = 1, math.min(needTesseract, 3) do spawnTesseract() end
        end
    else
        for i = #activeTesseract, 1, -1 do
            if activeTesseract[i].Model and activeTesseract[i].Model.Parent then
                activeTesseract[i].Model:Destroy()
            end
            table.remove(activeTesseract, i)
        end
    end
end)

-- ========================================================
-- CHARACTER MOD ENGINE (RGB / GHOST MODE / AURA PARTICLES)
-- ========================================================
local CharacterMod = {
    RGB = {
        Enabled = false,
        Speed = 0.35, -- Slower initial color transition as requested
        Style = "Neon", -- "Neon", "SmoothPlastic"
        Saturation = 1.0,
        Value = 1.0,
        WaveSpread = true,
    },
    Ghost = {
        Enabled = false,
        Theme = "Cyan", -- Cyan, Violet, White, Gold, Crimson, Rainbow
        BodyTransparency = 0.68,
        Material = "ForceField", -- ForceField, SmoothPlastic, Glass
        Pulse = true,
        OutlineTransparency = 0.75, -- Soft diffused edge, not harsh or sharp
        Wisps = true,
    },
    Particle = {
        Enabled = false,
        Preset = "SoulWisps",
        ColorMode = "Preset", -- "Preset", "SyncAmbience", "Rainbow"
        SizeScale = 1.0,
        RateScale = 1.0,
        SpeedScale = 1.0,
        PositionPreset = "Center",
        OffsetX = 0,
        OffsetY = -0.5,
        OffsetZ = 0,
    },
    JumpRing = {
        Enabled = true,
        ColorMode = "Auto", -- "Auto", "Rainbow", "SyncAmbience", "Cyan", "Gold", "White", "Crimson"
        Size = 1.5, -- 1.5x preferred by user
    },
    HitFX = {
        Enabled = true,
        ColorMode = "Auto", -- "Auto", "Rainbow", "SyncAmbience", "Crimson", "Gold", "Cyan"
        Shape = "Star", -- "Star", "Hexagram", "Diamond", "Nova"
        Size = 1.5,
    }
}

local GHOST_THEMES = {
    Cyan = {
        Name = "👻 ฟ้าวิญญาณ (Spectral Cyan)",
        Fill = Color3.fromRGB(0, 225, 255),
        Outline = Color3.fromRGB(180, 255, 255),
        WispColor = Color3.fromRGB(80, 240, 255)
    },
    Violet = {
        Name = "🔮 ม่วงภูติ (Phantom Violet)",
        Fill = Color3.fromRGB(170, 70, 255),
        Outline = Color3.fromRGB(225, 170, 255),
        WispColor = Color3.fromRGB(190, 100, 255)
    },
    White = {
        Name = "✨ ขาวบริสุทธิ์ (Ether White)",
        Fill = Color3.fromRGB(230, 240, 255),
        Outline = Color3.fromRGB(255, 255, 255),
        WispColor = Color3.fromRGB(220, 235, 255)
    },
    Gold = {
        Name = "👑 ทองคำศักดิ์สิทธิ์ (Divine Gold)",
        Fill = Color3.fromRGB(255, 200, 50),
        Outline = Color3.fromRGB(255, 245, 180),
        WispColor = Color3.fromRGB(255, 215, 80)
    },
    Crimson = {
        Name = "🩸 โลหิตปีศาจ (Blood Spectre)",
        Fill = Color3.fromRGB(255, 40, 70),
        Outline = Color3.fromRGB(255, 140, 160),
        WispColor = Color3.fromRGB(255, 60, 90)
    },
    Ambience = {
        Name = "🌌 ซิงค์สีบรรยากาศ (Sync Ambience)",
        Fill = Color3.fromRGB(160, 160, 255),
        Outline = Color3.fromRGB(210, 210, 255),
        WispColor = Color3.fromRGB(180, 180, 255)
    },
    Rainbow = {
        Name = "🌈 วิญญาณสีรุ้ง (Chroma Ghost)",
        Fill = Color3.fromRGB(255, 255, 255),
        Outline = Color3.fromRGB(255, 255, 255),
        WispColor = Color3.fromRGB(255, 255, 255)
    }
}

local CHAR_PARTICLE_PRESETS = {
    SoulWisps = {
        Name = "👻 Soul Wisps",
        Texture = "rbxasset://textures/particles/smoke_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(100, 240, 255), Color3.fromRGB(0, 140, 255)),
        LightEmission = 0.85,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.5, 1.2),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.9),
            NumberSequenceKeypoint.new(0.4, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(1.0, 1.8),
        Rate = 35,
        Speed = NumberRange.new(1.5, 3.5),
        SpreadAngle = Vector2.new(45, 45),
        Acceleration = Vector3.new(0, 2.5, 0),
        Drag = 1.0,
        Rotation = NumberRange.new(-180, 180),
        RotSpeed = NumberRange.new(-50, 50)
    },
    Starlight = {
        Name = "✨ Starlight Nova",
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 200), Color3.fromRGB(255, 180, 50)),
        LightEmission = 1.0,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 1.5),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.7, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(0.8, 1.5),
        Rate = 45,
        Speed = NumberRange.new(2, 5),
        SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, 1, 0),
        Drag = 2.0,
        Rotation = NumberRange.new(-180, 180),
        RotSpeed = NumberRange.new(-120, 120)
    },
    Electric = {
        Name = "⚡ Electric Surge",
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 255, 255)),
        LightEmission = 1.0,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.5, 0.9),
            NumberSequenceKeypoint.new(1, 0.1)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.8, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(0.2, 0.45),
        Rate = 60,
        Speed = NumberRange.new(4, 9),
        SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, 0, 0),
        Drag = 4.0,
        Rotation = NumberRange.new(-180, 180),
        RotSpeed = NumberRange.new(-360, 360)
    },
    Sakura = {
        Name = "🌸 Sakura Drift",
        Texture = "rbxasset://textures/particles/smoke_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(255, 175, 205), Color3.fromRGB(255, 130, 175)),
        LightEmission = 0.4,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.5, 0.7),
            NumberSequenceKeypoint.new(1, 0.2)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.4),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(1.8, 3.0),
        Rate = 30,
        Speed = NumberRange.new(1, 2.8),
        SpreadAngle = Vector2.new(70, 70),
        Acceleration = Vector3.new(1.2, -0.8, 0.8),
        Drag = 1.2,
        Rotation = NumberRange.new(-180, 180),
        RotSpeed = NumberRange.new(-70, 70)
    },
    VoidFlame = {
        Name = "🔥 Void Flames",
        Texture = "rbxasset://textures/particles/fire_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(150, 40, 255), Color3.fromRGB(40, 10, 80)),
        LightEmission = 0.9,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8),
            NumberSequenceKeypoint.new(0.6, 1.6),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.7, 0.4),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(0.6, 1.2),
        Rate = 50,
        Speed = NumberRange.new(2, 4.5),
        SpreadAngle = Vector2.new(30, 30),
        Acceleration = Vector3.new(0, 4, 0),
        Drag = 1.5,
        Rotation = NumberRange.new(-40, 40),
        RotSpeed = NumberRange.new(-40, 40)
    },
    Cyber = {
        Name = "🟩 Cyber Matrix",
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(50, 255, 120), Color3.fromRGB(0, 180, 80)),
        LightEmission = 1.0,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1, 0.1)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(0.9, 1.6),
        Rate = 40,
        Speed = NumberRange.new(2, 4),
        SpreadAngle = Vector2.new(60, 60),
        Acceleration = Vector3.new(0, 2, 0),
        Drag = 1.0,
        Rotation = NumberRange.new(0, 0),
        RotSpeed = NumberRange.new(0, 0)
    },
    DivineGold = {
        Name = "👑 Divine Radiance",
        Texture = "rbxasset://textures/particles/sparkles_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 170, 30)),
        LightEmission = 1.0,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.5, 1.3),
            NumberSequenceKeypoint.new(1, 0)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.6, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(1.0, 1.9),
        Rate = 40,
        Speed = NumberRange.new(1.8, 3.8),
        SpreadAngle = Vector2.new(90, 90),
        Acceleration = Vector3.new(0, 2.2, 0),
        Drag = 1.2,
        Rotation = NumberRange.new(-90, 90),
        RotSpeed = NumberRange.new(-60, 60)
    },
    CrimsonMist = {
        Name = "🩸 Crimson Mist",
        Texture = "rbxasset://textures/particles/smoke_main.dds",
        Color = ColorSequence.new(Color3.fromRGB(255, 30, 60), Color3.fromRGB(120, 10, 20)),
        LightEmission = 0.7,
        Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.5, 1.5),
            NumberSequenceKeypoint.new(1, 0.1)
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8),
            NumberSequenceKeypoint.new(0.4, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        }),
        Lifetime = NumberRange.new(1.2, 2.0),
        Rate = 35,
        Speed = NumberRange.new(1.2, 3.0),
        SpreadAngle = Vector2.new(60, 60),
        Acceleration = Vector3.new(0, 1.8, 0),
        Drag = 1.2,
        Rotation = NumberRange.new(-180, 180),
        RotSpeed = NumberRange.new(-45, 45)
    }
}

local SavedCharacterParts = {}
local GhostHighlight = nil
local GhostWispAttachment = nil
local GhostWispEmitter = nil
local CharAuraAttachment = nil
local CharAuraEmitter = nil
local CharGlowLight = nil
local CharFloorAttachment = nil
local CharFloorLight = nil
local charModConnection = nil
local charAddedConnection = nil

local function updateCharacterLights(character, targetColor, brightness, range)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not root then return end

    -- 1. Character Body Glow Light (แสงเรืองรอบตัวละครแบบนุ่มนวล ไม่สว่างจ้าเกินไป)
    if not CharGlowLight or CharGlowLight.Parent ~= root then
        if CharGlowLight then CharGlowLight:Destroy() end
        CharGlowLight = Instance.new("PointLight")
        CharGlowLight.Name = "CharGlowLight"
        CharGlowLight.Shadows = false
        CharGlowLight.Parent = root
    end
    CharGlowLight.Range = range or 14
    CharGlowLight.Brightness = brightness or 1.2
    CharGlowLight.Color = targetColor
    CharGlowLight.Enabled = true

    -- 2. Floor Light (ฉายแสงลงบนพื้นตามสีและโหมดที่เปิด นวลตา)
    if not CharFloorAttachment or CharFloorAttachment.Parent ~= root then
        if CharFloorAttachment then CharFloorAttachment:Destroy() end
        CharFloorAttachment = Instance.new("Attachment")
        CharFloorAttachment.Name = "CharFloorAttachment"
        CharFloorAttachment.Position = Vector3.new(0, -2.8, 0)
        CharFloorAttachment.Parent = root
    end

    if not CharFloorLight or CharFloorLight.Parent ~= CharFloorAttachment then
        if CharFloorLight then CharFloorLight:Destroy() end
        CharFloorLight = Instance.new("PointLight")
        CharFloorLight.Name = "CharFloorLight"
        CharFloorLight.Shadows = false
        CharFloorLight.Parent = CharFloorAttachment
    end
    CharFloorLight.Range = (range and range * 0.75) or 10
    CharFloorLight.Brightness = (brightness and brightness * 1.15) or 1.4
    CharFloorLight.Color = targetColor
    CharFloorLight.Enabled = true
end

local function disableCharacterLights()
    if CharGlowLight then CharGlowLight.Enabled = false end
    if CharFloorLight then CharFloorLight.Enabled = false end
end

local function getCharacterParts(character)
    if not character then return {} end
    local parts = {}
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("BasePart") then
            if desc.Name ~= "HumanoidRootPart" or desc.Transparency < 0.99 then
                table.insert(parts, desc)
            end
        end
    end
    return parts
end

local function savePartOriginalState(part)
    if not SavedCharacterParts[part] then
        local mesh = part:FindFirstChildOfClass("SpecialMesh")
        SavedCharacterParts[part] = {
            Color = part.Color,
            Material = part.Material,
            Transparency = part.Transparency,
            Reflectance = part.Reflectance,
            MeshVertexColor = mesh and mesh.VertexColor or nil
        }
    end
end

local function restoreCharacterOriginalState()
    for part, data in pairs(SavedCharacterParts) do
        if part and part.Parent then
            pcall(function()
                part.Color = data.Color
                part.Material = data.Material
                part.Transparency = data.Transparency
                part.Reflectance = data.Reflectance
                if data.MeshVertexColor then
                    local mesh = part:FindFirstChildOfClass("SpecialMesh")
                    if mesh then
                        mesh.VertexColor = data.MeshVertexColor
                    end
                end
            end)
        end
    end
    SavedCharacterParts = {}
end

local function applyGhostMode(character)
    if not character then return end
    if not CharacterMod.Ghost.Enabled then
        if GhostHighlight then GhostHighlight:Destroy(); GhostHighlight = nil end
        if GhostWispEmitter then GhostWispEmitter.Enabled = false end
        if not CharacterMod.RGB.Enabled then
            restoreCharacterOriginalState()
        else
            for part, data in pairs(SavedCharacterParts) do
                if part and part.Parent then
                    part.Transparency = data.Transparency
                    part.Material = (CharacterMod.RGB.Style == "Neon") and Enum.Material.Neon or Enum.Material.SmoothPlastic
                end
            end
        end
        return
    end

    local parts = getCharacterParts(character)
    local matEnum = Enum.Material.ForceField
    if CharacterMod.Ghost.Material == "SmoothPlastic" then
        matEnum = Enum.Material.SmoothPlastic
    elseif CharacterMod.Ghost.Material == "Glass" then
        matEnum = Enum.Material.Glass
    end

    for _, part in ipairs(parts) do
        savePartOriginalState(part)
        part.Transparency = CharacterMod.Ghost.BodyTransparency
        part.Material = matEnum
    end

    if not GhostHighlight or GhostHighlight.Parent ~= character then
        if GhostHighlight then GhostHighlight:Destroy() end
        GhostHighlight = Instance.new("Highlight")
        GhostHighlight.Name = "GhostModeHighlight"
        GhostHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        GhostHighlight.Parent = character
    end

    local theme = GHOST_THEMES[CharacterMod.Ghost.Theme] or GHOST_THEMES.Cyan
    local fillColor = theme.Fill
    local outlineColor = theme.Outline
    local wispCol = theme.WispColor
    if CharacterMod.Ghost.Theme == "Ambience" then
        local ambCol = CurrentState.Color or Color3.fromRGB(160, 160, 255)
        fillColor = ambCol
        outlineColor = Color3.new(
            math.clamp(ambCol.R * 1.25, 0, 1),
            math.clamp(ambCol.G * 1.25, 0, 1),
            math.clamp(ambCol.B * 1.25, 0, 1)
        )
        wispCol = ambCol
    end
    GhostHighlight.FillColor = fillColor
    GhostHighlight.OutlineColor = outlineColor
    GhostHighlight.FillTransparency = 0.62
    GhostHighlight.OutlineTransparency = CharacterMod.Ghost.OutlineTransparency or 0.78

    if CharacterMod.Ghost.Wisps then
        local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        if root then
            if not GhostWispAttachment or GhostWispAttachment.Parent ~= root then
                if GhostWispAttachment then GhostWispAttachment:Destroy() end
                GhostWispAttachment = Instance.new("Attachment")
                GhostWispAttachment.Name = "GhostWispAttachment"
                GhostWispAttachment.Position = Vector3.new(0, -1, 0)
                GhostWispAttachment.Parent = root
            end
            if not GhostWispEmitter or GhostWispEmitter.Parent ~= GhostWispAttachment then
                if GhostWispEmitter then GhostWispEmitter:Destroy() end
                GhostWispEmitter = Instance.new("ParticleEmitter")
                GhostWispEmitter.Name = "GhostWispEmitter"
                GhostWispEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
                GhostWispEmitter.LightEmission = 0.8
                GhostWispEmitter.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.4),
                    NumberSequenceKeypoint.new(0.6, 1.4),
                    NumberSequenceKeypoint.new(1, 0)
                })
                GhostWispEmitter.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.85),
                    NumberSequenceKeypoint.new(0.4, 0.35),
                    NumberSequenceKeypoint.new(1, 1)
                })
                GhostWispEmitter.Lifetime = NumberRange.new(1.2, 2.0)
                GhostWispEmitter.Rate = 22
                GhostWispEmitter.Speed = NumberRange.new(1.2, 2.6)
                GhostWispEmitter.SpreadAngle = Vector2.new(45, 45)
                GhostWispEmitter.Acceleration = Vector3.new(0, 2.2, 0)
                GhostWispEmitter.Drag = 1.0
                GhostWispEmitter.Parent = GhostWispAttachment
            end
            local wispCol = theme.WispColor
            GhostWispEmitter.Color = ColorSequence.new(wispCol, Color3.fromRGB(255, 255, 255))
            GhostWispEmitter.Enabled = true
        end
    else
        if GhostWispEmitter then GhostWispEmitter.Enabled = false end
    end
end

local function applyCharacterParticle(character)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not root then return end

    if not CharacterMod.Particle.Enabled then
        if CharAuraEmitter then CharAuraEmitter.Enabled = false end
        return
    end

    local presetKey = CharacterMod.Particle.Preset
    local preset = CHAR_PARTICLE_PRESETS[presetKey] or CHAR_PARTICLE_PRESETS.SoulWisps

    if not CharAuraAttachment or CharAuraAttachment.Parent ~= root then
        if CharAuraAttachment then CharAuraAttachment:Destroy() end
        CharAuraAttachment = Instance.new("Attachment")
        CharAuraAttachment.Name = "CharAuraAttachment"
        CharAuraAttachment.Parent = root
    end

    local pOffX = CharacterMod.Particle.OffsetX or 0
    local pOffY = CharacterMod.Particle.OffsetY or -0.5
    local pOffZ = CharacterMod.Particle.OffsetZ or 0
    CharAuraAttachment.Position = Vector3.new(pOffX, pOffY, pOffZ)

    if not CharAuraEmitter or CharAuraEmitter.Parent ~= CharAuraAttachment then
        if CharAuraEmitter then CharAuraEmitter:Destroy() end
        CharAuraEmitter = Instance.new("ParticleEmitter")
        CharAuraEmitter.Name = "CharAuraEmitter"
        CharAuraEmitter.Parent = CharAuraAttachment
    end

    CharAuraEmitter.Texture = preset.Texture
    CharAuraEmitter.LightEmission = preset.LightEmission
    CharAuraEmitter.Transparency = preset.Transparency
    CharAuraEmitter.Lifetime = preset.Lifetime
    CharAuraEmitter.SpreadAngle = preset.SpreadAngle
    CharAuraEmitter.Acceleration = preset.Acceleration
    CharAuraEmitter.Drag = preset.Drag
    CharAuraEmitter.Rotation = preset.Rotation
    CharAuraEmitter.RotSpeed = preset.RotSpeed

    local s = CharacterMod.Particle.SizeScale
    local keypoints = {}
    for _, kp in ipairs(preset.Size.Keypoints) do
        table.insert(keypoints, NumberSequenceKeypoint.new(kp.Time, math.clamp(kp.Value * s, 0.05, 20)))
    end
    CharAuraEmitter.Size = NumberSequence.new(keypoints)

    CharAuraEmitter.Rate = math.clamp(preset.Rate * CharacterMod.Particle.RateScale, 1, 300)
    CharAuraEmitter.Speed = NumberRange.new(
        preset.Speed.Min * CharacterMod.Particle.SpeedScale,
        preset.Speed.Max * CharacterMod.Particle.SpeedScale
    )

    if CharacterMod.Particle.ColorMode == "SyncAmbience" then
        local fogCol = CurrentState.Color or Color3.fromRGB(160, 160, 255)
        CharAuraEmitter.Color = ColorSequence.new(fogCol)
    elseif CharacterMod.Particle.ColorMode == "Rainbow" then
        local h = (tick() * 0.5) % 1
        CharAuraEmitter.Color = ColorSequence.new(Color3.fromHSV(h, 0.9, 1), Color3.fromHSV((h + 0.2) % 1, 0.9, 1))
    else
        CharAuraEmitter.Color = preset.Color
    end

    CharAuraEmitter.Enabled = true
end

local humanoidJumpConn = nil
local humanoidJumpingDirectConn = nil
local lastJumpTick = 0

local function spawnJumpParticleRing(character)
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not root then return end

    local rayOrigin = root.Position
    local rayDir = Vector3.new(0, -6.5, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(rayOrigin, rayDir, rayParams)
    local groundPos = hit and (hit.Position + Vector3.new(0, 0.08, 0)) or (rayOrigin - Vector3.new(0, 2.5, 0))

    local ringCol
    local mode = CharacterMod.JumpRing.ColorMode or "Auto"
    if mode == "Rainbow" or (mode == "Auto" and CharacterMod.RGB.Enabled) then
        local rgbSpeed = CharacterMod.RGB.Speed or 0.35
        local h = (tick() * rgbSpeed * 0.30) % 1
        ringCol = Color3.fromHSV(h, 1, 1)
    elseif mode == "SyncAmbience" or (mode == "Auto" and not CharacterMod.RGB.Enabled and not CharacterMod.Ghost.Enabled) then
        ringCol = CurrentState.Color or Color3.fromRGB(160, 220, 255)
    elseif mode == "Auto" and CharacterMod.Ghost.Enabled then
        local theme = GHOST_THEMES[CharacterMod.Ghost.Theme] or GHOST_THEMES.Cyan
        ringCol = (CharacterMod.Ghost.Theme == "Ambience") and (CurrentState.Color or theme.Fill) or theme.Fill
    elseif mode == "Cyan" then
        ringCol = Color3.fromRGB(0, 230, 255)
    elseif mode == "Gold" then
        ringCol = Color3.fromRGB(255, 205, 50)
    elseif mode == "White" then
        ringCol = Color3.fromRGB(240, 245, 255)
    elseif mode == "Crimson" then
        ringCol = Color3.fromRGB(255, 50, 80)
    else
        ringCol = CurrentState.Color or Color3.fromRGB(140, 210, 255)
    end

    local sizeScale = CharacterMod.JumpRing.Size or 1.0

    local ringHolder = Instance.new("Part")
    ringHolder.Name = "JumpRingFX"
    ringHolder.Size = Vector3.new(0.05, 0.05, 0.05)
    ringHolder.CFrame = CFrame.new(groundPos)
    ringHolder.Anchored = true
    ringHolder.CanCollide = false
    ringHolder.CanTouch = false
    ringHolder.CanQuery = false
    ringHolder.CastShadow = false
    ringHolder.Transparency = 1
    ringHolder.Parent = workspace

    local startRadius = 0
    local targetRadius = 1.95 * sizeScale
    local numArms = 3 -- 3 distinct swirling streams (3 เส้นทางน้ำวนชัดเจน)

    -- ฟังก์ชันคำนวณมุมหมุน รัศมี และความสูง Y ตามเวลาจริง (Analytical 3D Trajectory)
    local function getWhirlpoolAngle(t)
        if t <= 0.90 then
            local u = t / 0.90
            return 5.2 * t + (13.5 - 5.2) * 0.90 * (u - 0.5 * (u * u))
        else
            return 5.2 * t + (13.5 - 5.2) * 0.90 * 0.5
        end
    end

    local function getWhirlpoolRadius(t)
        if t < 0 then
            return 0
        elseif t < 0.75 then
            local p = t / 0.75
            return targetRadius * 1.12 * math.sin(p * math.pi * 0.5)
        elseif t < 0.95 then
            local q = (t - 0.75) / 0.20
            return targetRadius * (1.00 + 0.12 * math.cos(q * math.pi * 0.5))
        elseif t < 3.95 then
            return targetRadius
        else
            -- ขยายตัวเล็กน้อยตามเกลียวคลื่นขณะลอยขึ้นสู่ฟ้า
            local riseRatio = math.clamp((t - 3.95) / 0.90, 0, 1)
            return targetRadius * (1 + riseRatio * 0.22)
        end
    end

    local function getWhirlpoolY(t)
        if t < 3.95 then
            return 0.04
        else
            -- ความสูงคำนวณตามเวลาของแต่ละข้อต่อ ทำให้หัวลอยนำหน้าแล้วหางทอดยาวตามขึ้นไปในอากาศแบบ 3D Helix
            local riseElapsed = t - 3.95
            local riseRatio = math.clamp(riseElapsed / 0.90, 0, 1)
            return 0.04 + (riseRatio * riseRatio) * 4.0 * sizeScale
        end
    end

    local arms = {}
    local numSegments = 34 -- 34 ข้อต่อลูกแก้วนวลเรียงซ้อนทับกันแนบสนิท
    local tailDuration = 0.52 -- หางยาวครอบคลุมมุมโค้งกว่า 150 องศา

    -- สร้าง 3 แขนวังวน โดยแต่ละแขนประกอบด้วยหัวกลม + สายหางลูกแก้วนวล 34 ลูก
    for i = 1, numArms do
        local baseAng = (i / numArms) * math.pi * 2
        local segments = {}

        for s = 0, numSegments do
            local p = Instance.new("Part")
            p.Name = (s == 0) and ("WhirlpoolHead_" .. i) or ("WhirlpoolSeg_" .. i .. "_" .. s)
            p.Shape = Enum.PartType.Ball
            p.Material = Enum.Material.Neon
            p.Color = ringCol
            p.CanCollide = false
            p.CanTouch = false
            p.CanQuery = false
            p.CastShadow = false
            p.Anchored = true
            p.Transparency = 1
            p.CFrame = CFrame.new(groundPos)
            p.Parent = ringHolder

            table.insert(segments, p)
        end

        table.insert(arms, {
            baseAngle = baseAng,
            segments = segments
        })
    end

    -- Animate whirlpool: สายธารลูกแก้วนวล 3 สาย วาดส่วนโค้งวงกลมแท้จริงตามคณิตศาสตร์ 100%
    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ringHolder or not ringHolder.Parent then
            if conn then conn:Disconnect(); conn = nil end
            return
        end

        local elapsed = tick() - startTime
        local isAscending = elapsed >= 3.95
        local globalFade = 0
        if isAscending then
            globalFade = math.clamp((elapsed - 3.95) / 0.90, 0, 1)
        end

        -- Live sync color (รองรับ RGB Mode ให้กระพริบไล่เฉดสีสมูท)
        local liveCol = ringCol
        if mode == "Rainbow" or (mode == "Auto" and CharacterMod.RGB.Enabled) then
            local rgbSpeed = CharacterMod.RGB.Speed or 0.35
            local h = (tick() * rgbSpeed * 0.30) % 1
            liveCol = Color3.fromHSV(h, 1, 1)
        end

        for _, arm in ipairs(arms) do
            for s = 0, numSegments do
                local segPart = arm.segments[s + 1]
                if segPart and segPart.Parent then
                    local tau = (s / numSegments) * tailDuration
                    local tSample = elapsed - tau

                    if tSample < 0 then
                        -- ช่วงเริ่มต้นที่หางยังไม่งอกออกจากจุดศูนย์กลาง
                        segPart.Transparency = 1
                    else
                        local theta = arm.baseAngle + getWhirlpoolAngle(tSample)
                        local r = getWhirlpoolRadius(tSample)
                        -- คำนวณความสูง Y ตาม tSample ของจุดนั้นๆ ทำให้หัวลอยขึ้นก่อน แล้วหางค่อยๆ ลอยตามขึ้นไปในอากาศ
                        local y = getWhirlpoolY(tSample)

                        local pos = groundPos + Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r)
                        segPart.CFrame = CFrame.new(pos)
                        segPart.Color = liveCol

                        -- เรียวแหลมจากหัวสู่ปลายหางอย่างสมบูรณ์แบบ
                        local taper = 1 - (s / (numSegments + 1))
                        local sizeVal = (0.28 * sizeScale) * (taper ^ 0.65)
                        if isAscending then
                            sizeVal = sizeVal * (1 - globalFade * 0.40)
                        end
                        segPart.Size = Vector3.new(sizeVal, sizeVal, sizeVal)

                        -- ความโปร่งแสงค่อยๆ จางไปที่ปลายหาง + จางหายเมื่อลอยขึ้นสูง
                        local baseTrans
                        if s == 0 then
                            baseTrans = 0.05
                        else
                            baseTrans = 0.08 + 0.90 * ((s / numSegments) ^ 1.15)
                        end
                        if isAscending then
                            baseTrans = math.clamp(baseTrans + globalFade * 0.95, 0, 1)
                        end
                        segPart.Transparency = baseTrans
                    end
                end
            end
        end

        -- ล้างทรัพยากรทั้งหมดเมื่อเสร็จสิ้น
        if elapsed >= 4.90 then
            if conn then conn:Disconnect(); conn = nil end
            if ringHolder and ringHolder.Parent then
                ringHolder:Destroy()
            end
        end
    end)
end

local function setupCharacterJumpDetector(char)
    if humanoidJumpConn then humanoidJumpConn:Disconnect(); humanoidJumpConn = nil end
    if humanoidJumpingDirectConn then humanoidJumpingDirectConn:Disconnect(); humanoidJumpingDirectConn = nil end
    if not char then return end
    local humanoid = char:WaitForChild("Humanoid", 3) or char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local function handleJumpTrigger()
        if not CharacterMod.JumpRing or not CharacterMod.JumpRing.Enabled then return end
        local now = tick()
        if (now - lastJumpTick) < 0.28 then return end
        lastJumpTick = now
        spawnJumpParticleRing(char)
    end

    humanoidJumpConn = humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            handleJumpTrigger()
        end
    end)

    humanoidJumpingDirectConn = humanoid.Jumping:Connect(function(isActive)
        if isActive then
            handleJumpTrigger()
        end
    end)
end

local function getCombatHitColor()
    local mode = (CharacterMod.HitFX and CharacterMod.HitFX.ColorMode) or "Auto"
    if mode == "Rainbow" or (mode == "Auto" and CharacterMod.RGB.Enabled) then
        local rgbSpeed = CharacterMod.RGB.Speed or 0.35
        local h = (tick() * rgbSpeed * 0.30) % 1
        return Color3.fromHSV(h, 1, 1)
    elseif mode == "SyncAmbience" or (mode == "Auto" and not CharacterMod.RGB.Enabled and not CharacterMod.Ghost.Enabled) then
        return CurrentState.Color or Color3.fromRGB(255, 120, 80)
    elseif mode == "Auto" and CharacterMod.Ghost.Enabled then
        local theme = GHOST_THEMES[CharacterMod.Ghost.Theme] or GHOST_THEMES.Cyan
        return (CharacterMod.Ghost.Theme == "Ambience") and (CurrentState.Color or theme.Fill) or theme.Fill
    elseif mode == "Crimson" then
        return Color3.fromRGB(255, 45, 75)
    elseif mode == "Gold" then
        return Color3.fromRGB(255, 215, 60)
    elseif mode == "Cyan" then
        return Color3.fromRGB(0, 235, 255)
    elseif mode == "White" then
        return Color3.fromRGB(255, 255, 255)
    else
        return CurrentState.Color or Color3.fromRGB(255, 120, 80)
    end
end

local function spawnHitCombatFX(hitPos, hitNormal)
    if not CharacterMod.HitFX or not CharacterMod.HitFX.Enabled then return end

    local hitCol = getCombatHitColor()
    local sizeScale = CharacterMod.HitFX.Size or 1.5
    local shapeMode = CharacterMod.HitFX.Shape or "Star"

    local hitFolder = Instance.new("Folder")
    hitFolder.Name = "CombatHitFX"
    hitFolder.Parent = workspace

    local norm = hitNormal or Vector3.new(0, 1, 0)
    if norm.Magnitude < 0.1 then norm = Vector3.new(0, 1, 0) end
    local baseCF = CFrame.lookAt(hitPos, hitPos + norm)

    -- 1. แสงแฟลชสว่างกว้าง (PointLight Flash ส่องสว่างรอบตัว 24-40 studs)
    local flashPart = Instance.new("Part")
    flashPart.Size = Vector3.new(0.05, 0.05, 0.05)
    flashPart.CFrame = CFrame.new(hitPos)
    flashPart.Anchored = true; flashPart.CanCollide = false; flashPart.Transparency = 1
    flashPart.Parent = hitFolder

    local pl = Instance.new("PointLight")
    pl.Color = hitCol
    pl.Range = 24 * sizeScale
    pl.Brightness = 4.5
    pl.Shadows = false
    pl.Parent = flashPart

    local elements = {}

    local function addBeam(angleRad, length, thickness)
        local p = Instance.new("Part")
        p.Name = "HitBeam"
        p.Shape = Enum.PartType.Block
        p.Material = Enum.Material.Neon
        p.Color = hitCol
        p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
        p.Transparency = 0.05
        p.Parent = hitFolder
        table.insert(elements, {
            type = "beam",
            part = p,
            angle = angleRad,
            targetLen = length,
            thick = thickness
        })
    end

    local function addRing(diameter, thickness)
        local r = Instance.new("Part")
        r.Name = "HitRing"
        r.Shape = Enum.PartType.Cylinder
        r.Material = Enum.Material.Neon
        r.Color = hitCol
        r.Anchored = true; r.CanCollide = false; r.CanTouch = false; r.CastShadow = false
        r.Transparency = 0.08
        r.Parent = hitFolder
        table.insert(elements, {
            type = "ring",
            part = r,
            targetDiam = diameter,
            thick = thickness
        })
    end

    local function addNode(angleRad, radius, nodeSize)
        local n = Instance.new("Part")
        n.Name = "HitNode"
        n.Shape = Enum.PartType.Ball
        n.Material = Enum.Material.Neon
        n.Color = hitCol
        n.Anchored = true; n.CanCollide = false; n.CanTouch = false; n.CastShadow = false
        n.Transparency = 0.05
        n.Parent = hitFolder
        table.insert(elements, {
            type = "node",
            part = n,
            angle = angleRad,
            targetRadius = radius,
            targetSize = nodeSize
        })
    end

    -- ลูกแก้วศูนย์กลาง (Center Core Orb)
    local corePart = Instance.new("Part")
    corePart.Name = "HitCore"
    corePart.Shape = Enum.PartType.Ball
    corePart.Material = Enum.Material.Neon
    corePart.Color = hitCol
    corePart.Anchored = true; corePart.CanCollide = false; corePart.CanTouch = false; corePart.CastShadow = false
    corePart.Parent = hitFolder
    local coreTargetSize = 1.3 * sizeScale

    -- สร้างองค์ประกอบของรูปทรงเรขาคณิตตาม Shape Mode
    if shapeMode == "Hexagram" then
        -- 🔯 Arcane Hexagram Seal: ตราเวทย์ 6 แฉก พร้อมวงแหวนศักดิ์สิทธิ์
        addRing(8.8 * sizeScale, 0.14 * sizeScale)
        addRing(4.5 * sizeScale, 0.10 * sizeScale)
        local hexAngles = {30, 90, 150}
        for _, deg in ipairs(hexAngles) do
            addBeam(math.rad(deg), 8.2 * sizeScale, 0.22 * sizeScale)
        end
        local hexNodes = {30, 90, 150, 210, 270, 330}
        for _, deg in ipairs(hexNodes) do
            addNode(math.rad(deg), 4.1 * sizeScale, 0.60 * sizeScale)
        end
    elseif shapeMode == "Diamond" then
        -- 💎 Radiant Diamond Crest: ตราเพชรประกายแสง 4 แฉกยาว และวงแหวนเพชร
        addBeam(0, 11.0 * sizeScale, 0.30 * sizeScale)
        addBeam(math.rad(90), 8.0 * sizeScale, 0.24 * sizeScale)
        addBeam(math.rad(45), 5.2 * sizeScale, 0.18 * sizeScale)
        addBeam(math.rad(135), 5.2 * sizeScale, 0.18 * sizeScale)
        addRing(4.6 * sizeScale, 0.15 * sizeScale)

        addNode(0, 5.5 * sizeScale, 0.68 * sizeScale)
        addNode(math.pi, 5.5 * sizeScale, 0.68 * sizeScale)
        addNode(math.rad(90), 4.0 * sizeScale, 0.56 * sizeScale)
        addNode(math.rad(270), 4.0 * sizeScale, 0.56 * sizeScale)
    elseif shapeMode == "Nova" then
        -- 🪐 Cosmic Nova Seal: ตราสุริยันหมุนวน 12 แฉกพร้อมวงแหวนคู่
        addRing(4.2 * sizeScale, 0.14 * sizeScale)
        addRing(9.2 * sizeScale, 0.14 * sizeScale)
        for deg = 0, 330, 30 do
            addBeam(math.rad(deg), 9.2 * sizeScale, 0.18 * sizeScale)
            addNode(math.rad(deg), 4.6 * sizeScale, 0.48 * sizeScale)
        end
    else
        -- ⭐ Astral Star Crest (ค่าเริ่มต้น): ตราดาราศักดิ์สิทธิ์ 8 แฉกพร้อมวงแหวนเวทและดวงดาวโหนด
        addBeam(0, 9.6 * sizeScale, 0.26 * sizeScale)
        addBeam(math.rad(90), 9.6 * sizeScale, 0.26 * sizeScale)
        addBeam(math.rad(45), 6.8 * sizeScale, 0.18 * sizeScale)
        addBeam(math.rad(135), 6.8 * sizeScale, 0.18 * sizeScale)
        addRing(5.4 * sizeScale, 0.14 * sizeScale)

        local starAngles = {0, 45, 90, 135, 180, 225, 270, 315}
        for _, deg in ipairs(starAngles) do
            local isCardinal = (deg % 90 == 0)
            local r = (isCardinal and 4.8 or 3.4) * sizeScale
            local s = (isCardinal and 0.62 or 0.46) * sizeScale
            addNode(math.rad(deg), r, s)
        end
    end

    -- แอนิเมชัน 3 เฟส:
    -- 1. พุ่งรวมตัวเป็นรูปทรง (0.00s -> 0.08s): ลำแสงและดวงดาวพุ่งเข้าหากันจนประกอบเป็นรูปทรงสมบูรณ์
    -- 2. หมุนวนส่องสว่างคงรูป (0.08s -> 0.32s): ตราสัญลักษณ์หมุนวนอย่างสง่างาม
    -- 3. ขยายตัวสลายเป็นประกาย (0.32s -> 0.48s): แสงจางลงอย่างนุ่มนวล
    local startTick = tick()
    local hitConn
    hitConn = RunService.Heartbeat:Connect(function(dt)
        local age = tick() - startTick
        if age >= 0.48 or not hitFolder.Parent then
            if hitConn then hitConn:Disconnect(); hitConn = nil end
            if hitFolder and hitFolder.Parent then hitFolder:Destroy() end
            return
        end

        local convergeProg = math.clamp(age / 0.08, 0, 1)
        local fadeProg = (age > 0.32) and math.clamp((age - 0.32) / 0.16, 0, 1) or 0
        local spinAngle = age * 2.2
        local spinCF = baseCF * CFrame.Angles(0, 0, spinAngle)

        local sizeMult = (fadeProg > 0) and (1.0 + 0.25 * fadeProg) or 1.0
        local trans = (fadeProg > 0) and (0.05 + 0.95 * fadeProg) or 0.05

        -- แสง PointLight ค่อยๆ หรี่ตอนใกล้หมดเวลา
        pl.Brightness = 4.5 * (1 - fadeProg)

        -- ลูกแก้วตรงกลาง
        local curCoreS = coreTargetSize * (convergeProg < 1 and (0.3 + 0.7 * convergeProg) or (1.0 + 0.2 * fadeProg))
        corePart.Size = Vector3.new(curCoreS, curCoreS, curCoreS)
        corePart.CFrame = spinCF
        corePart.Transparency = trans

        -- อัปเดตชิ้นส่วนรูปทรง
        for _, elem in ipairs(elements) do
            if elem.type == "beam" then
                local curLen = elem.targetLen * sizeMult * (convergeProg < 1 and (0.2 + 0.8 * convergeProg) or 1.0)
                local curThick = elem.thick * (1 - fadeProg * 0.5)
                elem.part.Size = Vector3.new(curLen, curThick, curThick)
                elem.part.CFrame = spinCF * CFrame.Angles(0, 0, elem.angle)
                elem.part.Transparency = trans
            elseif elem.type == "ring" then
                local curD = elem.targetDiam * sizeMult * (convergeProg < 1 and (0.3 + 0.7 * convergeProg) or 1.0)
                local curThick = elem.thick * (1 - fadeProg * 0.5)
                elem.part.Size = Vector3.new(curThick, curD, curD)
                elem.part.CFrame = spinCF * CFrame.Angles(0, math.rad(90), 0)
                elem.part.Transparency = trans + 0.03
            elseif elem.type == "node" then
                -- ดาวโหนดพุ่งจากนอกเข้ามาเกาะรูปทรงตอนเริ่มต้น (Converge)
                local rRatio = (convergeProg < 1) and (1.8 - 0.8 * convergeProg) or 1.0
                local curR = elem.targetRadius * rRatio * sizeMult
                local curS = elem.targetSize * sizeMult * (convergeProg < 1 and (0.4 + 0.6 * convergeProg) or (1.0 - fadeProg * 0.4))
                local localX = math.cos(elem.angle) * curR
                local localY = math.sin(elem.angle) * curR
                elem.part.Size = Vector3.new(curS, curS, curS)
                elem.part.CFrame = spinCF * CFrame.new(localX, localY, 0)
                elem.part.Transparency = trans
            end
        end
    end)
end

local hitDetectorConns = {}
local targetHitDebounce = setmetatable({}, {__mode = "k"})
local lastAttackInputTick = 0
local lastAttackMouseTarget = nil
local enemyHealthCache = setmetatable({}, {__mode = "k"})
local lastToolHit = setmetatable({}, {__mode = "k"})
local monitoredChars = setmetatable({}, {__mode = "k"})

local function cleanupCombatHitDetector()
    for _, c in ipairs(hitDetectorConns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(hitDetectorConns)
    table.clear(monitoredChars)
    table.clear(lastToolHit)
end

local function setupCombatHitDetector(char)
    cleanupCombatHitDetector()
    if not char then return end

    local skillKeyCodes = {
        -- ปุ่มตัวเลขสกิล 1 2 3 4 5 6 7 8 9 0 (ทั้งแถวบนและ Numpad)
        [Enum.KeyCode.One] = true,
        [Enum.KeyCode.Two] = true,
        [Enum.KeyCode.Three] = true,
        [Enum.KeyCode.Four] = true,
        [Enum.KeyCode.Five] = true,
        [Enum.KeyCode.Six] = true,
        [Enum.KeyCode.Seven] = true,
        [Enum.KeyCode.Eight] = true,
        [Enum.KeyCode.Nine] = true,
        [Enum.KeyCode.Zero] = true,
        [Enum.KeyCode.KeypadOne] = true,
        [Enum.KeyCode.KeypadTwo] = true,
        [Enum.KeyCode.KeypadThree] = true,
        [Enum.KeyCode.KeypadFour] = true,
        [Enum.KeyCode.KeypadFive] = true,
        [Enum.KeyCode.KeypadSix] = true,
        [Enum.KeyCode.KeypadSeven] = true,
        [Enum.KeyCode.KeypadEight] = true,
        [Enum.KeyCode.KeypadNine] = true,
        [Enum.KeyCode.KeypadZero] = true,
        -- ปุ่มสกิลทั่วไป Q, E, R, F, C, V, Z, X, T, G, B
        [Enum.KeyCode.Q] = true,
        [Enum.KeyCode.E] = true,
        [Enum.KeyCode.R] = true,
        [Enum.KeyCode.F] = true,
        [Enum.KeyCode.C] = true,
        [Enum.KeyCode.V] = true,
        [Enum.KeyCode.Z] = true,
        [Enum.KeyCode.X] = true,
        [Enum.KeyCode.T] = true,
        [Enum.KeyCode.G] = true,
        [Enum.KeyCode.B] = true,
    }

    local function registerAttackInput()
        lastAttackInputTick = tick()
        local mouse = LocalPlayer:GetMouse()
        if mouse then
            pcall(function() lastAttackMouseTarget = mouse.Target end)
        end
    end

    -- 1. ตรวจจับการกดโจมตีและปุ่มสกิล (คลิกเมาส์, ทัชหน้าจอ, ปุ่มจอยสติ๊ก, ปุ่มเลข 1 2 3 4 และปุ่มสกิลทั้งหมด)
    local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- ไม่ตรวจจับหากผู้เล่นกำลังพิมพ์ข้อความในช่องแชท (Chat TextBox)
        local isTyping = (UserInputService:GetFocusedTextBox() ~= nil)
        if isTyping then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.Touch
            or input.KeyCode == Enum.KeyCode.ButtonR2
            or input.KeyCode == Enum.KeyCode.ButtonR1
            or input.KeyCode == Enum.KeyCode.ButtonL2
            or input.KeyCode == Enum.KeyCode.ButtonL1
            or skillKeyCodes[input.KeyCode] then
            registerAttackInput()
        end
    end)
    table.insert(hitDetectorConns, inputConn)

    -- 2. ตรวจจับแอนิเมชันสกิล/การโจมตี (เมื่อตัวละครปล่อยท่า Action Animation สกิลจะถูกลงทะเบียนอัตโนมัติ)
    local humanoid = char:WaitForChild("Humanoid", 3) or char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local function checkTrack(track)
            if not track then return end
            local p = track.Priority
            if p == Enum.AnimationPriority.Action
                or p == Enum.AnimationPriority.Action2
                or p == Enum.AnimationPriority.Action3
                or p == Enum.AnimationPriority.Action4 then
                registerAttackInput()
            end
        end

        local animator = humanoid:WaitForChild("Animator", 2) or humanoid:FindFirstChildOfClass("Animator")
        if animator then
            local animConn = animator.AnimationPlayed:Connect(checkTrack)
            table.insert(hitDetectorConns, animConn)
        end
        local humAnimConn = humanoid.AnimationPlayed:Connect(checkTrack)
        table.insert(hitDetectorConns, humAnimConn)
    end

    -- 3. ผูก Tool และ Backpack สำหรับสกิลที่อยู่ในช่องไอเทม/กระเป๋า
    local function bindTool(tool)
        if not tool:IsA("Tool") then return end
        local actConn = tool.Activated:Connect(function()
            registerAttackInput()
        end)
        table.insert(hitDetectorConns, actConn)

        local eqConn = tool.Equipped:Connect(function()
            registerAttackInput()
        end)
        table.insert(hitDetectorConns, eqConn)

        for _, desc in ipairs(tool:GetDescendants()) do
            if desc:IsA("BasePart") then
                local tConn = desc.Touched:Connect(function(hit)
                    if not hit or not hit.Parent then return end
                    local tChar = hit.Parent
                    if tChar:IsA("Accessory") then tChar = tChar.Parent end
                    if tChar and tChar ~= char and (tick() - lastAttackInputTick) < 0.80 then
                        lastToolHit[tChar] = { pos = hit.Position, tick = tick() }
                    end
                end)
                table.insert(hitDetectorConns, tConn)
            end
        end
        local descConn = tool.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") then
                local tConn = desc.Touched:Connect(function(hit)
                    if not hit or not hit.Parent then return end
                    local tChar = hit.Parent
                    if tChar:IsA("Accessory") then tChar = tChar.Parent end
                    if tChar and tChar ~= char and (tick() - lastAttackInputTick) < 0.80 then
                        lastToolHit[tChar] = { pos = hit.Position, tick = tick() }
                    end
                end)
                table.insert(hitDetectorConns, tConn)
            end
        end)
        table.insert(hitDetectorConns, descConn)
    end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then bindTool(child) end
    end
    local toolConn = char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then bindTool(child) end
    end)
    table.insert(hitDetectorConns, toolConn)

    local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then bindTool(item) end
        end
        local bpConn = bp.ChildAdded:Connect(function(item)
            if item:IsA("Tool") then bindTool(item) end
        end)
        table.insert(hitDetectorConns, bpConn)
    end

    -- 4. ตรวจจับดาเมจศัตรู (ทั้งระยะประชิด Melee, สกิลคอมโบ 1 2 3 4, และระยะไกล Ranged / Magic / Projectiles)
    -- ทำงานเฉพาะเมื่อเลือดศัตรูลดจริงเท่านั้น (newHealth < oldHealth) ไม่มีการลั่นเอฟเฟคตอนเดินชนกันแน่นอน
    local function monitorCharacterDamage(otherChar)
        if not otherChar or otherChar == char then return end
        if monitoredChars[otherChar] then return end
        monitoredChars[otherChar] = true

        local otherHum = otherChar:FindFirstChildOfClass("Humanoid")
        local otherRoot = otherChar:FindFirstChild("HumanoidRootPart") or otherChar:FindFirstChild("Torso")
        if not otherHum or not otherRoot then
            task.spawn(function()
                otherHum = otherChar:WaitForChild("Humanoid", 2)
                otherRoot = otherChar:WaitForChild("HumanoidRootPart", 2) or otherChar:FindFirstChild("Torso")
                if otherHum and otherRoot then
                    enemyHealthCache[otherHum] = otherHum.Health
                end
            end)
        else
            enemyHealthCache[otherHum] = otherHum.Health
        end

        local hConn = otherHum and otherHum.HealthChanged:Connect(function(newHealth)
            local oldH = enemyHealthCache[otherHum]
            if not oldH then
                enemyHealthCache[otherHum] = newHealth
                return
            end
            enemyHealthCache[otherHum] = newHealth
            local damage = oldH - newHealth
            if damage <= 0.05 then return end -- ต้องเกิดดาเมจจริงเท่านั้น
            if not CharacterMod.HitFX or not CharacterMod.HitFX.Enabled then return end

            local now = tick()
            if (now - (targetHitDebounce[otherChar] or 0)) < 0.10 then return end

            local isOurHit = false
            local myChar = LocalPlayer.Character
            local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso"))

            -- 4.1 ตรวจจับแท็ก creator ของ Roblox (ระบบอาวุธ/ปืน/กระสุนส่วนใหญ่จะมี ObjectValue ชื่อ creator)
            local creator = otherHum:FindFirstChild("creator")
            if creator and creator:IsA("ObjectValue") and creator.Value == LocalPlayer then
                isOurHit = true
            end

            -- 4.2 ตรวจจับจากการโจมตี/กดสกิล + ระยะทางและทิศทางการเล็ง (Heuristic Aim & Range Detection)
            if not isOurHit and myRoot and otherRoot and otherRoot.Parent then
                local dist = (otherRoot.Position - myRoot.Position).Magnitude
                local timeSinceAttack = now - lastAttackInputTick

                -- ก. ระยะประชิด & สกิลรอบตัว (Melee / AoE Skills: <= 22 studs) กดโจมตี/สกิลในรอบ 1.6 วินาที
                -- ครอบคลุมสกิลหมุนตัว, ทุบพื้น, สกิลฟันคอมโบ 360 องศา
                if dist <= 22 and timeSinceAttack < 1.60 then
                    isOurHit = true
                -- ข. สกิลระยะกลาง / พุ่งชน / คลื่นกระแทก (Medium Range Skills: 22 ถึง 40 studs)
                elseif dist > 22 and dist <= 40 and timeSinceAttack < 2.20 then
                    local toTarget = (otherRoot.Position - myRoot.Position).Unit
                    local facingDot = toTarget:Dot(myRoot.CFrame.LookVector)
                    if facingDot > -0.45 then
                        isOurHit = true
                    end
                -- ค. ระยะไกล & สกิลยิง / บีม / กระสุนเวท (Ranged Skills: 40 ถึง 950 studs) ในรอบ 3.5 วินาที
                elseif dist > 40 and dist <= 950 and timeSinceAttack < 3.50 then
                    local mouse = LocalPlayer:GetMouse()
                    local mouseTarget = mouse and mouse.Target

                    -- เล็งเมาส์โดนตัวเป้าหมายโดยตรง
                    if (mouseTarget and mouseTarget:IsDescendantOf(otherChar))
                        or (lastAttackMouseTarget and lastAttackMouseTarget:IsDescendantOf(otherChar)) then
                        isOurHit = true
                    else
                        local cam = workspace.CurrentCamera
                        if cam then
                            local toEnemy = (otherRoot.Position - cam.CFrame.Position).Unit
                            local camLook = cam.CFrame.LookVector
                            local aimDot = toEnemy:Dot(camLook)

                            local screenPos, onScreen = cam:WorldToViewportPoint(otherRoot.Position)
                            local mouseLoc = UserInputService:GetMouseLocation()
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude

                            -- เล็งไปทางศัตรู (Aim Cone หรือใกล้จุดกึ่งกลางเมาส์บนจอ)
                            if (onScreen and screenDist < 280) or aimDot > 0.72 then
                                isOurHit = true
                            end
                        end
                    end
                end
            end

            if isOurHit then
                targetHitDebounce[otherChar] = now

                -- กำหนดจุดเกิดเอฟเฟค
                local hitPos
                local recentTool = lastToolHit[otherChar]
                if recentTool and (now - recentTool.tick) < 0.40 then
                    hitPos = recentTool.pos
                else
                    local targetPart = otherChar:FindFirstChild("UpperTorso") or otherChar:FindFirstChild("Torso") or otherRoot
                    hitPos = targetPart.Position
                end

                -- หันเอฟเฟคมาทางเรา/กล้อง ให้เห็นแสงและสะเก็ดพุ่งเข้าตาอย่างอลังการ
                local cam = workspace.CurrentCamera
                local hitNormal
                if cam then
                    hitNormal = (cam.CFrame.Position - hitPos).Unit
                elseif myRoot then
                    hitNormal = (myRoot.Position - hitPos).Unit
                else
                    hitNormal = Vector3.new(0, 1, 0)
                end

                spawnHitCombatFX(hitPos, hitNormal)
            end
        end)
        if hConn then table.insert(hitDetectorConns, hConn) end

        local ancConn = otherChar.AncestryChanged:Connect(function(_, parent)
            if not parent then
                monitoredChars[otherChar] = nil
            end
        end)
        table.insert(hitDetectorConns, ancConn)
    end

    -- มอนิเตอร์ผู้เล่นคนอื่นในเซิร์ฟเวอร์
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            monitorCharacterDamage(p.Character)
        end
        local pCharConn = p.CharacterAdded:Connect(function(otherC)
            monitorCharacterDamage(otherC)
        end)
        table.insert(hitDetectorConns, pCharConn)
    end

    local plAddedConn = Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then
            local pCharConn = p.CharacterAdded:Connect(function(otherC)
                monitorCharacterDamage(otherC)
            end)
            table.insert(hitDetectorConns, pCharConn)
        end
    end)
    table.insert(hitDetectorConns, plAddedConn)

    -- มอนิเตอร์บอท/หุ่นซ้อม/NPCs/Dummies ใน workspace
    local function checkPotentialTarget(model)
        if model:IsA("Model") and model ~= char and model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then
                monitorCharacterDamage(model)
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        checkPotentialTarget(child)
        if child:IsA("Folder") or child:IsA("Model") then
            for _, sub in ipairs(child:GetChildren()) do
                checkPotentialTarget(sub)
            end
        end
    end

    local descConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Humanoid") and obj.Parent and obj.Parent ~= char and obj.Parent:IsA("Model") then
            monitorCharacterDamage(obj.Parent)
        end
    end)
    table.insert(hitDetectorConns, descConn)
end

local function cleanupCharacterMod()
    if charModConnection then charModConnection:Disconnect(); charModConnection = nil end
    if charAddedConnection then charAddedConnection:Disconnect(); charAddedConnection = nil end
    if humanoidJumpConn then humanoidJumpConn:Disconnect(); humanoidJumpConn = nil end
    if humanoidJumpingDirectConn then humanoidJumpingDirectConn:Disconnect(); humanoidJumpingDirectConn = nil end
    cleanupCombatHitDetector()
    if GhostHighlight then GhostHighlight:Destroy(); GhostHighlight = nil end
    if GhostWispAttachment then GhostWispAttachment:Destroy(); GhostWispAttachment = nil end
    if CharAuraAttachment then CharAuraAttachment:Destroy(); CharAuraAttachment = nil end
    if CharGlowLight then CharGlowLight:Destroy(); CharGlowLight = nil end
    if CharFloorLight then CharFloorLight:Destroy(); CharFloorLight = nil end
    if CharFloorAttachment then CharFloorAttachment:Destroy(); CharFloorAttachment = nil end
    restoreCharacterOriginalState()
end

charModConnection = RunService.Heartbeat:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end

    -- Master synchronized RGB cycle (ซิงค์สี RGB ทุกระบบให้ตรงกัน 100%)
    local rgbSpeed = CharacterMod.RGB.Speed or 0.35
    local masterHue = (tick() * rgbSpeed * 0.30) % 1
    local masterRGB = Color3.fromHSV(masterHue, CharacterMod.RGB.Saturation, CharacterMod.RGB.Value)

    local activeLightingColor = nil
    local activeLightingBrightness = 1.2

    -- 1. RGB Engine
    if CharacterMod.RGB.Enabled then
        local parts = getCharacterParts(char)
        local mat = (CharacterMod.RGB.Style == "Neon") and Enum.Material.Neon or Enum.Material.SmoothPlastic
        activeLightingColor = masterRGB
        activeLightingBrightness = 1.35

        for _, part in ipairs(parts) do
            savePartOriginalState(part)
            local col
            if CharacterMod.RGB.WaveSpread then
                local yOffset = (part.Position.Y * 0.10) + (part.Position.X * 0.03)
                local hue = (masterHue + yOffset) % 1
                col = Color3.fromHSV(hue, CharacterMod.RGB.Saturation, CharacterMod.RGB.Value)
            else
                col = masterRGB
            end
            part.Color = col
            if not CharacterMod.Ghost.Enabled then
                part.Material = mat
            end
            local mesh = part:FindFirstChildOfClass("SpecialMesh")
            if mesh then
                mesh.VertexColor = Vector3.new(col.R, col.G, col.B)
            end
        end
    end

    -- 2. Ghost Mode Pulse & Dynamic Sync
    if CharacterMod.Ghost.Enabled and GhostHighlight and GhostHighlight.Parent == char then
        if CharacterMod.Ghost.Pulse then
            local pulse = math.sin(tick() * 2.8) * 0.08
            GhostHighlight.FillTransparency = math.clamp(0.62 + pulse, 0.45, 0.85)
            local baseOutline = CharacterMod.Ghost.OutlineTransparency or 0.78
            GhostHighlight.OutlineTransparency = math.clamp(baseOutline + pulse * 0.25, 0.55, 0.98)
        end
        if CharacterMod.Ghost.Theme == "Rainbow" then
            -- ซิงค์สีรุ้งของ Ghost Mode กับความเร็ว RGB และสีหลัก
            GhostHighlight.FillColor = masterRGB
            GhostHighlight.OutlineColor = masterRGB
            if GhostWispEmitter and GhostWispEmitter.Parent then
                GhostWispEmitter.Color = ColorSequence.new(masterRGB, Color3.fromRGB(255, 255, 255))
            end
            if not activeLightingColor then
                activeLightingColor = masterRGB
                activeLightingBrightness = 1.3
            end
        elseif CharacterMod.Ghost.Theme == "Ambience" then
            -- ซิงค์สีเดียวกับบรรยากาศ
            local ambCol = CurrentState.Color or Color3.fromRGB(160, 160, 255)
            GhostHighlight.FillColor = ambCol
            GhostHighlight.OutlineColor = Color3.new(
                math.clamp(ambCol.R * 1.25, 0, 1),
                math.clamp(ambCol.G * 1.25, 0, 1),
                math.clamp(ambCol.B * 1.25, 0, 1)
            )
            if GhostWispEmitter and GhostWispEmitter.Parent then
                GhostWispEmitter.Color = ColorSequence.new(ambCol, Color3.fromRGB(255, 255, 255))
            end
            if not activeLightingColor then
                activeLightingColor = ambCol
                activeLightingBrightness = 1.25
            end
        else
            local theme = GHOST_THEMES[CharacterMod.Ghost.Theme] or GHOST_THEMES.Cyan
            GhostHighlight.FillColor = theme.Fill
            GhostHighlight.OutlineColor = theme.Outline
            if not activeLightingColor then
                activeLightingColor = theme.Fill
                activeLightingBrightness = 1.25
            end
        end
    end

    -- 3. Particle Aura Sync
    if CharacterMod.Particle.Enabled and CharAuraEmitter and CharAuraEmitter.Parent then
        if CharacterMod.Particle.ColorMode == "Rainbow" then
            -- ซิงค์สีรุ้งของ Particle กับ masterRGB
            local pCol2 = Color3.fromHSV((masterHue + 0.15) % 1, 0.9, 1)
            CharAuraEmitter.Color = ColorSequence.new(masterRGB, pCol2)
            if not activeLightingColor then
                activeLightingColor = masterRGB
                activeLightingBrightness = 1.2
            end
        elseif CharacterMod.Particle.ColorMode == "SyncAmbience" then
            local fogCol = CurrentState.Color or Color3.fromRGB(160, 160, 255)
            CharAuraEmitter.Color = ColorSequence.new(fogCol)
            if not activeLightingColor then
                activeLightingColor = fogCol
                activeLightingBrightness = 1.2
            end
        else
            if not activeLightingColor then
                local preset = CHAR_PARTICLE_PRESETS[CharacterMod.Particle.Preset] or CHAR_PARTICLE_PRESETS.SoulWisps
                activeLightingColor = preset.Color.Keypoints[1].Value
                activeLightingBrightness = 1.1
            end
        end
    end

    -- 4. Dynamic Character Glow & Floor Lighting (นุ่มนวล ไม่สว่างจ้า)
    if activeLightingColor then
        updateCharacterLights(char, activeLightingColor, activeLightingBrightness, 14)
    else
        disableCharacterLights()
    end
end)

charAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.35)
    SavedCharacterParts = {}
    if GhostHighlight then GhostHighlight:Destroy(); GhostHighlight = nil end
    if GhostWispAttachment then GhostWispAttachment:Destroy(); GhostWispAttachment = nil end
    if CharAuraAttachment then CharAuraAttachment:Destroy(); CharAuraAttachment = nil end
    if CharGlowLight then CharGlowLight:Destroy(); CharGlowLight = nil end
    if CharFloorLight then CharFloorLight:Destroy(); CharFloorLight = nil end
    if CharFloorAttachment then CharFloorAttachment:Destroy(); CharFloorAttachment = nil end

    if CharacterMod.Ghost.Enabled then
        applyGhostMode(newChar)
    end
    if CharacterMod.Particle.Enabled then
        applyCharacterParticle(newChar)
    end
    setupCharacterJumpDetector(newChar)
    setupCombatHitDetector(newChar)
end)

setupCharacterJumpDetector(LocalPlayer.Character)
setupCombatHitDetector(LocalPlayer.Character)

-- ========================================================
-- GUI
-- ========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AmbienceControllerUI"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 370, 0, 540)
MainFrame.Position = UDim2.new(0.5, -185, 0.5, -270)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- Title
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "✨ Horizon FX & Character Mod"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 13
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    cleanupCharacterMod()
    if lockConnection then lockConnection:Disconnect() end
    if mainFXConnection then mainFXConnection:Disconnect() end
    if customColorCorrection then customColorCorrection:Destroy() end
    if customBloom then customBloom:Destroy() end
    if ParticleFolder then ParticleFolder:Destroy() end
    ScreenGui:Destroy()
end)

-- Dragging
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Tab Navigation
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 32)
TabBar.Position = UDim2.new(0, 10, 0, 46)
TabBar.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabBarLayout = Instance.new("UIGridLayout")
TabBarLayout.CellSize = UDim2.new(0.485, 0, 1, 0)
TabBarLayout.CellPadding = UDim2.new(0.03, 0, 0, 0)
TabBarLayout.Parent = TabBar

local TabAmbienceBtn = Instance.new("TextButton")
TabAmbienceBtn.Text = "🌌 บรรยากาศ (Ambience)"
TabAmbienceBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 220)
TabAmbienceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabAmbienceBtn.Font = Enum.Font.GothamBold
TabAmbienceBtn.TextSize = 11
TabAmbienceBtn.Parent = TabBar
local cTab1 = Instance.new("UICorner"); cTab1.CornerRadius = UDim.new(0, 6); cTab1.Parent = TabAmbienceBtn

local TabCharBtn = Instance.new("TextButton")
TabCharBtn.Text = "👤 ตัวละคร (Character Mod)"
TabCharBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
TabCharBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
TabCharBtn.Font = Enum.Font.GothamBold
TabCharBtn.TextSize = 11
TabCharBtn.Parent = TabBar
local cTab2 = Instance.new("UICorner"); cTab2.CornerRadius = UDim.new(0, 6); cTab2.Parent = TabCharBtn

-- Content ScrollFrame (Ambience)
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -20, 1, -92)
Content.Position = UDim2.new(0, 10, 0, 84)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 5
Content.CanvasSize = UDim2.new(0, 0, 0, 2200)
Content.Visible = true
Content.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 9)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = Content

-- Content ScrollFrame (Character Mod)
local ContentChar = Instance.new("ScrollingFrame")
ContentChar.Size = UDim2.new(1, -20, 1, -92)
ContentChar.Position = UDim2.new(0, 10, 0, 84)
ContentChar.BackgroundTransparency = 1
ContentChar.BorderSizePixel = 0
ContentChar.ScrollBarThickness = 5
ContentChar.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentChar.CanvasSize = UDim2.new(0, 0, 0, 1950)
ContentChar.Visible = false
ContentChar.Parent = MainFrame

local UIListChar = Instance.new("UIListLayout")
UIListChar.Padding = UDim.new(0, 9)
UIListChar.SortOrder = Enum.SortOrder.LayoutOrder
UIListChar.Parent = ContentChar

TabAmbienceBtn.MouseButton1Click:Connect(function()
    Content.Visible = true
    ContentChar.Visible = false
    TabAmbienceBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 220)
    TabAmbienceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabCharBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
    TabCharBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
end)

TabCharBtn.MouseButton1Click:Connect(function()
    Content.Visible = false
    ContentChar.Visible = true
    TabCharBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 220)
    TabCharBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabAmbienceBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
    TabAmbienceBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
end)

do
    local function createSectionTitle(text, order, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(180, 200, 235)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = Content
    return label
end

-- ========================================================
-- 1. เวลา
-- ========================================================
createSectionTitle("⏰ ปรับเวลา (เริ่มต้น: กลางคืน)", 1)
local TimeFrame = Instance.new("Frame")
TimeFrame.Size = UDim2.new(1, 0, 0, 32); TimeFrame.BackgroundTransparency = 1; TimeFrame.LayoutOrder = 2; TimeFrame.Parent = Content
local TimeLayout = Instance.new("UIGridLayout"); TimeLayout.CellSize = UDim2.new(0.23, 0, 1, 0); TimeLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); TimeLayout.Parent = TimeFrame

local times = {{name="กลางคืน",val=0},{name="เช้า",val=6.5},{name="เที่ยง",val=12},{name="เย็น",val=17.8}}
for _, t in ipairs(times) do
    local btn = Instance.new("TextButton")
    btn.Text = t.name; btn.BackgroundColor3 = Color3.fromRGB(32, 34, 42); btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 11; btn.Parent = TimeFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function() CurrentState.ClockTime = t.val; applyLightingSettings() end)
end

-- ========================================================
-- 2. สีบรรยากาศ
-- ========================================================
createSectionTitle("🎨 สีบรรยากาศ + หมอก + แสงเรือง", 3)
local ColorFrame = Instance.new("Frame")
ColorFrame.Size = UDim2.new(1, 0, 0, 115); ColorFrame.BackgroundTransparency = 1; ColorFrame.LayoutOrder = 4; ColorFrame.Parent = Content
local ColorLayout = Instance.new("UIGridLayout"); ColorLayout.CellSize = UDim2.new(0.31, 0, 0, 32); ColorLayout.CellPadding = UDim2.new(0.035, 0, 0, 8); ColorLayout.Parent = ColorFrame

local colors = {
    {name="🔴 แดง", c=Color3.fromRGB(220, 40, 40)},
    {name="🟣 ม่วงนีออน", c=Color3.fromRGB(180, 60, 240)},
    {name="🔵 น้ำเงินลึก", c=Color3.fromRGB(40, 120, 255)},
    {name="🟢 เขียวพิษ", c=Color3.fromRGB(50, 220, 90)},
    {name="🟡 ทองคำ", c=Color3.fromRGB(240, 190, 50)},
    {name="🌸 ชมพูเวทมนตร์", c=Color3.fromRGB(240, 110, 180)},
    {name="⚪ ขาวสว่าง", c=Color3.fromRGB(255, 255, 255)},
    {name="⚫ ทมิฬมืด", c=Color3.fromRGB(25, 25, 35)},
    {name="🔄 รีเซ็ตเดิม", c=Color3.fromRGB(140, 140, 140)}
}
for _, cp in ipairs(colors) do
    local btn = Instance.new("TextButton")
    btn.Text = cp.name; btn.BackgroundColor3 = Color3.fromRGB(32, 34, 42); btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 11; btn.Parent = ColorFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function() CurrentState.Color = cp.c; applyLightingSettings() end)
end

-- ========================================================
-- 3. ปรับระยะหมอกขอบฟ้า
-- ========================================================
createSectionTitle("🌫️ ปรับระยะหมอก (คลุมพื้น + เส้นขอบฟ้า)", 5, Color3.fromRGB(200, 220, 240))
local FogFrame = Instance.new("Frame")
FogFrame.Size = UDim2.new(1, 0, 0, 75); FogFrame.BackgroundTransparency = 1; FogFrame.LayoutOrder = 6; FogFrame.Parent = Content
local FogLayout = Instance.new("UIGridLayout"); FogLayout.CellSize = UDim2.new(0.48, 0, 0, 32); FogLayout.CellPadding = UDim2.new(0.04, 0, 0, 8); FogLayout.Parent = FogFrame

local fogPresets = {
    {name = "หมอกทึบสุด (หนาแน่น)", fogEnd = 80, density = 0.75, haze = 5},
    {name = "หมอกปานกลาง (สมดุล)", fogEnd = 250, density = 0.45, haze = 3},
    {name = "หมอกบางรอบขอบฟ้า", fogEnd = 650, density = 0.2, haze = 1.5},
    {name = "ปิดหมอกทั้งหมด (Clear)", fogEnd = 100000, density = 0, haze = 0}
}

for _, fp in ipairs(fogPresets) do
    local btn = Instance.new("TextButton")
    btn.Text = fp.name; btn.BackgroundColor3 = Color3.fromRGB(32, 34, 42); btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = FogFrame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        CurrentState.FogEnd = fp.fogEnd
        CurrentState.FogDensity = fp.density
        CurrentState.FogHaze = fp.haze
        CurrentState.FogStart = 0
        applyLightingSettings()
        for _, other in ipairs(FogFrame:GetChildren()) do
            if other:IsA("TextButton") then other.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end
        end
        btn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
    end)
end

-- ========================================================
-- 3.5 ระยะการเกิด & ความหนาแน่นระยะอื่น (Global FX Distance & Density)
-- ========================================================
createSectionTitle("🌐 ขอบเขตระยะเกิด & การเกิดระยะอื่น (Global FX)", 7, Color3.fromRGB(130, 230, 210))

-- 1. ขอบเขตระยะการเกิด
local GlobalDistTitle = Instance.new("TextLabel")
GlobalDistTitle.Size = UDim2.new(1, 0, 0, 18); GlobalDistTitle.BackgroundTransparency = 1
GlobalDistTitle.Text = "📍 ขอบเขตระยะการเกิด (เริ่มต้น = ต่ำสุด):"
GlobalDistTitle.TextColor3 = Color3.fromRGB(160, 180, 210); GlobalDistTitle.Font = Enum.Font.Gotham; GlobalDistTitle.TextSize = 11
GlobalDistTitle.TextXAlignment = Enum.TextXAlignment.Left; GlobalDistTitle.LayoutOrder = 8; GlobalDistTitle.Parent = Content

local GlobalDistFrame = Instance.new("Frame")
GlobalDistFrame.Size = UDim2.new(1, 0, 0, 32); GlobalDistFrame.BackgroundTransparency = 1; GlobalDistFrame.LayoutOrder = 9; GlobalDistFrame.Parent = Content
local gdLayout = Instance.new("UIGridLayout"); gdLayout.CellSize = UDim2.new(0.23, 0, 1, 0); gdLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); gdLayout.Parent = GlobalDistFrame

local globalDists = {
    {name="เริ่มต้น (1.0x)", val=1.0},
    {name="ปานกลาง (2.0x)", val=2.0},
    {name="ไกลกว้าง (3.2x)", val=3.2},
    {name="ไกลสุดขอบฟ้า (4.5x)", val=4.5}
}

for _, gd in ipairs(globalDists) do
    local btn = Instance.new("TextButton")
    btn.Text = gd.name; btn.BackgroundColor3 = (Config.GlobalSpawnDistance == gd.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9.5; btn.Parent = GlobalDistFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.GlobalSpawnDistance = math.max(1.0, gd.val)
        for _, b in ipairs(GlobalDistFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- 2. ปรับการเกิดของระยะอื่น (ไม่ส่งผลต่อระยะปกติ)
local OuterBoostTitle = Instance.new("TextLabel")
OuterBoostTitle.Size = UDim2.new(1, 0, 0, 18); OuterBoostTitle.BackgroundTransparency = 1
OuterBoostTitle.Text = "✨ ปรับการเกิดของระยะอื่น (ไม่กระทบระยะปกติ):"
OuterBoostTitle.TextColor3 = Color3.fromRGB(160, 180, 210); OuterBoostTitle.Font = Enum.Font.Gotham; OuterBoostTitle.TextSize = 11
OuterBoostTitle.TextXAlignment = Enum.TextXAlignment.Left; OuterBoostTitle.LayoutOrder = 10; OuterBoostTitle.Parent = Content

local OuterBoostFrame = Instance.new("Frame")
OuterBoostFrame.Size = UDim2.new(1, 0, 0, 32); OuterBoostFrame.BackgroundTransparency = 1; OuterBoostFrame.LayoutOrder = 11; OuterBoostFrame.Parent = Content
local obLayout = Instance.new("UIGridLayout"); obLayout.CellSize = UDim2.new(0.23, 0, 1, 0); obLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); obLayout.Parent = OuterBoostFrame

local outerBoosts = {
    {name="คำนวณเดิม (1.0x)", val=1.0},
    {name="เพิ่มขึ้น (1.6x)", val=1.6},
    {name="หนาแน่น (2.5x)", val=2.5},
    {name="เต็มท้องฟ้า (3.8x)", val=3.8}
}

for _, ob in ipairs(outerBoosts) do
    local btn = Instance.new("TextButton")
    btn.Text = ob.name; btn.BackgroundColor3 = (Config.OuterDistanceSpawnBoost == ob.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9.5; btn.Parent = OuterBoostFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.OuterDistanceSpawnBoost = math.max(1.0, ob.val)
        for _, b in ipairs(OuterBoostFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- ========================================================
-- 4. ตั้งค่าแยก: เส้นหักมุม 90°
-- ========================================================
createSectionTitle("⚡ 1. เส้นหักมุม 90°", 12, Color3.fromRGB(100, 200, 255))

local SnapToggle = Instance.new("TextButton")
SnapToggle.Size = UDim2.new(1, 0, 0, 32); SnapToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
SnapToggle.Text = "⚡ เปิด/ปิด เส้นหักมุม 90°: เปิดอยู่"; SnapToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SnapToggle.Font = Enum.Font.GothamBold; SnapToggle.TextSize = 11; SnapToggle.LayoutOrder = 13; SnapToggle.Parent = Content
local stc = Instance.new("UICorner"); stc.CornerRadius = UDim.new(0, 6); stc.Parent = SnapToggle

SnapToggle.MouseButton1Click:Connect(function()
    Config.Snap.Enabled = not Config.Snap.Enabled
    if Config.Snap.Enabled then
        SnapToggle.Text = "⚡ เปิด/ปิด เส้นหักมุม 90°: เปิดอยู่"; SnapToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
    else
        SnapToggle.Text = "❌ ปิดใช้งาน เส้นหักมุม 90°"; SnapToggle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end)

-- ========================================================
-- 5. ตั้งค่าแยก: หางละอองหมอก (Droplet Mist - ช้าลงนุ่มนวล)
-- ========================================================
createSectionTitle("🌫️ 2. หางละอองหมอก (Droplets - ช้าลงนุ่มนวล หางเชื่อมสนิท)", 14, Color3.fromRGB(255, 180, 100))

local DropletToggle = Instance.new("TextButton")
DropletToggle.Size = UDim2.new(1, 0, 0, 32); DropletToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
DropletToggle.Text = "🌫️ เปิด/ปิด หางละอองหมอก: เปิดอยู่"; DropletToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
DropletToggle.Font = Enum.Font.GothamBold; DropletToggle.TextSize = 11; DropletToggle.LayoutOrder = 15; DropletToggle.Parent = Content
local dtc = Instance.new("UICorner"); dtc.CornerRadius = UDim.new(0, 6); dtc.Parent = DropletToggle

DropletToggle.MouseButton1Click:Connect(function()
    Config.CurveDroplet.Enabled = not Config.CurveDroplet.Enabled
    if Config.CurveDroplet.Enabled then
        DropletToggle.Text = "🌫️ เปิด/ปิด หางละอองหมอก: เปิดอยู่"; DropletToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
    else
        DropletToggle.Text = "❌ ปิดใช้งาน หางละอองหมอก"; DropletToggle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end)

-- ความเร็ว (Speed)
local DropletSpeedTitle = Instance.new("TextLabel")
DropletSpeedTitle.Size = UDim2.new(1, 0, 0, 18); DropletSpeedTitle.BackgroundTransparency = 1
DropletSpeedTitle.Text = "💨 ความเร็วการลอยล่อง (Speed):"
DropletSpeedTitle.TextColor3 = Color3.fromRGB(160, 180, 210); DropletSpeedTitle.Font = Enum.Font.Gotham; DropletSpeedTitle.TextSize = 11
DropletSpeedTitle.TextXAlignment = Enum.TextXAlignment.Left; DropletSpeedTitle.LayoutOrder = 16; DropletSpeedTitle.Parent = Content

local DropletSpeedFrame = Instance.new("Frame")
DropletSpeedFrame.Size = UDim2.new(1, 0, 0, 32); DropletSpeedFrame.BackgroundTransparency = 1; DropletSpeedFrame.LayoutOrder = 17; DropletSpeedFrame.Parent = Content
local dspLayout = Instance.new("UIGridLayout"); dspLayout.CellSize = UDim2.new(0.31, 0, 1, 0); dspLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); dspLayout.Parent = DropletSpeedFrame

local dropletSpeeds = {
    {name="ช้ามาก (3.5)", val=3.5},
    {name="ช้านุ่มนวล (5.2)", val=5.2},
    {name="ปกติ (8.5)", val=8.5}
}

for _, dsp in ipairs(dropletSpeeds) do
    local btn = Instance.new("TextButton")
    btn.Text = dsp.name; btn.BackgroundColor3 = (Config.CurveDroplet.Speed == dsp.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = DropletSpeedFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.CurveDroplet.Speed = dsp.val
        for _, b in ipairs(DropletSpeedFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- ขนาด
local DropletSizeTitle = Instance.new("TextLabel")
DropletSizeTitle.Size = UDim2.new(1, 0, 0, 18); DropletSizeTitle.BackgroundTransparency = 1
DropletSizeTitle.Text = "📏 ขนาดเริ่มต้นละอองหมอก:"
DropletSizeTitle.TextColor3 = Color3.fromRGB(160, 180, 210); DropletSizeTitle.Font = Enum.Font.Gotham; DropletSizeTitle.TextSize = 11
DropletSizeTitle.TextXAlignment = Enum.TextXAlignment.Left; DropletSizeTitle.LayoutOrder = 18; DropletSizeTitle.Parent = Content

local DropletSizeFrame = Instance.new("Frame")
DropletSizeFrame.Size = UDim2.new(1, 0, 0, 32); DropletSizeFrame.BackgroundTransparency = 1; DropletSizeFrame.LayoutOrder = 19; DropletSizeFrame.Parent = Content
local dsLayout = Instance.new("UIGridLayout"); dsLayout.CellSize = UDim2.new(0.31, 0, 1, 0); dsLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); dsLayout.Parent = DropletSizeFrame

local dropletSizes = {{name="จิ๋ว (0.2)", val=0.2},{name="กะทัดรัด (0.28)", val=0.28},{name="ปานกลาง (0.4)", val=0.4}}
for _, ds in ipairs(dropletSizes) do
    local btn = Instance.new("TextButton")
    btn.Text = ds.name; btn.BackgroundColor3 = (Config.CurveDroplet.HeadSize == ds.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = DropletSizeFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.CurveDroplet.HeadSize = ds.val
        for _, b in ipairs(DropletSizeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- ความถี่การปล่อยจุดหาง (Dot Rate / Spacing)
local DropletRateTitle = Instance.new("TextLabel")
DropletRateTitle.Size = UDim2.new(1, 0, 0, 18); DropletRateTitle.BackgroundTransparency = 1
DropletRateTitle.Text = "⏳ ความถี่จุดหาง (ปรับลดความรัว):"
DropletRateTitle.TextColor3 = Color3.fromRGB(160, 180, 210); DropletRateTitle.Font = Enum.Font.Gotham; DropletRateTitle.TextSize = 11
DropletRateTitle.TextXAlignment = Enum.TextXAlignment.Left; DropletRateTitle.LayoutOrder = 20; DropletRateTitle.Parent = Content

local DropletRateFrame = Instance.new("Frame")
DropletRateFrame.Size = UDim2.new(1, 0, 0, 32); DropletRateFrame.BackgroundTransparency = 1; DropletRateFrame.LayoutOrder = 21; DropletRateFrame.Parent = Content
local drLayout = Instance.new("UIGridLayout"); drLayout.CellSize = UDim2.new(0.31, 0, 1, 0); drLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); drLayout.Parent = DropletRateFrame

local dropletRates = {
    {name="ถี่แน่น (0.45)", val=0.45},
    {name="นุ่มนวลพอดี (0.58)", val=0.58},
    {name="ห่างโปร่ง (0.75)", val=0.75}
}

for _, dr in ipairs(dropletRates) do
    local btn = Instance.new("TextButton")
    btn.Text = dr.name; btn.BackgroundColor3 = (Config.CurveDroplet.StepRatio == dr.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9; btn.Parent = DropletRateFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.CurveDroplet.StepRatio = dr.val
        for _, b in ipairs(DropletRateFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- ========================================================
-- 6. ตั้งค่าแยก: หางแสงปกติ (Ribbon Trail)
-- ========================================================
createSectionTitle("💫 3. หางแสงปกติ (Ribbon Trail - ปลายแหลม)", 22, Color3.fromRGB(140, 220, 255))

local RibbonToggle = Instance.new("TextButton")
RibbonToggle.Size = UDim2.new(1, 0, 0, 32); RibbonToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
RibbonToggle.Text = "💫 เปิด/ปิด หางแสงปกติ: เปิดอยู่"; RibbonToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
RibbonToggle.Font = Enum.Font.GothamBold; RibbonToggle.TextSize = 11; RibbonToggle.LayoutOrder = 23; RibbonToggle.Parent = Content
local rtc = Instance.new("UICorner"); rtc.CornerRadius = UDim.new(0, 6); rtc.Parent = RibbonToggle

RibbonToggle.MouseButton1Click:Connect(function()
    Config.CurveRibbon.Enabled = not Config.CurveRibbon.Enabled
    if Config.CurveRibbon.Enabled then
        RibbonToggle.Text = "💫 เปิด/ปิด หางแสงปกติ: เปิดอยู่"; RibbonToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
    else
        RibbonToggle.Text = "❌ ปิดใช้งาน หางแสงปกติ"; RibbonToggle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end)

-- ========================================================
-- 7. ตั้งค่าแยก: ละอองลอยปกติ (Classic Ambience)
-- ========================================================
createSectionTitle("✨ 4. ละอองลอยปกติ (Classic Ambience)", 24, Color3.fromRGB(180, 240, 180))

local ClassicToggle = Instance.new("TextButton")
ClassicToggle.Size = UDim2.new(1, 0, 0, 32); ClassicToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
ClassicToggle.Text = "✨ เปิด/ปิด ละอองปกติ: เปิดอยู่"; ClassicToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
ClassicToggle.Font = Enum.Font.GothamBold; ClassicToggle.TextSize = 11; ClassicToggle.LayoutOrder = 25; ClassicToggle.Parent = Content
local cltc = Instance.new("UICorner"); cltc.CornerRadius = UDim.new(0, 6); cltc.Parent = ClassicToggle

ClassicToggle.MouseButton1Click:Connect(function()
    Config.Classic.Enabled = not Config.Classic.Enabled
    if Config.Classic.Enabled then
        ClassicToggle.Text = "✨ เปิด/ปิด ละอองปกติ: เปิดอยู่"; ClassicToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
    else
        ClassicToggle.Text = "❌ ปิดใช้งาน ละอองปกติ"; ClassicToggle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end)

-- ========================================================
-- 8. ตั้งค่าแยก: Tesseract มิติที่ 4
-- ========================================================
createSectionTitle("🔮 5. Tesseract มิติที่ 4 (ลูกบาศก์ลอยฟ้า)", 26, Color3.fromRGB(255, 170, 240))

local TesseractToggle = Instance.new("TextButton")
TesseractToggle.Size = UDim2.new(1, 0, 0, 32); TesseractToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
TesseractToggle.Text = "🔮 เปิด/ปิด Tesseract: เปิดอยู่"; TesseractToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
TesseractToggle.Font = Enum.Font.GothamBold; TesseractToggle.TextSize = 11; TesseractToggle.LayoutOrder = 27; TesseractToggle.Parent = Content
local tstc = Instance.new("UICorner"); tstc.CornerRadius = UDim.new(0, 6); tstc.Parent = TesseractToggle

TesseractToggle.MouseButton1Click:Connect(function()
    Config.Tesseract.Enabled = not Config.Tesseract.Enabled
    if Config.Tesseract.Enabled then
        TesseractToggle.Text = "🔮 เปิด/ปิด Tesseract: เปิดอยู่"; TesseractToggle.BackgroundColor3 = Color3.fromRGB(35, 120, 60)
    else
        TesseractToggle.Text = "❌ ปิดใช้งาน Tesseract"; TesseractToggle.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
    end
end)

-- ขนาด Tesseract
local TesseractSizeTitle = Instance.new("TextLabel")
TesseractSizeTitle.Size = UDim2.new(1, 0, 0, 18); TesseractSizeTitle.BackgroundTransparency = 1
TesseractSizeTitle.Text = "📏 ขนาด Tesseract:"
TesseractSizeTitle.TextColor3 = Color3.fromRGB(160, 180, 210); TesseractSizeTitle.Font = Enum.Font.Gotham; TesseractSizeTitle.TextSize = 11
TesseractSizeTitle.TextXAlignment = Enum.TextXAlignment.Left; TesseractSizeTitle.LayoutOrder = 28; TesseractSizeTitle.Parent = Content

local TesseractSizeFrame = Instance.new("Frame")
TesseractSizeFrame.Size = UDim2.new(1, 0, 0, 32); TesseractSizeFrame.BackgroundTransparency = 1; TesseractSizeFrame.LayoutOrder = 29; TesseractSizeFrame.Parent = Content
local tszLayout = Instance.new("UIGridLayout"); tszLayout.CellSize = UDim2.new(0.31, 0, 1, 0); tszLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); tszLayout.Parent = TesseractSizeFrame

local tesseractSizes = {
    {name="มินิ (1.5)", val=1.5},
    {name="กะทัดรัด (2.2)", val=2.2},
    {name="ปานกลาง (3.2)", val=3.2}
}

for _, ts in ipairs(tesseractSizes) do
    local btn = Instance.new("TextButton")
    btn.Text = ts.name; btn.BackgroundColor3 = (Config.Tesseract.Size == ts.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = TesseractSizeFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.Tesseract.Size = ts.val
        for _, b in ipairs(TesseractSizeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end

-- จำนวน Tesseract
local TesseractCountTitle = Instance.new("TextLabel")
TesseractCountTitle.Size = UDim2.new(1, 0, 0, 18); TesseractCountTitle.BackgroundTransparency = 1
TesseractCountTitle.Text = "🔢 จำนวนที่ลอยบนฟ้า:"
TesseractCountTitle.TextColor3 = Color3.fromRGB(160, 180, 210); TesseractCountTitle.Font = Enum.Font.Gotham; TesseractCountTitle.TextSize = 11
TesseractCountTitle.TextXAlignment = Enum.TextXAlignment.Left; TesseractCountTitle.LayoutOrder = 30; TesseractCountTitle.Parent = Content

local TesseractCountFrame = Instance.new("Frame")
TesseractCountFrame.Size = UDim2.new(1, 0, 0, 32); TesseractCountFrame.BackgroundTransparency = 1; TesseractCountFrame.LayoutOrder = 31; TesseractCountFrame.Parent = Content
local tcLayout = Instance.new("UIGridLayout"); tcLayout.CellSize = UDim2.new(0.31, 0, 1, 0); tcLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); tcLayout.Parent = TesseractCountFrame

local tesseractCounts = {
    {name="3 ชิ้น", val=3},
    {name="6 ชิ้น (แนะนำ)", val=6},
    {name="9 ชิ้น (หนาตา)", val=9}
}

for _, tc in ipairs(tesseractCounts) do
    local btn = Instance.new("TextButton")
    btn.Text = tc.name; btn.BackgroundColor3 = (Config.Tesseract.MaxCount == tc.val) and Color3.fromRGB(180, 100, 40) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = TesseractCountFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        Config.Tesseract.MaxCount = tc.val
        for _, b in ipairs(TesseractCountFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(180, 100, 40)
    end)
end
end -- End Ambience UI do-block

-- ========================================================
-- CHARACTER MOD UI (CONTENTCHAR)
-- ========================================================
local function createCharSectionTitle(text, order, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 24)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(220, 180, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = ContentChar
    return label
end

-- ==================== SECTION 1: RGB MODE ====================
do
    createCharSectionTitle("🌈 โหมด RGB ทั้งตัว (รวมเครื่องประดับ / ของแต่ง)", 1, Color3.fromRGB(255, 180, 220))

    local RgbToggleBtn = Instance.new("TextButton")
RgbToggleBtn.Size = UDim2.new(1, 0, 0, 36)
RgbToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
RgbToggleBtn.Text = "🔴 ปิด RGB อยู่ (คลิกเพื่อเปิดทั้งตัว)"
RgbToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RgbToggleBtn.Font = Enum.Font.GothamBold
RgbToggleBtn.TextSize = 12
RgbToggleBtn.LayoutOrder = 2
RgbToggleBtn.Parent = ContentChar
local cRgbTog = Instance.new("UICorner"); cRgbTog.CornerRadius = UDim.new(0, 8); cRgbTog.Parent = RgbToggleBtn

RgbToggleBtn.MouseButton1Click:Connect(function()
    CharacterMod.RGB.Enabled = not CharacterMod.RGB.Enabled
    if CharacterMod.RGB.Enabled then
        RgbToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        RgbToggleBtn.Text = "🟢 เปิด RGB ทั้งตัวอยู่ (คลิกเพื่อปิด)"
    else
        RgbToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
        RgbToggleBtn.Text = "🔴 ปิด RGB อยู่ (คลิกเพื่อเปิดทั้งตัว)"
        if not CharacterMod.Ghost.Enabled then
            restoreCharacterOriginalState()
        end
    end
end)

local RgbSpeedTitle = Instance.new("TextLabel")
RgbSpeedTitle.Size = UDim2.new(1, 0, 0, 18); RgbSpeedTitle.BackgroundTransparency = 1
RgbSpeedTitle.Text = "⚡ ความเร็วการเปลี่ยนสี:"; RgbSpeedTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
RgbSpeedTitle.Font = Enum.Font.Gotham; RgbSpeedTitle.TextSize = 11; RgbSpeedTitle.TextXAlignment = Enum.TextXAlignment.Left
RgbSpeedTitle.LayoutOrder = 3; RgbSpeedTitle.Parent = ContentChar

local RgbSpeedFrame = Instance.new("Frame")
RgbSpeedFrame.Size = UDim2.new(1, 0, 0, 30); RgbSpeedFrame.BackgroundTransparency = 1; RgbSpeedFrame.LayoutOrder = 4; RgbSpeedFrame.Parent = ContentChar
local rgbSpLayout = Instance.new("UIGridLayout"); rgbSpLayout.CellSize = UDim2.new(0.23, 0, 1, 0); rgbSpLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); rgbSpLayout.Parent = RgbSpeedFrame

local rgbSpeeds = {
    {name="0.15x ช้าเนียน", val=0.15},
    {name="0.35x เริ่มต้น", val=0.35},
    {name="0.75x ปานกลาง", val=0.75},
    {name="1.5x รวดเร็ว", val=1.5}
}
for _, sp in ipairs(rgbSpeeds) do
    local btn = Instance.new("TextButton")
    btn.Text = sp.name; btn.BackgroundColor3 = (CharacterMod.RGB.Speed == sp.val) and Color3.fromRGB(150, 60, 220) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = RgbSpeedFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.RGB.Speed = sp.val
        for _, b in ipairs(RgbSpeedFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(150, 60, 220)
    end)
end

local RgbStyleTitle = Instance.new("TextLabel")
RgbStyleTitle.Size = UDim2.new(1, 0, 0, 18); RgbStyleTitle.BackgroundTransparency = 1
RgbStyleTitle.Text = "✨ รูปแบบวัสดุ RGB:"; RgbStyleTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
RgbStyleTitle.Font = Enum.Font.Gotham; RgbStyleTitle.TextSize = 11; RgbStyleTitle.TextXAlignment = Enum.TextXAlignment.Left
RgbStyleTitle.LayoutOrder = 5; RgbStyleTitle.Parent = ContentChar

local RgbStyleFrame = Instance.new("Frame")
RgbStyleFrame.Size = UDim2.new(1, 0, 0, 30); RgbStyleFrame.BackgroundTransparency = 1; RgbStyleFrame.LayoutOrder = 6; RgbStyleFrame.Parent = ContentChar
local rgbStLayout = Instance.new("UIGridLayout"); rgbStLayout.CellSize = UDim2.new(0.485, 0, 1, 0); rgbStLayout.CellPadding = UDim2.new(0.03, 0, 0, 0); rgbStLayout.Parent = RgbStyleFrame

local rgbStyles = {
    {name="💡 Neon (เรืองแสงนีออน)", val="Neon"},
    {name="🎨 Smooth (สีรุ้งเนียนตา)", val="SmoothPlastic"}
}
for _, st in ipairs(rgbStyles) do
    local btn = Instance.new("TextButton")
    btn.Text = st.name; btn.BackgroundColor3 = (CharacterMod.RGB.Style == st.val) and Color3.fromRGB(150, 60, 220) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 11; btn.Parent = RgbStyleFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.RGB.Style = st.val
        for _, b in ipairs(RgbStyleFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(150, 60, 220)
    end)
end

local RgbSpreadTitle = Instance.new("TextLabel")
RgbSpreadTitle.Size = UDim2.new(1, 0, 0, 18); RgbSpreadTitle.BackgroundTransparency = 1
RgbSpreadTitle.Text = "🌊 การกระจายสีตามร่างกาย:"; RgbSpreadTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
RgbSpreadTitle.Font = Enum.Font.Gotham; RgbSpreadTitle.TextSize = 11; RgbSpreadTitle.TextXAlignment = Enum.TextXAlignment.Left
RgbSpreadTitle.LayoutOrder = 7; RgbSpreadTitle.Parent = ContentChar

local RgbSpreadFrame = Instance.new("Frame")
RgbSpreadFrame.Size = UDim2.new(1, 0, 0, 30); RgbSpreadFrame.BackgroundTransparency = 1; RgbSpreadFrame.LayoutOrder = 8; RgbSpreadFrame.Parent = ContentChar
local rgbSpdLayout = Instance.new("UIGridLayout"); rgbSpdLayout.CellSize = UDim2.new(0.485, 0, 1, 0); rgbSpdLayout.CellPadding = UDim2.new(0.03, 0, 0, 0); rgbSpdLayout.Parent = RgbSpreadFrame

local rgbSpreads = {
    {name="🌊 คลื่นสีรุ้ง (Wave Gradient)", val=true},
    {name="🎯 สีเดียวทั้งตัว (Uniform)", val=false}
}
for _, spd in ipairs(rgbSpreads) do
    local btn = Instance.new("TextButton")
    btn.Text = spd.name; btn.BackgroundColor3 = (CharacterMod.RGB.WaveSpread == spd.val) and Color3.fromRGB(150, 60, 220) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = RgbSpreadFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.RGB.WaveSpread = spd.val
        for _, b in ipairs(RgbSpreadFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(150, 60, 220)
    end)
end
end -- End Section 1: RGB Mode

-- ==================== SECTION 2: GHOST MODE ====================
do
    createCharSectionTitle("👻 Ghost Mode พรีเมียม (ออร่าเรืองแสง + หมอกวิญญาณ)", 9, Color3.fromRGB(120, 230, 255))

    local GhostToggleBtn = Instance.new("TextButton")
GhostToggleBtn.Size = UDim2.new(1, 0, 0, 36)
GhostToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
GhostToggleBtn.Text = "🔴 ปิด Ghost Mode อยู่ (คลิกเพื่อเปิด)"
GhostToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GhostToggleBtn.Font = Enum.Font.GothamBold
GhostToggleBtn.TextSize = 12
GhostToggleBtn.LayoutOrder = 10
GhostToggleBtn.Parent = ContentChar
local cGhostTog = Instance.new("UICorner"); cGhostTog.CornerRadius = UDim.new(0, 8); cGhostTog.Parent = GhostToggleBtn

GhostToggleBtn.MouseButton1Click:Connect(function()
    CharacterMod.Ghost.Enabled = not CharacterMod.Ghost.Enabled
    if CharacterMod.Ghost.Enabled then
        GhostToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        GhostToggleBtn.Text = "🟢 เปิด Ghost Mode พรีเมียมอยู่ (คลิกเพื่อปิด)"
    else
        GhostToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
        GhostToggleBtn.Text = "🔴 ปิด Ghost Mode อยู่ (คลิกเพื่อเปิด)"
    end
    applyGhostMode(LocalPlayer.Character)
end)

local GhostThemeTitle = Instance.new("TextLabel")
GhostThemeTitle.Size = UDim2.new(1, 0, 0, 18); GhostThemeTitle.BackgroundTransparency = 1
GhostThemeTitle.Text = "🎨 ธีมสีวิญญาณ + Highlight เรืองแสง:"; GhostThemeTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
GhostThemeTitle.Font = Enum.Font.Gotham; GhostThemeTitle.TextSize = 11; GhostThemeTitle.TextXAlignment = Enum.TextXAlignment.Left
GhostThemeTitle.LayoutOrder = 11; GhostThemeTitle.Parent = ContentChar

local GhostThemeFrame = Instance.new("Frame")
GhostThemeFrame.Size = UDim2.new(1, 0, 0, 108); GhostThemeFrame.BackgroundTransparency = 1; GhostThemeFrame.LayoutOrder = 12; GhostThemeFrame.Parent = ContentChar
local ghThLayout = Instance.new("UIGridLayout"); ghThLayout.CellSize = UDim2.new(0.31, 0, 0, 32); ghThLayout.CellPadding = UDim2.new(0.035, 0, 0, 6); ghThLayout.Parent = GhostThemeFrame

local ghostThemesList = {
    {key="Cyan", name="👻 ฟ้าวิญญาณ"},
    {key="Violet", name="🔮 ม่วงภูติ"},
    {key="White", name="✨ ขาวบริสุทธิ์"},
    {key="Gold", name="👑 ทองคำศักดิ์สิทธิ์"},
    {key="Crimson", name="🩸 โลหิตปีศาจ"},
    {key="Rainbow", name="🌈 วิญญาณสีรุ้ง"},
    {key="Ambience", name="🌌 ซิงค์หมอกฟ้า"}
}

for _, gt in ipairs(ghostThemesList) do
    local btn = Instance.new("TextButton")
    btn.Text = gt.name; btn.BackgroundColor3 = (CharacterMod.Ghost.Theme == gt.key) and Color3.fromRGB(30, 160, 210) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = GhostThemeFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Ghost.Theme = gt.key
        for _, b in ipairs(GhostThemeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        if CharacterMod.Ghost.Enabled then
            applyGhostMode(LocalPlayer.Character)
        end
    end)
end

local GhostMatTitle = Instance.new("TextLabel")
GhostMatTitle.Size = UDim2.new(1, 0, 0, 18); GhostMatTitle.BackgroundTransparency = 1
GhostMatTitle.Text = "💎 เนื้อสัมผัสวิญญาณ (Material):"; GhostMatTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
GhostMatTitle.Font = Enum.Font.Gotham; GhostMatTitle.TextSize = 11; GhostMatTitle.TextXAlignment = Enum.TextXAlignment.Left
GhostMatTitle.LayoutOrder = 13; GhostMatTitle.Parent = ContentChar

local GhostMatFrame = Instance.new("Frame")
GhostMatFrame.Size = UDim2.new(1, 0, 0, 30); GhostMatFrame.BackgroundTransparency = 1; GhostMatFrame.LayoutOrder = 14; GhostMatFrame.Parent = ContentChar
local ghMatLayout = Instance.new("UIGridLayout"); ghMatLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ghMatLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ghMatLayout.Parent = GhostMatFrame

local ghostMats = {
    {name="ForceField", val="ForceField"},
    {name="SmoothPlastic", val="SmoothPlastic"},
    {name="Glass แก้ว", val="Glass"}
}
for _, gm in ipairs(ghostMats) do
    local btn = Instance.new("TextButton")
    btn.Text = gm.name; btn.BackgroundColor3 = (CharacterMod.Ghost.Material == gm.val) and Color3.fromRGB(30, 160, 210) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = GhostMatFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Ghost.Material = gm.val
        for _, b in ipairs(GhostMatFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        if CharacterMod.Ghost.Enabled then
            applyGhostMode(LocalPlayer.Character)
        end
    end)
end

local GhostTransTitle = Instance.new("TextLabel")
GhostTransTitle.Size = UDim2.new(1, 0, 0, 18); GhostTransTitle.BackgroundTransparency = 1
GhostTransTitle.Text = "👁️ ระดับความโปร่งใสตัวละคร:"; GhostTransTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
GhostTransTitle.Font = Enum.Font.Gotham; GhostTransTitle.TextSize = 11; GhostTransTitle.TextXAlignment = Enum.TextXAlignment.Left
GhostTransTitle.LayoutOrder = 15; GhostTransTitle.Parent = ContentChar

local GhostTransFrame = Instance.new("Frame")
GhostTransFrame.Size = UDim2.new(1, 0, 0, 30); GhostTransFrame.BackgroundTransparency = 1; GhostTransFrame.LayoutOrder = 16; GhostTransFrame.Parent = ContentChar
local ghTrLayout = Instance.new("UIGridLayout"); ghTrLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ghTrLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ghTrLayout.Parent = GhostTransFrame

local ghostTransList = {
    {name="50% ชัดเจน", val=0.50},
    {name="68% สมดุล (แนะนำ)", val=0.68},
    {name="85% วิญญาณรางๆ", val=0.85}
}
for _, gt in ipairs(ghostTransList) do
    local btn = Instance.new("TextButton")
    btn.Text = gt.name; btn.BackgroundColor3 = (CharacterMod.Ghost.BodyTransparency == gt.val) and Color3.fromRGB(30, 160, 210) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9; btn.Parent = GhostTransFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Ghost.BodyTransparency = gt.val
        for _, b in ipairs(GhostTransFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        if CharacterMod.Ghost.Enabled then
            applyGhostMode(LocalPlayer.Character)
        end
    end)
end

local GhostWispsTitle = Instance.new("TextLabel")
GhostWispsTitle.Size = UDim2.new(1, 0, 0, 18); GhostWispsTitle.BackgroundTransparency = 1
GhostWispsTitle.Text = "🌫️ ละอองวิญญาณลอยรอบตัว (Soul Wisps):"; GhostWispsTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
GhostWispsTitle.Font = Enum.Font.Gotham; GhostWispsTitle.TextSize = 11; GhostWispsTitle.TextXAlignment = Enum.TextXAlignment.Left
GhostWispsTitle.LayoutOrder = 17; GhostWispsTitle.Parent = ContentChar

local GhostWispsFrame = Instance.new("Frame")
GhostWispsFrame.Size = UDim2.new(1, 0, 0, 30); GhostWispsFrame.BackgroundTransparency = 1; GhostWispsFrame.LayoutOrder = 18; GhostWispsFrame.Parent = ContentChar
local ghWsLayout = Instance.new("UIGridLayout"); ghWsLayout.CellSize = UDim2.new(0.485, 0, 1, 0); ghWsLayout.CellPadding = UDim2.new(0.03, 0, 0, 0); ghWsLayout.Parent = GhostWispsFrame

local ghostWispsOptions = {
    {name="✨ เปิดละออง Wisps", val=true},
    {name="❌ ปิดละออง Wisps", val=false}
}
for _, gwo in ipairs(ghostWispsOptions) do
    local btn = Instance.new("TextButton")
    btn.Text = gwo.name; btn.BackgroundColor3 = (CharacterMod.Ghost.Wisps == gwo.val) and Color3.fromRGB(30, 160, 210) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = GhostWispsFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Ghost.Wisps = gwo.val
        for _, b in ipairs(GhostWispsFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        if CharacterMod.Ghost.Enabled then
            applyGhostMode(LocalPlayer.Character)
        end
    end)
end

local GhostOutlineTitle = Instance.new("TextLabel")
GhostOutlineTitle.Size = UDim2.new(1, 0, 0, 18); GhostOutlineTitle.BackgroundTransparency = 1
GhostOutlineTitle.Text = "✨ ความชัดของเส้นขอบออร่า:"; GhostOutlineTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
GhostOutlineTitle.Font = Enum.Font.Gotham; GhostOutlineTitle.TextSize = 11; GhostOutlineTitle.TextXAlignment = Enum.TextXAlignment.Left
GhostOutlineTitle.LayoutOrder = 19; GhostOutlineTitle.Parent = ContentChar

local GhostOutlineFrame = Instance.new("Frame")
GhostOutlineFrame.Size = UDim2.new(1, 0, 0, 30); GhostOutlineFrame.BackgroundTransparency = 1; GhostOutlineFrame.LayoutOrder = 20; GhostOutlineFrame.Parent = ContentChar
local ghOtLayout = Instance.new("UIGridLayout"); ghOtLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ghOtLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ghOtLayout.Parent = GhostOutlineFrame

local ghostOutlineOptions = {
    {name="ฟุ้งเนียนไร้ขอบ", val=0.90},
    {name="นวลตา (แนะนำ)", val=0.75},
    {name="เห็นขอบจางๆ", val=0.55}
}
for _, goo in ipairs(ghostOutlineOptions) do
    local btn = Instance.new("TextButton")
    btn.Text = goo.name; btn.BackgroundColor3 = (CharacterMod.Ghost.OutlineTransparency == goo.val) and Color3.fromRGB(30, 160, 210) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9; btn.Parent = GhostOutlineFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Ghost.OutlineTransparency = goo.val
        for _, b in ipairs(GhostOutlineFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(30, 160, 210)
        if GhostHighlight and GhostHighlight.Parent then
            GhostHighlight.OutlineTransparency = goo.val
        end
    end)
end
end -- End Section 2: Ghost Mode

-- ==================== SECTION 3: PARTICLE AURA MENU ====================
do
    createCharSectionTitle("✨ Particle Aura ประจำตัวละคร (ปรับได้หลายตัวเลือก)", 21, Color3.fromRGB(255, 215, 120))

    local ParticleToggleBtn = Instance.new("TextButton")
ParticleToggleBtn.Size = UDim2.new(1, 0, 0, 36)
ParticleToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
ParticleToggleBtn.Text = "🔴 ปิด Aura Particle อยู่ (คลิกเพื่อเปิด)"
ParticleToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ParticleToggleBtn.Font = Enum.Font.GothamBold
ParticleToggleBtn.TextSize = 12
ParticleToggleBtn.LayoutOrder = 22
ParticleToggleBtn.Parent = ContentChar
local cPartTog = Instance.new("UICorner"); cPartTog.CornerRadius = UDim.new(0, 8); cPartTog.Parent = ParticleToggleBtn

ParticleToggleBtn.MouseButton1Click:Connect(function()
    CharacterMod.Particle.Enabled = not CharacterMod.Particle.Enabled
    if CharacterMod.Particle.Enabled then
        ParticleToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        ParticleToggleBtn.Text = "🟢 เปิด Aura Particle อยู่ (คลิกเพื่อปิด)"
    else
        ParticleToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
        ParticleToggleBtn.Text = "🔴 ปิด Aura Particle อยู่ (คลิกเพื่อเปิด)"
    end
    applyCharacterParticle(LocalPlayer.Character)
end)

local PartPresetTitle = Instance.new("TextLabel")
PartPresetTitle.Size = UDim2.new(1, 0, 0, 18); PartPresetTitle.BackgroundTransparency = 1
PartPresetTitle.Text = "🔮 เลือกสไตล์เอฟเฟกต์ (8 สไตล์):"; PartPresetTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartPresetTitle.Font = Enum.Font.Gotham; PartPresetTitle.TextSize = 11; PartPresetTitle.TextXAlignment = Enum.TextXAlignment.Left
PartPresetTitle.LayoutOrder = 23; PartPresetTitle.Parent = ContentChar

local PartPresetFrame = Instance.new("Frame")
PartPresetFrame.Size = UDim2.new(1, 0, 0, 130); PartPresetFrame.BackgroundTransparency = 1; PartPresetFrame.LayoutOrder = 24; PartPresetFrame.Parent = ContentChar
local ptPrLayout = Instance.new("UIGridLayout"); ptPrLayout.CellSize = UDim2.new(0.485, 0, 0, 28); ptPrLayout.CellPadding = UDim2.new(0.03, 0, 0, 6); ptPrLayout.Parent = PartPresetFrame

local particlePresetsList = {
    {key="SoulWisps", name="👻 Soul Wisps"},
    {key="Starlight", name="✨ Starlight Nova"},
    {key="Electric", name="⚡ Electric Surge"},
    {key="Sakura", name="🌸 Sakura Drift"},
    {key="VoidFlame", name="🔥 Void Flames"},
    {key="Cyber", name="🟩 Cyber Matrix"},
    {key="DivineGold", name="👑 Divine Radiance"},
    {key="CrimsonMist", name="🩸 Crimson Mist"}
}

for _, pp in ipairs(particlePresetsList) do
    local btn = Instance.new("TextButton")
    btn.Text = pp.name; btn.BackgroundColor3 = (CharacterMod.Particle.Preset == pp.key) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = PartPresetFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.Preset = pp.key
        for _, b in ipairs(PartPresetFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end

local PartColorTitle = Instance.new("TextLabel")
PartColorTitle.Size = UDim2.new(1, 0, 0, 18); PartColorTitle.BackgroundTransparency = 1
PartColorTitle.Text = "🎨 โหมดสีของ Particle:"; PartColorTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartColorTitle.Font = Enum.Font.Gotham; PartColorTitle.TextSize = 11; PartColorTitle.TextXAlignment = Enum.TextXAlignment.Left
PartColorTitle.LayoutOrder = 25; PartColorTitle.Parent = ContentChar

local PartColorFrame = Instance.new("Frame")
PartColorFrame.Size = UDim2.new(1, 0, 0, 30); PartColorFrame.BackgroundTransparency = 1; PartColorFrame.LayoutOrder = 26; PartColorFrame.Parent = ContentChar
local ptColLayout = Instance.new("UIGridLayout"); ptColLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ptColLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ptColLayout.Parent = PartColorFrame

local partColorModes = {
    {name="ธีมเดิม (Preset)", val="Preset"},
    {name="ซิงค์หมอกฟ้า", val="SyncAmbience"},
    {name="หมุนสีรุ้ง (RGB)", val="Rainbow"}
}
for _, pcm in ipairs(partColorModes) do
    local btn = Instance.new("TextButton")
    btn.Text = pcm.name; btn.BackgroundColor3 = (CharacterMod.Particle.ColorMode == pcm.val) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = PartColorFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.ColorMode = pcm.val
        for _, b in ipairs(PartColorFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end

local PartSizeTitle = Instance.new("TextLabel")
PartSizeTitle.Size = UDim2.new(1, 0, 0, 18); PartSizeTitle.BackgroundTransparency = 1
PartSizeTitle.Text = "📏 ขนาดเม็ด Particle:"; PartSizeTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartSizeTitle.Font = Enum.Font.Gotham; PartSizeTitle.TextSize = 11; PartSizeTitle.TextXAlignment = Enum.TextXAlignment.Left
PartSizeTitle.LayoutOrder = 27; PartSizeTitle.Parent = ContentChar

local PartSizeFrame = Instance.new("Frame")
PartSizeFrame.Size = UDim2.new(1, 0, 0, 30); PartSizeFrame.BackgroundTransparency = 1; PartSizeFrame.LayoutOrder = 28; PartSizeFrame.Parent = ContentChar
local ptSzLayout = Instance.new("UIGridLayout"); ptSzLayout.CellSize = UDim2.new(0.23, 0, 1, 0); ptSzLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); ptSzLayout.Parent = PartSizeFrame

local partSizes = {
    {name="0.6x เล็ก", val=0.6},
    {name="1.0x ปกติ", val=1.0},
    {name="1.8x ใหญ่", val=1.8},
    {name="2.8x อลังการ", val=2.8}
}
for _, ps in ipairs(partSizes) do
    local btn = Instance.new("TextButton")
    btn.Text = ps.name; btn.BackgroundColor3 = (CharacterMod.Particle.SizeScale == ps.val) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = PartSizeFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.SizeScale = ps.val
        for _, b in ipairs(PartSizeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end

local PartRateTitle = Instance.new("TextLabel")
PartRateTitle.Size = UDim2.new(1, 0, 0, 18); PartRateTitle.BackgroundTransparency = 1
PartRateTitle.Text = "🌪️ ความหนาแน่น (Rate):"; PartRateTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartRateTitle.Font = Enum.Font.Gotham; PartRateTitle.TextSize = 11; PartRateTitle.TextXAlignment = Enum.TextXAlignment.Left
PartRateTitle.LayoutOrder = 29; PartRateTitle.Parent = ContentChar

local PartRateFrame = Instance.new("Frame")
PartRateFrame.Size = UDim2.new(1, 0, 0, 30); PartRateFrame.BackgroundTransparency = 1; PartRateFrame.LayoutOrder = 30; PartRateFrame.Parent = ContentChar
local ptRtLayout = Instance.new("UIGridLayout"); ptRtLayout.CellSize = UDim2.new(0.23, 0, 1, 0); ptRtLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); ptRtLayout.Parent = PartRateFrame

local partRates = {
    {name="0.5x บางเบา", val=0.5},
    {name="1.0x ปกติ", val=1.0},
    {name="2.0x หนาแน่น", val=2.0},
    {name="3.5x พายุคลั่ง", val=3.5}
}
for _, pr in ipairs(partRates) do
    local btn = Instance.new("TextButton")
    btn.Text = pr.name; btn.BackgroundColor3 = (CharacterMod.Particle.RateScale == pr.val) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9; btn.Parent = PartRateFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.RateScale = pr.val
        for _, b in ipairs(PartRateFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end

local PartSpeedTitle = Instance.new("TextLabel")
PartSpeedTitle.Size = UDim2.new(1, 0, 0, 18); PartSpeedTitle.BackgroundTransparency = 1
PartSpeedTitle.Text = "💨 ความเร็วการลอยพุ่ง (Speed):"; PartSpeedTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartSpeedTitle.Font = Enum.Font.Gotham; PartSpeedTitle.TextSize = 11; PartSpeedTitle.TextXAlignment = Enum.TextXAlignment.Left
PartSpeedTitle.LayoutOrder = 31; PartSpeedTitle.Parent = ContentChar

local PartSpeedFrame = Instance.new("Frame")
PartSpeedFrame.Size = UDim2.new(1, 0, 0, 30); PartSpeedFrame.BackgroundTransparency = 1; PartSpeedFrame.LayoutOrder = 32; PartSpeedFrame.Parent = ContentChar
local ptSpLayout = Instance.new("UIGridLayout"); ptSpLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ptSpLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ptSpLayout.Parent = PartSpeedFrame

local partSpeeds = {
    {name="0.5x ลอยช้า", val=0.5},
    {name="1.0x ปกติ", val=1.0},
    {name="2.0x พุ่งแรง", val=2.0}
}
for _, ps in ipairs(partSpeeds) do
    local btn = Instance.new("TextButton")
    btn.Text = ps.name; btn.BackgroundColor3 = (CharacterMod.Particle.SpeedScale == ps.val) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = PartSpeedFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.SpeedScale = ps.val
        for _, b in ipairs(PartSpeedFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
        btn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end
end -- End Section 3 Basic Controls

-- ==================== PARTICLE POSITION CONTROLS ====================
do
    local PartPosTitle = Instance.new("TextLabel")
PartPosTitle.Size = UDim2.new(1, 0, 0, 18); PartPosTitle.BackgroundTransparency = 1
PartPosTitle.Text = "📍 ตำแหน่งจุดปล่อย Particle (Anchor Presets):"; PartPosTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartPosTitle.Font = Enum.Font.Gotham; PartPosTitle.TextSize = 11; PartPosTitle.TextXAlignment = Enum.TextXAlignment.Left
PartPosTitle.LayoutOrder = 33; PartPosTitle.Parent = ContentChar

local PartPosPresetFrame = Instance.new("Frame")
PartPosPresetFrame.Size = UDim2.new(1, 0, 0, 30); PartPosPresetFrame.BackgroundTransparency = 1; PartPosPresetFrame.LayoutOrder = 34; PartPosPresetFrame.Parent = ContentChar
local ptPosLayout = Instance.new("UIGridLayout"); ptPosLayout.CellSize = UDim2.new(0.23, 0, 1, 0); ptPosLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); ptPosLayout.Parent = PartPosPresetFrame

local PartHeightTitle = Instance.new("TextLabel")
PartHeightTitle.Size = UDim2.new(1, 0, 0, 18); PartHeightTitle.BackgroundTransparency = 1
PartHeightTitle.Text = "📐 ปรับระดับความสูงละเอียด (Height Offset Y):"; PartHeightTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartHeightTitle.Font = Enum.Font.Gotham; PartHeightTitle.TextSize = 11; PartHeightTitle.TextXAlignment = Enum.TextXAlignment.Left
PartHeightTitle.LayoutOrder = 35; PartHeightTitle.Parent = ContentChar

local PartHeightFrame = Instance.new("Frame")
PartHeightFrame.Size = UDim2.new(1, 0, 0, 30); PartHeightFrame.BackgroundTransparency = 1; PartHeightFrame.LayoutOrder = 36; PartHeightFrame.Parent = ContentChar

local DownBtn = Instance.new("TextButton")
DownBtn.Size = UDim2.new(0.28, 0, 1, 0); DownBtn.Position = UDim2.new(0, 0, 0, 0)
DownBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42); DownBtn.Text = "⬇️ ต่ำลง (-0.5m)"
DownBtn.TextColor3 = Color3.fromRGB(240, 240, 240); DownBtn.Font = Enum.Font.Gotham; DownBtn.TextSize = 9.5; DownBtn.Parent = PartHeightFrame
local cDown = Instance.new("UICorner"); cDown.CornerRadius = UDim.new(0, 6); cDown.Parent = DownBtn

local ValBtn = Instance.new("TextButton")
ValBtn.Size = UDim2.new(0.40, 0, 1, 0); ValBtn.Position = UDim2.new(0.30, 0, 0, 0)
ValBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 58); ValBtn.Text = "ความสูง Y: -0.5m (รีเซ็ต)"
ValBtn.TextColor3 = Color3.fromRGB(255, 210, 120); ValBtn.Font = Enum.Font.GothamBold; ValBtn.TextSize = 9.5; ValBtn.Parent = PartHeightFrame
local cVal = Instance.new("UICorner"); cVal.CornerRadius = UDim.new(0, 6); cVal.Parent = ValBtn

local UpBtn = Instance.new("TextButton")
UpBtn.Size = UDim2.new(0.28, 0, 1, 0); UpBtn.Position = UDim2.new(0.72, 0, 0, 0)
UpBtn.BackgroundColor3 = Color3.fromRGB(32, 34, 42); UpBtn.Text = "⬆️ สูงขึ้น (+0.5m)"
UpBtn.TextColor3 = Color3.fromRGB(240, 240, 240); UpBtn.Font = Enum.Font.Gotham; UpBtn.TextSize = 9.5; UpBtn.Parent = PartHeightFrame
local cUp = Instance.new("UICorner"); cUp.CornerRadius = UDim.new(0, 6); cUp.Parent = UpBtn

local PartDepthTitle = Instance.new("TextLabel")
PartDepthTitle.Size = UDim2.new(1, 0, 0, 18); PartDepthTitle.BackgroundTransparency = 1
PartDepthTitle.Text = "↔️ ปรับระยะ หน้า - หลัง (Depth Offset Z):"; PartDepthTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
PartDepthTitle.Font = Enum.Font.Gotham; PartDepthTitle.TextSize = 11; PartDepthTitle.TextXAlignment = Enum.TextXAlignment.Left
PartDepthTitle.LayoutOrder = 37; PartDepthTitle.Parent = ContentChar

local PartDepthFrame = Instance.new("Frame")
PartDepthFrame.Size = UDim2.new(1, 0, 0, 30); PartDepthFrame.BackgroundTransparency = 1; PartDepthFrame.LayoutOrder = 38; PartDepthFrame.Parent = ContentChar
local ptDpLayout = Instance.new("UIGridLayout"); ptDpLayout.CellSize = UDim2.new(0.31, 0, 1, 0); ptDpLayout.CellPadding = UDim2.new(0.035, 0, 0, 0); ptDpLayout.Parent = PartDepthFrame

local function syncParticlePositionUI()
    local x = CharacterMod.Particle.OffsetX or 0
    local y = CharacterMod.Particle.OffsetY or -0.5
    local z = CharacterMod.Particle.OffsetZ or 0
    if CharAuraAttachment and CharAuraAttachment.Parent then
        CharAuraAttachment.Position = Vector3.new(x, y, z)
    end
    ValBtn.Text = string.format("Y: %.1fm (กดรีเซ็ต)", y)

    for _, b in ipairs(PartPosPresetFrame:GetChildren()) do
        if b:IsA("TextButton") then
            if b:GetAttribute("PresetVal") == CharacterMod.Particle.PositionPreset then
                b.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
            else
                b.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
            end
        end
    end

    for _, b in ipairs(PartDepthFrame:GetChildren()) do
        if b:IsA("TextButton") then
            local targetZ = b:GetAttribute("DepthVal")
            if targetZ and math.abs(targetZ - z) < 0.05 then
                b.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
            else
                b.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
            end
        end
    end
end

local partPositions = {
    {name="🦶 ใต้เท้า", val="Feet", x=0, y=-2.6, z=0},
    {name="🧍 กลางตัว", val="Center", x=0, y=-0.5, z=0},
    {name="👑 เหนือหัว", val="Head", x=0, y=2.3, z=0},
    {name="🦋 ด้านหลัง", val="Back", x=0, y=0.2, z=1.3}
}
for _, pp in ipairs(partPositions) do
    local btn = Instance.new("TextButton")
    btn.Text = pp.name
    btn:SetAttribute("PresetVal", pp.val)
    btn.BackgroundColor3 = (CharacterMod.Particle.PositionPreset == pp.val) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = PartPosPresetFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.PositionPreset = pp.val
        CharacterMod.Particle.OffsetX = pp.x
        CharacterMod.Particle.OffsetY = pp.y
        CharacterMod.Particle.OffsetZ = pp.z
        syncParticlePositionUI()
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end

DownBtn.MouseButton1Click:Connect(function()
    CharacterMod.Particle.PositionPreset = "Custom"
    local curY = CharacterMod.Particle.OffsetY or -0.5
    CharacterMod.Particle.OffsetY = math.clamp(math.floor((curY - 0.5) * 10 + 0.5) / 10, -5, 6)
    syncParticlePositionUI()
end)

UpBtn.MouseButton1Click:Connect(function()
    CharacterMod.Particle.PositionPreset = "Custom"
    local curY = CharacterMod.Particle.OffsetY or -0.5
    CharacterMod.Particle.OffsetY = math.clamp(math.floor((curY + 0.5) * 10 + 0.5) / 10, -5, 6)
    syncParticlePositionUI()
end)

ValBtn.MouseButton1Click:Connect(function()
    CharacterMod.Particle.PositionPreset = "Center"
    CharacterMod.Particle.OffsetX = 0
    CharacterMod.Particle.OffsetY = -0.5
    CharacterMod.Particle.OffsetZ = 0
    syncParticlePositionUI()
end)

local partDepths = {
    {name="⬅️ ด้านหน้า (-1.0m)", val=-1.0},
    {name="🎯 กลางตัว (0.0m)", val=0.0},
    {name="➡️ ด้านหลัง (+1.2m)", val=1.2}
}
for _, pd in ipairs(partDepths) do
    local btn = Instance.new("TextButton")
    btn.Text = pd.name
    btn:SetAttribute("DepthVal", pd.val)
    btn.BackgroundColor3 = (math.abs((CharacterMod.Particle.OffsetZ or 0) - pd.val) < 0.05) and Color3.fromRGB(220, 140, 30) or Color3.fromRGB(32, 34, 42)
    btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9.5; btn.Parent = PartDepthFrame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        CharacterMod.Particle.OffsetZ = pd.val
        if CharacterMod.Particle.PositionPreset ~= "Back" and pd.val ~= 0 then
            CharacterMod.Particle.PositionPreset = "Custom"
        end
        syncParticlePositionUI()
        if CharacterMod.Particle.Enabled then
            applyCharacterParticle(LocalPlayer.Character)
        end
    end)
end
end -- End Particle Position Controls

-- ==================== SECTION 4: JUMP PARTICLE RING ====================
do
    createCharSectionTitle("👟 วงกลม Particle รอบเท้า (ตอนกระโดดเท่านั้น)", 40, Color3.fromRGB(130, 240, 190))

    local JumpToggleBtn = Instance.new("TextButton")
    JumpToggleBtn.Size = UDim2.new(1, 0, 0, 36)
    JumpToggleBtn.BackgroundColor3 = CharacterMod.JumpRing.Enabled and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(50, 52, 64)
    JumpToggleBtn.Text = CharacterMod.JumpRing.Enabled and "🟢 เปิด วงกลมรอบเท้าตอนกระโดดอยู่ (คลิกเพื่อปิด)" or "🔴 ปิด วงกลมรอบเท้าตอนกระโดด (คลิกเพื่อเปิด)"
    JumpToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    JumpToggleBtn.Font = Enum.Font.GothamBold
    JumpToggleBtn.TextSize = 12
    JumpToggleBtn.LayoutOrder = 41
    JumpToggleBtn.Parent = ContentChar
    local cJumpTog = Instance.new("UICorner"); cJumpTog.CornerRadius = UDim.new(0, 8); cJumpTog.Parent = JumpToggleBtn

    JumpToggleBtn.MouseButton1Click:Connect(function()
        CharacterMod.JumpRing.Enabled = not CharacterMod.JumpRing.Enabled
        if CharacterMod.JumpRing.Enabled then
            JumpToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
            JumpToggleBtn.Text = "🟢 เปิด วงกลมรอบเท้าตอนกระโดดอยู่ (คลิกเพื่อปิด)"
        else
            JumpToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
            JumpToggleBtn.Text = "🔴 ปิด วงกลมรอบเท้าตอนกระโดด (คลิกเพื่อเปิด)"
        end
    end)

    local JumpColTitle = Instance.new("TextLabel")
    JumpColTitle.Size = UDim2.new(1, 0, 0, 18); JumpColTitle.BackgroundTransparency = 1
    JumpColTitle.Text = "🎨 สีเอฟเฟกต์วงกลมกระโดด:"; JumpColTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
    JumpColTitle.Font = Enum.Font.Gotham; JumpColTitle.TextSize = 11; JumpColTitle.TextXAlignment = Enum.TextXAlignment.Left
    JumpColTitle.LayoutOrder = 42; JumpColTitle.Parent = ContentChar

    local JumpColFrame = Instance.new("Frame")
    JumpColFrame.Size = UDim2.new(1, 0, 0, 72); JumpColFrame.BackgroundTransparency = 1; JumpColFrame.LayoutOrder = 43; JumpColFrame.Parent = ContentChar
    local jpColLayout = Instance.new("UIGridLayout"); jpColLayout.CellSize = UDim2.new(0.31, 0, 0, 32); jpColLayout.CellPadding = UDim2.new(0.035, 0, 0, 6); jpColLayout.Parent = JumpColFrame

    local jumpColors = {
        {name="⚡ ซิงค์อัตโนมัติ", val="Auto"},
        {name="🌈 หมุนสีรุ้ง (RGB)", val="Rainbow"},
        {name="🌌 ซิงค์หมอกฟ้า", val="SyncAmbience"},
        {name="👻 ฟ้าวิญญาณ", val="Cyan"},
        {name="👑 ทองคำ", val="Gold"},
        {name="✨ ขาวบริสุทธิ์", val="White"}
    }
    for _, jc in ipairs(jumpColors) do
        local btn = Instance.new("TextButton")
        btn.Text = jc.name
        btn.BackgroundColor3 = (CharacterMod.JumpRing.ColorMode == jc.val) and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(32, 34, 42)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = JumpColFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CharacterMod.JumpRing.ColorMode = jc.val
            for _, b in ipairs(JumpColFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
        end)
    end

    local JumpSizeTitle = Instance.new("TextLabel")
    JumpSizeTitle.Size = UDim2.new(1, 0, 0, 18); JumpSizeTitle.BackgroundTransparency = 1
    JumpSizeTitle.Text = "📏 รัศมีวงกลมกระโดด:"; JumpSizeTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
    JumpSizeTitle.Font = Enum.Font.Gotham; JumpSizeTitle.TextSize = 11; JumpSizeTitle.TextXAlignment = Enum.TextXAlignment.Left
    JumpSizeTitle.LayoutOrder = 44; JumpSizeTitle.Parent = ContentChar

    local JumpSizeFrame = Instance.new("Frame")
    JumpSizeFrame.Size = UDim2.new(1, 0, 0, 30); JumpSizeFrame.BackgroundTransparency = 1; JumpSizeFrame.LayoutOrder = 45; JumpSizeFrame.Parent = ContentChar
    local jpSzLayout = Instance.new("UIGridLayout"); jpSzLayout.CellSize = UDim2.new(0.23, 0, 1, 0); jpSzLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); jpSzLayout.Parent = JumpSizeFrame

    local jumpSizes = {
        {name="0.7x เล็ก", val=0.7},
        {name="1.0x ปานกลาง", val=1.0},
        {name="1.5x พอดี (แนะนำ)", val=1.5},
        {name="2.2x กว้างใหญ่", val=2.2}
    }
    for _, js in ipairs(jumpSizes) do
        local btn = Instance.new("TextButton")
        btn.Text = js.name
        btn.BackgroundColor3 = (CharacterMod.JumpRing.Size == js.val) and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(32, 34, 42)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9.5; btn.Parent = JumpSizeFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CharacterMod.JumpRing.Size = js.val
            for _, b in ipairs(JumpSizeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
        end)
    end
end -- End Section 4: Jump Particle Ring

-- ==================== SECTION 5: COMBAT HIT EFFECT (PVP) ====================
do
    createCharSectionTitle("⚔️ เอฟเฟกต์ตอนตีคนอื่น (PvP Hit Effect)", 50, Color3.fromRGB(255, 120, 110))

    local HitToggleBtn = Instance.new("TextButton")
    HitToggleBtn.Size = UDim2.new(1, 0, 0, 36)
    HitToggleBtn.BackgroundColor3 = CharacterMod.HitFX.Enabled and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(50, 52, 64)
    HitToggleBtn.Text = CharacterMod.HitFX.Enabled and "🟢 เปิด เอฟเฟกต์ตอนตีคนอื่นอยู่ (คลิกเพื่อปิด)" or "🔴 ปิด เอฟเฟกต์ตอนตีคนอื่น (คลิกเพื่อเปิด)"
    HitToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    HitToggleBtn.Font = Enum.Font.GothamBold
    HitToggleBtn.TextSize = 12
    HitToggleBtn.LayoutOrder = 51
    HitToggleBtn.Parent = ContentChar
    local cHitTog = Instance.new("UICorner"); cHitTog.CornerRadius = UDim.new(0, 8); cHitTog.Parent = HitToggleBtn

    HitToggleBtn.MouseButton1Click:Connect(function()
        CharacterMod.HitFX.Enabled = not CharacterMod.HitFX.Enabled
        if CharacterMod.HitFX.Enabled then
            HitToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
            HitToggleBtn.Text = "🟢 เปิด เอฟเฟกต์ตอนตีคนอื่นอยู่ (คลิกเพื่อปิด)"
        else
            HitToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
            HitToggleBtn.Text = "🔴 ปิด เอฟเฟกต์ตอนตีคนอื่น (คลิกเพื่อเปิด)"
        end
    end)

    local HitColTitle = Instance.new("TextLabel")
    HitColTitle.Size = UDim2.new(1, 0, 0, 18); HitColTitle.BackgroundTransparency = 1
    HitColTitle.Text = "🎨 สีเอฟเฟกต์การโจมตี:"; HitColTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
    HitColTitle.Font = Enum.Font.Gotham; HitColTitle.TextSize = 11; HitColTitle.TextXAlignment = Enum.TextXAlignment.Left
    HitColTitle.LayoutOrder = 52; HitColTitle.Parent = ContentChar

    local HitColFrame = Instance.new("Frame")
    HitColFrame.Size = UDim2.new(1, 0, 0, 72); HitColFrame.BackgroundTransparency = 1; HitColFrame.LayoutOrder = 53; HitColFrame.Parent = ContentChar
    local hitColLayout = Instance.new("UIGridLayout"); hitColLayout.CellSize = UDim2.new(0.31, 0, 0, 32); hitColLayout.CellPadding = UDim2.new(0.035, 0, 0, 6); hitColLayout.Parent = HitColFrame

    local hitColors = {
        {name="⚡ ซิงค์อัตโนมัติ", val="Auto"},
        {name="🌈 หมุนสีรุ้ง (RGB)", val="Rainbow"},
        {name="🌌 ซิงค์หมอกฟ้า", val="SyncAmbience"},
        {name="🩸 โลหิตปีศาจ", val="Crimson"},
        {name="👑 ทองคำศักดิ์สิทธิ์", val="Gold"},
        {name="👻 ฟ้าวิญญาณ", val="Cyan"}
    }
    for _, hc in ipairs(hitColors) do
        local btn = Instance.new("TextButton")
        btn.Text = hc.name
        btn.BackgroundColor3 = (CharacterMod.HitFX.ColorMode == hc.val) and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(32, 34, 42)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = HitColFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CharacterMod.HitFX.ColorMode = hc.val
            for _, b in ipairs(HitColFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
        end)
    end

    local HitShapeTitle = Instance.new("TextLabel")
    HitShapeTitle.Size = UDim2.new(1, 0, 0, 18); HitShapeTitle.BackgroundTransparency = 1
    HitShapeTitle.Text = "🔯 รูปทรงเอฟเฟกต์การโจมตี (Hit Shape):"; HitShapeTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
    HitShapeTitle.Font = Enum.Font.Gotham; HitShapeTitle.TextSize = 11; HitShapeTitle.TextXAlignment = Enum.TextXAlignment.Left
    HitShapeTitle.LayoutOrder = 54; HitShapeTitle.Parent = ContentChar

    local HitShapeFrame = Instance.new("Frame")
    HitShapeFrame.Size = UDim2.new(1, 0, 0, 72); HitShapeFrame.BackgroundTransparency = 1; HitShapeFrame.LayoutOrder = 55; HitShapeFrame.Parent = ContentChar
    local hitShLayout = Instance.new("UIGridLayout"); hitShLayout.CellSize = UDim2.new(0.485, 0, 0, 32); hitShLayout.CellPadding = UDim2.new(0.03, 0, 0, 6); hitShLayout.Parent = HitShapeFrame

    local hitShapes = {
        {name="⭐ ตราดาว 8 แฉก", val="Star"},
        {name="🔯 ตราเวทย์ 6 แฉก", val="Hexagram"},
        {name="💎 ตราเพชรคมกริบ", val="Diamond"},
        {name="🪐 ตราสุริยัน 12 แฉก", val="Nova"}
    }
    for _, hs in ipairs(hitShapes) do
        local btn = Instance.new("TextButton")
        btn.Text = hs.name
        btn.BackgroundColor3 = (CharacterMod.HitFX.Shape == hs.val) and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(32, 34, 42)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 10; btn.Parent = HitShapeFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CharacterMod.HitFX.Shape = hs.val
            for _, b in ipairs(HitShapeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
        end)
    end

    local HitSizeTitle = Instance.new("TextLabel")
    HitSizeTitle.Size = UDim2.new(1, 0, 0, 18); HitSizeTitle.BackgroundTransparency = 1
    HitSizeTitle.Text = "📏 ขนาดประกายเอฟเฟกต์การโจมตี:"; HitSizeTitle.TextColor3 = Color3.fromRGB(180, 190, 210)
    HitSizeTitle.Font = Enum.Font.Gotham; HitSizeTitle.TextSize = 11; HitSizeTitle.TextXAlignment = Enum.TextXAlignment.Left
    HitSizeTitle.LayoutOrder = 56; HitSizeTitle.Parent = ContentChar

    local HitSizeFrame = Instance.new("Frame")
    HitSizeFrame.Size = UDim2.new(1, 0, 0, 30); HitSizeFrame.BackgroundTransparency = 1; HitSizeFrame.LayoutOrder = 57; HitSizeFrame.Parent = ContentChar
    local hitSzLayout = Instance.new("UIGridLayout"); hitSzLayout.CellSize = UDim2.new(0.23, 0, 1, 0); hitSzLayout.CellPadding = UDim2.new(0.026, 0, 0, 0); hitSzLayout.Parent = HitSizeFrame

    local hitSizes = {
        {name="1.0x ชัดเจน", val=1.0},
        {name="1.5x พอดี (แนะนำ)", val=1.5},
        {name="2.2x ใหญ่สะใจ", val=2.2},
        {name="3.2x อลังการยักษ์", val=3.2}
    }
    for _, hs in ipairs(hitSizes) do
        local btn = Instance.new("TextButton")
        btn.Text = hs.name
        btn.BackgroundColor3 = (CharacterMod.HitFX.Size == hs.val) and Color3.fromRGB(35, 160, 110) or Color3.fromRGB(32, 34, 42)
        btn.TextColor3 = Color3.fromRGB(240, 240, 240); btn.Font = Enum.Font.Gotham; btn.TextSize = 9.5; btn.Parent = HitSizeFrame
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
        btn.MouseButton1Click:Connect(function()
            CharacterMod.HitFX.Size = hs.val
            for _, b in ipairs(HitSizeFrame:GetChildren()) do if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(32, 34, 42) end end
            btn.BackgroundColor3 = Color3.fromRGB(35, 160, 110)
        end)
    end
end -- End Section 5: Combat Hit Effect

_G.AmbienceControllerCleanup = function()
    cleanupCharacterMod()
    if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
    if mainFXConnection then mainFXConnection:Disconnect(); mainFXConnection = nil end
    if customColorCorrection then customColorCorrection:Destroy() end
    if customBloom then customBloom:Destroy() end
    if ParticleFolder then ParticleFolder:Destroy() end
    if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
end

print("[Smooth Mist FX] Loaded Horizon FX & Character Mod System (RGB, Ghost Mode & Particle Aura) successfully!")

