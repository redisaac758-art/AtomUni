--[[
    features.lua
    Universal Visuals & Performance Features Engine for Atomware (Universal Script)
    Provides Universal Player ESP, Material Chams (t1r4 adaptation), and Chinese Hat ESP.
    Engineered with dual-pipeline rendering (Native Drawing API + Mobile ScreenGui Fallback).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera", 10)
if not Camera then error("Atomware: CurrentCamera was unavailable") end

trackConnection = function(conn)
    if _G.AtomwareConfig then return _G.AtomwareConfig:TrackConnection(conn) end
    return conn
end

trackTask = function(t)
    if _G.AtomwareConfig then return _G.AtomwareConfig:TrackTask(t) end
    return t
end

-- Update camera reference if changed
trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end))

--//==================================================
--// DUAL RENDERING PIPELINE (PC DRAWING + MOBILE SCREENGUI FALLBACK)
--//==================================================

local hasNativeDrawing = pcall(function()
    local test = Drawing.new("Line")
    test.Visible = false
    test:Remove()
end)

local FallbackGui = nil
if not hasNativeDrawing then
    pcall(function()
        local parent = (type(gethui) == "function" and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if parent then
            local existing = parent:FindFirstChild("AtomwareFallbackESP")
            if existing then existing:Destroy() end

            FallbackGui = Instance.new("ScreenGui")
            FallbackGui.Name = "AtomwareFallbackESP"
            FallbackGui.ResetOnSpawn = false
            FallbackGui.IgnoreGuiInset = true
            FallbackGui.DisplayOrder = 9999
            FallbackGui.Parent = parent
            if _G.AtomwareCleanup and _G.AtomwareCleanup.TrackInstance then
                _G.AtomwareCleanup:TrackInstance(FallbackGui)
            end
        end
    end)
end

local function createRenderObject(kind)
    if hasNativeDrawing then
        local d = Drawing.new(kind)
        if _G.AtomwareCleanup and _G.AtomwareCleanup.TrackDrawing then
            _G.AtomwareCleanup:TrackDrawing(d)
        end
        return d
    end

    -- Fallback ScreenGui object simulation for mobile/unsupported runtimes
    local obj = {
        Visible = false,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,
        Thickness = 1,
        From = Vector2.zero,
        To = Vector2.zero,
        Size = Vector2.zero,
        Position = Vector2.zero,
        Text = "",
        Center = false,
        Outline = false,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        ZIndex = 1,
    }

    local frame = nil
    if FallbackGui then
        if kind == "Line" then
            frame = Instance.new("Frame")
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.BorderSizePixel = 0
            frame.Parent = FallbackGui
        elseif kind == "Square" then
            frame = Instance.new("Frame")
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.Parent = FallbackGui
            local stroke = Instance.new("UIStroke")
            stroke.Color = obj.Color
            stroke.Thickness = obj.Thickness
            stroke.Parent = frame
            obj._stroke = stroke
        elseif kind == "Text" then
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 12
            label.Parent = FallbackGui
            frame = label
        end
        if frame then
            frame.Visible = false
            obj._frame = frame
        end
    end

    local mt = {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if not frame or not frame.Parent then return end

            if k == "Visible" then
                frame.Visible = v
            elseif k == "Color" then
                if kind == "Text" then
                    frame.TextColor3 = v
                elseif kind == "Square" and t._stroke then
                    t._stroke.Color = v
                else
                    frame.BackgroundColor3 = v
                end
            elseif k == "Thickness" then
                if kind == "Square" and t._stroke then
                    t._stroke.Thickness = v
                elseif kind == "Line" then
                    -- Size updated on From/To update
                end
            elseif k == "From" or k == "To" then
                if kind == "Line" then
                    local from = t.From
                    local to = t.To
                    local dist = (to - from).Magnitude
                    local mid = (from + to) / 2
                    local angle = math.deg(math.atan2(to.Y - from.Y, to.X - from.X))
                    frame.Size = UDim2.fromOffset(dist, t.Thickness or 1)
                    frame.Position = UDim2.fromOffset(mid.X, mid.Y)
                    frame.Rotation = angle
                end
            elseif k == "Position" then
                if kind == "Square" or kind == "Text" then
                    frame.Position = UDim2.fromOffset(v.X, v.Y)
                end
            elseif k == "Size" then
                if kind == "Square" then
                    frame.Size = UDim2.fromOffset(v.X, v.Y)
                elseif kind == "Text" and type(v) == "number" then
                    frame.TextSize = v
                end
            elseif k == "Text" and kind == "Text" then
                frame.Text = tostring(v)
            elseif k == "Center" and kind == "Text" then
                frame.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
            end
        end
    }

    function obj:Remove()
        if frame then frame:Destroy() end
        table.clear(obj)
    end

    return setmetatable(obj, mt)
end

--//==================================================
--// EVENT HOOKS WAITER
--//==================================================

repeat task.wait() until _G.OnToggle and _G.OnSlider and _G.OnDropdown and _G.OnColorPicker

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
--// RIG & BOUNDING BOX CALCULATION
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

local function getBoundingBoxScreen(character)
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    if not root or not head then return nil end

    local rig = getCharacterRigType(character)
    local topOffset = (rig == "R15") and 1.6 or 1.4
    local bottomOffset = (rig == "R15") and 3.2 or 3.0

    local topWorld = head.Position + Vector3.new(0, topOffset, 0)
    local bottomWorld = root.Position - Vector3.new(0, bottomOffset, 0)

    local topScreen, topVisible = Camera:WorldToViewportPoint(topWorld)
    local bottomScreen, bottomVisible = Camera:WorldToViewportPoint(bottomWorld)

    if not topVisible and not bottomVisible then return nil end

    local height = math.abs(bottomScreen.Y - topScreen.Y)
    local width = math.max(height * 0.6, 12)
    local x = topScreen.X - (width / 2)
    local y = topScreen.Y

    return {
        Position = Vector2.new(math.floor(x), math.floor(y)),
        Size = Vector2.new(math.floor(width), math.floor(height)),
        Top = topScreen,
        Bottom = bottomScreen,
        Center = Vector2.new(math.floor(topScreen.X), math.floor(y + height / 2)),
    }
end

--//==================================================
--// PLAYER ESP HOLDER & DRAWINGS CACHE
--//==================================================

local ESPHolders = {}

local function createESPEntry(player)
    local entry = {
        Player = player,
        -- Box drawings (Main box or 8 corner lines)
        Box = createRenderObject("Square"),
        BoxOutline = createRenderObject("Square"),
        Corners = {},
        CornerOutlines = {},
        -- Text elements
        Name = createRenderObject("Text"),
        Distance = createRenderObject("Text"),
        Tool = createRenderObject("Text"),
        -- Health bar
        HealthBar = createRenderObject("Line"),
        HealthBarOutline = createRenderObject("Line"),
        -- Tracers
        Tracer = createRenderObject("Line"),
        -- Chinese Hat lines (base ring + apex ribs)
        HatLines = {},
    }

    -- 8 corner lines + 8 outlines
    for i = 1, 8 do
        entry.Corners[i] = createRenderObject("Line")
        entry.CornerOutlines[i] = createRenderObject("Line")
    end

    -- Chinese hat lines pool (up to 32 lines for ring + ribs)
    for i = 1, 48 do
        entry.HatLines[i] = createRenderObject("Line")
    end

    return entry
end

local function removeESPEntry(entry)
    if not entry then return end
    entry.Box:Remove()
    entry.BoxOutline:Remove()
    for _, c in ipairs(entry.Corners) do c:Remove() end
    for _, co in ipairs(entry.CornerOutlines) do co:Remove() end
    entry.Name:Remove()
    entry.Distance:Remove()
    entry.Tool:Remove()
    entry.HealthBar:Remove()
    entry.HealthBarOutline:Remove()
    entry.Tracer:Remove()
    for _, hl in ipairs(entry.HatLines) do hl:Remove() end
end

local function hideESPEntry(entry)
    entry.Box.Visible = false
    entry.BoxOutline.Visible = false
    for i = 1, 8 do
        entry.Corners[i].Visible = false
        entry.CornerOutlines[i].Visible = false
    end
    entry.Name.Visible = false
    entry.Distance.Visible = false
    entry.Tool.Visible = false
    entry.HealthBar.Visible = false
    entry.HealthBarOutline.Visible = false
    entry.Tracer.Visible = false
    for _, hl in ipairs(entry.HatLines) do hl.Visible = false end
end

--//==================================================
--// CHINESE HAT WIREFRAME RENDERER
--//==================================================

local function renderChineseHat(entry, character, isLocal)
    if not VisualsState.HatEnabled then return end
    if isLocal and not VisualsState.HatLocalPlayer then return end
    if not isLocal and not VisualsState.HatOthers then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    local radius = VisualsState.HatRadius
    local segments = math.clamp(math.floor(VisualsState.HatSegments), 6, 24)
    local hatColor = VisualsState.HatColor
    local rotAngle = VisualsState.HatRotate and (tick() * 2 % (math.pi * 2)) or 0

    local baseCenter = head.Position + Vector3.new(0, 0.7, 0)
    local apexWorld = baseCenter + Vector3.new(0, 0.9, 0)

    local apexScreen, apexVisible = Camera:WorldToViewportPoint(apexWorld)
    if not apexVisible then return end
    local apexPos = Vector2.new(apexScreen.X, apexScreen.Y)

    -- Calculate screen points for base ring
    local ringPoints = {}
    local allVisible = true

    for i = 1, segments do
        local angle = rotAngle + ((i - 1) / segments) * math.pi * 2
        local ptWorld = baseCenter + Vector3.new(math.cos(angle) * radius, -0.35, math.sin(angle) * radius)
        local ptScreen, ptVis = Camera:WorldToViewportPoint(ptWorld)
        if not ptVis then
            allVisible = false
            break
        end
        table.insert(ringPoints, Vector2.new(ptScreen.X, ptScreen.Y))
    end

    if not allVisible or #ringPoints < segments then return end

    local lineIndex = 1

    -- Draw base ring (connecting adjacent points)
    for i = 1, segments do
        local nextIndex = (i % segments) + 1
        local line = entry.HatLines[lineIndex]
        if line then
            line.Visible = true
            line.Color = hatColor
            line.Thickness = 1.2
            line.From = ringPoints[i]
            line.To = ringPoints[nextIndex]
            lineIndex = lineIndex + 1
        end
    end

    -- Draw ribs from apex to each ring point
    for i = 1, segments do
        local line = entry.HatLines[lineIndex]
        if line then
            line.Visible = true
            line.Color = hatColor
            line.Thickness = 1.2
            line.From = apexPos
            line.To = ringPoints[i]
            lineIndex = lineIndex + 1
        end
    end
end

--//==================================================
--// MAIN RENDER LOOP (ESP + CHAMS + HAT)
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

local function updatePlayerESP(entry)
    local plr = entry.Player
    local isLocal = (plr == LocalPlayer)

    hideESPEntry(entry)

    local char = plr.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    -- Hat for Local Player
    if isLocal then
        renderChineseHat(entry, char, true)
        return
    end

    -- Team Check
    local isTeammate = (VisualsState.TeamCheck or VisualsState.ChamsTeamCheck) and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
    if VisualsState.TeamCheck and isTeammate then
        return
    end

    -- Chams per frame update
    if VisualsState.ChamsEnabled then
        applyChams(plr)
    end

    -- Hat for other players
    renderChineseHat(entry, char, false)

    if not VisualsState.ESPEnabled then return end

    local bbox = getBoundingBoxScreen(char)
    if not bbox then return end

    local espColor = isTeammate and VisualsState.TeamColor or VisualsState.ESPColor
    local pos = bbox.Position
    local size = bbox.Size
    local dist = math.floor((char:GetPivot().Position - Camera.CFrame.Position).Magnitude)

    -- 1. Box ESP
    if VisualsState.BoxESP then
        if VisualsState.BoxStyle == "Corner Box" then
            local cornerLen = math.clamp(math.floor(size.X * 0.25), 4, 18)
            local x1, y1 = pos.X, pos.Y
            local x2, y2 = pos.X + size.X, pos.Y + size.Y

            local lines = {
                -- Top Left
                { Vector2.new(x1, y1), Vector2.new(x1 + cornerLen, y1) },
                { Vector2.new(x1, y1), Vector2.new(x1, y1 + cornerLen) },
                -- Top Right
                { Vector2.new(x2, y1), Vector2.new(x2 - cornerLen, y1) },
                { Vector2.new(x2, y1), Vector2.new(x2, y1 + cornerLen) },
                -- Bottom Left
                { Vector2.new(x1, y2), Vector2.new(x1 + cornerLen, y2) },
                { Vector2.new(x1, y2), Vector2.new(x1, y2 - cornerLen) },
                -- Bottom Right
                { Vector2.new(x2, y2), Vector2.new(x2 - cornerLen, y2) },
                { Vector2.new(x2, y2), Vector2.new(x2, y2 - cornerLen) },
            }

            for i = 1, 8 do
                local c = entry.Corners[i]
                local co = entry.CornerOutlines[i]
                if lines[i] then
                    co.Visible = true
                    co.Color = Color3.fromRGB(0, 0, 0)
                    co.Thickness = 2.5
                    co.From = lines[i][1]
                    co.To = lines[i][2]

                    c.Visible = true
                    c.Color = espColor
                    c.Thickness = 1
                    c.From = lines[i][1]
                    c.To = lines[i][2]
                end
            end
        else
            -- 2D Box with 1px black outline for contrast
            local bo = entry.BoxOutline
            bo.Visible = true
            bo.Color = Color3.fromRGB(0, 0, 0)
            bo.Thickness = 2.5
            bo.Position = pos - Vector2.new(1, 1)
            bo.Size = size + Vector2.new(2, 2)

            local b = entry.Box
            b.Visible = true
            b.Color = espColor
            b.Thickness = 1
            b.Position = pos
            b.Size = size
        end
    end

    -- 2. Health Bar (Left of Box)
    if VisualsState.HealthBar then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local barHeight = math.floor(size.Y * hpPct)
        local barX = pos.X - 6
        local barY = pos.Y + size.Y

        local hbo = entry.HealthBarOutline
        hbo.Visible = true
        hbo.Color = Color3.fromRGB(0, 0, 0)
        hbo.Thickness = 3
        hbo.From = Vector2.new(barX, pos.Y + size.Y)
        hbo.To = Vector2.new(barX, pos.Y)

        local hb = entry.HealthBar
        hb.Visible = true
        hb.Color = Color3.fromHSV(hpPct * 0.33, 0.9, 1) -- Smooth Red to Green
        hb.Thickness = 1.5
        hb.From = Vector2.new(barX, barY)
        hb.To = Vector2.new(barX, barY - barHeight)
    end

    -- 3. Name & Distance ESP (Top of Box)
    if VisualsState.NameESP or VisualsState.DistanceESP then
        local textStr = ""
        if VisualsState.NameESP then textStr = plr.DisplayName or plr.Name end
        if VisualsState.DistanceESP then
            textStr = textStr ~= "" and (textStr .. " [" .. dist .. "m]") or ("[" .. dist .. "m]")
        end

        local nl = entry.Name
        nl.Visible = true
        nl.Color = Color3.fromRGB(245, 241, 255)
        nl.Text = textStr
        nl.Size = 12
        nl.Center = true
        nl.Position = Vector2.new(pos.X + size.X / 2, pos.Y - 15)
    end

    -- 4. Tool ESP (Bottom of Box)
    if VisualsState.ToolESP then
        local toolName = getCharacterTool(char)
        if toolName then
            local tl = entry.Tool
            tl.Visible = true
            tl.Color = Color3.fromRGB(205, 104, 255)
            tl.Text = toolName
            tl.Size = 11
            tl.Center = true
            tl.Position = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + 3)
        end
    end

    -- 5. Tracers
    if VisualsState.Tracers then
        local tr = entry.Tracer
        tr.Visible = true
        tr.Color = espColor
        tr.Thickness = 1
        tr.From = getTracerOrigin()
        tr.To = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y)
    end
end

-- RenderStepped render tick
trackConnection(RunService.RenderStepped:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        local entry = ESPHolders[plr]
        if not entry then
            entry = createESPEntry(plr)
            ESPHolders[plr] = entry
        end
        updatePlayerESP(entry)
    end
end))

-- Handle PlayerAdded / PlayerRemoving
trackConnection(Players.PlayerAdded:Connect(function(plr)
    if not ESPHolders[plr] then
        ESPHolders[plr] = createESPEntry(plr)
    end
    plr.CharacterAdded:Connect(function()
        task.wait(0.3)
        if VisualsState.ChamsEnabled then applyChams(plr) end
    end)
end))

trackConnection(Players.PlayerRemoving:Connect(function(plr)
    restoreChams(plr)
    if ESPHolders[plr] then
        removeESPEntry(ESPHolders[plr])
        ESPHolders[plr] = nil
    end
end))

-- Initialize existing players
for _, plr in ipairs(Players:GetPlayers()) do
    if not ESPHolders[plr] then
        ESPHolders[plr] = createESPEntry(plr)
    end
end

--//==================================================
--// EVENT HOOK CONNECTIONS FROM UI
--//==================================================

-- Player ESP
_G.OnToggle("Enable ESP", function(v) VisualsState.ESPEnabled = v end)
_G.OnToggle("Box ESP", function(v) VisualsState.BoxESP = v end)
_G.OnDropdown("Box Style", function(v) VisualsState.BoxStyle = v end)
_G.OnToggle("Name ESP", function(v) VisualsState.NameESP = v end)
_G.OnToggle("Distance ESP", function(v) VisualsState.DistanceESP = v end)
_G.OnToggle("Health Bar", function(v) VisualsState.HealthBar = v end)
_G.OnToggle("Tool ESP", function(v) VisualsState.ToolESP = v end)
_G.OnToggle("Tracers", function(v) VisualsState.Tracers = v end)
_G.OnDropdown("Tracer Origin", function(v) VisualsState.TracerOrigin = v end)
_G.OnToggle("Team Check", function(v) VisualsState.TeamCheck = v end)
_G.OnColorPicker("ESP Color", function(v) VisualsState.ESPColor = v end)
_G.OnColorPicker("Team Color", function(v) VisualsState.TeamColor = v end)

-- Material Chams (t1r4)
_G.OnToggle("Enable Chams", function(v)
    VisualsState.ChamsEnabled = v
    refreshAllChams()
end)
_G.OnDropdown("Material", function(v)
    if ChamsMaterials[v] then
        restoreAllChams()
        VisualsState.ChamsMaterial = v
        refreshAllChams()
    end
end)
_G.OnColorPicker("Chams Color", function(v)
    VisualsState.ChamsColor = v
    refreshAllChams()
end)
_G.OnToggle("See Through (Glow)", function(v)
    VisualsState.ChamsSeeThrough = v
    refreshAllChams()
end)
_G.OnToggle("Chams Team Check", function(v)
    VisualsState.ChamsTeamCheck = v
    refreshAllChams()
end)

-- Chinese Hat ESP
_G.OnToggle("Chinese Hat", function(v) VisualsState.HatEnabled = v end)
_G.OnToggle("Hat on Local Player", function(v) VisualsState.HatLocalPlayer = v end)
_G.OnToggle("Hat on Others", function(v) VisualsState.HatOthers = v end)
_G.OnSlider("Hat Radius", function(v) VisualsState.HatRadius = v end)
_G.OnSlider("Hat Segments", function(v) VisualsState.HatSegments = v end)
_G.OnColorPicker("Hat Color", function(v) VisualsState.HatColor = v end)
_G.OnToggle("Rotate Hat", function(v) VisualsState.HatRotate = v end)

--//==================================================
--// CLEANUP HANDLER ON UNLOAD
--//==================================================

if _G.AtomwareConfig then
    _G.AtomwareConfig:OnUnload(function()
        restoreAllChams()
        for _, entry in pairs(ESPHolders) do
            removeESPEntry(entry)
        end
        table.clear(ESPHolders)
        if FallbackGui then
            pcall(function() FallbackGui:Destroy() end)
            FallbackGui = nil
        end
    end)
end

_G.AtomwareFeaturesLoaded = true
print("Atomware Universal: Phase 1 Visuals Backend Loaded")
