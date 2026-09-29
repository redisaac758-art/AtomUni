--[[
    init.lua
    Universal Master Initializer for Atomware
    Shared between Trident Survival and Universal Script.

    Automatically detects whether the executing bundle is Trident Survival or Universal Script,
    enforces game-specific compatibility rules, detects platform (PC vs Mobile),
    and initializes the dedicated UI + backend.
]]

-- ──────────────────────────────────────────────────────────────────────────
-- GAME DETECTION & RULES
-- ──────────────────────────────────────────────────────────────────────────
local TRIDENT_PLACE_IDS = {
    [1325373543] = true,
    [12397460233901] = true,
}

local function isTridentSurvival()
    return TRIDENT_PLACE_IDS[game.PlaceId] == true or TRIDENT_PLACE_IDS[game.GameId] == true
end

local SCRIPT_SOURCES = _G.AtomwareScriptSources or {}

-- Determine which script bundle is executing
local isUniversal = false
local isTrident = false

if SCRIPT_SOURCES["UniversalModules/main_ui.lua"] or SCRIPT_SOURCES["UniversalModules/config.lua"] then
    isUniversal = true
elseif SCRIPT_SOURCES["TridentSurvivalMoudle's/main_ui.lua"] or SCRIPT_SOURCES["TridentSurvivalMoudle's/config.lua"] then
    isTrident = true
elseif _G.AtomwareScriptMode == "Universal" then
    isUniversal = true
elseif _G.AtomwareScriptMode == "Trident" then
    isTrident = true
else
    -- Fallback: if in Trident Survival and Trident files exist, use Trident; otherwise Universal.
    if isTridentSurvival() and SCRIPT_SOURCES["TridentSurvivalMoudle's/init.lua"] then
        isTrident = true
    else
        isUniversal = true
    end
end

-- Compatibility enforcement
local rejectReason = nil

if isUniversal then
    if isTridentSurvival() then
        rejectReason = "The game is not supported universally and you should Use our script which we have made for that game."
    end
elseif isTrident then
    if not isTridentSurvival() then
        rejectReason = "Atomware does not support the game you're in."
    end
end

if rejectReason then
    -- Clean up any existing Atomware session
    if _G.AtomwareUnload and (_G.AtomwareUILoaded or _G.AtomwareFeaturesLoaded) then
        pcall(_G.AtomwareUnload)
    end

    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, name in ipairs({ "AtomwareUI", "AtomwareMobileUI" }) do
                local existing = playerGui:FindFirstChild(name)
                if existing then existing:Destroy() end
            end
        end
    end)

    -- Display dismissal notice
    local parent = nil
    pcall(function()
        if type(gethui) == "function" then
            parent = gethui()
        else
            local player = game:GetService("Players").LocalPlayer
            parent = player and player:FindFirstChildOfClass("PlayerGui")
        end
    end)

    if parent then
        pcall(function()
            local existing = parent:FindFirstChild("AtomwareUnsupportedNotice")
            if existing then existing:Destroy() end

            local screen = Instance.new("ScreenGui")
            screen.Name = "AtomwareUnsupportedNotice"
            screen.ResetOnSpawn = false
            screen.IgnoreGuiInset = true
            screen.DisplayOrder = 10000

            local message = Instance.new("TextLabel")
            message.Name = "Message"
            message.AnchorPoint = Vector2.new(0.5, 0.5)
            message.Position = UDim2.fromScale(0.5, 0.5)
            message.Size = UDim2.new(0.85, 0, 0, 72)
            message.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
            message.BackgroundTransparency = 0
            message.BorderSizePixel = 0
            message.Text = rejectReason
            message.TextColor3 = Color3.fromRGB(245, 241, 255)
            message.TextSize = 15
            message.TextWrapped = true
            message.Font = Enum.Font.GothamMedium
            message.Parent = screen

            local sizeLimit = Instance.new("UISizeConstraint")
            sizeLimit.MinSize = Vector2.new(280, 72)
            sizeLimit.MaxSize = Vector2.new(500, 96)
            sizeLimit.Parent = message

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 10)
            corner.Parent = message

            local accent = Instance.new("Frame")
            accent.Size = UDim2.new(1, 0, 0, 3)
            accent.Position = UDim2.fromScale(0, 0)
            accent.BackgroundColor3 = Color3.fromRGB(157, 48, 255)
            accent.BorderSizePixel = 0
            accent.ZIndex = 2
            accent.Parent = message

            local accentCorner = Instance.new("UICorner")
            accentCorner.CornerRadius = UDim.new(0, 10)
            accentCorner.Parent = accent

            screen.Parent = parent
            task.delay(4, function()
                if screen.Parent then screen:Destroy() end
            end)
        end)
    end
    return
end

-- ──────────────────────────────────────────────────────────────────────────
-- RUNTIME INITIALIZATION
-- ──────────────────────────────────────────────────────────────────────────
local UserInputService = game:GetService("UserInputService")

-- Resolve module root folder
local MODULE_ROOT = isUniversal and "UniversalModules/" or "TridentSurvivalMoudle's/"
if not SCRIPT_SOURCES[MODULE_ROOT .. "config.lua"] and SCRIPT_SOURCES["config.lua"] then
    MODULE_ROOT = ""
end

-- If the initializer is run again, unload the previous UI/backend first
if _G.AtomwareUnload and (_G.AtomwareUILoaded or _G.AtomwareFeaturesLoaded) then
    pcall(_G.AtomwareUnload)
end

-- Platform Detection
-- TouchEnabled alone is the correct signal for mobile/tablet
local IS_MOBILE = UserInputService.TouchEnabled
local targetUIFile = MODULE_ROOT .. (IS_MOBILE and "mobile_ui.lua" or "main_ui.lua")

local function loadRemote(path)
    local source = SCRIPT_SOURCES[path]

    -- Fallback 1: Direct path in SCRIPT_SOURCES without MODULE_ROOT prefix
    if not source and MODULE_ROOT ~= "" then
        local stripped = path:gsub("^" .. MODULE_ROOT, "")
        source = SCRIPT_SOURCES[stripped]
    end

    -- Fallback 2: Local executor file testing (readfile)
    if not source and type(readfile) == "function" then
        local localCandidates = {
            path,
            path:gsub("^" .. MODULE_ROOT, ""),
            "UniversalModules/" .. path:gsub("^" .. MODULE_ROOT, ""),
        }
        for _, candidate in ipairs(localCandidates) do
            local ok, content = pcall(readfile, candidate)
            if ok and type(content) == "string" and #content > 0 then
                source = content
                break
            end
        end
    end

    -- Fallback 3: GitHub remote repository testing (game:HttpGet)
    if not source and game and type(game.HttpGet) == "function" then
        local cleanPath = path:gsub("^" .. MODULE_ROOT, "")
        local rawUrl = "https://raw.githubusercontent.com/redisaac758-art/AtomUni/main/" .. cleanPath
        local ok, content = pcall(function() return game:HttpGet(rawUrl) end)
        if ok and type(content) == "string" and #content > 0 then
            source = content
        end
    end

    if type(source) ~= "string" then
        warn("Atomware: module was not found in bundle, local files, or GitHub: " .. tostring(path))
        return false
    end

    local compileOk, chunk, compileErr = pcall(loadstring, source)
    if not compileOk or not chunk then
        warn("Atomware: failed to compile " .. tostring(path) .. ":", compileErr or chunk)
        return false
    end

    local runOk, runErr = pcall(chunk)
    if not runOk then
        warn("Atomware: failed to run " .. tostring(path) .. ":", runErr)
        return false
    end
    return true
end

-- 1. Load shared configuration and cleanup manager
if not loadRemote(MODULE_ROOT .. "config.lua") then
    warn("Atomware: shared configuration could not be loaded; startup aborted.")
    return
end
if not loadRemote(MODULE_ROOT .. "cleanup.lua") then
    warn("Atomware: cleanup manager could not be loaded; startup aborted.")
    return
end

_G.AtomwareUnload = function()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    local gui = playerGui and (
        playerGui:FindFirstChild("AtomwareUI") or
        playerGui:FindFirstChild("AtomwareMobileUI")
    )
    if _G.AtomwareConfig then
        _G.AtomwareConfig:Unload(gui)
    elseif gui then
        gui:Destroy()
    end
end

-- 2. Load Targeted Platform UI
if not loadRemote(targetUIFile) then
    if _G.AtomwareUnload then pcall(_G.AtomwareUnload) end
    return
end

-- 3. Wait for UI hooks to initialize (timeout after 15s)
local uiWaitCount = 0
repeat
    task.wait()
    uiWaitCount = uiWaitCount + 1
    if uiWaitCount > 900 then
        warn("Atomware: UI failed to initialise after 15s - aborting.")
        if _G.AtomwareUnload then pcall(_G.AtomwareUnload) end
        return
    end
until _G.AtomwareUILoaded and _G.AtomwareEvents and _G.OnToggle

-- 4. Load Features Engine (if present in bundle)
if not _G.AtomwareFeaturesLoaded then
    local featuresPath = MODULE_ROOT .. "features.lua"
    if SCRIPT_SOURCES[featuresPath] then
        if not loadRemote(featuresPath) then
            warn("Atomware: feature backend could not be loaded; cleaning up startup.")
            if _G.AtomwareUnload then pcall(_G.AtomwareUnload) end
            return
        end
    else
        -- No features.lua yet in this bundle (expected for initial universal setup)
        _G.AtomwareFeaturesLoaded = true
    end
end

-- 5. Verify everything is online (timeout after 15s)
local verifyCount = 0
repeat
    task.wait()
    verifyCount = verifyCount + 1
    if verifyCount > 900 then
        warn("Atomware: Features failed to mark loaded after 15s.")
        if _G.AtomwareUnload then pcall(_G.AtomwareUnload) end
        break
    end
until _G.AtomwareUILoaded and _G.AtomwareFeaturesLoaded

-- 6. Confirmation Print
local scriptLabel = isUniversal and "Universal" or "Trident Survival"
print("Atomware (" .. scriptLabel .. "): Fully initialized")
