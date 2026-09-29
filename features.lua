--[[
    features.lua
    Universal Visuals & Performance Features Engine for Atomware (Universal Script)
    Cross-platform visual features: Player ESP (BillboardGui), Material Chams (t1r4), Chinese Hat, and Tracers.
    Engineered with 100% native Roblox engine rendering for full iPad / Mobile / PC compatibility.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera", 10)

local function trackConnection(conn)
    if _G.AtomwareConfig and type(_G.AtomwareConfig.TrackConnection) == "function" then
        return _G.AtomwareConfig:TrackConnection(conn)
    end
    return conn
end

local function trackTask(t)
    if _G.AtomwareConfig and type(_G.AtomwareConfig.TrackTask) == "function" then
        return _G.AtomwareConfig:TrackTask(t)
    end
    return t
end

-- Update camera reference if changed
trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end))

--//==================================================
--// GUI PARENT RESOLVER (CROSS-PLATFORM IPAD / PC)
--//==================================================

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if playerGui then return playerGui end
    return CoreGui
end

-- ScreenGui for 2D screen elements (Tracers, ScreenGui fallback lines)
local ScreenGuiContainer = nil
pcall(function()
    local parent = getGuiParent()
    local existing = parent:FindFirstChild("AtomwareScreenVisuals")
    if existing then existing:Destroy() end

    ScreenGuiContainer = Instance.new("ScreenGui")
    ScreenGuiContainer.Name = "AtomwareScreenVisuals"
    ScreenGuiContainer.ResetOnSpawn = false
    ScreenGuiContainer.IgnoreGuiInset = true
    ScreenGuiContainer.DisplayOrder = 9999
    ScreenGuiContainer.Parent = parent
    if _G.AtomwareCleanup and type(_G.AtomwareCleanup.TrackInstance) == "function" then
        _G.AtomwareCleanup:TrackInstance(ScreenGuiContainer)
    end
end)

-- Check if native Drawing API is available and functional
local hasNativeDrawing = false
pcall(function()
    if type(Drawing) == "table" and type(Drawing.new) == "function" then
        local test = Drawing.new("Line")
        if test then
            test.Visible = false
            test:Remove()
            hasNativeDrawing = true
        end
    end
end)

--//==================================================
--// CONFIGURATION STATE
--//==================================================

local VisualsState = {
    -- Player ESP
    ESPEnabled      = false,
    BoxESP          = false,
    BoxStyle        = "2D Box",   -- "2D Box" or "Corner Box"
    NameESP         = false,
    DistanceESP     = false,
    HealthBar       = false,
    ToolESP         = false,
    Tracers         = false,
    TracerOrigin    = "Bottom",   -- "Bottom", "Center", "Mouse"
    TeamCheck       = false,
    ESPColor        = Color3.fromRGB(157, 48, 255),
    TeamColor       = Color3.fromRGB(42, 255, 157),

    -- Material Chams (t1r4)
    ChamsEnabled    = false,
    ChamsMaterial   = "ForceField",
    ChamsColor      = Color3.fromRGB(120, 200, 255),
    ChamsSeeThrough = true,
    ChamsTeamCheck  = false,

    -- Chinese Hat ESP
    HatEnabled      = false,
    HatLocalPlayer  = true,
    HatOthers       = true,
    HatRadius       = 2,
    HatSegments     = 12,
    HatColor        = Color3.fromRGB(205, 104, 255),
    HatRotate       = true,
}

--//==================================================
--// MATERIAL CHAMS ENGINE (t1r4 ADAPTATION)
--//==================================================

local ChamsMaterials = {
    ["ForceField"] = { material = Enum.Material.ForceField,  reflectance = 0,   transparency = 0,   tint = true  },
    ["Neon"]       = { material = Enum.Material.Neon,        reflectance = 0,   transparency = 0,   tint = true  },
    ["Glass"]      = { material = Enum.Material.Glass,       reflectance = 0.3, transparency = 0.4, tint = true  },
    ["Marble"]     = { material = Enum.Material.Marble,      reflectance = 0,   transparency = 0,   tint = false },
    ["Foil"]       = { material = Enum.Material.Foil,        reflectance = 0.4, transparency = 0,   tint = false },
    ["Metal"]      = { material = Enum.Material.DiamondPlate,reflectance = 0.5, transparency = 0,   tint = false },
    ["Wood"]       = { material = Enum.Material.WoodPlanks,  reflectance = 0,   transparency = 0,   tint = false },
    ["Ice"]        = { material = Enum.Material.Ice,         reflectance = 0.2, transparency = 0.2, tint = true  },
}

local ChamsApplied = {}

local function isBodyPart(inst)
    return inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart"
end

local function restoreChams(plr)
    local rec = ChamsApplied[plr]
    if not rec then return end
    for part, orig in pairs(rec.originals) do
        if part and part.Parent then
            part.Material     = orig.Material
            part.Reflectance  = orig.Reflectance
            part.Color        = orig.Color
            part.Transparency = orig.Transparency
            if orig.TextureID ~= nil and part:IsA("MeshPart") then
                part.TextureID = orig.TextureID
            end
        end
    end
    for inst, parentRef in pairs(rec.hidden) do
        if inst then
            pcall(function() inst.Parent = parentRef end)
        end
    end
    if rec.highlight then
        pcall(function() rec.highlight:Destroy() end)
    end
    ChamsApplied[plr] = nil
end

local function hideOverlay(rec, inst)
    if rec.hidden[inst] == nil and inst.Parent then
        rec.hidden[inst] = inst.Parent
        pcall(function() inst.Parent = nil end)
    end
end

local function applyChams(plr)
    if plr == LocalPlayer then return end
    if VisualsState.ChamsTeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
        restoreChams(plr)
        return
    end

    local char = plr.Character
    if not char then return end

    local preset = ChamsMaterials[VisualsState.ChamsMaterial] or ChamsMaterials["ForceField"]
    local rec = ChamsApplied[plr]
    if not rec then
        rec = { originals = {}, hidden = {}, highlight = nil }
        ChamsApplied[plr] = rec
    end

    for _, inst in ipairs(char:GetDescendants()) do
        if isBodyPart(inst) then
            local part = inst
            if not rec.originals[part] then
                rec.originals[part] = {
                    Material     = part.Material,
                    Reflectance  = part.Reflectance,
                    Color        = part.Color,
                    Transparency = part.Transparency,
                    TextureID    = part:IsA("MeshPart") and part.TextureID or nil,
                }
            end
            part.Material     = preset.material
            part.Reflectance  = preset.reflectance
            part.Transparency = preset.transparency or 0
            if part:IsA("MeshPart") then
                part.TextureID = ""
            end
            if preset.tint then
                part.Color = VisualsState.ChamsColor
            end
        elseif inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic")
            or inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("SurfaceAppearance") then
            hideOverlay(rec, inst)
        end
    end

    if VisualsState.ChamsSeeThrough then
        if not rec.highlight or not rec.highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "AtomwareChamsGlow"
            hl.FillTransparency = 1
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = CoreGui
            rec.highlight = hl
        end
        rec.highlight.Adornee = char
        rec.highlight.OutlineColor = VisualsState.ChamsColor
    elseif rec.highlight then
        pcall(function() rec.highlight:Destroy() end)
        rec.highlight = nil
    end
end

local function restoreAllChams()
    for plr in pairs(ChamsApplied) do
        restoreChams(plr)
    end
end

local function refreshAllChams()
    if not VisualsState.ChamsEnabled then
        restoreAllChams()
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        applyChams(plr)
    end
end

--//==================================================
--// RIG & TOOL DETECTION
--//==================================================

local function getCharacterRigType(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.RigType == Enum.HumanoidRigType.R15 then
        return "R15"
    elseif hum and hum.RigType == Enum.HumanoidRigType.R6 then
        return "R6"
    end
    if character:FindFirstChild("UpperTorso") then return "R15" end
    return "R6"
end

local function getCharacterTool(character)
    local tool = character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil
end

local function getCharacterRoot(character)
    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character.PrimaryPart
end

--//==================================================
--// NATIVE BILLBOARD ESP ENGINE (IPAD, MOBILE & PC)
--//==================================================

local ESPHolders = {}

local function createPlayerESP(player)
    local parent = getGuiParent()

    local bbg = Instance.new("BillboardGui")
    bbg.Name = "AtomwarePlayerESP_" .. player.Name
    bbg.AlwaysOnTop = true
    bbg.ResetOnSpawn = false
    bbg.ClipsDescendants = false
    bbg.Size = UDim2.new(4.2, 0, 5.6, 0)
    bbg.StudsOffset = Vector3.new(0, 0, 0)
    bbg.Enabled = false
    bbg.Parent = parent

    -- 2D Box Frame
    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxFrame"
    boxFrame.BackgroundTransparency = 1
    boxFrame.Size = UDim2.fromScale(1, 1)
    boxFrame.BorderSizePixel = 0
    boxFrame.Parent = bbg

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Name = "BoxStroke"
    boxStroke.Color = VisualsState.ESPColor
    boxStroke.Thickness = 1.5
    boxStroke.LineJoinMode = Enum.LineJoinMode.Miter
    boxStroke.Parent = boxFrame

    -- Corner Box Container (8 lines)
    local cornerContainer = Instance.new("Frame")
    cornerContainer.Name = "CornerContainer"
    cornerContainer.BackgroundTransparency = 1
    cornerContainer.Size = UDim2.fromScale(1, 1)
    cornerContainer.Visible = false
    cornerContainer.Parent = bbg

    local cornerBrackets = {}
    local cornerPositions = {
        { UDim2.new(0, 0, 0, 0), UDim2.new(0.25, 0, 0, 1.5) },       -- TL Horizontal
        { UDim2.new(0, 0, 0, 0), UDim2.new(0, 1.5, 0.25, 0) },       -- TL Vertical
        { UDim2.new(0.75, 0, 0, 0), UDim2.new(0.25, 0, 0, 1.5) },    -- TR Horizontal
        { UDim2.new(1, -1.5, 0, 0), UDim2.new(0, 1.5, 0.25, 0) },    -- TR Vertical
        { UDim2.new(0, 0, 1, -1.5), UDim2.new(0.25, 0, 0, 1.5) },    -- BL Horizontal
        { UDim2.new(0, 0, 0.75, 0), UDim2.new(0, 1.5, 0.25, 0) },    -- BL Vertical
        { UDim2.new(0.75, 0, 1, -1.5), UDim2.new(0.25, 0, 0, 1.5) }, -- BR Horizontal
        { UDim2.new(1, -1.5, 0.75, 0), UDim2.new(0, 1.5, 0.25, 0) }, -- BR Vertical
    }

    for i, p in ipairs(cornerPositions) do
        local line = Instance.new("Frame")
        line.Position = p[1]
        line.Size = p[2]
        line.BackgroundColor3 = VisualsState.ESPColor
        line.BorderSizePixel = 0
        line.Parent = cornerContainer
        table.insert(cornerBrackets, line)
    end

    -- Health Bar (Left)
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBg"
    healthBarBg.AnchorPoint = Vector2.new(1, 0)
    healthBarBg.Position = UDim2.new(0, -5, 0, 0)
    healthBarBg.Size = UDim2.new(0, 3, 1, 0)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Visible = false
    healthBarBg.Parent = bbg

    local healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthBarFill"
    healthBarFill.AnchorPoint = Vector2.new(0, 1)
    healthBarFill.Position = UDim2.new(0, 0, 1, 0)
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(42, 255, 157)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarBg

    -- Name & Distance Label (Top)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Position = UDim2.new(0.5, 0, 0, -5)
    nameLabel.Size = UDim2.new(2, 0, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(245, 241, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Visible = false
    nameLabel.Parent = bbg

    local nameStroke = Instance.new("UIStroke")
    nameStroke.Color = Color3.fromRGB(10, 7, 20)
    nameStroke.Thickness = 1
    nameStroke.Parent = nameLabel

    -- Tool Label (Bottom)
    local toolLabel = Instance.new("TextLabel")
    toolLabel.Name = "ToolLabel"
    toolLabel.AnchorPoint = Vector2.new(0.5, 0)
    toolLabel.Position = UDim2.new(0.5, 0, 1, 5)
    toolLabel.Size = UDim2.new(2, 0, 0, 14)
    toolLabel.BackgroundTransparency = 1
    toolLabel.Font = Enum.Font.GothamMedium
    toolLabel.TextSize = 11
    toolLabel.TextColor3 = Color3.fromRGB(205, 104, 255)
    toolLabel.TextXAlignment = Enum.TextXAlignment.Center
    toolLabel.Visible = false
    toolLabel.Parent = bbg

    local toolStroke = Instance.new("UIStroke")
    toolStroke.Color = Color3.fromRGB(10, 7, 20)
    toolStroke.Thickness = 1
    toolStroke.Parent = toolLabel

    -- Tracer line (ScreenGui Frame fallback)
    local tracerFrame = nil
    if ScreenGuiContainer then
        tracerFrame = Instance.new("Frame")
        tracerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        tracerFrame.BorderSizePixel = 0
        tracerFrame.BackgroundColor3 = VisualsState.ESPColor
        tracerFrame.Visible = false
        tracerFrame.Parent = ScreenGuiContainer
    end

    return {
        Player = player,
        Billboard = bbg,
        BoxFrame = boxFrame,
        BoxStroke = boxStroke,
        CornerContainer = cornerContainer,
        CornerBrackets = cornerBrackets,
        HealthBarBg = healthBarBg,
        HealthBarFill = healthBarFill,
        NameLabel = nameLabel,
        ToolLabel = toolLabel,
        TracerFrame = tracerFrame,
        ChineseHatPart = nil,
        ChineseHatWeld = nil,
    }
end

local function removePlayerESP(entry)
    if not entry then return end
    if entry.Billboard then
        pcall(function() entry.Billboard:Destroy() end)
    end
    if entry.TracerFrame then
        pcall(function() entry.TracerFrame:Destroy() end)
    end
    if entry.ChineseHatPart then
        pcall(function() entry.ChineseHatPart:Destroy() end)
    end
    table.clear(entry)
end

--//==================================================
--// CHINESE HAT (NATIVE 3D COSMETIC CONE ON HEAD)
--//==================================================

local function updateChineseHat(entry, char, isLocal)
    if not VisualsState.HatEnabled then
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
            entry.ChineseHatWeld = nil
        end
        return
    end

    if isLocal and not VisualsState.HatLocalPlayer then
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

    if not isLocal and not VisualsState.HatOthers then
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

    local head = char:FindFirstChild("Head")
    if not head then return end

    if not entry.ChineseHatPart or not entry.ChineseHatPart.Parent or not entry.ChineseHatWeld or not entry.ChineseHatWeld.Parent then
        if entry.ChineseHatPart then pcall(function() entry.ChineseHatPart:Destroy() end) end

        local hat = Instance.new("Part")
        hat.Name = "AtomwareChineseHat"
        hat.CanCollide = false
        hat.CanTouch = false
        hat.CanQuery = false
        hat.Massless = true
        hat.CastShadow = false
        hat.Material = Enum.Material.ForceField
        hat.Color = VisualsState.HatColor
        hat.Transparency = 0.35
        hat.Size = Vector3.new(0.2, 0.2, 0.2)

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://1778999" -- Classic Asian Rice / Cone Hat mesh
        local scale = VisualsState.HatRadius * 1.4
        mesh.Scale = Vector3.new(scale, scale * 0.6, scale)
        mesh.Parent = hat

        local weld = Instance.new("Weld")
        weld.Part0 = head
        weld.Part1 = hat
        weld.C0 = CFrame.new(0, 0.72, 0)
        weld.Parent = hat

        hat.Parent = char
        entry.ChineseHatPart = hat
        entry.ChineseHatWeld = weld
    else
        entry.ChineseHatPart.Color = VisualsState.HatColor
        local scale = VisualsState.HatRadius * 1.4
        local mesh = entry.ChineseHatPart:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            mesh.Scale = Vector3.new(scale, scale * 0.6, scale)
        end
        if VisualsState.HatRotate and entry.ChineseHatWeld then
            local rotAngle = tick() * 90 % 360
            entry.ChineseHatWeld.C0 = CFrame.new(0, 0.72, 0) * CFrame.Angles(0, math.rad(rotAngle), 0)
        end
    end
end

--//==================================================
--// MAIN RENDER LOOP (PER FRAME UPDATE)
--//==================================================

local function getTracerOrigin()
    local vp = Camera.ViewportSize
    if VisualsState.TracerOrigin == "Center" then
        return Vector2.new(vp.X / 2, vp.Y / 2)
    elseif VisualsState.TracerOrigin == "Mouse" then
        local mousePos = UserInputService:GetMouseLocation()
        return Vector2.new(mousePos.X, mousePos.Y)
    end
    return Vector2.new(vp.X / 2, vp.Y)
end

local function updatePlayer(entry)
    local plr = entry.Player
    local isLocal = (plr == LocalPlayer)
    local char = plr.Character

    if not char then
        entry.Billboard.Enabled = false
        if entry.TracerFrame then entry.TracerFrame.Visible = false end
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = getCharacterRoot(char)

    if not hum or hum.Health <= 0 or not root then
        entry.Billboard.Enabled = false
        if entry.TracerFrame then entry.TracerFrame.Visible = false end
        return
    end

    -- Chinese Hat Update
    updateChineseHat(entry, char, isLocal)

    if isLocal then
        entry.Billboard.Enabled = false
        if entry.TracerFrame then entry.TracerFrame.Visible = false end
        return
    end

    -- Team Check
    local isTeammate = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
    if VisualsState.TeamCheck and isTeammate then
        entry.Billboard.Enabled = false
        if entry.TracerFrame then entry.TracerFrame.Visible = false end
        return
    end

    -- Chams per frame update
    if VisualsState.ChamsEnabled then
        applyChams(plr)
    end

    if not VisualsState.ESPEnabled then
        entry.Billboard.Enabled = false
        if entry.TracerFrame then entry.TracerFrame.Visible = false end
        return
    end

    -- Attach Adornee
    entry.Billboard.Adornee = root
    entry.Billboard.Enabled = true

    local espColor = (isTeammate and VisualsState.TeamColor) or VisualsState.ESPColor

    -- Rig Detection sizing
    local rig = getCharacterRigType(char)
    if rig == "R15" then
        entry.Billboard.Size = UDim2.new(4.4, 0, 6.0, 0)
    else
        entry.Billboard.Size = UDim2.new(4.0, 0, 5.2, 0)
    end

    -- 1. Box ESP
    if VisualsState.BoxESP then
        if VisualsState.BoxStyle == "Corner Box" then
            entry.BoxFrame.Visible = false
            entry.CornerContainer.Visible = true
            for _, br in ipairs(entry.CornerBrackets) do
                br.BackgroundColor3 = espColor
            end
        else
            entry.CornerContainer.Visible = false
            entry.BoxFrame.Visible = true
            entry.BoxStroke.Color = espColor
        end
    else
        entry.BoxFrame.Visible = false
        entry.CornerContainer.Visible = false
    end

    -- 2. Health Bar
    if VisualsState.HealthBar then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        entry.HealthBarBg.Visible = true
        entry.HealthBarFill.Size = UDim2.new(1, 0, hpPct, 0)
        entry.HealthBarFill.BackgroundColor3 = Color3.fromHSV(hpPct * 0.33, 0.9, 1)
    else
        entry.HealthBarBg.Visible = false
    end

    -- 3. Name & Distance ESP
    if VisualsState.NameESP or VisualsState.DistanceESP then
        local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
        local textStr = ""
        if VisualsState.NameESP then textStr = plr.DisplayName or plr.Name end
        if VisualsState.DistanceESP then
            textStr = textStr ~= "" and (textStr .. " [" .. dist .. "m]") or ("[" .. dist .. "m]")
        end
        entry.NameLabel.Text = textStr
        entry.NameLabel.Visible = true
    else
        entry.NameLabel.Visible = false
    end

    -- 4. Tool ESP
    if VisualsState.ToolESP then
        local tool = getCharacterTool(char)
        if tool then
            entry.ToolLabel.Text = tool
            entry.ToolLabel.Visible = true
        else
            entry.ToolLabel.Visible = false
        end
    else
        entry.ToolLabel.Visible = false
    end

    -- 5. Tracers
    if VisualsState.Tracers and entry.TracerFrame then
        local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local origin = getTracerOrigin()
            local targetPos = Vector2.new(rootPos.X, rootPos.Y)
            local dist = (targetPos - origin).Magnitude
            local mid = (origin + targetPos) / 2
            local angle = math.deg(math.atan2(targetPos.Y - origin.Y, targetPos.X - origin.X))

            entry.TracerFrame.Visible = true
            entry.TracerFrame.BackgroundColor3 = espColor
            entry.TracerFrame.Size = UDim2.fromOffset(dist, 1.5)
            entry.TracerFrame.Position = UDim2.fromOffset(mid.X, mid.Y)
            entry.TracerFrame.Rotation = angle
        else
            entry.TracerFrame.Visible = false
        end
    elseif entry.TracerFrame then
        entry.TracerFrame.Visible = false
    end
end

-- Render loop
trackConnection(RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        local entry = ESPHolders[plr]
        if not entry then
            entry = createPlayerESP(plr)
            ESPHolders[plr] = entry
        end
        updatePlayer(entry)
    end
end))

-- Handle PlayerAdded & PlayerRemoving
trackConnection(Players.PlayerAdded:Connect(function(plr)
    if not ESPHolders[plr] then
        ESPHolders[plr] = createPlayerESP(plr)
    end
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if VisualsState.ChamsEnabled then applyChams(plr) end
    end)
end))

trackConnection(Players.PlayerRemoving:Connect(function(plr)
    restoreChams(plr)
    if ESPHolders[plr] then
        removePlayerESP(ESPHolders[plr])
        ESPHolders[plr] = nil
    end
end))

-- Pre-populate existing players
for _, plr in ipairs(Players:GetPlayers()) do
    if not ESPHolders[plr] then
        ESPHolders[plr] = createPlayerESP(plr)
    end
end

--//==================================================
--// EVENT HOOK CONNECTIONS FROM UI (SAFE WRAPPERS)
--//==================================================

local function bindToggle(name, cb)
    if type(_G.OnToggle) == "function" then
        _G.OnToggle(name, cb)
    else
        _G.AtomwareEvents = _G.AtomwareEvents or {}
        _G.AtomwareEvents[name] = cb
    end
end

local function bindSlider(name, cb)
    if type(_G.OnSlider) == "function" then
        _G.OnSlider(name, cb)
    else
        _G.AtomwareEvents = _G.AtomwareEvents or {}
        _G.AtomwareEvents[name] = cb
    end
end

local function bindDropdown(name, cb)
    if type(_G.OnDropdown) == "function" then
        _G.OnDropdown(name, cb)
    else
        _G.AtomwareEvents = _G.AtomwareEvents or {}
        _G.AtomwareEvents[name] = cb
    end
end

local function bindColorPicker(name, cb)
    if type(_G.OnColorPicker) == "function" then
        _G.OnColorPicker(name, cb)
    else
        _G.AtomwareEvents = _G.AtomwareEvents or {}
        _G.AtomwareEvents[name] = cb
    end
end

-- Player ESP
bindToggle("Enable ESP", function(v) VisualsState.ESPEnabled = v end)
bindToggle("Box ESP", function(v) VisualsState.BoxESP = v end)
bindDropdown("Box Style", function(v) VisualsState.BoxStyle = v end)
bindToggle("Name ESP", function(v) VisualsState.NameESP = v end)
bindToggle("Distance ESP", function(v) VisualsState.DistanceESP = v end)
bindToggle("Health Bar", function(v) VisualsState.HealthBar = v end)
bindToggle("Tool ESP", function(v) VisualsState.ToolESP = v end)
bindToggle("Tracers", function(v) VisualsState.Tracers = v end)
bindDropdown("Tracer Origin", function(v) VisualsState.TracerOrigin = v end)
bindToggle("Team Check", function(v) VisualsState.TeamCheck = v end)
bindColorPicker("ESP Color", function(v) VisualsState.ESPColor = v end)
bindColorPicker("Team Color", function(v) VisualsState.TeamColor = v end)

-- Material Chams (t1r4)
bindToggle("Enable Chams", function(v)
    VisualsState.ChamsEnabled = v
    refreshAllChams()
end)
bindDropdown("Material", function(v)
    if ChamsMaterials[v] then
        restoreAllChams()
        VisualsState.ChamsMaterial = v
        refreshAllChams()
    end
end)
bindColorPicker("Chams Color", function(v)
    VisualsState.ChamsColor = v
    refreshAllChams()
end)
bindToggle("See Through (Glow)", function(v)
    VisualsState.ChamsSeeThrough = v
    refreshAllChams()
end)
bindToggle("Chams Team Check", function(v)
    VisualsState.ChamsTeamCheck = v
    refreshAllChams()
end)

-- Chinese Hat ESP
bindToggle("Chinese Hat", function(v) VisualsState.HatEnabled = v end)
bindToggle("Hat on Local Player", function(v) VisualsState.HatLocalPlayer = v end)
bindToggle("Hat on Others", function(v) VisualsState.HatOthers = v end)
bindSlider("Hat Radius", function(v) VisualsState.HatRadius = v end)
bindSlider("Hat Segments", function(v) VisualsState.HatSegments = v end)
bindColorPicker("Hat Color", function(v) VisualsState.HatColor = v end)
bindToggle("Rotate Hat", function(v) VisualsState.HatRotate = v end)

--//==================================================
--// UNLOAD HANDLER
--//==================================================

if _G.AtomwareConfig and type(_G.AtomwareConfig.OnUnload) == "function" then
    _G.AtomwareConfig:OnUnload(function()
        restoreAllChams()
        for _, entry in pairs(ESPHolders) do
            removePlayerESP(entry)
        end
        table.clear(ESPHolders)
        if ScreenGuiContainer then
            pcall(function() ScreenGuiContainer:Destroy() end)
            ScreenGuiContainer = nil
        end
    end)
end

_G.AtomwareFeaturesLoaded = true
print("Atomware Universal: Cross-Platform Visuals Engine Online")
