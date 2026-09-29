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
--// FOV CIRCLE STATE (initialized after VisualsState below)
--//==================================================

local FOVHolder = nil
local FOVSegments = {}
local FOVFillFrame = nil
local lastTouchPos = nil

-- Touch tracking (fine to wire up immediately since trackConnection is defined above)
trackConnection(UserInputService.TouchStarted:Connect(function(touch)
    lastTouchPos = Vector2.new(touch.Position.X, touch.Position.Y)
end))
trackConnection(UserInputService.TouchMoved:Connect(function(touch)
    lastTouchPos = Vector2.new(touch.Position.X, touch.Position.Y)
end))

-- FOV_SEGMENTS_COUNT and cos/sin tables declared here, used after VisualsState
local FOV_SEGMENTS_COUNT = 36
local FOV_COS = {}
local FOV_SIN = {}
for i = 1, FOV_SEGMENTS_COUNT do
    local a = (i - 1) * (2 * math.pi / FOV_SEGMENTS_COUNT)
    FOV_COS[i] = math.cos(a)
    FOV_SIN[i] = math.sin(a)
end

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
    HatColor        = Color3.fromRGB(180, 80, 255),
    HatRotate       = true,

    -- Combat / Aimbot
    AimbotEnabled       = false,
    AimActive           = false,
    AimLock             = false,
    AimType             = "Camera Aim",   -- "Camera Aim" | "Mouse/Touch Aim"
    TargetPart          = "Head",
    AimbotSmoothness    = 5,
    AimKey              = Enum.UserInputType.MouseButton2,
    WallCheck           = false,
    AimbotTeamCheck     = false,

    -- FOV Circle
    FOVEnabled          = false,
    FOVRadius           = 120,
    FOVColor            = Color3.fromRGB(157, 48, 255),
    FOVFilled           = false,
    FOVTransparency     = 0.2,

    -- Aim Toggle Button appearance (mobile)
    AimToggleSize       = 54,         -- pixels
    AimToggleShape      = "Rounded",  -- "Rounded" | "Circle" | "Square"

    -- Hitbox Expander
    HitboxEnabled       = false,
    HitboxPart          = "Head",
    HitboxSize          = 5,
    HitboxTransparency  = 0.6,
    HitboxColor         = Color3.fromRGB(157, 48, 255),
    HitboxMaterial      = "ForceField",

    -- Triggerbot
    TriggerbotEnabled   = false,
    TriggerbotDelay     = 0.05,    -- seconds before clicking
    TriggerbotRadius    = 12,      -- screen-space px radius around crosshair
    TriggerbotMode      = "Always On", -- "Always On" | "Aimbot Only"

    -- Visual Enhancements
    HealthBasedColor      = false,   -- ESP box color (legacy, kept for compat)
    HealthBarBasedColor   = false,   -- health bar color based on HP %
    LookRays            = false,
    LookRayLength       = 7,
    LookRayColor        = Color3.fromRGB(255, 100, 100),
    SkeletonESP         = false,
    SkeletonColor       = Color3.fromRGB(220, 220, 255),

    -- World Visuals
    CustomTime          = false,
    TimeOfDay           = 14,
    SkyPreset           = "Default",
    NoFog               = false,

    -- Target HUD
    TargetHUD           = true,

    -- Player Whitelist ([UserId] = true)
    Whitelisted         = {},

    -- Custom Crosshairs
    CrosshairEnabled    = false,
    CrosshairStyle      = "Cross",    -- "Cross", "Dot", "T-Shape", "Circle"
    CrosshairSize       = 12,
    CrosshairGap        = 4,
    CrosshairThickness  = 2,
    CrosshairColor      = Color3.fromRGB(0, 255, 180),
    CrosshairSpin       = false,
    CrosshairSpinSpeed  = 2,

    -- Mini-Radar
    RadarEnabled        = false,
    RadarRange          = 150,
    RadarSize           = 130,

    -- Bullet Tracers
    BulletTracersEnabled    = false,
    BulletTracerColor       = Color3.fromRGB(255, 60, 60),
    BulletTracerThickness   = 2,
    BulletTracerDuration    = 0.35,
    BulletTracerParticles   = true,

    -- Hitmarker
    HitmarkerEnabled    = false,
    HitmarkerColor      = Color3.fromRGB(255, 255, 255),
    HitmarkerSize       = 14,
    HitmarkerDuration   = 0.25,

    -- Hit Sounds
    HitSoundEnabled     = false,
    HitSoundType        = "Default",
    HitSoundVolume      = 0.7,
}

--//==================================================
--// FOV CIRCLE ENGINE (COMBINED ESP BOX METHOD + FRAME SEGMENTS)
--// 100% Cross-Platform: guaranteed to render on iPad & Mobile
--// Uses the exact same working BoxFrame architecture as ESP (glass fill + stroke)
--// PLUS 36 perimeter line segments for razor-sharp rendering on all GPU backends
--//==================================================

local FOVCircleBoxFrame = nil
local FOVCircleBoxStroke = nil

local function ensureFOVCircle()
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    if FOVHolder and FOVHolder.Parent and #FOVSegments == FOV_SEGMENTS_COUNT and FOVCircleBoxFrame and FOVCircleBoxFrame.Parent then
        return FOVHolder
    end

    if FOVHolder then pcall(function() FOVHolder:Destroy() end) end
    table.clear(FOVSegments)
    FOVCircleBoxFrame = nil
    FOVCircleBoxStroke = nil

    -- Full-viewport Frame holder (EXACT SAME AS ESP HOLDER)
    FOVHolder = Instance.new("Frame")
    FOVHolder.Name = "AtomwareFOVHolder"
    FOVHolder.Size = UDim2.fromScale(1, 1)
    FOVHolder.Position = UDim2.fromScale(0, 0)
    FOVHolder.BackgroundTransparency = 1
    FOVHolder.BorderSizePixel = 0
    FOVHolder.ClipsDescendants = false
    FOVHolder.ZIndex = 2
    pcall(function() FOVHolder.Parent = container end)

    -- 1. EXACT ESP BOX METHOD CIRCLE (Glass fill + UIStroke + UICorner)
    FOVCircleBoxFrame = Instance.new("Frame")
    FOVCircleBoxFrame.Name = "FOVCircleBox"
    FOVCircleBoxFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVCircleBoxFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    FOVCircleBoxFrame.BackgroundTransparency = 0.88
    FOVCircleBoxFrame.BorderSizePixel = 0
    FOVCircleBoxFrame.Visible = false
    FOVCircleBoxFrame.ZIndex = 3
    FOVCircleBoxFrame.Parent = FOVHolder

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(1, 0)
    boxCorner.Parent = FOVCircleBoxFrame

    FOVCircleBoxStroke = Instance.new("UIStroke")
    FOVCircleBoxStroke.Name = "FOVBoxStroke"
    FOVCircleBoxStroke.Color = VisualsState and VisualsState.FOVColor or Color3.fromRGB(157, 48, 255)
    FOVCircleBoxStroke.Thickness = 1.5
    FOVCircleBoxStroke.Parent = FOVCircleBoxFrame

    -- 2. 36 LINE SEGMENTS (EXACT TRACER / 3D BOX METHOD)
    for i = 1, FOV_SEGMENTS_COUNT do
        local line = Instance.new("Frame")
        line.Name = "FOVSeg" .. i
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.BackgroundColor3 = VisualsState and VisualsState.FOVColor or Color3.fromRGB(157, 48, 255)
        line.BackgroundTransparency = VisualsState and VisualsState.FOVTransparency or 0.2
        line.Visible = false
        line.ZIndex = 4
        line.Parent = FOVHolder
        table.insert(FOVSegments, line)
    end

    return FOVHolder
end

local function getAimReferencePoint()
    local vp = Camera.ViewportSize
    if VisualsState.AimType == "Mouse/Touch Aim" then
        if lastTouchPos then return lastTouchPos end
        local mp = UserInputService:GetMouseLocation()
        if mp.X > 0 or mp.Y > 0 then return Vector2.new(mp.X, mp.Y) end
    end
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function updateFOVCircle()
    if not VisualsState.FOVEnabled then
        if FOVCircleBoxFrame then FOVCircleBoxFrame.Visible = false end
        for _, seg in ipairs(FOVSegments) do seg.Visible = false end
        return
    end

    ensureFOVCircle()
    if not FOVHolder then return end

    local rad    = VisualsState.FOVRadius
    local center = getAimReferencePoint()
    local color  = VisualsState.FOVColor
    local trans  = VisualsState.FOVTransparency

    -- 1. Update ESP Box Method Circle
    if FOVCircleBoxFrame then
        FOVCircleBoxFrame.Size = UDim2.fromOffset(rad * 2, rad * 2)
        FOVCircleBoxFrame.Position = UDim2.fromOffset(center.X, center.Y)
        if VisualsState.FOVFilled then
            FOVCircleBoxFrame.BackgroundColor3 = color
            FOVCircleBoxFrame.BackgroundTransparency = math.clamp(trans + 0.5, 0, 1)
        else
            FOVCircleBoxFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            FOVCircleBoxFrame.BackgroundTransparency = 0.88
        end
        if FOVCircleBoxStroke then
            FOVCircleBoxStroke.Color = color
            FOVCircleBoxStroke.Transparency = trans
        end
        FOVCircleBoxFrame.Visible = true
    end

    -- 2. Update 36 Line Segments
    if #FOVSegments == FOV_SEGMENTS_COUNT then
        for i = 1, FOV_SEGMENTS_COUNT do
            local ni  = (i % FOV_SEGMENTS_COUNT) + 1
            local p1  = center + Vector2.new(FOV_COS[i]  * rad, FOV_SIN[i]  * rad)
            local p2  = center + Vector2.new(FOV_COS[ni] * rad, FOV_SIN[ni] * rad)
            local dx  = p2.X - p1.X
            local dy  = p2.Y - p1.Y
            local len = math.sqrt(dx * dx + dy * dy)
            local mx  = (p1.X + p2.X) * 0.5
            local my  = (p1.Y + p2.Y) * 0.5
            local ang = math.deg(math.atan2(dy, dx))

            local seg = FOVSegments[i]
            if seg then
                seg.Size                = UDim2.fromOffset(len + 1, 2)
                seg.Position            = UDim2.fromOffset(mx, my)
                seg.Rotation            = ang
                seg.BackgroundColor3    = color
                seg.BackgroundTransparency = trans
                seg.Visible             = true
            end
        end
    end
end

-- Pre-initialize FOV Circle upfront (exact same pattern as ESP pre-population)
pcall(ensureFOVCircle)

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
--// HITBOX EXPANDER ENGINE (UNIVERSAL / CROSS-PLATFORM)
--// Uses a separate welded invisible part instead of resizing the real part.
--// This avoids the HRP-resize freeze bug completely.
--//==================================================

local HitboxApplied = {}         -- [plr] = hitboxPart
local HitboxRespawnConns = {}    -- [plr] = CharacterAdded connection

local function removeHitboxPart(plr)
    local existing = HitboxApplied[plr]
    if existing then
        pcall(function() existing:Destroy() end)
        HitboxApplied[plr] = nil
    end
end

local function applyHitboxToPlayer(plr)
    if not VisualsState.HitboxEnabled or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)
    if VisualsState.TeamCheck and myTeam and plr.Team == myTeam then
        removeHitboxPart(plr)
        return
    end

    local partName = VisualsState.HitboxPart
    local targetPart = char:FindFirstChild(partName)
    if not targetPart or not targetPart:IsA("BasePart") then return end

    -- Remove stale hitbox if target part changed or character changed
    local existing = HitboxApplied[plr]
    if existing then
        if existing.Parent ~= char then
            pcall(function() existing:Destroy() end)
            HitboxApplied[plr] = nil
            existing = nil
        else
            -- Update properties on existing hitbox
            local sz = VisualsState.HitboxSize
            existing.Size = Vector3.new(sz, sz, sz)
            existing.Transparency = VisualsState.HitboxTransparency
            existing.Color = VisualsState.HitboxColor
            local mat = Enum.Material[VisualsState.HitboxMaterial]
            existing.Material = mat or Enum.Material.ForceField
            return
        end
    end

    -- Create a new hitbox part welded to the target
    local hitboxPart = Instance.new("Part")
    hitboxPart.Name = "AtomwareHitbox"
    hitboxPart.CanCollide = false
    hitboxPart.CanTouch = false
    hitboxPart.CanQuery = true     -- must be queryable so raycasts hit it
    hitboxPart.Massless = true
    hitboxPart.Anchored = false
    local sz = VisualsState.HitboxSize
    hitboxPart.Size = Vector3.new(sz, sz, sz)
    hitboxPart.Transparency = VisualsState.HitboxTransparency
    hitboxPart.Color = VisualsState.HitboxColor
    local mat = Enum.Material[VisualsState.HitboxMaterial]
    hitboxPart.Material = mat or Enum.Material.ForceField
    hitboxPart.CFrame = targetPart.CFrame

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = targetPart
    weld.Part1 = hitboxPart
    weld.Parent = hitboxPart

    hitboxPart.Parent = char
    HitboxApplied[plr] = hitboxPart
end

local function restoreHitboxForPlayer(plr)
    removeHitboxPart(plr)
end

local function restoreAllHitboxes()
    for plr in pairs(HitboxApplied) do
        removeHitboxPart(plr)
    end
    table.clear(HitboxApplied)
end

local function refreshAllHitboxes()
    if not VisualsState.HitboxEnabled then
        restoreAllHitboxes()
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            applyHitboxToPlayer(plr)
        end
    end
end

-- Wire CharacterAdded for all existing + future players so hitbox persists through respawns
local function wireHitboxRespawn(plr)
    if HitboxRespawnConns[plr] then
        pcall(function() HitboxRespawnConns[plr]:Disconnect() end)
    end
    HitboxRespawnConns[plr] = plr.CharacterAdded:Connect(function()
        task.wait(0.5) -- wait for character to load
        removeHitboxPart(plr)
        if VisualsState.HitboxEnabled then
            pcall(function() applyHitboxToPlayer(plr) end)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then wireHitboxRespawn(plr) end
end
trackConnection(Players.PlayerAdded:Connect(function(plr)
    wireHitboxRespawn(plr)
end))
trackConnection(Players.PlayerRemoving:Connect(function(plr)
    removeHitboxPart(plr)
    if HitboxRespawnConns[plr] then
        pcall(function() HitboxRespawnConns[plr]:Disconnect() end)
        HitboxRespawnConns[plr] = nil
    end
end))


--//==================================================
--// AIMBOT ENGINE (UNIVERSAL / PC & MOBILE SUPPORT)
--//==================================================

local function getBestAimbotTarget()
    if not VisualsState.AimbotEnabled then return nil, nil end
    local refPt = getAimReferencePoint()
    local bestTarget = nil
    local bestTargetPlayer = nil
    local bestDist = VisualsState.FOVRadius

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not VisualsState.Whitelisted[plr.UserId] then
            local isTeammate = false
            if VisualsState.AimbotTeamCheck and myTeam and plr.Team == myTeam then
                isTeammate = true
            end

            if not isTeammate and plr.Character then
                local char = plr.Character
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local targetPartName = VisualsState.TargetPart
                    if targetPartName == "Torso" then
                        targetPartName = char:FindFirstChild("UpperTorso") and "UpperTorso" or "Torso"
                    end
                    local part = char:FindFirstChild(targetPartName) or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                    if part then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if screenPos.Z > 0 then
                            local screenPt = Vector2.new(screenPos.X, screenPos.Y)
                            local dist = (screenPt - refPt).Magnitude
                            if dist <= bestDist then
                                local isVisible = true
                                if VisualsState.WallCheck then
                                    local rayParams = RaycastParams.new()
                                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
                                    local rayResult = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams)
                                    if rayResult and not rayResult.Instance:IsDescendantOf(char) then
                                        isVisible = false
                                    end
                                end

                                if isVisible then
                                    bestDist = dist
                                    bestTarget = part
                                    bestTargetPlayer = plr
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestTargetPlayer
end

--//==================================================
--// TARGET HUD ENGINE (NEXT TO FOV CIRCLE)
--//==================================================

local TargetHUDFrame = nil
local TargetAvatarImg = nil
local TargetNameLabel = nil
local TargetLookLabel = nil
local TargetStatusLabel = nil

local function ensureTargetHUD()
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    if TargetHUDFrame and TargetHUDFrame.Parent then return TargetHUDFrame end
    if TargetHUDFrame then pcall(function() TargetHUDFrame:Destroy() end) end

    TargetHUDFrame = Instance.new("Frame")
    TargetHUDFrame.Name = "AtomwareTargetHUD"
    TargetHUDFrame.AnchorPoint = Vector2.new(0, 0.5)
    TargetHUDFrame.Size = UDim2.fromOffset(205, 68)
    TargetHUDFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
    TargetHUDFrame.BackgroundTransparency = 0.15
    TargetHUDFrame.BorderSizePixel = 0
    TargetHUDFrame.Visible = false
    TargetHUDFrame.ZIndex = 25
    pcall(function() TargetHUDFrame.Parent = container end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = TargetHUDFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = VisualsState.FOVColor
    stroke.Thickness = 1.2
    stroke.Parent = TargetHUDFrame

    TargetAvatarImg = Instance.new("ImageLabel")
    TargetAvatarImg.Name = "Avatar"
    TargetAvatarImg.Size = UDim2.fromOffset(50, 50)
    TargetAvatarImg.Position = UDim2.fromOffset(9, 9)
    TargetAvatarImg.BackgroundColor3 = Color3.fromRGB(20, 16, 35)
    TargetAvatarImg.BorderSizePixel = 0
    TargetAvatarImg.ZIndex = 26
    TargetAvatarImg.Parent = TargetHUDFrame
    local aCorner = Instance.new("UICorner")
    aCorner.CornerRadius = UDim.new(0, 6)
    aCorner.Parent = TargetAvatarImg

    TargetNameLabel = Instance.new("TextLabel")
    TargetNameLabel.Name = "NameLabel"
    TargetNameLabel.Size = UDim2.new(1, -70, 0, 16)
    TargetNameLabel.Position = UDim2.fromOffset(66, 9)
    TargetNameLabel.BackgroundTransparency = 1
    TargetNameLabel.Font = Enum.Font.GothamBold
    TargetNameLabel.TextSize = 12
    TargetNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TargetNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    TargetNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TargetNameLabel.ZIndex = 26
    TargetNameLabel.Parent = TargetHUDFrame

    TargetLookLabel = Instance.new("TextLabel")
    TargetLookLabel.Name = "LookLabel"
    TargetLookLabel.Size = UDim2.new(1, -70, 0, 14)
    TargetLookLabel.Position = UDim2.fromOffset(66, 28)
    TargetLookLabel.BackgroundTransparency = 1
    TargetLookLabel.Font = Enum.Font.GothamMedium
    TargetLookLabel.TextSize = 10
    TargetLookLabel.TextColor3 = Color3.fromRGB(180, 175, 215)
    TargetLookLabel.TextXAlignment = Enum.TextXAlignment.Left
    TargetLookLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TargetLookLabel.ZIndex = 26
    TargetLookLabel.Parent = TargetHUDFrame

    TargetStatusLabel = Instance.new("TextLabel")
    TargetStatusLabel.Name = "StatusLabel"
    TargetStatusLabel.Size = UDim2.new(1, -70, 0, 14)
    TargetStatusLabel.Position = UDim2.fromOffset(66, 45)
    TargetStatusLabel.BackgroundTransparency = 1
    TargetStatusLabel.Font = Enum.Font.GothamBold
    TargetStatusLabel.TextSize = 10
    TargetStatusLabel.TextColor3 = Color3.fromRGB(42, 255, 157)
    TargetStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    TargetStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TargetStatusLabel.ZIndex = 26
    TargetStatusLabel.Parent = TargetHUDFrame

    return TargetHUDFrame
end

local function updateTargetHUD(targetPart, isAiming, bestTargetPlayer)
    if not (VisualsState.AimbotEnabled and VisualsState.TargetHUD and targetPart and bestTargetPlayer) then
        if TargetHUDFrame then TargetHUDFrame.Visible = false end
        return
    end

    ensureTargetHUD()
    if not TargetHUDFrame then return end

    local rad = VisualsState.FOVRadius
    local center = getAimReferencePoint()
    TargetHUDFrame.Position = UDim2.fromOffset(center.X + rad + 16, center.Y - 34)

    TargetAvatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(bestTargetPlayer.UserId) .. "&w=100&h=100"
    TargetNameLabel.Text = bestTargetPlayer.DisplayName .. " (@" .. bestTargetPlayer.Name .. ")"

    -- Looking at you check
    local tChar = bestTargetPlayer.Character
    local tHead = tChar and tChar:FindFirstChild("Head")
    local myChar = LocalPlayer.Character
    local myHead = myChar and myChar:FindFirstChild("Head")

    if tHead and myHead then
        local dirToMe = (myHead.Position - tHead.Position).Unit
        local lookDot = math.clamp(tHead.CFrame.LookVector:Dot(dirToMe), -1, 1)
        local angleDeg = math.deg(math.acos(lookDot))
        if angleDeg <= 20 then
            TargetLookLabel.Text = "⚠ Looking directly at you!"
            TargetLookLabel.TextColor3 = Color3.fromRGB(255, 75, 100)
        elseif angleDeg <= 50 then
            TargetLookLabel.Text = "⚡ Facing towards you (" .. math.floor(angleDeg) .. "°)"
            TargetLookLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
        else
            TargetLookLabel.Text = "Looking away (" .. math.floor(angleDeg) .. "°)"
            TargetLookLabel.TextColor3 = Color3.fromRGB(160, 150, 200)
        end
    else
        TargetLookLabel.Text = "Target in view"
        TargetLookLabel.TextColor3 = Color3.fromRGB(160, 150, 200)
    end

    -- Whitelisted / Lock status
    if VisualsState.Whitelisted[bestTargetPlayer.UserId] then
        TargetStatusLabel.Text = "★ Whitelisted"
        TargetStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    elseif isAiming then
        TargetStatusLabel.Text = "● LOCKED ON TARGET"
        TargetStatusLabel.TextColor3 = Color3.fromRGB(42, 255, 157)
    else
        TargetStatusLabel.Text = "○ In FOV Range"
        TargetStatusLabel.TextColor3 = Color3.fromRGB(180, 175, 215)
    end

    TargetHUDFrame.Visible = true
end

local function updateAimbot()
    if not VisualsState.AimbotEnabled then
        if TargetHUDFrame then TargetHUDFrame.Visible = false end
        return
    end

    local isAiming = false
    if VisualsState.AimLock then
        isAiming = true
    elseif VisualsState.AimActive then
        isAiming = true
    elseif UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        isAiming = true
    end

    local targetPart, targetPlayer = getBestAimbotTarget()

    -- Target HUD is updated regardless of whether we're locking, as long as target is in FOV
    pcall(updateTargetHUD, targetPart, isAiming, targetPlayer)

    if isAiming and targetPart then
        if VisualsState.AimType == "Mouse/Touch Aim" then
            -- Follows mouse cursor / touch in 3rd person
            local targetScreen, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            if onScreen and targetScreen.Z > 0 then
                local mousePos = UserInputService:GetMouseLocation()
                local deltaX = targetScreen.X - mousePos.X
                local deltaY = targetScreen.Y - mousePos.Y

                if type(mousemoverel) == "function" then
                    local smooth = math.max(VisualsState.AimbotSmoothness, 1)
                    mousemoverel(deltaX / smooth, deltaY / smooth)
                else
                    local rayMouse = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
                    local rayTarget = (targetPart.Position - Camera.CFrame.Position).Unit
                    local cross = rayMouse.Direction:Cross(rayTarget)
                    local dot = math.clamp(rayMouse.Direction:Dot(rayTarget), -1, 1)
                    local angle = math.acos(dot)
                    if cross.Magnitude > 1e-4 and angle > 1e-4 then
                        local rotAxis = cross.Unit
                        local smooth = math.max(VisualsState.AimbotSmoothness, 1)
                        local stepAngle = angle / smooth
                        Camera.CFrame = CFrame.fromAxisAngle(rotAxis, stepAngle) * Camera.CFrame
                    end
                end
            end
        else
            -- "Camera Aim": Follows camera
            local targetCF = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            if VisualsState.AimbotSmoothness > 1 then
                local alpha = math.clamp(1 / VisualsState.AimbotSmoothness, 0.05, 1)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
            else
                Camera.CFrame = targetCF
            end
        end
    end
end

--//==================================================
--// TRIGGERBOT ENGINE
--// Screen-space radius check: auto-clicks when an enemy
--// is within TriggerbotRadius px of the crosshair center.
--// Modes: "Always On" | "Aimbot Only"
--//==================================================

local triggerbotCooldown = false

local function updateTriggerbot()
    if not VisualsState.TriggerbotEnabled then return end

    -- "Aimbot Only" mode: only trigger when aimbot is actively aiming
    if VisualsState.TriggerbotMode == "Aimbot Only" then
        local isAiming = VisualsState.AimLock or VisualsState.AimActive
            or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if not isAiming then return end
    end

    if triggerbotCooldown then return end

    local center = getAimReferencePoint()
    local radius = math.max(VisualsState.TriggerbotRadius, 1)

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not VisualsState.Whitelisted[plr.UserId] then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local isTeammate = VisualsState.AimbotTeamCheck and myTeam and plr.Team == myTeam
                if not isTeammate then
                    -- Check each target part
                    for _, partName in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso"}) do
                        local part = char:FindFirstChild(partName)
                        if part then
                            local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen and screen.Z > 0 then
                                local dx = screen.X - center.X
                                local dy = screen.Y - center.Y
                                if math.sqrt(dx * dx + dy * dy) <= radius then
                                    -- Enemy in crosshair — fire after delay
                                    triggerbotCooldown = true
                                    task.delay(math.max(VisualsState.TriggerbotDelay, 0), function()
                                        -- Simulate mouse click
                                        if type(mouse1click) == "function" then
                                            pcall(mouse1click)
                                        elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
                                            pcall(mouse1press)
                                            task.wait(0.05)
                                            pcall(mouse1release)
                                        end
                                        task.wait(0.1)
                                        triggerbotCooldown = false
                                    end)
                                    return -- only fire once per frame
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


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

local function getCharacterTool(character, plr)
    if not character then return nil end

    -- 1. Direct Tool child of Character (Standard Roblox equipped tool)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return child.Name
        end
    end

    -- 2. Look for Tool in descendants (some games wrap tools in a Model/Folder inside character)
    local toolDesc = character:FindFirstChildOfClass("Tool")
    if toolDesc then
        return toolDesc.Name
    end

    -- 3. Check for weapons/tools welded to character hands/arms
    local hands = {
        character:FindFirstChild("RightHand"),
        character:FindFirstChild("Right Arm"),
        character:FindFirstChild("LeftHand"),
        character:FindFirstChild("Left Arm"),
    }
    for _, hand in ipairs(hands) do
        if hand then
            for _, child in ipairs(hand:GetChildren()) do
                if child:IsA("Weld") or child:IsA("Motor6D") or child:IsA("WeldConstraint") then
                    local p1 = child.Part1
                    if p1 and p1 ~= hand then
                        local model = p1:FindFirstAncestorOfClass("Model")
                        if model and model ~= character and model.Parent ~= character then
                            return model.Name
                        end
                    end
                end
            end
        end
    end

    -- 4. Check for equipped item attributes or ValueObjects
    for _, name in ipairs({ "EquippedTool", "EquippedWeapon", "CurrentWeapon", "HeldItem", "Equipped", "Tool", "Weapon" }) do
        local val = character:FindFirstChild(name)
        if val then
            if val:IsA("StringValue") and val.Value ~= "" then
                return val.Value
            elseif val:IsA("ObjectValue") and val.Value then
                return val.Value.Name
            end
        end
        local attr = character:GetAttribute(name)
        if attr and tostring(attr) ~= "" then
            return tostring(attr)
        end
    end

    return nil
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

    -- 1. 2D Box Frame (glass fill + double outline for crisp contrast)
    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxFrame"
    boxFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    boxFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    boxFrame.BackgroundTransparency = 0.88
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

    local boxOutline = Instance.new("UIStroke")
    boxOutline.Name = "BoxOutline"
    boxOutline.Color = Color3.fromRGB(0, 0, 0)
    boxOutline.Thickness = 1.0
    boxOutline.LineJoinMode = Enum.LineJoinMode.Miter
    boxOutline.Parent = boxFrame

    -- 2. Corner Box Container inside boxFrame
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

        local lineStroke = Instance.new("UIStroke")
        lineStroke.Color = Color3.fromRGB(0, 0, 0)
        lineStroke.Thickness = 1.0
        lineStroke.LineJoinMode = Enum.LineJoinMode.Miter
        lineStroke.Parent = line

        line.Parent = cornerContainer
        table.insert(cornerBrackets, line)
    end

    -- 3. 3D Wireframe Box Lines (12 edge lines)
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

    -- 4. Health Bar Background + Fill + Text
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Name = "HealthBarBg"
    healthBarBg.AnchorPoint = Vector2.new(1, 0)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Visible = false
    healthBarBg.ZIndex = 3
    healthBarBg.Parent = holder

    local healthStroke = Instance.new("UIStroke")
    healthStroke.Color = Color3.fromRGB(0, 0, 0)
    healthStroke.Thickness = 1.0
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

    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HpLabel"
    hpLabel.AnchorPoint = Vector2.new(1, 0.5)
    hpLabel.Size = UDim2.fromOffset(30, 12)
    hpLabel.BackgroundTransparency = 1
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.TextSize = 10
    hpLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
    hpLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpLabel.TextStrokeTransparency = 0.25
    hpLabel.TextXAlignment = Enum.TextXAlignment.Right
    hpLabel.Visible = false
    hpLabel.ZIndex = 5
    hpLabel.Parent = holder

    -- 5. Name Label (TOP of the box)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.AnchorPoint = Vector2.new(0.5, 1)
    nameLabel.Size = UDim2.fromOffset(260, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0.25
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.Visible = false
    nameLabel.ZIndex = 5
    nameLabel.Parent = holder

    -- 6. Distance Label (BOTTOM of the box)
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.AnchorPoint = Vector2.new(0.5, 0)
    distanceLabel.Size = UDim2.fromOffset(260, 14)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Font = Enum.Font.GothamMedium
    distanceLabel.TextSize = 11
    distanceLabel.TextColor3 = Color3.fromRGB(200, 195, 220)
    distanceLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distanceLabel.TextStrokeTransparency = 0.25
    distanceLabel.TextXAlignment = Enum.TextXAlignment.Center
    distanceLabel.TextYAlignment = Enum.TextYAlignment.Center
    distanceLabel.Visible = false
    distanceLabel.ZIndex = 5
    distanceLabel.Parent = holder

    -- 7. Tool Label (BOTTOM of the box, below distance)
    local toolLabel = Instance.new("TextLabel")
    toolLabel.Name = "ToolLabel"
    toolLabel.AnchorPoint = Vector2.new(0.5, 0)
    toolLabel.Size = UDim2.fromOffset(260, 14)
    toolLabel.BackgroundTransparency = 1
    toolLabel.Font = Enum.Font.GothamMedium
    toolLabel.TextSize = 11
    toolLabel.TextColor3 = Color3.fromRGB(215, 150, 255)
    toolLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    toolLabel.TextStrokeTransparency = 0.25
    toolLabel.TextXAlignment = Enum.TextXAlignment.Center
    toolLabel.TextYAlignment = Enum.TextYAlignment.Center
    toolLabel.Visible = false
    toolLabel.ZIndex = 5
    toolLabel.Parent = holder

    -- 8. Tracer Line
    local tracerFrame = Instance.new("Frame")
    tracerFrame.Name = "Tracer"
    tracerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    tracerFrame.BorderSizePixel = 0
    tracerFrame.BackgroundColor3 = VisualsState.ESPColor
    tracerFrame.Visible = false
    tracerFrame.ZIndex = 2
    tracerFrame.Parent = holder

    -- 9. Look Direction Ray (Head Tracer)
    local lookRayLine = Instance.new("Frame")
    lookRayLine.Name = "LookRayLine"
    lookRayLine.AnchorPoint = Vector2.new(0.5, 0.5)
    lookRayLine.BorderSizePixel = 0
    lookRayLine.BackgroundColor3 = VisualsState.LookRayColor
    lookRayLine.Visible = false
    lookRayLine.ZIndex = 4
    lookRayLine.Parent = holder

    -- Arrow tip barbs (two short angled lines at ray end)
    local lookRayBarb1 = Instance.new("Frame")
    lookRayBarb1.Name = "LookRayBarb1"
    lookRayBarb1.AnchorPoint = Vector2.new(0, 0.5)
    lookRayBarb1.BorderSizePixel = 0
    lookRayBarb1.BackgroundColor3 = VisualsState.LookRayColor
    lookRayBarb1.Visible = false
    lookRayBarb1.ZIndex = 4
    lookRayBarb1.Parent = holder

    local lookRayBarb2 = Instance.new("Frame")
    lookRayBarb2.Name = "LookRayBarb2"
    lookRayBarb2.AnchorPoint = Vector2.new(0, 0.5)
    lookRayBarb2.BorderSizePixel = 0
    lookRayBarb2.BackgroundColor3 = VisualsState.LookRayColor
    lookRayBarb2.Visible = false
    lookRayBarb2.ZIndex = 4
    lookRayBarb2.Parent = holder

    -- 10. Skeleton / Bone Lines (14 segments for R15/R6)
    local skeletonLines = {}
    for i = 1, 14 do
        local bLine = Instance.new("Frame")
        bLine.Name = "BoneLine_" .. i
        bLine.AnchorPoint = Vector2.new(0.5, 0.5)
        bLine.BorderSizePixel = 0
        bLine.BackgroundColor3 = VisualsState.SkeletonColor
        bLine.Visible = false
        bLine.ZIndex = 3
        bLine.Parent = holder
        table.insert(skeletonLines, bLine)
    end

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
        HpLabel = hpLabel,
        NameLabel = nameLabel,
        DistanceLabel = distanceLabel,
        ToolLabel = toolLabel,
        TracerFrame = tracerFrame,
        LookRayLine = lookRayLine,
        LookRayBarb1 = lookRayBarb1,
        LookRayBarb2 = lookRayBarb2,
        SkeletonLines = skeletonLines,
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
--// CHINESE HAT (SLEEK HOVERING PURPLE GRADIENT CONE)
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
        h.Transparency = 0.38
        h.Size = Vector3.new(0.2, 0.2, 0.2)

        local scale = math.clamp(VisualsState.HatRadius * 0.72, 0.7, 2.2)
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://1033714" -- Official classic Asian straw cone hat mesh
        mesh.Scale = Vector3.new(scale, scale * 0.36, scale)
        mesh.Parent = h

        -- 8 Sleek delicate glowing neon purple rib lines radiating from apex to brim
        local ribs = 8
        local brimRadius = scale * 0.82
        local apexY = scale * 0.22
        local brimY = -scale * 0.08

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
            rib.Anchored = false
            rib.Material = Enum.Material.Neon
            rib.Color = Color3.fromRGB(225, 140, 255)
            rib.Transparency = 0.2
            rib.Size = Vector3.new(0.012, 0.012, length)

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
        local scale = math.clamp(VisualsState.HatRadius * 0.72, 0.7, 2.2)
        local mesh = hat:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            mesh.Scale = Vector3.new(scale, scale * 0.36, scale)
        end

        local rotAngle = VisualsState.HatRotate and (tick() * 75 % 360) or 0
        -- Gently hovers 0.95 studs above head center (floating subtly right over head/hair)
        hat.CFrame = head.CFrame * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, math.rad(rotAngle), 0)
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
    if entry.HpLabel then entry.HpLabel.Visible = false end
    entry.NameLabel.Visible = false
    if entry.DistanceLabel then entry.DistanceLabel.Visible = false end
    entry.ToolLabel.Visible = false
    entry.TracerFrame.Visible = false
    if entry.LookRayLine then entry.LookRayLine.Visible = false end
    if entry.LookRayBarb1 then entry.LookRayBarb1.Visible = false end
    if entry.LookRayBarb2 then entry.LookRayBarb2.Visible = false end
    if entry.SkeletonLines then
        for _, l in ipairs(entry.SkeletonLines) do l.Visible = false end
    end
end

local function updatePlayer(entry)
    local plr = entry.Player
    local isLocal = (plr == LocalPlayer)
    local char = plr.Character

    if VisualsState.Whitelisted[plr.UserId] then
        hidePlayerVisuals(entry)
        if entry.ChineseHatPart then
            pcall(function() entry.ChineseHatPart:Destroy() end)
            entry.ChineseHatPart = nil
        end
        return
    end

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
    -- Note: HealthBarBasedColor only applies to the health bar fill, not the box color

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

    -- 2. Health Bar (sleek 2.5px bar with dynamic HP text when damaged)
    if VisualsState.HealthBar then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        entry.HealthBarBg.Position = UDim2.fromOffset(boxLeft - 5, boxTop)
        entry.HealthBarBg.Size = UDim2.fromOffset(2.5, boxHeight)
        entry.HealthBarBg.Visible = true

        entry.HealthBarFill.Size = UDim2.new(1, 0, hpPct, 0)
        if VisualsState.HealthBarBasedColor then
            entry.HealthBarFill.BackgroundColor3 = Color3.fromHSV(hpPct * 0.33, 0.9, 1)
        else
            entry.HealthBarFill.BackgroundColor3 = Color3.fromRGB(42, 255, 120)
        end

        if entry.HpLabel then
            if hum.Health < hum.MaxHealth - 1 then
                entry.HpLabel.Text = tostring(math.floor(hum.Health))
                entry.HpLabel.Position = UDim2.fromOffset(boxLeft - 7, boxTop + boxHeight * (1 - hpPct))
                entry.HpLabel.Visible = true
            else
                entry.HpLabel.Visible = false
            end
        end
    else
        entry.HealthBarBg.Visible = false
        if entry.HpLabel then entry.HpLabel.Visible = false end
    end

    -- 3. Name ESP (TOP of the box)
    if VisualsState.NameESP then
        local nameStr = plr.DisplayName or plr.Name
        entry.NameLabel.Text = nameStr
        entry.NameLabel.Position = UDim2.fromOffset(boxCenter.X, boxTop - 2)
        entry.NameLabel.Visible = true
    else
        entry.NameLabel.Visible = false
    end

    -- 4. Distance ESP (BOTTOM of the box)
    local bottomOffset = 2
    if VisualsState.DistanceESP then
        local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
        if entry.DistanceLabel then
            entry.DistanceLabel.Text = string.format("[%dm]", dist)
            entry.DistanceLabel.Position = UDim2.fromOffset(boxCenter.X, boxBottom + bottomOffset)
            entry.DistanceLabel.Visible = true
        end
        bottomOffset = bottomOffset + 14
    else
        if entry.DistanceLabel then entry.DistanceLabel.Visible = false end
    end

    -- 5. Tool ESP (BOTTOM of the box, stacked below distance if both enabled)
    if VisualsState.ToolESP then
        local tool = getCharacterTool(char, plr)
        if tool and tool ~= "" then
            entry.ToolLabel.Text = tool
            entry.ToolLabel.Position = UDim2.fromOffset(boxCenter.X, boxBottom + bottomOffset)
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

    -- 6. Skeleton / Bone ESP (R6 and R15 rigs)
    if VisualsState.SkeletonESP and not isLocal and entry.SkeletonLines then
        local pairsList = nil
        if rig == "R15" then
            pairsList = {
                { "Head", "UpperTorso" },
                { "UpperTorso", "LowerTorso" },
                { "UpperTorso", "LeftUpperArm" },
                { "LeftUpperArm", "LeftLowerArm" },
                { "LeftLowerArm", "LeftHand" },
                { "UpperTorso", "RightUpperArm" },
                { "RightUpperArm", "RightLowerArm" },
                { "RightLowerArm", "RightHand" },
                { "LowerTorso", "LeftUpperLeg" },
                { "LeftUpperLeg", "LeftLowerLeg" },
                { "LeftLowerLeg", "LeftFoot" },
                { "LowerTorso", "RightUpperLeg" },
                { "RightUpperLeg", "RightLowerLeg" },
                { "RightLowerLeg", "RightFoot" },
            }
        else -- R6
            pairsList = {
                { "Head", "Torso" },
                { "Torso", "Left Arm" },
                { "Torso", "Right Arm" },
                { "Torso", "Left Leg" },
                { "Torso", "Right Leg" },
            }
        end

        local lineIdx = 1
        for _, pair in ipairs(pairsList) do
            local p1 = char:FindFirstChild(pair[1])
            local p2 = char:FindFirstChild(pair[2])
            if p1 and p2 then
                local s1, on1 = Camera:WorldToViewportPoint(p1.Position)
                local s2, on2 = Camera:WorldToViewportPoint(p2.Position)
                if s1.Z > 0 and s2.Z > 0 then
                    local dx = s2.X - s1.X
                    local dy = s2.Y - s1.Y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local mid = Vector2.new((s1.X + s2.X) * 0.5, (s1.Y + s2.Y) * 0.5)
                    local angle = math.deg(math.atan2(dy, dx))

                    local bLine = entry.SkeletonLines[lineIdx]
                    if bLine then
                        bLine.Size = UDim2.fromOffset(dist, 1.5)
                        bLine.Position = UDim2.fromOffset(mid.X, mid.Y)
                        bLine.Rotation = angle
                        bLine.BackgroundColor3 = VisualsState.SkeletonColor
                        bLine.Visible = true
                        lineIdx = lineIdx + 1
                    end
                end
            end
        end
        for i = lineIdx, #entry.SkeletonLines do
            entry.SkeletonLines[i].Visible = false
        end
    elseif entry.SkeletonLines then
        for _, bLine in ipairs(entry.SkeletonLines) do
            bLine.Visible = false
        end
    end

    -- 7. Look Direction / Head Tracers (Look Rays)
    if VisualsState.LookRays and not isLocal and entry.LookRayLine then
        local head = char:FindFirstChild("Head")
        if head then
            local rayLength = math.max(VisualsState.LookRayLength, 7)
            local rayEnd = head.Position + (head.CFrame.LookVector * rayLength)
            local s1, on1 = Camera:WorldToViewportPoint(head.Position)
            local s2, on2 = Camera:WorldToViewportPoint(rayEnd)
            if s1.Z > 0 and s2.Z > 0 then
                local dx = s2.X - s1.X
                local dy = s2.Y - s1.Y
                local dist = math.sqrt(dx * dx + dy * dy)
                local mid = Vector2.new((s1.X + s2.X) * 0.5, (s1.Y + s2.Y) * 0.5)
                local angle = math.deg(math.atan2(dy, dx))
                local col = VisualsState.LookRayColor

                entry.LookRayLine.Size = UDim2.fromOffset(dist, 1.8)
                entry.LookRayLine.Position = UDim2.fromOffset(mid.X, mid.Y)
                entry.LookRayLine.Rotation = angle
                entry.LookRayLine.BackgroundColor3 = col
                entry.LookRayLine.Visible = true

                -- Arrow barbs: two short lines at s2 angled ±150° from ray direction
                local BARB_LEN = 9
                local BARB_THICK = 1.8
                for bIdx, barb in ipairs({ entry.LookRayBarb1, entry.LookRayBarb2 }) do
                    if barb then
                        local bAngle = angle + (bIdx == 1 and 150 or -150)
                        local bRad = math.rad(bAngle)
                        local bMidX = s2.X + math.cos(bRad) * BARB_LEN * 0.5
                        local bMidY = s2.Y + math.sin(bRad) * BARB_LEN * 0.5
                        barb.Size = UDim2.fromOffset(BARB_LEN, BARB_THICK)
                        barb.AnchorPoint = Vector2.new(0.5, 0.5)
                        barb.Position = UDim2.fromOffset(bMidX, bMidY)
                        barb.Rotation = bAngle
                        barb.BackgroundColor3 = col
                        barb.Visible = true
                    end
                end
            else
                entry.LookRayLine.Visible = false
                if entry.LookRayBarb1 then entry.LookRayBarb1.Visible = false end
                if entry.LookRayBarb2 then entry.LookRayBarb2.Visible = false end
            end
        else
            entry.LookRayLine.Visible = false
            if entry.LookRayBarb1 then entry.LookRayBarb1.Visible = false end
            if entry.LookRayBarb2 then entry.LookRayBarb2.Visible = false end
        end
    elseif entry.LookRayLine then
        entry.LookRayLine.Visible = false
        if entry.LookRayBarb1 then entry.LookRayBarb1.Visible = false end
        if entry.LookRayBarb2 then entry.LookRayBarb2.Visible = false end
    end
end

--//==================================================
--// CUSTOM CROSSHAIR ENGINE
--//==================================================

local CrosshairHolder = nil
local CrosshairLines = {}
local CrosshairDot = nil
local CrosshairCircle = nil
local CrosshairCircleStroke = nil

local function ensureCrosshair()
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    if CrosshairHolder and CrosshairHolder.Parent then return CrosshairHolder end
    if CrosshairHolder then pcall(function() CrosshairHolder:Destroy() end) end
    table.clear(CrosshairLines)

    CrosshairHolder = Instance.new("Frame")
    CrosshairHolder.Name = "AtomwareCrosshair"
    CrosshairHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    CrosshairHolder.Size = UDim2.fromOffset(80, 80)
    CrosshairHolder.BackgroundTransparency = 1
    CrosshairHolder.BorderSizePixel = 0
    CrosshairHolder.Visible = false
    CrosshairHolder.ZIndex = 20
    pcall(function() CrosshairHolder.Parent = container end)

    for _, name in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local line = Instance.new("Frame")
        line.Name = name
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.BackgroundColor3 = VisualsState.CrosshairColor
        line.ZIndex = 21
        line.Parent = CrosshairHolder
        CrosshairLines[name] = line
    end

    CrosshairDot = Instance.new("Frame")
    CrosshairDot.Name = "Dot"
    CrosshairDot.AnchorPoint = Vector2.new(0.5, 0.5)
    CrosshairDot.BorderSizePixel = 0
    CrosshairDot.BackgroundColor3 = VisualsState.CrosshairColor
    CrosshairDot.Position = UDim2.fromScale(0.5, 0.5)
    CrosshairDot.Visible = false
    CrosshairDot.ZIndex = 22
    CrosshairDot.Parent = CrosshairHolder
    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(1, 0)
    dCorner.Parent = CrosshairDot

    CrosshairCircle = Instance.new("Frame")
    CrosshairCircle.Name = "Circle"
    CrosshairCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    CrosshairCircle.BackgroundTransparency = 1
    CrosshairCircle.BorderSizePixel = 0
    CrosshairCircle.Position = UDim2.fromScale(0.5, 0.5)
    CrosshairCircle.Visible = false
    CrosshairCircle.ZIndex = 21
    CrosshairCircle.Parent = CrosshairHolder
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(1, 0)
    cCorner.Parent = CrosshairCircle
    CrosshairCircleStroke = Instance.new("UIStroke")
    CrosshairCircleStroke.Color = VisualsState.CrosshairColor
    CrosshairCircleStroke.Thickness = 1.5
    CrosshairCircleStroke.Parent = CrosshairCircle

    return CrosshairHolder
end

local function updateCrosshair()
    if not VisualsState.CrosshairEnabled then
        if CrosshairHolder then CrosshairHolder.Visible = false end
        return
    end

    ensureCrosshair()
    if not CrosshairHolder then return end

    local center = getAimReferencePoint()
    CrosshairHolder.Position = UDim2.fromOffset(center.X, center.Y)
    CrosshairHolder.Visible = true

    if VisualsState.CrosshairSpin then
        CrosshairHolder.Rotation = (tick() * (VisualsState.CrosshairSpinSpeed * 90)) % 360
    else
        CrosshairHolder.Rotation = 0
    end

    local size = VisualsState.CrosshairSize
    local gap = VisualsState.CrosshairGap
    local thick = VisualsState.CrosshairThickness
    local col = VisualsState.CrosshairColor
    local style = VisualsState.CrosshairStyle

    if style == "Dot" then
        CrosshairDot.Size = UDim2.fromOffset(size, size)
        CrosshairDot.BackgroundColor3 = col
        CrosshairDot.Visible = true
        CrosshairCircle.Visible = false
        for _, l in pairs(CrosshairLines) do l.Visible = false end
    elseif style == "Circle" then
        CrosshairCircle.Size = UDim2.fromOffset(size * 2, size * 2)
        if CrosshairCircleStroke then
            CrosshairCircleStroke.Color = col
            CrosshairCircleStroke.Thickness = thick
        end
        CrosshairCircle.Visible = true
        CrosshairDot.Visible = false
        for _, l in pairs(CrosshairLines) do l.Visible = false end
    else
        CrosshairDot.Visible = false
        CrosshairCircle.Visible = false

        local showTop = (style ~= "T-Shape")
        CrosshairLines.Top.Visible = showTop
        if showTop then
            CrosshairLines.Top.Size = UDim2.fromOffset(thick, size)
            CrosshairLines.Top.Position = UDim2.new(0.5, 0, 0.5, -(gap + size * 0.5))
            CrosshairLines.Top.BackgroundColor3 = col
        end

        CrosshairLines.Bottom.Visible = true
        CrosshairLines.Bottom.Size = UDim2.fromOffset(thick, size)
        CrosshairLines.Bottom.Position = UDim2.new(0.5, 0, 0.5, gap + size * 0.5)
        CrosshairLines.Bottom.BackgroundColor3 = col

        CrosshairLines.Left.Visible = true
        CrosshairLines.Left.Size = UDim2.fromOffset(size, thick)
        CrosshairLines.Left.Position = UDim2.new(0.5, -(gap + size * 0.5), 0.5, 0)
        CrosshairLines.Left.BackgroundColor3 = col

        CrosshairLines.Right.Visible = true
        CrosshairLines.Right.Size = UDim2.fromOffset(size, thick)
        CrosshairLines.Right.Position = UDim2.new(0.5, gap + size * 0.5, 0.5, 0)
        CrosshairLines.Right.BackgroundColor3 = col
    end
end

--//==================================================
--// MINI-RADAR ENGINE (2D TOP-DOWN HUD RADAR)
--//==================================================

local RadarHolder = nil
local RadarBlips = {}
local MAX_RADAR_BLIPS = 32

local function ensureRadar()
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    if RadarHolder and RadarHolder.Parent then return RadarHolder end
    if RadarHolder then pcall(function() RadarHolder:Destroy() end) end
    table.clear(RadarBlips)

    local size = VisualsState.RadarSize
    RadarHolder = Instance.new("Frame")
    RadarHolder.Name = "AtomwareMiniRadar"
    RadarHolder.Size = UDim2.fromOffset(size, size)
    RadarHolder.Position = UDim2.fromOffset(18, 56)
    RadarHolder.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
    RadarHolder.BackgroundTransparency = 0.25
    RadarHolder.BorderSizePixel = 0
    RadarHolder.Visible = false
    RadarHolder.ZIndex = 15
    pcall(function() RadarHolder.Parent = container end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = RadarHolder

    local stroke = Instance.new("UIStroke")
    stroke.Color = VisualsState.ESPColor
    stroke.Thickness = 1.5
    stroke.Parent = RadarHolder

    -- Center dot (LocalPlayer)
    local centerDot = Instance.new("Frame")
    centerDot.Name = "CenterDot"
    centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    centerDot.Size = UDim2.fromOffset(6, 6)
    centerDot.Position = UDim2.fromScale(0.5, 0.5)
    centerDot.BackgroundColor3 = Color3.fromRGB(42, 255, 157)
    centerDot.BorderSizePixel = 0
    centerDot.ZIndex = 17
    centerDot.Parent = RadarHolder
    local cDotCorner = Instance.new("UICorner")
    cDotCorner.CornerRadius = UDim.new(1, 0)
    cDotCorner.Parent = centerDot

    -- Axis lines
    local hLine = Instance.new("Frame")
    hLine.Size = UDim2.new(1, 0, 0, 1)
    hLine.Position = UDim2.fromScale(0, 0.5)
    hLine.BackgroundColor3 = Color3.fromRGB(80, 70, 110)
    hLine.BackgroundTransparency = 0.5
    hLine.BorderSizePixel = 0
    hLine.ZIndex = 16
    hLine.Parent = RadarHolder

    local vLine = Instance.new("Frame")
    vLine.Size = UDim2.new(0, 1, 1, 0)
    vLine.Position = UDim2.fromScale(0.5, 0)
    vLine.BackgroundColor3 = Color3.fromRGB(80, 70, 110)
    vLine.BackgroundTransparency = 0.5
    vLine.BorderSizePixel = 0
    vLine.ZIndex = 16
    vLine.Parent = RadarHolder

    -- Pre-create blips
    for i = 1, MAX_RADAR_BLIPS do
        local blip = Instance.new("Frame")
        blip.Name = "Blip_" .. i
        blip.AnchorPoint = Vector2.new(0.5, 0.5)
        blip.Size = UDim2.fromOffset(5, 5)
        blip.BorderSizePixel = 0
        blip.BackgroundColor3 = VisualsState.ESPColor
        blip.Visible = false
        blip.ZIndex = 18
        blip.Parent = RadarHolder
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(1, 0)
        bCorner.Parent = blip
        table.insert(RadarBlips, blip)
    end

    return RadarHolder
end

local function updateRadar()
    if not VisualsState.RadarEnabled then
        if RadarHolder then RadarHolder.Visible = false end
        return
    end

    ensureRadar()
    if not RadarHolder then return end

    RadarHolder.Visible = true
    local myChar = LocalPlayer.Character
    local myRoot = myChar and getCharacterRoot(myChar)
    if not myRoot then
        for _, b in ipairs(RadarBlips) do b.Visible = false end
        return
    end

    local myPos = myRoot.Position
    local camCF = Camera.CFrame
    local camLook = camCF.LookVector
    local camAngle = math.atan2(camLook.X, camLook.Z)
    local cosA = math.cos(-camAngle)
    local sinA = math.sin(-camAngle)

    local radarRad = (VisualsState.RadarSize * 0.5) - 4
    local maxRange = VisualsState.RadarRange
    local blipIdx = 1

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and blipIdx <= MAX_RADAR_BLIPS then
            local pRoot = getCharacterRoot(plr.Character)
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if pRoot and hum and hum.Health > 0 then
                local dx = pRoot.Position.X - myPos.X
                local dz = pRoot.Position.Z - myPos.Z
                local dist = math.sqrt(dx * dx + dz * dz)

                if dist <= maxRange then
                    local rotX = dx * cosA - dz * sinA
                    local rotY = dx * sinA + dz * cosA

                    local px = (rotX / maxRange) * radarRad
                    local py = (rotY / maxRange) * radarRad

                    local blip = RadarBlips[blipIdx]
                    if blip then
                        blip.Position = UDim2.new(0.5, px, 0.5, py)
                        if VisualsState.Whitelisted[plr.UserId] then
                            blip.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                        elseif myTeam and plr.Team == myTeam then
                            blip.BackgroundColor3 = VisualsState.TeamColor
                        else
                            blip.BackgroundColor3 = VisualsState.ESPColor
                        end
                        blip.Visible = true
                        blipIdx = blipIdx + 1
                    end
                end
            end
        end
    end

    for i = blipIdx, #RadarBlips do
        RadarBlips[i].Visible = false
    end
end

--//==================================================
--// BULLET TRACERS ENGINE
--// Detects tool activation + physical projectiles
--// Raycast wall collision, neon beam, impact particles
--//==================================================

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- Hit sound asset IDs (all 8 supported types)
local hitSoundAudioIds = {
    Default   = "rbxassetid://9119561046",
    Rust      = "rbxassetid://5043539486",
    Gamesense = "rbxassetid://4817809188",
    Magic     = "rbxassetid://182765513",
    Firework  = "rbxassetid://269146157",
    Lazer     = "rbxassetid://360661189",
    Pop       = "rbxassetid://127231141534262",
    Zap       = "rbxassetid://9119594928",
}

-- Hitmarker UI
local HitmarkerHolder = nil
local HitmarkerLines  = {}
local HitmarkerTween  = nil

local function ensureHitmarker()
    local container = ensureScreenGuiContainer()
    if not container then return nil end
    if HitmarkerHolder and HitmarkerHolder.Parent then return HitmarkerHolder end
    if HitmarkerHolder then pcall(function() HitmarkerHolder:Destroy() end) end
    table.clear(HitmarkerLines)

    HitmarkerHolder = Instance.new("Frame")
    HitmarkerHolder.Name = "AtomwareHitmarker"
    HitmarkerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    HitmarkerHolder.Size = UDim2.fromOffset(48, 48)
    HitmarkerHolder.BackgroundTransparency = 1
    HitmarkerHolder.BorderSizePixel = 0
    HitmarkerHolder.Visible = false
    HitmarkerHolder.ZIndex = 30
    pcall(function() HitmarkerHolder.Parent = container end)

    -- 4 diagonal lines forming an X
    local angles = {45, -45, 135, -135}
    for i, ang in ipairs(angles) do
        local line = Instance.new("Frame")
        line.Name = "HMLine" .. i
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.ZIndex = 31
        line.Parent = HitmarkerHolder
        table.insert(HitmarkerLines, {frame = line, angle = ang})
    end
    return HitmarkerHolder
end

local function flashHitmarker()
    if not VisualsState.HitmarkerEnabled then return end
    ensureHitmarker()
    if not HitmarkerHolder then return end

    -- Cancel any ongoing tween
    if HitmarkerTween then HitmarkerTween:Cancel() end

    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    HitmarkerHolder.Position = UDim2.fromOffset(cx, cy)

    local sz = VisualsState.HitmarkerSize
    local col = VisualsState.HitmarkerColor
    local gap = sz * 0.5
    local len = sz

    for _, info in ipairs(HitmarkerLines) do
        local ang = info.angle
        local rad = math.rad(ang)
        local cx2 = math.cos(rad) * (gap + len * 0.5)
        local cy2 = math.sin(rad) * (gap + len * 0.5)
        info.frame.Size = UDim2.fromOffset(len, 2)
        info.frame.Position = UDim2.fromOffset(24 + cx2, 24 + cy2)
        info.frame.Rotation = ang
        info.frame.BackgroundColor3 = col
        info.frame.BackgroundTransparency = 0
    end
    HitmarkerHolder.Visible = true

    -- Fade out over duration
    local dur = math.max(VisualsState.HitmarkerDuration, 0.05)
    HitmarkerTween = TweenService:Create(
        HitmarkerHolder,
        TweenInfo.new(dur, Enum.EasingStyle.Linear),
        {}
    )
    task.delay(dur, function()
        if HitmarkerHolder then HitmarkerHolder.Visible = false end
    end)
end

local function playHitSound()
    if not VisualsState.HitSoundEnabled then return end
    local soundId = hitSoundAudioIds[VisualsState.HitSoundType] or hitSoundAudioIds.Default
    pcall(function()
        local snd = Instance.new("Sound")
        snd.SoundId = soundId
        snd.Volume = math.clamp(VisualsState.HitSoundVolume, 0, 1)
        snd.RollOffMaxDistance = 9999
        snd.Parent = Workspace
        snd:Play()
        Debris:AddItem(snd, 5)
    end)
end

local function onHitDetected()
    pcall(flashHitmarker)
    pcall(playHitSound)
end

-- Spawn a screen-space bullet tracer line from origin screen point to hit screen point
local function spawnBulletTracer(originPos, hitPos)
    if not VisualsState.BulletTracersEnabled then return end
    local container = ensureScreenGuiContainer()
    if not container then return end

    local s1, v1 = Camera:WorldToViewportPoint(originPos)
    local s2, v2 = Camera:WorldToViewportPoint(hitPos)
    if not (v1 and v2 and s1.Z > 0 and s2.Z > 0) then return end

    local dx = s2.X - s1.X
    local dy = s2.Y - s1.Y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local mid = Vector2.new((s1.X + s2.X) * 0.5, (s1.Y + s2.Y) * 0.5)
    local angle = math.deg(math.atan2(dy, dx))
    local thick = math.clamp(VisualsState.BulletTracerThickness, 1, 8)
    local col = VisualsState.BulletTracerColor
    local dur = math.max(VisualsState.BulletTracerDuration, 0.05)

    local line = Instance.new("Frame")
    line.Name = "AtomwareBulletTracer"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Size = UDim2.fromOffset(dist, thick)
    line.Position = UDim2.fromOffset(mid.X, mid.Y)
    line.Rotation = angle
    line.BackgroundColor3 = col
    line.BackgroundTransparency = 0
    line.BorderSizePixel = 0
    line.ZIndex = 35
    pcall(function() line.Parent = container end)

    -- Fade out
    local ti = TweenInfo.new(dur, Enum.EasingStyle.Linear)
    local tw = TweenService:Create(line, ti, {BackgroundTransparency = 1})
    tw:Play()
    Debris:AddItem(line, dur + 0.1)

    -- Impact particle burst at hit point (screen-space glow dot)
    if VisualsState.BulletTracerParticles then
        local particle = Instance.new("Frame")
        particle.Name = "AtomwareImpact"
        particle.AnchorPoint = Vector2.new(0.5, 0.5)
        particle.Size = UDim2.fromOffset(10, 10)
        particle.Position = UDim2.fromOffset(s2.X, s2.Y)
        particle.BackgroundColor3 = col
        particle.BackgroundTransparency = 0
        particle.BorderSizePixel = 0
        particle.ZIndex = 36
        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(1, 0)
        pCorner.Parent = particle
        local pStroke = Instance.new("UIStroke")
        pStroke.Color = Color3.fromRGB(255, 255, 255)
        pStroke.Thickness = 1.5
        pStroke.Transparency = 0.3
        pStroke.Parent = particle
        pcall(function() particle.Parent = container end)

        local pTw = TweenService:Create(particle,
            TweenInfo.new(dur * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20)}
        )
        pTw:Play()
        Debris:AddItem(particle, dur * 1.5 + 0.1)
    end
end

-- Universal Bullet Tracers:
-- Hitscan weapons  → instant raycast tracer on Tool.Activated
-- Projectile games → per-frame trail segments tracking the actual part as it flies
local tracerConnections = {}

local function connectBulletTracers()
    for _, c in ipairs(tracerConnections) do pcall(function() c:Disconnect() end) end
    table.clear(tracerConnections)

    -- ── HITSCAN: raycast from handle on tool activation ──────────────────────
    local function watchTool(tool)
        if not tool or not tool:IsA("Tool") then return end
        local conn = tool.Activated:Connect(function()
            if not VisualsState.BulletTracersEnabled then return end

            local char = LocalPlayer.Character
            if not char then return end
            local handle = tool:FindFirstChild("Handle")
            local originPos = handle and handle.Position or Camera.CFrame.Position

            local direction = Camera.CFrame.LookVector * 500
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {char, tool}
            params.FilterType = Enum.RaycastFilterType.Exclude

            local result = Workspace:Raycast(originPos, direction, params)
            local hitPos = result and result.Position or (originPos + direction)

            pcall(spawnBulletTracer, originPos, hitPos)

            if result and result.Instance then
                local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                local hitHum = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
                if hitHum and hitHum.Health > 0 then
                    local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
                    if hitPlayer and hitPlayer ~= LocalPlayer then
                        onHitDetected()
                    end
                end
            end
        end)
        table.insert(tracerConnections, conn)
    end

    local function onChildAdded(child)
        if child:IsA("Tool") then watchTool(child) end
    end
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do onChildAdded(child) end
        table.insert(tracerConnections, char.ChildAdded:Connect(onChildAdded))
    end
    table.insert(tracerConnections, LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        for _, child in ipairs(newChar:GetChildren()) do onChildAdded(child) end
        table.insert(tracerConnections, newChar.ChildAdded:Connect(onChildAdded))
    end))

    -- ── PROJECTILE: per-frame trail behind moving parts ───────────────────────
    local projectileNames = {
        bullet=true, projectile=true, arrow=true, missile=true,
        rocket=true, ball=true, shard=true, pellet=true,
    }

    table.insert(tracerConnections, Workspace.DescendantAdded:Connect(function(desc)
        if not VisualsState.BulletTracersEnabled then return end
        if not desc:IsA("BasePart") then return end
        if not projectileNames[desc.Name:lower()] then return end

        local lastPos = desc.Position
        local alive   = true
        local deadline = tick() + 6 -- max 6 sec lifetime

        -- Touched → stop tracking, draw final segment, fire hitmarker
        local touchConn
        touchConn = desc.Touched:Connect(function(hit)
            if not alive then return end
            alive = false
            pcall(function() touchConn:Disconnect() end)

            local endPos = desc.Position
            pcall(spawnBulletTracer, lastPos, endPos)

            local hitChar = hit:FindFirstAncestorOfClass("Model")
            local hitHum  = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
            if hitHum and hitHum.Health > 0 then
                local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
                if hitPlayer and hitPlayer ~= LocalPlayer then
                    onHitDetected()
                end
            end
        end)

        -- Per-frame trail: draw small segments between prev and current position
        local heartbeat
        heartbeat = RunService.Heartbeat:Connect(function()
            if not alive or tick() > deadline or not desc.Parent then
                alive = false
                pcall(function() touchConn:Disconnect() end)
                pcall(function() heartbeat:Disconnect() end)
                return
            end
            if not VisualsState.BulletTracersEnabled then return end
            local curPos = desc.Position
            local segDist = (curPos - lastPos).Magnitude
            if segDist > 0.05 then  -- only draw if part actually moved
                pcall(spawnBulletTracer, lastPos, curPos)
                lastPos = curPos
            end
        end)
        table.insert(tracerConnections, heartbeat)
        task.delay(6, function()
            alive = false
            pcall(function() touchConn:Disconnect() end)
        end)
    end))
end

connectBulletTracers()


--//==================================================
--// WORLD LIGHTING ENGINE (TIME OF DAY, SKYBOX, NO FOG)
--//==================================================

local Lighting = game:GetService("Lighting")
local origClockTime = Lighting.ClockTime
local origFogEnd = Lighting.FogEnd
local customSky = nil

-- Save original sky state so "Default" cleanly restores it
local origSkyData = nil
pcall(function()
    local existingSky = Lighting:FindFirstChildOfClass("Sky")
    if existingSky then
        origSkyData = {
            SkyboxBk = existingSky.SkyboxBk,
            SkyboxDn = existingSky.SkyboxDn,
            SkyboxFt = existingSky.SkyboxFt,
            SkyboxLf = existingSky.SkyboxLf,
            SkyboxRt = existingSky.SkyboxRt,
            SkyboxUp = existingSky.SkyboxUp,
        }
    end
end)

local skyPresets = {
    ["Default"] = nil,
    -- Purple Nebula — verified working
    ["Purple Nebula"] = {
        SkyboxBk = "rbxassetid://159454299",
        SkyboxDn = "rbxassetid://159454296",
        SkyboxFt = "rbxassetid://159454293",
        SkyboxLf = "rbxassetid://159454286",
        SkyboxRt = "rbxassetid://159454300",
        SkyboxUp = "rbxassetid://159454288",
    },
    -- Night Galaxy — verified working (classic Roblox galaxy sky)
    ["Night Galaxy"] = {
        SkyboxBk = "rbxassetid://8912714447",
        SkyboxDn = "rbxassetid://8912716153",
        SkyboxFt = "rbxassetid://8912714700",
        SkyboxLf = "rbxassetid://8912715441",
        SkyboxRt = "rbxassetid://8912715185",
        SkyboxUp = "rbxassetid://8912715808",
    },
    -- Synthwave sunset — verified working
    ["Synthwave"] = {
        SkyboxBk = "rbxassetid://6444884337",
        SkyboxDn = "rbxassetid://6444885364",
        SkyboxFt = "rbxassetid://6444883747",
        SkyboxLf = "rbxassetid://6444884757",
        SkyboxRt = "rbxassetid://6444884106",
        SkyboxUp = "rbxassetid://6444885091",
    },
    -- Blizzard / Overcast day
    ["Overcast"] = {
        SkyboxBk = "rbxassetid://2388033876",
        SkyboxDn = "rbxassetid://2388034020",
        SkyboxFt = "rbxassetid://2388033528",
        SkyboxLf = "rbxassetid://2388033687",
        SkyboxRt = "rbxassetid://2388033765",
        SkyboxUp = "rbxassetid://2388033957",
    },
}

local function applySkyPreset(name)
    local preset = skyPresets[name]
    if preset then
        -- Remove any existing game sky so our custom one takes over
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Sky") and child.Name ~= "AtomwareCustomSky" then
                pcall(function() child.Parent = nil end)
            end
        end
        if not customSky or not customSky.Parent then
            customSky = Instance.new("Sky")
            customSky.Name = "AtomwareCustomSky"
            pcall(function() customSky.Parent = Lighting end)
        end
        for prop, val in pairs(preset) do
            pcall(function() customSky[prop] = val end)
        end
    else
        -- Restore Default: destroy custom sky, restore original if saved
        if customSky then
            pcall(function() customSky:Destroy() end)
            customSky = nil
        end
        -- Re-parent any detached game sky children, or restore saved data
        local hasSky = Lighting:FindFirstChildOfClass("Sky")
        if not hasSky then
            if origSkyData then
                local restoreSky = Instance.new("Sky")
                restoreSky.Name = "RestoredSky"
                for prop, val in pairs(origSkyData) do
                    pcall(function() restoreSky[prop] = val end)
                end
                pcall(function() restoreSky.Parent = Lighting end)
            end
        end
    end
end

local function updateWorldVisuals()
    if VisualsState.CustomTime then
        Lighting.ClockTime = VisualsState.TimeOfDay
    end
    if VisualsState.NoFog then
        Lighting.FogEnd = 1e6
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then
            atmo.Density = 0
            atmo.Haze = 0
        end
    end
end

-- Render loop with individual try-catch to guarantee crash-free continuous rendering
trackConnection(RunService.RenderStepped:Connect(function()
    -- 1. FOV Circle Update
    pcall(updateFOVCircle)

    -- 2. Custom Crosshair Update
    pcall(updateCrosshair)

    -- 3. Mini-Radar Update
    pcall(updateRadar)

    -- 4. World Visuals Update (ClockTime / Fog)
    pcall(updateWorldVisuals)

    -- 5. Aimbot Logic & Target HUD
    pcall(updateAimbot)

    -- 6. Triggerbot
    pcall(updateTriggerbot)

    -- 7. Hitbox Expander Update (only re-apply if missing, CharacterAdded handles respawn)
    if VisualsState.HitboxEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and not HitboxApplied[plr] then
                pcall(applyHitboxToPlayer, plr)
            end
        end
    end

    -- 8. Player ESP Update
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
        if VisualsState.HitboxEnabled then pcall(function() applyHitboxToPlayer(plr) end) end
    end)
end))

trackConnection(Players.PlayerRemoving:Connect(function(plr)
    pcall(function() restoreChams(plr) end)
    pcall(function() restoreHitboxForPlayer(plr) end)
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
--// STAGE 3: PLAYER / MOVEMENT ENGINE (CROSS-PLATFORM)
--//==================================================

local MovementState = {
    SpeedEnabled = false,
    WalkSpeed = 32,
    JumpEnabled = false,
    JumpPower = 100,
    InfiniteJump = false,
    BunnyHop = false,
    FlyEnabled = false,
    FlySpeed = 50,
    Noclip = false,
    FreeCam = false,
    FreeCamSpeed = 10,
}

local defaultWalkSpeed = 16
local defaultJumpPower = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil

-- Noclip Handler (Stepped runs before physics simulation)
trackConnection(RunService.Stepped:Connect(function()
    if MovementState.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

-- Infinite Jump Handler (Space on PC, Jump button on Mobile)
trackConnection(UserInputService.JumpRequest:Connect(function()
    if MovementState.InfiniteJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- Movement, Flight & Jump Loop (Heartbeat)
trackConnection(RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = getCharacterRoot(char)
    if not hum or hum.Health <= 0 or not root then return end

    -- Speed Hack
    if MovementState.SpeedEnabled then
        hum.WalkSpeed = MovementState.WalkSpeed
    end

    -- Super Jump
    if MovementState.JumpEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = MovementState.JumpPower
    end

    -- Bunny Hop (Auto-jump when moving on ground)
    if MovementState.BunnyHop and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    -- Flight Engine (PC & Mobile)
    if MovementState.FlyEnabled then
        if not flyBodyVelocity or not flyBodyVelocity.Parent then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.Name = "AtomwareFlyBV"
            flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyVelocity.Parent = root

            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.Name = "AtomwareFlyBG"
            flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBodyGyro.P = 1e4
            flyBodyGyro.CFrame = root.CFrame
            flyBodyGyro.Parent = root
        end

        local moveDir = hum.MoveDirection
        local camCF = Camera.CFrame
        local targetVel = Vector3.zero

        if moveDir.Magnitude > 0 then
            local forward = camCF.LookVector
            local right = camCF.RightVector
            local camRelativeDir = (forward * (-Vector3.new(0,0,1):Dot(moveDir)) + right * (Vector3.new(1,0,0):Dot(moveDir))).Unit
            if camRelativeDir.Magnitude > 0 then
                targetVel = camRelativeDir * MovementState.FlySpeed
            else
                targetVel = moveDir * MovementState.FlySpeed
            end
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            targetVel = targetVel + Vector3.new(0, MovementState.FlySpeed * 0.8, 0)
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            targetVel = targetVel - Vector3.new(0, MovementState.FlySpeed * 0.8, 0)
        end

        flyBodyVelocity.Velocity = targetVel
        flyBodyGyro.CFrame = camCF
        hum.PlatformStand = true
    else
        if flyBodyVelocity then
            pcall(function() flyBodyVelocity:Destroy() end)
            flyBodyVelocity = nil
        end
        if flyBodyGyro then
            pcall(function() flyBodyGyro:Destroy() end)
            flyBodyGyro = nil
        end
        if hum.PlatformStand then
            hum.PlatformStand = false
        end
    end
end))

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

-- Combat / Aimbot
bindToggle("Enable Aimbot", function(v) VisualsState.AimbotEnabled = v end)
bindToggle("Aim Lock", function(v) VisualsState.AimLock = v end)
bindDropdown("Aim Type", function(v) VisualsState.AimType = v end)
bindDropdown("Target Part", function(v) VisualsState.TargetPart = v end)
bindSlider("Smoothness", function(v) VisualsState.AimbotSmoothness = v end)
bindToggle("Wall Check", function(v) VisualsState.WallCheck = v end)
bindToggle("Aimbot Team Check", function(v) VisualsState.AimbotTeamCheck = v end)
bindToggle("Aim Active", function(v) VisualsState.AimActive = v end)

-- FOV Circle
bindToggle("Show FOV Circle", function(v)
    VisualsState.FOVEnabled = v
    if not v then
        if FOVFillFrame then FOVFillFrame.Visible = false end
        for _, seg in ipairs(FOVSegments) do
            seg.Visible = false
        end
    end
end)
bindSlider("FOV Radius", function(v) VisualsState.FOVRadius = v end)
bindColorPicker("FOV Color", function(v) VisualsState.FOVColor = v end)
bindToggle("Filled FOV", function(v) VisualsState.FOVFilled = v end)
bindSlider("FOV Transparency", function(v) VisualsState.FOVTransparency = v end)

-- Hitbox Expander
bindToggle("Enable Hitbox Expander", function(v)
    VisualsState.HitboxEnabled = v
    refreshAllHitboxes()
end)
bindDropdown("Hitbox Part", function(v)
    restoreAllHitboxes()
    VisualsState.HitboxPart = v
    refreshAllHitboxes()
end)
bindSlider("Hitbox Size", function(v)
    VisualsState.HitboxSize = v
    refreshAllHitboxes()
end)
bindSlider("Hitbox Transparency", function(v)
    VisualsState.HitboxTransparency = v
    refreshAllHitboxes()
end)
bindColorPicker("Hitbox Color", function(v)
    VisualsState.HitboxColor = v
    refreshAllHitboxes()
end)
bindDropdown("Hitbox Material", function(v)
    VisualsState.HitboxMaterial = v
    refreshAllHitboxes()
end)

--//==================================================
--// STAGE 3: PLAYER / MOVEMENT BINDINGS
--//==================================================

bindToggle("Speed Hack", function(v)
    MovementState.SpeedEnabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = defaultWalkSpeed end
    end
end)
bindSlider("WalkSpeed", function(v) MovementState.WalkSpeed = v end)

bindToggle("Super Jump", function(v)
    MovementState.JumpEnabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = defaultJumpPower end
    end
end)
bindSlider("JumpPower", function(v) MovementState.JumpPower = v end)

bindToggle("Infinite Jump", function(v) MovementState.InfiniteJump = v end)
bindToggle("Bunny Hop", function(v) MovementState.BunnyHop = v end)

bindToggle("Fly", function(v)
    MovementState.FlyEnabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.PlatformStand then hum.PlatformStand = false end
    end
end)
bindSlider("Fly Speed", function(v) MovementState.FlySpeed = v end)

bindToggle("Noclip", function(v) MovementState.Noclip = v end)
bindToggle("FreeCam", function(v)
    MovementState.FreeCam = v
    if _G.FireEvent then _G.FireEvent("FreeCam Active", v) end
end)
bindSlider("FreeCam Speed", function(v) MovementState.FreeCamSpeed = v end)

--//==================================================
--// NEW VISUALS, RADAR, CROSSHAIR & WORLD BINDINGS
--//==================================================

bindToggle("Health Bar Color (HP-based)", function(v) VisualsState.HealthBarBasedColor = v end)
bindToggle("Look Direction Rays", function(v) VisualsState.LookRays = v end)
bindSlider("Ray Length", function(v) VisualsState.LookRayLength = v end)
bindColorPicker("Ray Color", function(v) VisualsState.LookRayColor = v end)
bindToggle("Skeleton / Bone ESP", function(v) VisualsState.SkeletonESP = v end)
bindColorPicker("Skeleton Color", function(v) VisualsState.SkeletonColor = v end)

-- World Lighting
bindToggle("No Fog", function(v)
    VisualsState.NoFog = v
    if not v then
        Lighting.FogEnd = origFogEnd
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then atmo.Density = 0.395 atmo.Haze = 0 end
    end
end)
bindToggle("Custom Time", function(v)
    VisualsState.CustomTime = v
    if not v then Lighting.ClockTime = origClockTime end
end)
bindSlider("Time of Day", function(v) VisualsState.TimeOfDay = v end)
bindDropdown("Skybox Preset", function(v)
    VisualsState.SkyPreset = v
    applySkyPreset(v)
end)

-- Target HUD
bindToggle("Target HUD", function(v)
    VisualsState.TargetHUD = v
    if not v and TargetHUDFrame then TargetHUDFrame.Visible = false end
end)

-- Triggerbot
bindToggle("Triggerbot", function(v) VisualsState.TriggerbotEnabled = v end)
bindSlider("Triggerbot Delay", function(v) VisualsState.TriggerbotDelay = v end)
bindSlider("Triggerbot Radius", function(v) VisualsState.TriggerbotRadius = v end)
bindDropdown("Triggerbot Mode", function(v) VisualsState.TriggerbotMode = v end)

-- Whitelist System
_G.AtomwareEvents = _G.AtomwareEvents or {}
_G.AtomwareEvents["WhitelistPlayer"] = function(userId, state)
    VisualsState.Whitelisted[userId] = state
end
_G.WhitelistPlayer = function(userId, state)
    VisualsState.Whitelisted[userId] = state
end

-- Custom Crosshairs
bindToggle("Enable Crosshair", function(v) VisualsState.CrosshairEnabled = v end)
bindDropdown("Crosshair Style", function(v) VisualsState.CrosshairStyle = v end)
bindSlider("Crosshair Size", function(v) VisualsState.CrosshairSize = v end)
bindSlider("Crosshair Gap", function(v) VisualsState.CrosshairGap = v end)
bindSlider("Crosshair Thickness", function(v) VisualsState.CrosshairThickness = v end)
bindColorPicker("Crosshair Color", function(v) VisualsState.CrosshairColor = v end)
bindToggle("Spinning Crosshair", function(v) VisualsState.CrosshairSpin = v end)
bindSlider("Spin Speed", function(v) VisualsState.CrosshairSpinSpeed = v end)

-- Mini-Radar
bindToggle("Mini-Radar", function(v) VisualsState.RadarEnabled = v end)
bindSlider("Radar Range", function(v) VisualsState.RadarRange = v end)
bindSlider("Radar Size", function(v) VisualsState.RadarSize = v end)

-- Bullet Tracers
bindToggle("Bullet Tracers", function(v) VisualsState.BulletTracersEnabled = v end)
bindColorPicker("Tracer Color", function(v) VisualsState.BulletTracerColor = v end)
bindSlider("Tracer Thickness", function(v) VisualsState.BulletTracerThickness = v end)
bindSlider("Tracer Duration", function(v) VisualsState.BulletTracerDuration = v end)
bindToggle("Tracer Particles", function(v) VisualsState.BulletTracerParticles = v end)

-- Hitmarker
bindToggle("Hitmarker", function(v) VisualsState.HitmarkerEnabled = v end)
bindColorPicker("Hitmarker Color", function(v) VisualsState.HitmarkerColor = v end)
bindSlider("Hitmarker Size", function(v) VisualsState.HitmarkerSize = v end)
bindSlider("Hitmarker Duration", function(v) VisualsState.HitmarkerDuration = v end)

-- Hit Sounds
bindToggle("Hit Sounds", function(v) VisualsState.HitSoundEnabled = v end)
bindDropdown("Hit Sound Type", function(v) VisualsState.HitSoundType = v end)
bindSlider("Hit Sound Volume", function(v) VisualsState.HitSoundVolume = v end)

--//==================================================
--// UNLOAD HANDLER
--//==================================================

if _G.AtomwareConfig and type(_G.AtomwareConfig.OnUnload) == "function" then
    _G.AtomwareConfig:OnUnload(function()
        restoreAllChams()
        restoreAllHitboxes()
        for _, entry in pairs(ESPHolders) do
            removePlayerESP(entry)
        end
        table.clear(ESPHolders)
        if FOVHolder then
            pcall(function() FOVHolder:Destroy() end)
            FOVHolder = nil
            table.clear(FOVSegments)
            FOVCircleBoxFrame = nil
            FOVCircleBoxStroke = nil
        end
        if TargetHUDFrame then
            pcall(function() TargetHUDFrame:Destroy() end)
            TargetHUDFrame = nil
        end
        if CrosshairHolder then
            pcall(function() CrosshairHolder:Destroy() end)
            CrosshairHolder = nil
            table.clear(CrosshairLines)
        end
        if RadarHolder then
            pcall(function() RadarHolder:Destroy() end)
            RadarHolder = nil
            table.clear(RadarBlips)
        end
        if HitmarkerHolder then
            pcall(function() HitmarkerHolder:Destroy() end)
            HitmarkerHolder = nil
            table.clear(HitmarkerLines)
        end
        for _, c in ipairs(tracerConnections) do pcall(function() c:Disconnect() end) end
        table.clear(tracerConnections)
        if customSky then
            pcall(function() customSky:Destroy() end)
            customSky = nil
        end
        pcall(function()
            Lighting.ClockTime = origClockTime
            Lighting.FogEnd = origFogEnd
        end)
        if ScreenGuiContainer then
            pcall(function() ScreenGuiContainer:Destroy() end)
            ScreenGuiContainer = nil
        end
        if flyBodyVelocity then pcall(function() flyBodyVelocity:Destroy() end) end
        if flyBodyGyro then pcall(function() flyBodyGyro:Destroy() end) end
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = defaultWalkSpeed
                hum.JumpPower = defaultJumpPower
                if hum.PlatformStand then hum.PlatformStand = false end
            end
        end
    end)
end

_G.AtomwareFeaturesLoaded = true
print("Atomware Universal: Cross-Platform Visuals, Combat & World Engine Online")
