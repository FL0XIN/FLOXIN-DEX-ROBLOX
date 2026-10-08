--[[ DEX V FLOXIN · Version Chooser v3
     Session tracking + Back to Run button ]]

local REPO = "https://raw.githubusercontent.com/FL0XIN/FLOXIN-DEX-ROBLOX/"
local SESSIONS_FILE = "floxin_sessions.json"
local HttpSvc = game:GetService("HttpService")

-- ═══════════════════════════════════════════════════════
-- SESSION HELPERS
-- ═══════════════════════════════════════════════════════
local function genSessionId()
    local d = os.date("*t")
    local date = string.format("%04d%02d%02d", d.year, d.month, d.day)
    local r = string.format("%04x", math.random(0, 0xFFFF))
    return "FLX-"..date.."-"..r
end

local function loadSessions()
    if not (isfile and readfile) then return {current = nil, history = {}} end
    if not isfile(SESSIONS_FILE) then return {current = nil, history = {}} end
    local ok, data = pcall(readfile, SESSIONS_FILE)
    if not ok or not data or #data == 0 then return {current = nil, history = {}} end
    local ok2, dec = pcall(function() return HttpSvc:JSONDecode(data) end)
    if not ok2 or not dec then return {current = nil, history = {}} end
    dec.current = dec.current or nil
    dec.history = dec.history or {}
    return dec
end

local function saveSessions(data)
    if not writefile then return false end
    return pcall(function()
        writefile(SESSIONS_FILE, HttpSvc:JSONEncode(data))
    end)
end

-- Prep session
local sessionsData = loadSessions()

-- Previous session never closed -> mark as crashed
if sessionsData.current and not sessionsData.current.ended then
    sessionsData.current.ended = os.time()
    sessionsData.current.crashed = true
    sessionsData.current.status = "crashed"
    table.insert(sessionsData.history, sessionsData.current)
    sessionsData.current = nil
end

-- New session
local SESSION = {
    id = genSessionId(),
    started = os.time(),
    hash = nil,
    version = nil,
    status = "open",
}
sessionsData.current = SESSION
saveSessions(sessionsData)

-- Expose
_G.FLOXIN = _G.FLOXIN or {}
_G.FLOXIN_SESSION = SESSION
_G.FLOXIN.session = SESSION
_G.FLOXIN.saveSession = function()
    saveSessions(sessionsData)
end

print("[FLOXIN] session: "..SESSION.id)

-- ═══════════════════════════════════════════════════════
-- BUILDS
-- ═══════════════════════════════════════════════════════
local VERSIONS = {
    {
        name = "Standard",
        hash = "993a57d",
        size = "672 KB",
        features = "All modules · Explorer, Browser, Editor, Dev Scripts, Players, Model Editor · Material Icons · Mobile KB",
        target = "PC · High-end mobile · Recommended",
    },
    {
        name = "Lite",
        hash = "0696e98",
        size = "537 KB",
        features = "Core tools · Explorer, Properties, Console, Notepad, SaveInstance, 3D Viewer, Bulk Copier",
        target = "Mid-tier mobile",
    },
    {
        name = "Minimal",
        hash = "de9d588",
        size = "537 KB",
        features = "Base Dex only",
        target = "Low-end mobile",
    },
}

-- ═══════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════
local CoreGui = game:GetService("CoreGui")
local parent = (gethui and select(2, pcall(gethui))) or CoreGui

local T = {
    bg      = Color3.fromRGB(45,45,45),
    panel   = Color3.fromRGB(52,52,52),
    panel2  = Color3.fromRGB(60,60,60),
    text    = Color3.fromRGB(230,230,230),
    sub     = Color3.fromRGB(150,150,150),
    accent  = Color3.fromRGB(11,90,175),
    ok      = Color3.fromRGB(60,140,80),
    err     = Color3.fromRGB(180,50,50),
    outline = Color3.fromRGB(33,33,33),
}

local gui = Instance.new("ScreenGui")
gui.Name = "FLOXIN_Chooser"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = parent

local vp = workspace.CurrentCamera.ViewportSize
local isM = game:GetService("UserInputService").TouchEnabled
local W = isM and math.clamp(math.floor(vp.X*0.92), 280, 360) or 400
local H = isM and math.clamp(math.floor(vp.Y*0.68), 340, 500) or 460

local win = Instance.new("Frame", gui)
win.Size = UDim2.new(0, W, 0, H)
win.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
win.BackgroundColor3 = T.bg
win.BorderSizePixel = 0
win.Draggable = true
win.Active = true
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", win)
title.Size = UDim2.new(1, -50, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "DEX V FLOXIN · Choose Build"
title.TextColor3 = T.text
title.Font = Enum.Font.SourceSansBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", win)
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -30, 0, 6)
closeBtn.BackgroundColor3 = T.panel2
closeBtn.Text = "X"
closeBtn.TextColor3 = T.text
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.MouseButton1Click:Connect(function()
    if SESSION and not SESSION.ended then
        SESSION.ended = os.time()
        SESSION.status = "closed_without_run"
        sessionsData.current = nil
        table.insert(sessionsData.history, SESSION)
        saveSessions(sessionsData)
    end
    gui:Destroy()
end)

local sidLbl = Instance.new("TextLabel", win)
sidLbl.Size = UDim2.new(1, -20, 0, 14)
sidLbl.Position = UDim2.new(0, 10, 0, 30)
sidLbl.BackgroundTransparency = 1
sidLbl.Text = "Session: "..SESSION.id
sidLbl.TextColor3 = T.sub
sidLbl.Font = Enum.Font.Code
sidLbl.TextSize = 10
sidLbl.TextXAlignment = Enum.TextXAlignment.Left

local sub = Instance.new("TextLabel", win)
sub.Size = UDim2.new(1, -20, 0, 14)
sub.Position = UDim2.new(0, 10, 0, 44)
sub.BackgroundTransparency = 1
sub.Text = "Select a build matching your device performance"
sub.TextColor3 = T.sub
sub.Font = Enum.Font.SourceSans
sub.TextSize = 11
sub.TextXAlignment = Enum.TextXAlignment.Left

local scroll = Instance.new("ScrollingFrame", win)
scroll.Size = UDim2.new(1, -16, 1, -96)
scroll.Position = UDim2.new(0, 8, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = T.outline
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local lay = Instance.new("UIListLayout", scroll)
lay.Padding = UDim.new(0, 8)
lay.SortOrder = Enum.SortOrder.LayoutOrder

local status = Instance.new("TextLabel", win)
status.Size = UDim2.new(1, -20, 0, 20)
status.Position = UDim2.new(0, 10, 1, -26)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = T.sub
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd

local function setStatus(text, color)
    status.Text = text or ""
    status.TextColor3 = color or T.sub
end

-- ═══════════════════════════════════════════════════════
-- BACK TO RUN BUTTON INJECTION
-- ═══════════════════════════════════════════════════════
local function findDexGui()
    local containers = {
        game:GetService("CoreGui"),
    }
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then table.insert(containers, 1, h) end
    end
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(containers, pg) end

    for _, cont in ipairs(containers) do
        if cont then
            for _, g in ipairs(cont:GetChildren()) do
                if g:IsA("ScreenGui") and g.Name == "MainMenu" then
                    return g
                end
            end
        end
    end
    -- fallback: search for OpenButton child
    for _, cont in ipairs(containers) do
        if cont then
            for _, g in ipairs(cont:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= gui and g:FindFirstChild("OpenButton", true) then
                    return g
                end
            end
        end
    end
end

local function injectBackButton()
    local tries = 0
    local dexGui
    while tries < 20 do
        dexGui = findDexGui()
        if dexGui then break end
        task.wait(0.5)
        tries = tries + 1
    end
    if not dexGui then
        warn("[FLOXIN] could not find Dex GUI for injection")
        return
    end

    local openButton = dexGui:FindFirstChild("OpenButton", true)
    if not openButton then
        warn("[FLOXIN] no OpenButton")
        return
    end
    local mainFrame = openButton:FindFirstChild("MainFrame")
    local bottomFrame = mainFrame and mainFrame:FindFirstChild("BottomFrame")
    if not bottomFrame then
        warn("[FLOXIN] no BottomFrame")
        return
    end

    -- Back button
    local backBtn = Instance.new("TextButton", bottomFrame)
    backBtn.Name = "FLOXIN_BackToRun"
    backBtn.Size = UDim2.new(0, 60, 1, 0)
    backBtn.Position = UDim2.new(0, 2, 0, 0)
    backBtn.BackgroundTransparency = 1
    backBtn.Text = "↩ Run"
    backBtn.TextColor3 = Color3.fromRGB(220,220,220)
    backBtn.Font = Enum.Font.SourceSansBold
    backBtn.TextSize = 12
    backBtn.BorderSizePixel = 0
    backBtn.AutoButtonColor = false

    -- Session label
    local sidShort = SESSION.id:match("FLX%-%d+%-(%w+)$") or "?"
    local sidLbl2 = Instance.new("TextLabel", bottomFrame)
    sidLbl2.Name = "FLOXIN_SessionLabel"
    sidLbl2.Size = UDim2.new(0, 90, 1, 0)
    sidLbl2.Position = UDim2.new(0, 64, 0, 0)
    sidLbl2.BackgroundTransparency = 1
    sidLbl2.Text = "FLX-"..sidShort
    sidLbl2.TextColor3 = Color3.fromRGB(140,140,140)
    sidLbl2.Font = Enum.Font.Code
    sidLbl2.TextSize = 10
    sidLbl2.TextXAlignment = Enum.TextXAlignment.Left

    backBtn.MouseButton1Click:Connect(function()
        -- close session
        SESSION.ended = os.time()
        SESSION.status = "closed_by_user"
        sessionsData.current = nil
        table.insert(sessionsData.history, SESSION)
        saveSessions(sessionsData)

        -- destroy Dex GUI
        pcall(function() dexGui:Destroy() end)

        -- wait for file write + destruction
        task.wait(0.4)

        -- reload chooser
        local url = REPO.."refs/heads/main/chooser.lua?t="..tostring(math.random(1e9))
        local ok, code = pcall(function() return game:HttpGet(url) end)
        if ok and code and #code > 1000 then
            local fn = loadstring(code, "@FLOXIN_CHOOSER")
            if fn then pcall(fn) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════
-- RUN
-- ═══════════════════════════════════════════════════════
local function tryLoad(v, btn)
    btn.Text = "..."
    btn.BackgroundColor3 = T.panel2
    setStatus("Fetching "..v.name.." ("..v.hash:sub(1,7)..")...")

    task.spawn(function()
        -- update session
        SESSION.hash = v.hash
        SESSION.version = v.name
        saveSessions(sessionsData)

        local url = REPO..v.hash.."/dex.lua?t="..tostring(math.random(1e9))
        local ok, code = pcall(function() return game:HttpGet(url) end)

        if not ok or type(code) ~= "string" or #code < 5000 then
            btn.Text = "Fail"
            btn.BackgroundColor3 = T.err
            setStatus("❌ fetch failed · "..(ok and (#(code or "").." bytes") or tostring(code):sub(1,60)), T.err)
            task.wait(2.5)
            btn.Text = "Run"
            btn.BackgroundColor3 = T.accent
            return
        end

        setStatus("Compiling "..#code.." bytes...", T.sub)
        local fn, err = loadstring(code, "@FLOXIN_"..v.hash:sub(1,7))
        if not fn then
            btn.Text = "Fail"
            btn.BackgroundColor3 = T.err
            setStatus("❌ compile: "..tostring(err):sub(1,80), T.err)
            task.wait(2.5)
            btn.Text = "Run"
            btn.BackgroundColor3 = T.accent
            return
        end

        setStatus("Executing "..v.name.."...", T.ok)
        gui:Destroy()

        task.spawn(function()
            local rok, rerr = pcall(fn)
            if not rok then
                warn("[FLOXIN] runtime: "..tostring(rerr):sub(1,200))
                -- mark session crashed
                SESSION.crashed = true
                saveSessions(sessionsData)
                return
            end
            -- inject back button after Dex loads
            task.wait(1.5)
            injectBackButton()
        end)
    end)
end

-- ═══════════════════════════════════════════════════════
-- BUILD CARDS
-- ═══════════════════════════════════════════════════════
for _, v in ipairs(VERSIONS) do
    local card = Instance.new("Frame", scroll)
    card.Size = UDim2.new(1, -6, 0, 100)
    card.BackgroundColor3 = T.panel
    card.BorderSizePixel = 0
    card.LayoutOrder = #scroll:GetChildren()
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

    local n = Instance.new("TextLabel", card)
    n.Size = UDim2.new(1, -100, 0, 22)
    n.Position = UDim2.new(0, 10, 0, 8)
    n.BackgroundTransparency = 1
    n.Text = v.name.." · "..v.size
    n.TextColor3 = T.text
    n.Font = Enum.Font.SourceSansBold
    n.TextSize = 15
    n.TextXAlignment = Enum.TextXAlignment.Left

    local tgt = Instance.new("TextLabel", card)
    tgt.Size = UDim2.new(1, -100, 0, 14)
    tgt.Position = UDim2.new(0, 10, 0, 32)
    tgt.BackgroundTransparency = 1
    tgt.Text = v.target
    tgt.TextColor3 = T.sub
    tgt.Font = Enum.Font.SourceSans
    tgt.TextSize = 11
    tgt.TextXAlignment = Enum.TextXAlignment.Left

    local feat = Instance.new("TextLabel", card)
    feat.Size = UDim2.new(1, -20, 0, 30)
    feat.Position = UDim2.new(0, 10, 0, 50)
    feat.BackgroundTransparency = 1
    feat.Text = v.features
    feat.TextColor3 = T.sub
    feat.Font = Enum.Font.SourceSans
    feat.TextSize = 10
    feat.TextWrapped = true
    feat.TextXAlignment = Enum.TextXAlignment.Left
    feat.TextYAlignment = Enum.TextYAlignment.Top

    local hashLbl = Instance.new("TextLabel", card)
    hashLbl.Size = UDim2.new(0, 100, 0, 14)
    hashLbl.Position = UDim2.new(0, 10, 0, 82)
    hashLbl.BackgroundTransparency = 1
    hashLbl.Text = v.hash:sub(1,8)
    hashLbl.TextColor3 = T.sub
    hashLbl.Font = Enum.Font.Code
    hashLbl.TextSize = 10
    hashLbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 80, 0, 30)
    btn.Position = UDim2.new(1, -90, 0.5, -15)
    btn.BackgroundColor3 = T.accent
    btn.Text = "Run"
    btn.TextColor3 = T.text
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    btn.MouseButton1Click:Connect(function()
        tryLoad(v, btn)
    end)
end

setStatus("Ready · session "..SESSION.id, T.sub)
