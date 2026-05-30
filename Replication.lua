-- VRNetwork.lua
local module = {}

function module.Start(Animator, CommEvent)
	task.spawn(function()
		while task.wait(1/30) do
			local Char = Animator.Character
			if not Char then continue end

			local Torso = Char:FindFirstChild("Torso")
			local HRP = Char:FindFirstChild("HumanoidRootPart")

			if not Torso or not HRP then continue end

			-- Находим моторы
			local RightShoulder = Torso:FindFirstChild("Right Shoulder")
			local LeftShoulder = Torso:FindFirstChild("Left Shoulder")
			local RightHip = Torso:FindFirstChild("Right Hip")
			local LeftHip = Torso:FindFirstChild("Left Hip")
			local Neck = Torso:FindFirstChild("Neck")
			local RootJoint = HRP:FindFirstChild("RootJoint")

			-- Функция получения данных
			-- ВАЖНО: Мы берем текущий C1, который должен быть обновлен AnimSystem через Transform
			local function GetJointData(Joint)
				if Joint then
					-- Вычисляем C1 на основе текущего Transform
					-- C1 = Transform * C0^-1
					local calculatedC1 = Joint.Part1.CFrame:Inverse() * Joint.Part0.CFrame * Joint.C0
					return {
						Joint = Joint,
						GoTo = calculatedC1
					}
				end
				return nil
			end

			-- Отладка: Проверим, изменился ли C1
			-- print("RS C1:", RightShoulder and RightShoulder.C1 or "Nil")

			local CFrameTable = {
				GetJointData(RightShoulder),
				GetJointData(LeftShoulder),
				GetJointData(RightHip),
				GetJointData(LeftHip),
				GetJointData(Neck),
				GetJointData(RootJoint)
			}

			pcall(function() 
				CommEvent:FireServer(CFrameTable) 
			end)
		end
	end)
end

return module