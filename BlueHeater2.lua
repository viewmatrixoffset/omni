local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jxereas/UI-Libraries/main/cerberus.lua"))()

local window = Library.new("OmniHub")
window:LockScreenBoundaries(true)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MainTab = window:Tab("Main")
local VisualsTab = window:Tab("Visuals")
local SettingsTab = window:Tab("Settings")

local state = {
    highlightEnabled = false,
    textESPEnabled = false,
    killAuraEnabled = false,
    killAuraRange = 30,
    speedEnabled = false,
    walkSpeed = 100,
    flyEnabled = false,
    flySpeed = 50,
    godModeEnabled = false,
    autoFarmEnabled = false,
    infiniteStaminaEnabled = false,
    highlights = {},
    espLabels = {},
    currentTarget = nil,
    flyConnection = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
    staminaConnection = nil
}

local CombatSection = MainTab:Section("Combat")

CombatSection:Title("Kill Aura")

CombatSection:Toggle("Kill Aura", function(v)
    state.killAuraEnabled = v
end)

CombatSection:Slider("Kill Aura Range", function(v)
    state.killAuraRange = v
end, 50, 10)

CombatSection:Title("Movement")

local SpeedToggle = CombatSection:Toggle("Speed", function(v)
    state.speedEnabled = v
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = v and state.walkSpeed or 16
        end
    end
end)

CombatSection:Keybind("Speed Key", function()
    state.speedEnabled = not state.speedEnabled
    SpeedToggle:Set(state.speedEnabled)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = state.speedEnabled and state.walkSpeed or 16
        end
    end
end, "LeftShift")

CombatSection:Slider("Walk Speed", function(v)
    state.walkSpeed = v
    if state.speedEnabled then
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = v
            end
        end
    end
end, 200, 16)

local FlyToggle = CombatSection:Toggle("Fly", function(v)
    state.flyEnabled = v
    if v then
        enableFly()
    else
        disableFly()
    end
end)

CombatSection:Keybind("Fly Key", function()
    state.flyEnabled = not state.flyEnabled
    FlyToggle:Set(state.flyEnabled)
    if state.flyEnabled then
        enableFly()
    else
        disableFly()
    end
end, "None")

CombatSection:Slider("Fly Speed", function(v)
    state.flySpeed = v
end, 150, 10)

CombatSection:Title("Other")

CombatSection:Toggle("God Mode", function(v)
    state.godModeEnabled = v
end)

CombatSection:Toggle("Infinite Stamina", function(v)
    state.infiniteStaminaEnabled = v
    if v then
        enableInfiniteStamina()
    else
        disableInfiniteStamina()
    end
end)

CombatSection:Toggle("Auto Farm", function(v)
    state.autoFarmEnabled = v
    if not v then
        state.currentTarget = nil
    end
end)

CombatSection:Label("⚠️ Make sure to have Kill Aura on")

local VisualsSection = VisualsTab:Section("ESP Settings")

VisualsSection:Toggle("Highlight ESP", function(v)
    state.highlightEnabled = v
    if not v then
        for _, highlight in pairs(state.highlights) do
            if highlight then highlight:Destroy() end
        end
        state.highlights = {}
    end
end)

VisualsSection:Toggle("Text ESP", function(v)
    state.textESPEnabled = v
    if not v then
        for _, label in pairs(state.espLabels) do
            if label then label:Destroy() end
        end
        state.espLabels = {}
    end
end)

local SettingsSection = SettingsTab:Section("Settings")

SettingsSection:Label("OmniHub v1.0")
SettingsSection:Label("General UI Settings")
SettingsSection:Label("Configure visuals, binds, layout, etc.")

local function getEntities()
    local entities = {}
    local spawnedEntities = workspace:FindFirstChild("SpawnedEntities")
    if spawnedEntities then
        for _, entity in pairs(spawnedEntities:GetChildren()) do
            if entity:IsA("Model") and entity:FindFirstChild("HumanoidRootPart") then
                table.insert(entities, entity)
            end
        end
    end
    return entities
end

local function createHighlight(object)
    if not state.highlights[object] and not object:FindFirstChildOfClass("Highlight") then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = object
        highlight.Parent = object
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 1
        state.highlights[object] = highlight
    end
end

local function createTextESP(object)
    if not state.espLabels[object] then
        local rootPart = object:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Adornee = rootPart
        billboardGui.Size = UDim2.new(0, 100, 0, 50)
        billboardGui.StudsOffset = Vector3.new(0, 3, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = rootPart
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "Enemy"
        textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        textLabel.TextStrokeTransparency = 0
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 16
        textLabel.Parent = billboardGui
        
        state.espLabels[object] = billboardGui
    end
end

local function findClosestEntity(position)
    local closest = nil
    local minDist = math.huge
    
    for _, entity in pairs(getEntities()) do
        local hrp = entity:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (hrp.Position - position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = entity
            end
        end
    end
    
    return closest
end

function enableFly()
    local character = player.Character
    if not character then return end
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    state.bodyVelocity = Instance.new("BodyVelocity")
    state.bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    state.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    state.bodyVelocity.Parent = root
    
    state.bodyGyro = Instance.new("BodyGyro")
    state.bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    state.bodyGyro.P = 9e4
    state.bodyGyro.CFrame = root.CFrame
    state.bodyGyro.Parent = root
    
    state.flyConnection = RunService.Heartbeat:Connect(function()
        if not state.flyEnabled or not character or not root then
            disableFly()
            return
        end
        
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new()
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + (camera.CFrame.LookVector * state.flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - (camera.CFrame.LookVector * state.flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - (camera.CFrame.RightVector * state.flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + (camera.CFrame.RightVector * state.flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + (Vector3.new(0, 1, 0) * state.flySpeed)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDirection = moveDirection - (Vector3.new(0, 1, 0) * state.flySpeed)
        end
        
        state.bodyVelocity.Velocity = moveDirection
        state.bodyGyro.CFrame = camera.CFrame
    end)
end

function disableFly()
    if state.flyConnection then
        state.flyConnection:Disconnect()
        state.flyConnection = nil
    end
    
    if state.bodyVelocity then
        state.bodyVelocity:Destroy()
        state.bodyVelocity = nil
    end
    
    if state.bodyGyro then
        state.bodyGyro:Destroy()
        state.bodyGyro = nil
    end
end

local function setupInfiniteStamina()
    local character = player.Character or player.CharacterAdded:Wait()
    local valuesFolder = character:WaitForChild("Values")
    local staminaValue = valuesFolder:WaitForChild("Stamina")
    
    staminaValue.Value = 100
    
    if state.staminaConnection then
        state.staminaConnection:Disconnect()
    end
    
    state.staminaConnection = staminaValue.Changed:Connect(function()
        if state.infiniteStaminaEnabled and staminaValue.Value ~= 100 then
            staminaValue.Value = 100
        end
    end)
end

function enableInfiniteStamina()
    pcall(setupInfiniteStamina)
end

function disableInfiniteStamina()
    if state.staminaConnection then
        state.staminaConnection:Disconnect()
        state.staminaConnection = nil
    end
end

RunService.Heartbeat:Connect(function()
    local entities = getEntities()
    
    if state.highlightEnabled then
        for _, entity in pairs(entities) do
            createHighlight(entity)
        end
    end
    
    if state.textESPEnabled then
        for _, entity in pairs(entities) do
            createTextESP(entity)
        end
    end
    
    for entity, highlight in pairs(state.highlights) do
        if not entity or not entity.Parent then
            if highlight then highlight:Destroy() end
            state.highlights[entity] = nil
        end
    end
    
    for entity, label in pairs(state.espLabels) do
        if not entity or not entity.Parent then
            if label then label:Destroy() end
            state.espLabels[entity] = nil
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        if state.killAuraEnabled then
            pcall(function()
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                
                local targets = {}
                for _, mob in pairs(getEntities()) do
                    local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                    if mobRoot then
                        local dist = (mobRoot.Position - root.Position).Magnitude
                        if dist <= state.killAuraRange then
                            table.insert(targets, mob)
                        end
                    end
                end
                
                if #targets > 0 then
                    ReplicatedStorage.PlayerEvents.MultiEntityHit:FireServer(targets)
                end
            end)
        end
    end
end)

player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    if state.speedEnabled then
        humanoid.WalkSpeed = state.walkSpeed
    end
    
    if state.flyEnabled then
        task.wait(0.5)
        enableFly()
    end
    
    if state.infiniteStaminaEnabled then
        task.wait(0.5)
        enableInfiniteStamina()
    end
end)

RunService.Heartbeat:Connect(function()
    if state.godModeEnabled then
        pcall(function()
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health < humanoid.MaxHealth then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if state.autoFarmEnabled then
            pcall(function()
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root then return end
                
                if state.currentTarget and (not state.currentTarget.Parent or not state.currentTarget:FindFirstChild("HumanoidRootPart")) then
                    state.currentTarget = nil
                end
                
                if not state.currentTarget then
                    state.currentTarget = findClosestEntity(root.Position)
                end
                
                if state.currentTarget then
                    local targetRoot = state.currentTarget:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        local offset = (root.Position - targetRoot.Position).Unit * 5
                        local targetPos = targetRoot.Position + offset
                        root.CFrame = CFrame.new(targetPos)
                    end
                end
            end)
        end
    end
end)

print("OmniHub loaded successfully!")