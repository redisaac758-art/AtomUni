--[[
    features.lua
    Universal Visuals & Performance Features Engine for Atomware (Universal Script)
    Cross-platform visual features: Player ESP (BillboardGui + 3D Box), Material Chams (t1r4), Chinese Hat, and Tracers.
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

local function getScreenGuiParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if pg then return pg end
    return CoreGui
end

-- ScreenGui for 2D screen elements (Tracers)
local ScreenGuiContainer = nil
local function ensureScreenGuiContainer()
    if ScreenGuiContainer and ScreenGuiContainer.Parent then return ScreenGuiContainer end
    pcall(function()
        local parent = getScreenGuiParent()
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
    return ScreenGuiContainer
end
ensureScreenGuiContainer()

--//==================================================
--// CONFIGURATION STATE
--//==================================================

local VisualsState = {
    -- Player ESP
    ESPEnabled      = false,
    BoxESP          = false,
    BoxStyle        = "2D Box",   -- "2D Box", "Corner Box", "3D Box"
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
    HatColor        = Color3.fromRGB(175, 60, 255),
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
--// PURE 2D SCREENGUI ESP & WORKSPACE CHINESE HAT
--// 100% Cross-Platform: Works on PC and iPad/Mobile
--// Bypasses mobile GPU BillboardGui/depth-buffer culling
--//==================================================

local ESPHolders = {}

local BOX_EDGES = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local function createPlayerESP(player)
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    -- CRITICAL: Use a full-viewport transparent Frame as the per-player holder.
    -- Folder instances cannot parent GuiObjects for rendering on Roblox iOS/iPad.
    -- All GuiObject children must live inside a GuiObject (Frame), not a Folder.
    local holder = Instance.new("Frame")
    holder.Name = "AtomwareESP_" .. player.Name
    holder.Size = UDim2.fromScale(1, 1)
    holder.Position = UDim2.fromScale(0, 0)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = false
    -- ZIndex > 1 ensures it sits above the base ScreenGui layer
    holder.ZIndex = 2
    pcall(function() holder.Parent = container end)

    -- 1. 2D Box Frame (absolute pixels, positioned each frame)
    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxFrame"
    boxFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.ZIndex = 3
    boxFrame.Parent = holder

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Name = "BoxStroke"
    boxStroke.Color = VisualsState.ESPColor
    boxStroke.Thickness = 1.5
    boxStroke.LineJoinMode = Enum.LineJoinMode.Miter
    boxStroke.Parent = boxFrame

    -- 2. Corner Box Container inside boxFrame (same size, hidden by default)
    local cornerContainer = Instance.new("Frame")
    cornerContainer.Name = "CornerContainer"
    cornerContainer.BackgroundTransparency = 1
    cornerContainer.BorderSizePixel = 0
    cornerContainer.Size = UDim2.fromScale(1, 1)
    cornerContainer.Visible = false
    cornerContainer.ZIndex = 3
    cornerContainer.Parent = boxFrame

    local cornerBrackets = {}
    for i = 1, 8 do
        local line = Instance.new("Frame")
        line.BorderSizePixel = 0
        line.BackgroundColor3 = VisualsState.ESPColor
        line.ZIndex = 4
        line.Parent = cornerContainer
        table.insert(cornerBrackets, line)
    end

    -- 3. 3D Wireframe Box Lines (12 edge lines, each absolute-positioned each frame)
    local box3DLines = {}
    for i = 1, 12 do
        local line = Instance.new("Frame")
        line.Name = "Box3DLine_" .. i
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.BackgroundColor3 = VisualsState.ESPColor
        line.Visible = false
        line.ZIndex = 3
        line.Parent = holder
        table.insert(box3DLines, line)
    end

    -- 4. Health Bar Background + Fill
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBg"
    healthBarBg.AnchorPoint = Vector2.new(1, 0)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Visible = false
    healthBarBg.ZIndex = 3
    healthBarBg.Parent = holder

    local healthStroke = Instance.new("UIStroke")
    healthStroke.Color = Color3.fromRGB(0, 0, 0)
    healthStroke.Thickness = 1
    healthStroke.Parent = healthBarBg

    local healthBarFill = Instance.new("Frame")
    healthBarFill.Name = "HealthBarFill"
    healthBarFill.AnchorPoint = Vector2.new(0, 1)
    healthBarFill.Position = UDim2.new(0, 0, 1, 0)
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = Color3.fromRGB(42, 255, 157)
    healthBarFill.BorderSizePixel = 0
    healthBarFill.ZIndex = 4
    healthBarFill.Parent = healthBarBg

    -- 5. Name & Distance Label (absolute-positioned each frame)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Size = UDim2.fromOffset(200, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.fromRGB(245, 241, 255)
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.Visible = false
    nameLabel.ZIndex = 5
    nameLabel.Parent = holder

    -- 6. Tool Label (absolute-positioned each frame)
    local toolLabel = Instance.new("TextLabel")
    toolLabel.Name = "ToolLabel"
    toolLabel.AnchorPoint = Vector2.new(0.5, 0)
    toolLabel.Size = UDim2.fromOffset(200, 14)
    toolLabel.BackgroundTransparency = 1
    toolLabel.Font = Enum.Font.GothamMedium
    toolLabel.TextSize = 12
    toolLabel.TextColor3 = Color3.fromRGB(205, 104, 255)
    toolLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    toolLabel.TextStrokeTransparency = 0
    toolLabel.TextXAlignment = Enum.TextXAlignment.Center
    toolLabel.TextYAlignment = Enum.TextYAlignment.Center
    toolLabel.Visible = false
    toolLabel.ZIndex = 5
    toolLabel.Parent = holder

    -- 7. Tracer Line
    local tracerFrame = Instance.new("Frame")
    tracerFrame.Name = "Tracer"
    tracerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    tracerFrame.BorderSizePixel = 0
    tracerFrame.BackgroundColor3 = VisualsState.ESPColor
    tracerFrame.Visible = false
    tracerFrame.ZIndex = 2
    tracerFrame.Parent = holder

    return {
        Player = player,
        Holder = holder,
        BoxFrame = boxFrame,
        BoxStroke = boxStroke,
        CornerContainer = cornerContainer,
        CornerBrackets = cornerBrackets,
        Box3DLines = box3DLines,
        HealthBarBg = healthBarBg,
        HealthBarFill = healthBarFill,
        NameLabel = nameLabel,
        ToolLabel = toolLabel,
        TracerFrame = tracerFrame,
        ChineseHatPart = nil,
    }
end

local function removePlayerESP(entry)
    if not entry then return end
    if entry.Holder then pcall(function() entry.Holder:Destroy() end) end
    if entry.ChineseHatPart then pcall(function() entry.ChineseHatPart:Destroy() end) end
    table.clear(entry)
end

--//==================================================
--// CHINESE HAT (HOVERING 3D PURPLE GRADIENT LINED CONE)
--// Anchored in Workspace/Character like Chams
--//==================================================

local function createLinedHat(char)
    local ok, hat = pcall(function()
        local h = Instance.new("Part")
        h.Name = "AtomwareChineseHat"
        h.CanCollide = false
        h.CanTouch = false
        h.CanQuery = false
        h.Massless = true
        h.CastShadow = false
        h.Anchored = true
        h.Material = Enum.Material.ForceField -- Dynamic see-through energy purple gradient
        h.Color = VisualsState.HatColor
        h.Transparency = 0.35
        h.Size = Vector3.new(0.2, 0.2, 0.2)

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://1033714" -- Official classic Asian straw cone hat mesh
        local scale = VisualsState.HatRadius * 1.5
        mesh.Scale = Vector3.new(scale, scale * 0.7, scale)
        mesh.Parent = h

        -- 8 Glowing neon purple rib lines radiating from apex to brim
        local ribs = 8
        local brimRadius = VisualsState.HatRadius * 1.35
        local apexY = 0.42
        local brimY = -0.32

        for i = 1, ribs do
            local angle = ((i - 1) / ribs) * math.pi * 2
            local bx = math.cos(angle) * brimRadius
            local bz = math.sin(angle) * brimRadius

            local startPt = Vector3.new(0, apexY, 0)
            local endPt = Vector3.new(bx, brimY, bz)
            local midPt = (startPt + endPt) / 2
            local length = (endPt - startPt).Magnitude

            local rib = Instance.new("Part")
            rib.Name = "HatRib"
            rib.CanCollide = false
            rib.CanTouch = false
            rib.CanQuery = false
            rib.Massless = true
            rib.CastShadow = false
            rib.Material = Enum.Material.Neon
            rib.Color = Color3.fromRGB(235, 140, 255)
            rib.Transparency = 0.15
            rib.Size = Vector3.new(0.04, 0.04, length)

            local ribWeld = Instance.new("Weld")
            ribWeld.Part0 = h
            ribWeld.Part1 = rib
            ribWeld.C0 = CFrame.lookAt(midPt, endPt)
            ribWeld.Parent = rib
            rib.Parent = h
        end

        h.Parent = char
        return h
    end)

    if ok and hat then return hat end
    return nil
end

local function updateChineseHat(entry, char, isLocal)
    if not VisualsState.HatEnabled then
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
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
    if not head then
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

    if not entry.ChineseHatPart or not entry.ChineseHatPart.Parent then
        if entry.ChineseHatPart then pcall(function() entry.ChineseHatPart:Destroy() end) end
        entry.ChineseHatPart = createLinedHat(char)
    end

    if entry.ChineseHatPart then
        local hat = entry.ChineseHatPart
        hat.Color = VisualsState.HatColor
        local scale = VisualsState.HatRadius * 1.5
        local mesh = hat:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            mesh.Scale = Vector3.new(scale, scale * 0.7, scale)
        end

        local rotAngle = VisualsState.HatRotate and (tick() * 90 % 360) or 0
        -- Smoothly positions hat hovering 1.85 studs above head center in RenderStepped!
        hat.CFrame = head.CFrame * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.rad(rotAngle), 0)
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

local function hidePlayerVisuals(entry)
    entry.BoxFrame.Visible = false
    entry.CornerContainer.Visible = false
    for _, l in ipairs(entry.Box3DLines) do l.Visible = false end
    entry.HealthBarBg.Visible = false
    entry.NameLabel.Visible = false
    entry.ToolLabel.Visible = false
    entry.TracerFrame.Visible = false
end

local function updatePlayer(entry)
    local plr = entry.Player
    local isLocal = (plr == LocalPlayer)
    local char = plr.Character

    if not char then
        hidePlayerVisuals(entry)
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = getCharacterRoot(char)

    if not hum or hum.Health <= 0 or not root then
        hidePlayerVisuals(entry)
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

    -- Chinese Hat Update (guarded in pcall)
    pcall(function()
        updateChineseHat(entry, char, isLocal)
    end)

    if isLocal then
        hidePlayerVisuals(entry)
        return
    end

    -- Team Check
    local isTeammate = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
    if VisualsState.TeamCheck and isTeammate then
        hidePlayerVisuals(entry)
        return
    end

    -- Chams per frame update (100% PRESERVED)
    if VisualsState.ChamsEnabled then
        pcall(function() applyChams(plr) end)
    end

    if not VisualsState.ESPEnabled then
        hidePlayerVisuals(entry)
        return
    end

    local espColor = (isTeammate and VisualsState.TeamColor) or VisualsState.ESPColor
    local rig = getCharacterRigType(char)

    -- Calculate 3D to 2D screen projections
    local H = (rig == "R15" and 5.2 or 4.8)
    local W = 3.6
    local D = 2.4

    local topPos = root.Position + Vector3.new(0, H / 2 + 0.35, 0)
    local bottomPos = root.Position - Vector3.new(0, H / 2 + 0.15, 0)

    local topScreen, topOn = Camera:WorldToViewportPoint(topPos)
    local bottomScreen, botOn = Camera:WorldToViewportPoint(bottomPos)

    -- Must be in front of camera
    if topScreen.Z <= 0 or bottomScreen.Z <= 0 or (not topOn and not botOn) then
        hidePlayerVisuals(entry)
        return
    end

    local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
    local boxWidth = boxHeight * 0.65
    local boxCenter = Vector2.new(bottomScreen.X, (topScreen.Y + bottomScreen.Y) / 2)
    local boxLeft = boxCenter.X - boxWidth / 2
    local boxRight = boxCenter.X + boxWidth / 2
    local boxTop = boxCenter.Y - boxHeight / 2
    local boxBottom = boxCenter.Y + boxHeight / 2

    -- 1. Box ESP: "2D Box", "Corner Box", or "3D Box"
    if VisualsState.BoxESP then
        if VisualsState.BoxStyle == "3D Box" then
            entry.BoxFrame.Visible = false
            entry.CornerContainer.Visible = false

            -- Calculate 8 3D corners in world space
            local cf = root.CFrame
            local hx, hy, hz = W / 2, H / 2 + 0.2, D / 2
            local corners3D = {
                cf * Vector3.new(-hx,  hy, -hz),
                cf * Vector3.new( hx,  hy, -hz),
                cf * Vector3.new( hx, -hy, -hz),
                cf * Vector3.new(-hx, -hy, -hz),
                cf * Vector3.new(-hx,  hy,  hz),
                cf * Vector3.new( hx,  hy,  hz),
                cf * Vector3.new( hx, -hy,  hz),
                cf * Vector3.new(-hx, -hy,  hz),
            }

            local screenPts = {}
            local allVisible = true
            for i = 1, 8 do
                local pt, vis = Camera:WorldToViewportPoint(corners3D[i])
                if pt.Z <= 0 then allVisible = false break end
                screenPts[i] = Vector2.new(pt.X, pt.Y)
            end

            if allVisible then
                for idx, edge in ipairs(BOX_EDGES) do
                    local p1 = screenPts[edge[1]]
                    local p2 = screenPts[edge[2]]
                    local line = entry.Box3DLines[idx]
                    if line and p1 and p2 then
                        local dist = (p2 - p1).Magnitude
                        local mid = (p1 + p2) / 2
                        local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))

                        line.Visible = true
                        line.BackgroundColor3 = espColor
                        line.Size = UDim2.fromOffset(dist, 1.5)
                        line.Position = UDim2.fromOffset(mid.X, mid.Y)
                        line.Rotation = angle
                    end
                end
            else
                for _, l in ipairs(entry.Box3DLines) do l.Visible = false end
            end
        else
            for _, l in ipairs(entry.Box3DLines) do l.Visible = false end

            entry.BoxFrame.Position = UDim2.fromOffset(boxCenter.X, boxCenter.Y)
            entry.BoxFrame.Size = UDim2.fromOffset(boxWidth, boxHeight)
            entry.BoxFrame.Visible = true

            if VisualsState.BoxStyle == "Corner Box" then
                entry.BoxStroke.Enabled = false
                entry.CornerContainer.Visible = true

                local cLen = math.clamp(boxWidth * 0.22, 4, 16)
                local t = 1.5
                local b = entry.CornerBrackets
                -- TL
                b[1].Position = UDim2.new(0, 0, 0, 0); b[1].Size = UDim2.fromOffset(cLen, t); b[1].BackgroundColor3 = espColor
                b[2].Position = UDim2.new(0, 0, 0, 0); b[2].Size = UDim2.fromOffset(t, cLen); b[2].BackgroundColor3 = espColor
                -- TR
                b[3].Position = UDim2.new(1, -cLen, 0, 0); b[3].Size = UDim2.fromOffset(cLen, t); b[3].BackgroundColor3 = espColor
                b[4].Position = UDim2.new(1, -t, 0, 0); b[4].Size = UDim2.fromOffset(t, cLen); b[4].BackgroundColor3 = espColor
                -- BL
                b[5].Position = UDim2.new(0, 0, 1, -t); b[5].Size = UDim2.fromOffset(cLen, t); b[5].BackgroundColor3 = espColor
                b[6].Position = UDim2.new(0, 0, 1, -cLen); b[6].Size = UDim2.fromOffset(t, cLen); b[6].BackgroundColor3 = espColor
                -- BR
                b[7].Position = UDim2.new(1, -cLen, 1, -t); b[7].Size = UDim2.fromOffset(cLen, t); b[7].BackgroundColor3 = espColor
                b[8].Position = UDim2.new(1, -t, 1, -cLen); b[8].Size = UDim2.fromOffset(t, cLen); b[8].BackgroundColor3 = espColor
            else
                -- "2D Box"
                entry.CornerContainer.Visible = false
                entry.BoxStroke.Enabled = true
                entry.BoxStroke.Color = espColor
            end
        end
    else
        entry.BoxFrame.Visible = false
        entry.CornerContainer.Visible = false
        for _, l in ipairs(entry.Box3DLines) do l.Visible = false end
    end

    -- 2. Health Bar
    if VisualsState.HealthBar then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        entry.HealthBarBg.Position = UDim2.fromOffset(boxLeft - 4, boxTop)
        entry.HealthBarBg.Size = UDim2.fromOffset(3, boxHeight)
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
        entry.NameLabel.Position = UDim2.fromOffset(boxCenter.X, boxTop - 3)
        entry.NameLabel.Visible = true
    else
        entry.NameLabel.Visible = false
    end

    -- 4. Tool ESP
    if VisualsState.ToolESP then
        local tool = getCharacterTool(char)
        if tool then
            entry.ToolLabel.Text = tool
            entry.ToolLabel.Position = UDim2.fromOffset(boxCenter.X, boxBottom + 3)
            entry.ToolLabel.Visible = true
        else
            entry.ToolLabel.Visible = false
        end
    else
        entry.ToolLabel.Visible = false
    end

    -- 5. Tracers (Leading to BOTTOM CENTER of the box)
    if VisualsState.Tracers then
        local origin = getTracerOrigin()
        local targetPos = Vector2.new(boxCenter.X, boxBottom)
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
end

-- Render loop with individual try-catch to guarantee crash-free continuous rendering
trackConnection(RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        local entry = ESPHolders[plr]
        if not entry then
            local ok, newEntry = pcall(createPlayerESP, plr)
            if ok and newEntry then
                ESPHolders[plr] = newEntry
                entry = newEntry
            end
        end
        if entry then
            pcall(updatePlayer, entry)
        end
    end
end))

-- Handle PlayerAdded & PlayerRemoving
trackConnection(Players.PlayerAdded:Connect(function(plr)
    if not ESPHolders[plr] then
        pcall(function()
            ESPHolders[plr] = createPlayerESP(plr)
        end)
    end
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if VisualsState.ChamsEnabled then pcall(function() applyChams(plr) end) end
    end)
end))

trackConnection(Players.PlayerRemoving:Connect(function(plr)
    pcall(function() restoreChams(plr) end)
    if ESPHolders[plr] then
        pcall(function() removePlayerESP(ESPHolders[plr]) end)
        ESPHolders[plr] = nil
    end
end))

-- Pre-populate existing players
for _, plr in ipairs(Players:GetPlayers()) do
    if not ESPHolders[plr] then
        pcall(function()
            ESPHolders[plr] = createPlayerESP(plr)
        end)
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
