--[[
    ========================================================================
    VISUALS ENGINE - 3D IN-WORLD MENU CANVAS
    File: VisualsEngine/Modules/InWorldMenu.lua
    ========================================================================
--]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")
local MathUtils = import("Core/MathUtils")

local LocalPlayer = Players.LocalPlayer

local InWorldMenu = {}
InWorldMenu.__index = InWorldMenu

function InWorldMenu.new(onToggleModule, onThemeChange)
    local self = setmetatable({}, InWorldMenu)
    self._isOpen = false
    self._onToggleModule = onToggleModule
    self._onThemeChange = onThemeChange

    self._part = nil
    self._surfaceGui = nil
    self._spring = nil
    self._currentCFrame = CFrame.identity
    self._moduleButtons = {}
    self._themeButtons = {}

    return self
end

function InWorldMenu:_buildWorldUI()
    local cfg = Config.InWorldMenu
    local cam = workspace.CurrentCamera or workspace

    local part = Instance.new("Part")
    part.Name = "MadiumInWorldMenuAnchor"
    part.Transparency = 1
    part.CanCollide = false
    part.CanQuery = false
    part.CastShadow = false
    part.Anchored = true
    part.Size = Vector3.new(4.5, 3.0, 0.05)
    part.Parent = cam
    self._part = part

    local targetParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("SurfaceGui")
    gui.Name = "MadiumInWorldMenuGui"
    gui.Face = Enum.NormalId.Back
    gui.CanvasSize = cfg.CanvasSize
    gui.AlwaysOnTop = true
    gui.Active = true
    gui.Adornee = part
    gui.Parent = targetParent
    self._surfaceGui = gui

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
    container.BackgroundTransparency = 0.08
    container.BorderSizePixel = 0
    container.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2.0
    stroke.Color = Color3.fromRGB(0, 255, 204)
    stroke.Parent = container

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 48)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = container

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -24, 1, 0)
    titleLabel.Position = UDim2.fromOffset(20, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "⚡ NEON PROTOCOL // 3D CANVAS"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local leftPanel = Instance.new("ScrollingFrame")
    leftPanel.Name = "ModulesList"
    leftPanel.Size = UDim2.new(0.62, -15, 1, -64)
    leftPanel.Position = UDim2.fromOffset(16, 56)
    leftPanel.BackgroundTransparency = 1
    leftPanel.BorderSizePixel = 0
    leftPanel.ScrollBarThickness = 4
    leftPanel.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 204)
    leftPanel.CanvasSize = UDim2.fromOffset(0, 420)
    leftPanel.Parent = container

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 7)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = leftPanel

    local modules = {
        {"Constellation", "Constellation Grid", Config.Constellation.Enabled},
        {"BezierFlow", "Bézier Vector Flow", Config.BezierFlow.Enabled},
        {"AuraShockwave", "Expanding Shockwaves", Config.AuraShockwave.Enabled},
        {"DottedOrbit", "Dotted Polar Orbit", Config.DottedOrbit.Enabled},
        {"GyroRings", "3-Axis Gyro Rings", Config.GyroRings.Enabled},
        {"PolygonWings", "Polygon Crystal Wings", Config.PolygonWings.Enabled},
        {"FlameWings", "Ethereal Flame Wings", Config.FlameWings.Enabled},
        {"TargetHUD", "Floating Target HUD", Config.TargetHUD.Enabled},
        {"Ambience", "Ambience & ESP Chams", Config.Ambience.BloomEnabled},
    }

    for order, item in ipairs(modules) do
        local modId = item[1]
        local modLabel = item[2]
        local isEnabled = item[3]

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 36)
        row.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = leftPanel

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.65, 0, 1, 0)
        label.Position = UDim2.fromOffset(12, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.Text = modLabel
        label.TextColor3 = Color3.fromRGB(230, 235, 245)
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.fromOffset(72, 24)
        toggleBtn.Position = UDim2.new(1, -82, 0.5, -12)
        toggleBtn.BackgroundColor3 = if isEnabled then Color3.fromRGB(0, 204, 150) else Color3.fromRGB(50, 56, 75)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Text = if isEnabled then "ON" else "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 11
        toggleBtn.Parent = row

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = toggleBtn

        self._moduleButtons[modId] = toggleBtn

        toggleBtn.MouseButton1Click:Connect(function()
            local newState = toggleBtn.Text == "OFF"
            toggleBtn.Text = if newState then "ON" else "OFF"
            toggleBtn.BackgroundColor3 = if newState then Color3.fromRGB(0, 204, 150) else Color3.fromRGB(50, 56, 75)
            self._onToggleModule(modId, newState)
        end)
    end

    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.38, -25, 1, -64)
    rightPanel.Position = UDim2.new(0.62, 8, 0, 56)
    rightPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = container

    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightPanel

    local themeTitle = Instance.new("TextLabel")
    themeTitle.Size = UDim2.new(1, 0, 0, 28)
    themeTitle.Position = UDim2.fromOffset(12, 10)
    themeTitle.BackgroundTransparency = 1
    themeTitle.Font = Enum.Font.GothamBold
    themeTitle.Text = "COLOR THEME"
    themeTitle.TextColor3 = Color3.fromRGB(0, 255, 204)
    themeTitle.TextSize = 13
    themeTitle.TextXAlignment = Enum.TextXAlignment.Left
    themeTitle.Parent = rightPanel

    local themes = {"Cyberpunk", "Moon", "Astolfo", "Exhibition", "Rainbow"}
    for idx, thName in ipairs(themes) do
        local thBtn = Instance.new("TextButton")
        thBtn.Size = UDim2.new(1, -24, 0, 32)
        thBtn.Position = UDim2.fromOffset(12, 42 + (idx - 1) * 38)
        thBtn.BackgroundColor3 = Color3.fromRGB(26, 32, 50)
        thBtn.Font = Enum.Font.GothamMedium
        thBtn.Text = thName
        thBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        thBtn.TextSize = 12
        thBtn.Parent = rightPanel

        local thCorner = Instance.new("UICorner")
        thCorner.CornerRadius = UDim.new(0, 6)
        thCorner.Parent = thBtn

        self._themeButtons[thName] = thBtn

        thBtn.MouseButton1Click:Connect(function()
            self._onThemeChange(thName)
            for _, btn in pairs(self._themeButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(26, 32, 50)
            end
            thBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
        end)
    end
end

function InWorldMenu:Toggle()
    self._isOpen = not self._isOpen

    if self._isOpen then
        if not self._part then
            self:_buildWorldUI()
        end
        local cam = workspace.CurrentCamera
        if cam then
            local targetPos = cam.CFrame.Position + cam.CFrame.LookVector * Config.InWorldMenu.Distance
            self._spring = MathUtils.Spring.new(
                Config.InWorldMenu.SpringStiffness,
                Config.InWorldMenu.SpringDamping,
                targetPos
            )
            self._currentCFrame = cam.CFrame * CFrame.new(0, 0, -Config.InWorldMenu.Distance)
            if self._part then
                self._part.CFrame = self._currentCFrame
            end
        end
        if self._surfaceGui then
            self._surfaceGui.Enabled = true
        end
    else
        if self._surfaceGui then
            self._surfaceGui.Enabled = false
        end
        if self._part then
            self._part.CFrame = CFrame.new(0, -9999, 0)
        end
    end
end

function InWorldMenu:IsOpen()
    return self._isOpen == true
end

function InWorldMenu:Enable()
    if not self._isOpen then
        self:Toggle()
    end
end

function InWorldMenu:Disable()
    if self._isOpen then
        self:Toggle()
    end
end

function InWorldMenu:Update(dt, camera)
    if not self._isOpen or not self._part or not self._spring then return end

    local cfg = Config.InWorldMenu
    local targetPos = camera.CFrame.Position + camera.CFrame.LookVector * cfg.Distance
    self._spring:SetTarget(targetPos)

    local smoothedPos = self._spring:Update(dt)
    local desiredRot = CFrame.lookAt(smoothedPos, camera.CFrame.Position)
    self._currentCFrame = self._currentCFrame:Lerp(desiredRot, math.clamp(dt * 14.0, 0, 1))

    self._part.CFrame = self._currentCFrame
end

function InWorldMenu:Destroy()
    if self._surfaceGui then
        self._surfaceGui:Destroy()
        self._surfaceGui = nil
    end
    if self._part then
        self._part:Destroy()
        self._part = nil
    end
end

return InWorldMenu
