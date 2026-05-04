--[[
    ╔══════════════════════════════════════════════════╗
    ║         GENARIX HUB PREMIUM - UNIVERSAL         ║
    ║         Version: 2.4.0                          ║
    ║         Powered by Genarix UI Library           ║
    ╚══════════════════════════════════════════════════╝
]]

local GenarixUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/GenarixScripts/Genarix-UI-Library/refs/heads/main/Source.lua", true))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ================================================
-- VARIÁVEIS
-- ================================================
local aimbotEnabled = false
local aimbotFOV = 150
local aimbotSmooth = 5
local aimbotPart = "Head"
local aimbotTeamCheck = true
local aimbotShowFOV = true
local aimbotActive = false
local aimbotInputType = "MouseButton2"
local aimbotKeyCode = nil
local aimbotMethod = "Mouse"

-- BULLET DROP
local bulletDropEnabled = true
local bulletDropIntensity = 1.0
local bulletDropStartDist = 50
local bulletDropMaxOffset = 200

local hitboxEnabled = false
local hitboxSize = 5
local hitboxTransparency = 0.5

local espEnabled = false
local espTeamCheck = true
local espShowName = true
local espShowHealth = true
local espShowDistance = true
local espShowBox = false

local flyEnabled = false
local flySpeed = 50
local noclipEnabled = false
local infJumpEnabled = false
local speedEnabled = false
local customSpeed = 16
local customJump = 50
local fullbrightEnabled = false
local removeFogEnabled = false
local removeParticlesEnabled = false

local espObjects = {}
local fovCircle = nil
local flyBody = nil
local flyGyro = nil

local allToggleAPIs = {}

-- ================================================
-- AIMBOT INPUT (Hold) - SEM BLOQUEIO DE gameProcessed
-- ================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if not aimbotEnabled then return end
    local activate = false
    if aimbotInputType == "Keyboard" and aimbotKeyCode then
        if input.KeyCode == aimbotKeyCode then activate = true end
    elseif aimbotInputType == "MouseButton1" and input.UserInputType == Enum.UserInputType.MouseButton1 then
        activate = true
    elseif aimbotInputType == "MouseButton2" and input.UserInputType == Enum.UserInputType.MouseButton2 then
        activate = true
    elseif aimbotInputType == "MouseButton3" and input.UserInputType == Enum.UserInputType.MouseButton3 then
        activate = true
    end
    if activate then aimbotActive = true end
end)

UserInputService.InputEnded:Connect(function(input)
    local deactivate = false
    if aimbotInputType == "Keyboard" and aimbotKeyCode then
        if input.KeyCode == aimbotKeyCode then deactivate = true end
    elseif aimbotInputType == "MouseButton1" and input.UserInputType == Enum.UserInputType.MouseButton1 then
        deactivate = true
    elseif aimbotInputType == "MouseButton2" and input.UserInputType == Enum.UserInputType.MouseButton2 then
        deactivate = true
    elseif aimbotInputType == "MouseButton3" and input.UserInputType == Enum.UserInputType.MouseButton3 then
        deactivate = true
    end
    if deactivate then aimbotActive = false end
end)

-- ================================================
-- UTILS
-- ================================================
local function isEnemy(p)
    if not aimbotTeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return p.Team ~= LocalPlayer.Team
end

local function isEnemyESP(p)
    if not espTeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return p.Team ~= LocalPlayer.Team
end

local function getClosestPlayer()
    local closest, closestPart, shortest = nil, nil, aimbotFOV
    if not LocalPlayer.Character then return nil, nil end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and isEnemy(p) then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local part = p.Character:FindFirstChild(aimbotPart) or p.Character:FindFirstChild("Head")
            if hum and hum.Health > 0 and part then
                local sp, on = Camera:WorldToScreenPoint(part.Position)
                if on then
                    local d = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(sp.X, sp.Y)).Magnitude
                    if d < shortest then
                        shortest = d
                        closest = p
                        closestPart = part
                    end
                end
            end
        end
    end
    return closestPart, closest
end

-- ================================================
-- BULLET DROP COMPENSATION
-- ================================================
local function calculateBulletDrop(targetPart)
    if not bulletDropEnabled or not targetPart then return 0 end

    local myChar = LocalPlayer.Character
    if not myChar then return 0 end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return 0 end

    -- Calcular distância 3D entre jogador e alvo
    local distance = (myHRP.Position - targetPart.Position).Magnitude

    -- Se a distância é menor que o início do drop, sem compensação
    if distance <= bulletDropStartDist then return 0 end

    -- Distância efetiva (acima do threshold)
    local effectiveDist = distance - bulletDropStartDist

    -- Fórmula de drop: quadrática para simular gravidade
    -- quanto mais longe, mais o drop aumenta (como gravidade real)
    -- dropPixels = intensity * (distancia_efetiva / 100)^2 * fator_base
    local dropFactor = (effectiveDist / 100) ^ 1.5
    local dropPixels = bulletDropIntensity * dropFactor * 30

    -- Limitar o offset máximo
    dropPixels = math.min(dropPixels, bulletDropMaxOffset)

    return dropPixels
end

-- ================================================
-- AIMBOT - COM BULLET DROP
-- ================================================
local function aimAtTarget(targetPart)
    if not targetPart then return end

    -- Calcular bullet drop offset (em pixels na tela)
    local dropOffset = calculateBulletDrop(targetPart)

    if aimbotMethod == "Camera" then
        -- Método Camera com bullet drop compensation
        -- Calcular posição ajustada do alvo (abaixar a mira = mirar ACIMA do alvo)
        local adjustedPos = targetPart.Position + Vector3.new(0, dropOffset * 0.05, 0)
        Camera.CFrame = Camera.CFrame:Lerp(
            CFrame.lookAt(Camera.CFrame.Position, adjustedPos),
            1 / aimbotSmooth
        )
    else
        -- Método Mouse com bullet drop compensation
        local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
        if not onScreen then return end

        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

        -- Posição do alvo na tela + offset de drop (positivo = abaixar mira na tela)
        -- Para compensar bullet drop, miramos ACIMA do alvo = offset NEGATIVO no Y da tela
        -- Mas o problema original é "mira muito pra cima quando longe"
        -- Então adicionamos offset POSITIVO para abaixar a mira
        local targetScreen = Vector2.new(screenPos.X, screenPos.Y + dropOffset)

        local delta = targetScreen - screenCenter

        local moveX = delta.X / aimbotSmooth
        local moveY = delta.Y / aimbotSmooth

        if mousemoverel then
            mousemoverel(moveX, moveY)
        else
            local adjustedPos = targetPart.Position - Vector3.new(0, dropOffset * 0.05, 0)
            Camera.CFrame = Camera.CFrame:Lerp(
                CFrame.lookAt(Camera.CFrame.Position, adjustedPos),
                1 / aimbotSmooth
            )
        end
    end
end

-- ================================================
-- FOV CIRCLE
-- ================================================
local function createFOVCircle()
    if fovCircle then fovCircle:Remove() end
    fovCircle = Drawing.new("Circle")
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Radius = aimbotFOV
    fovCircle.Color = GenarixUI:GetAccentColor()
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.Transparency = 0.6
    fovCircle.Visible = aimbotShowFOV and aimbotEnabled
end

local function updateFOVCircle()
    if not fovCircle then return end
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Radius = aimbotFOV
    fovCircle.Visible = aimbotShowFOV and aimbotEnabled
    fovCircle.Color = GenarixUI:GetAccentColor()
end

local function removeFOVCircle()
    if fovCircle then fovCircle:Remove(); fovCircle = nil end
end

-- ================================================
-- HITBOX
-- ================================================
local function updateHitboxes()
    if not hitboxEnabled then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                hrp.Transparency = hitboxTransparency
                hrp.CanCollide = false
                hrp.Color = GenarixUI:GetAccentColor()
                hrp.Material = Enum.Material.Neon
            end
        end
    end
end

local function resetHitboxes()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = false
            end
        end
    end
end

-- ================================================
-- ESP
-- ================================================
local function createESP(player)
    if player == LocalPlayer or espObjects[player] or not isEnemyESP(player) then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head then return end

    local data = {}
    local hl = Instance.new("Highlight")
    hl.FillColor = GenarixUI:GetAccentColor()
    hl.FillTransparency = 0.7
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char
    data.Highlight = hl

    local bb = Instance.new("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = char
    data.Billboard = bb

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, 0, 0, 18)
    nl.BackgroundTransparency = 1
    nl.Text = player.Name
    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nl.TextStrokeTransparency = 0.3
    nl.TextSize = 14
    nl.Font = Enum.Font.GothamBold
    nl.Parent = bb
    data.NameLabel = nl

    local hbg = Instance.new("Frame")
    hbg.Size = UDim2.new(0.6, 0, 0, 5)
    hbg.Position = UDim2.new(0.2, 0, 0, 20)
    hbg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hbg.BorderSizePixel = 0
    hbg.Parent = bb
    Instance.new("UICorner", hbg).CornerRadius = UDim.new(0, 3)
    data.HpBg = hbg

    local hfl = Instance.new("Frame")
    hfl.Size = UDim2.new(1, 0, 1, 0)
    hfl.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
    hfl.BorderSizePixel = 0
    hfl.Parent = hbg
    Instance.new("UICorner", hfl).CornerRadius = UDim.new(0, 3)
    data.HpFill = hfl

    local dl = Instance.new("TextLabel")
    dl.Size = UDim2.new(1, 0, 0, 14)
    dl.Position = UDim2.new(0, 0, 0, 27)
    dl.BackgroundTransparency = 1
    dl.Text = "0m"
    dl.TextColor3 = Color3.fromRGB(180, 180, 200)
    dl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    dl.TextStrokeTransparency = 0.5
    dl.TextSize = 11
    dl.Font = Enum.Font.Gotham
    dl.Parent = bb
    data.DistLabel = dl

    local bx = Instance.new("BoxHandleAdornment")
    bx.Adornee = char:FindFirstChild("HumanoidRootPart")
    bx.AlwaysOnTop = true
    bx.ZIndex = 5
    bx.Size = Vector3.new(4, 5, 1)
    bx.Color3 = GenarixUI:GetAccentColor()
    bx.Transparency = 0.6
    bx.Visible = espShowBox
    bx.Parent = char
    data.Box = bx

    espObjects[player] = data
end

local function removeESP(p)
    if espObjects[p] then
        for _, o in pairs(espObjects[p]) do
            if o and o.Parent then pcall(function() o:Destroy() end) end
        end
        espObjects[p] = nil
    end
end

local function removeAllESP()
    for p, _ in pairs(espObjects) do removeESP(p) end
    espObjects = {}
end

local function updateESP()
    if not espEnabled then return end
    local lc = LocalPlayer.Character
    if not lc then return end
    local lhrp = lc:FindFirstChild("HumanoidRootPart")
    if not lhrp then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if not isEnemyESP(p) then removeESP(p); continue end
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                if not espObjects[p] then createESP(p) end
                local d = espObjects[p]
                if d then
                    if d.NameLabel then d.NameLabel.Visible = espShowName end
                    if d.HpBg then d.HpBg.Visible = espShowHealth end
                    if d.DistLabel then d.DistLabel.Visible = espShowDistance end
                    if d.Box then d.Box.Visible = espShowBox end
                    if d.HpFill and espShowHealth then
                        local hp = hum.Health / hum.MaxHealth
                        d.HpFill.Size = UDim2.new(math.clamp(hp, 0, 1), 0, 1, 0)
                        d.HpFill.BackgroundColor3 = hp > 0.5 and Color3.fromRGB(80, 220, 120)
                            or hp > 0.25 and Color3.fromRGB(220, 200, 60)
                            or Color3.fromRGB(220, 60, 60)
                    end
                    if d.DistLabel and espShowDistance then
                        d.DistLabel.Text = tostring(math.floor((lhrp.Position - hrp.Position).Magnitude)) .. "m"
                    end
                end
            else
                removeESP(p)
            end
        end
    end
end

-- ================================================
-- FLY
-- ================================================
local function startFly()
    local c = LocalPlayer.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    flyBody = Instance.new("BodyVelocity")
    flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBody.Velocity = Vector3.zero
    flyBody.Parent = hrp
    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.D = 200
    flyGyro.P = 40000
    flyGyro.Parent = hrp
end

local function stopFly()
    if flyBody then flyBody:Destroy(); flyBody = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
end

local function updateFly()
    if not flyEnabled then return end
    local c = LocalPlayer.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBody or not flyGyro then return end
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit end
    flyBody.Velocity = dir * flySpeed
    flyGyro.CFrame = Camera.CFrame
end

-- ================================================
-- NOCLIP
-- ================================================
local function updateNoclip()
    if not noclipEnabled then return end
    local c = LocalPlayer.Character
    if not c then return end
    for _, p in pairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

-- ================================================
-- FULLBRIGHT
-- ================================================
local origLight = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows
}

local function enableFullbright()
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    Lighting.GlobalShadows = false
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then v.Density = 0 end
        if v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") then v.Enabled = false end
    end
end

local function disableFullbright()
    Lighting.Ambient = origLight.Ambient
    Lighting.Brightness = origLight.Brightness
    Lighting.OutdoorAmbient = origLight.OutdoorAmbient
    Lighting.GlobalShadows = origLight.GlobalShadows
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then v.Density = 0.3 end
        if v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") then v.Enabled = true end
    end
end

local function toggleFog(e)
    if e then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        Lighting.FogEnd = origLight.FogEnd
        Lighting.FogStart = origLight.FogStart
    end
end

local function toggleParticles(r)
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = not r
        end
    end
end

-- ================================================
-- INFINITE JUMP
-- ================================================
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

-- ================================================
-- MAIN LOOP
-- ================================================
RunService.RenderStepped:Connect(function()
    if aimbotEnabled and aimbotActive then
        local t = getClosestPlayer()
        if t then aimAtTarget(t) end
    end
    updateFOVCircle()
    updateFly()
    updateNoclip()
end)

RunService.Heartbeat:Connect(function()
    if hitboxEnabled then pcall(updateHitboxes) end
    if espEnabled then pcall(updateESP) end
    if speedEnabled then
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = customSpeed end
        end
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        removeESP(p)
        task.wait(1)
        if espEnabled and isEnemyESP(p) then pcall(function() createESP(p) end) end
    end)
end)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            removeESP(p)
            task.wait(1)
            if espEnabled and isEnemyESP(p) then pcall(function() createESP(p) end) end
        end)
    end
end

-- ================================================
-- GUI
-- ================================================
local Window = GenarixUI:CreateWindow({
    Name = "Genarix Hub Premium",
    Keybind = Enum.KeyCode.RightShift
})

GenarixUI:Notify({
    Title = "Genarix Hub",
    Content = "Premium Hub v2.4.0 carregado!",
    Duration = 4
})

-- ================================================
-- AIMBOT TAB
-- ================================================
local AimbotTab = Window:CreateTab({Name = "Aimbot", Icon = "🎯"})
local AimSection = AimbotTab:CreateSection("Aimbot Settings")

local aimbotToggle = AimSection:CreateToggle({
    Name = "Enable Aimbot",
    Default = false,
    Callback = function(v)
        aimbotEnabled = v
        if v then createFOVCircle() else removeFOVCircle(); aimbotActive = false end
        GenarixUI:Notify({
            Title = "Aimbot",
            Content = v and "Aimbot Ativado!" or "Aimbot Desativado!",
            Duration = 2
        })
    end
})
allToggleAPIs.aimbot = aimbotToggle

AimSection:CreateSlider({
    Name = "FOV Radius",
    Min = 50, Max = 500, Default = 150, Increment = 10,
    Callback = function(v) aimbotFOV = v end
})

AimSection:CreateSlider({
    Name = "Smoothness",
    Min = 1, Max = 20, Default = 5, Increment = 1,
    Callback = function(v) aimbotSmooth = v end
})

AimSection:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    Default = "Head",
    Callback = function(v) aimbotPart = v end
})

AimSection:CreateDropdown({
    Name = "Aim Method",
    Options = {"Mouse", "Camera"},
    Default = "Mouse",
    Callback = function(v)
        aimbotMethod = v
        GenarixUI:Notify({
            Title = "Aimbot",
            Content = v == "Mouse"
                and "Mouse Mode: move o mouse real (melhor para shooters)"
                or "Camera Mode: move apenas a camera",
            Duration = 3
        })
    end
})

local aimbotTeamToggle = AimSection:CreateToggle({
    Name = "Team Check",
    Default = true,
    Callback = function(v) aimbotTeamCheck = v end
})
allToggleAPIs.aimbotTeam = aimbotTeamToggle

local aimbotFOVToggle = AimSection:CreateToggle({
    Name = "Show FOV Circle",
    Default = true,
    Callback = function(v)
        aimbotShowFOV = v
        if fovCircle then fovCircle.Visible = v and aimbotEnabled end
    end
})
allToggleAPIs.aimbotFOV = aimbotFOVToggle

local aimKeybindAPI = AimSection:CreateKeybind({
    Name = "Aimbot Key (Hold)",
    Default = Enum.UserInputType.MouseButton2,
    Callback = function()
        local it = aimKeybindAPI:GetInputType()
        if it then
            aimbotInputType = it
            aimbotKeyCode = (it == "Keyboard") and aimKeybindAPI:Get() or nil
        end
    end
})

do
    local it = aimKeybindAPI:GetInputType()
    if it then
        aimbotInputType = it
        aimbotKeyCode = (it == "Keyboard") and aimKeybindAPI:Get() or nil
    end
end

AimSection:CreateLabel("Segure o botao/tecla para ativar o aimbot")
AimSection:CreateLabel("Mouse Mode = tiro vai no alvo | Camera Mode = so camera")

-- ================================================
-- BULLET DROP SECTION
-- ================================================
local DropSection = AimbotTab:CreateSection("Bullet Drop Compensation")

local bulletDropToggle = DropSection:CreateToggle({
    Name = "Enable Bullet Drop",
    Default = true,
    Callback = function(v)
        bulletDropEnabled = v
        GenarixUI:Notify({
            Title = "Bullet Drop",
            Content = v and "Compensacao de queda ativada!" or "Compensacao desativada!",
            Duration = 2
        })
    end
})
allToggleAPIs.bulletDrop = bulletDropToggle

DropSection:CreateSlider({
    Name = "Drop Intensity",
    Min = 0.1, Max = 5.0, Default = 1.0, Increment = 0.1,
    Callback = function(v) bulletDropIntensity = v end
})

DropSection:CreateSlider({
    Name = "Start Distance (studs)",
    Min = 10, Max = 200, Default = 50, Increment = 5,
    Callback = function(v) bulletDropStartDist = v end
})

DropSection:CreateSlider({
    Name = "Max Drop Offset (px)",
    Min = 50, Max = 500, Default = 200, Increment = 10,
    Callback = function(v) bulletDropMaxOffset = v end
})

DropSection:CreateLabel("Intensity: quanto a mira abaixa por distancia")
DropSection:CreateLabel("Start Dist: distancia minima para comecar o drop")
DropSection:CreateLabel("Ajuste a intensidade conforme o jogo!")

-- ================================================
-- HITBOX TAB
-- ================================================
local HitboxTab = Window:CreateTab({Name = "Hitbox", Icon = "📦"})
local HitSection = HitboxTab:CreateSection("Hitbox Expander")

local hitboxToggle = HitSection:CreateToggle({
    Name = "Enable Hitbox",
    Default = false,
    Callback = function(v)
        hitboxEnabled = v
        if not v then resetHitboxes() end
        GenarixUI:Notify({
            Title = "Hitbox",
            Content = v and "Hitbox Ativada!" or "Hitbox Desativada!",
            Duration = 2
        })
    end
})
allToggleAPIs.hitbox = hitboxToggle

HitSection:CreateSlider({
    Name = "Hitbox Size",
    Min = 1, Max = 15, Default = 5, Increment = 1,
    Callback = function(v) hitboxSize = v end
})

HitSection:CreateSlider({
    Name = "Hitbox Transparency",
    Min = 0, Max = 1, Default = 0.5, Increment = 0.05,
    Callback = function(v) hitboxTransparency = v end
})

-- ================================================
-- ESP TAB
-- ================================================
local ESPTab = Window:CreateTab({Name = "ESP", Icon = "👁️"})
local ESPSection = ESPTab:CreateSection("ESP Settings")

local espToggle = ESPSection:CreateToggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(v)
        espEnabled = v
        if v then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and isEnemyESP(p) then
                    pcall(function() createESP(p) end)
                end
            end
        else
            removeAllESP()
        end
        GenarixUI:Notify({
            Title = "ESP",
            Content = v and "ESP Ativado!" or "ESP Desativado!",
            Duration = 2
        })
    end
})
allToggleAPIs.esp = espToggle

local espTeamToggle = ESPSection:CreateToggle({
    Name = "Team Check",
    Default = true,
    Callback = function(v)
        espTeamCheck = v
        if espEnabled then removeAllESP() end
    end
})
allToggleAPIs.espTeam = espTeamToggle

local espNameToggle = ESPSection:CreateToggle({
    Name = "Show Names",
    Default = true,
    Callback = function(v) espShowName = v end
})
allToggleAPIs.espName = espNameToggle

local espHealthToggle = ESPSection:CreateToggle({
    Name = "Show Health Bar",
    Default = true,
    Callback = function(v) espShowHealth = v end
})
allToggleAPIs.espHealth = espHealthToggle

local espDistToggle = ESPSection:CreateToggle({
    Name = "Show Distance",
    Default = true,
    Callback = function(v) espShowDistance = v end
})
allToggleAPIs.espDist = espDistToggle

local espBoxToggle = ESPSection:CreateToggle({
    Name = "Show Box ESP",
    Default = false,
    Callback = function(v) espShowBox = v end
})
allToggleAPIs.espBox = espBoxToggle

-- ================================================
-- PLAYER TAB
-- ================================================
local PlayerTab = Window:CreateTab({Name = "Player", Icon = "🏃"})
local MoveSection = PlayerTab:CreateSection("Movement")

local speedToggle = MoveSection:CreateToggle({
    Name = "Speed Hack",
    Default = false,
    Callback = function(v)
        speedEnabled = v
        if not v then
            local c = LocalPlayer.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = 16 end
            end
        end
    end
})
allToggleAPIs.speed = speedToggle

MoveSection:CreateSlider({
    Name = "Walk Speed",
    Min = 16, Max = 200, Default = 16, Increment = 1,
    Callback = function(v) customSpeed = v end
})

MoveSection:CreateSlider({
    Name = "Jump Power",
    Min = 50, Max = 300, Default = 50, Increment = 5,
    Callback = function(v)
        customJump = v
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.JumpPower = v end
        end
    end
})

local infJumpToggle = MoveSection:CreateToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(v)
        infJumpEnabled = v
        GenarixUI:Notify({
            Title = "Player",
            Content = v and "Infinite Jump ON!" or "Infinite Jump OFF!",
            Duration = 2
        })
    end
})
allToggleAPIs.infJump = infJumpToggle

local FlySection = PlayerTab:CreateSection("Fly & Noclip")

local flyToggle = FlySection:CreateToggle({
    Name = "Enable Fly",
    Default = false,
    Callback = function(v)
        flyEnabled = v
        if v then startFly() else stopFly() end
        GenarixUI:Notify({
            Title = "Fly",
            Content = v and "Fly ativado! (WASD+Space/Ctrl)" or "Fly desativado!",
            Duration = 2
        })
    end
})
allToggleAPIs.fly = flyToggle

FlySection:CreateSlider({
    Name = "Fly Speed",
    Min = 10, Max = 200, Default = 50, Increment = 5,
    Callback = function(v) flySpeed = v end
})

local noclipToggle = FlySection:CreateToggle({
    Name = "Noclip",
    Default = false,
    Callback = function(v)
        noclipEnabled = v
        GenarixUI:Notify({
            Title = "Noclip",
            Content = v and "Noclip ON!" or "Noclip OFF!",
            Duration = 2
        })
    end
})
allToggleAPIs.noclip = noclipToggle

-- ================================================
-- VISUALS TAB
-- ================================================
local VisualsTab = Window:CreateTab({Name = "Visuals", Icon = "🌟"})
local LightSection = VisualsTab:CreateSection("Lighting")

local fullbrightToggle = LightSection:CreateToggle({
    Name = "Fullbright",
    Default = false,
    Callback = function(v)
        fullbrightEnabled = v
        if v then enableFullbright() else disableFullbright() end
        GenarixUI:Notify({
            Title = "Visuals",
            Content = v and "Fullbright ON!" or "Fullbright OFF!",
            Duration = 2
        })
    end
})
allToggleAPIs.fullbright = fullbrightToggle

local fogToggle = LightSection:CreateToggle({
    Name = "Remove Fog",
    Default = false,
    Callback = function(v)
        removeFogEnabled = v
        toggleFog(v)
    end
})
allToggleAPIs.fog = fogToggle

local particlesToggle = LightSection:CreateToggle({
    Name = "Remove Particles",
    Default = false,
    Callback = function(v)
        removeParticlesEnabled = v
        toggleParticles(v)
    end
})
allToggleAPIs.particles = particlesToggle

-- ================================================
-- SETTINGS TAB
-- ================================================
local SettingsTab = Window:CreateTab({Name = "Settings", Icon = "⚙️"})
local ThemeSection = SettingsTab:CreateSection("Theme Color")

ThemeSection:CreateDropdown({
    Name = "Accent Color",
    Options = {"Purple", "Red", "Blue", "Green", "Orange", "Pink", "Cyan", "Yellow", "White"},
    Default = "Purple",
    Callback = function(v)
        local cm = {
            Purple = Color3.fromRGB(130, 80, 255),
            Red = Color3.fromRGB(220, 50, 60),
            Blue = Color3.fromRGB(50, 120, 255),
            Green = Color3.fromRGB(50, 200, 100),
            Orange = Color3.fromRGB(240, 140, 30),
            Pink = Color3.fromRGB(240, 80, 160),
            Cyan = Color3.fromRGB(50, 200, 220),
            Yellow = Color3.fromRGB(240, 220, 50),
            White = Color3.fromRGB(220, 220, 230)
        }
        GenarixUI:SetAccentColor(cm[v] or cm["Purple"])
        GenarixUI:Notify({Title = "Theme", Content = "Cor alterada para " .. v .. "!", Duration = 2})
    end
})

local KeySection = SettingsTab:CreateSection("Keybinds")

KeySection:CreateKeybind({
    Name = "GUI Toggle Key",
    Default = Enum.KeyCode.RightShift,
    Flag = "GUIToggle",
    Callback = function() end
})

KeySection:CreateKeybind({
    Name = "Panic Key (Desliga Tudo)",
    Default = Enum.KeyCode.P,
    Callback = function()
        aimbotEnabled = false
        hitboxEnabled = false
        espEnabled = false
        flyEnabled = false
        noclipEnabled = false
        speedEnabled = false
        infJumpEnabled = false
        fullbrightEnabled = false
        removeFogEnabled = false
        removeParticlesEnabled = false
        bulletDropEnabled = false
        aimbotActive = false

        for name, api in pairs(allToggleAPIs) do
            pcall(function() api:Set(false) end)
        end

        resetHitboxes()
        removeAllESP()
        removeFOVCircle()
        stopFly()
        disableFullbright()
        toggleFog(false)
        toggleParticles(false)

        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then
                h.WalkSpeed = 16
                h.JumpPower = 50
            end
        end

        GenarixUI:Notify({
            Title = "⚠️ PANIC",
            Content = "Todas as funcoes desativadas!",
            Duration = 3
        })
    end
})

local InfoSection = SettingsTab:CreateSection("Info")
InfoSection:CreateLabel("Genarix Hub Premium v2.4.0")
InfoSection:CreateLabel("Powered by Genarix UI Library")
InfoSection:CreateLabel("100% Free & Universal")

InfoSection:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        GenarixUI:Notify({Title = "Rejoin", Content = "Reconectando...", Duration = 2})
        task.wait(1)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end
})

InfoSection:CreateButton({
    Name = "Copy Game ID",
    Callback = function()
        pcall(function() setclipboard(tostring(game.PlaceId)) end)
        GenarixUI:Notify({Title = "Copied!", Content = "Game ID: " .. tostring(game.PlaceId), Duration = 2})
    end
})

InfoSection:CreateButton({
    Name = "Reset Character",
    Callback = function()
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
        GenarixUI:Notify({Title = "Reset", Content = "Personagem resetado!", Duration = 2})
    end
})

print("=============================================")
print("  Genarix Hub Premium v2.4.0")
print("  GUI Toggle: RightShift")
print("  Panic Key: P | Aimbot: Mouse2")
print("  Aim Method: Mouse + Bullet Drop")
print("=============================================")
