local getinfo = getinfo or debug.getinfo
local DEBUG = false
local Hooked = {}

local Detected, Kill

setthreadidentity(2)

for i, v in getgc(true) do
    if typeof(v) == "table" then
        local DetectFunc = rawget(v, "Detected")
        local KillFunc = rawget(v, "Kill")
    
        if typeof(DetectFunc) == "function" and not Detected then
            Detected = DetectFunc
            
            local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
                if Action ~= "_" then
                    if DEBUG then
                        warn(`Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`)
                    end
                end
                
                return true
            end)

            table.insert(Hooked, Detected)
        end

        if rawget(v, "Variables") and rawget(v, "Process") and typeof(KillFunc) == "function" and not Kill then
            Kill = KillFunc
            local Old; Old = hookfunction(Kill, function(Info)
                if DEBUG then
                    warn(`Adonis AntiCheat tried to kill (fallback): {Info}`)
                end
            end)

            table.insert(Hooked, Kill)
        end
    end
end

local Old; Old = hookfunction(getrenv().debug.info, newcclosure(function(...)
    local LevelOrFunc, Info = ...

    if Detected and LevelOrFunc == Detected then
        if DEBUG then
            warn(`adonis bypassed`)
        end

        return coroutine.yield(coroutine.running())
    end
    
    return Old(...)
end))

setthreadidentity(7)

local Decimals = 4
local Clock = os.clock()

--========================================================--
--                   Cerberus UI Setup
--========================================================--

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jxereas/UI-Libraries/main/cerberus.lua"))()

local window = Library.new("OmniHub - Flick")
window:LockScreenBoundaries(true)

-- Tabs
local CombatTab = window:Tab("Combat")
local RageTab = window:Tab("Rage")
local VisualsTab = window:Tab("Visuals")
local SettingsTab = window:Tab("Settings")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Shared Combat Variables
local CombatClosestPart = false
local WallCheckEnabled = false

-- Triggerbot Variables
local TriggerbotEnabled = false
local TriggerbotDelay = 0
local LastShot = 0
local ShootCooldown = 0.1

-- Aimbot Variables
local AimbotEnabled = false
local AimbotFOV = 150
local AimbotSmoothing = 50
local ShowFOVCircle = false
local FOVCircle = nil

-- Silent Aim Variables
local SilentAimEnabled = false
local SilentAimFOV = 100
local SilentAimTarget = nil
local SilentAimHitChance = 100

-- Rage Variables
local SpeedEnabled = false
local SpeedValue = 16
local FOVChangerEnabled = false
local FOVValue = 70
local SpinbotEnabled = false
local SpinbotSpeed = 10

-- ESP Variables
local Highlights = {}
local BoxESPs = {}
local HealthBars = {}
local HighlightEnabled = false
local BoxESPEnabled = false
local HealthESPEnabled = false
local EnemyColor = Color3.fromRGB(255, 0, 0)

-- Utility Functions
local function GetCharacter(player)
    return player and player.Character
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
end

local function IsAlive(character)
    local humanoid = GetHumanoid(character)
    return humanoid and humanoid.Health > 0
end

local function HasLineOfSight(origin, target)
    if not WallCheckEnabled then return true end
    
    local direction = (target - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {GetCharacter(LocalPlayer)}
    raycastParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if result then
        local hitPlayer = Players:GetPlayerFromCharacter(result.Instance.Parent)
        return hitPlayer ~= nil
    end
    
    return true
end

local function GetClosestPartToMouse(character)
    if not character then return nil end
    
    local closestPart = nil
    local shortestDistance = math.huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
    
    for _, partName in ipairs(parts) do
        local part = character:FindFirstChild(partName)
        if part then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPart = part
                end
            end
        end
    end
    
    return closestPart
end

local function GetClosestPlayerInFOV(fov, useClosestPart)
    local closestPlayer = nil
    local shortestDistance = fov or math.huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = GetCharacter(player)
            if character and IsAlive(character) then
                local targetPart = useClosestPart and GetClosestPartToMouse(character) or character:FindFirstChild("Head")
                
                if not targetPart then
                    targetPart = GetRootPart(character)
                end
                
                if targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if distance < shortestDistance then
                            if HasLineOfSight(Camera.CFrame.Position, targetPart.Position) then
                                shortestDistance = distance
                                closestPlayer = {player = player, part = targetPart}
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- FOV Circle
local function CreateFOVCircle()
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Transparency = 1
    FOVCircle.Thickness = 2
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.NumSides = 64
    FOVCircle.Radius = AimbotFOV
    FOVCircle.Filled = false
    FOVCircle.Visible = ShowFOVCircle and AimbotEnabled
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
end

CreateFOVCircle()

-- Update FOV Circle
RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
        FOVCircle.Radius = AimbotFOV
        FOVCircle.Visible = ShowFOVCircle and AimbotEnabled
    end
end)

-- Triggerbot Function
local function IsLookingAtEnemy()
    if not Camera then return false end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {GetCharacter(LocalPlayer)}
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 1000, raycastParams)
    
    if raycastResult and raycastResult.Instance then
        local hit = raycastResult.Instance
        local targetPlayer = Players:GetPlayerFromCharacter(hit.Parent)
        if targetPlayer and targetPlayer ~= LocalPlayer then
            return true
        end
    end
    return false
end

-- Triggerbot Logic
RunService.RenderStepped:Connect(function()
    if not TriggerbotEnabled then return end
    
    local currentTime = tick()
    if currentTime - LastShot < ShootCooldown then return end
    
    if IsLookingAtEnemy() then
        if TriggerbotDelay > 0 then
            task.wait(TriggerbotDelay / 1000)
        end
        mouse1press()
        task.wait(0.01)
        mouse1release()
        LastShot = currentTime
    end
end)

-- Aimbot Logic
RunService.RenderStepped:Connect(function()
    if not AimbotEnabled then return end
    
    local target = GetClosestPlayerInFOV(AimbotFOV, CombatClosestPart)
    
    if target and target.part then
        local targetPos = target.part.Position
        local cameraCFrame = Camera.CFrame
        local targetCFrame = CFrame.new(cameraCFrame.Position, targetPos)
        
        local lerpAlpha = 1 / AimbotSmoothing
        
        Camera.CFrame = cameraCFrame:Lerp(targetCFrame, lerpAlpha)
    end
end)

-- Update Silent Aim Target Loop
RunService.RenderStepped:Connect(function()
    if not SilentAimEnabled then
        SilentAimTarget = nil
        return
    end
    
    local target = GetClosestPlayerInFOV(SilentAimFOV, CombatClosestPart)
    SilentAimTarget = target
end)

-- Hook __namecall for Raycast
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
    local Args = {...}
    local Method = getnamecallmethod()
    
    if SilentAimEnabled and SilentAimTarget and math.random(1, 100) <= SilentAimHitChance then
        local targetPart = SilentAimTarget.part
        
        if Self == Workspace and Method == "Raycast" then
            Args[2] = targetPart.Position - Args[1]
            return OldNamecall(Self, unpack(Args))
        end
    end
    
    return OldNamecall(Self, ...)
end))

-- Speed Changer
RunService.Heartbeat:Connect(function()
    if SpeedEnabled then
        local character = GetCharacter(LocalPlayer)
        local humanoid = GetHumanoid(character)
        if humanoid then
            humanoid.WalkSpeed = SpeedValue
        end
    end
end)

-- FOV Changer
RunService.RenderStepped:Connect(function()
    if FOVChangerEnabled then
        Camera.FieldOfView = FOVValue
    end
end)

-- Spinbot
local SpinAngle = 0
RunService.RenderStepped:Connect(function()
    if SpinbotEnabled then
        local character = GetCharacter(LocalPlayer)
        local rootPart = GetRootPart(character)
        if rootPart then
            SpinAngle = SpinAngle + (SpinbotSpeed * 0.1)
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(SpinAngle), 0)
        end
    end
end)

--========================================================--
--                      COMBAT TAB UI
--========================================================--

local CombatSection = CombatTab:Section("Combat Settings")

CombatSection:Toggle("Closest Part", function(v)
    CombatClosestPart = v
end)

CombatSection:Toggle("Wall Check", function(v)
    WallCheckEnabled = v
end)

--========================================================--
--                    TRIGGERBOT SECTION
--========================================================--

CombatSection:Title("Triggerbot")

local TriggerbotToggleUI = CombatSection:Toggle("Triggerbot", function(v)
    TriggerbotEnabled = v
end)

CombatSection:Keybind("Triggerbot Key", function()
    TriggerbotEnabled = not TriggerbotEnabled
    TriggerbotToggleUI:Set(TriggerbotEnabled)
end, "None")

CombatSection:Slider("Triggerbot Delay (ms)", function(v)
    TriggerbotDelay = v
end, 500, 0)

--========================================================--
--                      AIMBOT SECTION
--========================================================--

CombatSection:Title("Aimbot")

local AimbotToggleUI = CombatSection:Toggle("Aimbot", function(v)
    AimbotEnabled = v
    if FOVCircle then
        FOVCircle.Visible = ShowFOVCircle and v
    end
end)

CombatSection:Keybind("Aimbot Key", function()
    AimbotEnabled = not AimbotEnabled
    AimbotToggleUI:Set(AimbotEnabled)
    if FOVCircle then
        FOVCircle.Visible = ShowFOVCircle and AimbotEnabled
    end
end, "None")

CombatSection:Toggle("Show FOV Circle", function(v)
    ShowFOVCircle = v
    if FOVCircle then
        FOVCircle.Visible = v and AimbotEnabled
    end
end)

CombatSection:Slider("Aimbot FOV", function(v)
    AimbotFOV = v
    if FOVCircle then
        FOVCircle.Radius = v
    end
end, 500, 50)

CombatSection:Slider("Aimbot Smoothing", function(v)
    AimbotSmoothing = v
end, 100, 1)

--========================================================--
--                    SILENT AIM SECTION
--========================================================--

CombatSection:Title("Silent Aim")

local SilentAimToggleUI = CombatSection:Toggle("Silent Aim", function(v)
    SilentAimEnabled = v
end)

CombatSection:Keybind("Silent Aim Key", function()
    SilentAimEnabled = not SilentAimEnabled
    SilentAimToggleUI:Set(SilentAimEnabled)
end, "None")

CombatSection:Slider("Silent Aim FOV", function(v)
    SilentAimFOV = v
end, 500, 50)

CombatSection:Slider("Silent Aim Hit Chance", function(v)
    SilentAimHitChance = v
end, 100, 0)



local RageSection = RageTab:Section("Rage Settings")

RageSection:Title("Movement")

RageSection:Toggle("Speed Changer", function(v)
    SpeedEnabled = v
    if not v then
        local character = GetCharacter(LocalPlayer)
        local humanoid = GetHumanoid(character)
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end)

RageSection:Slider("Speed Value", function(v)
    SpeedValue = v
end, 100, 16)

RageSection:Title("Camera")

RageSection:Toggle("FOV Changer", function(v)
    FOVChangerEnabled = v
    if not v then
        Camera.FieldOfView = 70
    end
end)

RageSection:Slider("FOV Value", function(v)
    FOVValue = v
end, 120, 70)

RageSection:Title("Spinbot")

RageSection:Toggle("Spinbot", function(v)
    SpinbotEnabled = v
end)

RageSection:Slider("Spinbot Speed", function(v)
    SpinbotSpeed = v
end, 50, 1)



-- Highlight Functions
local function CreateHighlight(character)
    if not character or Highlights[character] then return end
    
    local success, highlight = pcall(function()
        local h = Instance.new("Highlight")
        h.Adornee = character
        h.FillColor = EnemyColor
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = CoreGui
        return h
    end)
    
    if success and highlight then
        Highlights[character] = highlight
    end
end

local function RemoveHighlight(character)
    if Highlights[character] then
        pcall(function() Highlights[character]:Destroy() end)
        Highlights[character] = nil
    end
end

local function UpdateAllHighlights()
    if not HighlightEnabled then
        for _, highlight in pairs(Highlights) do
            pcall(function() highlight:Destroy() end)
        end
        Highlights = {}
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = GetCharacter(player)
            
            if character and IsAlive(character) then
                local highlight = Highlights[character]
                if not highlight or not highlight.Parent then
                    CreateHighlight(character)
                    highlight = Highlights[character]
                end
                if highlight then
                    highlight.FillColor = EnemyColor
                end
            else
                RemoveHighlight(character)
            end
        end
    end
end

-- Box ESP Functions
local function CreateBoxESP(player)
    if BoxESPs[player] then
        for _, v in pairs(BoxESPs[player]) do pcall(function() v:Remove() end) end
    end
    
    local box = {}
    local parts = {"TL", "TR", "BL", "BR", "L", "R", "T", "B"}
    
    for _, part in ipairs(parts) do
        box[part] = Drawing.new("Line")
        box[part].Visible = false
        box[part].Thickness = 2
        box[part].Transparency = 1
    end
    
    BoxESPs[player] = box
end

local function RemoveBoxESP(player)
    if BoxESPs[player] then
        for _, line in pairs(BoxESPs[player]) do pcall(function() line:Remove() end) end
        BoxESPs[player] = nil
    end
end

local function UpdateBoxESP(player, box)
    local character = GetCharacter(player)
    if not character or not IsAlive(character) then
        for _, line in pairs(box) do line.Visible = false end
        return
    end
    
    local rootPart = GetRootPart(character)
    if not rootPart then
        for _, line in pairs(box) do line.Visible = false end
        return
    end
    
    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    
    if not onScreen then
        for _, line in pairs(box) do line.Visible = false end
        return
    end
    
    local head = character:FindFirstChild("Head")
    local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or rootPos
    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    
    local height = math.abs(headPos.Y - legPos.Y)
    local width = height * 0.5
    local corner = width * 0.25
    
    local x1, y1 = rootPos.X - width * 0.5, headPos.Y
    local x2, y2 = rootPos.X + width * 0.5, legPos.Y
    
    box.TL.From, box.TL.To = Vector2.new(x1, y1), Vector2.new(x1 + corner, y1)
    box.TR.From, box.TR.To = Vector2.new(x2, y1), Vector2.new(x2 - corner, y1)
    box.BL.From, box.BL.To = Vector2.new(x1, y2), Vector2.new(x1 + corner, y2)
    box.BR.From, box.BR.To = Vector2.new(x2, y2), Vector2.new(x2 - corner, y2)
    box.L.From, box.L.To = Vector2.new(x1, y1), Vector2.new(x1, y1 + height * 0.25)
    box.R.From, box.R.To = Vector2.new(x2, y1), Vector2.new(x2, y1 + height * 0.25)
    box.T.From, box.T.To = Vector2.new(x1, y2), Vector2.new(x1, y2 - height * 0.25)
    box.B.From, box.B.To = Vector2.new(x2, y2), Vector2.new(x2, y2 - height * 0.25)
    
    for _, line in pairs(box) do
        line.Color = EnemyColor
        line.Visible = true
    end
end

-- Health ESP Functions
local function CreateHealthBar(player)
    if HealthBars[player] then
        for _, v in pairs(HealthBars[player]) do pcall(function() v:Remove() end) end
    end
    
    local healthBar = {
        Outline = Drawing.new("Square"),
        Bar = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    
    healthBar.Outline.Visible = false
    healthBar.Outline.Color = Color3.fromRGB(0, 0, 0)
    healthBar.Outline.Thickness = 1
    healthBar.Outline.Filled = false
    
    healthBar.Bar.Visible = false
    healthBar.Bar.Filled = true
    
    healthBar.Text.Visible = false
    healthBar.Text.Color = Color3.fromRGB(255, 255, 255)
    healthBar.Text.Size = 13
    healthBar.Text.Center = true
    healthBar.Text.Outline = true
    
    HealthBars[player] = healthBar
end

local function RemoveHealthBar(player)
    if HealthBars[player] then
        for _, element in pairs(HealthBars[player]) do pcall(function() element:Remove() end) end
        HealthBars[player] = nil
    end
end

local function UpdateHealthBar(player, healthBar)
    local character = GetCharacter(player)
    local humanoid = GetHumanoid(character)
    
    if not character or not humanoid or humanoid.Health <= 0 then
        healthBar.Outline.Visible = false
        healthBar.Bar.Visible = false
        healthBar.Text.Visible = false
        return
    end
    
    local rootPart = GetRootPart(character)
    if not rootPart then
        healthBar.Outline.Visible = false
        healthBar.Bar.Visible = false
        healthBar.Text.Visible = false
        return
    end
    
    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    
    if not onScreen then
        healthBar.Outline.Visible = false
        healthBar.Bar.Visible = false
        healthBar.Text.Visible = false
        return
    end
    
    local head = character:FindFirstChild("Head")
    local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or rootPos
    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    
    local height = math.abs(headPos.Y - legPos.Y)
    local barWidth = 4
    local barX = rootPos.X - height * 0.25 - barWidth - 5
    
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    local barFillHeight = height * healthPercent
    
    healthBar.Outline.Size = Vector2.new(barWidth + 2, height + 2)
    healthBar.Outline.Position = Vector2.new(barX - 1, headPos.Y - 1)
    healthBar.Outline.Visible = true
    
    healthBar.Bar.Size = Vector2.new(barWidth, barFillHeight)
    healthBar.Bar.Position = Vector2.new(barX, headPos.Y + (height - barFillHeight))
    healthBar.Bar.Color = healthPercent > 0.6 and Color3.fromRGB(0, 255, 0) or healthPercent > 0.3 and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
    healthBar.Bar.Visible = true
    
    healthBar.Text.Text = tostring(math.floor(humanoid.Health))
    healthBar.Text.Position = Vector2.new(barX + barWidth / 2, headPos.Y - 15)
    healthBar.Text.Visible = true
end

--========================================================--
--                      VISUALS TAB UI
--========================================================--

local VisualsSection = VisualsTab:Section("ESP Settings")

VisualsSection:Toggle("Highlight ESP", function(v)
    HighlightEnabled = v
    UpdateAllHighlights()
end)

VisualsSection:Toggle("Box ESP", function(v)
    BoxESPEnabled = v
    if not v then
        for player in pairs(BoxESPs) do RemoveBoxESP(player) end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then CreateBoxESP(player) end
        end
    end
end)

VisualsSection:Toggle("Health ESP", function(v)
    HealthESPEnabled = v
    if not v then
        for player in pairs(HealthBars) do RemoveHealthBar(player) end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then CreateHealthBar(player) end
        end
    end
end)

VisualsSection:ColorWheel("Enemy Color", function(c)
    EnemyColor = c
    UpdateAllHighlights()
end)

--========================================================--
--                      SETTINGS TAB
--========================================================--

local SettingsSection = SettingsTab:Section("Settings")

SettingsSection:Label("OmniHub - Flick")
SettingsSection:Label("Made for Flick game")

--========================================================--
--                      EVENT HANDLERS
--========================================================--

local function OnCharacterAdded(character)
    task.wait(0.1)
    if HighlightEnabled then UpdateAllHighlights() end
end

Players.PlayerAdded:Connect(function(player)
    if BoxESPEnabled then CreateBoxESP(player) end
    if HealthESPEnabled then CreateHealthBar(player) end
    player.CharacterAdded:Connect(OnCharacterAdded)
    if player.Character then OnCharacterAdded(player.Character) end
end)

Players.PlayerRemoving:Connect(function(player)
    local character = GetCharacter(player)
    if character then RemoveHighlight(character) end
    RemoveBoxESP(player)
    RemoveHealthBar(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if BoxESPEnabled then CreateBoxESP(player) end
        if HealthESPEnabled then CreateHealthBar(player) end
        local character = GetCharacter(player)
        if character then OnCharacterAdded(character) end
        player.CharacterAdded:Connect(OnCharacterAdded)
    end
end

-- Update Loops
local LastESPUpdate = 0
local ESPUpdateInterval = 0.1

RunService.Heartbeat:Connect(function()
    if not HighlightEnabled then return end
    
    local currentTime = tick()
    if currentTime - LastESPUpdate >= ESPUpdateInterval then
        UpdateAllHighlights()
        LastESPUpdate = currentTime
    end
end)

RunService.RenderStepped:Connect(function()
    if not BoxESPEnabled and not HealthESPEnabled then return end
    
    for player, box in pairs(BoxESPs) do
        if player and player.Parent then
            UpdateBoxESP(player, box)
        else
            RemoveBoxESP(player)
        end
    end
    
    for player, healthBar in pairs(HealthBars) do
        if player and player.Parent then
            UpdateHealthBar(player, healthBar)
        else
            RemoveHealthBar(player)
        end
    end
end)

local Time = string.format("%." .. tostring(Decimals) .. "f", os.clock() - Clock)
print("OmniHub loaded in " .. tostring(Time) .. "s")