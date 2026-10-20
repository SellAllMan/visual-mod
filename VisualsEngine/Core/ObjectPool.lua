--[[
    ========================================================================
    VISUALS ENGINE - HIGH PERFORMANCE OBJECT POOL
    File: VisualsEngine/Core/ObjectPool.lua
    ========================================================================
--]]

local ObjectPool = {}
ObjectPool.__index = ObjectPool

local poolFolder = nil
local function getPoolFolder()
    if not poolFolder or not poolFolder.Parent then
        local cam = workspace.CurrentCamera or workspace
        local existing = cam:FindFirstChild("__VisualEngine_MadiumPool")
        if existing and existing:IsA("Folder") then
            poolFolder = existing
        else
            local f = Instance.new("Folder")
            f.Name = "__VisualEngine_MadiumPool"
            f.Parent = cam
            poolFolder = f
        end
    end
    return poolFolder
end

function ObjectPool.new(createFunc, resetFunc, initialCount, categoryName)
    local self = setmetatable({}, ObjectPool)

    self._createFunc = createFunc
    self._resetFunc = resetFunc or function(obj)
        if obj:IsA("BasePart") then
            obj.Transparency = 1
            obj.CFrame = CFrame.new(0, -9999, 0)
        elseif obj:IsA("Beam") then
            obj.Enabled = false
        end
    end

    self._available = {}
    self._active = {}
    self._category = categoryName or "Default"

    local container = Instance.new("Folder")
    container.Name = self._category
    container.Parent = getPoolFolder()
    self._container = container

    local count = initialCount or 10
    for _ = 1, count do
        local obj = self._createFunc()
        obj.Parent = self._container
        self._resetFunc(obj)
        table.insert(self._available, obj)
    end

    return self
end

function ObjectPool:Get()
    local obj
    if #self._available > 0 then
        obj = table.remove(self._available)
    else
        obj = self._createFunc()
        obj.Parent = self._container
    end
    self._active[obj] = true
    return obj
end

function ObjectPool:Return(obj)
    if self._active[obj] then
        self._active[obj] = nil
        self._resetFunc(obj)
        table.insert(self._available, obj)
    end
end

function ObjectPool:ReturnAll()
    for obj in pairs(self._active) do
        self._resetFunc(obj)
        table.insert(self._available, obj)
    end
    table.clear(self._active)
end

function ObjectPool:Destroy()
    self:ReturnAll()
    for _, obj in ipairs(self._available) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(self._available)
    table.clear(self._active)
    if self._container then
        pcall(function() self._container:Destroy() end)
    end
end

return ObjectPool
