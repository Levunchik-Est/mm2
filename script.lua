--[[
    MM2 GUI — Murder Mystery 2
    Полный клиентский скрипт для executor.
    Все функции из ТЗ реализованы в меру возможностей клиента.
    Функции, требующие серверного доступа, помечены в комментариях.
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
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ (единая точка управления)
-- ============================================================
local State = {
    -- Farm
    AutoFarm = false,
    FarmMode = "Fly — лежа",     -- "Fly — лежа" | "Fly — стоя" | "Teleport" | "Underground Teleport"
    FarmSpeed = 35,
    FarmOrder = "Nearest Item",   -- "Nearest Item" | "Random Item"
    AntiAFK = false,
    -- Visuals
    ESPRoles = false,
    ShowNicknames = false,
    -- Sheriff
    AimAssist = false,
    -- Murderer
    -- (нет постоянных состояний, только кнопки)
    -- Fun
    -- (нет постоянных состояний, только кнопки)
    
    -- Внутренние
    _connections = {},
    _espObjects = {},
    _nicknameObjects = {},
    _farmRunning = false,
    _antiAFKLoop = nil,
    _aimAssistConn = nil,
    _flingRunning = false,
}

-- Список всех созданных объектов GUI для полной очистки
local GUIObjects = {}

local function track(obj)
    table.insert(GUIObjects, obj)
    return obj
end

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
local function getHRP(plr)
    plr = plr or LocalPlayer
    if plr.Character then
        return plr.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getHumanoid(plr)
    plr = plr or LocalPlayer
    if plr.Character then
        return plr.Character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

-- Определение роли игрока (эвристика: Knife/Gun в Character или Backpack)
local function getRole(plr)
    if not plr or not plr.Character then return "Innocent" end
    local char = plr.Character
    local backpack = plr:FindFirstChild("Backpack")
    
    local function hasTool(name)
        if char:FindFirstChild(name) then return true end
        if backpack and backpack:FindFirstChild(name) then return true end
        return false
    end
    
    if hasTool("Knife") then return "Murderer" end
    if hasTool("Gun") then return "Sheriff" end
    return "Innocent"
end

local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 60, 60) end
    if role == "Sheriff" then return Color3.fromRGB(60, 120, 255) end
    return Color3.fromRGB(80, 255, 80)
end

-- Безопасное добавление Connection в State._connections
local function trackConn(conn)
    table.insert(State._connections, conn)
    return conn
end

-- Полная очистка всех соединений
local function disconnectAll()
    for _, conn in ipairs(State._connections) do
        pcall(function() conn:Disconnect() end)
    end
    State._connections = {}
end

-- ============================================================
-- БАЗОВЫЙ GUI (ScreenGui, Main Frame, TitleBar, Nav)
-- ============================================================
local screenGui = track(Instance.new("ScreenGui"))
screenGui.Name = "MM2_GUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- Плавающая иконка (для свёрнутого режима)
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

-- Главное окно
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

-- Заголовок (для перетаскивания)
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

-- Кнопка "−" (свернуть)
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

-- Кнопка "X" (закрыть)
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

-- ============================================================
-- НАВИГАЦИЯ (5 категорий)
-- ============================================================
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

-- Контентная область
local contentArea = track(Instance.new("Frame"))
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -138, 1, -48)
contentArea.Position = UDim2.new(0, 138, 0, 44)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- Контейнеры для каждой категории
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

-- Выделить первую категорию
categories["Farm"].button.BackgroundColor3 = Color3.fromRGB(55, 55, 78)
categories["Farm"].button.TextColor3 = Color3.fromRGB(255, 255, 255)

-- ============================================================
-- ФАБРИКИ UI-ЭЛЕМЕНТОВ
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
        callback(state)
    end

    switch.MouseButton1Click:Connect(function()
        setState(not state)
    end)

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
        local rel = math.clamp((mouseX - absPos) / absSize, 0, 1)
        local val = math.floor(min + rel * (max - min) + 0.5)
        currentValue = val
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valueLabel.Text = tostring(val)
        callback(val)
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

    return {frame = frame, getValue = function() return currentValue end, setValue = function(v)
        local rel = math.clamp((v - min) / (max - min), 0, 1)
        currentValue = v
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        valueLabel.Text = tostring(v)
        callback(v)
    end}
end

local function createDropdown(parent, text, options, default, callback)
    local frame = track(Instance.new("Frame"))
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = track(Instance.new("TextLabel"))
    label.Size = UDim2.new(1, -120, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
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
    btn.Parent = frame
    local bc = track(Instance.new("UICorner"))
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = btn

    local list = track(Instance.new("Frame"))
    list.Size = UDim2.new(0, 115, 0, 0)
    list.Position = UDim2.new(1, -115, 1, 2)
    list.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    list.BorderSizePixel = 0
    list.ClipsDescendants = true
    list.Visible = false
    list.ZIndex = 10
    list.Parent = frame
    local lc = track(Instance.new("UICorner"))
    lc.CornerRadius = UDim.new(0, 5)
    lc.Parent = list

    local listLayout = track(Instance.new("UIListLayout"))
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local selected = default
    local itemButtons = {}

    local function rebuildOptions(newOptions)
        for _, b in ipairs(itemButtons) do
            pcall(function() b:Destroy() end)
        end
        itemButtons = {}
        for i, opt in ipairs(newOptions) do
            local item = track(Instance.new("TextButton"))
            item.Size = UDim2.new(1, 0, 0, 26)
            item.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            item.BorderSizePixel = 0
            item.Text = opt
            item.TextColor3 = Color3.fromRGB(200, 200, 210)
            item.TextSize = 12
            item.Font = Enum.Font.Gotham
            item.ZIndex = 11
            item.Parent = list
            item.MouseButton1Click:Connect(function()
                selected = opt
                btn.Text = opt
                list.Visible = false
                list.Size = UDim2.new(0, 115, 0, 0)
                callback(opt)
            end)
            table.insert(itemButtons, item)
        end
    end

    rebuildOptions(options)

    btn.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        if list.Visible then
            local targetHeight = #itemButtons * 26
            TweenService:Create(list, TweenInfo.new(0.15), {Size = UDim2.new(0, 115, 0, targetHeight)}):Play()
        else
            TweenService:Create(list, TweenInfo.new(0.15), {Size = UDim2.new(0, 115, 0, 0)}):Play()
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

    btn.MouseButton1Click:Connect(function()
        callback()
    end)
    return btn
end

-- ============================================================
-- НАПОЛНЕНИЕ: FARM
-- ============================================================
local farmContent = categories["Farm"].container

createToggle(farmContent, "Auto Farm", false, function(v)
    State.AutoFarm = v
    if v then
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

createDropdown(farmContent, "Режим движения", {"Fly — лежа", "Fly — стоя", "Teleport", "Underground Teleport"}, "Fly — лежа", function(v)
    State.FarmMode = v
end)

createSlider(farmContent, "Скорость (10–60 studs/s)", 10, 60, 35, function(v)
    State.FarmSpeed = v
end)

createDropdown(farmContent, "Порядок сбора", {"Nearest Item", "Random Item"}, "Nearest Item", function(v)
    State.FarmOrder = v
end)

createToggle(farmContent, "Anti-AFK", false, function(v)
    State.AntiAFK = v
    if v then
        startAntiAFK()
    else
        stopAntiAFK()
    end
end)

-- ============================================================
-- НАПОЛНЕНИЕ: VISUALS
-- ============================================================
local visualsContent = categories["Visuals"].container

createToggle(visualsContent, "ESP Roles", false, function(v)
    State.ESPRoles = v
    if v then
        startESP()
    else
        stopESP()
    end
end)

createToggle(visualsContent, "Show Nicknames", false, function(v)
    State.ShowNicknames = v
    if v then
        startNicknames()
    else
        stopNicknames()
    end
end)

-- ============================================================
-- НАПОЛНЕНИЕ: SHERIFF
-- ============================================================
local sheriffContent = categories["Sheriff"].container

createToggle(sheriffContent, "Aim Assist (на убийцу)", false, function(v)
    State.AimAssist = v
    if v then
        startAimAssist()
    else
        stopAimAssist()
    end
end)

createButton(sheriffContent, "Get Gun ( Sheriff )", function()
    getGunSequence()
end)

-- ============================================================
-- НАПОЛНЕНИЕ: MURDERER
-- ============================================================
local murdererContent = categories["Murderer"].container

local playerDropdownKill = createDropdown(murdererContent, "Выбрать игрока", {}, nil, function(v) end)

createButton(murdererContent, "Kill Selected Player", function()
    local targetName = playerDropdownKill.getSelected()
    if targetName then
        local target = Players:FindFirstChild(targetName)
        if target then
            attemptKill(target)
        end
    end
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
    State._flingRunning = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            attemptFling(plr)
            task.wait(0.05)
        end
    end
    task.delay(2, function() State._flingRunning = false end)
end)

local playerDropdownFling = createDropdown(funContent, "Выбрать игрока", {}, nil, function(v) end)

createButton(funContent, "Fling Selected Player", function()
    local targetName = playerDropdownFling.getSelected()
    if targetName then
        local target = Players:FindFirstChild(targetName)
        if target then
            attemptFling(target)
        end
    end
end)

-- ============================================================
-- ОБНОВЛЕНИЕ СПИСКОВ ИГРОКОВ (Dropdown)
-- ============================================================
local function refreshPlayerDropdowns()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    if #names == 0 then names = {"(нет игроков)"} end
    playerDropdownKill.refresh(names)
    playerDropdownFling.refresh(names)
end

trackConn(Players.PlayerAdded:Connect(function() task.wait(1); refreshPlayerDropdowns() end))
trackConn(Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshPlayerDropdowns() end))
task.spawn(function() task.wait(2); refreshPlayerDropdowns() end)

-- ============================================================
-- РЕАЛИЗАЦИЯ: ANTI-AFK
-- ============================================================
function startAntiAFK()
    stopAntiAFK()
    State._antiAFKLoop = task.spawn(function()
        while State.AntiAFK do
            task.wait(600) -- 10 минут
            if not State.AntiAFK then break end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end)
end

function stopAntiAFK()
    if State._antiAFKLoop then
        task.cancel(State._antiAFKLoop)
        State._antiAFKLoop = nil
    end
end

-- ============================================================
-- РЕАЛИЗАЦИЯ: ESP ROLES
-- ============================================================
local function createESPForPlayer(plr)
    if plr == LocalPlayer then return end
    if State._espObjects[plr] then return end
    if not plr.Character then return end
    local head = plr.Character:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MM2_ESP_" .. plr.Name
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.P
