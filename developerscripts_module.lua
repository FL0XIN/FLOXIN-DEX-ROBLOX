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

local function clearList()
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
    row.Size = UDim2.new(1, -6, 0, 82)
    row.BackgroundColor3 = Settings.Theme.Main2
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local n = Instance.new("TextLabel", row)
    n.Size = UDim2.new(1, -12, 0, 18)
    n.Position = UDim2.new(0, 6, 0, 4)
    n.BackgroundTransparency = 1
    n.Text = (item.name or "?").."  ·  "..(item.author or "?")
    n.TextColor3 = Settings.Theme.Text
    n.Font = Enum.Font.SourceSansBold
    n.TextSize = 13
    n.TextXAlignment = Enum.TextXAlignment.Left
    n.TextTruncate = Enum.TextTruncate.AtEnd

    local d = Instance.new("TextLabel", row)
    d.Size = UDim2.new(1, -12, 0, 14)
    d.Position = UDim2.new(0, 6, 0, 22)
    d.BackgroundTransparency = 1
    d.Text = item.description or "(no description)"
    d.TextColor3 = Settings.Theme.PlaceholderText
    d.Font = Enum.Font.SourceSans
    d.TextSize = 11
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextTruncate = Enum.TextTruncate.AtEnd

    local tg = Instance.new("TextLabel", row)
    tg.Size = UDim2.new(1, -12, 0, 14)
    tg.Position = UDim2.new(0, 6, 0, 38)
    tg.BackgroundTransparency = 1
    local ts = ""
    if type(item.tags) == "table" and #item.tags > 0 then
        ts = "#"..table.concat(item.tags, " #")
    end
    tg.Text = ts
    tg.TextColor3 = Settings.Theme.PlaceholderText
    tg.Font = Enum.Font.Code
    tg.TextSize = 10
    tg.TextXAlignment = Enum.TextXAlignment.Left
    tg.TextTruncate = Enum.TextTruncate.AtEnd

    local function mkBtn(text, x, w, cb)
        local b = Instance.new("TextButton", row)
        b.Size = UDim2.new(0, w, 0, 22)
        b.Position = UDim2.new(1, x, 0, 54)
        b.BackgroundColor3 = Settings.Theme.Button
        b.Text = text
        b.TextColor3 = Settings.Theme.Text
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    local function loadCode(cb)
        if isMine or item.code then cb(item.code or "", nil) return end
        if not item.path then cb(nil, "no path") return end
        task.spawn(function()
            local ok, data = pcall(function() return game:HttpGet(BASE..item.path.."?t="..tostring(tick())) end)
            if not ok or not data then cb(nil, "fetch failed") return end
            cb(data, nil)
        end)
    end

    mkBtn("Run", -232, 62, Settings.Theme.ListSelection, function() end)
    for _, c in ipairs(row:GetChildren()) do
        if c:IsA("TextButton") and c.Text == "Run" then
            c.BackgroundColor3 = Settings.Theme.ListSelection
            c.MouseButton1Click:Connect(function()
                loadCode(function(code, err)
                    if err then statusLbl.Text = "❌ "..err return end
                    local ok, res = DS:RunScript(code, item.name)
                    statusLbl.Text = ok and ("✅ ran: "..(item.name or "?")) or ("❌ "..tostring(res):sub(1,70))
                end)
            end)
        end
    end

    mkBtn("View", -168, 62, nil, function()
        loadCode(function(code, err)
            if err then statusLbl.Text = "❌ "..err return end
            if Apps.Editor then
                Apps.Editor:Log("=== "..(item.name or "?").." ===", Color3.fromRGB(200,150,255))
                Apps.Editor:Log(code, Color3.fromRGB(220,220,220))
                if Apps.Editor.Window then Apps.Editor.Window:Show() end
            else
                if setclipboard then pcall(setclipboard, code) end
                statusLbl.Text = "📋 copied"
            end
        end)
    end)

    mkBtn("Copy", -104, 62, nil, function()
        loadCode(function(code, err)
            if err then statusLbl.Text = "❌ "..err return end
            local okc = false
            if env and env.setclipboard then pcall(function() env.setclipboard(code) okc=true end) end
            if not okc and setclipboard then pcall(function() setclipboard(code) okc=true end) end
            statusLbl.Text = okc and "📋 copied" or "❌ no clipboard"
        end)
    end)

    if isMine then
        mkBtn("Del", -40, 36, Settings.Theme.Important, function()
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

local function openCreate()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DS_Create"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    Lib.ShowGui(gui)

    local win = Instance.new("Frame", gui)
    win.Size = UDim2.new(0, 400, 0, 470)
    win.Position = UDim2.new(0.5, -200, 0.5, -235)
    win.BackgroundColor3 = Settings.Theme.Main1
    win.BorderSizePixel = 0
    win.Active = true
    win.Draggable = true
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", win)
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Create New Script"
    title.TextColor3 = Settings.Theme.Text
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left

    local function mkField(y, label, placeholder)
        local l = Instance.new("TextLabel", win)
        l.Size = UDim2.new(0, 90, 0, 18)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = Settings.Theme.PlaceholderText
        l.Font = Enum.Font.SourceSansBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left

        local b = Instance.new("TextBox", win)
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

    local nameBox = mkField(36, "Name *", "My Cool Script")
    local authorBox = mkField(62, "Author", plr.Name or "anon")
    local descBox = mkField(88, "Description", "short desc")
    local tagsBox = mkField(114, "Tags (,)", "utility, combat")

    local codeLabel = Instance.new("TextLabel", win)
    codeLabel.Size = UDim2.new(1, -20, 0, 16)
    codeLabel.Position = UDim2.new(0, 10, 0, 140)
    codeLabel.BackgroundTransparency = 1
    codeLabel.Text = "Code *"
    codeLabel.TextColor3 = Settings.Theme.PlaceholderText
    codeLabel.Font = Enum.Font.SourceSansBold
    codeLabel.TextSize = 11
    codeLabel.TextXAlignment = Enum.TextXAlignment.Left

    local holder = Instance.new("Frame", win)
    holder.Size = UDim2.new(1, -20, 0, 230)
    holder.Position = UDim2.new(0, 10, 0, 158)
    holder.BackgroundColor3 = Settings.Theme.Main2
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 5)

    local code = Lib.CodeFrame.new()
    code.Frame.Position = UDim2.new(0, 2, 0, 2)
    code.Frame.Size = UDim2.new(1, -4, 1, -4)
    code.Frame.Parent = holder
    code:SetText("-- your script here\nprint('hello')")

    local status = Instance.new("TextLabel", win)
    status.Size = UDim2.new(1, -20, 0, 16)
    status.Position = UDim2.new(0, 10, 0, 396)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Settings.Theme.PlaceholderText
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function close() gui:Destroy() end

    local sb = Instance.new("TextButton", win)
    sb.Size = UDim2.new(0, 110, 0, 30)
    sb.Position = UDim2.new(0, 10, 1, -40)
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

    local cb = Instance.new("TextButton", win)
    cb.Size = UDim2.new(0, 100, 0, 30)
    cb.Position = UDim2.new(1, -110, 1, -40)
    cb.BackgroundColor3 = Settings.Theme.Button
    cb.Text = "Cancel"
    cb.TextColor3 = Settings.Theme.Text
    cb.Font = Enum.Font.SourceSansBold
    cb.TextSize = 12
    cb.BorderSizePixel = 0
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(close)
end

local function openImport()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DS_Import"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999999
    Lib.ShowGui(gui)

    local win = Instance.new("Frame", gui)
    win.Size = UDim2.new(0, 400, 0, 260)
    win.Position = UDim2.new(0.5, -200, 0.5, -130)
    win.BackgroundColor3 = Settings.Theme.Main1
    win.BorderSizePixel = 0
    win.Active = true
    win.Draggable = true
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", win)
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Import Script from URL"
    title.TextColor3 = Settings.Theme.Text
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left

    local desc = Instance.new("TextLabel", win)
    desc.Size = UDim2.new(1, -20, 0, 32)
    desc.Position = UDim2.new(0, 10, 0, 32)
    desc.BackgroundTransparency = 1
    desc.Text = "Allowed: raw.githubusercontent.com · pastebin.com/raw · cdn.jsdelivr.net · raw.githack.com"
    desc.TextColor3 = Settings.Theme.PlaceholderText
    desc.Font = Enum.Font.SourceSans
    desc.TextSize = 11
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left

    local urlBox = Instance.new("TextBox", win)
    urlBox.Size = UDim2.new(1, -20, 0, 30)
    urlBox.Position = UDim2.new(0, 10, 0, 70)
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

    local status = Instance.new("TextLabel", win)
    status.Size = UDim2.new(1, -20, 0, 30)
    status.Position = UDim2.new(0, 10, 0, 108)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Settings.Theme.PlaceholderText
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function close() gui:Destroy() end

    local fb = Instance.new("TextButton", win)
    fb.Size = UDim2.new(0, 130, 0, 30)
    fb.Position = UDim2.new(0, 10, 1, -40)
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
            if #data < 10 or #data > 200000 then status.Text = "❌ size invalid" return end
            local bl = scanForNetwork(data)
            if bl then status.Text = "❌ blocked: "..bl return end
            local nm = url:match("([^/]+)%.lua") or ("imported_"..tostring(os.time()))
            table.insert(mine, {
                name = nm, author = "imported",
                description = "imported from "..url:sub(1,40),
                tags = {"imported"}, code = data, created = os.time(),
            })
            DS:SaveMine()
            status.Text = "✅ saved: "..nm
            task.wait(0.7)
            close()
            DS:RenderList()
        end)
    end)

    local cb = Instance.new("TextButton", win)
    cb.Size = UDim2.new(0, 100, 0, 30)
    cb.Position = UDim2.new(1, -110, 1, -40)
    cb.BackgroundColor3 = Settings.Theme.Button
    cb.Text = "Cancel"
    cb.TextColor3 = Settings.Theme.Text
    cb.Font = Enum.Font.SourceSansBold
    cb.TextSize = 12
    cb.BorderSizePixel = 0
    Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5)
    cb.MouseButton1Click:Connect(close)
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
    local tM = mkTab("My Scripts", "mine", 90)
    local tA = mkTab("All", "all", 60)
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
        b.AutoButtonClick = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    mkBtn("+ Create", -220, 70, openCreate)
    mkBtn("Import", -145, 70, openImport)
    mkBtn("Refresh", -70, 66, function()
        statusLbl.Text = "⏳ loading..."
        task.spawn(function()
            local ok = DS:FetchCommunity()
            statusLbl.Text = ok and ("✅ "..#community.." community") or "❌ fetch failed"
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
        statusLbl.Text = "⏳ fetching community..."
        local ok = DS:FetchCommunity()
        statusLbl.Text = ok and ("✅ "..#community.." community · "..#mine.." mine") or ("⚠ "..#mine.." mine (community fetch failed)")
        DS:RenderList()
    end)
end

return DS
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

