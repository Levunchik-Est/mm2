-- ============================================================
-- MM2 Candy Farm & Anti-AFK & Role ESP & TP to Murderer
-- Requirements: Executor with LocalScript execution capability
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CONFIG = {
    CANDY_FARM_INTERVAL = 2.0,      -- Seconds between teleports
    CANDY_SEARCH_RADIUS = 300,
    ANTI_AFK_INTERVAL = 600,
    MAX_CANDY_LIMIT = 200,
    LOBBY_POSITION = Vector3.new(0, 10, 0),
    ESP_UPDATE_INTERVAL = 0.5,
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
    Connections = {},
}

-- ============================================================
-- GUI (Modern Interface)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Automation_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 385)
MainFrame.Position = UDim2.new(0, 50, 0, 50)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 70)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleBarFix = Instance.new("Frame")
TitleBarFix.Size = UDim2.new(1, 0, 0, 10)
TitleBarFix.Position = UDim2.new(0, 0, 1, -10)
TitleBarFix.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleBarFix.BorderSizePixel = 0
TitleBarFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MM2 Automation"
TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local MinButton = Instance.new("TextButton")
MinButton.Size = UDim2.new(0, 30, 0, 30)
MinButton.Position = UDim2.new(1, -65, 0, 2)
MinButton.BackgroundTransparency = 1
MinButton.Text = "−"
MinButton.TextColor3 = Color3.fromRGB(180, 180, 190)
MinButton.TextSize = 20
MinButton.Font = Enum.Font.GothamBold
MinButton.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 2)
CloseButton.BackgroundTransparency = 1
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -20, 1, -50)
ContentFrame.Position = UDim2.new(0, 10, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- ============================================================
-- TOGGLE HELPER
-- ============================================================
local function CreateToggle(parent, yOffset, labelText, initialValue, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, 0, 0, 45)
    ToggleFrame.Position = UDim2.new(0, 0, 0, yOffset)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Parent = parent

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 6)
    ToggleCorner.Parent = ToggleFrame

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -70, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = labelText
    Label.TextColor3 = Color3.fromRGB(200, 200, 210)
    Label.TextSize = 13
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleFrame

    local SwitchBg = Instance.new("Frame")
    SwitchBg.Size = UDim2.new(0, 44, 0, 24)
    SwitchBg.Position = UDim2.new(1, -56, 0.5, -12)
    SwitchBg.BackgroundColor3 = initialValue and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(70, 70, 78)
    SwitchBg.BorderSizePixel = 0
    SwitchBg.Parent = ToggleFrame

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBg

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = SwitchBg

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local ClickArea = Instance.new("TextButton")
    ClickArea.Size = UDim2.new(1, 0, 1, 0)
    ClickArea.BackgroundTransparency = 1
    ClickArea.Text = ""
    ClickArea.Parent = ToggleFrame

    local currentValue = initialValue

    local function updateVisual(value)
        if value then
            SwitchBg.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
            Knob.Position = UDim2.new(1, -21, 0.5, -9)
        else
            SwitchBg.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
            Knob.Position = UDim2.new(0, 3, 0.5, -9)
        end
    end

    ClickArea.MouseButton1Click:Connect(function()
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
-- CANDY FARM
-- ============================================================
local function FindNearestCandy()
    local character = LocalPlayer.Character
    if not character then return nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local nearestCandy = nil
    local shortestDist = CONFIG.CANDY_SEARCH_RADIUS

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("candy") or name:find("coin") then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and part.Transparency < 0.5 then
                    local dist = (rootPart.Position - part.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        nearestCandy = part
                    end
                end
            end
        end
    end
    return nearestCandy
end

local function TeleportTo(targetPart)
    local character = LocalPlayer.Character
    if not character then return false end
    local success = pcall(function()
        character:PivotTo(CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)))
    end)
    return success
end

local function TeleportToLobby()
    local character = LocalPlayer.Character
    if not character then return end
    pcall(function()
        character:PivotTo(CFrame.new(CONFIG.LOBBY_POSITION))
    end)
end

local function StartCandyFarm()
    if State.CandyFarmThread then task.cancel(State.CandyFarmThread) end
    State.CandyCount = 0
    State.CandyFarmThread = task.spawn(function()
        while State.CandyFarmEnabled and not State.IsClosed do
            local character = LocalPlayer.Character
            if not character then task.wait(1) continue end
            local candy = FindNearestCandy()
            if candy then
                local success = TeleportTo(candy)
                if success then
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
            local character = LocalPlayer.Character
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local originalPos = rootPart.CFrame
                    pcall(function() rootPart.CFrame = originalPos * CFrame.new(0.1, 0, 0) end)
                    task.wait(0.1)
                    pcall(function() rootPart.CFrame = originalPos end)
                end
            end
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
-- ROLE DETECTION
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

    local hasKnife, hasGun = false, false
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            local n = child.Name:lower()
            if n:find("knife") then hasKnife = true end
            if n:find("gun") or n:find("revolver") or n:find("pistol") then hasGun = true end
        end
    end
    if hasKnife then return "Murderer" end
    if hasGun then return "Sheriff" end

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
    for player, hl in pairs(State.ESPHighlights) do
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
-- TP TO MURDERER (One-shot button)
-- ============================================================
local function TeleportToMurderer()
    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local murdererPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local role = GetPlayerRole(player)
            if role == "Murderer" then
                murdererPlayer = player
                break
            end
        end
    end

    if not murdererPlayer then
        print("[MM2] Murderer not found.")
        return
    end

    local murdererChar = murdererPlayer.Character
    local murdererRoot = murdererChar and murdererChar:FindFirstChild("HumanoidRootPart")
    if not murdererRoot then
        print("[MM2] Murderer has no HumanoidRootPart.")
        return
    end

    pcall(function()
        localChar:PivotTo(murdererRoot.CFrame * CFrame.new(0, 0, -3))
    end)
    print("[MM2] Teleported to murderer: " .. murdererPlayer.Name)
end

-- ============================================================
-- BUILD GUI
-- ============================================================
local CandyFarmToggleUpdate

local CandyFarmFrame, candyUpdater = CreateToggle(
    ContentFrame, 0, "🍬 Candy Farm", false,
    function(value)
        State.CandyFarmEnabled = value
        if value then StartCandyFarm() else StopCandyFarm() end
    end
)
CandyFarmToggleUpdate = candyUpdater

local AntiAFKFrame, antiAFKUpdater = CreateToggle(
    ContentFrame, 60, "🛡️ Anti-AFK", false,
    function(value)
        State.AntiAFKEnabled = value
        if value then StartAntiAFK() else StopAntiAFK() end
    end
)

local ESPFrame, espUpdater = CreateToggle(
    ContentFrame, 120, "👁️ Role ESP", false,
    function(value)
        State.ESPEnabled = value
        if value then StartESP() else StopESP() end
    end
)

-- ============================================================
-- TP TO MURDERER BUTTON (One-shot)
-- ============================================================
local TPButtonFrame = Instance.new("Frame")
TPButtonFrame.Size = UDim2.new(1, 0, 0, 45)
TPButtonFrame.Position = UDim2.new(0, 0, 0, 180)
TPButtonFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
TPButtonFrame.BorderSizePixel = 0
TPButtonFrame.Parent = ContentFrame

local TPButtonCorner = Instance.new("UICorner")
TPButtonCorner.CornerRadius = UDim.new(0, 6)
TPButtonCorner.Parent = TPButtonFrame

local TPButton = Instance.new("TextButton")
TPButton.Size = UDim2.new(1, -16, 1, -10)
TPButton.Position = UDim2.new(0, 8, 0, 5)
TPButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
TPButton.Text = "🎯 TP к убийце (одноразово)"
TPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TPButton.TextSize = 13
TPButton.Font = Enum.Font.GothamBold
TPButton.Parent = TPButtonFrame

local TPButtonCorner2 = Instance.new("UICorner")
TPButtonCorner2.CornerRadius = UDim.new(0, 6)
TPButtonCorner2.Parent = TPButton

TPButton.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    TeleportToMurderer()
end)

-- ESP Legend
local LegendFrame = Instance.new("Frame")
LegendFrame.Size = UDim2.new(1, 0, 0, 55)
LegendFrame.Position = UDim2.new(0, 0, 0, 235)
LegendFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
LegendFrame.BorderSizePixel = 0
LegendFrame.Parent = ContentFrame

local LegendCorner = Instance.new("UICorner")
LegendCorner.CornerRadius = UDim.new(0, 6)
LegendCorner.Parent = LegendFrame

local function MakeLegendRow(parent, y, color, text)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 12, 0, y)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.Parent = parent
    local dotC = Instance.new("UICorner")
    dotC.CornerRadius = UDim.new(1, 0)
    dotC.Parent = dot

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -30, 0, 14)
    lbl.Position = UDim2.new(0, 28, 0, y - 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

MakeLegendRow(LegendFrame, 6, ESP_COLORS.Murderer, "Murderer")
MakeLegendRow(LegendFrame, 21, ESP_COLORS.Sheriff, "Sheriff")
MakeLegendRow(LegendFrame, 36, ESP_COLORS.Innocent, "Innocent")

-- Info Label
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 30)
InfoLabel.Position = UDim2.new(0, 0, 0, 300)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Candy Farm: 2.0s/teleport, limit " .. CONFIG.MAX_CANDY_LIMIT .. "."
InfoLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
InfoLabel.TextSize = 11
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextWrapped = true
InfoLabel.Parent = ContentFrame

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
MiniIcon.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 8)
MiniCorner.Parent = MiniIcon

local MiniStroke = Instance.new("UIStroke")
MiniStroke.Color = Color3.fromRGB(80, 180, 100)
MiniStroke.Thickness = 2
MiniStroke.Parent = MiniIcon

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
    if CandyFarmToggleUpdate then CandyFarmToggleUpdate(false) end
    if antiAFKUpdater then antiAFKUpdater(false) end
    if espUpdater then espUpdater(false) end
    for _, conn in ipairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}
    ClearAllHighlights()
    ScreenGui:Destroy()
    local character = LocalPlayer.Character
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            pcall(function()
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    if State.CandyFarmThread then
        task.cancel(State.CandyFarmThread)
        State.CandyFarmThread = nil
    end
end)

print("[MM2 Automation] Script loaded. (Teleport interval: 2.0s)")
