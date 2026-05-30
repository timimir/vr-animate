-- MainLoader.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ==========================================
-- НАСТРОЙКИ GITHUB
-- ==========================================

local GITHUB_BASE = "https://raw.githubusercontent.com/timimir/vr-animate/refs/heads/main/"

-- ==========================================
-- ФУНКЦИЯ ЗАГРУЗКИ МОДУЛЕЙ
-- ==========================================
local function LoadModule(name)

	-- Режим Игры: качаем с GitHub
	local url = GITHUB_BASE .. name .. ".lua"
	local success, code = pcall(function() 
		return game:HttpGetAsync(url) 
	end)

	if success and code then
		local func = loadstring(code)
		if func then return func() end
	end

	warn("Failed to load module:", name)
	return nil
end

-- ==========================================
-- ИНИЦИАЛИЗАЦИЯ СИСТЕМЫ
-- ==========================================
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")


-- 1. Загружаем ядро системы
local AnimSystem = LoadModule("AnimSystem")
local VRNetwork = LoadModule("Replication")
local CustomAnimate = LoadModule("Animate")

if not (AnimSystem and VRNetwork and CustomAnimate) then
	warn("Critical Error: Failed to load core modules.")
	return
end

-- 2. Находим RemoteEvent игры (Путь зависит от игры!)
-- Для теста в своей игре создай: ReplicatedStorage/MainModule/Remotes/Communication
local MainModule = ReplicatedStorage:FindFirstChild("MainModule")
local Remotes = MainModule and MainModule:FindFirstChild("Remotes")
local CommEvent = Remotes and Remotes:FindFirstChild("Communication")

if not CommEvent then
	warn("Network Error: Communication Event not found in ReplicatedStorage.MainModule.Remotes")
	return
end

-- 3. Удаляем стандартные анимации Roblox, чтобы они не мешали
if Character:FindFirstChild("Animate") then Character.Animate:Destroy() end
if Humanoid:FindFirstChild("Animator") then Humanoid.Animator:Destroy() end

-- 4. Создаем экземпляр аниматора и запускаем сеть
local Animator = AnimSystem.new(Character)
VRNetwork.Start(Animator, CommEvent)

-- 5. Запускаем логику переключения анимаций (CustomAnimate)
CustomAnimate.Init(Character, Animator)


local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game.CoreGui

-- Главный фрейм
local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 0) -- высота авто через UIListLayout
Frame.Position = UDim2.new(0, 12, 0.5, -130)
Frame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
Frame.BackgroundTransparency = 0.05
Frame.BorderSizePixel = 0
Frame.AutomaticSize = Enum.AutomaticSize.Y
Frame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = Frame

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(255, 255, 255)
Stroke.Transparency = 0.88
Stroke.Thickness = 1
Stroke.Parent = Frame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 0)
Layout.FillDirection = Enum.FillDirection.Vertical
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Frame

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 10)
Padding.PaddingBottom = UDim.new(0, 10)
Padding.PaddingLeft = UDim.new(0, 10)
Padding.PaddingRight = UDim.new(0, 10)
Padding.Parent = Frame

-- Заголовок
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundTransparency = 1
Header.LayoutOrder = 0
Header.Parent = Frame

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 8, 0, 8)
Dot.Position = UDim2.new(0, 0, 0.5, -4)
Dot.BackgroundColor3 = Color3.fromRGB(74, 222, 128)
Dot.BorderSizePixel = 0
Dot.Parent = Header
local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = Dot

local Title = Instance.new("TextLabel")
Title.Text = "ANIMATIONS"
Title.Size = UDim2.new(1, -18, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(220, 220, 220)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Функция: разделитель с названием категории
local function AddCategory(label, order)
	local Cat = Instance.new("TextLabel")
	Cat.Text = label
	Cat.Size = UDim2.new(1, 0, 0, 22)
	Cat.BackgroundTransparency = 1
	Cat.TextColor3 = Color3.fromRGB(90, 90, 100)
	Cat.Font = Enum.Font.GothamBold
	Cat.TextSize = 9
	Cat.TextXAlignment = Enum.TextXAlignment.Left
	Cat.LayoutOrder = order
	Cat.Parent = Frame
end

-- Функция: кнопка анимации
-- accentColor: Color3 для подсветки (nil = нейтральный)
-- badge: текст бейджа ("∞" или "0.6s")
local function AddButton(text, animName, accentColor, order)
	local Btn = Instance.new("TextButton")
	Btn.Size = UDim2.new(1, 0, 0, 36)
	Btn.BackgroundColor3 = accentColor
		and Color3.fromRGB(
			math.floor(accentColor.R * 255 * 0.12),
			math.floor(accentColor.G * 255 * 0.12),
			math.floor(accentColor.B * 255 * 0.12)
		)
		or Color3.fromRGB(28, 28, 34)
	Btn.BackgroundTransparency = 0
	Btn.BorderSizePixel = 0
	Btn.Text = ""
	Btn.LayoutOrder = order
	Btn.Parent = Frame

	local BtnCorner = Instance.new("UICorner")
	BtnCorner.CornerRadius = UDim.new(0, 7)
	BtnCorner.Parent = Btn

	local BtnStroke = Instance.new("UIStroke")
	BtnStroke.Color = accentColor or Color3.fromRGB(255, 255, 255)
	BtnStroke.Transparency = accentColor and 0.65 or 0.88
	BtnStroke.Thickness = 1
	BtnStroke.Parent = Btn


	-- Название
	local NameLabel = Instance.new("TextLabel")
	NameLabel.Text = text
	NameLabel.Size = UDim2.new(1, -80, 1, 0)
	NameLabel.Position = UDim2.new(0, 6, 0, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.TextColor3 = Color3.fromRGB(224, 224, 224)
	NameLabel.Font = Enum.Font.GothamMedium
	NameLabel.TextSize = 13
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.Parent = Btn


	-- Hover / Active эффекты
	Btn.MouseEnter:Connect(function()
		Btn.BackgroundTransparency = accentColor and 0 or 0
		Btn.BackgroundColor3 = accentColor
			and Color3.fromRGB(
				math.floor(accentColor.R * 255 * 0.2),
				math.floor(accentColor.G * 255 * 0.2),
				math.floor(accentColor.B * 255 * 0.2)
			)
			or Color3.fromRGB(40, 40, 50)
	end)
	Btn.MouseLeave:Connect(function()
		Btn.BackgroundColor3 = accentColor
			and Color3.fromRGB(
				math.floor(accentColor.R * 255 * 0.12),
				math.floor(accentColor.G * 255 * 0.12),
				math.floor(accentColor.B * 255 * 0.12)
			)
			or Color3.fromRGB(28, 28, 34)
	end)

	Btn.MouseButton1Click:Connect(function()
		if _G.PlayCustomAnim then
			_G.PlayCustomAnim(animName)
		end
	end)
end

-- Небольшой отступ между категорией и кнопками
local function Spacer(order)
	local S = Instance.new("Frame")
	S.Size = UDim2.new(1, 0, 0, 4)
	S.BackgroundTransparency = 1
	S.LayoutOrder = order
	S.Parent = Frame
end

-- ==========================================
-- СТРУКТУРА МЕНЮ
-- ==========================================

AddCategory("ACTIONS", 1)
Spacer(2)
AddButton("Backflip",   "backflip",   Color3.fromRGB(168, 85, 247), 3)
AddButton("Sit", "sit", Color3.fromRGB(17, 255, 0), 4)
AddButton("Punch", "punch", Color3.fromRGB(255, 48, 48), 5)