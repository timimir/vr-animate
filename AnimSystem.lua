-- AnimSystem.lua
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- НАСТРОЙКИ GITHUB
local GITHUB_USER = "timimir"       -- !!! ЗАМЕНИ
local GITHUB_REPO = "vr-animate"   -- !!! ЗАМЕНИ
local GITHUB_BRANCH = "main"
local GITHUB_BASE = string.format("https://raw.githubusercontent.com/%s/%s/%s/Anims/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

local Animator = {}
Animator.__index = Animator

-- Маппинг для R6 -> R15 (как в оригинале)
local PartMap = {
	["Torso"] = "UpperTorso",
	["Left Arm"] = "LeftUpperArm",
	["Right Arm"] = "RightUpperArm",
	["Left Leg"] = "LeftUpperLeg",
	["Right Leg"] = "RightUpperLeg",
}

local _Registry = {}

function Animator.new(character)
	if not character then return nil end
	if _Registry[character] then return _Registry[character] end

	local self = setmetatable({}, Animator)
	self.Character = character
	self.PlayingTracks = {}
	self._Motor6Ds = {} -- Ключи здесь будут ИМЕНАМИ ЧАСТЕЙ ТЕЛА (Part1.Name)

	-- ==========================================
	-- ОЖИДАНИЕ ЗАГРУЗКИ ПЕРСОНАЖА
	-- ==========================================
	local keyPart = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	if not keyPart then
		keyPart = character:WaitForChild("Torso", 5) or character:WaitForChild("HumanoidRootPart", 5)
	end

	-- Ждем появления плеча, чтобы убедиться, что риг цел
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso then
		torso:WaitForChild("Right Shoulder", 5)
	else
		task.wait(1)
	end

	-- Находим моторы, используя логику оригинала (ключ = Part1.Name)
	for _, descendant in pairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			self._Motor6Ds[descendant.Part1.Name] = descendant
		end
	end


	-- Чистка стандартных анимаций
	if character:FindFirstChild("Animate") then character.Animate:Destroy() end
	if character.Humanoid:FindFirstChild("Animator") then character.Humanoid.Animator:Destroy() end

	self._Connection = RunService.RenderStepped:Connect(function(dt) self:_Update(dt) end)

	_Registry[character] = self
	return self
end

-- МЕТОД ПОЛУЧЕНИЯ АНИМАЦИИ (HTTP или Local)
function Animator:GetAnim(animName)
	-- Простой кэш можно добавить сюда, если нужно, но пока грузим каждый раз или из Studio
	if RunService:IsStudio() then
		local AnimsFolder = ReplicatedStorage:FindFirstChild("Custom") and ReplicatedStorage.Custom:FindFirstChild("Anims")
		if AnimsFolder then
			local mod = AnimsFolder:FindFirstChild(animName)
			if mod then return require(mod) end
		end
	end

	local url = GITHUB_BASE .. animName .. ".lua"
	local success, code = pcall(function() return game:HttpGetAsync(url) end)
	if success and code then
		local func = loadstring(code)
		if func then return func() end
	end

	warn("Failed to load animation:", animName)
	return nil
end

function Animator:Play(animData, speed, fadeTime)
	if not animData then return end

	local track = self:_LoadTrack(animData)
	if not track then return end

	for _, t in ipairs(self.PlayingTracks) do
		t.TargetWeight = 0
		t.FadeSpeed = 1 / (fadeTime or 0.25)
	end

	track.Speed = speed or 1
	track.FadeSpeed = 1 / (fadeTime or 0.25)
	track.TargetWeight = 1
	table.insert(self.PlayingTracks, track)
end

function Animator:_LoadTrack(animData)
	if not animData.Keyframes then return nil end

	local timePoints = {}
	for t, _ in pairs(animData.Keyframes) do table.insert(timePoints, t) end
	table.sort(timePoints)

	local tracksPerPart = {}
	for _, t in ipairs(timePoints) do
		local flatPoses = {}
		self:_FlattenToTable(animData.Keyframes[t].Poses, flatPoses)

		for partName, poseData in pairs(flatPoses) do
			if not tracksPerPart[partName] then tracksPerPart[partName] = {} end
			table.insert(tracksPerPart[partName], {
				Time = t,
				CFrame = poseData.CFrame,
				EasingStyle = poseData.EasingStyle or Enum.EasingStyle.Linear,
				EasingDirection = poseData.EasingDirection or Enum.EasingDirection.In
			})
		end
	end

	local duration = timePoints[#timePoints] or 0.1
	local finalLoop = animData.Loop ~= false

	return {
		TracksPerPart = tracksPerPart,
		Duration = duration,
		Time = 0,
		Weight = 0,
		TargetWeight = 1,
		FadeSpeed = 0,
		Speed = 1,
		Loop = finalLoop,
		IsPlaying = true,
	}
end

function Animator:_FlattenToTable(poses, output)
	for partName, data in pairs(poses) do
		output[partName] = data
		if data.SubPoses then
			self:_FlattenToTable(data.SubPoses, output)
		end
	end
end

function Animator:_GetPartKeyframes(partTrack, currentTime, duration, loop)
	local count = #partTrack
	if count == 0 then return nil, nil, 0 end
	if count == 1 then return partTrack[1], partTrack[1], 0 end

	if currentTime >= partTrack[count].Time then
		return partTrack[count], (loop and partTrack[1] or partTrack[count]), 0
	end

	for i = 1, count - 1 do
		if currentTime >= partTrack[i].Time and currentTime < partTrack[i+1].Time then
			return partTrack[i], partTrack[i+1], (currentTime - partTrack[i].Time) / (partTrack[i+1].Time - partTrack[i].Time)
		end
	end
	return partTrack[1], partTrack[1], 0
end

function Animator:_Update(dt)
	local masterTransforms = {}

	for i = #self.PlayingTracks, 1, -1 do
		local track = self.PlayingTracks[i]

		if track.Weight ~= track.TargetWeight then
			local step = track.FadeSpeed * dt
			if track.Weight < track.TargetWeight then
				track.Weight = math.min(track.Weight + step, track.TargetWeight)
			else
				track.Weight = math.max(track.Weight - step, track.TargetWeight)
			end
		end

		local isFinished = not track.Loop and track.Time >= track.Duration
		if (track.TargetWeight == 0 and track.Weight <= 0.01) or isFinished then
			table.remove(self.PlayingTracks, i)
			continue
		end

		track.Time += dt * track.Speed
		local normTime = track.Loop and (track.Time % track.Duration) or math.min(track.Time, track.Duration)

		for partName, keyframes in pairs(track.TracksPerPart) do
			-- ИСПОЛЬЗУЕМ МАППИНГ КАК В ОРИГИНАЛЕ
			local motor = self._Motor6Ds[partName] or self._Motor6Ds[PartMap[partName]]
			if not motor then continue end

			local k1, k2, alpha = self:_GetPartKeyframes(keyframes, normTime, track.Duration, track.Loop)
			if not k1 or not k2 then continue end

			local easedAlpha = TweenService:GetValue(alpha, k1.EasingStyle, k1.EasingDirection)
			local currentCF = k1.CFrame:Lerp(k2.CFrame, easedAlpha)

			if not masterTransforms[motor] then
				masterTransforms[motor] = {cf = currentCF, totalWeight = track.Weight}
			else
				local data = masterTransforms[motor]
				local weightAlpha = track.Weight / (data.totalWeight + track.Weight)
				data.cf = data.cf:Lerp(currentCF, weightAlpha)
				data.totalWeight += track.Weight
			end
		end
	end

	for motor, data in pairs(masterTransforms) do
		-- В оригинале было motor.Transform = data.cf
		-- Но правильно применять относительно C0, если данные локальные. 
		-- Если анимации сделаны под оригинальный скрипт, то data.cf уже готовый Transform.
		motor.Transform = data.cf
	end
end

return Animator