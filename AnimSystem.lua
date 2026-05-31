local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GITHUB_BASE = "https://raw.githubusercontent.com/timimir/vr-animate/refs/heads/main/Anims/"

local Animator = {}
Animator.__index = Animator

local PartMap = {
    ["Torso"] = "UpperTorso",
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
}

local _Registry = {}

-- ==========================================
-- ВНУТРЕННЯЯ ЗАГРУЗКА С GITHUB
-- ==========================================
local function _LoadFromGithub(path)
    local url = GITHUB_BASE .. path .. ".lua"
    local success, result = pcall(function()
        return game:HttpGetAsync(url)
    end)
    if not success or not result or #result < 5 then
        return nil
    end
    -- 404 с GitHub приходит как текст
    if result:find("404") and #result < 300 then
        return nil
    end
    local fn, err = loadstring(result)
    if not fn then
        warn("AnimSystem loadstring error:", path, err)
        return nil
    end
    local ok, data = pcall(fn)
    if not ok then
        warn("AnimSystem execute error:", path, data)
        return nil
    end
    if type(data) ~= "table" then
        warn("AnimSystem data is not table:", path, type(data))
        return nil
    end
    return data
end

-- ==========================================
-- СЛИЯНИЕ ЧАСТЕЙ В ОДНУ АНИМАЦИЮ
-- ==========================================
local function _MergeParts(parts)
    if not parts or #parts == 0 then return nil end
    if type(parts[1]) ~= "table" then
        warn("AnimSystem _MergeParts: parts[1] is", type(parts[1]))
        return nil
    end

    local merged = {
        Keyframes = {},
        Loop = parts[1].Loop,
        Priority = parts[1].Priority,
    }

    for idx, part in ipairs(parts) do
        if type(part) ~= "table" then
            warn("AnimSystem: part", idx, "not a table")
            continue
        end
        if part.Keyframes then
            for t, frame in pairs(part.Keyframes) do
                if not merged.Keyframes[t] then
                    merged.Keyframes[t] = {
                        Poses = {},
                        Markers = (type(frame) == "table" and frame.Markers) or {}
                    }
                end
                if type(frame) == "table" and frame.Poses then
                    for poseName, poseData in pairs(frame.Poses) do
                        merged.Keyframes[t].Poses[poseName] = poseData
                    end
                end
            end
        end
    end

    return merged
end

function Animator.new(character)
    if not character then return nil end
    if _Registry[character] then return _Registry[character] end

    local self = setmetatable({}, Animator)
    self.Character = character
    self.PlayingTracks = {}
    self._Motor6Ds = {}

    -- Ожидание загрузки персонажа
    local keyPart = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    if not keyPart then
        keyPart = character:WaitForChild("Torso", 5) or character:WaitForChild("HumanoidRootPart", 5)
    end

    -- Ждем появления плеча, чтобы убедиться, что риг цел
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if torso then
        local shoulder = torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")
        if not shoulder then
            task.wait(0.5)
        end
    else
        task.wait(1)
    end

    -- Находим моторы, ключ = Part1.Name
    for _, descendant in pairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") and descendant.Part1 then
            self._Motor6Ds[descendant.Part1.Name] = descendant
        end
    end

    -- Чистка стандартных анимаций
    if character:FindFirstChild("Animate") then character.Animate:Destroy() end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid:FindFirstChild("Animator") then
        humanoid.Animator:Destroy()
    end

    self._Connection = RunService.RenderStepped:Connect(function(dt)
        self:_Update(dt)
    end)

    _Registry[character] = self
    return self
end

-- ==========================================
-- GetAnim
-- Поддерживает:
--   1. Одиночную анимацию: animName.lua -> { Keyframes = {...} }
--   2. Мульти-парт манифест: animName.lua -> { __isAnimMulti=true, Parts={"part1",...}, Loop=..., Priority=... }
--      Части грузятся по путям из Parts относительно GITHUB_BASE.
-- БЕЗ проброса 404 для автоопределения!
-- ==========================================
function Animator:GetAnim(animName)
    -- Загружаем описательный файл анимации
    local data = _LoadFromGithub(animName)
    if not data then
        warn("AnimSystem: failed to load animation:", animName)
        return nil
    end

    -- Мульти-парт анимация (явный манифест)
    if data.__isAnimMulti == true and type(data.Parts) == "table" then
        local parts = {}
        for _, partPath in ipairs(data.Parts) do
            local partData = _LoadFromGithub(partPath)
            if partData then
                table.insert(parts, partData)
            else
                warn("AnimSystem: failed to load part:", partPath, "for", animName)
            end
        end

        if #parts == 0 then
            warn("AnimSystem: no parts loaded for multi-anim:", animName)
            return nil
        end

        local merged = _MergeParts(parts)
        if not merged then
            warn("AnimSystem: merge failed for", animName)
            return nil
        end

        -- Применяем настройки из манифеста
        if data.Loop ~= nil then merged.Loop = data.Loop end
        if data.Priority then merged.Priority = data.Priority end

        return merged
    end

    -- Одиночная анимация
    if data.Keyframes then
        return data
    end

    warn("AnimSystem: loaded", animName, "but it's not a valid animation or manifest")
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

function Animator:SetSpeed(speed)
    if #self.PlayingTracks > 0 then
        self.PlayingTracks[#self.PlayingTracks].Speed = speed
    end
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
                EasingDirection = poseData.EasingDirection or Enum.EasingDirection.In,
            })
        end
    end

    local duration = timePoints[#timePoints] or 0.1
    return {
        TracksPerPart = tracksPerPart,
        Duration = duration,
        Time = 0,
        Weight = 0,
        TargetWeight = 1,
        FadeSpeed = 0,
        Speed = 1,
        Loop = animData.Loop ~= false,
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
        motor.Transform = data.cf
    end
end

return Animator
