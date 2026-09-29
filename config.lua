-- Shared settings, profile storage, and UI overlay helpers for Atomware.
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Environment = (type(getgenv) == "function" and getgenv()) or _G

local ROOT = "Atomware"
local PROFILE_DIR = ROOT .. "/Profiles"
local ACTIVE_FILE = PROFILE_DIR .. "/autoload.txt"

local Config = {
    Defaults = {},
    Values = {},
    Bindings = {},
    Keybinds = {},
    Connections = {},
    Tasks = {},
    Cleanup = {},
    Profile = nil,
    NotificationCorner = "TopRight",
    KeybindListVisible = false,
    WatermarkVisible = false,
    FPSCounterVisible = false,
    FPSCounter = nil,
    ActiveToasts = {},
    NotificationQueue = {},
    NotificationWorker = false,
    CustomCursorVisible = false,
    WatermarkColor = Color3.fromRGB(205, 104, 255),
    CursorWasEnabled = UserInputService.MouseIconEnabled,
    CursorEnabledBeforeCustom = nil,
}

local function supported(name)
    return type(Environment[name]) == "function"
end

local function decodeValue(value)
    if type(value) ~= "table" then return value end
    if value.__type == "Color3" then
        if type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number" then
            return Color3.new(math.clamp(value.r, 0, 1), math.clamp(value.g, 0, 1), math.clamp(value.b, 0, 1))
        end
        return nil
    end
    return value
end

local function encodeValue(value)
    if typeof(value) == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    end
    if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then return value end
    return nil
end

local function ensureProfileDirectory()
    if not (supported("writefile") and supported("makefolder")) then
        return false, "This executor does not expose profile file storage."
    end
    pcall(function() if not supported("isfolder") or not isfolder(ROOT) then makefolder(ROOT) end end)
    pcall(function() if not supported("isfolder") or not isfolder(PROFILE_DIR) then makefolder(PROFILE_DIR) end end)
    return true
end

local function cleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[^%w _%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #name < 1 or #name > 32 then return nil end
    return name
end

local function profilePath(name)
    local cleaned = cleanName(name)
    if not cleaned then return nil end
    return PROFILE_DIR .. "/" .. cleaned .. ".json"
end

local function validFor(name, value)
    local validator = Config.Bindings[name] and Config.Bindings[name].Validate
    if validator then
        local ok, valid = pcall(validator, value)
        return ok and valid == true
    end
    local default = Config.Defaults[name]
    return typeof(value) == typeof(default)
end

function Config:Register(name, default, apply, validate)
    Config.Defaults[name] = default
    Config.Bindings[name] = { Apply = apply, Validate = validate }
    local value
    if Config.LoadedValues then value = decodeValue(Config.LoadedValues[name]) end
    if value == nil or not validFor(name, value) then value = default end
    Config.Values[name] = value
    return value
end

function Config:Store(name, value)
    if Config.Defaults[name] == nil or not validFor(name, value) then return false end
    Config.Values[name] = value
    return true
end

function Config:Save(name)
    local path = profilePath(name)
    if not path then return false, "Use a profile name between 1 and 32 letters, numbers, spaces, _ or -." end
    local ready, err = ensureProfileDirectory()
    if not ready then return false, err end
    local values = {}
    for key, value in pairs(Config.Values) do
        local encoded = encodeValue(value)
        if encoded ~= nil then values[key] = encoded end
    end
    local ok, result = pcall(function()
        writefile(path, HttpService:JSONEncode({ version = 1, values = values }))
    end)
    if not ok then return false, tostring(result) end
    Config.Profile = cleanName(name)
    return true
end

function Config:Load(name)
    local path = profilePath(name)
    if not path then return false, "Invalid profile name." end
    if not (supported("readfile") and supported("isfile")) then
        return false, "This executor does not expose profile file storage."
    end
    local ok, decoded = pcall(function()
        if not isfile(path) then error("Profile not found: " .. cleanName(name)) end
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(decoded) ~= "table" or type(decoded.values) ~= "table" then
        return false, ok and "The profile file is invalid." or tostring(decoded)
    end

    Config.Profile = cleanName(name)
    for key, binding in pairs(Config.Bindings) do
        local value = decodeValue(decoded.values[key])
        if value ~= nil and validFor(key, value) then
            Config.Values[key] = value
            if binding.Apply then
                local applyOk, applyErr = pcall(binding.Apply, value)
                if not applyOk then warn("Atomware: could not apply profile setting " .. key .. ": " .. tostring(applyErr)) end
            end
        end
    end
    return true
end

function Config:SetAutoload(name)
    local cleaned = cleanName(name)
    if not cleaned then return false, "Invalid profile name." end
    local ready, err = ensureProfileDirectory()
    if not ready then return false, err end
    local ok, result = pcall(function() writefile(ACTIVE_FILE, cleaned) end)
    if not ok then return false, tostring(result) end
    Config.Profile = cleaned
    return true
end

if supported("readfile") and supported("isfile") then
    pcall(function()
        if isfile(ACTIVE_FILE) then
            local name = cleanName(readfile(ACTIVE_FILE))
            if name then
                local path = profilePath(name)
                if path and isfile(path) then
                    local data = HttpService:JSONDecode(readfile(path))
                    if type(data) == "table" and type(data.values) == "table" then
                        Config.LoadedValues = data.values
                        Config.Profile = name
                    end
                end
            end
        end
    end)
end

function Config:TrackConnection(connection)
    if _G.AtomwareCleanup and _G.AtomwareCleanup.TrackConnection then
        return _G.AtomwareCleanup:TrackConnection(connection)
    end
    if connection then table.insert(Config.Connections, connection) end
    return connection
end

function Config:TrackTask(thread)
    if _G.AtomwareCleanup and _G.AtomwareCleanup.TrackTask then
        return _G.AtomwareCleanup:TrackTask(thread)
    end
    if thread then table.insert(Config.Tasks, thread) end
    return thread
end

function Config:RegisterKeybind(name, getValue)
    Config.Keybinds[name] = getValue
    if Config.Refresh then Config:Refresh() end
end

function Config:AttachUI(screenGui, deviceName)
    Config.ScreenGui = screenGui
    Config.DeviceName = deviceName

    local watermark = Instance.new("TextLabel")
    watermark.Name = "AtomwareWatermark"
    watermark.AnchorPoint = Vector2.new(1, 0)
    watermark.Position = UDim2.new(1, -12, 0, 12)
    watermark.Size = deviceName == "Mobile" and UDim2.new(1, -24, 0, 30) or UDim2.fromOffset(210, 28)
    watermark.BackgroundColor3 = Color3.fromRGB(10, 7, 20)
    watermark.BackgroundTransparency = 0.15
    watermark.TextColor3 = Config.WatermarkColor
    watermark.Text = "atomware v2  •  " .. deviceName
    watermark.TextSize = deviceName == "Mobile" and 14 or 13
    watermark.Font = Enum.Font.GothamBold
    watermark.Visible = Config.WatermarkVisible
    watermark.Parent = screenGui
    if deviceName == "Mobile" then
        local watermarkConstraint = Instance.new("UISizeConstraint")
        watermarkConstraint.MinSize = Vector2.new(120, 30)
        watermarkConstraint.MaxSize = Vector2.new(210, 30)
        watermarkConstraint.Parent = watermark
    end
    local watermarkCorner = Instance.new("UICorner")
    watermarkCorner.CornerRadius = UDim.new(0, 7)
    watermarkCorner.Parent = watermark
    Config.Watermark = watermark

    local fpsCounter = Instance.new("TextLabel")
    fpsCounter.Name = "AtomwareFPSCounter"
    fpsCounter.AnchorPoint = Vector2.new(0, 0)
    fpsCounter.Position = UDim2.new(0, 12, 0, 12)
    fpsCounter.Size = deviceName == "Mobile" and UDim2.new(1, -24, 0, 30) or UDim2.fromOffset(174, 26)
    fpsCounter.BackgroundColor3 = Color3.fromRGB(10, 7, 20)
    fpsCounter.BackgroundTransparency = 0.15
    fpsCounter.TextColor3 = Config.WatermarkColor
    fpsCounter.Text = "FPS: --"
    fpsCounter.TextSize = deviceName == "Mobile" and 13 or 12
    fpsCounter.Font = Enum.Font.GothamBold
    fpsCounter.Visible = Config.FPSCounterVisible
    fpsCounter.Parent = screenGui
    if deviceName == "Mobile" then
        local fpsConstraint = Instance.new("UISizeConstraint")
        fpsConstraint.MinSize = Vector2.new(120, 30)
        fpsConstraint.MaxSize = Vector2.new(174, 30)
        fpsConstraint.Parent = fpsCounter
    end
    local fpsCorner = Instance.new("UICorner")
    fpsCorner.CornerRadius = UDim.new(0, 7)
    fpsCorner.Parent = fpsCounter
    Config.FPSCounter = fpsCounter
    local elapsed, frames, statsElapsed, memoryText = 0, 0, 0, ""
    Config:TrackConnection(game:GetService("RunService").RenderStepped:Connect(function(dt)
        if not fpsCounter.Visible then
            elapsed, frames, statsElapsed, memoryText = 0, 0, 0, ""
            return
        end
        frames = frames + 1
        elapsed = elapsed + dt
        statsElapsed = statsElapsed + dt
        if elapsed >= 1 then
            local fps = math.floor(frames / elapsed + 0.5)
            if statsElapsed >= 2 then
                statsElapsed = 0
                local ok, memoryMb = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)
                if ok and type(memoryMb) == "number" then memoryText = "  •  " .. tostring(math.floor(memoryMb + 0.5)) .. " MB" end
            end
            fpsCounter.Text = "FPS: " .. tostring(fps) .. memoryText
            frames, elapsed = 0, 0
        end
    end))

    local keybindPanel = Instance.new("Frame")
    keybindPanel.Name = "AtomwareKeybindList"
    keybindPanel.AnchorPoint = Vector2.new(1, 0)
    keybindPanel.Position = UDim2.new(1, -12, 0, 48)
    keybindPanel.Size = UDim2.fromOffset(190, 30)
    keybindPanel.BackgroundColor3 = Color3.fromRGB(10, 7, 20)
    keybindPanel.BackgroundTransparency = 0.15
    keybindPanel.Visible = Config.KeybindListVisible
    keybindPanel.Parent = screenGui
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 7)
    panelCorner.Parent = keybindPanel
    local panelPadding = Instance.new("UIPadding")
    panelPadding.PaddingLeft = UDim.new(0, 10)
    panelPadding.PaddingRight = UDim.new(0, 10)
    panelPadding.PaddingTop = UDim.new(0, 7)
    panelPadding.Parent = keybindPanel
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = keybindPanel
    Config.KeybindPanel = keybindPanel

    local customCursor = Instance.new("Frame")
    customCursor.Name = "AtomwareCustomCursor"
    customCursor.AnchorPoint = Vector2.new(0.5, 0.5)
    customCursor.Size = UDim2.fromOffset(8, 8)
    customCursor.BackgroundColor3 = Config.WatermarkColor
    customCursor.BorderSizePixel = 0
    customCursor.Visible = Config.CustomCursorVisible
    customCursor.ZIndex = 200
    customCursor.Parent = screenGui
    local cursorCorner = Instance.new("UICorner")
    cursorCorner.CornerRadius = UDim.new(1, 0)
    cursorCorner.Parent = customCursor
    Config.CustomCursor = customCursor
    Config:TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if Config.CustomCursorVisible and input.UserInputType == Enum.UserInputType.MouseMovement then
            customCursor.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
        end
    end))
    Config:Refresh()
end

function Config:Refresh()
    if Config.Watermark then
        Config.Watermark.Visible = Config.WatermarkVisible
        Config.Watermark.TextColor3 = Config.WatermarkColor
    end
    if Config.CustomCursor then
        Config.CustomCursor.Visible = Config.CustomCursorVisible
        Config.CustomCursor.BackgroundColor3 = Config.WatermarkColor
    end
    if Config.FPSCounter then
        Config.FPSCounter.Visible = Config.FPSCounterVisible
        Config.FPSCounter.TextColor3 = Config.WatermarkColor
    end
    if not Config.KeybindPanel then return end
    Config.KeybindPanel.Visible = Config.KeybindListVisible
    for _, child in ipairs(Config.KeybindPanel:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local names = {}
    for name in pairs(Config.Keybinds) do table.insert(names, name) end
    table.sort(names)
    local count = 0
    for _, name in ipairs(names) do
        local value = Config.Keybinds[name]()
        if type(value) == "string" and value ~= "None" then
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 0, 16)
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 11
            label.TextColor3 = Config.WatermarkColor
            label.Text = name .. "  •  " .. value
            label.Parent = Config.KeybindPanel
            count = count + 1
        end
    end
    Config.KeybindPanel.Size = UDim2.fromOffset(190, math.max(30, 14 + count * 20))
end

function Config:SetKeybindListVisible(value)
    Config.KeybindListVisible = value == true
    Config:Refresh()
end

function Config:SetWatermarkVisible(value)
    Config.WatermarkVisible = value == true
    Config:Refresh()
end

function Config:SetFPSCounterVisible(value)
    Config.FPSCounterVisible = value == true
    Config:Refresh()
end

function Config:SetWatermarkColor(value)
    if typeof(value) ~= "Color3" then return end
    Config.WatermarkColor = value
    Config:Refresh()
end

function Config:SetCustomCursorVisible(value)
    value = value == true
    if value and not Config.CustomCursorVisible then
        Config.CursorEnabledBeforeCustom = UserInputService.MouseIconEnabled
    elseif not value and Config.CustomCursorVisible and Config.CursorEnabledBeforeCustom ~= nil then
        UserInputService.MouseIconEnabled = Config.CursorEnabledBeforeCustom
        Config.CursorEnabledBeforeCustom = nil
    end
    Config.CustomCursorVisible = value
    if value then UserInputService.MouseIconEnabled = false end
    Config:Refresh()
end

function Config:SetNotificationCorner(value)
    if table.find({ "TopRight", "TopLeft", "BottomRight", "BottomLeft" }, value) then
        Config.NotificationCorner = value
    end
end

function Config:Notify(message, duration)
    if not Config.ScreenGui or Config.Unloaded then return end
    if #Config.NotificationQueue >= 20 then table.remove(Config.NotificationQueue, 1) end
    table.insert(Config.NotificationQueue, {
        Message = tostring(message),
        Duration = math.clamp(tonumber(duration) or 3, 1, 10),
    })
    if Config.NotificationWorker then return end
    Config.NotificationWorker = true
    Config:TrackTask(task.spawn(function()
        while #Config.NotificationQueue > 0 and Config.ScreenGui and not Config.Unloaded do
            local item = table.remove(Config.NotificationQueue, 1)
            local top = Config.NotificationCorner:sub(1, 3) == "Top"
            local left = Config.NotificationCorner:sub(-4) == "Left"
            local toast = Instance.new("TextLabel")
            toast.Name = "AtomwareNotification"
            toast.BackgroundColor3 = Color3.fromRGB(10, 7, 20)
            toast.BackgroundTransparency = 0.08
            toast.TextColor3 = Color3.fromRGB(245, 241, 255)
            toast.TextWrapped = true
            toast.Text = item.Message
            local isMobile = Config.DeviceName == "Mobile"
            toast.TextSize = isMobile and 14 or 12
            toast.Font = Enum.Font.GothamMedium
            toast.AnchorPoint = Vector2.new(left and 0 or 1, top and 0 or 1)
            toast.Position = UDim2.new(left and 0 or 1, left and 12 or -12, top and 0 or 1, top and 12 or -12)
            local screenWidth = Config.ScreenGui.AbsoluteSize.X
            local toastWidth = isMobile and math.max(1, math.min(300, screenWidth - 24)) or 230
            toast.Size = UDim2.fromOffset(toastWidth, isMobile and 76 or 42)
            toast.ZIndex = 120
            toast.Parent = Config.ScreenGui
            local toastPadding = Instance.new("UIPadding")
            toastPadding.PaddingLeft = UDim.new(0, 10)
            toastPadding.PaddingRight = UDim.new(0, 10)
            toastPadding.Parent = toast
            local toastCorner = Instance.new("UICorner")
            toastCorner.CornerRadius = UDim.new(0, 7)
            toastCorner.Parent = toast
            table.insert(Config.ActiveToasts, toast)
            task.wait(item.Duration)
            for index, activeToast in ipairs(Config.ActiveToasts) do
                if activeToast == toast then table.remove(Config.ActiveToasts, index) break end
            end
            if toast.Parent then toast:Destroy() end
        end
        Config.NotificationWorker = false
    end))
end

function Config:OnUnload(callback)
    if _G.AtomwareCleanup and _G.AtomwareCleanup.TrackRestore then
        _G.AtomwareCleanup:TrackRestore(callback)
    elseif type(callback) == "function" then
        table.insert(Config.Cleanup, callback)
    end
end

function Config:Unload(screenGui)
    if Config.Unloaded then return end
    Config.Unloaded = true
    screenGui = screenGui or Config.ScreenGui
    table.clear(Config.NotificationQueue)
    for _, toast in ipairs(Config.ActiveToasts) do pcall(function() toast:Destroy() end) end
    table.clear(Config.ActiveToasts)
    -- Turn off active boolean features while their callbacks are still live.
    for name, default in pairs(Config.Defaults) do
        if type(default) == "boolean" then
            local callback = _G.AtomwareEvents and _G.AtomwareEvents[name]
            if callback then pcall(callback, false) end
        end
    end
    _G.AtomwareForceHeadshots = false
    local cleanup = _G.AtomwareCleanup
    if cleanup and type(cleanup.Run) == "function" then
        cleanup:Run(Config)
    else
        for _, connection in ipairs(Config.Connections) do pcall(function() connection:Disconnect() end) end
        Config.Connections = {}
        for _, thread in ipairs(Config.Tasks) do pcall(task.cancel, thread) end
        Config.Tasks = {}
        for _, callback in ipairs(Config.Cleanup) do pcall(callback) end
        Config.Cleanup = {}
    end
    local cursorEnabled = Config.CursorWasEnabled
    if Config.CursorEnabledBeforeCustom ~= nil then
        cursorEnabled = Config.CursorEnabledBeforeCustom
    end
    UserInputService.MouseIconEnabled = cursorEnabled
    if screenGui then pcall(function() screenGui:Destroy() end) end
    Config.ScreenGui = nil
    Config.Watermark = nil
    Config.KeybindPanel = nil
    Config.CustomCursor = nil
    Config.FPSCounter = nil
    _G.AtomwareUILoaded = false
    _G.AtomwareFeaturesLoaded = false
    _G.AtomwareEvents = nil
    _G.AtomwarePendingEvents = nil
    _G.OnToggle, _G.OnSlider, _G.OnDropdown, _G.OnColorPicker, _G.OnKeybind, _G.FireEvent = nil, nil, nil, nil, nil, nil
    _G.AtomwareConfig = nil
    _G.AtomwareCleanup = nil
    _G.AtomwareUnload = nil
end

_G.AtomwareConfig = Config
return Config
