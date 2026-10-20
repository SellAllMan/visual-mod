--[[
    ========================================================================
    VISUALS ENGINE - 3D TARGET HUD
    File: VisualsEngine/Modules/TargetHUD.lua
    ========================================================================
--]]

local Players = game:GetService("Players")
local import = ... or (getgenv and getgenv().VisualsEngine_Import) or _G.VisualsEngine_Import
local Config = import("Config")

local LocalPlayer = Players.LocalPlayer

local TargetHUD = {}
TargetHUD.__index = TargetHUD

function TargetHUD.new()
    local self = setmetatable({}, TargetHUD)
    self._enabled = false
    self._currentTarget = nil
    self._currentHpPercent = 1.0
    self._ghostHpPercent = 1.0

    self._billboardGui = nil
    self._avatarImage = nil
    self._nameLabel = nil
    self._distLabel = nil
    self._hpLabel = nil
    self._hpBar = nil
    self._ghostHpBar = nil
    self._stroke = nil
    self._canvasGroup = nil

    return self
end

function TargetHUD:_buildUI()
    local cfg = Config.TargetHUD

    local targetGuiParent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

    local bb = Instance.new("BillboardGui")
    bb.Name = "MadiumTargetHUD"
    bb.Size = UDim2.fromOffset(280, 105)
    bb.StudsOffset = cfg.Offset
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false
    bb.Active = false
    bb.Parent = targetGuiParent
    self._billboardGui = bb

    local canvas = Instance.new("CanvasGroup")
    canvas.Name = "RootCanvas"
    canvas.Size = UDim2.fromScale(1, 1)
    canvas.BackgroundTransparency = 1
    canvas.GroupTransparency = 1
    canvas.Parent = bb
    self._canvasGroup = canvas

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = canvas

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(0, 255, 204)
    stroke.Transparency = 0.2
    stroke.Parent = card
    self._stroke = stroke

    local avatarFrame = Instance.new("Frame")
    avatarFrame.Name = "AvatarFrame"
    avatarFrame.Size = UDim2.fromOffset(68, 68)
    avatarFrame.Position = UDim2.fromOffset(12, 12)
    avatarFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.Parent = card

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 8)
    avatarCorner.Parent = avatarFrame

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Name = "Avatar"
    avatarImg.Size = UDim2.fromScale(1, 1)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Parent = avatarFrame
    self._avatarImage = avatarImg

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "TargetName"
    nameLbl.Size = UDim2.new(1, -100, 0, 22)
    nameLbl.Position = UDim2.fromOffset(90, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = "Target"
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextSize = 15
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = card
    self._nameLabel = nameLbl

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Distance"
    distLbl.Size = UDim2.new(1, -100, 0, 16)
    distLbl.Position = UDim2.fromOffset(90, 36)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.Text = "0.0 studs"
    distLbl.TextColor3 = Color3.fromRGB(160, 175, 200)
    distLbl.TextSize = 11
    distLbl.TextXAlignment = Enum.TextXAlignment.Left
    distLbl.Parent = card
    self._distLabel = distLbl

    local hpTrack = Instance.new("Frame")
    hpTrack.Name = "HpTrack"
    hpTrack.Size = UDim2.new(1, -102, 0, 14)
    hpTrack.Position = UDim2.fromOffset(90, 58)
    hpTrack.BackgroundColor3 = Color3.fromRGB(28, 32, 45)
    hpTrack.BorderSizePixel = 0
    hpTrack.Parent = card

    local hpCorner = Instance.new("UICorner")
    hpCorner.CornerRadius = UDim.new(0, 4)
    hpCorner.Parent = hpTrack

    local ghostBar = Instance.new("Frame")
    ghostBar.Name = "GhostBar"
    ghostBar.Size = UDim2.fromScale(1, 1)
    ghostBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    ghostBar.BorderSizePixel = 0
    ghostBar.Parent = hpTrack

    local ghostCorner = Instance.new("UICorner")
    ghostCorner.CornerRadius = UDim.new(0, 4)
    ghostCorner.Parent = ghostBar
    self._ghostHpBar = ghostBar

    local hpBar = Instance.new("Frame")
    hpBar.Name = "HpBar"
    hpBar.Size = UDim2.fromScale(1, 1)
    hpBar.BackgroundColor3 = Color3.fromRGB(0, 255, 204)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = hpTrack

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = hpBar
    self._hpBar = hpBar

    local hpValLbl = Instance.new("TextLabel")
    hpValLbl.Name = "HpValue"
    hpValLbl.Size = UDim2.fromOffset(60, 14)
    hpValLbl.Position = UDim2.new(1, -66, 0, 0)
    hpValLbl.BackgroundTransparency = 1
    hpValLbl.Font = Enum.Font.GothamBold
    hpValLbl.Text = "100%"
    hpValLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpValLbl.TextSize = 10
    hpValLbl.TextXAlignment = Enum.TextXAlignment.Right
    hpValLbl.Parent = hpTrack
    self._hpLabel = hpValLbl
end

function TargetHUD:Enable()
    if self._enabled then return end
    self._enabled = true
    if not self._billboardGui then
        self:_buildUI()
    end
end

function TargetHUD:Disable()
    if not self._enabled then return end
    self._enabled = false
    self._currentTarget = nil
    if self._canvasGroup then
        self._canvasGroup.GroupTransparency = 1
    end
end

function TargetHUD:_findTarget(localChar)
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end

    local myPos = localRoot.Position
    local bestTarget = nil
    local minDistance = Config.TargetHUD.MaxLockDistance

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local dist = (root.Position - myPos).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    bestTarget = {
                        Player = player,
                        Character = char,
                        Humanoid = hum,
                        RootPart = root,
                        Distance = dist,
                    }
                end
            end
        end
    end

    if not bestTarget then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= localChar and not Players:GetPlayerFromCharacter(obj) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local root = obj:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    local dist = (root.Position - myPos).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        bestTarget = {
                            Player = nil,
                            Character = obj,
                            Humanoid = hum,
                            RootPart = root,
                            Distance = dist,
                        }
                    end
                end
            end
        end
    end

    return bestTarget
end

function TargetHUD:Update(dt, localChar, themeColor)
    if not self._enabled or not self._billboardGui or not self._canvasGroup then return end

    local target = self:_findTarget(localChar)
    local cfg = Config.TargetHUD

    if target then
        if self._currentTarget == nil or self._currentTarget.Character ~= target.Character then
            self._currentTarget = target
            local targetName = if target.Player then target.Player.DisplayName else target.Character.Name
            self._nameLabel.Text = targetName

            if target.Player then
                task.spawn(function()
                    local thumb, isReady = Players:GetUserThumbnailAsync(
                        target.Player.UserId,
                        Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size100x100
                    )
                    if isReady and self._avatarImage then
                        self._avatarImage.Image = thumb
                    end
                end)
            else
                self._avatarImage.Image = "rbxassetid://10849911878"
            end

            self._billboardGui.Adornee = target.RootPart
        end

        self._canvasGroup.GroupTransparency = math.max(0, self._canvasGroup.GroupTransparency - dt * 6.0)

        local maxHp = math.max(1, target.Humanoid.MaxHealth)
        local curHp = math.clamp(target.Humanoid.Health, 0, maxHp)
        local targetFrac = curHp / maxHp

        self._currentHpPercent = self._currentHpPercent + (targetFrac - self._currentHpPercent) * math.clamp(dt * cfg.SmoothLerpSpeed, 0, 1)

        if self._ghostHpPercent < self._currentHpPercent then
            self._ghostHpPercent = self._currentHpPercent
        else
            self._ghostHpPercent = self._ghostHpPercent + (self._currentHpPercent - self._ghostHpPercent) * math.clamp(dt * cfg.GhostHpSpeed, 0, 1)
        end

        self._hpBar.Size = UDim2.fromScale(math.clamp(self._currentHpPercent, 0, 1), 1)
        self._hpBar.BackgroundColor3 = themeColor
        self._ghostHpBar.Size = UDim2.fromScale(math.clamp(self._ghostHpPercent, 0, 1), 1)

        self._stroke.Color = themeColor
        self._distLabel.Text = string.format("%.1f studs", target.Distance)
        self._hpLabel.Text = string.format("%d%%", math.round(targetFrac * 100))
    else
        self._currentTarget = nil
        self._canvasGroup.GroupTransparency = math.min(1, self._canvasGroup.GroupTransparency + dt * 5.0)
    end
end

function TargetHUD:Destroy()
    self:Disable()
    if self._billboardGui then
        self._billboardGui:Destroy()
        self._billboardGui = nil
    end
end

return TargetHUD
