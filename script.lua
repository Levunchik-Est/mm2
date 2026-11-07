-- ============================================================
-- MM2 Candy Farm & Anti-AFK Script
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
    CANDY_FARM_INTERVAL = 1.5,      -- Seconds between teleports
    CANDY_SEARCH_RADIUS = 300,      -- Studs to search for candy
    ANTI_AFK_INTERVAL = 600,        -- 10 minutes (600 seconds)
    MAX_CANDY_LIMIT = 200,          -- Auto-stop after this many candies (adjust as needed)
    LOBBY_POSITION = Vector3.new(0, 10, 0), -- Fallback lobby position
}

-- ============================================================
-- STATE MANAGEMENT
-- ============================================================
local State = {
    CandyFarmEnabled = false,
    AntiAFKEnabled = false,
    IsMinimized = false,
    IsClosed = false,
    CandyFarmThread = nil,
    AntiAFKThread = nil,
    CandyCount = 0,
    Connections = {},
}

-- ============================================================
-- GUI CREATION (Modern, Clean Interface)
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Automation_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 280, 0, 320)
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

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Fix bottom corners of title bar (square)
local TitleBarFix = Instance.new("Frame")
TitleBarFix.Size = UDim2.new(1, 0, 0, 10)
TitleBarFix.Position = UDim2.new(0, 0, 1, -10)
TitleBarFix.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
TitleBarFix.BorderSizePixel = 0
TitleBarFix.Parent = TitleBar

-- Title Text
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

-- Minimize Button
local MinButton = Instance.new("TextButton")
MinButton.Size = UDim2.new(0, 30, 0, 30)
MinButton.Position = UDim2.new(1, -65, 0, 2)
MinButton.BackgroundTransparency = 1
MinButton.Text = "−"
MinButton.TextColor3 = Color3.fromRGB(180, 180, 190)
MinButton.TextSize = 20
MinButton.Font = Enum.Font.GothamBold
MinButton.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 2)
CloseButton.BackgroundTransparency = 1
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

-- Content Container
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -20, 1, -50)
ContentFrame.Position = UDim2.new(0, 10, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- ============================================================
-- TOGGLE SWITCH HELPER
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

    -- Switch Background
    local SwitchBg = Instance.new("Frame")
    SwitchBg.Size = UDim2.new(0, 44, 0, 24)
    SwitchBg.Position = UDim2.new(1, -56, 0.5, -12)
    SwitchBg.BackgroundColor3 = initialValue and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(70, 70, 78)
    SwitchBg.BorderSizePixel = 0
    SwitchBg.Parent = ToggleFrame

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = SwitchBg

    -- Switch Knob
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 18, 0, 18)
    Knob.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = SwitchBg

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    -- Click Area
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
        if callback then
            callback(currentValue)
        end
    end)

    return ToggleFrame, function(val)
        currentValue = val
        updateVisual(val)
    end
end

-- ============================================================
-- CANDY FARM LOGIC
-- ============================================================
local function FindNearestCandy()
    local character = LocalPlayer.Character
    if not character then return nil end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local nearestCandy = nil
    local shortestDist = CONFIG.CANDY_SEARCH_RADIUS

    -- Search for candy in Workspace
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

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    -- Use PivotTo for modern teleportation (Roblox API)
    local success, err = pcall(function()
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
    if State.CandyFarmThread then
        task.cancel(State.CandyFarmThread)
    end

    State.CandyCount = 0

    State.CandyFarmThread = task.spawn(function()
        while State.CandyFarmEnabled and not State.IsClosed do
            local character = LocalPlayer.Character
            if not character then
                task.wait(1)
                continue
            end

            local candy = FindNearestCandy()
            if candy then
                local success = TeleportTo(candy)
                if success then
                    State.CandyCount = State.CandyCount + 1
                    -- Check candy limit
                    if State.CandyCount >= CONFIG.MAX_CANDY_LIMIT then
                        -- Disable farm, return to lobby
                        State.CandyFarmEnabled = false
                        if CandyFarmToggleUpdate then
                            CandyFarmToggleUpdate(false)
                        end
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
-- ANTI-AFK LOGIC
-- ============================================================
local function StartAntiAFK()
    if State.AntiAFKThread then
        task.cancel(State.AntiAFKThread)
    end

    State.AntiAFKThread = task.spawn(function()
        while State.AntiAFKEnabled and not State.IsClosed do
            task.wait(CONFIG.ANTI_AFK_INTERVAL)

            if State.IsClosed or not State.AntiAFKEnabled then
                break
            end

            local character = LocalPlayer.Character
            if character then
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    -- Minimal movement: slight shift and back
                    local originalPos = rootPart.CFrame
                    pcall(function()
                        rootPart.CFrame = originalPos * CFrame.new(0.1, 0, 0)
                    end)
                    task.wait(0.1)
                    pcall(function()
                        rootPart.CFrame = originalPos
                    end)
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
-- BUILD GUI (Toggles)
-- ============================================================
local CandyFarmToggleUpdate -- Forward declaration

local CandyFarmFrame, candyUpdater = CreateToggle(
    ContentFrame,
    0,
    "🍬 Candy Farm",
    false,
    function(value)
        State.CandyFarmEnabled = value
        if value then
            StartCandyFarm()
        else
            StopCandyFarm()
        end
    end
)
CandyFarmToggleUpdate = candyUpdater

local AntiAFKFrame, antiAFKUpdater = CreateToggle(
    ContentFrame,
    60,
    "🛡️ Anti-AFK",
    false,
    function(value)
        State.AntiAFKEnabled = value
        if value then
            StartAntiAFK()
        else
            StopAntiAFK()
        end
    end
)

-- Info Label
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 40)
InfoLabel.Position = UDim2.new(0, 0, 0, 120)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Candy Farm teleports every 1.5s.\nAuto-stops at " .. CONFIG.MAX_CANDY_LIMIT .. " candies."
InfoLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
InfoLabel.TextSize = 11
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextWrapped = true
InfoLabel.Parent = ContentFrame

-- ============================================================
-- MINIMIZE ICON (Small separate icon)
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
-- BUTTON LOGIC: MINIMIZE / RESTORE / CLOSE
-- ============================================================

-- Minimize Button Click
MinButton.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    State.IsMinimized = true
    MainFrame.Visible = false
    MiniIcon.Visible = true
end)

-- Mini Icon Click (Restore)
MiniIcon.MouseButton1Click:Connect(function()
    if State.IsClosed then return end
    State.IsMinimized = false
    MainFrame.Visible = true
    MiniIcon.Visible = false
end)

-- Close Button Click (Full Stop)
CloseButton.MouseButton1Click:Connect(function()
    -- Mark as closed first to stop all loops
    State.IsClosed = true

    -- Stop all functions
    StopCandyFarm()
    StopAntiAFK()

    -- Reset toggles visually
    if CandyFarmToggleUpdate then CandyFarmToggleUpdate(false) end
    if antiAFKUpdater then antiAFKUpdater(false) end

    -- Disconnect all connections
    for _, conn in ipairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}

    -- Destroy GUI
    ScreenGui:Destroy()

    -- Clear any residual character velocity
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

-- ============================================================
-- CLEANUP ON CHARACTER REMOVAL (Safety)
-- ============================================================
LocalPlayer.CharacterRemoving:Connect(function()
    if State.CandyFarmThread then
        task.cancel(State.CandyFarmThread)
        State.CandyFarmThread = nil
    end
    -- Don't stop Anti-AFK thread here; it will re-check on next loop
end)

-- ============================================================
-- SCRIPT INITIALIZATION
-- ============================================================
print("[MM2 Automation] Script loaded. GUI ready.")
