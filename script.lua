-- ============================================================
-- MM2 Automation Hub (final clean build)
-- Tabs: Farm / Visuals / Murderer / Sheriff
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    CANDY_FARM_INTERVAL = 2.0,
    CANDY_SEARCH_RADIUS = 300,
    ANTI_AFK_INTERVAL = 600,
    MAX_CANDY_LIMIT = 200,
    LOBBY_POSITION = Vector3.new(0, 10, 0),
    ESP_UPDATE_INTERVAL = 0.5,
    COLLECT_NUDGE_DURATION = 0.15,
}

local ESP_COLORS = {
    Murderer = Color3.fromRGB(255, 0, 0),
    Sheriff  = Color3.fromRGB(0, 120, 255),
    Innocent = Color3.fromRGB(0, 220, 80),
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    CandyFarmEnabled = false,
    AntiAFKEnabled = false,
    ESPEnabled = false,
    IsMinimized = false,
    IsClosed = false,
    CandyFarmThread = nil,
    AntiAFKThread = nil,
    ESPThread = nil,
    CandyCount = 0,
    ESPHighlights = {},
    CurrentCharacter = nil,
}

-- ============================================================
-- CHARACTER REFRESH
-- ============================================================
State.CurrentCharacter = LocalPlayer.Character
LocalPlayer.CharacterAdded:Connect(function(character)
    State.CurrentCharacter = character
end)

-- ============================================================
-- GUI ROOT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Automation_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ZIndex = 1
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 70)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- ============================================================
-- TITLE BAR
-- ============================================================
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.ZIndex = 10
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleFix.BorderSizePixel = 0
TitleFix.ZIndex = 10
TitleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MM2 Automation"
TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 11
TitleLabel.Parent = TitleBar

-- ============================================================
-- DRAG ZONE (separate Frame covering only left part of title bar)
-- ============================================================
local DragZone = Instance.new("Frame")
DragZone.Name = "DragZone"
DragZone.Size = UDim2.new(1, -80, 1, 0)
DragZone.Position = UDim2.new(0, 0, 0, 0)
DragZone.BackgroundTransparency = 1
DragZone.Active = true
DragZone.ZIndex = 12
DragZone.Parent = TitleBar

local dragging = false
local dragStart = nil
local startPos = nil

DragZone.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

DragZone.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

DragZone.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- MIN / CLOSE BUTTONS (visible, AutoButtonColor for hover)
-- ============================================================
local MinButton = Instance.new("TextButton")
MinButton.Name = "MinButton"
MinButton.Size = UDim2.new(0, 30, 0, 28)
MinButton.Position = UDim2.new(1, -66, 0, 3)
MinButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
MinButton.BorderSizePixel = 0
MinButton.Text = "−"
MinButton.TextColor3 = Color3.fromRGB(200, 200, 210)
MinButton.TextSize = 20
MinButton.Font = Enum.Font.GothamBold
MinButton.AutoButtonColor = true
MinButton.Active = true
MinButton.ZIndex = 100
MinButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinButton

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 28)
CloseButton.Position = UDim2.new(1, -34, 0, 3)
CloseButton.BackgroundColor3 = Color3.fromRGB(80, 45, 45)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 140, 140)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.AutoButtonColor = true
CloseButton.Active = true
CloseButton.ZIndex = 100
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseButton

-- ============================================================
-- DRAG (only left zone of title bar; buttons excluded)
-- ============================================================
local dragging = false
local dragStart = nil
local startPos = nil
local BUTTON_ZONE_START = 1 - (80 / 300)

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        local relX = (input.Position.X - TitleBar.AbsolutePosition.X) / TitleBar.AbsoluteSize.X
        if relX >= BUTTON_ZONE_START then return end
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- TAB BAR
-- ============================================================
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 32)
TabBar.Position = UDim2.new(0, 0, 0, 35)
TabBar.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 5
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Parent = TabBar

local Tabs = {}
local ActiveTab = nil

local function SetActiveTab(name)
    if not Tabs[name] then return end
    for tabName, tabData in pairs(Tabs) do
        if tabName == name then
            tabData.button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            tabData.button.TextColor3 = Color3.fromRGB(255, 255, 255)
            tabData.content.Visible = true
        else
            tabData.button.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
            tabData.button.TextColor3 = Color3.fromRGB(150, 150, 160)
            tabData.content.Visible = false
        end
    end
    ActiveTab = name
end

local function CreateTab(name, order)
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(0, 75, 1, 0)
    button.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
    button.BorderSizePixel = 0
    button.Text = name
    button.TextColor3 = Color3.fromRGB(150, 150, 160)
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.LayoutOrder = order
    button.ZIndex = 6
    button.Parent = TabBar

    button.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            button.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
        end
    end)
    button.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            button.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
        end
    end)

    local content = Instance.new("Frame")
    content.Name = name .. "Content"
    content.Size = UDim2.new(1, -20, 1, -85)
    content.Position = UDim2.new(0, 10, 0, 75)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.ZIndex = 2
    content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = content

    Tabs[name] = { button = button, content = content }

    button.MouseButton1Click:Connect(function()
        if State.IsClosed then return end
        SetActiveTab(name)
    end)

    return content
end

local FarmTab = CreateTab("Farm", 1)
local VisualsTab = CreateTab("Visuals", 2)
local MurdererTab = CreateTab("Murderer", 3)
local SheriffTab = CreateTab("Sheriff", 4)

-- ============================================================
-- TOGGLE HELPER
-- ============================================================
local function CreateToggle(parent, labelText, initialValue, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, -8, 0, 45)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.ZIndex = 4
    ToggleFrame.Parent = parent

    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 6)
    c1.Parent = ToggleFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 210)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = ToggleFrame

    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 44, 0, 24)
    switchBg.Position = UDim2.new(1, -56, 0.5, -12)
    switchBg.BackgroundColor3 = initialValue and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(70, 70, 78)
    switchBg.BorderSizePixel = 0
    switchBg.ZIndex = 5
    switchBg.Parent = ToggleFrame

    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(1, 0)
    c2.Parent = switchBg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 6
    knob.Parent = switchBg

    local c3 = Instance.new("UICorner")
    c3.CornerRadius = UDim.new(1, 0)
    c3.Parent = knob

    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.ZIndex = 10
    clickArea.Active = true
    clickArea.Parent = ToggleFrame

    local currentValue = initialValue

    local function updateVisual(value)
        if value then
            switchBg.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
            knob.Position = UDim2.new(1, -21, 0.5, -9)
        else
            switchBg.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
            knob.Position = UDim2.new(0, 3, 0.5, -9)
        end
    end

    clickArea.MouseButton1Click:Connect(function()
        if State.IsClosed then return end
        currentValue = not currentValue
        updateVisual(currentValue)
        if callback then callback(currentValue) end
    end)

    return ToggleFrame, function(val)
        currentValue = val
        updateVisual(val)
    end
end

-- ============================================================
-- PLACEHOLDER HELPER
-- ============================================================
local function CreatePlaceholder(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -8, 0, 45)
    lbl.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    lbl.BorderSizePixel = 0
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(110, 110, 120)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamItalic
    lbl.ZIndex = 4
    lbl.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = lbl

    return lbl
end

-- ============================================================
-- CANDY FARM
-- ============================================================
local function GetAllCandies()
    local character = State.CurrentCharacter or LocalPlayer.Character
    if not character then return {} end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return {} end

    local candies = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("candy") or name:find("coin") then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and part.Transparency < 0.5 then
                    local dist = (rootPart.Position - part.Position).Magnitude
                    if dist <= CONFIG.CANDY_SEARCH_RADIUS then
                        table.insert(candies, part)
                    end
                end
            end
        end
    end
    return candies
end

local function GetRandomCandy()
    local candies = GetAllCandies()
    if #candies == 0 then return nil end
    return candies[math.random(1, #candies)]
end

local function TeleportToAndCollect(targetPart)
    local character = State.CurrentCharacter or LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local ok = pcall(function()
        character:PivotTo(CFrame.new(targetPart.Position + Vector3.new(0, 2, 0)))
    end)
    if not ok then return false end

    local origCollide = rootPart.CanCollide
    rootPart.CanCollide = true
    task.wait(CONFIG.COLLECT_NUDGE_DURATION)
    pcall(function()
        rootPart.CFrame = rootPart.CFrame * CFrame.new(0, -1, 0)
    end)
    task.wait(0.05)
    rootPart.CanCollide = origCollide
    return true
end

local function TeleportToLobby()
    local character = State.CurrentCharacter or LocalPlayer.Character
    if not character then return end
    pcall(function()
        character:PivotTo(CFrame.new(CONFIG.LOBBY_POSITION))
    end)
end

local CandyFarmToggleUpdate

local function StartCandyFarm()
    if State.CandyFarmThread then task.cancel(State.CandyFarmThread) end
    State.CandyCount = 0
    State.CandyFarmThread = task.spawn(function()
        while State.CandyFarmEnabled and not State.IsClosed do
            local character = State.CurrentCharacter or LocalPlayer.Character
            if not character then task.wait(1) continue end
            local candy = GetRandomCandy()
            if candy then
                if TeleportToAndCollect(candy) then
                    State.CandyCount = State.CandyCount + 1
                    if State.CandyCount >= CONFIG.MAX_CANDY_LIMIT then
                        State.CandyFarmEnabled = false
                        if CandyFarmToggleUpdate then CandyFarmToggleUpdate(false) end
                        TeleportToLobby()
                        break
                    end
                end
            end
            task.wait(CONFIG.CANDY_FARM_INTERVAL)
        end
    end)
end

local function StopCandyFarm()
    State.CandyFarmEnabled = false
    if State.CandyFarmThread then
        task.cancel(State.CandyFarmThread)
        State.CandyFarmThread = nil
    end
end

-- ============================================================
-- ANTI-AFK
-- ============================================================
local function StartAntiAFK()
    if State.AntiAFKThread then task.cancel(State.AntiAFKThread) end
    State.AntiAFKThread = task.spawn(function()
        while State.AntiAFKEnabled and not State.IsClosed do
            task.wait(CONFIG.ANTI_AFK_INTERVAL)
            if State.IsClosed or not State.AntiAFKEnabled then break end
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
            print("[MM2] Anti-AFK pulse sent.")
        end
    end)
end

local function StopAntiAFK()
    State.AntiAFKEnabled = false
    if State.AntiAFKThread then
        task.cancel(State.AntiAFKThread)
        State.AntiAFKThread = nil
    end
end

-- ============================================================
-- ROLE DETECTION (Backpack + Character)
-- ============================================================
local function GetPlayerRole(player)
    if player == LocalPlayer then return nil end
    local character = player.Character
    if not character then return nil end

    local attrRole = character:GetAttribute("Role") or player:GetAttribute("Role")
    if type(attrRole) == "string" then
        local r = attrRole:lower()
        if r:find("murder") or r:find("killer") then return "Murderer" end
        if r:find("sheriff") or r:find("cop") then return "Sheriff" end
        if r:find("innocent") then return "Innocent" end
    end

    local function hasTool(container, toolName)
        if not container then return false end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") then
                if child.Name:lower():find(toolName) then return true end
            end
        end
        return false
    end

    local backpack = player:FindFirstChild("Backpack")

    if hasTool(character, "knife") or hasTool(backpack, "knife") then
        return "Murderer"
    end
    if hasTool(character, "gun") or hasTool(character, "revolver") or hasTool(character, "pistol")
    or hasTool(backpack, "gun") or hasTool(backpack, "revolver") or hasTool(backpack, "pistol") then
        return "Sheriff"
    end

    local tags = {}
    pcall(function()
        for _, tag in ipairs(game:GetService("CollectionService"):GetTags(character)) do
            table.insert(tags, tag:lower())
        end
    end)
    for _, t in ipairs(tags) do
        if t:find("murder") or t:find("killer") then return "Murderer" end
        if t:find("sheriff") or t:find("cop") then return "Sheriff" end
        if t:find("innocent") then return "Innocent" end
    end

    return "Innocent"
end

-- ============================================================
-- ESP
-- ============================================================
local function ClearAllHighlights()
    for _, hl in pairs(State.ESPHighlights) do
        pcall(function() hl:Destroy() end)
    end
    State.ESPHighlights = {}
end

local function UpdateESP()
    if State.IsClosed or not State.ESPEnabled then return end

    for player, hl in pairs(State.ESPHighlights) do
        if not player.Parent or not player.Character then
            pcall(function() hl:Destroy() end)
            State.ESPHighlights[player] = nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local role = GetPlayerRole(player)
            if role then
                local color = ESP_COLORS[role]
                local existing = State.ESPHighlights[player]
                if existing and existing.Parent then
                    existing.FillColor = color
                    existing.OutlineColor = color
                else
                    local hl = Instance.new("Highlight")
                    hl.Name = "MM2_RoleESP_" .. player.Name
                    hl.Adornee = player.Character
                    hl.FillColor = color
                    hl.FillTransparency = 0.6
                    hl.OutlineColor = color
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = player.Character
                    State.ESPHighlights[player] = hl
                end
            else
                local existing = State.ESPHighlights[player]
                if existing then
                    pcall(function() existing:Destroy() end)
                    State.ESPHighlights[player] = nil
                end
            end
        end
    end
end

local function StartESP()
    if State.ESPThread then task.cancel(State.ESPThread) end
    State.ESPThread = task.spawn(function()
        while State.ESPEnabled and not State.IsClosed do
            UpdateESP()
            task.wait(CONFIG.ESP_UPDATE_INTERVAL)
        end
    end)
end

local function StopESP()
    State.ESPEnabled = false
    if State.ESPThread then
        task.cancel(State.ESPThread)
        State.ESPThread = nil
    end
    ClearAllHighlights()
end

-- ============================================================
-- TP TO MURDERER
-- ============================================================
local function TeleportToMurderer()
    local localChar = State.CurrentCharacter or LocalPlayer.Character
    if not localChar then return end

    local murdererPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if GetPlayerRole(player) == "Murderer" then
                murdererPlayer = player
                break
            end
        end
    end

    if not murdererPlayer then
        print("[MM2] Murderer not found.")
        return
    end

    local murdererRoot = murdererPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererRoot then return end

    pcall(function()
        localChar:PivotTo(murdererRoot.CFrame * CFrame.new(0, 0, -3))
    end)
    print("[MM2] Teleported to murderer: " .. murdererPlayer.Name)
end

-- ============================================================
-- BUILD FARM TAB
-- ============================================================
local candyToggle, candyUpdater = CreateToggle(
    FarmTab, "🍬 Candy Auto Farm", false,
    function(value)
        State.CandyFarmEnabled = value
        if value then StartCandyFarm() else StopCandyFarm() end
    end
)
CandyFarmToggleUpdate = candyUpdater
candyToggle.LayoutOrder = 1

local antiAFKToggle, antiAFKUpdater = CreateToggle(
    FarmTab, "🛡️ Anti-AFK", false,
    function(value)
        State.AntiAFKEnabled = value
        if value then StartAntiAFK() else StopAntiAFK() end
    end
)
antiAFKToggle.LayoutOrder = 2

-- ============================================================
-- BUILD VISUALS TAB
-- ============================================================
local espToggle, espUpdater = CreateToggle(
    VisualsTab, "👁️ Role ESP", false,
    function(value)
        State.ESPEnabled = value
        if value then StartESP() else StopESP() end
    end
)
espToggle.LayoutOrder = 1

local legend = Instance.new("Frame")
legend.Size = UDim2.new(1, -8, 0, 75)
legend.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
legend.BorderSizePixel = 0
legend.LayoutOrder = 2
legend.ZIndex = 4
legend.Parent = VisualsTab

local legendCorner = Instance.new("UICorner")
legendCorner.CornerRadius = UDim.new(0, 6)
legendCorner.Parent = legend

local function MakeLegendRow(y, color, text)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 12, 0, y)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.ZIndex = 5
    dot.Parent = legend
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = dot

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -30, 0, 14)
    lbl.Position = UDim2.new(0, 28, 0, y - 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5
    lbl.Parent = legend
end

MakeLegendRow(8, ESP_COLORS.Murderer, "Murderer")
MakeLegendRow(28, ESP_COLORS.Sheriff, "Sheriff")
MakeLegendRow(48, ESP_COLORS.Innocent, "Innocent")

-- ============================================================
-- BUILD MURDERER TAB
-- ============================================================
local tpFrame = Instance.new("Frame")
tpFrame.Size = UDim2.new(1, -8, 0, 45)
tpFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
tpFrame.BorderSizePixel = 0
tpFrame.LayoutOrder = 1
tpFrame.ZIndex = 4
tpFrame.Parent = MurdererTab

local tpc = Instance.new("UICorner")
tpc.CornerRadius = UDim.new(0, 6)
tpc.Parent = tpFrame

local tpButton = Instance.new("TextButton")
tpButton.Size = UDim2.new(1, -16, 1, -10)
tpButton.Position = UDim2.new(0, 8, 0, 5)
tpButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
tpButton.Text = "🎯 TP к убийце (одноразово)"
tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpButton.TextSize = 13
tpButton.Font = Enum.Font.GothamBold
tpButton.ZIndex = 5
tpButton.Parent = tpFrame

local tpc2 = Instance.new("UICorner")
tpc2.CornerRadius = UDim.new(0, 6)
tpc2.Parent = tpButton

tpButton.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    TeleportToMurderer()
end)

local murdererPlaceholder = CreatePlaceholder(MurdererTab, "Скоро... (функции для убийцы)")
murdererPlaceholder.LayoutOrder = 2

-- ============================================================
-- BUILD SHERIFF TAB
-- ============================================================
local sheriffPlaceholder = CreatePlaceholder(SheriffTab, "Скоро... (функции для шерифа)")
sheriffPlaceholder.LayoutOrder = 1

-- ============================================================
-- MINIMIZE ICON
-- ============================================================
local MiniIcon = Instance.new("TextButton")
MiniIcon.Name = "MiniIcon"
MiniIcon.Size = UDim2.new(0, 40, 0, 40)
MiniIcon.Position = UDim2.new(0, 50, 0, 50)
MiniIcon.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
MiniIcon.BorderSizePixel = 0
MiniIcon.Text = "M"
MiniIcon.TextColor3 = Color3.fromRGB(220, 220, 230)
MiniIcon.TextSize = 16
MiniIcon.Font = Enum.Font.GothamBold
MiniIcon.Visible = false
MiniIcon.ZIndex = 20
MiniIcon.Parent = ScreenGui

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = MiniIcon

local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(80, 180, 100)
ms.Thickness = 2
ms.Parent = MiniIcon

-- ============================================================
-- BUTTON LOGIC
-- ============================================================
MinButton.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    State.IsMinimized = true
    MainFrame.Visible = false
    MiniIcon.Visible = true
end)

MiniIcon.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    State.IsMinimized = false
    MainFrame.Visible = true
    MiniIcon.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    State.IsClosed = true
    StopCandyFarm()
    StopAntiAFK()
    StopESP()
    if candyUpdater then candyUpdater(false) end
    if antiAFKUpdater then antiAFKUpdater(false) end
    if espUpdater then espUpdater(false) end
    ClearAllHighlights()
    ScreenGui:Destroy()
    local character = State.CurrentCharacter or LocalPlayer.Character
    if character then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end)

SetActiveTab("Farm")

print("[MM2 Automation] Script loaded. All functions ready.")
