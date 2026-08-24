local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- 1. Создаем фрейм иконки (маленькая кнопка в углу)
local ToggleIcon = Instance.new("ImageButton")
ToggleIcon.Size = UDim2.new(0, 50, 0, 50)
ToggleIcon.Position = UDim2.new(1, -60, 1, -60) -- Правый нижний угол
ToggleIcon.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleIcon.BorderColor3 = Color3.fromRGB(200, 0, 0)
ToggleIcon.BorderSizePixel = 2
ToggleIcon.Image = "rbxassetid://4458474257" -- Иконка шестеренки
ToggleIcon.ScaleType = Enum.ScaleType.Fit
ToggleIcon.AutoButtonColor = false
ToggleIcon.Parent = CoreGui

-- 2. Создаем само меню (изначально скрыто или свернуто)
local Menu = Instance.new("Frame")
Menu.Size = UDim2.new(0, 250, 0, 200)
Menu.Position = UDim2.new(0.5, -125, 0.5, -100) -- Центр экрана
Menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Menu.BorderSizePixel = 0
Menu.Parent = CoreGui
Menu.Visible = false -- Сначала скрыто

-- Заголовок
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.Text = "MM2 Mod Menu"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = Menu

-- Кнопки
local Buttons = {
    {Text = "Auto Farm", Pos = UDim2.new(0, 0, 0, 35)},
    {Text = "ESP Coins", Pos = UDim2.new(0, 0, 0, 70)},
    {Text = "Big Hitbox", Pos = UDim2.new(0, 0, 0
