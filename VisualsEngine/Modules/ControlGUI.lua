--[[
    ========================================================================
    VISUALS ENGINE - INTERACTIVE 2D CONTROL GUI (DRAGGABLE)
    File: VisualsEngine/Modules/ControlGUI.lua
    ========================================================================
--]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")

local LocalPlayer = Players.LocalPlayer

local ControlGUI = {}
ControlGUI.__index = ControlGUI

function ControlGUI.new(onToggleModule, onThemeChange)
    local self = setmetatable({}, ControlGUI)
    self._isOpen = true
    self._onToggleModule = onToggleModule
    self._onThemeChange = onThemeChange

    self._screenGui = nil
    self._mainFrame = nil
    self._moduleButtons = {}
    self._themeButtons = {}

    self:_buildGUI()
    return self
end

function ControlGUI:_buildGUI()
    local targetParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

    local sg = Instance.new("ScreenGui")
    sg.Name = "MadiumVisualsControlGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = targetParent
    self._screenGui = sg

    -- Main Card
    local frame = Instance.new("Frame")
    frame.Name = "MainCard"
    frame.Size = UDim2.fromOffset(560, 420)
    frame.Position = UDim2.fromOffset(60, 60)
    frame.BackgroundColor3 = Color3.fromRGB(13, 15, 23)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true
    frame.Parent = sg
    self._mainFrame = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.8
    stroke.Color = Color3.fromRGB(0, 255, 204)
    stroke.Parent = frame
    self._stroke = stroke

    -- Make Frame Draggable
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundColor3 = Color3.fromRGB(19, 23, 36)
    header.BorderSizePixel = 0
    header.Parent = frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -120, 1, 0)
    titleLbl.Position = UDim2.fromOffset(16, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = "⚡ NEON PROTOCOL // CLIENT VISUALS"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 26)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(36, 42, 60)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    closeBtn.TextSize = 12
    closeBtn.Parent = header
    local closeCorner = Instance.new("UICorner") closeCorner.CornerRadius = UDim.new(0, 5) closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    -- Left Modules List (Scrolling)
    local leftScroll = Instance.new("ScrollingFrame")
    leftScroll.Name = "ModulesList"
    leftScroll.Size = UDim2.new(0.62, -15, 1, -54)
    leftScroll.Position = UDim2.fromOffset(12, 48)
    leftScroll.BackgroundTransparency = 1
    leftScroll.BorderSizePixel = 0
    leftScroll.ScrollBarThickness = 4
    leftScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 204)
    leftScroll.CanvasSize = UDim2.fromOffset(0, 420)
    leftScroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = leftScroll

    local modules = {
        {"Constellation", "Constellation Grid", Config.Constellation.Enabled},
        {"BezierFlow", "Bézier Vector Flow", Config.BezierFlow.Enabled},
        {"AuraShockwave", "Ground Shockwaves", Config.AuraShockwave.Enabled},
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
        row.Size = UDim2.new(1, -8, 0, 36)
        row.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = leftScroll

        local rCorner = Instance.new("UICorner") rCorner.CornerRadius = UDim.new(0, 6) rCorner.Parent = row

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
        toggleBtn.Size = UDim2.fromOffset(68, 24)
        toggleBtn.Position = UDim2.new(1, -78, 0.5, -12)
        toggleBtn.BackgroundColor3 = if isEnabled then Color3.fromRGB(0, 204, 150) else Color3.fromRGB(48, 54, 72)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Text = if isEnabled then "ON" else "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.TextSize = 11
        toggleBtn.Parent = row
        local tCorner = Instance.new("UICorner") tCorner.CornerRadius = UDim.new(0, 4) tCorner.Parent = toggleBtn

        self._moduleButtons[modId] = toggleBtn

        toggleBtn.MouseButton1Click:Connect(function()
            local newState = toggleBtn.Text == "OFF"
            toggleBtn.Text = if newState then "ON" else "OFF"
            toggleBtn.BackgroundColor3 = if newState then Color3.fromRGB(0, 204, 150) else Color3.fromRGB(48, 54, 72)
            self._onToggleModule(modId, newState)
        end)
    end

    -- Right Panel: Themes & Status
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0.38, -15, 1, -54)
    rightPanel.Position = UDim2.new(0.62, 4, 0, 48)
    rightPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = frame
    local rpCorner = Instance.new("UICorner") rpCorner.CornerRadius = UDim.new(0, 8) rpCorner.Parent = rightPanel

    local themeTitle = Instance.new("TextLabel")
    themeTitle.Size = UDim2.new(1, 0, 0, 28)
    themeTitle.Position = UDim2.fromOffset(12, 10)
    themeTitle.BackgroundTransparency = 1
    themeTitle.Font = Enum.Font.GothamBold
    themeTitle.Text = "THEMES"
    themeTitle.TextColor3 = Color3.fromRGB(0, 255, 204)
    themeTitle.TextSize = 13
    themeTitle.TextXAlignment = Enum.TextXAlignment.Left
    themeTitle.Parent = rightPanel

    local themes = {"Cyberpunk", "Moon", "Astolfo", "Exhibition", "Rainbow"}
    for idx, thName in ipairs(themes) do
        local thBtn = Instance.new("TextButton")
        thBtn.Size = UDim2.new(1, -24, 0, 34)
        thBtn.Position = UDim2.fromOffset(12, 40 + (idx - 1) * 40)
        thBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 48)
        thBtn.Font = Enum.Font.GothamMedium
        thBtn.Text = thName
        thBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        thBtn.TextSize = 12
        thBtn.Parent = rightPanel
        local thCorner = Instance.new("UICorner") thCorner.CornerRadius = UDim.new(0, 6) thCorner.Parent = thBtn

        self._themeButtons[thName] = thBtn

        thBtn.MouseButton1Click:Connect(function()
            self._onThemeChange(thName)
            for _, btn in pairs(self._themeButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(24, 30, 48)
            end
            thBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
        end)
    end

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -24, 0, 36)
    hint.Position = UDim2.new(0, 12, 1, -44)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.GothamMedium
    hint.Text = "Press [RSHIFT] / [INSERT] to hide GUI"
    hint.TextColor3 = Color3.fromRGB(140, 155, 185)
    hint.TextSize = 11
    hint.TextWrapped = true
    hint.Parent = rightPanel
end

function ControlGUI:Toggle()
    self._isOpen = not self._isOpen
    if self._mainFrame then
        self._mainFrame.Visible = self._isOpen
    end
end

function ControlGUI:IsOpen()
    return self._isOpen
end

function ControlGUI:Destroy()
    if self._screenGui then
        self._screenGui:Destroy()
        self._screenGui = nil
    end
end

return ControlGUI
