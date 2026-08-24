-- MM2 Ultimate Mod Menu v1.0
-- Created for GitHub Raw Usage
-- Date: 2026

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Ждем загрузки персонажа
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- --- КОНФИГУРАЦИЯ ---
local Settings = {
    FarmMode = true,      -- Автоматический сбор монет
    ESPCoins = true,      -- Подсветка монет
    ESPKnife = true,      -- Подсветка убийцы
    BigHitbox = true,     -- Увеличенный размер хитбокса
    InvincibleMode = true,-- Режим "под землей" (неуязвимость)
    AutoPickup = true     -- Автоподбор
}

-- --- ИНТЕРФЕЙС (GUI) ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2_ModMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Name = "MenuFrame"
Frame.Size = UDim2.new(0, 240, 0, 180)
Frame.Position = UDim2.new(0.5, -120, 0.2, 0)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "MM2 ULTIMATE MOD"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothicBold
Title.TextSize = 18
Title.Parent = Frame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -25, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Parent = Frame
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Функция для создания кнопок меню
local function createBtn(name, yPos, toggleKey, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 25)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.Text = name
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Parent = Frame
    
    -- Обновление цвета при клике
    btn.MouseButton1Click:Connect(function()
        callback()
        if Settings[toggleKey] then
            btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Зеленый (ВКЛ)
        else
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- Серый (ВЫКЛ)
        end
    end)
    return btn
end

-- Создаем кнопки
local btnFarm = createBtn("Auto Farm", 35, "FarmMode", function()
    Settings.FarmMode = not Settings.FarmMode
end)

local btnESP = createBtn("ESP (Coins/Knife)", 65, "ESPCoins", function()
    Settings.ESPCoins = not Settings.ESPCoins
    if not Settings.ESPCoins then
        Settings.ESPKnife = false -- Выключаем ESP ножей, если выключили общий
    end
end)

local btnKnifeESP = createBtn("ESP Knife Only", 95, "ESPKnife", function()
    Settings.ESPKnife = not Settings.ESPKnife
end)

local btnHitbox = createBtn("Big Hitbox", 125, "BigHitbox", function()
    Settings.BigHitbox = not Settings.BigHitbox
end)

local btnInvincible = createBtn("Invincible (Underground)", 155, "InvincibleMode", function()
    Settings.InvincibleMode = not Settings.InvincibleMode
    if Settings.InvincibleMode then
        -- Телепортируем под карту
        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.CFrame.X, -1000, HumanoidRootPart.CFrame.Z)
    end
end)

-- --- ЛОГИКА ---

-- 1. Управление физикой и коллизиями
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(10000, 10000, 10000)
bv.Velocity = Vector3.new(0,0,0)

local function updatePhysics()
    if Settings.InvincibleMode then
        -- Отключаем коллизии и урон
        Humanoid.DamageType = Enum.HumanoidDamageType.None
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        bv.Parent = HumanoidRootPart
    else
        -- Возвращаем все как было
        Humanoid.DamageType = Enum.HumanoidDamageType.None -- Или можно вернуть стандартный урон
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        bv.Parent = nil
    end
end

-- 2. Логика Хитбокса
local function updateHitbox()
    if Settings.BigHitbox then
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" then
                    part.Size = Vector3.new(10, 10, 10)
                else
                    part.Size = Vector3.new(4, 4, 4)
                end
            end
        end
    else
        -- Возврат к нормальным размерам
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" then
                    part.Size = Vector3.new(2, 2, 1)
                else
                    part.Size = Vector3.new(1, 1, 1)
                end
            end
        end
    end
end

-- 3. ESP (Спектральный режим)
local function updateESP()
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            -- Поиск монет
            if obj.Name == "Coin" then
                if Settings.ESPCoins then
                    obj.BrickColor = BrickColor.new("Bright yellow")
                    obj.Transparency = 0
                    if not obj:FindFirstChild("BillboardGui") then
                        local bg = Instance.new("BillboardGui")
                        bg.Adornee = obj
                        bg.StudsOffset = Vector3.new(0, 2, 0)
                        bg.Size = UDim2.new(0, 100, 0, 50)
                        bg.Parent = obj
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Text = "Coin"
                        label.TextColor3 = Color3.new(1, 1, 0)
                        label.Parent = bg
                    end
                else
                    obj.BrickColor = BrickColor.new("Institutional white")
                    obj.Transparency = 0
                end
            end
            
            -- Поиск ножей (Убийцы)
            if obj.Name == "Knife" or obj:FindFirstChild("Knife") then
                if Settings.ESPKnife then
                    local knifePart = obj:IsA("BasePart") and obj or obj:FindFirstChild("Handle") or obj
                    if knifePart then
                        knifePart.BrickColor = BrickColor.new("Really red")
                        if not knifePart:FindFirstChild("BillboardGui") then
                            local bg = Instance.new("BillboardGui")
                            bg.Adornee = knifePart
                            bg.StudsOffset = Vector3.new(0, 2, 0)
                            bg.Size = UDim2.new(0, 100, 0, 50)
                            bg.Parent = knifePart
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.Text = "MURDERER"
                            label.TextColor3 = Color3.new(1, 0, 0)
                            label.Parent = bg
                        end
                    end
                else
                    obj.BrickColor = BrickColor.new("Light grey")
                end
            end
        end
    end
end

-- 4. Автофарм и перемещение
spawn(function()
    while true do
        -- Логика полета/перемещения
        if Settings.InvincibleMode then
            -- Если мы под землей, просто висим
            bv.Velocity = Vector3.new(0,0,0)
        elseif Settings.FarmMode then
            -- Ищем ближайшую монету
            local minDist = 1000
            local targetPos = HumanoidRootPart.Position
            
            for _, obj in pairs(Workspace:GetChildren()) do
                if obj.Name == "Coin" and obj:IsA("BasePart") then
                    local dist = (HumanoidRootPart.Position - obj.Position).Magnitude
                    if dist < minDist and dist > 2 then -- Не лететь к тем, что уже в руке
                        minDist = dist
                        targetPos = obj.Position
                    end
                end
            end
            
            -- Двигаемся к цели
            local dir = (targetPos - HumanoidRootPart.Position).Unit
            bv.Velocity = dir * 100 -- Скорость полета
        else
            bv.Velocity = Vector3.new(0,0,0)
        end
        wait(0.1)
    end
end)

-- Инициализация
updatePhysics()
updateHitbox()
updateESP()

-- Периодическое обновление ESP и состояний
RunService.RenderStepped:Connect(function()
    updateESP() -- Постоянная проверка для ESP
    if Settings.BigHitbox then
        -- Обновление размера хитбокса каждый кадр, чтобы не сбивалось
        updateHitbox()
    end
end)

-- Горячие клавиши
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F then -- F для переключения Farm
        Settings.FarmMode = not Settings.FarmMode
    end
    if input.KeyCode == Enum.KeyCode.T then -- T для переключения Invincible
        Settings.InvincibleMode = not Settings.InvincibleMode
        updatePhysics()
    end
end)

print("[MM2 Mod] Loaded Successfully!")
