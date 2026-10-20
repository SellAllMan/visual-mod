--[[
    ========================================================================
    VISUALS ENGINE - CONFIGURATION
    File: VisualsEngine/Config.lua
    ========================================================================
--]]

local Config = {
    Global = {
        Enabled = true,
        MenuKey = Enum.KeyCode.RightShift,
        QuickToggleKey = Enum.KeyCode.V,
        CurrentTheme = "Cyberpunk",
        PoolContainerName = "__VisualEngine_MadiumPool",
    },

    Themes = {
        Cyberpunk = {
            Primary = Color3.fromRGB(0, 255, 204),
            Secondary = Color3.fromRGB(180, 0, 255),
            Accent = Color3.fromRGB(255, 0, 128),
            Background = Color3.fromRGB(12, 14, 24),
            Text = Color3.fromRGB(240, 245, 255),
        },
        Moon = {
            Primary = Color3.fromRGB(65, 145, 255),
            Secondary = Color3.fromRGB(25, 45, 130),
            Accent = Color3.fromRGB(230, 245, 255),
            Background = Color3.fromRGB(8, 12, 22),
            Text = Color3.fromRGB(255, 255, 255),
        },
        Astolfo = {
            Primary = Color3.fromRGB(255, 105, 180),
            Secondary = Color3.fromRGB(200, 75, 255),
            Accent = Color3.fromRGB(130, 240, 255),
            Background = Color3.fromRGB(20, 10, 22),
            Text = Color3.fromRGB(255, 240, 250),
        },
        Exhibition = {
            Primary = Color3.fromRGB(255, 45, 45),
            Secondary = Color3.fromRGB(255, 185, 0),
            Accent = Color3.fromRGB(255, 255, 255),
            Background = Color3.fromRGB(18, 14, 14),
            Text = Color3.fromRGB(255, 255, 255),
        },
        Rainbow = {
            Speed = 0.5,
            Saturation = 1.0,
            Lightness = 0.55,
        }
    },

    Constellation = {
        Enabled = true,
        NodeCount = 26,
        ConnectDistance = 12.0,
        Speed = 1.6,
        Radius = 16.0,
        LineThickness = 0.07,
        MaxConnectionsPerNode = 4,
        NodeSize = 0.22,
        HeightOffset = 3.0,
    },

    BezierFlow = {
        Enabled = true,
        StreamCount = 5,
        Radius = 10.0,
        HeightRange = 7.0,
        Speed = 1.8,
        SegmentsPerStream = 12,
        LineWidth = 0.12,
    },

    AuraShockwave = {
        Enabled = true,
        Interval = 0.9,
        MaxRadius = 13.0,
        Lifetime = 1.1,
        Thickness = 0.12,
        GroundRaycastDistance = 6.0,
    },

    DottedOrbit = {
        Enabled = true,
        DotCount = 30,
        Radius = 6.2,
        Speed = 2.2,
        DotSize = 0.28,
        HeightOffset = 0.5,
        WaveAmplitude = 0.45,
        WaveFrequency = 3.0,
    },

    GyroRings = {
        Enabled = true,
        Radius = 5.2,
        Segments = 28,
        Thickness = 0.08,
        RingAngles = {
            Vector3.new(25, 0, 15),
            Vector3.new(-35, 20, 60),
            Vector3.new(70, -45, 120),
        },
        RotationSpeeds = {
            Vector3.new(0.8, 1.4, 0.3),
            Vector3.new(-1.1, 0.6, 1.2),
            Vector3.new(0.5, -1.5, 0.8),
        },
    },

    PolygonWings = {
        Enabled = true,
        FlapSpeed = 4.2,
        FlapAmplitude = 24.0,
        IdleSpread = 32.0,
        MoveSpreadBoost = 18.0,
        FacetCount = 4,
        FacetThickness = 0.08,
    },

    FlameWings = {
        Enabled = true,
        LightEmission = 1.0,
        TextureSpeed = 1.5,
        WiggleSpeed = 3.5,
        WiggleAmount = 0.8,
        Width = 3.2,
    },

    TargetHUD = {
        Enabled = true,
        MaxLockDistance = 75.0,
        SmoothLerpSpeed = 9.0,
        GhostHpSpeed = 4.0,
        Offset = Vector3.new(0, 3.2, 0),
    },

    InWorldMenu = {
        Enabled = false, -- Default to false in executor, ScreenGui control menu is active by default
        Distance = 4.8,
        CanvasSize = Vector2.new(580, 380),
        SpringStiffness = 180.0,
        SpringDamping = 18.0,
    },

    Ambience = {
        BloomEnabled = true,
        BloomIntensity = 1.05,
        BloomSize = 22,
        BloomThreshold = 2.1,
        ColorCorrectionEnabled = true,
        Contrast = 0.14,
        Saturation = 0.22,
        TintColor = Color3.fromRGB(245, 248, 255),
        ESPEnabled = true,
        ESPRainbow = true,
        ESPRainbowSpeed = 0.6,
        OutlineTransparency = 0.0,
        FillTransparency = 0.72,
    }
}

return Config
