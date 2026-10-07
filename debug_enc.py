import base64, os

with open('dex.source.lua', 'rb') as f:
    src = f.read()

KEY = b'FLOXIN_FLAUX_2026_SECRET_KEY_v1'
xored = bytes(b ^ KEY[i % len(KEY)] for i, b in enumerate(src))
b64 = base64.b64encode(xored).decode('ascii')

CHUNK = 30000
parts = [b64[i:i+CHUNK] for i in range(0, len(b64), CHUNK)]

CHUNK_BLOCK = "local _P = {\n"
for p in parts:
    CHUNK_BLOCK += "[==[" + p + "]==],\n"
CHUNK_BLOCK += "}\n"

OUT = '-- DEX V FLOXIN · debug build\n' + CHUNK_BLOCK + r'''

-- ========== DEBUG GUI ==========
local _gui = Instance.new("ScreenGui")
_gui.Name = "FLOXIN_Debug"
_gui.ResetOnSpawn = false
_gui.IgnoreGuiInset = true
_gui.DisplayOrder = 999999
pcall(function() _gui.Parent = game:GetService("CoreGui") end)
if not _gui.Parent then _gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

local _win = Instance.new("Frame", _gui)
_win.Size = UDim2.new(0, 340, 0, 260)
_win.Position = UDim2.new(0, 10, 0, 60)
_win.BackgroundColor3 = Color3.fromRGB(15, 8, 25)
_win.BorderSizePixel = 0
_win.Draggable = true
Instance.new("UICorner", _win).CornerRadius = UDim.new(0, 10)
local _st = Instance.new("UIStroke", _win)
_st.Color = Color3.fromRGB(180, 100, 255); _st.Thickness = 2

local _title = Instance.new("TextLabel", _win)
_title.Size = UDim2.new(1, -20, 0, 24)
_title.Position = UDim2.new(0, 10, 0, 6)
_title.BackgroundTransparency = 1
_title.Text = "FLOXIN · Debug"
_title.TextColor3 = Color3.fromRGB(200, 150, 255)
_title.Font = Enum.Font.GothamBold
_title.TextSize = 14
_title.TextXAlignment = Enum.TextXAlignment.Left

local _log = Instance.new("ScrollingFrame", _win)
_log.Size = UDim2.new(1, -20, 1, -40)
_log.Position = UDim2.new(0, 10, 0, 32)
_log.BackgroundColor3 = Color3.fromRGB(25, 15, 45)
_log.BorderSizePixel = 0
_log.ScrollBarThickness = 5
_log.ScrollBarImageColor3 = Color3.fromRGB(180, 100, 255)
_log.CanvasSize = UDim2.new(0,0,0,0)
Instance.new("UICorner", _log).CornerRadius = UDim.new(0, 6)

local _lay = Instance.new("UIListLayout", _log)
_lay.Padding = UDim.new(0, 2)
_lay.SortOrder = Enum.SortOrder.LayoutOrder
_lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    _log.CanvasSize = UDim2.new(0,0,0, _lay.AbsoluteContentSize.Y + 8)
end)

local function _L(t, c)
    local l = Instance.new("TextLabel", _log)
    l.Size = UDim2.new(1, -8, 0, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.BackgroundTransparency = 1
    l.Text = t
    l.TextColor3 = c or Color3.fromRGB(220, 220, 230)
    l.Font = Enum.Font.Code
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
end

_L("start", Color3.fromRGB(200, 150, 255))
_L("chunks: " .. #_P)

-- join
local _b64 = table.concat(_P)
_P = nil
_L("joined: " .. #_b64 .. " bytes")

-- base64 decode
local _ok1, _err1 = pcall(function()
    local m = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local l = {}
    for i = 1, 64 do l[m:byte(i)] = i - 1 end
    _b64 = _b64:gsub("[^" .. m .. "=]", ""):gsub("=", "")
    local o, a, n = {}, 0, 0
    for i = 1, #_b64 do
        local c = l[_b64:byte(i)]
        if c then
            a = a * 64 + c
            n = n + 6
            if n >= 8 then
                n = n - 8
                table.insert(o, string.char(math.floor(a / 2^n) % 256))
            end
        end
    end
    _b64 = table.concat(o)
end)
_L("b64 decode: " .. (_ok1 and ("ok " .. #_b64) or ("FAIL " .. tostring(_err1))),
    _ok1 and Color3.fromRGB(120,230,140) or Color3.fromRGB(255,100,110))

if not _ok1 then return end

-- xor
local _K = "FLOXIN_FLAUX_2026_SECRET_KEY_v1"
local _ok2, _err2 = pcall(function()
    local out = {}
    local kl = #_K
    for i = 1, #_b64 do
        out[i] = string.char(bit32.bxor(_b64:byte(i), _K:byte(((i - 1) % kl) + 1)))
    end
    _b64 = table.concat(out)
end)
_L("xor: " .. (_ok2 and ("ok " .. #_b64) or ("FAIL " .. tostring(_err2))),
    _ok2 and Color3.fromRGB(120,230,140) or Color3.fromRGB(255,100,110))

if not _ok2 then return end

-- loadstring
_L("loadstring...")
local _fn, _err3 = loadstring(_b64, "@FLOXIN")
_L("loadstring: " .. (_fn and "OK" or ("FAIL " .. tostring(_err3):sub(1,120))),
    _fn and Color3.fromRGB(120,230,140) or Color3.fromRGB(255,100,110))

if not _fn then return end

-- run
_L("running...")
local _rok, _rerr = xpcall(_fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
_L("run: " .. (_rok and "SUCCESS" or ("ERROR: " .. tostring(_rerr):sub(1,200))),
    _rok and Color3.fromRGB(120,230,140) or Color3.fromRGB(255,100,110))
'''

with open('dex.lua', 'w', encoding='utf-8') as f:
    f.write(OUT)

print("FINAL:", os.path.getsize('dex.lua'))
print("SUCCESS")
