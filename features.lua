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
--// FOV CIRCLE (SAME FRAME HOLDER METHOD AS ESP - CROSS-PLATFORM)
--//==================================================
--// FOV CIRCLE (PURE FRAME SEGMENTS - EXACT SAME METHOD AS ESP)
--// 100% Cross-Platform: guaranteed to render on iPad & Mobile
--// Bypasses UIStroke / UICorner culling bugs on mobile GPU
--//==================================================

local FOV_SEGMENTS_COUNT = 36
local FOV_COS = {}
local FOV_SIN = {}
for i = 1, FOV_SEGMENTS_COUNT do
    local a = (i - 1) * (2 * math.pi / FOV_SEGMENTS_COUNT)
    FOV_COS[i] = math.cos(a)
    FOV_SIN[i] = math.sin(a)
end

local FOVHolder = nil
local FOVSegments = {}
local FOVFillFrame = nil
local lastTouchPos = nil

trackConnection(UserInputService.TouchStarted:Connect(function(touch)
    lastTouchPos = Vector2.new(touch.Position.X, touch.Position.Y)
end))
trackConnection(UserInputService.TouchMoved:Connect(function(touch)
    lastTouchPos = Vector2.new(touch.Position.X, touch.Position.Y)
end))

local function ensureFOVCircle()
    local container = ensureScreenGuiContainer()
    if not container then return nil end

    if FOVHolder and FOVHolder.Parent and #FOVSegments == FOV_SEGMENTS_COUNT then
        return FOVHolder
    end

    if FOVHolder then pcall(function() FOVHolder:Destroy() end) end
    table.clear(FOVSegments)

    -- Full-viewport Frame holder (EXACT same pattern as ESP holder)
    FOVHolder = Instance.new("Frame")
    FOVHolder.Name = "AtomwareFOVHolder"
    FOVHolder.Size = UDim2.fromScale(1, 1)
    FOVHolder.Position = UDim2.fromScale(0, 0)
    FOVHolder.BackgroundTransparency = 1
    FOVHolder.BorderSizePixel = 0
    FOVHolder.ClipsDescendants = false
    FOVHolder.ZIndex = 5
    pcall(function() FOVHolder.Parent = container end)

    -- Filled circle center (optional fill when FOVFilled is on)
    FOVFillFrame = Instance.new("Frame")
    FOVFillFrame.Name = "FOVFill"
    FOVFillFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVFillFrame.BorderSizePixel = 0
    FOVFillFrame.BackgroundTransparency = 1
    FOVFillFrame.Visible = false
    FOVFillFrame.ZIndex = 5
    FOVFillFrame.Parent = FOVHolder

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = FOVFillFrame

    -- 36 Line Segments (EXACT same method as Tracers and 3D Box ESP)
    for i = 1, FOV_SEGMENTS_COUNT do
        local line = Instance.new("Frame")
        line.Name = "FOVSegment_" .. i
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.BackgroundColor3 = VisualsState and VisualsState.FOVColor or Color3.fromRGB(157, 48, 255)
        line.BackgroundTransparency = 0.2
        line.Visible = false
        line.ZIndex = 6
        line.Parent = FOVHolder
        table.insert(FOVSegments, line)
    end

    return FOVHolder
end

local function getAimReferencePoint()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    if VisualsState and VisualsState.AimType == "Mouse/Touch Aim" then
        if lastTouchPos then
            return lastTouchPos
        end
        local mousePos = UserInputService:GetMouseLocation()
        if mousePos.X > 0 and mousePos.Y > 0 then
            return Vector2.new(mousePos.X, mousePos.Y)
        end
    end
    return center
end

local function updateFOVCircle()
    if VisualsState.FOVEnabled then
        ensureFOVCircle()
        if FOVHolder and #FOVSegments == FOV_SEGMENTS_COUNT then
            local rad = VisualsState.FOVRadius
            local center = getAimReferencePoint()
            local color = VisualsState.FOVColor
            local trans = VisualsState.FOVTransparency

            -- Optional filled center
            if VisualsState.FOVFilled and FOVFillFrame then
                FOVFillFrame.Size = UDim2.fromOffset(rad * 2, rad * 2)
                FOVFillFrame.Position = UDim2.fromOffset(center.X, center.Y)
                FOVFillFrame.BackgroundColor3 = color
                FOVFillFrame.BackgroundTransparency = math.clamp(trans + 0.5, 0, 1)
                FOVFillFrame.Visible = true
            elseif FOVFillFrame then
                FOVFillFrame.Visible = false
            end

            -- 36 Segments around circumference (same drawing math as 3D box and tracers)
            for i = 1, FOV_SEGMENTS_COUNT do
                local nextIdx = (i % FOV_SEGMENTS_COUNT) + 1
                local p1 = center + Vector2.new(FOV_COS[i] * rad, FOV_SIN[i] * rad)
                local p2 = center + Vector2.new(FOV_COS[nextIdx] * rad, FOV_SIN[nextIdx] * rad)
                local dist = (p2 - p1).Magnitude
                local mid = (p1 + p2) / 2
                local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))

                local seg = FOVSegments[i]
                if seg then
                    seg.Size = UDim2.fromOffset(dist + 0.8, 2)
                    seg.Position = UDim2.fromOffset(mid.X, mid.Y)
                    seg.Rotation = angle
                    seg.BackgroundColor3 = color
                    seg.BackgroundTransparency = trans
                    seg.Visible = true
                end
            end
        end
    else
        if FOVFillFrame then FOVFillFrame.Visible = false end
        for _, seg in ipairs(FOVSegments) do
            seg.Visible = false
        end
    end
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
--// HITBOX EXPANDER ENGINE (UNIVERSAL / CROSS-PLATFORM)
--//==================================================

local HitboxApplied = {}

local function applyHitboxToPlayer(plr)
    if not VisualsState.HitboxEnabled or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)
    if VisualsState.TeamCheck and myTeam and plr.Team == myTeam then
        return
    end

    local partName = VisualsState.HitboxPart
    local part = char:FindFirstChild(partName)
    if not part or not part:IsA("BasePart") then return end

    if not HitboxApplied[plr] then
        HitboxApplied[plr] = {
            part = part,
            origSize = part.Size,
            origTrans = part.Transparency,
            origColor = part.Color,
            origMat = part.Material,
            origCanCollide = part.CanCollide,
        }
    end

    local size = VisualsState.HitboxSize
    part.Size = Vector3.new(size, size, size)
    part.Transparency = VisualsState.HitboxTransparency
    part.CanCollide = false
    part.Massless = true
    part.Color = VisualsState.HitboxColor
    part.Material = Enum.Material[VisualsState.HitboxMaterial] or Enum.Material.ForceField
end

local function restoreHitboxForPlayer(plr)
    local rec = HitboxApplied[plr]
    if rec then
        local part = rec.part
        if part and part.Parent then
            part.Size = rec.origSize
            part.Transparency = rec.origTrans
            part.Color = rec.origColor
            part.Material = rec.origMat
            part.CanCollide = rec.origCanCollide
        end
        HitboxApplied[plr] = nil
    end
end

local function restoreAllHitboxes()
    for plr in pairs(HitboxApplied) do
        restoreHitboxForPlayer(plr)
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

--//==================================================
--// AIMBOT ENGINE (UNIVERSAL / PC & MOBILE SUPPORT)
--//==================================================

local function getBestAimbotTarget()
    if not VisualsState.AimbotEnabled then return nil end
    local refPt = getAimReferencePoint()
    local bestTarget = nil
    local bestDist = VisualsState.FOVRadius

    local myTeam = nil
    pcall(function() myTeam = LocalPlayer.Team end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
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
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

local function updateAimbot()
    if not VisualsState.AimbotEnabled then return end

    local isAiming = false
    if VisualsState.AimLock then
        isAiming = true
    elseif VisualsState.AimActive then
        isAiming = true
    elseif UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        isAiming = true
    end

    if isAiming then
        local targetPart = getBestAimbotTarget()
        if targetPart then
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

    -- 2. Health Bar (sleek 2.5px bar with dynamic HP text when damaged)
    if VisualsState.HealthBar then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        entry.HealthBarBg.Position = UDim2.fromOffset(boxLeft - 5, boxTop)
        entry.HealthBarBg.Size = UDim2.fromOffset(2.5, boxHeight)
        entry.HealthBarBg.Visible = true

        entry.HealthBarFill.Size = UDim2.new(1, 0, hpPct, 0)
        entry.HealthBarFill.BackgroundColor3 = Color3.fromHSV(hpPct * 0.33, 0.9, 1)

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
end

-- Render loop with individual try-catch to guarantee crash-free continuous rendering
trackConnection(RunService.RenderStepped:Connect(function()
    -- 1. FOV Circle Update
    pcall(updateFOVCircle)

    -- 2. Aimbot Logic
    pcall(updateAimbot)

    -- 3. Hitbox Expander Update
    if VisualsState.HitboxEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                pcall(applyHitboxToPlayer, plr)
            end
        end
    end

    -- 4. Player ESP Update
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
            FOVFillFrame = nil
        end
        if ScreenGuiContainer then
            pcall(function() ScreenGuiContainer:Destroy() end)
            ScreenGuiContainer = nil
        end
    end)
end

_G.AtomwareFeaturesLoaded = true
print("Atomware Universal: Cross-Platform Visuals & Combat Engine Online")
