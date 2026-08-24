-- MM2 Ultimate Mod v2.0
-- Создает иконку и меню автоматически

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- 1. Создаем Иконку (Шестеренка)
local Icon = Instance.new("ImageButton")
Icon.Size = UDim2.new(0, 40, 0, 40)
Icon.Position = UDim2.new(1, -50, 1, -50)
Icon.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Icon.BorderColor3 = Color3.fromRGB(0, 150, 255)
Icon.BorderSizePixel = 2
Icon.Image = "rbxassetid://4458474257" -- Шестеренка
Icon.ScaleType = Enum.ScaleType.Fit
Icon.AutoButtonColor = false
Icon.Parent = CoreGui

-- 2. Создаем Меню
local Menu = Instance.new("Frame")
Menu.Size = UDim2.new(0, 200, 0, 150)
Menu.Position = UDim2.new(0.5, -100, 0.5, -75)
Menu.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Menu.BorderSizePixel = 0
Menu.Parent = CoreGui
Menu.Visible = false

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.Text = "MM2 Ultimate"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Parent = Menu

-- Кнопки
local Options = {
    {Name = "Auto Farm", Enabled = false},
    {Name = "ESP Coins", Enabled = false},
    {Name = "Speed Hack", Enabled = false},
    {Name = "No Clip", Enabled = false}
}

local Buttons = {}
for i, Opt in ipairs(Options) do
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -10, 0, 30)
    Btn.Position = UDim2.new(0, 5, 0, 35 + ((i-1)*35))
    Btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Btn.Text = Opt.Name
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.SourceSans
    Btn.Parent = Menu
    
    Btn.MouseButton1Click:Connect(function()
        Opt.Enabled = not Opt.Enabled
        Btn.BackgroundColor3 = Opt.Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
        
        -- Логика
        if Opt.Name == "Speed Hack" then
            if Opt.Enabled then
                Player.Character.Humanoid.WalkSpeed = 30
            else
                Player.Character.Humanoid.WalkSpeed = 16
            end
        elseif Opt.Name == "No Clip" then
            if Opt.Enabled then
                Player.Character.Humanoid.CanCollide = false
            else
                Player.Character.Humanoid.CanCollide = true
            end
        end
    end)
    Buttons[#Buttons+1] = Btn
end

-- 3. Логика Иконки
local IsOpen = false
Icon.MouseButton1Click:Connect(function()
    IsOpen = not IsOpen
    Menu.Visible = IsOpen
end)

-- 4. Геймплей (ESP и Farm)
local function getCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function espCoins()
    local character = getCharacter()
    if not character then return end
    
    -- Пример простого ESP: подсветка монет
    for _, item in pairs(workspace:GetDescendants()) do
        if item:IsA("Tool") and item.Name == "Coin" then
            -- Можно добавить BillboardGui для маркера
        end
    end
end

-- Автофарм (клик по ножам/монетам)
while true do
    wait(0.1)
    for _, opt in ipairs(Options) do
        if opt.Name == "Auto Farm" and opt.Enabled then
            -- Простая логика клика по ближайшей цели
            if Mouse.Target and Mouse.Target.Parent then
                -- Здесь можно добавить логику авто-клика
            end
        end
    end
end
