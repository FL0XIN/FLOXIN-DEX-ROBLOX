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

