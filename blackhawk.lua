--========================================================--
--                   Cerberus UI Setup
--========================================================--

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

-- UI Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Jxereas/UI-Libraries/main/cerberus.lua"))()

-- UI Window
local window = Library.new("OmniHub")
window:LockScreenBoundaries(true)

-- Tabs
local MainTab = window:Tab("Main")
local VisualsTab = window:Tab("Visuals")

--========================================================--
--                      VARIABLES
--========================================================--

-- Aimbot Variables
local AimbotEnabled = false
local AimbotKey = nil
local AimbotFOV = 200
local AimbotSmoothing = 5
local AimbotHoldKey = false
local ShowFOV = false

-- Triggerbot Variables
local TriggerbotEnabled = false
local TriggerbotKey = nil
local TriggerbotDelay = 100
local TriggerbotHoldKey = false

-- ESP Variables
local HighlightEnabled = false
local BoxESPEnabled = false
local ESPColor = Color3.fromRGB(0, 255, 200)

-- Storage
local ESPObjects = {}
local FOVCircle = nil

--========================================================--
--                      MAIN TAB
--========================================================--

local MainSection = MainTab:Section("Combat Features")

MainSection:Title("Aimbot")

-- Aimbot Toggle
local AimbotToggle = MainSection:Toggle("Aimbot", function(v)
    AimbotEnabled = v
end)

-- Aimbot Keybind
MainSection:Keybind("Aimbot Toggle Key", function()
    AimbotEnabled = not AimbotEnabled
    AimbotToggle:Set(AimbotEnabled)
end, "None")

-- Aimbot FOV
MainSection:Slider("Aimbot FOV", function(v)
    AimbotFOV = v
    if FOVCircle then
        FOVCircle.Radius = v
    end
end, 500, 50)

-- Aimbot Smoothing
MainSection:Slider("Aimbot Smoothing", function(v)
    AimbotSmoothing = v
end, 20, 1)

-- Show FOV Circle
MainSection:Toggle("Show FOV Circle", function(v)
    ShowFOV = v
    if FOVCircle then
        FOVCircle.Visible = v
    end
end)

MainSection:Title("Triggerbot")

-- Triggerbot Toggle
local TriggerbotToggle = MainSection:Toggle("Triggerbot", function(v)
    TriggerbotEnabled = v
end)

-- Triggerbot Keybind
MainSection:Keybind("Triggerbot Toggle Key", function()
    TriggerbotEnabled = not TriggerbotEnabled
    TriggerbotToggle:Set(TriggerbotEnabled)
end, "None")

-- Triggerbot Delay
MainSection:Slider("Triggerbot Delay (ms)", function(v)
    TriggerbotDelay = v
end, 500, 0)

--========================================================--
--                    VISUALS TAB
--========================================================--

local VisualsSection = VisualsTab:Section("ESP Settings")

-- Highlight ESP
VisualsSection:Toggle("Highlight ESP", function(v)
    HighlightEnabled = v
    if not v then
        -- Remove all highlights
        for _, data in pairs(ESPObjects) do
            if data.Highlight then
                data.Highlight:Destroy()
            end
        end
    end
end)

-- Box ESP
VisualsSection:Toggle("Box ESP", function(v)
    BoxESPEnabled = v
    if not v then
        -- Remove all boxes
        for _, data in pairs(ESPObjects) do
            if data.BoxDrawing then
                for _, drawing in pairs(data.BoxDrawing) do
                    drawing:Remove()
                end
            end
        end
    end
end)

-- ESP Color
VisualsSection:ColorWheel("ESP Color", function(c)
    ESPColor = c
    -- Update existing ESP colors
    for _, data in pairs(ESPObjects) do
        if data.Highlight then
            data.Highlight.FillColor = c
        end
        if data.BoxDrawing then
            for _, drawing in pairs(data.BoxDrawing) do
                drawing.Color = c
            end
        end
    end
end)

--========================================================--
--                  UTILITY FUNCTIONS
--========================================================--

-- Get all Male models in workspace
local function getMaleModels()
    local models = {}
    for _, object in pairs(Workspace:GetChildren()) do
        if object:IsA("Model") and object.Name == "Male" then
            table.insert(models, object)
        end
    end
    return models
end

-- Get closest Male model to cursor
local function getClosestMale()
    local closestMale = nil
    local shortestDistance = AimbotFOV
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, male in pairs(getMaleModels()) do
        local hrp = male:FindFirstChild("HumanoidRootPart") or male:FindFirstChild("Head") or male:FindFirstChildWhichIsA("BasePart")
        if hrp then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestMale = male
                end
            end
        end
    end
    
    return closestMale
end

-- Get target part from Male model
local function getTargetPart(model)
    return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

--========================================================--
--                  FOV CIRCLE
--========================================================--

local function createFOVCircle()
    local circle = Drawing.new("Circle")
    circle.Thickness = 2
    circle.NumSides = 50
    circle.Radius = AimbotFOV
    circle.Filled = false
    circle.Visible = ShowFOV
    circle.Color = Color3.fromRGB(255, 255, 255)
    circle.Transparency = 1
    return circle
end

FOVCircle = createFOVCircle()

local function updateFOVCircle()
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = AimbotFOV
        FOVCircle.Visible = ShowFOV
    end
end

--========================================================--
--                  HIGHLIGHT ESP
--========================================================--

local function updateHighlightESP()
    if not HighlightEnabled then return end
    
    for _, male in pairs(getMaleModels()) do
        if male and male.Parent then
            if not ESPObjects[male] then
                ESPObjects[male] = {}
            end
            
            if not ESPObjects[male].Highlight then
                local success, highlight = pcall(function()
                    local h = Instance.new("Highlight")
                    h.Adornee = male
                    h.Parent = male
                    h.FillColor = ESPColor
                    h.FillTransparency = 0.75
                    h.OutlineTransparency = 1
                    return h
                end)
                
                if success then
                    ESPObjects[male].Highlight = highlight
                end
            else
                -- Update color if it changed
                if ESPObjects[male].Highlight then
                    pcall(function()
                        ESPObjects[male].Highlight.FillColor = ESPColor
                    end)
                end
            end
        end
    end
end

--========================================================--
--                  2D BOX ESP
--========================================================--

local function createBoxDrawing()
    local box = {}
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = 2
        line.Color = ESPColor
        line.Transparency = 1
        table.insert(box, line)
    end
    return box
end

local function updateBoxESP()
    if not BoxESPEnabled then return end
    
    for _, male in pairs(getMaleModels()) do
        if male and male.Parent then
            if not ESPObjects[male] then
                ESPObjects[male] = {}
            end
            
            if not ESPObjects[male].BoxDrawing then
                ESPObjects[male].BoxDrawing = createBoxDrawing()
            end
            
            local box = ESPObjects[male].BoxDrawing
            
            -- Try to find the HumanoidRootPart or Head
            local hrp = male:FindFirstChild("HumanoidRootPart") or male:FindFirstChild("Head") or male:FindFirstChild("Torso")
            
            if hrp and hrp.Parent then
                local success = pcall(function()
                    -- Get model bounds
                    local cf, size = male:GetBoundingBox()
                    
                    -- Reduce width by 30% to make box tighter
                    size = Vector3.new(size.X * 0.7, size.Y, size.Z * 0.7)
                    
                    -- Calculate 8 corners of the 3D bounding box
                    local corners3D = {
                        cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
                        cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
                        cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
                        cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
                        cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
                        cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
                        cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
                        cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)
                    }
                    
                    -- Convert to 2D screen space
                    local corners2D = {}
                    
                    for _, corner in ipairs(corners3D) do
                        local screenPos, onScreen = Camera:WorldToViewportPoint(corner.Position)
                        if onScreen then
                            table.insert(corners2D, Vector2.new(screenPos.X, screenPos.Y))
                        end
                    end
                    
                    -- Find min/max bounds for 2D box
                    if #corners2D > 0 then
                        local minX, minY = math.huge, math.huge
                        local maxX, maxY = -math.huge, -math.huge
                        
                        for _, corner in ipairs(corners2D) do
                            minX = math.min(minX, corner.X)
                            minY = math.min(minY, corner.Y)
                            maxX = math.max(maxX, corner.X)
                            maxY = math.max(maxY, corner.Y)
                        end
                        
                        -- Draw 2D bounding box
                        local topLeft = Vector2.new(minX, minY)
                        local topRight = Vector2.new(maxX, minY)
                        local bottomLeft = Vector2.new(minX, maxY)
                        local bottomRight = Vector2.new(maxX, maxY)
                        
                        box[1].From = topLeft
                        box[1].To = topRight
                        box[1].Visible = true
                        box[1].Color = ESPColor
                        
                        box[2].From = topRight
                        box[2].To = bottomRight
                        box[2].Visible = true
                        box[2].Color = ESPColor
                        
                        box[3].From = bottomRight
                        box[3].To = bottomLeft
                        box[3].Visible = true
                        box[3].Color = ESPColor
                        
                        box[4].From = bottomLeft
                        box[4].To = topLeft
                        box[4].Visible = true
                        box[4].Color = ESPColor
                    else
                        -- Hide box if not visible
                        for _, line in pairs(box) do
                            line.Visible = false
                        end
                    end
                end)
                
                if not success then
                    -- Hide box on error
                    for _, line in pairs(box) do
                        line.Visible = false
                    end
                end
            else
                -- Hide box if no valid part
                for _, line in pairs(box) do
                    line.Visible = false
                end
            end
        end
    end
end

--========================================================--
--                      AIMBOT
--========================================================--

local function runAimbot()
    if not AimbotEnabled then return end
    
    local targetMale = getClosestMale()
    if targetMale then
        local targetPart = getTargetPart(targetMale)
        if targetPart and targetPart.Parent then
            local targetPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            
            if onScreen then
                local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local targetScreen = Vector2.new(targetPos.X, targetPos.Y)
                local distance = targetScreen - screenCenter
                
                -- Check if within FOV
                if distance.Magnitude <= AimbotFOV then
                    -- Smooth mouse movement
                    local moveX = distance.X / AimbotSmoothing
                    local moveY = distance.Y / AimbotSmoothing
                    
                    mousemoverel(moveX, moveY)
                end
            end
        end
    end
end

--========================================================--
--                    TRIGGERBOT (FIXED)
--========================================================--

local lastShot = 0

local function runTriggerbot()
    if not TriggerbotEnabled then return end
    
    local currentTime = tick()
    local delayInSeconds = TriggerbotDelay / 1000
    
    -- Only check delay if delay is greater than 0
    if TriggerbotDelay > 0 and (currentTime - lastShot) < delayInSeconds then 
        return 
    end
    
    -- Check if any Male model is under the crosshair (screen center)
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local triggerRadius = 20 -- Increased radius for better detection
    
    for _, male in pairs(getMaleModels()) do
        if male and male.Parent then
            -- Check multiple parts for better detection
            local parts = {
                male:FindFirstChild("Head"),
                male:FindFirstChild("HumanoidRootPart"),
                male:FindFirstChild("Torso"),
                male:FindFirstChild("UpperTorso")
            }
            
            for _, targetPart in pairs(parts) do
                if targetPart and targetPart.Parent then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        
                        -- If target is within trigger radius from crosshair
                        if distance <= triggerRadius then
                            mouse1click()
                            lastShot = currentTime
                            return -- Exit after shooting once
                        end
                    end
                end
            end
        end
    end
end

--========================================================--
--                  MAIN LOOP
--========================================================--

-- Cleanup function
local function cleanupESP()
    for male, data in pairs(ESPObjects) do
        if not male or not male.Parent or not male:IsDescendantOf(Workspace) then
            if data.Highlight then
                pcall(function()
                    data.Highlight:Destroy()
                end)
            end
            if data.BoxDrawing then
                for _, drawing in pairs(data.BoxDrawing) do
                    pcall(function()
                        drawing:Remove()
                    end)
                end
            end
            ESPObjects[male] = nil
        end
    end
end

-- Main update loop
RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    updateHighlightESP()
    updateBoxESP()
    runAimbot()
    runTriggerbot()
    cleanupESP()
end)

-- Keybind handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Note: Keybinds are handled automatically by the UI library
    -- This section can be used for additional custom keybind logic if needed
end)

print("OmniHub loaded successfully!")
