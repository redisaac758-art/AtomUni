--[[
--[[
    main_ui.lua
    Desktop & Xbox Controller UI for Atomware (Universal Script)
    Same framework as Trident Survival - game features will be added per-game
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
--// THEME & STYLING
--//==================================================

local THEME = {
    Background      = Color3.fromRGB(6, 4, 12),
    Header          = Color3.fromRGB(10, 7, 20),
    Sidebar         = Color3.fromRGB(10, 7, 20),
    Card            = Color3.fromRGB(14, 9, 26),
    CardAlt         = Color3.fromRGB(19, 13, 35),
    CardHover       = Color3.fromRGB(25, 16, 45),

    Border          = Color3.fromRGB(90, 38, 165),
    BorderDim       = Color3.fromRGB(45, 24, 80),
    Accent          = Color3.fromRGB(157, 48, 255),
    AccentBright    = Color3.fromRGB(205, 104, 255),
    AccentDark      = Color3.fromRGB(70, 24, 125),

    Text            = Color3.fromRGB(245, 241, 255),
    TextMuted       = Color3.fromRGB(155, 142, 185),
    TextDim         = Color3.fromRGB(95, 82, 122),

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
ScreenGui.Name = "AtomwareUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
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
local existingGui = guiParent and guiParent:FindFirstChild("AtomwareUI")
if existingGui then existingGui:Destroy() end
ScreenGui.Parent = guiParent
if _G.AtomwareConfig then _G.AtomwareConfig:AttachUI(ScreenGui, "PC") end

--//==================================================
--// MAIN WINDOW CONTAINER
--//==================================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.Size = UDim2.new(0.92, 0, 0.90, 0)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
local mainFrameSizeConstraint = Instance.new("UISizeConstraint")
mainFrameSizeConstraint.MinSize = Vector2.new(0, 0)
mainFrameSizeConstraint.MaxSize = Vector2.new(880, 560)
mainFrameSizeConstraint.Parent = MainFrame
corner(MainFrame, 12)
stroke(MainFrame, THEME.Border, 1.5)

local OuterGlow = Instance.new("UIStroke")
OuterGlow.Color = THEME.Accent
OuterGlow.Thickness = 8
OuterGlow.Transparency = 0.88
OuterGlow.Parent = MainFrame

local UIVisible = true
local function setUIVisible(state)
    UIVisible = state
    if state then
        MainFrame.Visible = true
        tween(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.92, 0, 0.90, 0)
        })
    else
        tween(MainFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0)
        }).Completed:Once(function()
            if not UIVisible then MainFrame.Visible = false end
        end)
    end
end

-- Dragging System
local dragging, dragStart, startPos
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = MainFrame.Position
    trackConnection(input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end))
end

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

-- Fixed Header (Never Scrolls)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = THEME.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
stroke(Header, THEME.BorderDim, 1)

trackConnection(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        beginDrag(input)
    end
end))

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.fromOffset(4, 26)
HeaderAccent.Position = UDim2.fromOffset(12, 11)
HeaderAccent.BackgroundColor3 = THEME.Accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header
corner(HeaderAccent, 2)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Text = "atomware  <font color=\"#cd68ff\">v2</font>"
Title.RichText = true
Title.Size = UDim2.new(0.4, 0, 1, 0)
Title.Position = UDim2.fromOffset(24, 0)
Title.TextSize = 19
Title.TextColor3 = THEME.Text
Title.Font = FONT_BOLD
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(32, 28)
CloseBtn.Position = UDim2.new(1, -40, 0, 10)
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

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(32, 28)
MinBtn.Position = UDim2.new(1, -78, 0, 10)
MinBtn.BackgroundColor3 = THEME.Card
MinBtn.Text = "—"
MinBtn.TextColor3 = THEME.Text
MinBtn.TextSize = 13
MinBtn.Font = FONT_BOLD
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header
corner(MinBtn, 6)
stroke(MinBtn, THEME.BorderDim, 1)
trackConnection(MinBtn.MouseButton1Click:Connect(function() setUIVisible(false) end))

-- Fixed Left Sidebar (Never Scrolls)
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 180, 1, -58)
Sidebar.Position = UDim2.fromOffset(10, 52)
Sidebar.BackgroundColor3 = THEME.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
corner(Sidebar, 10)
stroke(Sidebar, THEME.BorderDim, 1)
padding(Sidebar, 8, 8, 10, 10)

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.Parent = Sidebar

-- Content Area (Scrollable Independent Pages)
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.BackgroundTransparency = 1
ContentArea.Position = UDim2.fromOffset(198, 52)
ContentArea.Size = UDim2.new(1, -208, 1, -58)
ContentArea.Parent = MainFrame

local Pages = {}
local PageColumns = {}
local TabButtons = {}
local InteractiveElements = {}
local CurrentPageName = "Visuals"

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.new(1, 0, 1, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.Accent
    page.Visible = false
    page.Parent = ContentArea
    padding(page, 6, 8, 2, 14)

    -- Each column owns a vertical layout so cards keep their content-driven
    -- height. A UIGridLayout with a zero-height cell clipped/overlapped cards.
    local columns = {}
    for i = 1, 2 do
        local column = Instance.new("Frame")
        column.Name = i == 1 and "LeftColumn" or "RightColumn"
        column.BackgroundTransparency = 1
        column.Position = UDim2.new((i - 1) * 0.5, i == 1 and 6 or 4, 0, 2)
        column.Size = UDim2.new(0.5, -12, 0, 0)
        column.AutomaticSize = Enum.AutomaticSize.Y
        column.Parent = page

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 10)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = column
        columns[i] = column
    end

    PageColumns[page] = { Columns = columns, Counts = { 0, 0 } }
    Pages[name] = page
    return page
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
--// WIDGET BUILDERS (CONTAINER CARD ARCHITECTURE)
--//==================================================

local function createCard(parent, title)
    local cardParent = parent
    local pageLayout = PageColumns[parent]
    if pageLayout then
        local counts = pageLayout.Counts
        local columnIndex = counts[1] <= counts[2] and 1 or 2
        counts[columnIndex] = counts[columnIndex] + 1
        cardParent = pageLayout.Columns[columnIndex]
    end

    local card = Instance.new("Frame")
    card.Name = title .. "Card"
    card.BackgroundColor3 = THEME.Card
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = cardParent
    corner(card, 8)
    stroke(card, THEME.BorderDim, 1)
    padding(card, 10, 10, 8, 10)

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 6)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Parent = card

    local head = Instance.new("Frame")
    head.Name = "CardHeader"
    head.LayoutOrder = 1
    head.Size = UDim2.new(1, 0, 0, 22)
    head.BackgroundTransparency = 1
    head.Parent = card

    local acc = Instance.new("Frame")
    acc.Size = UDim2.fromOffset(3, 15)
    acc.Position = UDim2.fromOffset(0, 3)
    acc.BackgroundColor3 = THEME.Accent
    acc.BorderSizePixel = 0
    acc.Parent = head
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.fromOffset(8, 0)
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.Text
    lbl.Font = FONT_BOLD
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = head

    local div = Instance.new("Frame")
    div.Name = "Divider"
    div.LayoutOrder = 2
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = THEME.BorderDim
    div.BorderSizePixel = 0
    div.Parent = card

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.LayoutOrder = 3
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Parent = card

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = body

    return card, body
end

local function createToggle(parent, setting, defaultState, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -52, 1, 0)
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextMuted
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(40, 20)
    btn.Position = UDim2.new(1, -40, 0.5, -10)
    btn.BackgroundColor3 = defaultState and THEME.Accent or THEME.CardAlt
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 10)
    stroke(btn, defaultState and THEME.AccentBright or THEME.BorderDim, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = defaultState and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = btn
    corner(knob, 7)

    local state = defaultState
    local function apply(v)
        if type(v) ~= "boolean" then return end
        state = v
        tween(btn, TweenInfo.new(0.14), { BackgroundColor3 = state and THEME.Accent or THEME.CardAlt })
        tween(knob, TweenInfo.new(0.14), { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3) })
        _G.FireEvent(setting, state)
        if onChange then onChange(state) end
    end
    state = bindSetting(setting, defaultState, apply, function(v) return type(v) == "boolean" end)
    apply(state)

    trackConnection(btn.MouseButton1Click:Connect(function()
        apply(not state)
    end))

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function() apply(not state) end
    })

    return row
end

local function createSlider(parent, setting, min, max, default, step, suffix)
    step = step or 1
    suffix = suffix or ""

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(0.6, 0, 0, 16)
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = THEME.TextMuted
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default) .. suffix
    valLbl.Size = UDim2.new(0.4, 0, 0, 16)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.AccentBright
    valLbl.Font = FONT_BOLD
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.fromOffset(0, 24)
    track.BackgroundColor3 = THEME.CardAlt
    track.Parent = row
    corner(track, 4)
    stroke(track, THEME.BorderDim, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.Parent = track
    corner(fill, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.Text
    knob.Parent = track
    corner(knob, 7)
    stroke(knob, THEME.AccentBright, 1)

    local val = default
    local dragging = false

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
        local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        apply(min + (relX * (max - min)))
    end

    trackConnection(row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input.Position)
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input.Position)
        end
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    table.insert(InteractiveElements, {
        Frame = row,
        Adjust = function(delta) apply(val + (delta * step)) end
    })

    return row
end

local function createDropdown(parent, setting, options, default, onChange, displayNames)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local function optionLabel(value)
        return displayNames and displayNames[value] or tostring(value)
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = setting
    titleLbl.Size = UDim2.new(1, 0, 0, 16)
    titleLbl.TextSize = 11
    titleLbl.TextColor3 = THEME.TextMuted
    titleLbl.Font = FONT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.Position = UDim2.fromOffset(0, 20)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = "  " .. optionLabel(default or options[1])
    btn.TextColor3 = THEME.Text
    btn.TextSize = 11
    btn.Font = FONT
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.Size = UDim2.fromOffset(24, 26)
    arrow.Position = UDim2.new(1, -24, 0, 0)
    arrow.TextColor3 = THEME.AccentBright
    arrow.TextSize = 10
    arrow.Parent = btn

    local dropFrame = Instance.new("Frame")
    dropFrame.Size = UDim2.new(1, 0, 0, #options * 26 + 6)
    dropFrame.Position = UDim2.new(0, 0, 1, 4)
    dropFrame.BackgroundColor3 = THEME.Header
    dropFrame.Visible = false
    dropFrame.ZIndex = 80
    dropFrame.Parent = btn
    corner(dropFrame, 6)
    stroke(dropFrame, THEME.Accent, 1)
    padding(dropFrame, 4, 4, 4, 4)

    local dropList = Instance.new("UIListLayout")
    dropList.Padding = UDim.new(0, 2)
    dropList.Parent = dropFrame

    local selected = default or options[1]
    local open = false

    local function toggle()
        open = not open
        dropFrame.Visible = open
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
        _G.FireEvent(setting, selected)
        if onChange then onChange(selected) end
    end

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.BackgroundColor3 = THEME.Card
        optBtn.Text = "  " .. optionLabel(opt)
        optBtn.TextColor3 = (opt == selected) and THEME.AccentBright or THEME.TextMuted
        optBtn.TextSize = 11
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

    table.insert(InteractiveElements, {
        Frame = row,
        Action = toggle,
        Adjust = function(direction)
            local index = table.find(options, selected) or 1
            apply(options[(index - 1 + direction) % #options + 1])
        end,
    })
    return row
end

local function createColorPicker(parent, setting, defaultColor, onChange)
    defaultColor = defaultColor or Color3.fromRGB(157, 48, 255)

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextMuted
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local preview = Instance.new("TextButton")
    preview.Size = UDim2.fromOffset(36, 20)
    preview.Position = UDim2.new(1, -36, 0.5, -10)
    preview.BackgroundColor3 = defaultColor
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.Parent = row
    corner(preview, 6)
    stroke(preview, THEME.BorderDim, 1)

    local palette = {
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(157, 48, 255),
        Color3.fromRGB(205, 104, 255), Color3.fromRGB(42, 255, 157),
        Color3.fromRGB(255, 75, 125), Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(0, 150, 255), Color3.fromRGB(72, 72, 72)
    }

    local popover = Instance.new("Frame")
    popover.Size = UDim2.fromOffset(170, 70)
    popover.Position = UDim2.new(1, -170, 1, 4)
    popover.BackgroundColor3 = THEME.Header
    popover.Visible = false
    popover.ZIndex = 90
    popover.Parent = preview
    corner(popover, 8)
    stroke(popover, THEME.Accent, 1)
    padding(popover, 6, 6, 6, 6)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(34, 26)
    grid.CellPadding = UDim2.fromOffset(4, 4)
    grid.Parent = popover

    local open = false
    local selectedColor = defaultColor
    local function apply(value)
        if typeof(value) ~= "Color3" then return end
        selectedColor = value
        preview.BackgroundColor3 = value
        _G.FireEvent(setting, value)
        if onChange then onChange(value) end
    end
    defaultColor = bindSetting(setting, defaultColor, apply, function(v) return typeof(v) == "Color3" end)
    apply(defaultColor)
    trackConnection(preview.MouseButton1Click:Connect(function()
        open = not open
        popover.Visible = open
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

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function() open = not open popover.Visible = open end,
        Adjust = function(direction)
            local index = table.find(palette, selectedColor) or 1
            apply(palette[(index - 1 + direction) % #palette + 1])
        end,
    })

    return row
end

local function createKeybind(parent, setting, defaultKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = setting
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextMuted
    lbl.Font = FONT
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(60, 22)
    btn.Position = UDim2.new(1, -60, 0.5, -11)
    btn.BackgroundColor3 = THEME.CardAlt
    btn.Text = defaultKey or "None"
    btn.TextColor3 = THEME.AccentBright
    btn.TextSize = 11
    btn.Font = FONT_BOLD
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    local listening = false
    local boundKey = defaultKey or "None"
    local boundInputType
    if defaultKey then
        -- Keyboard keys (V, X, Insert, etc.) are KeyCodes, not UserInputTypes.
        -- Only mouse buttons should be matched against UserInputType.
        for _, inputType in ipairs(Enum.UserInputType:GetEnumItems()) do
            if inputType.Name == defaultKey then
                boundInputType = inputType
                break
            end
        end
    end
    local actionKeybind = setting == "Xray" or setting == "Free Cam"
    local function apply(keyName)
        if type(keyName) ~= "string" or keyName == "" then return end
        boundKey = keyName
        boundInputType = nil
        for _, inputType in ipairs(Enum.UserInputType:GetEnumItems()) do
            if inputType.Name == keyName then boundInputType = inputType break end
        end
        btn.Text = keyName
        if _G.AtomwareConfig then _G.AtomwareConfig:Store(setting, keyName) end
        if not actionKeybind then _G.FireEvent(setting, keyName) end
        if _G.AtomwareConfig then _G.AtomwareConfig:Refresh() end
    end
    boundKey = bindSetting(setting, boundKey, apply, function(v) return type(v) == "string" and #v > 0 end)
    apply(boundKey)
    if _G.AtomwareConfig then _G.AtomwareConfig:RegisterKeybind(setting, function() return boundKey end) end
    trackConnection(btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        btn.TextColor3 = THEME.Red
    end))

    trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard
                or input.UserInputType == Enum.UserInputType.Gamepad1
                or input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2 then
                local isButtonInput = input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.MouseButton2
                local kName = isButtonInput and input.UserInputType.Name or input.KeyCode.Name
                listening = false
                btn.TextColor3 = THEME.AccentBright
                apply(kName)
            end
        elseif (not gpe or input.UserInputType == Enum.UserInputType.Gamepad1) and boundKey ~= "None"
            and (input.KeyCode.Name == boundKey or input.UserInputType == boundInputType) then
            _G.FireEvent(setting .. " Pressed")
        end
    end))

    table.insert(InteractiveElements, {
        Frame = row,
        Action = function() listening = true btn.Text = "..." btn.TextColor3 = THEME.Red end
    })

    return row
end

--//==================================================
--// BUILD TABS & SECTIONS
--//==================================================

local tabsData = {
    { Name = "Visuals",  Icon = "👁️" },
    { Name = "Combat",   Icon = "⚔️" },
    { Name = "Player",   Icon = "👤" },
    { Name = "Settings", Icon = "⚙️" },
}

for i, t in ipairs(tabsData) do
    local pName = t.Name
    createPage(pName)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = THEME.Card
    btn.Text = "  " .. t.Icon .. "  " .. pName
    btn.TextColor3 = THEME.TextMuted
    btn.TextSize = 12
    btn.Font = FONT_BOLD
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = Sidebar
    corner(btn, 6)
    stroke(btn, THEME.BorderDim, 1)

    TabButtons[pName] = btn
    trackConnection(btn.MouseButton1Click:Connect(function() switchPage(pName) end))
end

-- ---------------------------------------------------
-- TAB 1: VISUALS
-- ---------------------------------------------------
local pVisuals = Pages["Visuals"]

local _, bPlayerESP = createCard(pVisuals, "Player ESP")
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

local _, bChams = createCard(pVisuals, "Material Chams")
createToggle(bChams, "Enable Chams", false)
local chamsMaterialOptions = { "ForceField", "Neon", "Glass", "Ice", "Marble", "Foil", "Metal", "Wood" }
createDropdown(bChams, "Material", chamsMaterialOptions, "ForceField")
createColorPicker(bChams, "Chams Color", Color3.fromRGB(120, 200, 255))
createToggle(bChams, "See Through (Glow)", true)
createToggle(bChams, "Chams Team Check", false)

local _, bHat = createCard(pVisuals, "Chinese Hat ESP")
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
local pCombat = Pages["Combat"]

local _, bAimbot = createCard(pCombat, "Aimbot")
createToggle(bAimbot, "Enable Aimbot", false)
createToggle(bAimbot, "Aim Lock", false)
createDropdown(bAimbot, "Aim Type", { "Camera Aim", "Mouse/Touch Aim" }, "Camera Aim")
createDropdown(bAimbot, "Target Part", { "Head", "Torso", "HumanoidRootPart" }, "Head")
createSlider(bAimbot, "Smoothness", 1, 20, 5, 1, "")
createKeybind(bAimbot, "Aim Key", "MouseButton2")
createToggle(bAimbot, "Wall Check", false)
createToggle(bAimbot, "Aimbot Team Check", false)

local _, bFOV = createCard(pCombat, "FOV Circle")
createToggle(bFOV, "Show FOV Circle", false)
createSlider(bFOV, "FOV Radius", 30, 500, 120, 5, " px")
createColorPicker(bFOV, "FOV Color", Color3.fromRGB(157, 48, 255))
createToggle(bFOV, "Filled FOV", false)
createSlider(bFOV, "FOV Transparency", 0, 1, 0.2, 0.05, "")

local _, bHitbox = createCard(pCombat, "Hitbox Expander")
createToggle(bHitbox, "Enable Hitbox Expander", false)
createDropdown(bHitbox, "Hitbox Part", { "Head", "HumanoidRootPart" }, "Head")
createSlider(bHitbox, "Hitbox Size", 1.5, 20, 5, 0.5, " studs")
createSlider(bHitbox, "Hitbox Transparency", 0, 1, 0.6, 0.05, "")
createColorPicker(bHitbox, "Hitbox Color", Color3.fromRGB(157, 48, 255))
createDropdown(bHitbox, "Hitbox Material", { "ForceField", "Neon", "Glass", "SmoothPlastic" }, "ForceField")

-- ---------------------------------------------------
-- TAB 3: PLAYER
-- ---------------------------------------------------
local pPlayer = Pages["Player"]

local _, bMove = createCard(pPlayer, "Movement")
createToggle(bMove, "Speed Hack", false)
createSlider(bMove, "WalkSpeed", 16, 250, 32, 1, " studs/s")
createToggle(bMove, "Super Jump", false)
createSlider(bMove, "JumpPower", 50, 300, 100, 5, "")
createToggle(bMove, "Infinite Jump", false)
createToggle(bMove, "Bunny Hop", false)

local _, bFly = createCard(pPlayer, "Flight & Utility")
createToggle(bFly, "Fly", false)
createSlider(bFly, "Fly Speed", 10, 200, 50, 5, "")
createToggle(bFly, "Noclip", false)
createToggle(bFly, "FreeCam", false)
createSlider(bFly, "FreeCam Speed", 1, 50, 10, 1, "")

-- ---------------------------------------------------
-- TAB 4: SETTINGS
-- ---------------------------------------------------
local pSettings = Pages["Settings"]

-- Declare the toggle key variable before the InputBegan listener so the
-- keybind widget can update it at runtime.
local menuToggleKey = Enum.KeyCode.Insert

local _, bUISet = createCard(pSettings, "Menu Settings")
-- U3: pass the keybind name through OnKeybind so changing the key in the UI
--     actually updates menuToggleKey and takes effect immediately.
createKeybind(bUISet, "Toggle Menu Key", "Insert")
createToggle(bUISet, "Show Keybind List", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetKeybindListVisible(v) end
end)
createToggle(bUISet, "Show Watermark", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkVisible(v) end
end)
createToggle(bUISet, "Show FPS Counter", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetFPSCounterVisible(v) end
end)
createSlider(bUISet, "Aim Button Size", 36, 80, 54, 2, "px")
createDropdown(bUISet, "Aim Button Shape", { "Rounded", "Circle", "Square" }, "Rounded")
createColorPicker(bUISet, "Watermark Color", Color3.fromRGB(205, 104, 255), function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetWatermarkColor(v) end
end)
createDropdown(bUISet, "Notification Corner", { "TopRight", "TopLeft", "BottomRight", "BottomLeft" }, "TopRight", function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetNotificationCorner(v) end
end)
createToggle(bUISet, "Use Custom Cursor", false, function(v)
    if _G.AtomwareConfig then _G.AtomwareConfig:SetCustomCursorVisible(v) end
end)

local destBtn = Instance.new("TextButton")
destBtn.Size = UDim2.new(1, 0, 0, 36)
destBtn.BackgroundColor3 = Color3.fromRGB(70, 20, 35)
destBtn.Text = "Unload Atomware"
destBtn.TextColor3 = THEME.Red
destBtn.TextSize = 12
destBtn.Font = FONT_BOLD
destBtn.Parent = bUISet
corner(destBtn, 6)
trackConnection(destBtn.MouseButton1Click:Connect(function()
    if _G.AtomwareUnload then _G.AtomwareUnload() else ScreenGui:Destroy() end
end))

local _, bProfiles = createCard(pSettings, "Profiles")
local profileName = Instance.new("TextBox")
profileName.Size = UDim2.new(1, 0, 0, 30)
profileName.BackgroundColor3 = THEME.CardAlt
profileName.TextColor3 = THEME.Text
profileName.PlaceholderColor3 = THEME.TextDim
profileName.PlaceholderText = "Profile name"
profileName.Text = (_G.AtomwareConfig and _G.AtomwareConfig.Profile) or "Default"
profileName.ClearTextOnFocus = false
profileName.TextSize = 11
profileName.Font = FONT
profileName.Parent = bProfiles
corner(profileName, 6)

local function makeProfileButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 30)
    button.BackgroundColor3 = THEME.CardAlt
    button.Text = text
    button.TextColor3 = THEME.AccentBright
    button.TextSize = 11
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

-- Wire the "Toggle Menu Key" keybind so changing it in the UI updates menuToggleKey.
-- createKeybind fires AtomwareEvents with the KeyCode name string.
_G.OnKeybind("Toggle Menu Key", function(keyName)
    if Enum.KeyCode[keyName] then
        menuToggleKey = Enum.KeyCode[keyName]
    end
end)

--//==================================================
--// XBOX CONTROLLER ENGINE
--//==================================================

local focusedIndex = 1
local cursorHighlight = Instance.new("UIStroke")
cursorHighlight.Color = THEME.AccentBright
cursorHighlight.Thickness = 2
cursorHighlight.Enabled = false

local function getCurrentPageElements()
    local valid = {}
    for _, item in ipairs(InteractiveElements) do
        if item.Frame and item.Frame:IsDescendantOf(Pages[CurrentPageName]) and item.Frame.Visible then
            table.insert(valid, item)
        end
    end
    return valid
end

local function updateControllerNav()
    local valid = getCurrentPageElements()
    if #valid == 0 then return end
    focusedIndex = math.clamp(focusedIndex, 1, #valid)
    local cur = valid[focusedIndex]
    if cur and cur.Frame then
        cursorHighlight.Parent = cur.Frame
        cursorHighlight.Enabled = true
        local page = Pages[CurrentPageName]
        local rowTop = page.CanvasPosition.Y + cur.Frame.AbsolutePosition.Y - page.AbsolutePosition.Y
        local rowBottom = rowTop + cur.Frame.AbsoluteSize.Y
        local viewTop = page.CanvasPosition.Y
        local viewBottom = viewTop + page.AbsoluteSize.Y
        if rowTop < viewTop then
            page.CanvasPosition = Vector2.new(page.CanvasPosition.X, math.max(0, rowTop))
        elseif rowBottom > viewBottom then
            page.CanvasPosition = Vector2.new(page.CanvasPosition.X, math.max(0, rowBottom - page.AbsoluteSize.Y))
        end
    end
end

local function switchAdjacentPage(direction)
    local currentIndex = 1
    for index, tab in ipairs(tabsData) do
        if tab.Name == CurrentPageName then currentIndex = index break end
    end
    local nextIndex = (currentIndex - 1 + direction) % #tabsData + 1
    switchPage(tabsData[nextIndex].Name)
    focusedIndex = 1
    updateControllerNav()
end

trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe and input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end

    if input.UserInputType == Enum.UserInputType.Gamepad1 then
        if input.KeyCode == Enum.KeyCode.ButtonL1 then
            setUIVisible(not UIVisible)
        elseif input.KeyCode == Enum.KeyCode.DPadDown then
            focusedIndex = focusedIndex + 1
            updateControllerNav()
        elseif input.KeyCode == Enum.KeyCode.DPadUp then
            focusedIndex = math.max(1, focusedIndex - 1)
            updateControllerNav()
        elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.DPadLeft then
            local direction = input.KeyCode == Enum.KeyCode.DPadRight and 1 or -1
            local valid = getCurrentPageElements()
            local current = valid[focusedIndex]
            if current and current.Adjust then
                current.Adjust(direction)
                updateControllerNav()
            else
                switchAdjacentPage(direction)
            end
        elseif input.KeyCode == Enum.KeyCode.ButtonA then
            local valid = getCurrentPageElements()
            local cur = valid[focusedIndex]
            if cur and cur.Action then cur.Action() end
        end
    elseif input.KeyCode == menuToggleKey then
        setUIVisible(not UIVisible)
    end
end))
_G.AtomwareUILoaded = true
print("Good to go")
