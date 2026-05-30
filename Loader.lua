-- MainLoader.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ==========================================
-- НАСТРОЙКИ GITHUB
-- ==========================================

local STUDIO_PATH = ReplicatedStorage.Custom -- Путь для тестов в Studio
local GITHUB_BASE = "https://raw.githubusercontent.com/timimir/vr-animate/refs/heads/main/"

-- ==========================================
-- ФУНКЦИЯ ЗАГРУЗКИ МОДУЛЕЙ
-- ==========================================
local function LoadModule(name)
	-- Режим Studio: берем из локальной папки
	if RunService:IsStudio() and STUDIO_PATH:FindFirstChild(name) then
		return require(STUDIO_PATH:FindFirstChild(name))
	end

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

