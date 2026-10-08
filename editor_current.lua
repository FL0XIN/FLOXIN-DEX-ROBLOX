["Editor"] = function()
local Main,Lib,Apps,Settings
local API,RMD,env,service,plr,create,createSimple
local function initDeps(d)
    Main=d.Main Lib=d.Lib Apps=d.Apps Settings=d.Settings
    API=d.API RMD=d.RMD env=d.env service=d.service plr=d.plr
    create=d.create createSimple=d.createSimple
end
local function initAfterMain() end

local function main()
local Editor = {}
local window, tabBar, content
local panels = {}
local history = {}
local historyIdx = 0
local logBuffer = {}
local snippets = {}
local autoSaveEnabled = true

local HttpSvc = game:GetService("HttpService")
local WORKSPACE_FILE = "floxin_workspace.json"

-- ============ outbound protection ============
-- نحذف كل دوال الاتصال الخارجي من الـsandbox
local function makeBlocked(name)
    return function(...)
        error("[sandbox] blocked: "..name.." — external calls are disabled in Editor", 2)
    end
end

-- HttpService methods
local safeHttpService = setmetatable({}, {
    __index = function(_, key)
        if key == "GetAsync" or key == "PostAsync" or key == "RequestAsync"
           or key == "GetAsyncCached" or key == "JSONEncode" or key == "JSONDecode" then
            if key == "JSONEncode" or key == "JSONDecode" then
                return HttpSvc[key]
            end
            return makeBlocked("HttpService:"..key)
        end
        return nil
    end,
})

-- wrap game to intercept HttpGet
local safeGame = setmetatable({}, {
    __index = function(_, key)
        if key == "HttpGet" or key == "HttpGetAsync" then
            return makeBlocked("game:"..key)
        end
        return game[key]
    end,
    __newindex = function(_, k, v) game[k] = v end,
})

-- wrap a table to remove network-ish functions
local function stripNet(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) ~= "function" then
            out[k] = v
        else
            local n = tostring(k)
            if n == "request" or n == "http_request" or n == "HttpGet" or n == "HttpGetAsync"
               or n:lower():find("http") and not n:lower():find("jsond") then
                out[k] = makeBlocked("."..n)
            else
                out[k] = v
            end
        end
    end
    return out
end

-- safe loadstring: only allow non-url source
local realLoadstring = loadstring
local function safeLoadstring(src, chunkname)
    if type(src) ~= "string" then
        error("[sandbox] loadstring expects a string", 2)
    end
    if #src > 200000 then
        error("[sandbox] loadstring source too large (max 200KB)", 2)
    end
    -- block if source contains a URL that looks like it will HttpGet
    local lowered = src:lower()
    if lowered:find("game:httpget") or lowered:find("httpgetasync")
       or lowered:find("httpservice:getasync") or lowered:find("httpservice:postasync")
       or lowered:find("httpservice:requestasync") or lowered:find("http_request%(") then
        error("[sandbox] loadstring contains network call", 2)
    end
    if lowered:find("request%s*%(%s*{%s*url") or lowered:find("syn%.request")
       or lowered:find("http%.request") or lowered:find("https?://[^%s\"']+%.lua") then
        error("[sandbox] loadstring contains external request", 2)
    end
    local fn, err = realLoadstring(src, chunkname or "@FLOXIN_EDITOR")
    return fn, err
end

-- safe writefile: only allow floxin_*.json / .log / .txt
local realWritefile = writefile
local function safeWritefile(path, data)
    if type(path) ~= "string" then error("[sandbox] writefile: bad path", 2) end
    local p = path:lower()
    if not p:match("^floxin_") and not p:match("^/floxin_") then
        error("[sandbox] writefile: only 'floxin_*' files allowed", 2)
    end
    if p:match("%.lua$") or p:match("%.rbxm$") or p:match("%.rbxl$") then
        error("[sandbox] writefile: cannot write script/binary files from Editor", 2)
    end
    if type(data) == "string" and #data > 5 * 1024 * 1024 then
        error("[sandbox] writefile: data too large (max 5MB)", 2)
    end
    if realWritefile then
        return realWritefile(path, data)
    end
end

Editor.SafeGame = safeGame

-- ============ SANDBOX ============
local SANDBOX = setmetatable({
    game = safeGame,
    workspace = workspace,
    script = script,

    Apps = Apps,
    Lib = Lib,
    Settings = Settings,
    Main = Main,

    -- ========= Bridge: Explorer + 3D Viewer =========
    Select = function(obj)
        if not obj then return nil, "no object" end
        if not Apps.Explorer then return nil, "Explorer not loaded" end
        local nodes = Explorer and _G._DEX_NODES
        -- best-effort: use Explorer.ViewObj
        pcall(function() Apps.Explorer.ViewObj(obj) end)
        pcall(function()
            if Apps.Explorer.Selection then
                local n = (_G.nodes and _G.nodes[obj]) or nil
                if n then Apps.Explorer.Selection:Set(n) end
            end
        end)
        return "selected: " .. obj:GetFullName()
    end,

    Preview = function(obj)
        if not obj then
            return nil, "no object passed"
        end
        if type(obj) ~= "userdata" or not obj:IsA("Instance") then
            return nil, "not an Instance"
        end
        if not (obj:IsA("BasePart") or obj:IsA("Model")) then
            return nil, "only BasePart or Model can be previewed"
        end
        if not Apps.ModelViewer then
            return nil, "ModelViewer not loaded"
        end
        local ok, err = pcall(function() Apps.ModelViewer.ViewModel(obj) end)
        if not ok then return nil, "ViewModel error: " .. tostring(err) end
        return "previewing: " .. obj:GetFullName()
    end,

    PreviewSelected = function()
        if not Apps.Explorer or not Apps.Explorer.Selection then
            return nil, "no selection available"
        end
        local list = Apps.Explorer.Selection.List
        if not list or #list == 0 then
            return nil, "nothing selected in Explorer"
        end
        local obj = list[1].Obj
        return Editor.Sandbox.Preview(obj)
    end,

    GetSelected = function()
        if not Apps.Explorer or not Apps.Explorer.Selection then
            return nil, "no selection available"
        end
        local list = Apps.Explorer.Selection.List
        if not list or #list == 0 then
            return nil, "nothing selected"
        end
        return list[1].Obj
    end,

    ClickPartSelect = function(enabled)
        if not Main.CreateApp then return nil, "no CreateApp" end
        -- toggle click part selection via Main menu (fire the button)
        -- We do best-effort: use Main.MenuApps if available
        local menu = Main.MenuApps
        if not menu then return nil, "menu apps not exposed" end
        local app = menu["Click part to select"]
        if not app then return nil, "Click part app not found" end
        if enabled then
            app:Enable()
            return "click-part enabled"
        else
            app:Disable()
            return "click-part disabled"
        end
    end,

    HttpService = safeHttpService,

    loadstring = safeLoadstring,
    load = safeLoadstring,

    writefile = safeWritefile,
    appendfile = safeWritefile,
    readfile = readfile,
    isfile = isfile,
    listfiles = listfiles,
    delfile = delfile,

    setclipboard = function(t)
        if type(t) ~= "string" then return end
        if setclipboard then pcall(setclipboard, t) end
    end,

    wait = wait, task = task, spawn = spawn, delay = delay, tick = tick, time = time,
    math = math, string = string, table = table, os = os, utf8 = utf8,
    tostring = tostring, tonumber = tonumber, type = type, typeof = typeof,
    pairs = pairs, ipairs = ipairs, next = next, select = select,
    pcall = pcall, xpcall = xpcall, error = error, assert = assert,
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            table.insert(parts, tostring(select(i, ...)))
        end
        Editor:Log(table.concat(parts, "  "), Color3.fromRGB(230,230,230))
    end,
    warn = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            table.insert(parts, tostring(select(i, ...)))
        end
        Editor:Log("[warn] "..table.concat(parts, "  "), Color3.fromRGB(255,200,100))
    end,
    save = function(name, code)
        if type(name) ~= "string" or type(code) ~= "string" then return end
        snippets[name] = code
        Editor:Log("[snippet] saved: "..name, Color3.fromRGB(120,230,140))
    end,
    load_snippet = function(name)
        return snippets[name]
    end,
    help = function()
        Editor:Log("Editor is sandboxed — no external calls.", Color3.fromRGB(255,210,100))
        Editor:Log("Bridge:", Color3.fromRGB(255,210,100))
        Editor:Log("  Preview(instance) — open in 3D Viewer", Color3.fromRGB(200,200,200))
        Editor:Log("  PreviewSelected() — preview Explorer selection", Color3.fromRGB(200,200,200))
        Editor:Log("  Select(instance) — select in Explorer", Color3.fromRGB(200,200,200))
        Editor:Log("  GetSelected() — get current Explorer selection", Color3.fromRGB(200,200,200))
        Editor:Log("  ClickPartSelect(true/false) — toggle click-part mode", Color3.fromRGB(200,200,200))
    end,
}, {__index = function(_, k)
    if k == "request" or k == "http_request" or k == "syn" or k == "http" then
        return nil
    end
    return nil
end})
Editor.Sandbox = SANDBOX

-- ============ workspace ============
function Editor:SaveWorkspace(reason)
    if not writefile then return false end
    local data = {
        v = 1,
        savedAt = os.time(),
        history = history,
        snippets = snippets,
    }
    local ok = pcall(function()
        writefile(WORKSPACE_FILE, HttpSvc:JSONEncode(data))
    end)
    if ok and reason ~= "silent" then
        Editor:Log("[autosave] saved", Color3.fromRGB(120,230,140))
    end
    return ok
end

function Editor:LoadWorkspace()
    if not (isfile and readfile) then return end
    if not isfile(WORKSPACE_FILE) then return end
    local ok, data = pcall(function() return readfile(WORKSPACE_FILE) end)
    if not ok or not data then return end
    local ok2, decoded = pcall(function() return HttpSvc:JSONDecode(data) end)
    if not ok2 or not decoded then return end
    if decoded.history then history = decoded.history historyIdx = #history + 1 end
    if decoded.snippets then snippets = decoded.snippets end
end

task.spawn(function()
    while autoSaveEnabled do
        task.wait(15)
        if autoSaveEnabled then pcall(function() Editor:SaveWorkspace("silent") end) end
    end
end)

-- ============ log ============
function Editor:Log(text, color)
    table.insert(logBuffer, {text = text, color = color or Color3.fromRGB(220,220,220)})
    if #logBuffer > 800 then table.remove(logBuffer, 1) end
    if self.RefreshConsole then self:RefreshConsole() end
end

function Editor:Clear()
    logBuffer = {}
    if self.RefreshConsole then self:RefreshConsole() end
end

-- ============ run ============
function Editor:Run(code)
    if not code or code == "" then return end
    Editor:Log("> "..code, Color3.fromRGB(130,180,255))

    -- Pre-scan for network patterns in the raw code
    local low = code:lower()
    local blocked = nil
    if low:find("httpget") or low:find("httpgetasync") then blocked = "HttpGet"
    elseif low:find("httpservice:getasync") or low:find("httpservice:postasync") or low:find("httpservice:requestasync") then blocked = "HttpService network call"
    elseif low:find("syn%.request") or low:find("http%.request") or low:find("http_request") then blocked = "request()"
    elseif low:find("discord%.com/api/webhooks") then blocked = "Discord webhook"
    elseif low:find("https?://[^%s\"']+%.lua") then blocked = "loading external .lua"
    end

    if blocked then
        Editor:Log("════════ BLOCKED ════════", Color3.fromRGB(255,100,110))
        Editor:Log("Editor is sandboxed.", Color3.fromRGB(255,210,100))
        Editor:Log("Reason: "..blocked, Color3.fromRGB(255,100,110))
        Editor:Log("External calls & data exfil are disabled.", Color3.fromRGB(255,210,100))
        return
    end

    local fn, err = safeLoadstring(code, "@FLOXIN_EDITOR")
    if not fn then
        Editor:Log("compile error: "..tostring(err), Color3.fromRGB(255,100,110))
        return
    end
    setfenv(fn, SANDBOX)
    local ok, res = pcall(fn)
    if not ok then
        Editor:Log("runtime error: "..tostring(res), Color3.fromRGB(255,100,110))
    elseif res ~= nil then
        Editor:Log(tostring(res), Color3.fromRGB(120,230,140))
    end
end

-- ============ scan ============
local function scanModules()
    local list = {}
    for name, mod in pairs(Apps) do
        local t = type(mod)
        local keys = {}
        if t == "table" then
            for k, v in pairs(mod) do
                table.insert(keys, tostring(k).." ("..type(v)..")")
            end
            table.sort(keys)
        end
        table.insert(list, {name = name, kind = t, keys = keys})
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function scanHooks()
    local out = {}
    local function add(n, v) table.insert(out, {name = n, kind = tostring(v)}) end
    add("Explorer.Sorting", Settings.Explorer.Sorting)
    add("Explorer.PartSelectionBox", Settings.Explorer.PartSelectionBox)
    add("Explorer.GuiSelectionBox", Settings.Explorer.GuiSelectionBox)
    add("Properties.ShowDeprecated", Settings.Properties.ShowDeprecated)
    add("Properties.ShowHidden", Settings.Properties.ShowHidden)
    add("Properties.ShowAttributes", Settings.Properties.ShowAttributes)
    add("Window.Transparency", Settings.Window.Transparency)
    add("Window.TitleOnMiddle", Settings.Window.TitleOnMiddle)
    add("PlayerName", plr.Name)
    add("UserId", plr.UserId)
    add("PlaceId", game.PlaceId)
    add("JobId", game.JobId ~= "" and game.JobId or "private")
    add("Executor", (identifyexecutor and identifyexecutor() or "?"))
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

-- ============ UI helpers ============
local function newPanel()
    local p = Instance.new("Frame", content)
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = false
    return p
end

local function makeBtn(parent, text, color, cb, w, x, y)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, w or 70, 0, 26)
    b.Position = UDim2.new(0, x or 0, 0, y or 0)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

-- CONSOLE (real code editor + mobile toolbar + responsive)
local function buildConsole(parent)
    local banner = Instance.new("TextLabel", parent)
    banner.BackgroundColor3 = Settings.Theme.Main2
    banner.Text = "Sandbox · no external requests · local only"
    banner.TextColor3 = Settings.Theme.Text
    banner.TextTransparency = 0.15
    banner.Font = Enum.Font.SourceSans
    banner.TextSize = 11
    banner.TextWrapped = true
    banner.TextXAlignment = Enum.TextXAlignment.Left
    banner.TextYAlignment = Enum.TextYAlignment.Center
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 5)

    local out = Instance.new("ScrollingFrame", parent)
    out.BackgroundColor3 = Color3.fromRGB(18,18,22)
    out.BorderSizePixel = 0
    out.ScrollBarThickness = 8
    out.ScrollBarImageColor3 = Color3.fromRGB(120,120,120)
    out.ScrollBarImageTransparency = 0
    out.CanvasSize = UDim2.new(0,0,0,0)
    out.AutomaticCanvasSize = Enum.AutomaticSize.Y
    out.ScrollingDirection = Enum.ScrollingDirection.Y
    out.Active = true
    Instance.new("UICorner", out).CornerRadius = UDim.new(0, 5)
    local lay = Instance.new("UIListLayout", out)
    lay.Padding = UDim.new(0, 2)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    local function refresh()
        for _, c in ipairs(out:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        for i, item in ipairs(logBuffer) do
            local l = Instance.new("TextLabel", out)
            l.Size = UDim2.new(1, -8, 0, 0)
            l.AutomaticSize = Enum.AutomaticSize.Y
            l.BackgroundTransparency = 1
            l.Text = item.text
            l.TextColor3 = item.color
            l.Font = Enum.Font.Code
            l.TextSize = 11
            l.TextWrapped = true
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.LayoutOrder = i
        end
        task.wait()
        out.CanvasPosition = Vector2.new(0, lay.AbsoluteContentSize.Y)
    end
    Editor.RefreshConsole = refresh
    refresh()

    local mobileRow = Instance.new("Frame", parent)
    mobileRow.BackgroundTransparency = 1
    local mLay = Instance.new("UIListLayout", mobileRow)
    mLay.FillDirection = Enum.FillDirection.Horizontal
    mLay.Padding = UDim.new(0, 3)
    mLay.SortOrder = Enum.SortOrder.LayoutOrder

    local editorHolder = Instance.new("Frame", parent)
    editorHolder.BackgroundColor3 = Settings.Theme.Main1
    editorHolder.BorderSizePixel = 0
    Instance.new("UICorner", editorHolder).CornerRadius = UDim.new(0, 5)

    local codeFrame = Lib.CodeFrame.new()
    codeFrame.Frame.Position = UDim2.new(0, 0, 0, 0)
    codeFrame.Frame.Size = UDim2.new(1, 0, 1, 0)
    codeFrame.Frame.Parent = editorHolder
    codeFrame:SetText("-- Editor · sandboxed Lua\n-- try: Apps.Browser.Window:Show()\nprint('hello')")

    local row = Instance.new("Frame", parent)
    row.BackgroundTransparency = 1

    local function runCode()
        local c = codeFrame:GetText()
        if c == "" then return end
        table.insert(history, c)
        historyIdx = #history + 1
        Editor:Run(c)
    end

    local function makeMBtn(text, cb, w)
        local b = Instance.new("TextButton", mobileRow)
        b.Size = UDim2.new(0, w or 42, 1, 0)
        b.BackgroundColor3 = Settings.Theme.Button
        b.Text = text
        b.TextColor3 = Settings.Theme.Text
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    makeMBtn("Del", function()
        local cf = codeFrame
        if cf.CursorX > 0 then
            local line = cf.Lines[cf.CursorY + 1] or ""
            cf.Lines[cf.CursorY + 1] = line:sub(1, cf.CursorX - 1) .. line:sub(cf.CursorX + 1)
            cf.CursorX = cf.CursorX - 1
            cf.FloatCursorX = cf.CursorX
        elseif cf.CursorY > 0 then
            local prev = cf.Lines[cf.CursorY] or ""
            local cur = cf.Lines[cf.CursorY + 1] or ""
            cf.Lines[cf.CursorY] = prev .. cur
            table.remove(cf.Lines, cf.CursorY + 1)
            cf.CursorY = cf.CursorY - 1
            cf.CursorX = #prev
            cf.FloatCursorX = cf.CursorX
        end
        cf:ProcessTextChange()
    end, 40)

    makeMBtn("Enter", function() codeFrame:AppendText("\n") end, 48)
    makeMBtn("Tab", function() codeFrame:AppendText("    ") end, 40)
    makeMBtn("Space", function() codeFrame:AppendText(" ") end, 48)
    makeMBtn("Copy", function()
        local t = codeFrame:GetText()
        if setclipboard then pcall(setclipboard, t) end
    end, 44)
    makeMBtn("Copy Log", function()
        local lines = {}
        for _, item in ipairs(logBuffer) do
            table.insert(lines, item.text)
        end
        local txt = table.concat(lines, "\n")
        local okc = false
        if env and env.setclipboard then pcall(function() env.setclipboard(txt) okc = true end) end
        if not okc and setclipboard then pcall(function() setclipboard(txt) okc = true end) end
        if not okc and toclipboard then pcall(function() toclipboard(txt) okc = true end) end
        if okc then
            Editor:Log("[copied "..#txt.." bytes]", Color3.fromRGB(120,230,140))
        else
            Editor:Log("[copy failed]", Color3.fromRGB(255,100,110))
        end
    end, 74)

    makeMBtn("Clear Log", function()
        Editor:Clear()
    end, 74)

    makeMBtn("Clear", function() codeFrame:SetText("") end, 50)

    makeBtn(row, "Run", Settings.Theme.ListSelection, runCode, 70, 0)
    makeBtn(row, "Clr Log", Settings.Theme.Button, function() Editor:Clear() end, 70, 76)
    makeBtn(row, "Last", Settings.Theme.Button, function()
        if historyIdx > 1 then
            historyIdx = historyIdx - 1
            codeFrame:SetText(history[historyIdx] or "")
        end
    end, 60, 152)
    makeBtn(row, "Save", Settings.Theme.Button, function() Editor:SaveWorkspace() end, 70, 218)

    local function relayout()
        local H = parent.AbsoluteSize.Y
        local W = parent.AbsoluteSize.X
        if W < 10 or H < 10 then return end
        local bannerH = 24
        local mobRowH = 26
        local actRowH = 28
        local gap = 6
        local avail = H - bannerH - mobRowH - actRowH - gap * 4
        if avail < 120 then avail = 120 end
        local logH = math.max(50, math.floor(avail * 0.42))
        local editH = math.max(70, avail - logH)
        banner.Position = UDim2.new(0, 4, 0, 2)
        banner.Size = UDim2.new(1, -8, 0, bannerH)
        out.Position = UDim2.new(0, 4, 0, bannerH + gap + 2)
        out.Size = UDim2.new(1, -8, 0, logH)
        editorHolder.Position = UDim2.new(0, 4, 0, bannerH + gap * 2 + logH + 2)
        editorHolder.Size = UDim2.new(1, -8, 0, editH)
        mobileRow.Position = UDim2.new(0, 4, 0, bannerH + gap * 3 + logH + editH + 2)
        mobileRow.Size = UDim2.new(1, -8, 0, mobRowH)
        row.Position = UDim2.new(0, 4, 1, -actRowH - 4)
        row.Size = UDim2.new(1, -8, 0, actRowH)
    end
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
    task.defer(relayout)

    game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Return then
            if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftControl) then
                runCode()
            end
        end
    end)
end

-- SNIPPETS
local function buildSnippets(parent)
    local scroll = Instance.new("ScrollingFrame", parent)
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0, 4, 0, 4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 4)

    local function refresh()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
        end
        local names = {}
        for n in pairs(snippets) do table.insert(names, n) end
        table.sort(names)
        if #names == 0 then
            local l = Instance.new("TextLabel", scroll)
            l.Size = UDim2.new(1, -6, 0, 40)
            l.BackgroundTransparency = 1
            l.Text = "No snippets yet.\nUse: save('name', 'code') in Console"
            l.TextColor3 = Settings.Theme.PlaceholderText
            l.Font = Enum.Font.SourceSans
            l.TextSize = 11
            l.TextWrapped = true
            l.TextXAlignment = Enum.TextXAlignment.Left
            return
        end
        for i, n in ipairs(names) do
            local card = Instance.new("Frame", scroll)
            card.Size = UDim2.new(1, -6, 0, 56)
            card.BackgroundColor3 = Settings.Theme.Main2
            card.BorderSizePixel = 0
            card.LayoutOrder = i
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

            local t = Instance.new("TextLabel", card)
            t.Size = UDim2.new(1, -120, 0, 22)
            t.Position = UDim2.new(0, 8, 0, 4)
            t.BackgroundTransparency = 1
            t.Text = n
            t.TextColor3 = Settings.Theme.Text
            t.Font = Enum.Font.SourceSansBold
            t.TextSize = 13
            t.TextXAlignment = Enum.TextXAlignment.Left

            local prev = Instance.new("TextLabel", card)
            prev.Size = UDim2.new(1, -16, 0, 24)
            prev.Position = UDim2.new(0, 8, 0, 28)
            prev.BackgroundTransparency = 1
            prev.Text = (snippets[n] or ""):sub(1, 80):gsub("\n", " ")
            prev.TextColor3 = Settings.Theme.PlaceholderText
            prev.Font = Enum.Font.Code
            prev.TextSize = 10
            prev.TextXAlignment = Enum.TextXAlignment.Left
            prev.TextTruncate = Enum.TextTruncate.AtEnd

            makeBtn(card, "Run", Color3.fromRGB(11,90,175), function() Editor:Run(snippets[n]) end, 50, 0, 4)
            makeBtn(card, "Del", Color3.fromRGB(160,50,50), function() snippets[n] = nil refresh() end, 50, 0, 4)
            for _, c in ipairs(card:GetChildren()) do
                if c:IsA("TextButton") then
                    if c.Text == "Run" then c.Position = UDim2.new(1, -106, 0, 4)
                    elseif c.Text == "Del" then c.Position = UDim2.new(1, -52, 0, 4) end
                end
            end
        end
    end
    Editor.RefreshSnippets = refresh
    refresh()
end

-- MODULES
local function buildModules(parent)
    local scroll = Instance.new("ScrollingFrame", parent)
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0, 4, 0, 4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 4)

    local list = scanModules()
    for i, m in ipairs(list) do
        local card = Instance.new("Frame", scroll)
        card.Size = UDim2.new(1, -6, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Settings.Theme.Main2
        card.BorderSizePixel = 0
        card.LayoutOrder = i
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 5)

        local hdr = Instance.new("TextButton", card)
        hdr.Size = UDim2.new(1, 0, 0, 24)
        hdr.BackgroundTransparency = 1
        hdr.Text = "  >  "..m.name.."  ("..m.kind..")"
        hdr.TextColor3 = Settings.Theme.Text
        hdr.Font = Enum.Font.SourceSansBold
        hdr.TextSize = 12
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.AutoButtonColor = false

        local body = Instance.new("Frame", card)
        body.Size = UDim2.new(1, -12, 0, 0)
        body.Position = UDim2.new(0, 6, 0, 26)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.Visible = false
        local bLay = Instance.new("UIListLayout", body)
        bLay.Padding = UDim.new(0, 1)

        local built = false
        hdr.MouseButton1Click:Connect(function()
            if not built then
                built = true
                for _, k in ipairs(m.keys) do
                    local lbl = Instance.new("TextLabel", body)
                    lbl.Size = UDim2.new(1, 0, 0, 15)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = "    "..k
                    lbl.TextColor3 = Settings.Theme.PlaceholderText
                    lbl.Font = Enum.Font.Code
                    lbl.TextSize = 10
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                end
            end
            body.Visible = not body.Visible
            hdr.Text = (body.Visible and "  v  " or "  >  ")..m.name
        end)
    end
end

-- HOOKS
local function buildHooks(parent)
    local scroll = Instance.new("ScrollingFrame", parent)
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0, 4, 0, 4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 3)

    for i, h in ipairs(scanHooks()) do
        local l = Instance.new("TextLabel", scroll)
        l.Size = UDim2.new(1, -6, 0, 18)
        l.BackgroundColor3 = Settings.Theme.Main2
        l.BorderSizePixel = 0
        l.Text = "  "..h.name.."  =  "..h.kind
        l.TextColor3 = Settings.Theme.Text
        l.Font = Enum.Font.Code
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = i
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
    end
end

-- API
local function buildAPI(parent)
    local scroll = Instance.new("ScrollingFrame", parent)
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0, 4, 0, 4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0, 3)

    local function add(k, v, c)
        local l = Instance.new("TextLabel", scroll)
        l.Size = UDim2.new(1, -6, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.BackgroundColor3 = Settings.Theme.Main2
        l.BorderSizePixel = 0
        l.Text = "  "..k..(v and ("  ·  "..tostring(v)) or "")
        l.TextColor3 = c or Settings.Theme.Text
        l.Font = Enum.Font.Code
        l.TextSize = 11
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = #scroll:GetChildren()
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
    end

    add("Sandbox status", "ACTIVE", Color3.fromRGB(255,100,110))
    add("", "")
    add("Blocked:", "", Color3.fromRGB(255,150,150))
    add("  game:HttpGet / HttpGetAsync", "error", Color3.fromRGB(255,100,110))
    add("  HttpService:GetAsync", "error", Color3.fromRGB(255,100,110))
    add("  HttpService:PostAsync", "error", Color3.fromRGB(255,100,110))
    add("  HttpService:RequestAsync", "error", Color3.fromRGB(255,100,110))
    add("  request / http_request / syn.request", "nil (removed)", Color3.fromRGB(255,100,110))
    add("  loadstring with URL", "error", Color3.fromRGB(255,100,110))
    add("  writefile outside floxin_*", "error", Color3.fromRGB(255,100,110))
    add("  writefile *.lua / *.rbxm", "error", Color3.fromRGB(255,100,110))
    add("", "")
    add("Allowed:", "", Color3.fromRGB(120,230,140))
    add("  Apps.* · Lib.* · Settings.*", "full access")
    add("  game (read-only)", "HttpGet removed")
    add("  workspace · script", "read")
    add("  loadstring(local_code)", "max 200KB")
    add("  writefile('floxin_*.json/log/txt')", "max 5MB")
    add("  setclipboard", "allowed")
    add("", "")
    add("Helpers:", "", Color3.fromRGB(255,210,100))
    add("  save('name', 'code')", "snippet save")
    add("  load_snippet('name')", "snippet read")
    add("  help()", "tips")
    add("  Editor:SaveWorkspace()", "manual save")
    add("", "")
    add("Examples:", "", Color3.fromRGB(130,180,255))
    add("  Apps.Browser.Window:Show()")
    add("  Settings.Window.Transparency = 0.5")
    add("  save('openB', \"Apps.Browser.Window:Show()\")")
end

-- SAVE
local function buildSave(parent)
    local holder = Instance.new("Frame", parent)
    holder.Size = UDim2.new(1, -8, 1, -8)
    holder.Position = UDim2.new(0, 4, 0, 4)
    holder.BackgroundTransparency = 1
    local lay = Instance.new("UIListLayout", holder)
    lay.Padding = UDim.new(0, 6)

    local function addBtn(label, color, cb)
        local b = Instance.new("TextButton", holder)
        b.Size = UDim2.new(1, 0, 0, 34)
        b.BackgroundColor3 = color
        b.Text = label
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 12
        b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    addBtn("Save workspace", Color3.fromRGB(11,90,175), function() Editor:SaveWorkspace() end)
    addBtn("Load workspace", Color3.fromRGB(60,130,80), function()
        Editor:LoadWorkspace()
        if Editor.RefreshSnippets then Editor:RefreshSnippets() end
        Editor:Log("[workspace] loaded", Color3.fromRGB(120,230,140))
    end)
    addBtn("Copy session log", Color3.fromRGB(60,60,70), function()
        local lines = {}
        for _, item in ipairs(logBuffer) do table.insert(lines, item.text) end
        if setclipboard then pcall(setclipboard, table.concat(lines, "\n")) end
    end)
    addBtn("Toggle Auto-save", Color3.fromRGB(160,110,30), function()
        autoSaveEnabled = not autoSaveEnabled
        Editor:Log("[autosave] "..(autoSaveEnabled and "ON" or "OFF"), Color3.fromRGB(255,210,100))
    end)
    addBtn("Reset Settings", Color3.fromRGB(180,50,50), function()
        if Main and Main.ResetSettings then Main.ResetSettings() end
    end)
end

-- ============ INIT ============
Editor.Init = function()
    Editor:LoadWorkspace()

    window = Lib.Window.new()
    window:SetTitle("Editor")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 350 or 440, isMobile and 500 or 580)
    Editor.Window = window

    tabBar = Instance.new("Frame", window.GuiElems.Content)
    tabBar.Size = UDim2.new(1, -8, 0, 30)
    tabBar.Position = UDim2.new(0, 4, 0, 4)
    tabBar.BackgroundTransparency = 1
    local tabLay = Instance.new("UIListLayout", tabBar)
    tabLay.FillDirection = Enum.FillDirection.Horizontal
    tabLay.Padding = UDim.new(0, 3)

    content = Instance.new("Frame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -42)
    content.Position = UDim2.new(0, 4, 0, 38)
    content.BackgroundTransparency = 1

    local tabs = {"Console", "Snippets", "Modules", "Hooks", "API", "Save"}
    local tabBtns = {}

    for i, name in ipairs(tabs) do
        local b = Instance.new("TextButton", tabBar)
        b.Size = UDim2.new(0, 60, 1, 0)
        b.BackgroundColor3 = Settings.Theme.Main2
        b.Text = name
        b.TextColor3 = Settings.Theme.PlaceholderText
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 10
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        tabBtns[name] = b

        local panel = newPanel()
        panels[name] = panel

        if name == "Console" then buildConsole(panel)
        elseif name == "Snippets" then buildSnippets(panel)
        elseif name == "Modules" then buildModules(panel)
        elseif name == "Hooks" then buildHooks(panel)
        elseif name == "API" then buildAPI(panel)
        elseif name == "Save" then buildSave(panel)
        end

        b.MouseButton1Click:Connect(function()
            for k, btn in pairs(tabBtns) do
                btn.BackgroundColor3 = Settings.Theme.Main2
                btn.TextColor3 = Settings.Theme.PlaceholderText
                if panels[k] then panels[k].Visible = false end
            end
            b.BackgroundColor3 = Color3.fromRGB(11,90,175)
            b.TextColor3 = Color3.new(1,1,1)
            panel.Visible = true
        end)
    end

    tabBtns["Console"].BackgroundColor3 = Color3.fromRGB(11,90,175)
    tabBtns["Console"].TextColor3 = Color3.new(1,1,1)
    panels["Console"].Visible = true

    Editor:Log("FLOXIN Editor", Color3.fromRGB(200,150,255))
    Editor:Log("Sandboxed · no external requests", Color3.fromRGB(255,180,180))
    Editor:Log("Auto-save ON · source never modified", Color3.fromRGB(150,150,155))
end

return Editor
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

["ModelEditor"] = function()
local Main,Lib,Apps,Settings
local API,RMD,env,service,plr,create,createSimple
local function initDeps(d)
    Main=d.Main Lib=d.Lib Apps=d.Apps Settings=d.Settings
    API=d.API RMD=d.RMD env=d.env service=d.service plr=d.plr
    create=d.create createSimple=d.createSimple
end
local function initAfterMain() end

local function main()
local ME = {}
local window, content
local spawned = {}
local lastSettings = {
    shape = "Block",
    material = "Plastic",
    color = {r=1, g=1, b=1},
    sizeX = 4, sizeY = 4, sizeZ = 4,
    anchored = true,
    cancollide = true,
    transparency = 0,
}

local SHAPES = {"Block", "Ball", "Cylinder", "Wedge", "CornerWedge"}
local MATERIALS = {
    "Plastic","Wood","Slate","Concrete","CorrodedMetal","DiamondPlate",
    "Foil","Grass","Ice","Marble","Granite","Brick","Pebble","Sand",
    "Fabric","SmoothPlastic","Metal","WoodPlanks","Cobblestone","Neon",
    "Glass","ForceField","Marble"
}

local function getSpawnPosition()
    local cam = workspace.CurrentCamera
    if not cam then return Vector3.new(0, 10, 0) end
    local cf = cam.CFrame
    return (cf * CFrame.new(0, 0, -20)).Position
end

local function createPart()
    local p = Instance.new("Part")
    p.Name = "FLOXIN_Part_"..math.random(1000,9999)
    p.Shape = Enum.PartType[lastSettings.shape]
    p.Material = Enum.Material[lastSettings.material]
    p.Color = Color3.new(lastSettings.color.r, lastSettings.color.g, lastSettings.color.b)
    p.Size = Vector3.new(lastSettings.sizeX, lastSettings.sizeY, lastSettings.sizeZ)
    p.Anchored = lastSettings.anchored
    p.CanCollide = lastSettings.cancollide
    p.Transparency = lastSettings.transparency
    p.Position = getSpawnPosition()
    p.Parent = workspace
    table.insert(spawned, p)
    return p
end

-- UI helpers
local function mkRow(parent)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -6, 0, 26)
    f.BackgroundColor3 = Settings.Theme.Main2
    f.BorderSizePixel = 0
    f.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    return f
end

local function mkLabel(parent, text, w)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(0, w or 80, 1, 0)
    l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Settings.Theme.Text
    l.Font = Enum.Font.SourceSans
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local function mkNum(parent, x, default, cb)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(0, 46, 0, 20)
    box.Position = UDim2.new(0, x, 0, 3)
    box.BackgroundColor3 = Settings.Theme.TextBox
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = Settings.Theme.Text
    box.Font = Enum.Font.Code
    box.TextSize = 11
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then cb(n) end
    end)
    return box
end

local function mkDropdown(parent, x, list, default, cb)
    local holder = Instance.new("Frame", parent)
    holder.Size = UDim2.new(0, 110, 0, 20)
    holder.Position = UDim2.new(0, x, 0, 3)
    holder.BackgroundColor3 = Settings.Theme.TextBox
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 3)

    local lbl = Instance.new("TextLabel", holder)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(default)
    lbl.TextColor3 = Settings.Theme.Text
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    local btn = Instance.new("TextButton", holder)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        local ctx = Instance.new("Frame", window.GuiElems.Content)
        ctx.Size = UDim2.new(0, 130, 0, math.min(#list*22+8, 200))
        ctx.Position = UDim2.new(0, holder.AbsolutePosition.X - window.GuiElems.Content.AbsolutePosition.X, 0, holder.AbsolutePosition.Y - window.GuiElems.Content.AbsolutePosition.Y + 22)
        ctx.BackgroundColor3 = Settings.Theme.Main1
        ctx.BorderSizePixel = 0
        ctx.ZIndex = 99
        Instance.new("UICorner", ctx).CornerRadius = UDim.new(0, 5)
        local st = Instance.new("UIStroke", ctx)
        st.Color = Settings.Theme.Outline1
        local sc = Instance.new("ScrollingFrame", ctx)
        sc.Size = UDim2.new(1, 0, 1, 0)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 4
        sc.CanvasSize = UDim2.new(0,0,0,#list*22+4)
        local lay = Instance.new("UIListLayout", sc)
        lay.Padding = UDim.new(0,1)
        for _, item in ipairs(list) do
            local ib = Instance.new("TextButton", sc)
            ib.Size = UDim2.new(1, -4, 0, 20)
            ib.BackgroundColor3 = Settings.Theme.Main2
            ib.Text = tostring(item)
            ib.TextColor3 = Settings.Theme.Text
            ib.Font = Enum.Font.SourceSans
            ib.TextSize = 11
            ib.BorderSizePixel = 0
            ib.AutoButtonColor = false
            Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 3)
            ib.MouseButton1Click:Connect(function()
                lbl.Text = tostring(item)
                cb(item)
                ctx:Destroy()
            end)
        end
        -- close on outside click
        local mConn
        mConn = service.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                ctx:Destroy()
                mConn:Disconnect()
            end
        end)
    end)
    return holder
end

local function mkBtn(parent, text, color, cb, w, x, y)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, w or 100, 0, 28)
    b.Position = UDim2.new(0, x or 0, 0, y or 0)
    b.BackgroundColor3 = color or Settings.Theme.Button
    b.Text = text
    b.TextColor3 = Settings.Theme.Text
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

ME.Init = function()
    window = Lib.Window.new()
    window:SetTitle("Model Editor")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 320 or 380, isMobile and 460 or 540)
    ME.Window = window

    content = Instance.new("ScrollingFrame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -8)
    content.Position = UDim2.new(0, 4, 0, 4)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = Settings.Theme.Outline1
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout", content)
    lay.Padding = UDim.new(0, 4)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    -- header
    local hdr = Instance.new("TextLabel", content)
    hdr.Size = UDim2.new(1, -6, 0, 22)
    hdr.BackgroundTransparency = 1
    hdr.Text = "Create Part"
    hdr.TextColor3 = Settings.Theme.Text
    hdr.Font = Enum.Font.SourceSansBold
    hdr.TextSize = 13
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.LayoutOrder = #content:GetChildren()

    -- Shape
    local r1 = mkRow(content)
    mkLabel(r1, "Shape", 50)
    mkDropdown(r1, 60, SHAPES, lastSettings.shape, function(v) lastSettings.shape = v end)

    -- Material
    local r2 = mkRow(content)
    mkLabel(r2, "Material", 60)
    mkDropdown(r2, 70, MATERIALS, lastSettings.material, function(v) lastSettings.material = v end)

    -- Size
    local r3 = mkRow(content)
    mkLabel(r3, "Size X/Y/Z", 70)
    mkNum(r3, 76, lastSettings.sizeX, function(v) lastSettings.sizeX = v end)
    mkNum(r3, 128, lastSettings.sizeY, function(v) lastSettings.sizeY = v end)
    mkNum(r3, 180, lastSettings.sizeZ, function(v) lastSettings.sizeZ = v end)

    -- Color R/G/B
    local r4 = mkRow(content)
    mkLabel(r4, "Color R/G/B", 76)
    mkNum(r4, 82, lastSettings.color.r, function(v) lastSettings.color.r = math.clamp(v, 0, 1) end)
    mkNum(r4, 134, lastSettings.color.g, function(v) lastSettings.color.g = math.clamp(v, 0, 1) end)
    mkNum(r4, 186, lastSettings.color.b, function(v) lastSettings.color.b = math.clamp(v, 0, 1) end)

    -- Transparency
    local r5 = mkRow(content)
    mkLabel(r5, "Transparency", 80)
    mkNum(r5, 88, lastSettings.transparency, function(v) lastSettings.transparency = math.clamp(v, 0, 1) end)

    -- Anchored / CanCollide
    local r6 = mkRow(content)
    mkLabel(r6, "Anchored", 60)
    local anchBtn = mkBtn(r6, lastSettings.anchored and "ON" or "OFF", lastSettings.anchored and Settings.Theme.ListSelection or Settings.Theme.Button, function() end, 40, 66, 0)
    anchBtn.MouseButton1Click:Connect(function()
        lastSettings.anchored = not lastSettings.anchored
        anchBtn.Text = lastSettings.anchored and "ON" or "OFF"
        anchBtn.BackgroundColor3 = lastSettings.anchored and Settings.Theme.ListSelection or Settings.Theme.Button
    end)

    mkLabel(r6, "  CanCollide", 0)
    local ccLbl = r6:GetChildren()[#r6:GetChildren()]
    ccLbl.Position = UDim2.new(0, 116, 0, 0)
    ccLbl.Size = UDim2.new(0, 70, 1, 0)
    local ccBtn = mkBtn(r6, lastSettings.cancollide and "ON" or "OFF", lastSettings.cancollide and Settings.Theme.ListSelection or Settings.Theme.Button, function() end, 40, 190, 0)
    ccBtn.MouseButton1Click:Connect(function()
        lastSettings.cancollide = not lastSettings.cancollide
        ccBtn.Text = lastSettings.cancollide and "ON" or "OFF"
        ccBtn.BackgroundColor3 = lastSettings.cancollide and Settings.Theme.ListSelection or Settings.Theme.Button
    end)

    -- separator
    local sep = Instance.new("Frame", content)
    sep.Size = UDim2.new(1, -6, 0, 1)
    sep.BackgroundColor3 = Settings.Theme.Outline1
    sep.BorderSizePixel = 0
    sep.LayoutOrder = #content:GetChildren()

    -- Actions header
    local hdr2 = Instance.new("TextLabel", content)
    hdr2.Size = UDim2.new(1, -6, 0, 20)
    hdr2.BackgroundTransparency = 1
    hdr2.Text = "Actions"
    hdr2.TextColor3 = Settings.Theme.Text
    hdr2.Font = Enum.Font.SourceSansBold
    hdr2.TextSize = 13
    hdr2.TextXAlignment = Enum.TextXAlignment.Left
    hdr2.LayoutOrder = #content:GetChildren()

    -- Spawn
    mkBtn(content, "Spawn Part", Settings.Theme.ListSelection, function()
        local p = createPart()
        if Apps.ModelViewer and Apps.ModelViewer.ViewModel then
            pcall(function() Apps.ModelViewer.ViewModel(p) end)
        end
    end, 200, 0, 0).Size = UDim2.new(0, 200, 0, 30)

    -- Clear spawned
    mkBtn(content, "Clear My Spawned Parts ("..#spawned..")", Settings.Theme.Button, function()
        for _, p in ipairs(spawned) do
            pcall(function() p:Destroy() end)
        end
        spawned = {}
    end, 260, 0, 0).Size = UDim2.new(0, 260, 0, 28)

    -- Spawn Cube 10x10
    mkBtn(content, "Quick: 10x10 Cube", Settings.Theme.Button, function()
        lastSettings.sizeX = 10; lastSettings.sizeY = 10; lastSettings.sizeZ = 10
        createPart()
    end, 140, 0, 0).Size = UDim2.new(0, 140, 0, 26)

    -- Spawn Sphere
    mkBtn(content, "Quick: Ball r=5", Settings.Theme.Button, function()
        lastSettings.shape = "Ball"
        lastSettings.sizeX = 10; lastSettings.sizeY = 10; lastSettings.sizeZ = 10
        createPart()
    end, 140, 0, 0).Size = UDim2.new(0, 140, 0, 26)
end

return ME
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

["DeveloperScripts"] = function()
local Main,Lib,Apps,Settings
local API,RMD,env,service,plr,create,createSimple
local function initDeps(d)
    Main=d.Main Lib=d.Lib Apps=d.Apps Settings=d.Settings
    API=d.API RMD=d.RMD env=d.env service=d.service plr=d.plr
    create=d.create createSimple=d.createSimple
end
local function initAfterMain() end

local function main()
local DS = {}
local window, listFrame, searchBox, statusLbl, tabRow
local community = {}
local mine = {}
local searchText = ""
local currentTab = "community"

local HttpSvc = game:GetService("HttpService")
local MY_FILE = "floxin_myscripts.json"
local REPO = "FL0XIN/FLOXIN-DEX-ROBLOX"
local BASE = "https://raw.githubusercontent.com/"..REPO.."/refs/heads/main/scripts/"
local INDEX_URL = BASE.."index.json"
local MAX_CHARS = 5000

function DS:LoadMine()
    if not (isfile and readfile) then return end
    if not isfile(MY_FILE) then return end
    local ok, data = pcall(readfile, MY_FILE)
    if not ok or not data then return end
    local ok2, dec = pcall(function() return HttpSvc:JSONDecode(data) end)
    if ok2 and dec and dec.scripts then mine = dec.scripts end
end

function DS:SaveMine()
    if not writefile then return false end
    return pcall(function() writefile(MY_FILE, HttpSvc:JSONEncode({scripts = mine})) end)
end

function DS:FetchCommunity()
    local ok, data = pcall(function() return game:HttpGet(INDEX_URL.."?t="..tostring(tick())) end)
    if not ok or not data then return false end
    local ok2, dec = pcall(function() return HttpSvc:JSONDecode(data) end)
    if not ok2 or not dec then return false end
    community = dec.scripts or dec or {}
    return true
end

local function scanForNetwork(code)
    local low = code:lower()
    if low:find("httpget") or low:find("httpgetasync") then return "HttpGet" end
    if low:find("httpservice:getasync") or low:find("httpservice:postasync") then return "HttpService" end
    if low:find("syn%.request") or low:find("http_request") or low:find("http%.request") then return "request()" end
    if low:find("discord%.com/api/webhooks") then return "webhook" end
    return nil
end

function DS:RunScript(code, name)
    if #code > MAX_CHARS then return false, "code too long (> "..MAX_CHARS.." chars)" end
    local blocked = scanForNetwork(code)
    if blocked then return false, "blocked: "..blocked end
    local fn, err = loadstring(code, "@DEVS:"..(name or "script"))
    if not fn then return false, "compile: "..tostring(err):sub(1,80) end
    local sb = (Apps.Editor and Apps.Editor.Sandbox) or getfenv()
    setfenv(fn, sb)
    local ok, res = pcall(fn)
    if not ok then return false, tostring(res):sub(1,80) end
    return true, res
end

local function copy(t)
    local ok = false
    if env and env.setclipboard then pcall(function() env.setclipboard(t) ok=true end) end
    if not ok and setclipboard then pcall(function() setclipboard(t) ok=true end) end
    if not ok and toclipboard then pcall(function() toclipboard(t) ok=true end) end
    return ok
end

local function mkPopup(title, w, h)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FLOXIN_Popup_" .. tostring(math.random(1,1e6))
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    local parent
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and typeof(h) == "Instance" then parent = h end
    end
    if not parent then
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then parent = cg end
    end
    if not parent then
        local ok, pg = pcall(function() return plr:WaitForChild("PlayerGui", 5) end)
        if ok and pg then parent = pg end
    end
    if not parent then
        warn("[DS] no valid parent")
        return nil, nil
    end
    gui.Parent = parent

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, w, 0, h)
    main.Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
    main.BackgroundColor3 = Settings.Theme.Main1
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

    local bar = Instance.new("Frame", main)
    bar.Size = UDim2.new(1, 0, 0, 24)
    bar.BackgroundColor3 = Settings.Theme.Main2
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

    local t = Instance.new("TextLabel", bar)
    t.Size = UDim2.new(1, -30, 1, 0)
    t.Position = UDim2.new(0, 8, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Settings.Theme.Text
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left

    local x = Instance.new("TextButton", bar)
    x.Size = UDim2.new(0, 20, 0, 18)
    x.Position = UDim2.new(1, -24, 0, 3)
    x.BackgroundColor3 = Settings.Theme.Button
    x.Text = "X"
    x.TextColor3 = Settings.Theme.Text
    x.Font = Enum.Font.SourceSansBold
    x.TextSize = 11
    x.BorderSizePixel = 0
    x.AutoButtonColor = false
    Instance.new("UICorner", x).CornerRadius = UDim.new(0, 4)
    x.MouseButton1Click:Connect(function() gui:Destroy() end)

    local content = Instance.new("Frame", main)
    content.Size = UDim2.new(1, -8, 1, -32)
    content.Position = UDim2.new(0, 4, 0, 28)
    content.BackgroundTransparency = 1

    return gui, content
end

-- ============ IDENTITY CARD ============
local function openIdentity(item, isMine)
    local isMobile = game:GetService("UserInputService").TouchEnabled
    local _, content = mkPopup("Script Identity", isMobile and 320 or 380, isMobile and 380 or 440)

    local Y = 8
    local function addLine(label, value, col)
        local l = Instance.new("TextLabel", content)
        l.Size = UDim2.new(1, -20, 0, 20)
        l.Position = UDim2.new(0, 10, 0, Y)
        l.BackgroundTransparency = 1
        l.Text = label..": "..tostring(value)
        l.TextColor3 = col or Settings.Theme.Text
        l.Font = Enum.Font.SourceSans
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        Y = Y + 22
    end

    -- Title
    local t = Instance.new("TextLabel", content)
    t.Size = UDim2.new(1, -20, 0, 26)
    t.Position = UDim2.new(0, 10, 0, Y)
    t.BackgroundTransparency = 1
    t.Text = item.name or "?"
    t.TextColor3 = Settings.Theme.Text
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = 18
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextTruncate = Enum.TextTruncate.AtEnd
    Y = Y + 32

    addLine("Author", item.author or "unknown")
    addLine("Description", item.description or "(none)")

    local tags = ""
    if type(item.tags) == "table" and #item.tags > 0 then
        tags = "#"..table.concat(item.tags, "  #")
    end
    addLine("Tags", tags ~= "" and tags or "(none)")

    if item.created then
        addLine("Created", os.date("%Y-%m-%d %H:%M", item.created))
    else
        addLine("Created", "unknown")
    end

    local size = item.code and #item.code or item.size or "?"
    addLine("Size", tostring(size).." chars")

    if item.locked then
        addLine("Protection", "LOCKED (copy disabled)", Settings.Theme.Important)
    else
        addLine("Protection", "open", Color3.fromRGB(120,200,140))
    end

    addLine("Source", isMine and "My Scripts (local)" or "Community (repo)")

    -- Buttons
    local by = 1
    local function mkBtn(text, x, w, col, cb)
        local b = Instance.new("TextButton", content)
        b.Size = UDim2.new(0, w, 0, 30)
        b.Position = UDim2.new(0, x, 1, -42)
        b.BackgroundColor3 = col or Settings.Theme.Button
        b.Text = text
        b.TextColor3 = Settings.Theme.Text
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 12
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    local function fetchCode(cb)
        if isMine or item.code then
            cb(item.code or "", nil)
            return
        end
        if not item.path then cb(nil, "no path") return end
        task.spawn(function()
            local ok, data = pcall(function() return game:HttpGet(BASE..item.path.."?t="..tostring(tick())) end)
            if not ok or not data then cb(nil, "fetch failed") return end
            cb(data, nil)
        end)
    end

    local runBtn = mkBtn("Run", 10, 100, Settings.Theme.ListSelection, function() end)
    runBtn.MouseButton1Click:Connect(function()
        runBtn.Text = "..."
        fetchCode(function(code, err)
            if err then runBtn.Text = "Run"; statusLbl.Text = "❌ "..err; return end
            local ok, res = DS:RunScript(code, item.name)
            if ok then
                runBtn.Text = "✓ Ran"
            else
                runBtn.Text = "✗"
                statusLbl.Text = "❌ "..tostring(res):sub(1,60)
            end
            task.wait(1.4)
            runBtn.Text = "Run"
        end)
    end)

    local copyBtn = mkBtn("Copy", 118, 100, Settings.Theme.Button, function() end)
    if item.locked then
        copyBtn.Text = "🔒 Locked"
        copyBtn.BackgroundColor3 = Settings.Theme.Button
    else
        copyBtn.MouseButton1Click:Connect(function()
            fetchCode(function(code, err)
                if err then statusLbl.Text = "❌ "..err; return end
                local ok = copy(code)
                copyBtn.Text = ok and "✓ Copied" or "✗"
                task.wait(1.4)
                copyBtn.Text = "Copy"
            end)
        end)
    end

    local closeBtn = mkBtn("Close", 226, 100, Settings.Theme.Button, function()
        local top = content.Parent
        if top and top.Parent then top.Parent:Destroy() end
    end)
end

-- ============ CREATE ============
local function openCreate()
    local isMobile = game:GetService("UserInputService").TouchEnabled
    local _, content = mkPopup("Create New Script", isMobile and 340 or 420, isMobile and 500 or 560)

    local function mkField(y, label, placeholder)
        local l = Instance.new("TextLabel", content)
        l.Size = UDim2.new(0, 90, 0, 18)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Settings.Theme.PlaceholderText
        l.Font = Enum.Font.SourceSansBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left

        local b = Instance.new("TextBox", content)
        b.Size = UDim2.new(1, -110, 0, 22)
        b.Position = UDim2.new(0, 100, 0, y - 2)
        b.BackgroundColor3 = Settings.Theme.TextBox
        b.BorderSizePixel = 0
        b.Text = ""
        b.PlaceholderText = placeholder or ""
        b.PlaceholderColor3 = Settings.Theme.PlaceholderText
        b.TextColor3 = Settings.Theme.Text
        b.Font = Enum.Font.Code
        b.TextSize = 11
        b.ClearTextOnFocus = false
        b.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        local p = Instance.new("UIPadding", b)
        p.PaddingLeft = UDim.new(0, 6)
        return b
    end

    local nameBox = mkField(10, "Name *", "My Cool Script")
    local authorBox = mkField(36, "Author", plr.Name or "anon")
    local descBox = mkField(62, "Description", "short desc")
    local tagsBox = mkField(88, "Tags (,)", "utility, combat")

    -- Lock checkbox
    local lockRow = Instance.new("Frame", content)
    lockRow.Size = UDim2.new(1, -20, 0, 22)
    lockRow.Position = UDim2.new(0, 10, 0, 116)
    lockRow.BackgroundTransparency = 1

    local lockLbl = Instance.new("TextLabel", lockRow)
    lockLbl.Size = UDim2.new(1, -130, 1, 0)
    lockLbl.BackgroundTransparency = 1
    lockLbl.Text = "🔒 حماية السكربت (منع النسخ)"
    lockLbl.TextColor3 = Settings.Theme.Text
    lockLbl.Font = Enum.Font.SourceSansBold
    lockLbl.TextSize = 11
    lockLbl.TextXAlignment = Enum.TextXAlignment.Left

    local locked = false
    local lockBtn = Instance.new("TextButton", lockRow)
    lockBtn.Size = UDim2.new(0, 50, 0, 20)
    lockBtn.Position = UDim2.new(1, -56, 0, 1)
    lockBtn.BackgroundColor3 = Settings.Theme.Button
    lockBtn.Text = "OFF"
    lockBtn.TextColor3 = Settings.Theme.Text
    lockBtn.Font = Enum.Font.SourceSansBold
    lockBtn.TextSize = 11
    lockBtn.BorderSizePixel = 0
    lockBtn.AutoButtonColor = false
    Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 4)
    lockBtn.MouseButton1Click:Connect(function()
        locked = not locked
        lockBtn.Text = locked and "ON" or "OFF"
        lockBtn.BackgroundColor3 = locked and Settings.Theme.Important or Settings.Theme.Button
    end)

    -- Code area
    local codeLabel = Instance.new("TextLabel", content)
    codeLabel.Size = UDim2.new(1, -20, 0, 16)
    codeLabel.Position = UDim2.new(0, 10, 0, 144)
    codeLabel.BackgroundTransparency = 1
    codeLabel.Text = "Code *  (max "..MAX_CHARS.." chars)"
    codeLabel.TextColor3 = Settings.Theme.PlaceholderText
    codeLabel.Font = Enum.Font.SourceSansBold
    codeLabel.TextSize = 11
    codeLabel.TextXAlignment = Enum.TextXAlignment.Left

    local holder = Instance.new("Frame", content)
    holder.Size = UDim2.new(1, -20, 1, -250)
    holder.Position = UDim2.new(0, 10, 0, 164)
    holder.BackgroundColor3 = Settings.Theme.Main2
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 5)

    local code = Lib.CodeFrame.new()
    code.Frame.Position = UDim2.new(0, 2, 0, 2)
    code.Frame.Size = UDim2.new(1, -4, 1, -4)
    code.Frame.Parent = holder
    code:SetText("-- your script here\nprint('hello')")

    local counter = Instance.new("TextLabel", content)
    counter.Size = UDim2.new(1, -20, 0, 14)
    counter.Position = UDim2.new(0, 10, 1, -84)
    counter.BackgroundTransparency = 1
    counter.Text = "0 / "..MAX_CHARS
    counter.TextColor3 = Settings.Theme.PlaceholderText
    counter.Font = Enum.Font.Code
    counter.TextSize = 10
    counter.TextXAlignment = Enum.TextXAlignment.Left

    task.spawn(function()
        while counter.Parent do
            local n = #code:GetText()
            counter.Text = n.." / "..MAX_CHARS
            counter.TextColor3 = (n > MAX_CHARS) and Settings.Theme.Important or Settings.Theme.PlaceholderText
            task.wait(0.4)
        end
    end)

    local status = Instance.new("TextLabel", content)
    status.Size = UDim2.new(1, -20, 0, 16)
    status.Position = UDim2.new(0, 10, 1, -66)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Settings.Theme.PlaceholderText
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function close()
        local top = content.Parent
        if top and top.Parent then top.Parent:Destroy() end
    end

    local sb = Instance.new("TextButton", content)
    sb.Size = UDim2.new(0, 120, 0, 30)
    sb.Position = UDim2.new(0, 10, 1, -42)
    sb.BackgroundColor3 = Settings.Theme.ListSelection
    sb.Text = "Save Script"
    sb.TextColor3 = Settings.Theme.Text
    sb.Font = Enum.Font.SourceSansBold
    sb.TextSize = 12
    sb.BorderSizePixel = 0
    Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 5)
    sb.MouseButton1Click:Connect(function()
        local nm = nameBox.Text
        if nm == "" then status.Text = "❌ name required" return end
        local cd = code:GetText()
        if cd == "" then status.Text = "❌ code empty" return end
        if #cd > MAX_CHARS then
            status.Text = "❌ code too long: "..#cd.." / "..MAX_CHARS
            return
        end
        local bl = scanForNetwork(cd)
        if bl then status.Text = "❌ blocked: "..bl return end
        local tags = {}
        for t in tagsBox.Text:gmatch("[^,]+") do
            t = t:gsub("^%s+",""):gsub("%s+$","")
            if t ~= "" then table.insert(tags, t) end
        end
        table.insert(mine, {
            name = nm, author = authorBox.Text,
            description = descBox.Text, tags = tags,
            code = cd, created = os.time(),
            locked = locked, size = #cd,
        })
        if DS:SaveMine() then
            status.Text = "✅ saved"
            task.wait(0.7)
            close()
            DS:RenderList()
        else
            status.Text = "❌ save failed"
        end
    end)

    local cb = Instance.new("TextButton", content)
    cb.Size = UDim2.new(0, 100, 0, 30)
    cb.Position = UDim2.new(1, -110, 1, -42)
    cb.BackgroundColor3 = Settings.Theme.Button
    cb.Text = "Cancel"
    cb.TextColor3 = Settings.Theme.Text
    cb.Font = Enum.Font.SourceSansBold
    cb.TextSize = 12
    cb.BorderSizePixel = 0
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(close)
end

-- ============ IMPORT ============
local function openImport()
    local isMobile = game:GetService("UserInputService").TouchEnabled
    local _, content = mkPopup("Import Script from URL", isMobile and 340 or 420, isMobile and 260 or 300)

    local desc = Instance.new("TextLabel", content)
    desc.Size = UDim2.new(1, -20, 0, 40)
    desc.Position = UDim2.new(0, 10, 0, 6)
    desc.BackgroundTransparency = 1
    desc.Text = "Allowed domains: raw.githubusercontent.com · pastebin.com/raw · raw.githack.com · cdn.jsdelivr.net"
    desc.TextColor3 = Settings.Theme.PlaceholderText
    desc.Font = Enum.Font.SourceSans
    desc.TextSize = 11
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left

    local urlBox = Instance.new("TextBox", content)
    urlBox.Size = UDim2.new(1, -20, 0, 30)
    urlBox.Position = UDim2.new(0, 10, 0, 52)
    urlBox.BackgroundColor3 = Settings.Theme.TextBox
    urlBox.BorderSizePixel = 0
    urlBox.Text = ""
    urlBox.PlaceholderText = "https://raw.githubusercontent.com/..."
    urlBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
    urlBox.TextColor3 = Settings.Theme.Text
    urlBox.Font = Enum.Font.Code
    urlBox.TextSize = 11
    urlBox.ClearTextOnFocus = false
    urlBox.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", urlBox).CornerRadius = UDim.new(0, 4)

    local status = Instance.new("TextLabel", content)
    status.Size = UDim2.new(1, -20, 0, 40)
    status.Position = UDim2.new(0, 10, 0, 90)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Settings.Theme.PlaceholderText
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function close()
        local top = content.Parent
        if top and top.Parent then top.Parent:Destroy() end
    end

    local fb = Instance.new("TextButton", content)
    fb.Size = UDim2.new(0, 130, 0, 30)
    fb.Position = UDim2.new(0, 10, 1, -42)
    fb.BackgroundColor3 = Settings.Theme.ListSelection
    fb.Text = "Fetch & Save"
    fb.TextColor3 = Settings.Theme.Text
    fb.Font = Enum.Font.SourceSansBold
    fb.TextSize = 12
    fb.BorderSizePixel = 0
    Instance.new("UICorner", fb).CornerRadius = UDim.new(0, 5)
    fb.MouseButton1Click:Connect(function()
        local url = urlBox.Text
        if not url:match("^https?://") then status.Text = "❌ invalid URL" return end
        if not (url:find("raw%.githubusercontent%.com") or url:find("pastebin%.com/raw")
            or url:find("raw%.githack%.com") or url:find("cdn%.jsdelivr%.net")) then
            status.Text = "❌ domain not allowed"
            return
        end
        status.Text = "⏳ fetching..."
        task.spawn(function()
            local ok, data = pcall(function() return game:HttpGet(url) end)
            if not ok or not data then status.Text = "❌ fetch failed" return end
            if #data < 10 then status.Text = "❌ file too small" return end
            if #data > MAX_CHARS then status.Text = "❌ file too large (> "..MAX_CHARS..")" return end
            local bl = scanForNetwork(data)
            if bl then status.Text = "❌ blocked: "..bl return end
            local nm = url:match("([^/]+)%.lua") or ("imported_"..tostring(os.time()))
            table.insert(mine, {
                name = nm, author = "imported",
                description = "imported from "..url:sub(1,40),
                tags = {"imported"}, code = data,
                created = os.time(), size = #data,
            })
            DS:SaveMine()
            status.Text = "✅ saved: "..nm
            task.wait(0.7)
            close()
            DS:RenderList()
        end)
    end)

    local cb = Instance.new("TextButton", content)
    cb.Size = UDim2.new(0, 100, 0, 30)
    cb.Position = UDim2.new(1, -110, 1, -42)
    cb.BackgroundColor3 = Settings.Theme.Button
    cb.Text = "Cancel"
    cb.TextColor3 = Settings.Theme.Text
    cb.Font = Enum.Font.SourceSansBold
    cb.TextSize = 12
    cb.BorderSizePixel = 0
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(close)

end

-- ============ LIST ============
local function clearList()
    if not listFrame then return end
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

local function matches(item)
    if searchText == "" then return true end
    local q = searchText:lower()
    local n = (item.name or ""):lower()
    local a = (item.author or ""):lower()
    local d = (item.description or ""):lower()
    local t = ""
    if type(item.tags) == "table" then t = table.concat(item.tags, " "):lower() end
    return n:find(q,1,true) or a:find(q,1,true) or d:find(q,1,true) or t:find(q,1,true)
end

local function makeRow(parent, item, isMine)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -6, 0, 76)
    row.BackgroundColor3 = Settings.Theme.Main2
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    -- main content button (opens identity card)
    local click = Instance.new("TextButton", row)
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.ZIndex = 1
    click.MouseButton1Click:Connect(function()
        openIdentity(item, isMine)
    end)

    -- name
    local n = Instance.new("TextLabel", row)
    n.Size = UDim2.new(1, -70, 0, 18)
    n.Position = UDim2.new(0, 6, 0, 4)
    n.BackgroundTransparency = 1
    local lockMark = item.locked and " 🔒" or ""
    n.Text = (item.name or "?")..lockMark
    n.TextColor3 = Settings.Theme.Text
    n.Font = Enum.Font.SourceSansBold
    n.TextSize = 13
    n.TextXAlignment = Enum.TextXAlignment.Left
    n.TextTruncate = Enum.TextTruncate.AtEnd
    n.ZIndex = 2

    local au = Instance.new("TextLabel", row)
    au.Size = UDim2.new(1, -70, 0, 14)
    au.Position = UDim2.new(0, 6, 0, 22)
    au.BackgroundTransparency = 1
    au.Text = "by "..(item.author or "unknown")
    au.TextColor3 = Settings.Theme.PlaceholderText
    au.Font = Enum.Font.SourceSans
    au.TextSize = 11
    au.TextXAlignment = Enum.TextXAlignment.Left
    au.ZIndex = 2

    local d = Instance.new("TextLabel", row)
    d.Size = UDim2.new(1, -70, 0, 14)
    d.Position = UDim2.new(0, 6, 0, 38)
    d.BackgroundTransparency = 1
    d.Text = item.description or "(no description)"
    d.TextColor3 = Settings.Theme.PlaceholderText
    d.Font = Enum.Font.SourceSans
    d.TextSize = 11
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextTruncate = Enum.TextTruncate.AtEnd
    d.ZIndex = 2

    -- size + locked indicator
    local meta = Instance.new("TextLabel", row)
    meta.Size = UDim2.new(1, -70, 0, 12)
    meta.Position = UDim2.new(0, 6, 0, 56)
    meta.BackgroundTransparency = 1
    local sz = item.code and #item.code or item.size or "?"
    local prot = item.locked and " · 🔒 locked" or ""
    meta.Text = tostring(sz).." chars"..prot
    meta.TextColor3 = Settings.Theme.PlaceholderText
    meta.Font = Enum.Font.Code
    meta.TextSize = 10
    meta.TextXAlignment = Enum.TextXAlignment.Left
    meta.ZIndex = 2

    -- open button (arrow)
    local open = Instance.new("TextButton", row)
    open.Size = UDim2.new(0, 30, 0, 26)
    open.Position = UDim2.new(1, -36, 0, 4)
    open.BackgroundColor3 = Settings.Theme.ListSelection
    open.Text = ">"
    open.TextColor3 = Settings.Theme.Text
    open.Font = Enum.Font.SourceSansBold
    open.TextSize = 14
    open.BorderSizePixel = 0
    open.AutoButtonColor = false
    open.ZIndex = 3
    Instance.new("UICorner", open).CornerRadius = UDim.new(0, 4)
    open.MouseButton1Click:Connect(function() openIdentity(item, isMine) end)

    -- delete for mine
    if isMine then
        local del = Instance.new("TextButton", row)
        del.Size = UDim2.new(0, 30, 0, 26)
        del.Position = UDim2.new(1, -72, 0, 4)
        del.BackgroundColor3 = Settings.Theme.Button
        del.Text = "X"
        del.TextColor3 = Settings.Theme.Important
        del.Font = Enum.Font.SourceSansBold
        del.TextSize = 13
        del.BorderSizePixel = 0
        del.AutoButtonColor = false
        del.ZIndex = 3
        Instance.new("UICorner", del).CornerRadius = UDim.new(0, 4)
        del.MouseButton1Click:Connect(function()
            for i, s in ipairs(mine) do
                if s == item then table.remove(mine, i) break end
            end
            DS:SaveMine()
            clearList()
            DS:RenderList()
        end)
    end
end

function DS:RenderList()
    clearList()
    local list = {}
    if currentTab == "community" then
        for _, it in ipairs(community) do table.insert(list, {item=it, isMine=false}) end
    elseif currentTab == "mine" then
        for _, it in ipairs(mine) do table.insert(list, {item=it, isMine=true}) end
    else
        for _, it in ipairs(community) do table.insert(list, {item=it, isMine=false}) end
        for _, it in ipairs(mine) do table.insert(list, {item=it, isMine=true}) end
    end
    local count = 0
    for _, e in ipairs(list) do
        if matches(e.item) then
            makeRow(listFrame, e.item, e.isMine)
            count = count + 1
        end
    end
    statusLbl.Text = "showing "..count.." / "..#list
end

DS.Init = function()
    DS:LoadMine()

    window = Lib.Window.new()
    window:SetTitle("Developer Scripts")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 340 or 420, isMobile and 480 or 560)
    DS.Window = window
    local content = window.GuiElems.Content

    tabRow = Instance.new("Frame", content)
    tabRow.Size = UDim2.new(1, -8, 0, 26)
    tabRow.Position = UDim2.new(0, 4, 0, 4)
    tabRow.BackgroundTransparency = 1
    local tLay = Instance.new("UIListLayout", tabRow)
    tLay.FillDirection = Enum.FillDirection.Horizontal
    tLay.Padding = UDim.new(0, 3)

    local function mkTab(text, key, w)
        local b = Instance.new("TextButton", tabRow)
        b.Size = UDim2.new(0, w or 90, 1, 0)
        b.BackgroundColor3 = Settings.Theme.Main2
        b.Text = text
        b.TextColor3 = Settings.Theme.PlaceholderText
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function()
            currentTab = key
            for _, c in ipairs(tabRow:GetChildren()) do
                if c:IsA("TextButton") then
                    c.BackgroundColor3 = Settings.Theme.Main2
                    c.TextColor3 = Settings.Theme.PlaceholderText
                end
            end
            b.BackgroundColor3 = Settings.Theme.ListSelection
            b.TextColor3 = Settings.Theme.Text
            DS:RenderList()
        end)
        return b
    end

    local tC = mkTab("Community", "community", 100)
    mkTab("My Scripts", "mine", 90)
    mkTab("All", "all", 60)
    tC.BackgroundColor3 = Settings.Theme.ListSelection
    tC.TextColor3 = Settings.Theme.Text

    local row2 = Instance.new("Frame", content)
    row2.Size = UDim2.new(1, -8, 0, 30)
    row2.Position = UDim2.new(0, 4, 0, 34)
    row2.BackgroundTransparency = 1

    searchBox = Instance.new("TextBox", row2)
    searchBox.Size = UDim2.new(1, -230, 1, 0)
    searchBox.BackgroundColor3 = Settings.Theme.TextBox
    searchBox.BorderSizePixel = 0
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search..."
    searchBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
    searchBox.TextColor3 = Settings.Theme.Text
    searchBox.Font = Enum.Font.SourceSans
    searchBox.TextSize = 12
    searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)
    local sp = Instance.new("UIPadding", searchBox)
    sp.PaddingLeft = UDim.new(0, 6)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchText = searchBox.Text
        DS:RenderList()
    end)

    local function mkBtn(text, x, w, cb)
        local b = Instance.new("TextButton", row2)
        b.Size = UDim2.new(0, w, 1, 0)
        b.Position = UDim2.new(1, x, 0, 0)
        b.BackgroundColor3 = Settings.Theme.Button
        b.Text = text
        b.TextColor3 = Settings.Theme.Text
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    mkBtn("+ Create", -220, 70, function()
        if statusLbl then statusLbl.Text = "[click] create pressed" end
        local ok, err = pcall(openCreate)
        if not ok and statusLbl then statusLbl.Text = "ERR: "..tostring(err):sub(1,80) end
    end)
    mkBtn("Import", -145, 70, function()
        if statusLbl then statusLbl.Text = "[click] import pressed" end
        local ok, err = pcall(openImport)
        if not ok and statusLbl then statusLbl.Text = "ERR: "..tostring(err):sub(1,80) end
    end)
    mkBtn("Refresh", -70, 66, function()
        if statusLbl then statusLbl.Text = "loading..." end
        task.spawn(function()
            local ok = DS:FetchCommunity()
            if statusLbl then statusLbl.Text = ok and ("community: "..#community.." · mine: "..#mine) or "fetch failed" end
            DS:RenderList()
        end)
    end)

    statusLbl = Instance.new("TextLabel", content)
    statusLbl.Size = UDim2.new(1, -8, 0, 16)
    statusLbl.Position = UDim2.new(0, 4, 0, 68)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "ready"
    statusLbl.TextColor3 = Settings.Theme.PlaceholderText
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextSize = 10
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left

    listFrame = Instance.new("ScrollingFrame", content)
    listFrame.Size = UDim2.new(1, -8, 1, -92)
    listFrame.Position = UDim2.new(0, 4, 0, 88)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 5
    listFrame.ScrollBarImageColor3 = Settings.Theme.Outline1
    listFrame.CanvasSize = UDim2.new(0,0,0,0)
    listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lLay = Instance.new("UIListLayout", listFrame)
    lLay.Padding = UDim.new(0, 6)
    lLay.SortOrder = Enum.SortOrder.LayoutOrder

    task.spawn(function()
        if statusLbl then statusLbl.Text = "fetching community..." end
        local ok = DS:FetchCommunity()
        if statusLbl then
            statusLbl.Text = ok and ("community: "..#community.." · mine: "..#mine) or ("mine: "..#mine.." (fetch failed)")
        end
        DS:RenderList()
    end)
end

return DS
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

