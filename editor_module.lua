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
    out.BackgroundColor3 = Settings.Theme.Main1
    out.BorderSizePixel = 0
    out.ScrollBarThickness = 5
    out.ScrollBarImageColor3 = Settings.Theme.Outline1
    out.CanvasSize = UDim2.new(0,0,0,0)
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
    makeMBtn("Clear", function() codeFrame:SetText("") end, 46)

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

