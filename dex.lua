-- FLOXIN · Compare + Copy
local CoreGui = game:GetService("CoreGui")
local parent = (gethui and select(2, pcall(gethui))) or CoreGui

local Theme = {
    Main1 = Color3.fromRGB(52,52,52),
    Main2 = Color3.fromRGB(45,45,45),
    Outline1 = Color3.fromRGB(33,33,33),
    Text = Color3.fromRGB(255,255,255),
}

local gui = Instance.new("ScreenGui")
gui.Name = "FLOXIN_Cmp"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = parent

local win = Instance.new("Frame", gui)
win.Size = UDim2.new(0, 400, 0, 340)
win.Position = UDim2.new(0.5, -200, 0.5, -170)
win.BackgroundColor3 = Theme.Main1
win.BorderSizePixel = 0
win.Draggable = true
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 4)
local st = Instance.new("UIStroke", win); st.Color = Theme.Outline1

-- title bar
local bar = Instance.new("Frame", win)
bar.Size = UDim2.new(1, 0, 0, 20)
bar.BackgroundColor3 = Theme.Main2
bar.BorderSizePixel = 0
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

local title = Instance.new("TextLabel", bar)
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 5, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FLOXIN · Compare"
title.TextColor3 = Theme.Text
title.Font = Enum.Font.SourceSans
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

-- COPY button
local copyBtn = Instance.new("TextButton", bar)
copyBtn.Size = UDim2.new(0, 40, 0, 16)
copyBtn.Position = UDim2.new(1, -62, 0, 2)
copyBtn.BackgroundColor3 = Color3.fromRGB(60,90,140)
copyBtn.Text = "Copy"
copyBtn.TextColor3 = Theme.Text
copyBtn.Font = Enum.Font.SourceSansBold
copyBtn.TextSize = 12
copyBtn.BorderSizePixel = 0
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 3)
copyBtn.AutoButtonColor = false
copyBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard(table.concat(_allLines, "\n"))
        copyBtn.Text = "OK!"
        task.wait(1)
        copyBtn.Text = "Copy"
    elseif toclipboard then
        toclipboard(table.concat(_allLines, "\n"))
        copyBtn.Text = "OK!"
        task.wait(1)
        copyBtn.Text = "Copy"
    else
        copyBtn.Text = "N/A"
    end
end)

-- close X
local closeBtn = Instance.new("TextButton", bar)
closeBtn.Size = UDim2.new(0, 16, 0, 16)
closeBtn.Position = UDim2.new(1, -20, 0, 2)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "\226\156\149"
closeBtn.TextColor3 = Theme.Text
closeBtn.Font = Enum.Font.SourceSans
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundTransparency = 0 end)
closeBtn.MouseLeave:Connect(function() closeBtn.BackgroundTransparency = 1 end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local scroll = Instance.new("ScrollingFrame", win)
scroll.Size = UDim2.new(1, -8, 1, -28)
scroll.Position = UDim2.new(0, 4, 0, 24)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
scroll.CanvasSize = UDim2.new(0,0,0,0)

local lay = Instance.new("UIListLayout", scroll)
lay.Padding = UDim.new(0, 2)
lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + 6)
end)

_allLines = {}

local function log(t, c)
    table.insert(_allLines, t)
    local l = Instance.new("TextLabel", scroll)
    l.Size = UDim2.new(1, -6, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Text = t
    l.TextColor3 = c or Theme.Text
    l.Font = Enum.Font.SourceSans
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
end

local function hash(s)
    local h = 5381
    for i = 1, #s do
        h = ((h * 33) + s:byte(i)) % 0x100000000
    end
    return string.format("%08X", h)
end

local function hexOf(s, n)
    local out = {}
    for i = 1, math.min(n, #s) do
        out[#out+1] = string.format("%02X", s:byte(i))
    end
    return table.concat(out, " ")
end

task.spawn(function()
    log("Fetching RAW...", Color3.fromRGB(180,180,220))
    local rawUrl = "https://raw.githubusercontent.com/FL0XIN/FLOXIN-DEX-ROBLOX/refs/heads/main2/dex_raw.lua?v=" .. tostring(math.random(1e6))
    local ok1, raw = pcall(function() return game:HttpGet(rawUrl) end)
    if not ok1 or not raw then log("raw fetch failed"); return end
    log("RAW size: " .. #raw)
    log("RAW hash: " .. hash(raw), Color3.fromRGB(100,220,130))
    log("RAW first 20 hex: " .. hexOf(raw, 20))
    log("RAW last 20 hex: " .. hexOf(raw:sub(-20), 20))
    log("")

    log("Fetching ENCODED...", Color3.fromRGB(180,180,220))
    local encUrl = "https://raw.githubusercontent.com/FL0XIN/FLOXIN-DEX-ROBLOX/refs/heads/main2/dex.lua?v=" .. tostring(math.random(1e6))
    local ok2, enc = pcall(function() return game:HttpGet(encUrl) end)
    if not ok2 or not enc then log("enc fetch failed"); return end
    log("ENC size: " .. #enc)
    log("")

    log("Extracting chunks...", Color3.fromRGB(180,180,220))
    local chunks = {}
    for chunk in enc:gmatch("%[==%[(.-)%]==%]") do
        table.insert(chunks, chunk)
    end
    log("chunks: " .. #chunks)

    local b64 = table.concat(chunks)
    log("joined b64: " .. #b64)

    log("Base64 decode...", Color3.fromRGB(180,180,220))
    local m = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local l = {}
    for i = 1, 64 do l[m:byte(i)] = i - 1 end
    local clean = b64:gsub("[^" .. m .. "=]", ""):gsub("=", "")
    log("clean b64: " .. #clean)

    local o, a, n = {}, 0, 0
    for i = 1, #clean do
        local c = l[clean:byte(i)]
        if c then
            a = a * 64 + c
            n = n + 6
            if n >= 8 then
                n = n - 8
                table.insert(o, string.char(math.floor(a / 2^n) % 256))
            end
        end
    end
    local xored = table.concat(o)
    log("b64 decoded: " .. #xored)

    log("XOR...", Color3.fromRGB(180,180,220))
    local K = "FLOXIN_FLAUX_2026_SECRET_KEY_v1"
    local out = {}
    local kl = #K
    for i = 1, #xored do
        out[i] = string.char(bit32.bxor(xored:byte(i), K:byte(((i - 1) % kl) + 1)))
    end
    local decoded = table.concat(out)
    log("decoded: " .. #decoded)
    log("")
    log("=== COMPARE ===", Color3.fromRGB(255,210,100))
    log("RAW : " .. #raw)
    log("DEC : " .. #decoded)
    log("RAW hash: " .. hash(raw), Color3.fromRGB(100,220,130))
    log("DEC hash: " .. hash(decoded), Color3.fromRGB(100,220,130))
    log("")
    log("RAW first hex: " .. hexOf(raw, 20))
    log("DEC first hex: " .. hexOf(decoded, 20))
    log("")
    log("RAW last hex: " .. hexOf(raw:sub(-20), 20))
    log("DEC last hex: " .. hexOf(decoded:sub(-20), 20))
    log("")
    if raw == decoded then
        log("MATCH!", Color3.fromRGB(100,220,130))
    else
        log("MISMATCH!", Color3.fromRGB(255,100,110))
    end
    log("")
    log("DONE - tap Copy", Color3.fromRGB(255,210,100))
end)
