local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Config = {
    TriggerbotEnabled = false,
    TriggerbotDelay = 0,
    
    AimbotEnabled = false,
    ShowAimbotFOV = false,
    AimbotFOV = 100,
    AimbotSmoothing = 10,
    
    SilentAimEnabled = false,
    ShowSilentFOV = false,
    SilentAimFOV = 100,
    SilentAimHitChance = 100,
    
    HighlightEnabled = false,
    BoxESPEnabled = false,
    HealthESPEnabled = false,
    EnemyColor = Color3.fromRGB(255, 0, 0),
    
    WalkspeedEnabled = false,
    WalkspeedValue = 16,
    FOVChangerEnabled = false,
    FOVValue = 70
}

local function IsAlive(player)
    if not player or not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    return humanoid and root and humanoid.Health > 0
end

local function GetClosestPlayerToCursor(fov)
    local closestPlayer = nil
    local shortestDistance = fov or math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local character = player.Character
            local targetPart = character:FindFirstChild("HumanoidRootPart")
            
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = {player, character, targetPart}
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local AimbotFOVCircle = Drawing.new("Circle")
AimbotFOVCircle.Thickness = 2
AimbotFOVCircle.NumSides = 64
AimbotFOVCircle.Radius = Config.AimbotFOV
AimbotFOVCircle.Filled = false
AimbotFOVCircle.Visible = false
AimbotFOVCircle.Color = Color3.fromRGB(255, 255, 255)
AimbotFOVCircle.Transparency = 1

local SilentAimFOVCircle = Drawing.new("Circle")
SilentAimFOVCircle.Thickness = 2
SilentAimFOVCircle.NumSides = 64
SilentAimFOVCircle.Radius = Config.SilentAimFOV
SilentAimFOVCircle.Filled = false
SilentAimFOVCircle.Visible = false
SilentAimFOVCircle.Color = Color3.fromRGB(255, 0, 0)
SilentAimFOVCircle.Transparency = 1

RunService.RenderStepped:Connect(function()
    local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)
    
    AimbotFOVCircle.Position = mousePos
    AimbotFOVCircle.Radius = Config.AimbotFOV
    AimbotFOVCircle.Visible = Config.ShowAimbotFOV and Config.AimbotEnabled
    
    SilentAimFOVCircle.Position = mousePos
    SilentAimFOVCircle.Radius = Config.SilentAimFOV
    SilentAimFOVCircle.Visible = Config.ShowSilentFOV and Config.SilentAimEnabled
end)

local AimbotConnection = nil

local function StartAimbot()
    if AimbotConnection then return end
    
    AimbotConnection = RunService.RenderStepped:Connect(function()
        if not Config.AimbotEnabled then return end
        
        local target = GetClosestPlayerToCursor(Config.AimbotFOV)
        if target then
            local targetPart = target[3]
            local targetPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                local mousePos = Vector2.new(Mouse.X, Mouse.Y + 36)
                local smoothing = math.max(Config.AimbotSmoothing, 1)
                
                local moveX = (targetPos.X - mousePos.X) / smoothing
                local moveY = (targetPos.Y - mousePos.Y) / smoothing
                
                mousemoverel(moveX, moveY)
            end
        end
    end)
end

StartAimbot()

local SilentAimTarget = nil

RunService.Heartbeat:Connect(function()
    if Config.SilentAimEnabled then
        SilentAimTarget = GetClosestPlayerToCursor(Config.SilentAimFOV)
    else
        SilentAimTarget = nil
    end
end)

local OldNamecall = nil
OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
    if checkcaller() then return OldNamecall(Self, ...) end
    
    if SilentAimTarget and Config.SilentAimEnabled and math.random(1, 100) <= Config.SilentAimHitChance then
        local Args = {...}
        local Method = getnamecallmethod()
        
        if Self == Workspace and Method == "Raycast" then
            local targetPos = SilentAimTarget[3].Position
            Args[2] = (targetPos - Args[1]).Unit * Args[2].Magnitude
            return OldNamecall(Self, unpack(Args))
        end
    end
    
    return OldNamecall(Self, ...)
end)

local lastTriggerTime = 0

RunService.Heartbeat:Connect(function()
    if not Config.TriggerbotEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastTriggerTime < Config.TriggerbotDelay / 1000 then return end
    
    local target = Mouse.Target
    if target then
        local player = Players:GetPlayerFromCharacter(target.Parent)
        if player and player ~= LocalPlayer and IsAlive(player) then
            mouse1click()
            lastTriggerTime = currentTime
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if Config.WalkspeedEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.WalkspeedValue
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if Config.FOVChangerEnabled then
        Camera.FieldOfView = Config.FOVValue
    end
end)

local ESPObjects = {}

local function RemoveESP(player)
    if ESPObjects[player] then
        if ESPObjects[player].Highlight then
            pcall(function() ESPObjects[player].Highlight:Destroy() end)
        end
        
        if ESPObjects[player].Box then
            for _, line in pairs(ESPObjects[player].Box) do
                pcall(function() line:Remove() end)
            end
        end
        
        if ESPObjects[player].Health then
            pcall(function() ESPObjects[player].Health.Bar:Remove() end)
            pcall(function() ESPObjects[player].Health.Text:Remove() end)
        end
        
        ESPObjects[player] = nil
    end
end

local function CreateHighlightESP(character)
    local existingHighlight = character:FindFirstChildOfClass("Highlight")
    if existingHighlight then
        pcall(function() existingHighlight:Destroy() end)
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = character
    highlight.Parent = character
    highlight.FillColor = Config.EnemyColor
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    return highlight
end

local function CreateBoxESP()
    local box = {}
    
    for i = 1, 4 do
        box[i] = Drawing.new("Line")
        box[i].Thickness = 2
        box[i].Color = Config.EnemyColor
        box[i].Visible = false
        box[i].Transparency = 1
    end
    
    return box
end

local function CreateHealthESP()
    local healthBar = Drawing.new("Line")
    healthBar.Thickness = 3
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Visible = false
    healthBar.Transparency = 1
    
    local healthText = Drawing.new("Text")
    healthText.Size = 14
    healthText.Center = true
    healthText.Outline = true
    healthText.Color = Color3.fromRGB(255, 255, 255)
    healthText.Visible = false
    healthText.Transparency = 1
    
    return {Bar = healthBar, Text = healthText}
end

local function UpdateBoxESP(box, character)
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if not root or not humanoid or humanoid.Health <= 0 then
        for _, line in pairs(box) do
            line.Visible = false
        end
        return nil
    end
    
    local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen then
        for _, line in pairs(box) do
            line.Visible = false
        end
        return nil
    end
    
    local headPos = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
    
    local height = math.abs(headPos.Y - legPos.Y)
    local width = height / 2
    
    local x1 = math.floor(rootPos.X - width / 2)
    local y1 = math.floor(headPos.Y)
    local x2 = math.floor(rootPos.X + width / 2)
    local y2 = math.floor(legPos.Y)
    
    box[1].From = Vector2.new(x1, y1)
    box[1].To = Vector2.new(x2, y1)
    
    box[2].From = Vector2.new(x1, y2)
    box[2].To = Vector2.new(x2, y2)
    
    box[3].From = Vector2.new(x1, y1)
    box[3].To = Vector2.new(x1, y2)
    
    box[4].From = Vector2.new(x2, y1)
    box[4].To = Vector2.new(x2, y2)
    
    for _, line in pairs(box) do
        line.Color = Config.EnemyColor
        line.Visible = true
    end
    
    return {x1, y1, x2, y2, height}
end

local function UpdateHealthESP(health, character, boxData)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not root or humanoid.Health <= 0 or not boxData then
        health.Bar.Visible = false
        health.Text.Visible = false
        return
    end
    
    local x1, y1, x2, y2, height = boxData[1], boxData[2], boxData[3], boxData[4], boxData[5]
    local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
    
    local barHeight = height * healthPercent
    health.Bar.From = Vector2.new(x1 - 6, y2)
    health.Bar.To = Vector2.new(x1 - 6, y2 - barHeight)
    health.Bar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
    health.Bar.Visible = true
    
    health.Text.Text = tostring(math.floor(humanoid.Health))
    health.Text.Position = Vector2.new(x1 - 6, y1 - 15)
    health.Text.Visible = true
end

local function UpdateESP(player)
    if not IsAlive(player) then
        RemoveESP(player)
        return
    end
    
    local character = player.Character
    if not character then
        RemoveESP(player)
        return
    end
    
    if not ESPObjects[player] then
        ESPObjects[player] = {
            Highlight = nil,
            Box = CreateBoxESP(),
            Health = CreateHealthESP()
        }
    end
    
    if Config.HighlightEnabled then
        if not ESPObjects[player].Highlight or not ESPObjects[player].Highlight.Parent then
            pcall(function()
                ESPObjects[player].Highlight = CreateHighlightESP(character)
            end)
        end
        if ESPObjects[player].Highlight then
            ESPObjects[player].Highlight.FillColor = Config.EnemyColor
        end
    else
        if ESPObjects[player].Highlight then
            pcall(function()
                ESPObjects[player].Highlight:Destroy()
                ESPObjects[player].Highlight = nil
            end)
        end
    end
    
    local boxData = nil
    if Config.BoxESPEnabled then
        boxData = UpdateBoxESP(ESPObjects[player].Box, character)
    else
        for _, line in pairs(ESPObjects[player].Box) do
            line.Visible = false
        end
    end
    
    if Config.HealthESPEnabled and boxData then
        UpdateHealthESP(ESPObjects[player].Health, character, boxData)
    else
        ESPObjects[player].Health.Bar.Visible = false
        ESPObjects[player].Health.Text.Visible = false
    end
end

RunService.RenderStepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            pcall(function()
                UpdateESP(player)
            end)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterRemoving:Connect(function()
        RemoveESP(player)
    end)
end)

for _, player in pairs(Players:GetPlayers()) do
    if player.Character then
        player.CharacterRemoving:Connect(function()
            RemoveESP(player)
        end)
    end
end

local Decimals = 4
local Clock = os.clock()

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/drillygzzly/Roblox-UI-Libs/main/1%20Tokyo%20Lib%20(FIXED)/Tokyo%20Lib%20Source.lua"))({
    cheatname = "OmniHub",
    gamename = "Universal",
})
library:init()

local Window = library.NewWindow({
    title = "OmniHub | Universal",
    size = UDim2.new(0, 510, 0.6, 6)
})

local CombatTab = Window:AddTab("  Combat  ")
local VisualsTab = Window:AddTab("  Visuals  ")
local MiscTab = Window:AddTab("  Misc  ")
local SettingsTab = library:CreateSettingsTab(Window)

local TriggerbotSection = CombatTab:AddSection("Triggerbot", 1)

TriggerbotSection:AddToggle({
    text = "Enable Triggerbot",
    state = false,
    risky = false,
    tooltip = "Automatically shoots when hovering over enemies",
    flag = "Triggerbot_Toggle",
    callback = function(v)
        Config.TriggerbotEnabled = v
    end
}):AddBind({
    enabled = true,
    text = "Triggerbot Keybind",
    tooltip = "Toggle triggerbot on/off",
    mode = "toggle",
    bind = "None",
    flag = "Triggerbot_Key",
    state = false,
    nomouse = false,
    risky = false,
    noindicator = false,
    callback = function(v)
        Config.TriggerbotEnabled = v
    end
})

TriggerbotSection:AddSlider({
    enabled = true,
    text = "Triggerbot Delay",
    tooltip = "Delay in milliseconds before shooting",
    flag = "Triggerbot_Delay",
    suffix = "ms",
    min = 0,
    max = 500,
    increment = 10,
    risky = false,
    callback = function(v)
        Config.TriggerbotDelay = v
    end
})

local AimbotSection = CombatTab:AddSection("Aimbot", 1)

AimbotSection:AddToggle({
    text = "Enable Aimbot",
    state = false,
    risky = true,
    tooltip = "Smooth aimbot targeting",
    flag = "Aimbot_Toggle",
    callback = function(v)
        Config.AimbotEnabled = v
    end
}):AddBind({
    enabled = true,
    text = "Aimbot Keybind",
    tooltip = "Toggle aimbot on/off",
    mode = "toggle",
    bind = "None",
    flag = "Aimbot_Key",
    state = false,
    nomouse = false,
    risky = false,
    noindicator = false,
    callback = function(v)
        Config.AimbotEnabled = v
    end
})

AimbotSection:AddToggle({
    text = "Show FOV Circle",
    state = false,
    risky = false,
    tooltip = "Display aimbot FOV circle",
    flag = "Aimbot_ShowFOV",
    callback = function(v)
        Config.ShowAimbotFOV = v
    end
})

AimbotSection:AddSlider({
    enabled = true,
    text = "Aimbot FOV",
    tooltip = "Field of view for aimbot targeting",
    flag = "Aimbot_FOV",
    suffix = "",
    min = 50,
    max = 500,
    increment = 5,
    risky = false,
    callback = function(v)
        Config.AimbotFOV = v
    end
})

AimbotSection:AddSlider({
    enabled = true,
    text = "Aimbot Smoothing",
    tooltip = "Lower = faster aim, Higher = smoother aim",
    flag = "Aimbot_Smoothing",
    suffix = "",
    min = 1,
    max = 100,
    increment = 1,
    risky = false,
    callback = function(v)
        Config.AimbotSmoothing = v
    end
})

local SilentAimSection = CombatTab:AddSection("Silent Aim", 1)

SilentAimSection:AddToggle({
    text = "Enable Silent Aim",
    state = false,
    risky = true,
    tooltip = "Silent aim without camera movement",
    flag = "SilentAim_Toggle",
    callback = function(v)
        Config.SilentAimEnabled = v
    end
}):AddBind({
    enabled = true,
    text = "Silent Aim Keybind",
    tooltip = "Toggle silent aim on/off",
    mode = "toggle",
    bind = "None",
    flag = "SilentAim_Key",
    state = false,
    nomouse = false,
    risky = false,
    noindicator = false,
    callback = function(v)
        Config.SilentAimEnabled = v
    end
})

SilentAimSection:AddToggle({
    text = "Show FOV Circle",
    state = false,
    risky = false,
    tooltip = "Display silent aim FOV circle",
    flag = "SilentAim_ShowFOV",
    callback = function(v)
        Config.ShowSilentFOV = v
    end
})

SilentAimSection:AddSlider({
    enabled = true,
    text = "Silent Aim FOV",
    tooltip = "Field of view for silent aim targeting",
    flag = "SilentAim_FOV",
    suffix = "",
    min = 50,
    max = 500,
    increment = 5,
    risky = false,
    callback = function(v)
        Config.SilentAimFOV = v
    end
})

SilentAimSection:AddSlider({
    enabled = true,
    text = "Hit Chance",
    tooltip = "Percentage chance to hit target",
    flag = "SilentAim_HitChance",
    suffix = "%",
    min = 0,
    max = 100,
    increment = 5,
    risky = false,
    callback = function(v)
        Config.SilentAimHitChance = v
    end
})

local ESPSection = VisualsTab:AddSection("ESP Settings", 1)

ESPSection:AddToggle({
    text = "Highlight ESP",
    state = false,
    risky = false,
    tooltip = "3D character highlighting",
    flag = "Highlight_Toggle",
    callback = function(v)
        Config.HighlightEnabled = v
        if not v then
            for player, objects in pairs(ESPObjects) do
                if objects.Highlight then
                    pcall(function()
                        objects.Highlight:Destroy()
                        objects.Highlight = nil
                    end)
                end
            end
        end
    end
})

ESPSection:AddToggle({
    text = "Box ESP",
    state = false,
    risky = false,
    tooltip = "2D box around players",
    flag = "Box_Toggle",
    callback = function(v)
        Config.BoxESPEnabled = v
    end
})

ESPSection:AddToggle({
    text = "Health ESP",
    state = false,
    risky = false,
    tooltip = "Display player health bar and text",
    flag = "Health_Toggle",
    callback = function(v)
        Config.HealthESPEnabled = v
    end
})

ESPSection:AddColor({
    enabled = true,
    text = "ESP Color",
    tooltip = "Change ESP color",
    color = Color3.fromRGB(255, 0, 0),
    flag = "ESP_Color",
    trans = 0,
    open = false,
    risky = false,
    callback = function(v)
        Config.EnemyColor = v
    end
})

local MovementSection = MiscTab:AddSection("Movement", 1)

MovementSection:AddToggle({
    text = "Walkspeed Changer",
    state = false,
    risky = false,
    tooltip = "Modify player walkspeed",
    flag = "Walkspeed_Toggle",
    callback = function(v)
        Config.WalkspeedEnabled = v
    end
})

MovementSection:AddSlider({
    enabled = true,
    text = "Walkspeed",
    tooltip = "Set walkspeed value",
    flag = "Walkspeed_Value",
    suffix = "",
    min = 16,
    max = 200,
    increment = 1,
    risky = false,
    callback = function(v)
        Config.WalkspeedValue = v
    end
})

local CameraSection = MiscTab:AddSection("Camera", 1)

CameraSection:AddToggle({
    text = "FOV Changer",
    state = false,
    risky = false,
    tooltip = "Modify camera field of view",
    flag = "FOV_Toggle",
    callback = function(v)
        Config.FOVChangerEnabled = v
    end
})

CameraSection:AddSlider({
    enabled = true,
    text = "FOV Value",
    tooltip = "Set camera FOV value",
    flag = "FOV_Value",
    suffix = "",
    min = 70,
    max = 120,
    increment = 1,
    risky = false,
    callback = function(v)
        Config.FOVValue = v
    end
})

local Time = (string.format("%."..tostring(Decimals).."f", os.clock() - Clock))
library:SendNotification(("OmniHub Loaded In "..tostring(Time).."s"), 6)