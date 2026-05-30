-- CustomAnimate.lua
local CustomAnimate = {}

function CustomAnimate.Init(Character, Animator)
	local Humanoid = Character:WaitForChild("Humanoid")

	-- ==========================================
	-- 1. ПРЕДЗАГРУЗКА АНИМАЦИЙ (Как в оригинале)
	-- ==========================================
	local anims = {
		idle  = Animator:GetAnim("idle"),
		walk  = Animator:GetAnim("walk"),
		run   = Animator:GetAnim("run"),     -- Если есть
		jump  = Animator:GetAnim("jump"),
		fall  = Animator:GetAnim("fall"),
		climb = Animator:GetAnim("climb"),
		sit   = Animator:GetAnim("sit"),
	}

	if not anims.idle or not anims.walk then
		warn("CustomAnimate: CRITICAL! Idle or Walk animation missing.")
		return
	end


	local currentAnim = nil

	-- ==========================================
	-- 2. ФУНКЦИЯ ПРОИГРЫВАНИЯ (Как в оригинале)
	-- ==========================================
	local function playAnim(name)
		if currentAnim == name then return end

		local animModule = anims[name]
		if not animModule then 
			-- Если конкретной анимации нет (например, run), пробуем откатиться на walk/idle
			if name == "run" and anims.walk then animModule = anims.walk
			elseif name == "toolnone" and anims.idle then animModule = anims.idle
			else return end
		end

		-- Вызываем Play с данными анимации
		Animator:Play(animModule, 1, 0.2)

		currentAnim = name
	end

	-- ==========================================
	-- 3. СОБЫТИЯ HUMANOID (1 в 1 как в оригинале)
	-- ==========================================

	Humanoid.Running:Connect(function(speed)
		if speed > 0.05 then
			playAnim("walk")
		else
			playAnim("idle")
		end
	end)

	Humanoid.Jumping:Connect(function()
		playAnim("jump")
	end)

	Humanoid.FreeFalling:Connect(function()
		playAnim("fall")
	end)

	Humanoid.Climbing:Connect(function()
		playAnim("climb")
	end)

	Humanoid.Seated:Connect(function(isSeated)
		if isSeated then
			playAnim("sit")
		else
			playAnim("idle")
		end
	end)

	-- ==========================================
	-- 4. ИНИЦИАЛИЗАЦИЯ (Запуск Idle)
	-- ==========================================
	playAnim("idle")

end

return CustomAnimate