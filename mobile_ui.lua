--[[
    mobile_ui.lua
    mobile_ui.lua
    Mobile UI for Atomware (Universal Script)
    Same framework as Trident Survival - game features added per-game
    Two-column compact layout with draggable mobile controls
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function trackConnection(connection)
    if _G.AtomwareConfig then return _G.AtomwareConfig:TrackConnection(connection) end
    return connection
end
local function trackTask(thread)
    if _G.AtomwareConfig then return _G.AtomwareConfig:TrackTask(thread) end
    return thread
end

--//==================================================
--// GLOBAL EVENT BINDING SYSTEM
--//==================================================

_G.AtomwareEvents = _G.AtomwareEvents or {}
_G.AtomwarePendingEvents = {}
local eventWorkers = {}
local queuedEvents = {}

local function dispatchEvent(name, callback, args, count)
    local queued = queuedEvents[name]
    if name == "Free Cam Look" and queued then
        queued.Args[1] = (tonumber(queued.Args[1]) or 0) + (tonumber(args[1]) or 0)
        queued.Args[2] = (tonumber(queued.Args[2]) or 0) + (tonumber(args[2]) or 0)
        queued.Count = 2
    elseif name == "Free Cam Input" and queued then
        if not queued.Batch then
            queued.Batch = { { Callback = queued.Callback, Args = queued.Args, Count = queued.Count } }
        end
        table.insert(queued.Batch, { Callback = callback, Args = args, Count = count })
    else
        queuedEvents[name] = { Callback = callback, Args = args, Count = count }
    end
    if eventWorkers[name] then return end
    eventWorkers[name] = true
    local worker = task.spawn(function()
        while queuedEvents[name] do
            local event = queuedEvents[name]
            queuedEvents[name] = nil
            local batch = event.Batch or { event }
            for _, item in ipairs(batch) do
                local ok, err = pcall(item.Callback, table.unpack(item.Args, 1, item.Count))
                if not ok then warn("Atomware: event '" .. name .. "' failed: " .. tostring(err)) end
            end
        end
        eventWorkers[name] = nil
    end)
    trackTask(worker)
end

local function registerAtomwareEvent(name, callback)
    _G.AtomwareEvents[name] = callback
    local pending = _G.AtomwarePendingEvents[name]
    if pending then
        _G.AtomwarePendingEvents[name] = nil
        dispatchEvent(name, callback, pending, pending.n)
    end
end

_G.OnToggle = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnSlider = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnDropdown = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnColorPicker = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.OnKeybind = function(name, callback)
    registerAtomwareEvent(name, callback)
end

_G.FireEvent = function(name, ...)
    if _G.AtomwareConfig and type(_G.AtomwareConfig.Store) == "function" and select("#", ...) == 1 then
        pcall(function(...) _G.AtomwareConfig:Store(name, (...)) end, ...)
    end
    local callback = _G.AtomwareEvents and _G.AtomwareEvents[name]
    if type(callback) == "function" then
        local args = { ... }
        local count = select("#", ...)
        dispatchEvent(name, callback, args, count)
        return
    end
    _G.AtomwarePendingEvents = _G.AtomwarePendingEvents or {}
    local args = { ... }
    args.n = select("#", ...)
    _G.AtomwarePendingEvents[name] = args
end

local function bindSetting(name, default, apply, validate)
    if _G.AtomwareConfig then return _G.AtomwareConfig:Register(name, default, apply, validate) end
    return default
end

--//==================================================
--// MOBILE THEME & STYLING
--//==================================================

local THEME = {
    Background      = Color3.fromRGB(8, 6, 15),
    Header          = Color3.fromRGB(13, 9, 24),
    Card            = Color3.fromRGB(16, 11, 30),
    CardAlt         = Color3.fromRGB(24, 16, 44),
    CardHover       = Color3.fromRGB(32, 20, 56),

    Border          = Color3.fromRGB(105, 45, 195),
    BorderDim       = Color3.fromRGB(55, 30, 95),
    Accent          = Color3.fromRGB(157, 48, 255),
    AccentBright    = Color3.fromRGB(205, 104, 255),
    AccentDark      = Color3.fromRGB(80, 26, 142),

    Text            = Color3.fromRGB(245, 241, 255),
    TextMuted       = Color3.fromRGB(170, 155, 205),
    TextDim         = Color3.fromRGB(110, 95, 140),

    Green           = Color3.fromRGB(42, 255, 157),
    Red             = Color3.fromRGB(255, 75, 125),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent
    return p
end

--//==================================================
--// SCREEN GUI ROOT
--//==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AtomwareMobileUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
pcall(function()
    ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
ScreenGui.DisplayOrder = 100

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    if LocalPlayer then
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
        if playerGui then return playerGui end
    end
    return CoreGui
end

local guiParent = getGuiParent()
local existingGui = guiParent and guiParent:FindFirstChild("AtomwareMobileUI")
if existingGui then existingGui:Destroy() end
ScreenGui.Parent = guiParent
if _G.AtomwareConfig then _G.AtomwareConfig:AttachUI(ScreenGui, "Mobile") end

--//==================================================
--// FLOATING MOBILE UI TOGGLE
--//==================================================

local mobileControlScale = 1
local mobileLayoutControls = {}
local freeCamTouchPad
local freeCamEnabled = false
local mobileToggleLocked = false
local MobileToggleDock
local MobileToggleBtn
local MobileToggleLockBtn
local MobileToggleScale

local function clampMobileControl(item, persist)
    local frame = item and item.frame
    if not frame or not frame.Parent then return end
    local viewport = ScreenGui.AbsoluteSize
    if viewport.X <= 0 or viewport.Y <= 0 then return end

    local anchor = frame.AnchorPoint
    local absoluteSize = frame.AbsoluteSize
    local minX = absoluteSize.X * anchor.X / viewport.X
    local maxX = 1 - absoluteSize.X * (1 - anchor.X) / viewport.X
    local minY = absoluteSize.Y * anchor.Y / viewport.Y
    local maxY = 1 - absoluteSize.Y * (1 - anchor.Y) / viewport.Y
    if minX > maxX then minX, maxX = 0.5, 0.5 end
    if minY > maxY then minY, maxY = 0.5, 0.5 end

    local position = frame.Position
    local x = math.clamp(position.X.Scale, minX, maxX)
    local y = math.clamp(position.Y.Scale, minY, maxY)
    frame.Position = UDim2.fromScale(x, y)
    if persist and _G.AtomwareConfig then
        _G.AtomwareConfig:Store(item.name .. " X", x)
        _G.AtomwareConfig:Store(item.name .. " Y", y)
    end
end

local function clampAllMobileControls(persist)
    for _, item in ipairs(mobileLayoutControls) do
        clampMobileControl(item, persist)
    end
end

local function configureMobileControl(frame, name, defaultX, defaultY, dragTarget, onTap)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    local item
    local function setX(value)
        frame.Position = UDim2.new(value, 0, frame.Position.Y.Scale, 0)
        if item then clampMobileControl(item, true) end
    end
    local function setY(value)
        frame.Position = UDim2.new(frame.Position.X.Scale, 0, value, 0)
        if item then clampMobileControl(item, true) end
    end
    local config = _G.AtomwareConfig
    local storedX = config and config.Values[name .. " X"]
    local storedY = config and config.Values[name .. " Y"]
    local validatePosition = function(v) return type(v) == "number" and v >= 0.03 and v <= 0.97 end
    local x = bindSetting(name .. " X", storedX or defaultX, setX, validatePosition)
    local y = bindSetting(name .. " Y", storedY or defaultY, setY, validatePosition)
    frame.Position = UDim2.fromScale(x, y)
    item = {
        frame = frame, name = name,
        defaultX = defaultX, defaultY = defaultY,
    }
    table.insert(mobileLayoutControls, item)
    clampMobileControl(item, true)
    task.defer(function() clampMobileControl(item, true) end)

    if dragTarget then
        local activeInput, pressPosition, startCenter
        local hasDragged = false

        local function updateDrag(input)
            if not activeInput or mobileToggleLocked then return end
            local position = input.Position
            local delta = Vector2.new(position.X, position.Y) - pressPosition
            if not hasDragged and delta.Magnitude < 8 then return end
            hasDragged = true

            local viewport = ScreenGui.AbsoluteSize
            if viewport.X <= 0 or viewport.Y <= 0 then return end
            local center = startCenter + delta
            local halfWidth = frame.AbsoluteSize.X * 0.5
            local halfHeight = frame.AbsoluteSize.Y * 0.5
            local minX, maxX = halfWidth / viewport.X, 1 - halfWidth / viewport.X
            local minY, maxY = halfHeight / viewport.Y, 1 - halfHeight / viewport.Y
            if minX > maxX then minX, maxX = 0.5, 0.5 end
            if minY > maxY then minY, maxY = 0.5, 0.5 end
            local nx = math.clamp(center.X / viewport.X, minX, maxX)
            local ny = math.clamp(center.Y / viewport.Y, minY, maxY)
            frame.Position = UDim2.fromScale(nx, ny)
            if _G.AtomwareConfig then
                _G.AtomwareConfig:Store(name .. " X", nx)
                _G.AtomwareConfig:Store(name .. " Y", ny)
            end
        end

        local function endDrag(input)
            if not activeInput then return end
            local releasedTouch = activeInput.UserInputType == Enum.UserInputType.Touch and input == activeInput
            local releasedMouse = activeInput.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1
            if not releasedTouch and not releasedMouse then return end

            if not hasDragged and not mobileToggleLocked and onTap then onTap() end
            activeInput, pressPosition, startCenter = nil, nil, nil
            hasDragged = false
        end

        trackConnection(dragTarget.InputBegan:Connect(function(input)
            if mobileToggleLocked then return end
            if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if activeInput then return end
            activeInput = input
            local position = input.Position
            pressPosition = Vector2.new(position.X, position.Y)
            hasDragged = false
            local origin = ScreenGui.AbsolutePosition
            startCenter = frame.AbsolutePosition + Vector2.new(
                frame.AbsoluteSize.X * frame.AnchorPoint.X,
                frame.AbsoluteSize.Y * frame.AnchorPoint.Y
            ) - origin
        end))

        -- Touch has its own movement signal. TouchMoved carries the same
        -- InputObject as InputBegan for that finger, unlike the generic
        -- InputChanged stream on some mobile clients.
        trackConnection(UserInputService.TouchMoved:Connect(function(input)
            if not activeInput or activeInput.UserInputType ~= Enum.UserInputType.Touch then return end
            if input ~= activeInput then return end
            updateDrag(input)
        end))

        trackConnection(UserInputService.InputChanged:Connect(function(input)
            if not activeInput or activeInput.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            updateDrag(input)
        end))

        trackConnection(UserInputService.TouchEnded:Connect(endDrag))
        trackConnection(UserInputService.InputEnded:Connect(function(input)
            if activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 then
                endDrag(input)
            end
        end))
    end

    return item
end

local function setMobileControlScale(value)
    mobileControlScale = math.clamp(value, 0.92, 1.5)
    if MobileToggleScale then MobileToggleScale.Scale = mobileControlScale end
    if MobileToggleDock and MobileToggleBtn and MobileToggleLockBtn then
        local toggleSize = 56 * mobileControlScale
        local lockSize = 60
        local gap = 6
        local dockHeight = math.max(toggleSize, 56)
        MobileToggleDock.Size = UDim2.fromOffset(toggleSize + gap + lockSize, dockHeight)
        MobileToggleBtn.Position = UDim2.fromOffset(toggleSize / 2, dockHeight / 2)
        MobileToggleLockBtn.Position = UDim2.fromOffset(toggleSize + gap + lockSize / 2, dockHeight / 2)
    end
    clampAllMobileControls(true)
    task.defer(function() clampAllMobileControls(true) end)
end

local function makeFloatingToggle(onTap)
    local dock = Instance.new("Frame")
    dock.Name = "MobileToggleDock"
    dock.AnchorPoint = Vector2.new(0.5, 0.5)
    dock.BackgroundTransparency = 1
    dock.ZIndex = 150
    dock.Parent = ScreenGui

    local toggle = Instance.new("TextButton")
    toggle.Name = "MobileToggle"
    toggle.AnchorPoint = Vector2.new(0.5, 0.5)
    toggle.Size = UDim2.fromOffset(56, 56)
    toggle.BackgroundColor3 = THEME.Header
    toggle.Text = "A"
    toggle.TextColor3 = THEME.AccentBright
    toggle.TextSize = 23
    toggle.Font = FONT_BOLD
    toggle.AutoButtonColor = false
    toggle.ZIndex = 151
    toggle.Parent = dock
    corner(toggle, 16)
    stroke(toggle, THEME.Accent, 1.5)

    MobileToggleScale = Instance.new("UIScale")
    MobileToggleScale.Parent = toggle

    local lock = Instance.new("TextButton")
    lock.Name = "Lock"
    lock.AnchorPoint = Vector2.new(0.5, 0.5)
    lock.Size = UDim2.fromOffset(60, 56)
    lock.BackgroundColor3 = THEME.CardAlt
    lock.Text = "LOCK: OFF"
    lock.TextColor3 = THEME.TextMuted
    lock.TextSize = 9
    lock.Font = FONT_BOLD
    lock.AutoButtonColor = false
    lock.ZIndex = 151
    lock.Parent = dock
    corner(lock, 12)
    stroke(lock, THEME.Accent, 1.5)

    MobileToggleDock = dock
    MobileToggleBtn = toggle
    MobileToggleLockBtn = lock
    configureMobileControl(dock, "MobileToggle", 0.84, 0.72, toggle, onTap)
    setMobileControlScale(mobileControlScale)

    trackConnection(lock.MouseButton1Click:Connect(function()
        mobileToggleLocked = not mobileToggleLocked
        lock.Text = mobileToggleLocked and "LOCK: ON" or "LOCK: OFF"
        lock.BackgroundColor3 = mobileToggleLocked and THEME.Accent or THEME.CardAlt
        lock.TextColor3 = mobileToggleLocked and THEME.Text or THEME.TextMuted
    end))

    return toggle
end

--//==================================================
--// MAIN WINDOW CONTAINER (FIXED NON-SCROLLING HEADER & TABS)
--//==================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.Size = UDim2.new(0.97, 0, 0.94, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
local mainFrameSizeConstraint = Instance.new("UISizeConstraint")
mainFrameSizeConstraint.MinSize = Vector2.new(0, 0)
mainFrameSizeConstraint.MaxSize = Vector2.new(960, 820)
mainFrameSizeConstraint.Parent = MainFrame
corner(MainFrame, 12)
stroke(MainFrame, THEME.Border, 1.5)

local UIVisible = true
local function setUIVisible(state)
    UIVisible = state
    if state then
        MainFrame.Visible = true
        tween(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.97, 0, 0.94, 0)
        })
    else
        tween(MainFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        }).Completed:Once(function()
            if not UIVisible then MainFrame.Visible = false end
        end)
    end
end

MobileToggleBtn = makeFloatingToggle(function()
    setUIVisible(not UIVisible)
end)

-- Fixed Header (Never Scrolls)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
stroke(Header, THEME.BorderDim, 1)

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.fromOffset(4, 24)
HeaderAccent.Position = UDim2.fromOffset(12, 11)
HeaderAccent.BackgroundColor3 = THEME.Accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header
corner(HeaderAccent, 2)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Text = "atomware  <font color=\"#cd68ff\">mobile</font>"
Title.RichText = true
Title.Size = UDim2.new(0.6, 0, 1, 0)
Title.Position = UDim2.fromOffset(24, 0)
Title.TextSize = 18
Title.TextColor3 = THEME.Text
Title.Font = FONT_BOLD
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(44, 44)
CloseBtn.Position = UDim2.new(1, -50, 0, 3)
CloseBtn.BackgroundColor3 = THEME.Card
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = THEME.Red
CloseBtn.TextSize = 13
CloseBtn.Font = FONT_BOLD
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
corner(CloseBtn, 6)
stroke(CloseBtn, THEME.BorderDim, 1)
trackConnection(CloseBtn.MouseButton1Click:Connect(function() setUIVisible(false) end))

-- Navigation Tab Bar (Fixed, Stays Locked Under Header)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 52)
TabBar.Position = UDim2.fromOffset(0, 50)
TabBar.BackgroundColor3 = THEME.Header
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 2
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.Parent = MainFrame
padding(TabBar, 8, 8, 4, 4)

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabListLayout.Padding = UDim.new(0, 8)
TabListLayout.Parent = TabBar

-- Content Viewport (Scrollable Content Container)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.fromOffset(0, 102)
ContentArea.Size = UDim2.new(1, 0, 1, -102)
ContentArea.Parent = MainFrame

local Pages = {}
local TabButtons = {}
local CurrentPageName = "Visuals"
local responsiveLayouts = {}

--//==================================================
--// TWO-COLUMN PAGE CREATOR
--//==================================================

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.new(1, 0, 1, 0)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.Parent = ContentArea
    padding(page, 8, 8, 8, 20)

    -- Horizontal two-column container
    local colContainer = Instance.new("Frame")
    colContainer.Name = "ColContainer"       -- named so getCols() can find it reliably
    colContainer.BackgroundTransparency = 1
    colContainer.Size = UDim2.new(1, 0, 0, 0)
    colContainer.AutomaticSize = Enum.AutomaticSize.Y
    colContainer.Parent = page

    local hList = Instance.new("UIListLayout")
    hList.FillDirection = Enum.FillDirection.Horizontal
    hList.VerticalAlignment = Enum.VerticalAlignment.Top
    hList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    hList.Padding = UDim.new(0, 8)
    hList.SortOrder = Enum.SortOrder.LayoutOrder
    hList.Parent = colContainer

    local leftCol = Instance.new("Frame")
    leftCol.BackgroundTransparency = 1
    leftCol.Size = UDim2.new(0.5, -4, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.LayoutOrder = 1
    leftCol.Parent = colContainer

    local leftList = Instance.new("UIListLayout")
    leftList.Padding = UDim.new(0, 8)
    leftList.SortOrder = Enum.SortOrder.LayoutOrder
    leftList.Parent = leftCol

    local rightCol = Instance.new("Frame")
    rightCol.BackgroundTransparency = 1
    rightCol.Size = UDim2.new(0.5, -4, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.LayoutOrder = 2
    rightCol.Parent = colContainer

    local rightList = Instance.new("UIListLayout")
    rightList.Padding = UDim.new(0, 8)
    rightList.SortOrder = Enum.SortOrder.LayoutOrder
    rightList.Parent = rightCol

    table.insert(responsiveLayouts, { layout = hList, left = leftCol, right = rightCol })

    Pages[name] = page
    return page, leftCol, rightCol
end

local function switchPage(name)
    CurrentPageName = name
    for pName, pFrame in pairs(Pages) do
        pFrame.Visible = (pName == name)
    end
    for pName, btn in pairs(TabButtons) do
        local active = (pName == name)
        tween(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and THEME.AccentDark or THEME.Card,
            TextColor3 = active and THEME.AccentBright or THEME.TextMuted
        })
    end
end

--//==================================================
--// ROBUST CARD CONTAINER WIDGET BUILDER
--//==================================================

local function createCard(parent, title)
    local card = Instance.new("Frame")
    card.Name = title .. "Card"
    card.BackgroundColor3 = THEME.Card
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent
    corner(card, 10)
    stroke(card, THEME.BorderDim, 1)
    padding(card, 10, 10, 8, 10)

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 6)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Parent = card

    -- Card Header
    local head = Instance.new("Frame")
    head.Name = "CardHeader"
    head.LayoutOrder = 1
    head.Size = UDim2.new(1, 0, 0, 24)
    head.BackgroundTransparency = 1
    head.Parent = card

    local acc = Instance.new("Frame")
    acc.Size = UDim2.fromOffset(3, 14)
    acc.Position = UDim2.fromOffset(0, 3)
    acc.BackgroundColor3 = THEME.Accent
    acc.BorderSizePixel = 0
    acc.Parent = head
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    lbl.TextSize = 14
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT_BOLD
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = head

    -- Divider
    local div = Instance.new("Frame")
    div.Name = "Divider"
    div.LayoutOrder = 2
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = THEME.BorderDim
    div.BorderSizePixel = 0
    div.Parent = card

    -- Card Body
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.LayoutOrder = 3
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Parent = card

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 6)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    return card, body
end

local function createToggle(parent, setting, defaultState, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -64, 1, 0)
    lbl.TextSize = 14
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(52, 44)
    btn.Position = UDim2.new(1, -52, 0.5, -22)
    btn.BackgroundColor3 = defaultState and THEME.Accent or THEME.CardAlt
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 11)
    stroke(btn, defaultState and THEME.AccentBright or THEME.BorderDim, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.Position = defaultState and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = btn
    corner(knob, 8)

    local state = defaultState
    local function apply(v)
        if type(v) ~= "boolean" then return end
        state = v
        tween(btn, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
        tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) })
        _G.FireEvent(setting, state)
        if onChange then onChange(state) end
    end
    state = bindSetting(setting, defaultState, apply, function(v) return type(v) == "boolean" end)
    apply(state)

    trackConnection(btn.MouseButton1Click:Connect(function()
        apply(not state)
    end))
    return row
end

local function createFreeCamTouchPad()
    local pad = Instance.new("Frame")
    pad.Name = "FreeCamTouchControls"
    pad.Size = UDim2.fromOffset(224, 148)
    pad.Position = UDim2.fromScale(0.36, 0.76)
    pad.BackgroundTransparency = 1
    pad.Visible = false
    pad.ZIndex = 30
    pad.Parent = ScreenGui
    configureMobileControl(pad, "Free Camera Pad", 0.36, 0.76)

    local function addButton(name, text, x, y, onStart, onStop)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.fromOffset(48, 48)
        button.Position = UDim2.fromOffset(x, y)
        button.BackgroundColor3 = THEME.Header
        button.BackgroundTransparency = 0.12
        button.Text = text
        button.TextColor3 = THEME.Text
        button.TextSize = 19
        button.Font = FONT_BOLD
        button.AutoButtonColor = false
        button.ZIndex = 31
        button.Parent = pad
        corner(button, 8)
        stroke(button, THEME.Accent, 1)
        local activeInput
        trackConnection(button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                if activeInput then return end
                activeInput = input
                onStart()
            end
        end))
        trackConnection(button.InputEnded:Connect(function(input)
            if activeInput and (input == activeInput or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
                activeInput = nil
                if onStop then onStop() end
            end
        end))
    end

    local function movementButton(name, text, x, y, keyName)
        addButton(name, text, x, y,
            function() _G.FireEvent("Free Cam Input", keyName, true) end,
            function() _G.FireEvent("Free Cam Input", keyName, false) end)
    end
    movementButton("FreeCamForward", "▲", 50, 0, "W")
    movementButton("FreeCamLeft", "◀", 0, 50, "A")
    movementButton("FreeCamBack", "▼", 50, 50, "S")
    movementButton("FreeCamRight", "▶", 100, 50, "D")
    movementButton("FreeCamUp", "+", 50, 100, "Space")
    movementButton("FreeCamDown", "−", 100, 100, "LeftShift")

    local lookSurface = Instance.new("TextButton")
    lookSurface.Name = "FreeCamLookSurface"
    lookSurface.Size = UDim2.fromOffset(76, 148)
    lookSurface.Position = UDim2.fromOffset(148, 0)
    lookSurface.BackgroundColor3 = THEME.Header
    lookSurface.BackgroundTransparency = 0.12
    lookSurface.Text = "SWIPE\nTO LOOK"
    lookSurface.TextColor3 = THEME.TextMuted
    lookSurface.TextSize = 13
    lookSurface.TextWrapped = true
    lookSurface.Font = FONT_BOLD
    lookSurface.AutoButtonColor = false
    lookSurface.ZIndex = 31
    lookSurface.Parent = pad
    corner(lookSurface, 8)
    stroke(lookSurface, THEME.Accent, 1)
    local lookInput, lastLookPosition
    trackConnection(lookSurface.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            lookInput, lastLookPosition = input, input.Position
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not lookInput then return end
        if lookInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= lookInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local delta = input.Position - lastLookPosition
        lastLookPosition = input.Position
        _G.FireEvent("Free Cam Look", delta.X * 0.25, delta.Y * 0.25)
    end))
    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if lookInput and (input == lookInput or (lookInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
            lookInput, lastLookPosition = nil, nil
        end
    end))
    return pad
end

freeCamTouchPad = createFreeCamTouchPad()

local function createSlider(parent, setting, min, max, default, step, suffix)
    step = step or 1
    suffix = suffix or ""

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 64)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(0.6, 0, 0, 20)
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = THEME.Text
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default) .. suffix
    valLbl.Size = UDim2.new(0.4, 0, 0, 20)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextSize = 14
    valLbl.TextColor3 = THEME.AccentBright
    valLbl.Font = FONT_BOLD
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 12)
    track.Position = UDim2.fromOffset(0, 38)
    track.BackgroundColor3 = THEME.CardAlt
    track.Parent = row
    corner(track, 5)
    stroke(track, THEME.BorderDim, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.Parent = track
    corner(fill, 5)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = track
    corner(knob, 8)
    stroke(knob, THEME.AccentBright, 1)

    local val = default
    local dragging = false
    local dragInput
    local dragOrigin
    local dragMode

    local function apply(value)
        if type(value) ~= "number" then return end
        val = math.clamp(math.floor(value / step + 0.5) * step, min, max)
        local pct = (val - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = tostring(val) .. suffix
        _G.FireEvent(setting, val)
    end
    val = bindSetting(setting, default, apply, function(v) return type(v) == "number" and v >= min and v <= max end)
    apply(val)

    local function update(inputPos)
        if track.AbsoluteSize.X <= 0 then return end
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        apply(min + (relX * (max - min)))
    end

    trackConnection(row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local trackTop = track.AbsolutePosition.Y - 20
            local trackBottom = track.AbsolutePosition.Y + track.AbsoluteSize.Y + 20
            if input.Position.Y < trackTop or input.Position.Y > trackBottom then return end
            dragging = true
            dragInput = input
            dragOrigin = input.Position
            dragMode = nil
            update(input.Position)
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= dragInput then return end
            if not dragMode then
                local delta = input.Position - dragOrigin
                if math.abs(delta.Y) > 8 and math.abs(delta.Y) > math.abs(delta.X) * 1.2 then
                    dragging, dragInput, dragOrigin = false, nil, nil
                    return
                elseif math.abs(delta.X) > 5 then
                    dragMode = "slider"
                else
                    return
                end
            end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        update(input.Position)
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if not dragging or not dragInput then return end
        if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging, dragInput, dragOrigin, dragMode = false, nil, nil, nil
        end
    end))

    return row
end

-- createDropdown accepts an optional onChange callback for local UI logic
local function createDropdown(parent, setting, options, default, onChange, displayNames)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 70)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local function optionLabel(value)
        return displayNames and displayNames[value] or tostring(value)
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = THEME.Text
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.Position = UDim2.fromOffset(0, 22)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = "  " .. optionLabel(default or options[1])
    btn.TextColor3 = THEME.AccentBright
    btn.TextSize = 14
    btn.Font = FONT_BOLD
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Size = UDim2.fromOffset(30, 44)
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.TextColor3 = THEME.AccentBright
    arrow.TextSize = 12
    arrow.Parent = btn

    local dropFrame = Instance.new("ScrollingFrame")
    local dropdownCanvasHeight = #options * 48 + 8
    local availableHeight = MainFrame.AbsoluteSize.Y
    if availableHeight <= 0 then availableHeight = 360 end
    local dropdownHeight = math.max(120, math.min(240, availableHeight - 120))
    local desiredPopupHeight = math.min(dropdownCanvasHeight, dropdownHeight)
    dropFrame.Size = UDim2.new(1, 0, 0, desiredPopupHeight)
    dropFrame.CanvasSize = UDim2.new(0, 0, 0, dropdownCanvasHeight)
    dropFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    dropFrame.ScrollBarThickness = 3
    dropFrame.ScrollBarImageColor3 = THEME.Accent
    dropFrame.ClipsDescendants = true
    dropFrame.Position = UDim2.new(0, 0, 1, 4)
    dropFrame.BackgroundColor3 = THEME.Header
    dropFrame.Visible = false
    dropFrame.ZIndex = 80
    dropFrame.Parent = btn
    corner(dropFrame, 8)
    stroke(dropFrame, THEME.Accent, 1)
    padding(dropFrame, 4, 4, 4, 4)

    local dropList = Instance.new("UIListLayout")
    dropList.Padding = UDim.new(0, 4)
    dropList.Parent = dropFrame

    local selected = default or options[1]
    local open = false

    local function toggle()
        open = not open
        dropFrame.Visible = open
        if open then
            local frameTop = MainFrame.AbsolutePosition.Y
            local frameBottom = frameTop + MainFrame.AbsoluteSize.Y
            local buttonTop = btn.AbsolutePosition.Y
            local buttonBottom = buttonTop + btn.AbsoluteSize.Y
            local spaceBelow = frameBottom - buttonBottom
            local spaceAbove = buttonTop - frameTop
            local desiredHeight = desiredPopupHeight
            local maxHeight = math.max(1, MainFrame.AbsoluteSize.Y - 16)
            local popupHeight = math.min(desiredHeight, maxHeight)
            dropFrame.Size = UDim2.new(1, 0, 0, popupHeight)
            if spaceBelow >= popupHeight + 8 then
                dropFrame.Position = UDim2.new(0, 0, 1, 4)
            elseif spaceAbove >= popupHeight + 8 then
                dropFrame.Position = UDim2.new(0, 0, 0, -popupHeight - 4)
            else
                local topMin = frameTop + 8
                local topMax = math.max(topMin, frameBottom - popupHeight - 8)
                local top = math.clamp(buttonTop, topMin, topMax)
                dropFrame.Position = UDim2.new(0, 0, 0, top - buttonTop)
            end
            dropFrame.CanvasPosition = Vector2.zero
        end
        arrow.Text = open and "▲" or "▼"
    end

    trackConnection(btn.MouseButton1Click:Connect(toggle))

    local optionButtons = {}
    local function apply(value)
        if not table.find(options, value) then return end
        selected = value
        btn.Text = "  " .. optionLabel(selected)
        for _, optionButton in ipairs(optionButtons) do
            optionButton.TextColor3 = optionButton.Text == "  " .. optionLabel(selected) and THEME.AccentBright or THEME.TextMuted
        end
        if _G.AtomwareConfig then _G.AtomwareConfig:Store(setting, selected) end
        _G.FireEvent(setting, selected)
        if onChange then onChange(selected) end
    end

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 44)
        optBtn.BackgroundColor3 = THEME.Card
        optBtn.Text = "  " .. optionLabel(opt)
        optBtn.TextColor3 = (opt == selected) and THEME.AccentBright or THEME.TextMuted
        optBtn.TextSize = 14
        optBtn.Font = FONT
        optBtn.TextXAlignment = Enum.TextXAlignment.Left
        optBtn.TextTruncate = Enum.TextTruncate.AtEnd
        optBtn.ZIndex = 81
        optBtn.Parent = dropFrame
        corner(optBtn, 4)
        table.insert(optionButtons, optBtn)

        trackConnection(optBtn.MouseButton1Click:Connect(function()
            apply(opt)
            toggle()
        end))
    end

    selected = bindSetting(setting, selected, apply, function(v) return table.find(options, v) ~= nil end)
    apply(selected)

    return row
end

local function createColorPicker(parent, setting, defaultColor, onChange)
    defaultColor = defaultColor or Color3.fromRGB(157, 48, 255)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -68, 1, 0)
    lbl.TextSize = 14
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = row

    local preview = Instance.new("TextButton")
    preview.Size = UDim2.fromOffset(50, 44)
    preview.Position = UDim2.new(1, -50, 0.5, -22)
    preview.BackgroundColor3 = defaultColor
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.Parent = row
    corner(preview, 6)
    stroke(preview, THEME.BorderDim, 1)

    local palette = {
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(157, 48, 255),
        Color3.fromRGB(205, 104, 255), Color3.fromRGB(42, 255, 157),
        Color3.fromRGB(255, 75, 125),  Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(0, 150, 255),   Color3.fromRGB(72, 72, 72)
    }

    local popover = Instance.new("Frame")
    popover.Size = UDim2.fromOffset(184, 160)
    popover.Position = UDim2.new(1, -184, 1, 4)
    popover.BackgroundColor3 = THEME.Header
    popover.Visible = false
    popover.ZIndex = 90
    popover.Parent = preview
    corner(popover, 8)
    stroke(popover, THEME.Accent, 1)
    padding(popover, 6, 6, 6, 6)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(44, 44)
    grid.CellPadding = UDim2.fromOffset(4, 4)
    grid.Parent = popover

    local open = false
    local function apply(value)
        if typeof(value) ~= "Color3" then return end
        preview.BackgroundColor3 = value
        _G.FireEvent(setting, value)
        if onChange then onChange(value) end
    end
    defaultColor = bindSetting(setting, defaultColor, apply, function(v) return typeof(v) == "Color3" end)
    apply(defaultColor)
    trackConnection(preview.MouseButton1Click:Connect(function()
        open = not open
        popover.Visible = open
        if open then
            local frameTop = MainFrame.AbsolutePosition.Y
            local frameBottom = frameTop + MainFrame.AbsoluteSize.Y
            local popupHeight = popover.AbsoluteSize.Y
            if popupHeight <= 0 then popupHeight = popover.Size.Y.Offset end
            local previewTop = preview.AbsolutePosition.Y
            local previewBottom = previewTop + preview.AbsoluteSize.Y
            local spaceBelow = frameBottom - previewBottom
            local spaceAbove = previewTop - frameTop
            if spaceBelow >= popupHeight + 8 then
                popover.Position = UDim2.new(1, -184, 1, 4)
            elseif spaceAbove >= popupHeight + 8 then
                popover.Position = UDim2.new(1, -184, 0, -popupHeight - 4)
            else
                local topMin = frameTop + 8
                local topMax = math.max(topMin, frameBottom - popupHeight - 8)
                local top = math.clamp(previewTop, topMin, topMax)
                popover.Position = UDim2.new(1, -184, 0, top - previewTop)
            end
        end
    end))

    for _, col in ipairs(palette) do
        local pBtn = Instance.new("TextButton")
        pBtn.BackgroundColor3 = col
        pBtn.Text = ""
        pBtn.ZIndex = 91
        pBtn.Parent = popover
        corner(pBtn, 4)
        trackConnection(pBtn.MouseButton1Click:Connect(function()
            open = false
            popover.Visible = false
            apply(col)
        end))
    end

    return row
end

--//==================================================
--// POPULATE ALL TABS & SECTIONS
--//==================================================

local tabsData = {
    { Name = "Visuals",  Icon = "👁️" },
    { Name = "Combat",   Icon = "⚔️" },
    { Name = "Player",   Icon = "👤" },
    { Name = "Settings", Icon = "⚙️" },
}

for _, t in ipairs(tabsData) do
    local pName = t.Name
    createPage(pName)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(104, 44)
    btn.BackgroundColor3 = THEME.Card
    btn.Text = t.Icon .. "  " .. pName
    btn.TextColor3 = THEME.TextMuted
    btn.TextSize = 13
    btn.Font = FONT_BOLD
    btn.AutoButtonColor = false
    btn.Parent = TabBar
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    TabButtons[pName] = btn
    trackConnection(btn.MouseButton1Click:Connect(function()
        switchPage(pName)
    end))
end

-- Helper to get both columns of a page.
-- Uses the named "ColContainer" child set in createPage() — robust against
-- other Frame children that may exist on the ScrollingFrame.
local function getCols(pageName)
    local page = Pages[pageName]
    local col = page:FindFirstChild("ColContainer")
    if not col then
        -- Fallback: scan for the Frame that owns a horizontal UIListLayout
        for _, c in ipairs(page:GetChildren()) do
            if c:IsA("Frame") then
                local layout = c:FindFirstChildOfClass("UIListLayout")
                if layout and layout.FillDirection == Enum.FillDirection.Horizontal then
                    col = c
                    break
                end
            end
        end
    end
    local left, right
    if col then
        for _, c in ipairs(col:GetChildren()) do
            if c:IsA("Frame") then
                if c.LayoutOrder == 1 then left = c
                elseif c.LayoutOrder == 2 then right = c
                end
            end
        end
    end
    return left, right
end

local function updateResponsiveColumns()
    local isNarrow = MainFrame.AbsoluteSize.X < 640
    for _, entry in ipairs(responsiveLayouts) do
        if isNarrow then
            entry.layout.FillDirection = Enum.FillDirection.Vertical
            entry.left.Size = UDim2.new(1, 0, 0, 0)
            entry.right.Size = UDim2.new(1, 0, 0, 0)
        else
            entry.layout.FillDirection = Enum.FillDirection.Horizontal
            entry.left.Size = UDim2.new(0.5, -4, 0, 0)
            entry.right.Size = UDim2.new(0.5, -4, 0, 0)
        end
    end
end

-- ---------------------------------------------------
-- TAB 1: VISUALS
-- ---------------------------------------------------
local lVisuals, rVisuals = getCols("Visuals")

local _, bPlayerESP = createCard(lVisuals, "Player ESP")
createToggle(bPlayerESP, "Enable ESP", false)
createToggle(bPlayerESP, "Box ESP", false)
createDropdown(bPlayerESP, "Box Style", { "2D Box", "Corner Box", "3D Box" }, "2D Box")
createToggle(bPlayerESP, "Name ESP", false)
createToggle(bPlayerESP, "Distance ESP", false)
createToggle(bPlayerESP, "Health Bar", false)
createToggle(bPlayerESP, "Tool ESP", false)
createToggle(bPlayerESP, "Tracers", false)
createDropdown(bPlayerESP, "Tracer Origin", { "Bottom", "Center", "Mouse" }, "Bottom")
createToggle(bPlayerESP, "Team Check", false)
createColorPicker(bPlayerESP, "ESP Color", Color3.fromRGB(157, 48, 255))
createColorPicker(bPlayerESP, "Team Color", Color3.fromRGB(42, 255, 157))

local _, bChams = createCard(rVisuals, "Material Chams")
createToggle(bChams, "Enable Chams", false)
local chamsMaterialOptions = { "ForceField", "Neon", "Glass", "Ice", "Marble", "Foil", "Metal", "Wood" }
createDropdown(bChams, "Material", chamsMaterialOptions, "ForceField")
createColorPicker(bChams, "Chams Color", Color3.fromRGB(120, 200, 255))
createToggle(bChams, "See Through (Glow)", true)
createToggle(bChams, "Chams Team Check", false)

local _, bHat = createCard(rVisuals, "Chinese Hat ESP")
createToggle(bHat, "Chinese Hat", false)
createToggle(bHat, "Hat on Local Player", true)
createToggle(bHat, "Hat on Others", true)
createSlider(bHat, "Hat Radius", 1, 5, 2, 0.5, " studs")
createSlider(bHat, "Hat Segments", 6, 24, 12, 1, "")
createColorPicker(bHat, "Hat Color", Color3.fromRGB(205, 104, 255))
createToggle(bHat, "Rotate Hat", true)

-- ---------------------------------------------------
-- TAB 2: COMBAT
-- ---------------------------------------------------
local lCombat, rCombat = getCols("Combat")
local _, bCombat = createCard(lCombat, "Combat")
local cNotice = Instance.new("TextLabel")
cNotice.Size = UDim2.new(1, 0, 0, 32)
cNotice.BackgroundTransparency = 1
cNotice.Text = "Universal Combat modules will load here."
cNotice.TextColor3 = THEME.TextMuted
cNotice.TextSize = 13
cNotice.Font = FONT
cNotice.Parent = bCombat

-- ---------------------------------------------------
-- TAB 3: PLAYER
-- ---------------------------------------------------
local lPlayer, rPlayer = getCols("Player")
local _, bPlayer = createCard(lPlayer, "Movement & Player")
local pNotice = Instance.new("TextLabel")
pNotice.Size = UDim2.new(1, 0, 0, 32)
pNotice.BackgroundTransparency = 1
pNotice.Text = "Universal Player modules will load here."
pNotice.TextColor3 = THEME.TextMuted
pNotice.TextSize = 13
pNotice.Font = FONT
pNotice.Parent = bPlayer

-- ---------------------------------------------------
-- TAB 4: SETTINGS
-- ---------------------------------------------------
local lSettings, rSettings = getCols("Settings")

-- LEFT COLUMN
local _, bMobileSet = createCard(lSettings, "Mobile Controls")
_G.OnSlider("UI Toggle Size", setMobileControlScale)
createSlider(bMobileSet, "UI Toggle Size", 0.92, 1.5, 1, 0.1, "x")

-- RIGHT COLUMN
local _, bClose = createCard(rSettings, "Manage UI")
createToggle(bClose, "Show Keybind List", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetKeybindListVisible(v) end
end)
createToggle(bClose, "Show Watermark", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkVisible(v) end
end)
createToggle(bClose, "Show FPS Counter", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetFPSCounterVisible(v) end
end)
createToggle(bClose, "Raid Alerts", false)
createToggle(bClose, "Airdrop Alerts", false)
createSlider(bClose, "Alert Duration", 1, 10, 3, 1, "s")
createColorPicker(bClose, "Watermark Color", Color3.fromRGB(205, 104, 255), function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkColor(v) end
end)
createDropdown(bClose, "Notification Corner", { "TopRight", "TopLeft", "BottomRight", "BottomLeft" }, "TopRight", function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetNotificationCorner(v) end
end)
local destBtn = Instance.new("TextButton")
destBtn.Size = UDim2.new(1, 0, 0, 44)
destBtn.BackgroundColor3 = Color3.fromRGB(70, 20, 35)
destBtn.Text = "Unload Atomware"
destBtn.TextColor3 = THEME.Red
destBtn.TextSize = 14
destBtn.Font = FONT_BOLD
destBtn.Parent = bClose
corner(destBtn, 6)
trackConnection(destBtn.MouseButton1Click:Connect(function()
    if _G.AtomwareUnload then _G.AtomwareUnload() else ScreenGui:Destroy() end
end))

local _, bProfiles = createCard(rSettings, "Profiles")
local profileName = Instance.new("TextBox")
profileName.Size = UDim2.new(1, 0, 0, 44)
profileName.BackgroundColor3 = THEME.CardAlt
profileName.TextColor3 = THEME.Text
profileName.PlaceholderColor3 = THEME.TextDim
profileName.PlaceholderText = "Profile name"
profileName.Text = (_G.AtomwareConfig and _G.AtomwareConfig.Profile) or "Default"
profileName.ClearTextOnFocus = false
profileName.TextSize = 14
profileName.Font = FONT
profileName.Parent = bProfiles
corner(profileName, 6)
trackConnection(profileName.Focused:Connect(function()
    trackTask(task.spawn(function()
        RunService.RenderStepped:Wait()
        local page = Pages.Settings
        if not page or not profileName.Parent then return end
        local fieldY = profileName.AbsolutePosition.Y - page.AbsolutePosition.Y
        local targetY = page.CanvasPosition.Y + fieldY - 120
        local maxY = math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteSize.Y)
        page.CanvasPosition = Vector2.new(page.CanvasPosition.X, math.clamp(targetY, 0, maxY))
    end))
end))

local function makeProfileButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 44)
    button.BackgroundColor3 = THEME.CardAlt
    button.Text = text
    button.TextColor3 = THEME.AccentBright
    button.TextSize = 14
    button.Font = FONT_BOLD
    button.AutoButtonColor = false
    button.Parent = bProfiles
    corner(button, 6)
    trackConnection(button.MouseButton1Click:Connect(callback))
end

makeProfileButton("Save Profile", function()
    local ok, message = _G.AtomwareConfig:Save(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Profile saved." or (message or "Profile save failed."))
end)
makeProfileButton("Load Profile", function()
    local ok, message = _G.AtomwareConfig:Load(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Profile loaded." or (message or "Profile load failed."))
end)
makeProfileButton("Use at Startup", function()
    local ok, message = _G.AtomwareConfig:SetAutoload(profileName.Text)
    _G.AtomwareConfig:Notify(ok and "Startup profile set." or (message or "Could not set startup profile."))
end)

switchPage("Visuals")

updateResponsiveColumns()
local viewportConnection
local function observeCurrentCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = trackConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            updateResponsiveColumns()
            clampAllMobileControls(true)
        end))
    end
    updateResponsiveColumns()
    clampAllMobileControls(true)
end
observeCurrentCamera()
trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(observeCurrentCamera))
trackConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    updateResponsiveColumns()
    clampAllMobileControls(true)
end))

trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then
        setUIVisible(not UIVisible)
    end
end))

_G.AtomwareUILoaded = true
print("Good to go")
