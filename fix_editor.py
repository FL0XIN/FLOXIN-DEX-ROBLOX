import sys

# ============ STEP 1: Remove Editor from dex.source.lua ============
with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

orig = len(src)
print(f"[i] source before: {orig}")

if '["Editor"] = function' in src:
    print("[i] removing existing Editor...")
    start = src.find('["Editor"] = function')
    end_pos = src.find('["Console"] = function()', start)
    if start > 0 and end_pos > start:
        src = src[:start] + src[end_pos:]
        print(f"    module removed ({end_pos - start} chars)")
    src = src.replace(',"Editor"}', '}')
    src = src.replace('\n\t\tEditor = Apps.Editor', '')
    src = src.replace('\n\t\t\tEditor = Editor,', '')
    src = src.replace('\n\t\tEditor.Init()', '')
    src = src.replace('\n\t\tMain.CreateApp({Name = "Editor", IconMap = Main.MiscIcons, Icon = "ViewScript", Window = Editor.Window})', '')
    print(f"    source after cleanup: {len(src)}")

if '["Editor"] = function' in src:
    print("ABORT: Editor still in source")
    sys.exit(1)

# ============ STEP 2: Patch editor_module.lua ============
with open('editor_module.lua', 'r', encoding='utf-8') as f:
    module = f.read()

mc_start = module.find('-- CONSOLE (real code editor via Lib.CodeFrame)')
mc_end = module.find('-- SNIPPETS', mc_start)
if mc_start < 0 or mc_end < 0:
    print(f"ABORT: buildConsole markers not found ({mc_start}, {mc_end})")
    sys.exit(1)
print(f"[i] replacing Console section: {mc_end - mc_start} chars")

NEW_CONSOLE = r'''-- CONSOLE (real code editor + mobile toolbar + responsive)
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

'''

module = module[:mc_start] + NEW_CONSOLE + module[mc_end:]
with open('editor_module.lua', 'w', encoding='utf-8') as f:
    f.write(module)
print(f"[i] module patched: {len(module)}")

# ============ STEP 3: Re-merge Editor ============
if '["Editor"] = function' in src:
    print("ABORT: src still has Editor"); sys.exit(1)

MARKER = '["Console"] = function()'
if src.count(MARKER) != 1:
    print(f"ABORT: marker = {src.count(MARKER)}"); sys.exit(1)
src = src.replace(MARKER, module + MARKER, 1)
print("[1] editor inserted")

OLD = '"ModelViewer","BulkCopier","Browser","PlayersExplorer"}'
NEW = '"ModelViewer","BulkCopier","Browser","PlayersExplorer","Editor"}'
if src.count(OLD) != 1:
    print(f"ABORT: ModuleList = {src.count(OLD)}"); sys.exit(1)
src = src.replace(OLD, NEW, 1)
print("[2] ModuleList")

OLD = 'PlayersExplorer = Apps.PlayersExplorer'
src = src.replace(OLD, OLD + '\n\t\tEditor = Apps.Editor', 1)
print("[3] apps")

OLD = 'PlayersExplorer = PlayersExplorer,'
src = src.replace(OLD, OLD + '\n\t\t\tEditor = Editor,', 1)
print("[4] appTable")

OLD = 'PlayersExplorer.Init()'
src = src.replace(OLD, OLD + '\n\t\tEditor.Init()', 1)
print("[5] Init")

OLD = 'Main.CreateApp({Name = "Players Explorer", IconMap = Main.MiscIcons, Icon = "SelectChildren", Window = PlayersExplorer.Window})'
src = src.replace(OLD, OLD + '\n\t\tMain.CreateApp({Name = "Editor", IconMap = Main.MiscIcons, Icon = "ViewScript", Window = Editor.Window})', 1)
print("[6] CreateApp icon")

# verify
for n in ['["Editor"] = function', 'Editor.Init()', 'Editor = Apps.Editor', 'Editor = Editor,', 'Name = "Editor"']:
    if src.count(n) != 1:
        print(f"FAIL: {n} = {src.count(n)}"); sys.exit(1)

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)
print(f"[OK] New size: {len(src)} (delta {len(src)-orig:+d})")
print("SUCCESS")
