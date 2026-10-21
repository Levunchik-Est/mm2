-- MM2 Auto Farm Script v2 (Stable)
-- Optimized for Synapse X, Script-Ware, KRNL, Delta

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ==========================================
-- CONFIGURATION
-- ==========================================
local CONFIG = {
    AntiAFKInterval = 5, -- Seconds between anti-afk moves
    AntiAFKJitter = 0.5, -- Random movement amount
    FarmCooldown = 1, -- Seconds to wait after collecting
    MinDistanceToCollect = 2, -- Minimum distance to consider candy "collected"
}

-- ==========================================
-- STATE MANAGEMENT
-- ==========================================
local IsScriptActive = true
local IsFarming = false
local IsMinimized = false
local FarmLoopTask = nil -- Task handle to stop the loop correctly
local LastAntiAFKTime = tick()

-- ==========================================
-- ANTI-AFK MODULE (Always On)
-- ==========================================
local function AntiAFKLoop()
    while IsScriptActive do
        task.wait(1) -- Check every second
        
        local now = tick()
        if now - LastAntiAFKTime >= CONFIG.AntiAFKInterval then
            -- Micro-movement to simulate human activity
            -- Moves character slightly in a random direction and back
            local dirX = math.random(-CONFIG.AntiAFKJitter, CONFIG.AntiAFKJitter)
            local dirZ = math.random(-CONFIG.AntiAFKJitter, CONFIG.ANTI_AFK_JITTER or CONFIG.AntiAFKJitter)
            
            -- Apply small velocity impulse
            HumanoidRootPart.Velocity = Vector3.new(dirX, 0, dirZ) * 2
            
            -- Reset velocity quickly so it doesn't push player far
            task.delay(0.2, function()
                if HumanoidRootPart then
                    HumanoidRootPart.Velocity = Vector3.zero
                end
            end)
            
            LastAntiAFKTime = now
        end
    end
end

-- Start Anti-AFK immediately
task.spawn(AntiAFKLoop)

-- ==========================================
-- AUTO FARM MODULE
-- ==========================================
local function FindNearestCandy()
    local NearestCandy = nil
    local MinDist = math.huge
    
    -- Iterate through all descendants of Workspace
    -- We look for parts that are likely candies/coins
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local nameLower = obj.Name:lower()
            -- Common names for candies/coins in MM2 or similar games
            if nameLower:find("candy") or nameLower:find("coin") or nameLower:find("sweet") then
                -- Check if it's visible and not part of the player
                if obj.Transparency < 1 and obj.Parent ~= Character then
                    local dist = (obj.Position - HumanoidRootPart.Position).Magnitude
                    if dist < MinDist then
                        MinDist = dist
                        NearestCandy = obj
                    end
                end
            end
        end
    end
    return NearestCandy
end

local function TeleportTo(Pos)
    -- Smooth but instant teleportation logic
    -- Set CFrame directly. This is usually allowed by executors.
    HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(0, 2, 0))
    
    -- Small sync wait to ensure server registers position before next action
    task.wait(0.05)
end

local function FarmLoop()
    while IsScriptActive and IsFarming do
        local Candy = FindNearestCandy()
        
        if Candy then
            TeleportTo(Candy.Position)
            
            -- Wait for collection event to trigger
            -- Sometimes we need to wait a tiny bit for the server to register the touch
            task.wait(0.1)
            
            -- Wait for the configured cooldown
            task.wait(CONFIG.FarmCooldown)
        else
            -- No candy found, wait a bit before searching again
            task.wait(0.5)
        end
    end
end

-- ==========================================
-- UI MODULE
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_Farm_UI_V2"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = StarterGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 120)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
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
    IsFarming = false
    if FarmLoopTask then
        FarmLoopTask:Cancel()
    end
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
SwitchBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
SwitchBtn.Text = "Auto Farm: OFF"
SwitchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SwitchBtn.Font = Enum.Font.GothamBold
SwitchBtn.TextSize = 14
SwitchBtn.Parent = MainFrame

SwitchBtn.MouseButton1Click:Connect(function()
    IsFarming = not IsFarming
    if IsFarming then
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        SwitchBtn.Text = "Auto Farm: ON"
        -- Start farming loop if not running
        if not FarmLoopTask or FarmLoopTask.Status == Enum.ThreadStatus.Terminated then
            FarmLoopTask = task.spawn(FarmLoop)
        end
    else
        SwitchBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        SwitchBtn.Text = "Auto Farm: OFF"
        -- Stop farming loop
        if FarmLoopTask then
            FarmLoopTask:Cancel()
        end
    end
end)

-- Mini Icon (for minimized state)
local MiniIcon = Instance.new("ImageButton")
MiniIcon.Name = "MiniIcon"
MiniIcon.Size = UDim2.new(0, 40, 0, 40)
MiniIcon.Position = UDim2.new(0, 10, 0, 10)
-- Using a generic Roblox icon ID that usually works
MiniIcon.Image = "rbxassetid://4458903098" 
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
