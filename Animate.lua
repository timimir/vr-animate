-- CustomAnimate.lua
local CustomAnimate = {}

function CustomAnimate.Init(Character, Animator)
	local Humanoid = Character:WaitForChild("Humanoid")

	print("CustomAnimate: Preloading animations...")

	local Anims = {
		Idle   = Animator:GetAnim("idle"),
		Walk   = Animator:GetAnim("walk"),
		Run    = Animator:GetAnim("run"),
		Jump   = Animator:GetAnim("jump"),
		Fall   = Animator:GetAnim("fall"),
		Climb  = Animator:GetAnim("climb"),
		Sit    = Animator:GetAnim("sit"),
	}

	if not Anims.Idle or not Anims.Walk then
		warn("Critical Animations Missing!")
		return
	end

	local Priorities = {
		Core   = 1,
		Action = 5,
	}

	local CurrentPriority = 0
	local CurrentState = "None"

	local function IsRunning(currentSpeed)

		local PlayerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not PlayerGui then return false end

		local RunScript = PlayerGui:FindFirstChild("Run")
		if not RunScript then 
			return currentSpeed > 16 
		end

		local success, walkSpeed = pcall(function()
			return RunScript.Walkspeed.Value * (RunScript.WalkPercentage.Value / 100)
		end)

		if not success then
			return false
		end

		local threshold = walkSpeed + 1

		return currentSpeed >= threshold
	end

	-- Вспомогательная функция для получения длительности из данных анимации
	local function GetDuration(animData)
		if animData and animData.Keyframes then
			local times = {}
			for t, _ in pairs(animData.Keyframes) do table.insert(times, t) end
			table.sort(times)
			return times[#times] or 0.1
		end
		return 0.5 -- Дефолт, если не нашли
	end

	local function PlayAnim(nameOrData, priorityType, forceDuration)
		local newPriority = Priorities[priorityType] or Priorities.Core

		if newPriority < CurrentPriority then return end

		local animData = nameOrData
		if type(nameOrData) == "string" then
			animData = Anims[nameOrData]
			if not animData then animData = Animator:GetAnim(nameOrData) end
		end

		if not animData then 
			warn("Animation data not found for:", nameOrData)
			return 
		end

		if typeof(nameOrData) == "string" and CurrentState == nameOrData and newPriority == CurrentPriority then
			return
		end

		CurrentState = typeof(nameOrData) == "string" and nameOrData or "CustomData"
		CurrentPriority = newPriority

		Animator:Play(animData, 1, 0.2)

		-- ВОЗВРАЩАЕМ ДЛИТЕЛЬНОСТЬ АНИМАЦИИ, ЧТОБЫ ИСПОЛЬЗОВАТЬ ЕЕ В GUI
		return GetDuration(animData)
	end

	-- ==========================================
	-- ОБРАБОТЧИКИ СОБЫТИЙ
	-- ==========================================

	Humanoid.Running:Connect(function(speed)
		if CurrentPriority >= 5 then return end
		if speed > 0.05 then 
			if IsRunning(speed) then
				PlayAnim("Run", "Core")
			else
				PlayAnim("Walk", "Core")
			end
		else PlayAnim("Idle", "Core") end
	end)

	Humanoid.Jumping:Connect(function() PlayAnim("Jump", "Core") end)
	Humanoid.FreeFalling:Connect(function() PlayAnim("Fall", "Core") end)

	Humanoid.Seated:Connect(function(isSeated)
		if isSeated then PlayAnim("Sit", "Action")
		else PlayAnim("Idle", "Core") end
	end)

	-- ==========================================
	-- ЭКСПОРТ ФУНКЦИИ ДЛЯ GUI (_G.PlayCustomAnim)
	-- ==========================================

	_G.PlayCustomAnim = function(animSource)
		-- Запускаем анимацию и получаем её реальную длительность из файла
		local realDuration = PlayAnim(animSource, "Action")

		-- Если пользователь не указал длительность вручную, используем реальную из файла
		local durationToUse = realDuration

		-- Если длительность есть и анимация не зациклена (Loop=false в файле), ставим таймер сброса
		-- Проверка на зацикленность сложна здесь без доступа к треку, 
		-- поэтому просто используем логику: если manualDuration=nil, пробуем взять из файла.

		if durationToUse and durationToUse > 0 then
			task.delay(durationToUse + 0.1, function() -- +0.1 запас на плавность
				-- Сбрасываем приоритет только если с тех пор не запустили что-то более важное
				if CurrentPriority <= 5 then 
					CurrentPriority = 0 

					if Humanoid.MoveDirection.Magnitude > 0.1 then
						local speed = Character.PrimaryPart.AssemblyLinearVelocity.Magnitude
						if IsRunning(speed) then
							PlayAnim("Run", "Core")
						else
							PlayAnim("Walk", "Core")
						end
					else
						PlayAnim("Idle", "Core")
					end
				end
			end)
		end
	end

	PlayAnim("Idle", "Core")
	print("CustomAnimate with Auto-Duration Initialized.")
end

return CustomAnimate