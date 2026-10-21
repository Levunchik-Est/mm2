-- Auto Farm MM2 Script with UI and Anti-AFK
-- Designed for use in executors like Synapse X, Script-Ware, KRNL, Delta

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera = workspace.CurrentCamera

-- Configuration
local CONFIG = {
    AntiAFKInterval = 5, -- Seconds between anti-afk movements
    AntiAFKJitter = 0.5, -- Random jitter amount for movement
    FarmCooldown = 1, -- Seconds to wait after collecting a candy
    CandyTags = {"Candy", "Coin"} -- Tags often used for collectibles in MM2
}

-- State Management
local IsScriptActive = true
local IsFarming = false
local IsMinimized = false
local LastAntiAFKTime = tick()

-- ==========================================
-- ANTI-AFK MODULE (Always On)
-- ==========================================
local function AntiAFK()
    local now = tick()
    if now - LastAntiAFKTime >= CONFIG.AntiAFKInterval then
        -- Micro-movement to simulate human activity
        -- Slight random rotation of the camera or character head
        local jitterX = math.random(-CONFIG.AntiAFKJitter, CONFIG.AntiAFKJitter)
        local jitterY = math.random(-CONFIG.AntiAFKJitter, CONFIG.ANTI_AFK_JITTER or CONFIG.AntiAFKJitter)
        
        -- Simulate key press by slightly moving the character forward/backward randomly
        -- This prevents server-side AFK detection
        local direction = Vector3.new(math.random(-1,1), 0, math.random(-1,1))
        HumanoidRootPart.Velocity = direction * 5
        
        LastAntiAFKTime = now
    end
end

RunService.Heartbeat:Connect(AntiAFK)

-- ==========================================
-- AUTO FARM MODULE
-- ==========================================
local function FindNearestCandy()
    local MinDistance = math.huge
    local NearestCandy = nil
    
    -- Search in Workspace for objects that might be candies
    -- Note: In MM2, candies are often children of specific folders or tagged.
    -- We scan all descendants for safety.
    
    local Candidates = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("candy") or obj.Name:lower():find("coin") then
            -- Check if it's not already collected or invisible
            if obj.Transparency < 1 and obj.CanCollide == false then -- Many collectibles are uncollidable
                local Dist = (obj.Position - HumanoidRootPart.Position).Magnitude
                if Dist < MinDistance then
                    MinDistance = Dist
                    NearestCandy = obj
                end
            end
        end
    end
    
    return NearestCandy
end

local function TeleportToPosition(Pos)
    -- Instant teleportation without animation delay
    HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(0, 2, 0)) -- Slightly above to avoid clipping
    -- Force sync to ensure server sees the position immediately
    HumanoidRootPart.Anchored = true
    task.wait(0.01)
    HumanoidRootPart.Anchored = false
end

local function StartFarmLoop()
    while IsScriptActive and IsFarming do
        local Candy = FindNearestCandy()
        
        if Candy then
            TeleportToPosition(Candy.Position)
            
            -- Small wait to allow collection event to trigger on server/client
            task.wait(0.1) 
            
            -- Wait for cooldown
            task.wait(CONFIG.FarmCooldown)
        else
            -- If no candy found, wait a bit before checking again to save CPU
            task.wait(0.5)
        end
    end
end

-- ==========================================
-- UI MODULE
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Farm_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = StarterGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 200, 0, 100)
MainFrame.Position = UDim2.new(0, 10, 0, 10) -- Top Left Corner
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- Header Bar
local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "HeaderBar"
HeaderBar.Size = UDim2.new(1, 0, 0, 30)
HeaderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
HeaderBar.BorderSizePixel = 0
HeaderBar.Parent = MainFrame

-- Title Text
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
TitleLabel.Position = UDim2.new(0.15, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "MM2 Auto Farm"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Parent = HeaderBar

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 16
CloseBtn.Parent = HeaderBar

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    IsScriptActive = false
    IsFarming = false -- Stop farm loop
end)

-- Minimize Button (-)
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "MinBtn"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -60, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 16
MinBtn.Parent = HeaderBar

MinBtn.MouseButton1Click:Connect(function()
    IsMinimized = not IsMinimized
    if IsMinimized then
        MainFrame.Visible = false
    else
        MainFrame.Visible = true
    end
end)

-- Switch Button
local SwitchBtn = Instance.new("TextButton")
SwitchBtn.Name = "SwitchBtn"
SwitchBtn.Size = UDim2.new(0.8, 0, 0, 40)
SwitchBtn.Position = UDim2.new(0.1, 0, 0, 40)
SwitchBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
SwitchBtn.Text = "Auto Farm: ON"
SwitchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SwitchBtn.Font = Enum.Font.GothamBold
SwitchBtn.TextSize = 14
SwitchBtn.Parent = MainFrame

SwitchBtn.MouseButton1Click:Connect(function()
    IsFarming = not IsFarming
    if IsFarming then
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        SwitchBtn.Text = "Auto Farm: ON"
        -- Start the farming loop if not already running
        -- We use a coroutine to ensure it runs independently
        if not FarmThread or FarmThread.Status == Enum.ThreadStatus.Terminated then
            FarmThread = task.spawn(StartFarmLoop)
        end
    else
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        SwitchBtn.Text = "Auto Farm: OFF"
    end
end)

-- Mini Icon (for minimized state)
local MiniIcon = Instance.new("ImageButton")
MiniIcon.Name = "MiniIcon"
MiniIcon.Size = UDim2.new(0, 40, 0, 40)
MiniIcon.Position = UDim2.new(0, 10, 0, 10)
MiniIcon.Image = "rbxassetid://123456789" -- Generic placeholder ID, replace if needed
MiniIcon.BackgroundTransparency = 0.5
MiniIcon.Parent = ScreenGui
MiniIcon.Visible = false

MiniIcon.MouseButton1Click:Connect(function()
    if IsMinimized then
        IsMinimized = false
        MainFrame.Visible = true
        MiniIcon.Visible = false
    end
end)

-- Update visibility logic for MiniIcon
game:GetService("RunService").RenderStepped:Connect(function()
    if IsMinimized and not MainFrame.Visible then
        MiniIcon.Visible = true
    elseif not IsMinimized then
        MiniIcon.Visible = false
    end
end)

-- Initial State Setup
SwitchBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
SwitchBtn.Text = "Auto Farm: OFF"
