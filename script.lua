--[[
    MM2 GUI — Murder Mystery 2
    Полный клиентский скрипт для executor.
]]

-- ============================================================
-- СЕРВИСЫ
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ
-- ============================================================
local State = {
    AutoFarm = false,
    FarmMode = "Fly — лежа",
    FarmSpeed = 35,
    FarmOrder = "Nearest Item",
    AntiAFK = false,
    ESPRoles = false,
    ShowNicknames = false,
    AimAssist = false,

    _connections = {},
    _espObjects = {},
    _nicknameObjects = {},
    _farmThread = nil,
    _antiAFKThread = nil,
    _aimAssistConn = nil,
    _flingRunning = false,
    _closed = false,
}

local GUIObjects = {}
local function track(obj) table.insert(GUIObjects, obj); return obj end
local function trackConn(c) table.insert(State._connections, c); return c end

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local function getHRP(plr)
    plr = plr or LocalPlayer
    if plr.Character then return plr.Character:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function getHumanoid(plr)
    plr = plr or LocalPlayer
    if plr.Character then return plr.Character:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function getRole(plr)
    if not plr or not plr.Character then return "Innocent" end
    local char = plr.Character
    local backpack = plr:FindFirstChild("Backpack")
    local function has(name)
        if char:FindFirstChild(name) then return true end
        if backpack and backpack:FindFirstChild(name) then return true end
        return false
    end
    if has("Knife") then return "Murderer" end
    if has("Gun") then return "Sheriff" end
    return "Innocent"
end

local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 60, 60) end
    if role == "Sheriff" then return Color3.fromRGB(60, 120, 255) end
    return Color3.fromRGB(80, 255, 80)
end

-- ============================================================
-- FORWARD DECLARATIONS (чтобы GUI мог ссылаться до определения)
-- ============================================================
local startAutoFarm, stopAutoFarm
local startAntiAFK, stopAntiAFK
local startESP, stopESP
local startNicknames, stopNicknames
local startAimAssist, stopAimAssist
local getGunSequence, attemptKill, attemptFling
local fullShutdown

-- ============================================================
-- БАЗОВЫЙ GUI
-- ============================================================
local screenGui = track(Instance.new("ScreenGui"))
screenGui.Name = "MM2_GUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local floatingIcon = track(Instance.new("TextButton"))
floatingIcon.Name = "FloatingIcon"
floatingIcon.Size = UDim2.new(0, 50, 0, 50)
floatingIcon.Position = UDim2.new(0, 20, 0, 20)
floatingIcon.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
floatingIcon.BackgroundTransparency = 0.15
floatingIcon.BorderSizePixel = 0
floatingIcon.Text = "M"
floatingIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
floatingIcon.TextSize = 24
floatingIcon.Font = Enum.Font.GothamBold
floatingIcon.Visible = false
floatingIcon.Parent = screenGui
local iconCorner = track(Instance.new("UICorner"))
iconCorner.CornerRadius = UDim.new(0, 12)
iconCorner.Parent = floatingIcon

local mainFrame = track(Instance.new("Frame"))
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 380)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
local mainCorner = track(Instance.new("UICorner"))
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local titleBar = track(Instance.new("Frame"))
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = track(Instance.new("TextLabel"))
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MM2 GUI"
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local minimizeBtn = track(Instance.new("TextButton"))
minimizeBtn.Size = UDim2.new(0, 32, 0, 32)
minimizeBtn.Position = UDim2.new(1, -76, 0, 4)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
minimizeBtn.TextSize = 20
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = titleBar
local minCorner = track(Instance.new("UICorner"))
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

local closeBtn = track(Instance.new("TextButton"))
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar
local closeCorner = track(Instance.new("UICorner"))
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Навигация
local navBar = track(Instance.new("Frame"))
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 130, 1, -40)
navBar.Position = UDim2.new(0, 0, 0, 40)
navBar.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
navBar.BorderSizePixel = 0
navBar.Parent = mainFrame

local navLayout = track(Instance.new("UIListLayout"))
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, 4)
navLayout.Parent = navBar

local navPadding = track(Instance.new("UIPadding"))
navPadding.PaddingTop = UDim.new(0, 8)
navPadding.PaddingLeft = UDim.new(0, 8)
navPadding.PaddingRight = UDim.new(0, 8)
navPadding.Parent = navBar

local contentArea = track(Instance.new("Frame"))
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -138, 1, -48)
contentArea.Position = UDim2.new(0, 138, 0, 44)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local categories = {}
local categoryNames = {"Farm", "Visuals", "Sheriff", "Murderer", "Fun"}

for i, name in ipairs(categoryNames) do
    local btn = track(Instance.new("TextButton"))
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(190, 190, 200)
    btn.TextSize = 14
    btn.Font = Enum.Font.Gotham
    btn.Parent = navBar
    local c = track(Instance.new("UICorner"))
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local container = track(Instance.new("ScrollingFrame"))
    container.Name = name .. "Content"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.Position = UDim2.new(0, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.ScrollBarThickness = 4
    container.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    container.Visible = (i == 1)
    container.Parent = contentArea

    local layout = track(Instance.new("UIListLayout"))
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = container

    local pad = track(Instance.new("UIPadding"))
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = container

    categories[name] = {button = btn, container = container}

    btn.MouseButton1Click:Connect(function()
        for _, cat in pairs(categories) do
            cat.container.Visible = false
            cat.button.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
            cat.button.TextColor3 = Color3.fromRGB(190, 190, 200)
        end
        container.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end

categories["Farm"].button.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
categories["Farm"].button.TextColor3 = Color3.fromRGB(255, 255, 255)

-- ============================================================
-- ПЕРЕТАСКИВАНИЕ ОКНА
-- ============================================================
do
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                           startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

-- ============================================================
-- ФАБРИКИ UI
-- ============================================================
local function createToggle(parent, text, default, callback)
    local frame = track(Instance.new("Frame"))
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = track(Instance.new("TextLabel"))
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local switch = track(Instance.new("TextButton"))
    switch.Size = UDim2.new(0, 44, 0, 22)
    switch.Position = UDim2.new(1, -44, 0.5, -11)
    switch.BackgroundColor3 = default and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(55, 55, 70)
    switch.BorderSizePixel = 0
    switch.Text = ""
    switch.Parent = frame
    local sc = track(Instance.new("UICorner"))
    sc.CornerRadius = UDim.new(1, 0)
    sc.Parent = switch

    local knob = track(Instance.new("Frame"))
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    local kc = track(Instance.new("UICorner"))
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local state = default
    local function setState(newState)
        state = newState
        TweenService:Create(switch, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(55, 55, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        }):Play()
        if callback then callback(state) end
    end
    switch.MouseButton1Click:Connect(function() setState(not state) end)
    return {frame = frame, setState = setState, getState = function() return state end}
end

local function createSlider(parent, text, min, max, default, callback)
    local frame = track(Instance.new("Frame"))
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = track(Instance.new("TextLabel"))
    label.Size = UDim2.new(1, -50, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = track(Instance.new("TextLabel"))
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Position = UDim2.new(1, -50, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 13
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame

    local barBg = track(Instance.new("Frame"))
    barBg.Size = UDim2.new(1, 0, 0, 6)
    barBg.Position = UDim2.new(0, 0, 0, 30)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame
    local bc = track(Instance.new("UICorner"))
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = barBg

    local fill = track(Instance.new("Frame"))
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    local fc = track(Instance.new("UICorner"))
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local knob = track(Instance.new("Frame"))
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = barBg
    local kc = track(Instance.new("UICorner"))
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local dragging = false
    local currentValue = default

    local function updateFromX(mouseX)
        local absPos = barBg.AbsolutePosition.X
        local absSize = barBg.AbsoluteSize.X
        if absSize <= 0 then return end
        local rel = math.clamp((mouseX - absPos) / absSize, 0, 1)
        local val = math.floor(min + rel * (max - min) + 0.5)
        currentValue = val
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valueLabel.Text = tostring(val)
        if callback then callback(val) end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromX(input.Position.X)
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    return {frame = frame, getValue = function() return currentValue end}
end

local function createDropdown(parent, text, options, default, callback)
    local frame = track(Instance.new("Frame"))
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1
    frame.ClipsDescendants = false
    frame.ZIndex = 5
    frame.Parent = parent

    local label = track(Instance.new("TextLabel"))
    label.Size = UDim2.new(1, -120, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = frame

    local btn = track(Instance.new("TextButton"))
    btn.Size = UDim2.new(0, 115, 0, 26)
    btn.Position = UDim2.new(1, -115, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
    btn.BorderSizePixel = 0
    btn.Text = default or (options[1] or "")
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.TextSize = 12
    btn.Font = Enum.Font.Gotham
    btn.ZIndex = 6
    btn.Parent = frame
    local bc = track(Instance.new("UICorner"))
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = btn

    -- Список привязан к кнопке и раскрывается строго под ней
    local list = track(Instance.new("Frame"))
    list.Size = UDim2.new(0, 115, 0, 0)
    list.Position = UDim2.new(0, 0, 1, 4)
    list.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    list.BorderSizePixel = 0
    list.ClipsDescendants = true
    list.Visible = false
    list.ZIndex = 20
    list.Parent = btn
    local lc = track(Instance.new("UICorner"))
    lc.CornerRadius = UDim.new(0, 5)
    lc.Parent = list

    local listLayout = track(Instance.new("UIListLayout"))
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local selected = default
    local itemButtons = {}
    local expanded = false

    local function updateCanvas()
        local p = parent
        while p and not p:IsA("ScrollingFrame") do
            p = p.Parent
        end
        if p then
            local layout = p:FindFirstChildOfClass("UIListLayout")
            if layout then
                p.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
            end
        end
    end

    local function rebuildOptions(newOptions)
        for _, b in ipairs(itemButtons) do pcall(function() b:Destroy() end) end
        itemButtons = {}
        if #newOptions == 0 then newOptions = {"(нет игроков)"} end
        for _, opt in ipairs(newOptions) do
            local item = track(Instance.new("TextButton"))
            item.Size = UDim2.new(1, 0, 0, 26)
            item.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            item.BorderSizePixel = 0
            item.Text = opt
            item.TextColor3 = Color3.fromRGB(200, 200, 210)
            item.TextSize = 12
            item.Font = Enum.Font.Gotham
            item.ZIndex = 21
            item.Parent = list
            item.MouseButton1Click:Connect(function()
                selected = opt
                btn.Text = opt
                expanded = false
                list.Visible = false
                list.Size = UDim2.new(0, 115, 0, 0)
                if callback then callback(opt) end
            end)
            table.insert(itemButtons, item)
        end
    end

    rebuildOptions(options)

    btn.MouseButton1Click:Connect(function()
        expanded = not expanded
        list.Visible = expanded
        if expanded then
            list.Size = UDim2.new(0, 115, 0, 0)
            TweenService:Create(list, TweenInfo.new(0.15), {Size = UDim2.new(0, 115, 0, #itemButtons * 26)}):Play()
            frame.ZIndex = 50
            btn.ZIndex = 51
            list.ZIndex = 52
            for _, ib in ipairs(itemButtons) do ib.ZIndex = 53 end
            task.defer(updateCanvas)
        else
            TweenService:Create(list, TweenInfo.new(0.15), {Size = UDim2.new(0, 115, 0, 0)}):Play()
            task.delay(0.15, function()
                if not expanded then
                    frame.ZIndex = 5
                    btn.ZIndex = 6
                    list.ZIndex = 20
                end
            end)
        end
    end)

    return {frame = frame, refresh = rebuildOptions, getSelected = function() return selected end}
end

local function createButton(parent, text, callback)
    local btn = track(Instance.new("TextButton"))
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(230, 230, 240)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = parent
    local c = track(Instance.new("UICorner"))
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end
-- ============================================================
-- НАПОЛНЕНИЕ: FARM
-- ============================================================
local farmContent = categories["Farm"].container

createToggle(farmContent, "Auto Farm", false, function(v)
    State.AutoFarm = v
    if v then startAutoFarm() else stopAutoFarm() end
end)

createDropdown(farmContent, "Режим движения", {"Fly — лежа", "Fly — стоя", "Teleport", "Underground Teleport"}, "Fly — лежа", function(v)
    -- Приводим отображаемое значение к внутреннему ключу
    local map = {
        ["Fly — лежа"] = "Fly Lying",
        ["Fly — стоя"] = "Fly Standing",
        ["Teleport"] = "Teleport",
        ["Underground Teleport"] = "Underground Teleport",
    }
    State.FarmMode = map[v] or "Fly Lying"
end)

createSlider(farmContent, "Скорость (10–60 studs/s)", 10, 60, 35, function(v) State.FarmSpeed = v end)

createDropdown(farmContent, "Порядок сбора", {"Nearest Item", "Random Item"}, "Nearest Item", function(v)
    State.FarmOrder = v
end)

createToggle(farmContent, "Anti-AFK", false, function(v)
    State.AntiAFK = v
    if v then startAntiAFK() else stopAntiAFK() end
end)

-- ============================================================
-- НАПОЛНЕНИЕ: VISUALS
-- ============================================================
local visualsContent = categories["Visuals"].container

createToggle(visualsContent, "ESP Roles", false, function(v)
    State.ESPRoles = v
    if v then startESP() else stopESP() end
end)

createToggle(visualsContent, "Show Nicknames", false, function(v)
    State.ShowNicknames = v
    if v then startNicknames() else stopNicknames() end
end)

-- ============================================================
-- НАПОЛНЕНИЕ: SHERIFF
-- ============================================================
local sheriffContent = categories["Sheriff"].container

createToggle(sheriffContent, "Aim Assist", false, function(v)
    State.AimAssist = v
    if v then startAimAssist() else stopAimAssist() end
end)

createButton(sheriffContent, "Get Gun", function() getGunSequence() end)

-- ============================================================
-- НАПОЛНЕНИЕ: MURDERER
-- ============================================================
local murdererContent = categories["Murderer"].container
local playerDropdownKill = createDropdown(murdererContent, "Выбрать игрока", {}, nil, function(v) end)

createButton(murdererContent, "Kill Selected Player", function()
    local name = playerDropdownKill.getSelected()
    if not name then return end
    local target = Players:FindFirstChild(name)
    if target then attemptKill(target) end
end)

createButton(murdererContent, "Kill All", function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            attemptKill(plr)
            task.wait(0.1)
        end
    end
end)

-- ============================================================
-- НАПОЛНЕНИЕ: FUN
-- ============================================================
local funContent = categories["Fun"].container

createButton(funContent, "Fling All", function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            attemptFling(plr)
            task.wait(0.05)
        end
    end
end)

local playerDropdownFling = createDropdown(funContent, "Выбрать игрока", {}, nil, function(v) end)

createButton(funContent, "Fling Selected Player", function()
    local name = playerDropdownFling.getSelected()
    if not name then return end
    local target = Players:FindFirstChild(name)
    if target then attemptFling(target) end
end)

-- ============================================================
-- ОБНОВЛЕНИЕ DROPDOWN ИГРОКОВ
-- ============================================================
local function refreshPlayerDropdowns()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(names, plr.Name) end
    end
    playerDropdownKill.refresh(names)
    playerDropdownFling.refresh(names)
end

trackConn(Players.PlayerAdded:Connect(function() task.wait(1); refreshPlayerDropdowns() end))
trackConn(Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshPlayerDropdowns() end))
task.spawn(function() task.wait(1); refreshPlayerDropdowns() end)

-- ============================================================
-- ANTI-AFK
-- ============================================================
function startAntiAFK()
    stopAntiAFK()
    State._antiAFKThread = task.spawn(function()
        while State.AntiAFK and not State._closed do
            task.wait(300) -- 5 минут, безопасный интервал
            if not State.AntiAFK or State._closed then break end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(0, 0))
                -- дополнительно сбрасываем "idle" через InputBegan
                if LocalPlayer.Idled then
                    LocalPlayer:Idled()
                end
            end)
        end
    end)
end

function stopAntiAFK()
    if State._antiAFKThread then
        pcall(function() task.cancel(State._antiAFKThread) end)
        State._antiAFKThread = nil
    end
end

-- ============================================================
-- AUTO FARM (переписан с нуля по ТЗ)
-- ============================================================
local farmCollected = {}          -- [Instance] = true  — уже собрано
local farmAttempts  = {}          -- [Instance] = number — сколько попыток
local MAX_ATTEMPTS  = 3           -- попыток на одну конфету
local FARM_TP_INTERVAL = 2        -- строго 2 секунды
local FARM_SPEED_DEFAULT = 35     -- синхронизировано со слайдером (10–60, дефолт 35)

-- Инициализация значений в State (если их ещё нет)
State.FarmSpeed = State.FarmSpeed or FARM_SPEED_DEFAULT
State.FarmOrder = State.FarmOrder or "Nearest Item"
State.FarmMode  = State.FarmMode  or "Fly Lying"

-- ------------------------------------------------------------
-- Поиск предметов
-- ------------------------------------------------------------
local function isCandyPart(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name
    return n == "Coin" or n == "Coin_" or n:find("Coin")
        or n:find("Candy") or n:find("Item") or n:find("Gift")
end

local function findItems()
    local items = {}
    local myChar = LocalPlayer.Character
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCandyPart(obj) then
            if not myChar or not obj:IsDescendantOf(myChar) then
                if not farmCollected[obj] then
                    table.insert(items, obj)
                end
            end
        end
    end
    return items
end

local function pickTarget(items, fromPos)
    if #items == 0 then return nil end
    if State.FarmOrder == "Random Item" then
        return items[math.random(1, #items)]
    end
    local best, bestDist = nil, math.huge
    for _, it in ipairs(items) do
        local d = (it.Position - fromPos).Magnitude
        if d < bestDist then best, bestDist = it, d end
    end
    return best
end

-- ------------------------------------------------------------
-- Коллизии: полностью выкл/вкл
-- ------------------------------------------------------------
local function disableCollisions()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false end)
        end
    end
end

local function restoreCollisions()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = true end)
        end
    end
    -- HumanoidRootPart в норме не должен коллизить (иначе застревание)
    local hrp = getHRP()
    if hrp then pcall(function() hrp.CanCollide = false end) end
end

-- Приземление: ставим персонажа на ближайшую поверхность
local function landOnGround()
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end
    hum.PlatformStand = false
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -200, 0), params)
    if ray then
        hrp.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3.5, 0))
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
end

local function freezeForFly(on)
    local hum = getHumanoid()
    if hum then hum.PlatformStand = on end
end

-- ------------------------------------------------------------
-- Проверка успешного сбора
-- ------------------------------------------------------------
local function waitCollected(item, timeout)
    local deadline = tick() + (timeout or 2)
    while tick() < deadline do
        if not item or not item.Parent then
            return true
        end
        task.wait(0.05)
    end
    return false
end

-- ------------------------------------------------------------
-- Микродвижения
-- ------------------------------------------------------------
local microOffset = 0
local function applyMicroJitter(hrp, baseY)
    microOffset = microOffset + 0.15
    local dy = math.sin(microOffset) * 0.3
    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(hrp.Position.X, baseY + dy, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ------------------------------------------------------------
-- TELEPORT (обычный)
-- ------------------------------------------------------------
local function doTeleportNormal(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- ------------------------------------------------------------
-- UNDERGROUND TELEPORT
-- Голова на уровне конфеты, висим под конфетой, не падаем
-- ------------------------------------------------------------
local function doTeleportUnderground(targetPos)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end

    local HEAD_OFFSET = 1.5
    local desiredHRP_Y = targetPos.Y - HEAD_OFFSET

    -- Проверка потолка: если близко — опускаем
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local ray = Workspace:Raycast(
        Vector3.new(targetPos.X, desiredHRP_Y, targetPos.Z),
        Vector3.new(0, HEAD_OFFSET + 1.5, 0),
        params
    )
    if ray then
        desiredHRP_Y = ray.Position.Y - HEAD_OFFSET - 0.5
    end

    local fixedCF = CFrame.new(targetPos.X, desiredHRP_Y, targetPos.Z)
    hrp.CFrame = fixedCF
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- Коллизии выключены, физика удержания
    disableCollisions()
    hum.PlatformStand = true

    local deadline = tick() + 2
    local holdThread = task.spawn(function()
        while tick() < deadline and State.AutoFarm and not State._closed do
            local h = getHRP()
            if not h then break end
            h.CFrame = fixedCF
            h.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.03)
        end
        if not State.AutoFarm or State._closed then return end
        hum.PlatformStand = false
        restoreCollisions()
        landOnGround()
    end)
    return holdThread
end

-- ------------------------------------------------------------
-- FLY — сквозь стены
-- ------------------------------------------------------------
local function doFlyStep(targetPos, lying, fixedY)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end

    local current = hrp.Position
    local dir = Vector3.new(targetPos.X - current.X, 0, targetPos.Z - current.Z)
    if dir.Magnitude < 2 then
        return true
    end

    local speed = State.FarmSpeed
    local step = dir.Unit * speed * (RunService.Heartbeat:Wait() or 0.016)
    local newX = current.X + step.X
    local newZ = current.Z + step.Z

    local lookAt = Vector3.new(targetPos.X, fixedY, targetPos.Z)
    local newCF = CFrame.new(Vector3.new(newX, fixedY, newZ), lookAt)
    if lying then
        newCF = newCF * CFrame.Angles(0, 0, math.rad(90))
    end
    hrp.CFrame = newCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    return false
end

-- ------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
-- ------------------------------------------------------------
function startAutoFarm()
    stopAutoFarm()
    farmCollected = {}
    farmAttempts = {}

    State._farmThread = task.spawn(function()
        while State.AutoFarm and not State._closed do
            local hrp = getHRP()
            local hum = getHumanoid()

            if not hrp or not hum or hum.Health <= 0 then
                freezeForFly(false)
                restoreCollisions()
                task.wait(0.5)
            else
                local items = findItems()

                if #items == 0 then
                    freezeForFly(false)
                    restoreCollisions()
                    task.wait(0.4)
                else
                    local target = pickTarget(items, hrp.Position)
                    if not target then
                        task.wait(0.3)
                    else
                        local mode = State.FarmMode

                        -------------------------------------------------
                        -- TELEPORT
                        -------------------------------------------------
                        if mode == "Teleport" then
                            doTeleportNormal(target.Position)
                            waitCollected(target, 1.5)
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- UNDERGROUND TELEPORT
                        -------------------------------------------------
                        elseif mode == "Underground Teleport" then
                            local hold = doTeleportUnderground(target.Position)
                            waitCollected(target, 1.5)
                            if hold then pcall(function() task.cancel(hold) end) end
                            -- Гарантированно вернуть физику после удержания
                            if getHumanoid() then getHumanoid().PlatformStand = false end
                            restoreCollisions()
                            landOnGround()
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- FLY (Lying / Standing) — сквозь стены
                        -------------------------------------------------
                        else
                            local lying = (mode == "Fly Lying")
                            local fixedY
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                fixedY = hrp.Position.Y + 2
                            else
                                fixedY = hrp.Position.Y
                            end

                            freezeForFly(true)
                            disableCollisions()

                            local deadline = tick() + 5
                            while State.AutoFarm and not State._closed and target.Parent do
                                if tick() > deadline then break end
                                if doFlyStep(target.Position, lying, fixedY) then
                                    break
                                end
                                applyMicroJitter(hrp, fixedY)
                                task.wait()
                            end

                            -- Возвращаем физику и ставим на землю
                            freezeForFly(false)
                            restoreCollisions()
                            landOnGround()

                            local ok = waitCollected(target, 1.0)
                            if ok then
                                farmCollected[target] = true
                            else
                                farmAttempts[target] = (farmAttempts[target] or 0) + 1
                                if farmAttempts[target] >= MAX_ATTEMPTS then
                                    farmCollected[target] = true
                                end
                            end

                            task.wait(0.3)
                        end
                    end
                end
            end
        end

        freezeForFly(false)
        restoreCollisions()
        landOnGround()
    end)
end

function stopAutoFarm()
    if State._farmThread then
        pcall(function() task.cancel(State._farmThread) end)
        State._farmThread = nil
    end
    farmCollected = {}
    farmAttempts = {}
    freezeForFly(false)
    restoreCollisions()
    landOnGround()
end

-- ------------------------------------------------------------
-- Поиск предметов
-- ------------------------------------------------------------
local function isCandyPart(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name
    return n == "Coin" or n == "Coin_" or n:find("Coin")
        or n:find("Candy") or n:find("Item") or n:find("Gift")
end

local function findItems()
    local items = {}
    local myChar = LocalPlayer.Character
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCandyPart(obj) then
            if not myChar or not obj:IsDescendantOf(myChar) then
                if not farmCollected[obj] then
                    table.insert(items, obj)
                end
            end
        end
    end
    return items
end

local function pickTarget(items, fromPos)
    if #items == 0 then return nil end
    if State.FarmOrder == "Random Item" then
        return items[math.random(1, #items)]
    end
    local best, bestDist = nil, math.huge
    for _, it in ipairs(items) do
        local d = (it.Position - fromPos).Magnitude
        if d < bestDist then best, bestDist = it, d end
    end
    return best
end

-- ------------------------------------------------------------
-- Безопасное включение/выключение физики
-- (используется ТОЛЬКО вокруг реального движения)
-- ------------------------------------------------------------
local function setNoCollide(on)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = not on end)
        end
    end
end

local function freezeForFly(on)
    local hum = getHumanoid()
    if hum then hum.PlatformStand = on end
end

-- ------------------------------------------------------------
-- Проверка успешного сбора: ждём, пока объект исчезнет
-- ------------------------------------------------------------
local function waitCollected(item, timeout)
    local deadline = tick() + (timeout or 2)
    while tick() < deadline do
        if not item or not item.Parent then
            return true
        end
        task.wait(0.05)
    end
    return false
end

-- ------------------------------------------------------------
-- Микродвижения (небольшие колебания, чтобы регистрировался Touch)
-- ------------------------------------------------------------
local microOffset = 0
local function applyMicroJitter(hrp, baseY)
    microOffset = microOffset + 0.15
    local dy = math.sin(microOffset) * 0.3
    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(hrp.Position.X, baseY + dy, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ------------------------------------------------------------
-- TELEPORT (обычный)
-- ------------------------------------------------------------
local function doTeleportNormal(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- ------------------------------------------------------------
-- UNDERGROUND TELEPORT (голова на уровне конфеты, не падаем)
-- ------------------------------------------------------------
local function doTeleportUnderground(targetPos)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end

    -- Голова примерно на HRP.Y + 1.5 (R6/R15). Ставим HRP так,
    -- чтобы голова оказалась на уровне конфеты.
    local HEAD_OFFSET = 1.5
    local desiredHRP_Y = targetPos.Y - HEAD_OFFSET

    -- Проверка на потолок: если над точкой близко потолок — не лезем
    -- головой в него, оставляем запас.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local ray = Workspace:Raycast(
        Vector3.new(targetPos.X, desiredHRP_Y, targetPos.Z),
        Vector3.new(0, HEAD_OFFSET + 1.5, 0),
        params
    )
    if ray then
        desiredHRP_Y = ray.Position.Y - HEAD_OFFSET - 0.5
    end

    local fixedCF = CFrame.new(targetPos.X, desiredHRP_Y, targetPos.Z)
    hrp.CFrame = fixedCF
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- Отключаем коллизии, чтобы потолок/пол не мешали удержанию
    setNoCollide(true)
    hum.PlatformStand = true

    -- Держим позицию, пока объект не собран (макс 2 сек), без падения в бездну
    local deadline = tick() + 2
    local holdThread = task.spawn(function()
        while tick() < deadline and State.AutoFarm and not State._closed do
            local h = getHRP()
            if not h then break end
            h.CFrame = fixedCF
            h.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.03)
        end
        -- возвращаем физику
        setNoCollide(false)
        local hm = getHumanoid()
        if hm then hm.PlatformStand = false end
    end)
    return holdThread
end

-- ------------------------------------------------------------
-- FLY (общий для Lying/Standing) — сквозь стены
-- Возвращает true, если долетели до цели.
-- ------------------------------------------------------------
local function doFlyStep(targetPos, lying, fixedY)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end

    local current = hrp.Position
    local dir = Vector3.new(targetPos.X - current.X, 0, targetPos.Z - current.Z)
    if dir.Magnitude < 2 then
        return true
    end

    local speed = State.FarmSpeed
    local step = dir.Unit * speed * (RunService.Heartbeat:Wait() or 0.016)
    local newX = current.X + step.X
    local newZ = current.Z + step.Z

    local lookAt = Vector3.new(targetPos.X, fixedY, targetPos.Z)
    local newCF = CFrame.new(Vector3.new(newX, fixedY, newZ), lookAt)
    if lying then
        newCF = newCF * CFrame.Angles(0, 0, math.rad(90))
    end
    hrp.CFrame = newCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    return false
end

-- ------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
-- ------------------------------------------------------------
function startAutoFarm()
    stopAutoFarm()
    farmCollected = {}
    farmAttempts = {}

    State._farmThread = task.spawn(function()
        while State.AutoFarm and not State._closed do
            local hrp = getHRP()
            local hum = getHumanoid()

            -- Нет персонажа / умер / респавн — ждём, физику НЕ трогаем
            if not hrp or not hum or hum.Health <= 0 then
                freezeForFly(false)
                setNoCollide(false)
                task.wait(0.5)
            else
                local items = findItems()

                -- КОНФЕТ НЕТ — просто стоим, ничего не делаем
                if #items == 0 then
                    freezeForFly(false)
                    task.wait(0.4)
                else
                    local target = pickTarget(items, hrp.Position)
                    if not target then
                        task.wait(0.3)
                    else
                        local mode = State.FarmMode

                        -------------------------------------------------
                        -- TELEPORT
                        -------------------------------------------------
                        if mode == "Teleport" then
                            doTeleportNormal(target.Position)
                            waitCollected(target, 1.5)
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- UNDERGROUND TELEPORT
                        -------------------------------------------------
                        elseif mode == "Underground Teleport" then
                            local hold = doTeleportUnderground(target.Position)
                            waitCollected(target, 1.5)
                            if hold then pcall(function() task.cancel(hold) end) end
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- FLY (Lying / Standing) — сквозь стены
                        -------------------------------------------------
                        else
                            local lying = (mode == "Fly Lying")
                            local fixedY
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                fixedY = hrp.Position.Y + 2
                            else
                                fixedY = hrp.Position.Y
                            end

                            freezeForFly(true)
                            setNoCollide(true) -- держим на весь полёт: сквозь стены

                            local deadline = tick() + 5
                            while State.AutoFarm and not State._closed and target.Parent do
                                if tick() > deadline then break end
                                if doFlyStep(target.Position, lying, fixedY) then
                                    break
                                end
                                -- каждые ~0.1 сек поддерживаем no-collide на случай сброса
                                if tick() % 0.1 < 0.02 then setNoCollide(true) end
                                applyMicroJitter(hrp, fixedY)
                                task.wait()
                            end

                            -- Возвращаем физику только после прибытия
                            setNoCollide(false)
                            freezeForFly(false)

                            local ok = waitCollected(target, 1.0)
                            if ok then
                                farmCollected[target] = true
                            else
                                farmAttempts[target] = (farmAttempts[target] or 0) + 1
                                if farmAttempts[target] >= MAX_ATTEMPTS then
                                    farmCollected[target] = true
                                end
                            end

                            task.wait(0.3)
                        end
                    end
                end
            end
        end

        -- При выходе из цикла гарантированно сбрасываем физику
        freezeForFly(false)
        setNoCollide(false)
    end)
end

function stopAutoFarm()
    if State._farmThread then
        pcall(function() task.cancel(State._farmThread) end)
        State._farmThread = nil
    end
    farmCollected = {}
    farmAttempts = {}
    freezeForFly(false)
    setNoCollide(false)
end

-- ------------------------------------------------------------
-- Поиск предметов
-- ------------------------------------------------------------
local function isCandyPart(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("BasePart") then return false end
    local n = obj.Name
    return n == "Coin" or n == "Coin_" or n:find("Coin")
        or n:find("Candy") or n:find("Item") or n:find("Gift")
end

local function findItems()
    local items = {}
    local myChar = LocalPlayer.Character
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCandyPart(obj) then
            if not myChar or not obj:IsDescendantOf(myChar) then
                if not farmCollected[obj] then
                    table.insert(items, obj)
                end
            end
        end
    end
    return items
end

local function pickTarget(items, fromPos)
    if #items == 0 then return nil end
    if State.FarmOrder == "Random Item" then
        return items[math.random(1, #items)]
    end
    local best, bestDist = nil, math.huge
    for _, it in ipairs(items) do
        local d = (it.Position - fromPos).Magnitude
        if d < bestDist then best, bestDist = it, d end
    end
    return best
end

-- ------------------------------------------------------------
-- Безопасное включение/выключение физики
-- (используется ТОЛЬКО вокруг реального движения)
-- ------------------------------------------------------------
local function setNoCollide(on)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = not on end)
        end
    end
end

local function freezeForFly(on)
    local hum = getHumanoid()
    if hum then hum.PlatformStand = on end
end

-- ------------------------------------------------------------
-- Проверка успешного сбора: ждём, пока объект исчезнет
-- ------------------------------------------------------------
local function waitCollected(item, timeout)
    local deadline = tick() + (timeout or 2)
    while tick() < deadline do
        if not item or not item.Parent then
            return true
        end
        task.wait(0.05)
    end
    return false
end

-- ------------------------------------------------------------
-- Микродвижения (небольшие колебания, чтобы регистрировался Touch)
-- ------------------------------------------------------------
local microOffset = 0
local function applyMicroJitter(hrp, baseY)
    microOffset = microOffset + 0.15
    local dy = math.sin(microOffset) * 0.3
    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(hrp.Position.X, baseY + dy, hrp.Position.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- ------------------------------------------------------------
-- TELEPORT (обычный)
-- ------------------------------------------------------------
local function doTeleportNormal(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- ------------------------------------------------------------
-- UNDERGROUND TELEPORT
-- ------------------------------------------------------------
local function doTeleportUnderground(targetPos)
    local hrp = getHRP()
    if not hrp then return end
    local fixedCF = CFrame.new(targetPos.X, targetPos.Y - 4.5, targetPos.Z)
    hrp.CFrame = fixedCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    -- Держим позицию 0.5 сек, но без драки с потолком: только velocity=0
    local holdUntil = tick() + 0.5
    local holdThread = task.spawn(function()
        while tick() < holdUntil and State.AutoFarm and not State._closed do
            local h = getHRP()
            if h then
                h.CFrame = fixedCF
                h.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.05)
        end
    end)
    return holdThread
end

-- ------------------------------------------------------------
-- FLY (общий для Lying/Standing)
-- Возвращает true, если долетели до цели.
-- ------------------------------------------------------------
local function doFlyStep(targetPos, lying, fixedY)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end

    local current = hrp.Position
    local dir = Vector3.new(targetPos.X - current.X, 0, targetPos.Z - current.Z)
    if dir.Magnitude < 2 then
        return true
    end

    local speed = State.FarmSpeed
    local step = dir.Unit * speed * (RunService.Heartbeat:Wait() or 0.016)
    local newX = current.X + step.X
    local newZ = current.Z + step.Z

    local lookAt = Vector3.new(targetPos.X, fixedY, targetPos.Z)
    local newCF = CFrame.new(Vector3.new(newX, fixedY, newZ), lookAt)
    if lying then
        newCF = newCF * CFrame.Angles(0, 0, math.rad(90))
    end
    hrp.CFrame = newCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    return false
end

-- ------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
-- ------------------------------------------------------------
function startAutoFarm()
    stopAutoFarm()
    farmCollected = {}
    farmAttempts = {}

    State._farmThread = task.spawn(function()
        while State.AutoFarm and not State._closed do
            local hrp = getHRP()
            local hum = getHumanoid()

            -- Нет персонажа / умер / респавн — ждём, физику НЕ трогаем
            if not hrp or not hum or hum.Health <= 0 then
                freezeForFly(false)
                setNoCollide(false)
                task.wait(0.5)
            else
                local items = findItems()

                -- КОНФЕТ НЕТ — просто стоим, ничего не делаем
                if #items == 0 then
                    -- На всякий случай убеждаемся, что физика в норме
                    freezeForFly(false)
                    task.wait(0.4)
                else
                    local target = pickTarget(items, hrp.Position)
                    if not target then
                        task.wait(0.3)
                    else
                        local mode = State.FarmMode

                        -------------------------------------------------
                        -- TELEPORT
                        -------------------------------------------------
                        if mode == "Teleport" then
                            doTeleportNormal(target.Position)
                            waitCollected(target, 1.5)
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- UNDERGROUND TELEPORT
                        -------------------------------------------------
                        elseif mode == "Underground Teleport" then
                            local hold = doTeleportUnderground(target.Position)
                            waitCollected(target, 1.5)
                            if hold then pcall(function() task.cancel(hold) end) end
                            farmCollected[target] = true
                            task.wait(FARM_TP_INTERVAL)

                        -------------------------------------------------
                        -- FLY (Lying / Standing)
                        -------------------------------------------------
                        else
                            local lying = (mode == "Fly Lying")
                            -- Фиксируем высоту только если стоим на земле
                            local fixedY
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                fixedY = hrp.Position.Y + 2
                            else
                                fixedY = hrp.Position.Y  -- не поднимаем, если в воздухе
                            end

                            freezeForFly(true)
                            setNoCollide(true)

                            local deadline = tick() + 5
                            local reached = false
                            while State.AutoFarm and not State._closed and target.Parent do
                                if tick() > deadline then break end
                                if doFlyStep(target.Position, lying, fixedY) then
                                    reached = true
                                    break
                                end
                                applyMicroJitter(hrp, fixedY)
                                task.wait()
                            end

                            -- Возвращаем физику сразу после подлёта
                            setNoCollide(false)
                            freezeForFly(false)

                            -- Проверяем фактический сбор
                            local ok = waitCollected(target, 1.0)
                            if ok then
                                farmCollected[target] = true
                            else
                                farmAttempts[target] = (farmAttempts[target] or 0) + 1
                                if farmAttempts[target] >= MAX_ATTEMPTS then
                                    farmCollected[target] = true
                                end
                            end

                            task.wait(0.3)
                        end
                    end
                end
            end
        end

        -- При выходе из цикла гарантированно сбрасываем физику
        freezeForFly(false)
        setNoCollide(false)
    end)
end

function stopAutoFarm()
    if State._farmThread then
        task.cancel(State._farmThread)
        State._farmThread = nil
    end
    farmCollected = {}
    farmAttempts = {}
    freezeForFly(false)
    setNoCollide(false)
    -- На случай, если остались BodyVelocity — не трогаем, они самоудалятся
end

-- ============================================================
-- ESP ROLES (подсветка тела сквозь стены)
-- ============================================================
local function createESPForPlayer(plr)
    if plr == LocalPlayer then return end
    if State._espObjects[plr] then return end
    if not plr.Character then return end

    local role = getRole(plr)
    local color = roleColor(role)

    local highlight = Instance.new("Highlight")
    highlight.Name = "MM2_ESP_" .. plr.Name
    highlight.Adornee = plr.Character
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = plr.Character

    State._espObjects[plr] = {highlight = highlight, role = role, character = plr.Character}
end

local function updateESPForPlayer(plr)
    local data = State._espObjects[plr]
    if not data then return end

    -- Персонаж сменился (респавн) — пересоздаём
    if not plr.Character or data.character ~= plr.Character then
        removeESPForPlayer(plr)
        createESPForPlayer(plr)
        return
    end

    -- Роль сменилась (например, шериф подобрал Gun) — обновляем цвет
    local role = getRole(plr)
    if role ~= data.role then
        local color = roleColor(role)
        data.highlight.FillColor = color
        data.highlight.OutlineColor = color
        data.role = role
    end
end

local function removeESPForPlayer(plr)
    local data = State._espObjects[plr]
    if data then
        pcall(function() data.highlight:Destroy() end)
        State._espObjects[plr] = nil
    end
end

function startESP()
    stopESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        createESPForPlayer(plr)
        updateESPForPlayer(plr)
    end
    trackConn(Players.PlayerAdded:Connect(function(plr)
        task.wait(1)
        if State.ESPRoles then createESPForPlayer(plr); updateESPForPlayer(plr) end
    end))
    trackConn(Players.PlayerRemoving:Connect(function(plr) removeESPForPlayer(plr) end))

    State._espThread = task.spawn(function()
        while State.ESPRoles and not State._closed do
            task.wait(0.5)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    if not State._espObjects[plr] then createESPForPlayer(plr) end
                    updateESPForPlayer(plr)
                end
            end
        end
    end)
end

function stopESP()
    if State._espThread then
        pcall(function() task.cancel(State._espThread) end)
        State._espThread = nil
    end
    for plr, data in pairs(State._espObjects) do
        pcall(function() data.highlight:Destroy() end)
    end
    State._espObjects = {}
end

-- ============================================================
-- SHOW NICKNAMES
-- ============================================================
local function createNicknameForPlayer(plr)
    if plr == LocalPlayer then return end
    if State._nicknameObjects[plr] then return end
    if not plr.Character then return end
    local head = plr.Character:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MM2_Nick_" .. plr.Name
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 200
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = plr.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextStrokeTransparency = 0.3
    label.Parent = billboard

    State._nicknameObjects[plr] = {billboard = billboard, label = label}
end

local function removeNicknameForPlayer(plr)
    local data = State._nicknameObjects[plr]
    if data then
        pcall(function() data.billboard:Destroy() end)
        State._nicknameObjects[plr] = nil
    end
end

function startNicknames()
    stopNicknames()
    for _, plr in ipairs(Players:GetPlayers()) do createNicknameForPlayer(plr) end
    trackConn(Players.PlayerAdded:Connect(function(plr)
        task.wait(1)
        if State.ShowNicknames then createNicknameForPlayer(plr) end
    end))
    trackConn(Players.PlayerRemoving:Connect(function(plr) removeNicknameForPlayer(plr) end))

    State._nicknameThread = task.spawn(function()
        while State.ShowNicknames and not State._closed do
            task.wait(1)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and not State._nicknameObjects[plr] then
                    createNicknameForPlayer(plr)
                end
            end
        end
    end)
end

function stopNicknames()
    if State._nicknameThread then
        pcall(function() task.cancel(State._nicknameThread) end)
        State._nicknameThread = nil
    end
    for plr, data in pairs(State._nicknameObjects) do
        pcall(function() data.billboard:Destroy() end)
    end
    State._nicknameObjects = {}
end

-- ============================================================
-- AIM ASSIST
-- ============================================================
-- Примечание: гарантированное «попадание» невозможно на клиенте без
-- серверного RemoteEvent. Здесь — наведение камеры и попытка
-- вызвать Tool:Activate() на пистолете, когда убийца в поле зрения.
function startAimAssist()
    stopAimAssist()
    State._aimAssistConn = RunService.RenderStepped:Connect(function()
        if not State.AimAssist or State._closed then return end
        local murderer = nil
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and getRole(plr) == "Murderer" and plr.Character then
                local hrp = getHRP(plr)
                if hrp then murderer = hrp; break end
            end
        end
        if not murderer then return end
        -- Наводим камеру на убийцу
        local myHRP = getHRP()
        if not myHRP then return end
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, murderer.Position)
        -- Пытаемся активировать пистолет, если он в руках
        local char = LocalPlayer.Character
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == "Gun" then
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end)
    table.insert(State._connections, State._aimAssistConn)
end

function stopAimAssist()
    if State._aimAssistConn then
        pcall(function() State._aimAssistConn:Disconnect() end)
        State._aimAssistConn = nil
    end
end

-- ============================================================
-- GET GUN (последовательность)
-- ============================================================
-- Примечание: физическое выталкивание ЧУЖОГО игрока (шерифа) клиентом
-- ненадёжно — сервер может откатить. Реализовано через BodyVelocity
-- на HumanoidRootPart шерифа + вращение своего персонажа.
function getGunSequence()
    local myChar = LocalPlayer.Character
    local myHRP = getHRP()
    if not myChar or not myHRP then return end
    local startCFrame = myHRP.CFrame

    -- Ищем шерифа
    local sheriff = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and getRole(plr) == "Sheriff" then
            sheriff = plr; break
        end
    end
    if not sheriff then return end
    local sheriffHRP = getHRP(sheriff)
    if not sheriffHRP then return end

    -- 1. Вращение своего персонажа (для вида)
    local spinConn
    spinConn = RunService.Heartbeat:Connect(function()
        if myHRP and myHRP.Parent then
            myHRP.CFrame = myHRP.CFrame * CFrame.Angles(0, math.rad(30), 0)
        end
    end)

    -- 2. Выталкивание шерифа
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.new(0, 500, 0)
    bv.Parent = sheriffHRP

    task.delay(2, function()
        if spinConn then spinConn:Disconnect() end
        pcall(function() bv:Destroy() end)
    end)

    -- 3. Ждём, пока шериф умрёт, затем ищем выпавший пистолет
    task.spawn(function()
        local timeout = tick() + 15
        while tick() < timeout and not State._closed do
            task.wait(0.3)
            local gun = nil
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Tool") and obj.Name == "Gun" and not obj:IsDescendantOf(LocalPlayer.Character) then
                    gun = obj; break
                end
            end
            if gun then
                local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
                if handle and myHRP then
                    pcall(function()
                        myHRP.CFrame = CFrame.new(handle.Position + Vector3.new(0, 3, 0))
                    end)
                    task.wait(1)
                end
                break
            end
        end
        -- 4. Возврат на исходную позицию
        if myHRP and myHRP.Parent then
            pcall(function() myHRP.CFrame = startCFrame end)
        end
    end)
end

-- ============================================================
-- KILL (попытка)
-- ============================================================
-- Примечание: убийство обрабатывается сервером MM2. Клиент может
-- лишь телепортироваться к цели и активировать нож. Гарантий нет.
function attemptKill(target)
    if not target or target == LocalPlayer then return end
    local myHRP = getHRP()
    local targetHRP = getHRP(target)
    if not myHRP or not targetHRP then return end
    local targetHum = getHumanoid(target)
    if not targetHum or targetHum.Health <= 0 then return end

    pcall(function()
        myHRP.CFrame = CFrame.new(targetHRP.Position + Vector3.new(0, 0, 2))
    end)
    task.wait(0.1)
    local char = LocalPlayer.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Knife" then
                pcall(function() tool:Activate() end)
            end
        end
    end
end

-- ============================================================
-- FLING (попытка)
-- ============================================================
-- Примечание: классический fling работает нестабильно и часто
-- блокируется анти-читом. Реализовано через BodyVelocity.
function attemptFling(target)
    if not target or target == LocalPlayer then return end
    local targetHRP = getHRP(target)
    if not targetHRP then return end
    pcall(function()
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e7, 1e7, 1e7)
        bv.Velocity = Vector3.new(
            (math.random() - 0.5) * 2000,
            2000,
            (math.random() - 0.5) * 2000
        )
        bv.Parent = targetHRP
        task.delay(1, function() pcall(function() bv:Destroy() end) end)
    end)
end

-- ============================================================
-- СВОРАЧИВАНИЕ / ЗАКРЫТИЕ
-- ============================================================
minimizeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    floatingIcon.Visible = true
end)

floatingIcon.MouseButton1Click:Connect(function()
    floatingIcon.Visible = false
    mainFrame.Visible = true
end)

local function disconnectAll()
    for _, c in ipairs(State._connections) do
        pcall(function()
            if typeof(c) == "RBXScriptConnection" then
                c:Disconnect()
            elseif type(c) == "table" and c.Disconnect then
                c.Disconnect()
            end
        end)
    end
    State._connections = {}
end

function fullShutdown()
    State._closed = true
    State.AutoFarm = false
    State.AntiAFK = false
    State.ESPRoles = false
    State.ShowNicknames = false
    State.AimAssist = false

    stopAutoFarm()
    stopAntiAFK()
    stopESP()
    stopNicknames()
    stopAimAssist()

    disconnectAll()

    for _, obj in ipairs(GUIObjects) do
        pcall(function() obj:Destroy() end)
    end
    GUIObjects = {}

    pcall(function() screenGui:Destroy() end)
end

closeBtn.MouseButton1Click:Connect(function()
    fullShutdown()
end)

-- ============================================================
-- ОЧИСТКА ПРИ ВЫХОДЕ
-- ============================================================
trackConn(LocalPlayer.OnTeleport:Connect(function()
    -- Не отключаем при телепорте, только при явном закрытии
end))

-- ============================================================
-- ОЧИСТКА ПРИ ВЫХОДЕ
-- ============================================================
trackConn(LocalPlayer.OnTeleport:Connect(function()
    -- Не отключаем при телепорте, только при явном закрытии
end))
